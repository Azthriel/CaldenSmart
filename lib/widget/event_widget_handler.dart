import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:home_widget/home_widget.dart';
import 'package:http/http.dart' as http;

import 'package:caldensmart/aws/dynamo/dynamo.dart';
import 'package:caldensmart/escenas/models/evento_estado.dart';
import 'package:caldensmart/logger.dart';
import 'package:caldensmart/secret.dart';
import 'package:caldensmart/widget/event_widget_models.dart';


const String androidEventWidgetName =
    'com.caldensmart.sime.widget.ControlWidgetProvider';
const String iOSEventWidgetName = 'ControlWidget';

/// Lista de widget IDs de eventos. Se mantiene APARTE de `active_widget_ids`
/// aunque compartan provider: syncWidgetsWithDatabase() y getWidgetTopics()
/// iteran esa lista esperando encontrar `widget_pc_$id` / `widget_sn_$id`. Si
/// metiéramos los eventos ahí, cada uno caería en la rama "datos incompletos,
/// saltando".
const String _kEventIdsKey = 'active_event_widget_ids';

String _cfgKey(int widgetId) => 'event_widget_cfg_$widgetId';

// ── Redibujado coalescido ──────────────────────────────────────────────────
// Una cadena de 7 pasos manda 7 mensajes MQTT. Sin coalescer, son 7
// updateAppWidget() seguidos y el widget parpadea. Los datos se escriben
// SIEMPRE al instante (baratos); lo que se agrupa es el redibujo visual.
final Map<int, Timer> _redrawTimers = {};
const Duration _redrawDebounce = Duration(milliseconds: 800);

/// Estados terminales: se redibujan al toque, sin esperar el debounce.
const Set<String> _terminalStatuses = {
  'completed',
  'cancelled',
  'error',
  'missing',
};

// ═══════════════════════════════════════════════════════════════════════════
// 1. Redibujado
// ═══════════════════════════════════════════════════════════════════════════

/// Fuerza el redibujo de TODOS los widgets de evento en el launcher.
Future<void> updateAllEventWidgets() async {
  try {
    if (Platform.isAndroid) {
      await HomeWidget.updateWidget(
          qualifiedAndroidName: androidEventWidgetName);
    } else if (Platform.isIOS) {
      await HomeWidget.updateWidget(iOSName: iOSEventWidgetName);
    }
  } catch (e) {
    printLog.e('Error actualizando widgets de evento: $e');
  }
}

void _scheduleRedraw(int widgetId, {required bool immediate}) {
  _redrawTimers[widgetId]?.cancel();

  if (immediate) {
    _redrawTimers.remove(widgetId);
    unawaited(updateAllEventWidgets());
    return;
  }

  _redrawTimers[widgetId] = Timer(_redrawDebounce, () {
    _redrawTimers.remove(widgetId);
    unawaited(updateAllEventWidgets());
  });
}

/// Cancela todos los timers pendientes. Llamar desde disposeWidgetListener().
void disposeEventWidgetTimers() {
  for (final t in _redrawTimers.values) {
    t.cancel();
  }
  _redrawTimers.clear();
}

// ═══════════════════════════════════════════════════════════════════════════
// 2. Registro y configuración
// ═══════════════════════════════════════════════════════════════════════════

Future<List<int>> getEventWidgetIds() async {
  try {
    final raw = await HomeWidget.getWidgetData<String>(_kEventIdsKey);
    if (raw == null || raw.isEmpty) return [];
    return List<int>.from(jsonDecode(raw));
  } catch (e) {
    printLog.e('Error leyendo lista de widgets de evento: $e');
    return [];
  }
}

Future<bool> hasActiveEventWidgets() async =>
    (await getEventWidgetIds()).isNotEmpty;

Future<void> registerEventWidgetId(int widgetId) async {
  try {
    final ids = await getEventWidgetIds();
    if (!ids.contains(widgetId)) {
      ids.add(widgetId);
      await HomeWidget.saveWidgetData(_kEventIdsKey, jsonEncode(ids));
      printLog.i('Widget de evento $widgetId registrado. Total: ${ids.length}');
    }
  } catch (e) {
    printLog.e('Error registrando widget de evento: $e');
  }
}

Future<void> unregisterEventWidgetId(int widgetId) async {
  try {
    final ids = await getEventWidgetIds();
    ids.remove(widgetId);
    await HomeWidget.saveWidgetData(_kEventIdsKey, jsonEncode(ids));

    // Limpiar los datos del widget para no dejar basura en SharedPrefs.
    await HomeWidget.saveWidgetData(_cfgKey(widgetId), '');
    await HomeWidget.saveWidgetData('widget_state_$widgetId', '');

    _redrawTimers.remove(widgetId)?.cancel();

    printLog.i('Widget de evento $widgetId eliminado. Total: ${ids.length}');
  } catch (e) {
    printLog.e('Error eliminando widget de evento: $e');
  }
}

Future<void> saveEventWidgetConfig(EventWidgetData data) async {
  await HomeWidget.saveWidgetData(_cfgKey(data.widgetId), data.toJsonString());
  printLog.i('Config de widget de evento ${data.widgetId} guardada: '
      '${data.kind.label} "${data.eventName}"');
}

Future<EventWidgetData?> loadEventWidgetConfig(int widgetId) async {
  try {
    final raw = await HomeWidget.getWidgetData<String>(_cfgKey(widgetId));
    if (raw == null || raw.isEmpty) return null;
    return EventWidgetData.fromJsonString(raw);
  } catch (e) {
    printLog.e('Error cargando config de widget de evento $widgetId: $e');
    return null;
  }
}

/// Topics MQTT que necesitan los widgets de evento activos.
/// Se unen con los de getWidgetTopics() en subscribeToWidgetTopics().
///
/// Solo el topic de progreso: `eventos/<tipo>/<email>/<nombre>/status`.
///
/// El widget NO verifica la conexión de los equipos que integran el evento.
/// Eso lo hace la pantalla de wifi, donde globalDATA está poblado y el dato es
/// gratis; acá había que reconstruirlo desde cero en un isolate donde no
/// existe. Si falta un equipo, el Lambda responde y el widget muestra el error.
Future<Set<String>> getEventWidgetTopics() async {
  final Set<String> topics = {};
  try {
    for (final id in await getEventWidgetIds()) {
      final cfg = await loadEventWidgetConfig(id);
      if (cfg == null) continue;
      if (cfg.eventName.isNotEmpty && cfg.email.isNotEmpty) {
        topics.add(cfg.mqttTopic);
      }
    }
  } catch (e) {
    printLog.e('Error obteniendo topics de widgets de evento: $e');
  }
  return topics;
}

// ═══════════════════════════════════════════════════════════════════════════
// 3. Escritura de estado (lo que lee Kotlin)
// ═══════════════════════════════════════════════════════════════════════════

/// Escribe el JSON atómico que renderiza EventWidgetProvider.
///
/// Se usa la MISMA clave `widget_state_$id` que los widgets de equipo: los
/// appWidgetId son únicos a nivel sistema, así que no hay colisión, y el
/// discriminante `kind: 'event'` permite que cualquiera de los dos providers
/// detecte si le corresponde el dato.
///
/// El progreso viaja YA RESUELTO (`progress` 0..100): Kotlin no debe
/// reimplementar los regex de EventoEstado.pasosCompletadosFromMensaje.
Future<void> writeEventWidgetState(
  EventWidgetData cfg,
  EventWidgetState state, {
  bool loading = false,
  bool immediate = false,
}) async {
  try {
    final map = <String, dynamic>{
      'kind': 'event',
      'nickname': cfg.nickname,
      'eventKind': cfg.kind.name,
      'eventType': cfg.kind.mqttType,
      'eventName': cfg.eventName,
      'status': state.status,
      'mensaje': state.mensaje,
      'pasosCompletados': state.pasosCompletados,
      'totalPasos': state.totalPasos,
      'progress': state.progressPercent,
      'hasProgress': cfg.kind.hasProgress,
      'canPause': cfg.kind.canPause,
      'loading': loading,
      'initializing': false,
      'ts': DateTime.now().millisecondsSinceEpoch,
    };
    if (state.groupOn != null) map['groupOn'] = state.groupOn;
    if (state.lastError != null) map['lastError'] = state.lastError;

    await HomeWidget.saveWidgetData(
        'widget_state_${cfg.widgetId}', jsonEncode(map));

    _scheduleRedraw(
      cfg.widgetId,
      immediate:
          immediate || loading || _terminalStatuses.contains(state.status),
    );
  } catch (e) {
    printLog.e('Error escribiendo estado de widget de evento: $e');
  }
}

/// Lee el estado actual desde SharedPrefs sin tocar la red.
Future<EventWidgetState> readEventWidgetState(int widgetId) async {
  try {
    final raw =
        await HomeWidget.getWidgetData<String>('widget_state_$widgetId');
    if (raw == null || raw.isEmpty) return EventWidgetState.idle();
    final map = Map<String, dynamic>.from(jsonDecode(raw));
    return EventWidgetState(
      status: map['status'] ?? 'idle',
      pasosCompletados: map['pasosCompletados'] ?? 0,
      totalPasos: map['totalPasos'] ?? 0,
      mensaje: map['mensaje'] ?? '',
      groupOn: map['groupOn'],
      lastError: map['lastError'],
    );
  } catch (e) {
    return EventWidgetState.idle();
  }
}

/// Refresca solo el `ts` de los widgets de evento, sin consultar nada.
///
/// OJO: a diferencia de los equipos, para un evento el `ts` NO sirve para
/// inferir "desconectado". Un evento en `idle` puede estar quieto días y estar
/// perfecto; una cadena en `running` puede tardar horas. El `ts` acá solo
/// sirve para que Kotlin sepa hace cuánto no confirmamos el dato y lo marque
/// como "sin confirmar" — nunca como offline.
Future<void> refreshEventWidgetTimestamps() async {
  final ids = await getEventWidgetIds();
  if (ids.isEmpty) return;

  final now = DateTime.now().millisecondsSinceEpoch;
  for (final id in ids) {
    try {
      final raw = await HomeWidget.getWidgetData<String>('widget_state_$id');
      if (raw == null || raw.isEmpty) continue;
      final map = Map<String, dynamic>.from(jsonDecode(raw));
      map['ts'] = now;
      map['loading'] = false;
      map['initializing'] = false;
      await HomeWidget.saveWidgetData('widget_state_$id', jsonEncode(map));
    } catch (e) {
      printLog.e('Error refrescando ts de widget de evento $id: $e');
    }
  }
  await updateAllEventWidgets();
}

// ═══════════════════════════════════════════════════════════════════════════
// 4. MQTT
// ═══════════════════════════════════════════════════════════════════════════

/// Maneja un mensaje de `eventos/<tipo>/<email>/<nombre>/status`.
///
/// Llamar SIEMPRE antes del parseo de devices en _handleWidgetMqttMessage:
/// ese hace `parts[1]` = productCode y `parts[2]` = serialNumber, y con un
/// topic de evento eso daría pc='ControlPorCadena' y sn=<email>, ensuciando
/// los widgets de equipo con datos basura.
Future<void> handleEventWidgetMqttMessage(
    String topic, Map<String, dynamic> messageMap) async {
  try {
    final parts = topic.split('/');
    // eventos / tipo / email / nombre / status
    if (parts.length < 5 || parts[4] != 'status') return;

    final tipoEvento = parts[1];
    final email = parts[2];
    final nombreEvento = parts[3];

    final kind = eventWidgetKindFromMqtt(tipoEvento);
    if (kind == null) {
      printLog.i('Widget evento: tipo desconocido "$tipoEvento", ignorado');
      return;
    }

    final estado = EventoEstado.fromJson(messageMap);
    printLog
        .i('Widget evento MQTT: $tipoEvento/$nombreEvento → ${estado.status} '
            '(${estado.mensaje})');

    await updateWidgetsForEvent(kind, nombreEvento, email, estado);
  } catch (e) {
    printLog.e('Error procesando mensaje MQTT de evento: $e');
  }
}

/// Actualiza todos los widgets que apunten a este evento.
Future<void> updateWidgetsForEvent(
  EventWidgetKind kind,
  String eventName,
  String email,
  EventoEstado estado,
) async {
  try {
    for (final id in await getEventWidgetIds()) {
      final cfg = await loadEventWidgetConfig(id);
      if (cfg == null) continue;
      if (cfg.kind != kind) continue;
      if (cfg.eventName != eventName) continue;
      // Distinto usuario: el topic es del mismo evento pero de otra cuenta.
      if (cfg.email.isNotEmpty && cfg.email != email) continue;

      final state = EventWidgetState.fromEventoEstado(estado);
      await writeEventWidgetState(cfg, state);

      printLog.i('Widget de evento $id actualizado: ${state.status} '
          '${state.pasosCompletados}/${state.totalPasos} (${state.progressPercent}%)');
    }
  } catch (e) {
    printLog.e('Error actualizando widgets para evento $eventName: $e');
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 5. Sincronización contra DynamoDB
// ═══════════════════════════════════════════════════════════════════════════

/// Trae el estado real de los eventos desde DynamoDB y lo vuelca a los widgets.
///
/// Para eventos, la fuente de verdad es `estado_ejecucion`, NO el timestamp.
/// Se agrupan las consultas por (email, tipo) para no hacer una query por
/// widget: con 4 widgets de cadena del mismo usuario, es UNA sola query.
Future<void> syncEventWidgetsWithDatabase() async {
  try {
    final ids = await getEventWidgetIds();
    if (ids.isEmpty) {
      printLog.i('No hay widgets de evento para sincronizar');
      return;
    }

    // 1. Cargar configs
    final configs = <EventWidgetData>[];
    for (final id in ids) {
      final cfg = await loadEventWidgetConfig(id);
      if (cfg != null) configs.add(cfg);
    }
    if (configs.isEmpty) return;

    final emails = configs.map((c) => c.email).toSet();

    // 2. Una query por (email, tipo), solo de los tipos que hagan falta
    final needCadena = configs.any((c) => c.kind == EventWidgetKind.cadena);
    final needRiego = configs.any((c) => c.kind == EventWidgetKind.riego);
    final needGrupo = configs.any((c) => c.kind == EventWidgetKind.grupo);

    // clave: '<email>|<kind.name>|<nombreEvento>' → estado_ejecucion crudo
    final Map<String, Map<String, dynamic>?> estados = {};
    // nombres de eventos que EXISTEN (para detectar huérfanos)
    final Set<String> existentes = {};

    for (final email in emails) {
      if (needCadena) {
        for (final ev in await queryEventosControlPorCadena(email)) {
          final nombre = ev['nombreEvento'] ?? '';
          existentes.add('$email|cadena|$nombre');
          estados['$email|cadena|$nombre'] =
              ev['estado_ejecucion'] as Map<String, dynamic>?;
        }
      }
      if (needRiego) {
        for (final ev in await queryEventosControlDeRiego(email)) {
          final nombre = ev['nombreEvento'] ?? '';
          existentes.add('$email|riego|$nombre');
          estados['$email|riego|$nombre'] =
              ev['estado_ejecucion'] as Map<String, dynamic>?;
        }
      }
      if (needGrupo) {
        // Los grupos no tienen tabla con estado. Se verifica existencia contra
        // la lista maestra de eventos (Alexa-Devices.events), que es lo mismo
        // que consume eventosCreados en la UI.
        for (final ev in await getEventos(email)) {
          if (ev['evento'] == 'grupo') {
            existentes.add('$email|grupo|${ev['title'] ?? ''}');
          }
        }
      }
    }

    // 3. Volcar a cada widget
    for (final cfg in configs) {
      final key = '${cfg.email}|${cfg.kind.name}|${cfg.eventName}';

      if (!existentes.contains(key)) {
        // El evento fue borrado o renombrado → widget huérfano.
        // Es un estado DISTINTO de "desconectado": no se arregla solo, hay que
        // recrear el widget. Por eso tiene su propio status.
        printLog.i(
            'Widget de evento ${cfg.widgetId}: "${cfg.eventName}" ya no existe');
        await writeEventWidgetState(cfg, EventWidgetState.missing(),
            immediate: true);
        continue;
      }

      if (!cfg.kind.hasProgress) {
        // Grupo: existe y no tiene estado que traer. Se preserva el último
        // groupOn optimista para no perder el toggle visual.
        final prev = await readEventWidgetState(cfg.widgetId);
        await writeEventWidgetState(
          cfg,
          EventWidgetState(status: 'idle', groupOn: prev.groupOn),
        );
        printLog
            .i('Widget de evento ${cfg.widgetId} (grupo "${cfg.eventName}") '
                'sincronizado');
        continue;
      }

      // CLAVE: eventoEstadoDesdeDynamo() sintetiza el campo `mensaje`, que NO
      // existe en la tabla. Sin eso, progresoDecimal / pasosCompletadosFromMensaje
      // devuelven 0 y la barra queda siempre vacía aunque haya 5 de 7 pasos.
      final estado = eventoEstadoDesdeDynamo(estados[key]);

      final state = estado == null
          ? EventWidgetState.idle()
          : EventWidgetState.fromEventoEstado(estado);

      await writeEventWidgetState(cfg, state);
      printLog
          .i('Widget de evento ${cfg.widgetId} sincronizado: ${state.status} '
              '${state.pasosCompletados}/${state.totalPasos}');
    }

    await updateAllEventWidgets();
    printLog.i('Sincronización de widgets de evento completada');
  } catch (e) {
    printLog.e('Error sincronizando widgets de evento: $e');
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 6. Acciones (tap en el widget)
// ═══════════════════════════════════════════════════════════════════════════

/// Acciones que puede disparar el widget.
/// URI: caldensmart://widget/event?widgetId=N&action=start|pause|resume|cancel|group[&on=true]
Future<void> handleEventWidgetAction(
  int widgetId,
  String action, {
  bool? on,
}) async {
  final cfg = await loadEventWidgetConfig(widgetId);
  if (cfg == null) {
    printLog.e('Widget de evento $widgetId: sin configuración');
    return;
  }

  // ── Loading inmediato ─────────────────────────────────────────────────
  final currentState = await readEventWidgetState(widgetId);
  await writeEventWidgetState(cfg, currentState,
      loading: true, immediate: true);

  try {
    final result = await _dispatchEventAction(cfg, action, on: on);

    if (result.ok) {
      // Estado optimista. El estado REAL llega enseguida por MQTT
      // (eventos/.../status) y pisa esto. Para grupo, que no publica estado,
      // el optimista es lo único que hay.
      final optimistic = switch (action) {
        'start' => currentState.copyWith(
            status: 'running',
            mensaje: 'Iniciando...',
            pasosCompletados: 0,
          ),
        'pause' => currentState.copyWith(status: 'paused'),
        'resume' => currentState.copyWith(status: 'running'),
        'cancel' => currentState.copyWith(status: 'cancelled'),
        'group' => currentState.copyWith(status: 'idle', groupOn: on),
        _ => currentState,
      };
      await writeEventWidgetState(cfg, optimistic, immediate: true);
      printLog.i('Widget evento $widgetId: acción "$action" OK');
    } else {
      // El Lambda es el que valida permisos (checkAdminTimePermission,
      // equipos restringidos, etc). NO se replica esa lógica acá: en el
      // isolate de background globalDATA está vacío y daríamos falsos
      // negativos. Se muestra el motivo que devuelve el backend.
      await writeEventWidgetState(
        cfg,
        currentState.copyWith(status: 'error', lastError: result.message),
        immediate: true,
      );
      printLog.e(
          'Widget evento $widgetId: acción "$action" falló → ${result.message}');

      // Volver al estado real tras mostrar el error unos segundos.
      Timer(const Duration(seconds: 4), () async {
        final s = await readEventWidgetState(widgetId);
        if (s.status == 'error') {
          await writeEventWidgetState(cfg, currentState, immediate: true);
        }
      });
    }
  } catch (e) {
    printLog.e('Error ejecutando acción de widget de evento: $e');
    await writeEventWidgetState(
      cfg,
      currentState.copyWith(status: 'error', lastError: 'Sin conexión'),
      immediate: true,
    );
  }
}

class _ActionResult {
  final bool ok;
  final String message;
  const _ActionResult(this.ok, this.message);
}

/// Traduce (kind, action) al POST correspondiente.
///
/// Los payloads NO son uniformes entre tipos — replican exactamente lo que
/// manda wifi.dart hoy:
///   • cadena → {'nombreEvento','email','accion': start|pause|resume|cancel}
///   • riego  → start: {'nombreEvento','email'}
///              resto: {'operation': pausar|reanudar|cancelar,'email','nombreEvento'}
///   • grupo  → {'email','on','grupo','app'}
Future<_ActionResult> _dispatchEventAction(
  EventWidgetData cfg,
  String action, {
  bool? on,
}) async {
  final Uri uri;
  final String body;
  final headers = {'Content-Type': 'application/json'};

  switch (cfg.kind) {
    case EventWidgetKind.cadena:
      const accionMap = {
        'start': 'start',
        'pause': 'pause',
        'resume': 'resume',
        'cancel': 'cancel',
      };
      final accion = accionMap[action];
      if (accion == null) {
        return const _ActionResult(false, 'Acción no válida');
      }
      uri = Uri.parse(controlCadenaAPI);
      body = jsonEncode({
        'nombreEvento': cfg.eventName,
        'email': cfg.email,
        'accion': accion,
      });

    case EventWidgetKind.riego:
      uri = Uri.parse(controlRiegoAPI);
      if (action == 'start') {
        body = jsonEncode({
          'nombreEvento': cfg.eventName,
          'email': cfg.email,
        });
      } else {
        const opMap = {
          'pause': 'pausar',
          'resume': 'reanudar',
          'cancel': 'cancelar',
        };
        final op = opMap[action];
        if (op == null) {
          return const _ActionResult(false, 'Acción no válida');
        }
        body = jsonEncode({
          'operation': op,
          'email': cfg.email,
          'nombreEvento': cfg.eventName,
        });
      }

    case EventWidgetKind.grupo:
      if (action != 'group' || on == null) {
        return const _ActionResult(false, 'Acción no válida');
      }
      uri = Uri.parse(controlGruposAPI);
      body = jsonEncode({
        'email': cfg.email,
        'on': on,
        'grupo': cfg.eventName,
        // Fijo en 0: la global `app` la setea la UI y en el isolate de
        // background no hay garantia de que este inicializada.
        'app': 0,
      });
  }

  printLog.i('Widget evento → POST $uri  body=$body');

  final response = await http
      .post(uri, headers: headers, body: body)
      .timeout(const Duration(seconds: 15));

  printLog.i('Widget evento ← ${response.statusCode}: ${response.body}');

  switch (response.statusCode) {
    case 200:
      return const _ActionResult(true, '');
    case 207:
      // Grupo: algunos equipos no respondieron.
      return const _ActionResult(true, 'Parcial');
    case 400:
      return _ActionResult(
          false, _errorFromBody(response.body, 'Datos inválidos'));
    case 403:
      return _ActionResult(false, _errorFromBody(response.body, 'Sin permiso'));
    case 404:
      return const _ActionResult(false, 'No existe');
    default:
      return _ActionResult(false, 'Error ${response.statusCode}');
  }
}

String _errorFromBody(String body, String fallback) {
  try {
    final map = jsonDecode(body);
    final msg = map is Map ? (map['error'] ?? map['message']) : null;
    if (msg is String && msg.isNotEmpty) {
      // El widget tiene poco espacio: recortamos.
      return msg.length > 40 ? '${msg.substring(0, 37)}...' : msg;
    }
  } catch (_) {}
  return fallback;
}
