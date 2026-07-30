import 'dart:convert';
import 'package:caldensmart/escenas/models/evento_estado.dart';

/// Tipos de evento que pueden tener widget en la pantalla de inicio.
///
/// Ojo: NO todos los eventos de la app entran acá. `clima`, `horario` y
/// `disparador` son eventos *automáticos* (los dispara el backend solo), así
/// que un widget para "activarlos a mano" no tendría sentido. Solo modelamos
/// los tres que en wifi.dart tienen botón de activación manual.
enum EventWidgetKind {
  /// Ejecuta N pasos en secuencia. Tiene estado_ejecucion y progreso.
  cadena,

  /// Rutina de riego por zonas. Tiene estado_ejecucion y progreso.
  riego,

  /// Enciende/apaga un conjunto de equipos de una. SIN estado persistido.
  grupo,
}

extension EventWidgetKindX on EventWidgetKind {
  /// Segmento que usa el topic MQTT:
  ///   eventos/<mqttType>/<email>/<nombreEvento>/status
  ///
  /// Debe coincidir EXACTAMENTE con subscribeToAllUserEventos() en mqtt.dart
  /// y con las claves que usa eventosEstadoProvider ('<mqttType>/<nombre>').
  String get mqttType {
    switch (this) {
      case EventWidgetKind.cadena:
        return 'ControlPorCadena';
      case EventWidgetKind.riego:
        return 'ControlPorRiego';
      case EventWidgetKind.grupo:
        return 'ControlPorGrupos';
    }
  }

  /// Valor del campo 'evento' tal como viene de getEventos() / eventosCreados.
  String get eventoField {
    switch (this) {
      case EventWidgetKind.cadena:
        return 'cadena';
      case EventWidgetKind.riego:
        return 'riego';
      case EventWidgetKind.grupo:
        return 'grupo';
    }
  }

  /// ¿Tiene estado_ejecucion persistido en DynamoDB y progreso por pasos?
  ///
  /// Grupo NO: putEventoControlPorGrupos() solo guarda email/nombreEvento/grupo,
  /// y loadInitialEventosState() no lo recorre. Es comando puro.
  bool get hasProgress => this != EventWidgetKind.grupo;

  /// ¿Se puede pausar / reanudar / cancelar mientras corre?
  bool get canPause => this != EventWidgetKind.grupo;

  String get label {
    switch (this) {
      case EventWidgetKind.cadena:
        return 'Cadena';
      case EventWidgetKind.riego:
        return 'Riego';
      case EventWidgetKind.grupo:
        return 'Grupo';
    }
  }
}

/// Resuelve el kind desde el campo 'evento' de getEventos(). Devuelve null si
/// el evento no es widgetizable (clima, horario, disparador).
EventWidgetKind? eventWidgetKindFromEvento(String? evento) {
  switch (evento) {
    case 'cadena':
      return EventWidgetKind.cadena;
    case 'riego':
      return EventWidgetKind.riego;
    case 'grupo':
      return EventWidgetKind.grupo;
    default:
      return null;
  }
}

/// Normaliza el campo `deviceGroup`, que según el evento puede venir como
/// List<dynamic> o como String separado por comas (wifi.dart lo trata de las
/// dos formas en _hasRestrictedDevicesInGroup).
List<String> parseDeviceGroup(dynamic raw) {
  if (raw == null) return const [];
  if (raw is List) {
    return raw
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }
  if (raw is String) {
    return raw
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }
  return const [];
}

/// Resuelve el kind desde el segmento del topic MQTT.
EventWidgetKind? eventWidgetKindFromMqtt(String? mqttType) {
  switch (mqttType) {
    case 'ControlPorCadena':
      return EventWidgetKind.cadena;
    case 'ControlPorRiego':
      return EventWidgetKind.riego;
    case 'ControlPorGrupos':
      return EventWidgetKind.grupo;
    default:
      return null;
  }
}

/// Configuración persistida de un widget de evento.
///
/// A diferencia de WidgetData (que se identifica por productCode/serialNumber,
/// inmutables), un evento se identifica por **nombre**, que ES la primary key
/// en DynamoDB. Si el usuario renombra o borra el evento, el widget queda
/// huérfano: por eso el sync distingue "no existe" de "desconectado".
class EventWidgetData {
  final int widgetId;
  final EventWidgetKind kind;

  /// nombreEvento == evento['title']. Es la PK en DynamoDB.
  final String eventName;

  /// Email del dueño. Forma parte del topic MQTT, así que hay que guardarlo:
  /// el isolate de background no puede asumir que loadEmail() devuelva lo
  /// mismo si el usuario cambió de cuenta.
  final String email;

  /// Nombre a mostrar. Hoy == eventName, pero lo dejamos separado por si más
  /// adelante se permite renombrar el widget sin tocar el evento.
  final String nickname;

  const EventWidgetData({
    required this.widgetId,
    required this.kind,
    required this.eventName,
    required this.email,
    required this.nickname,
  });

  /// Topic al que hay que suscribirse para recibir el progreso.
  String get mqttTopic => 'eventos/${kind.mqttType}/$email/$eventName/status';

  /// Clave equivalente a la que usa eventosEstadoProvider en la UI.
  String get stateKey => '${kind.mqttType}/$eventName';

  Map<String, dynamic> toJson() => {
        'widgetId': widgetId,
        'kind': kind.name,
        'eventName': eventName,
        'email': email,
        'nickname': nickname,
      };

  factory EventWidgetData.fromJson(Map<String, dynamic> json) {
    final kind = EventWidgetKind.values.firstWhere(
      (e) => e.name == json['kind'],
      orElse: () => EventWidgetKind.grupo,
    );
    return EventWidgetData(
      widgetId: json['widgetId'],
      kind: kind,
      eventName: json['eventName'] ?? '',
      email: json['email'] ?? '',
      nickname: json['nickname'] ?? json['eventName'] ?? '',
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory EventWidgetData.fromJsonString(String s) =>
      EventWidgetData.fromJson(jsonDecode(s));
}

/// Estado renderizable de un widget de evento.
///
/// Es el puente entre EventoEstado (modelo de la app, con getters que parsean
/// el mensaje) y el JSON plano que lee Kotlin. El progreso se calcula ACÁ, en
/// Dart, y viaja ya resuelto: Kotlin no debe reimplementar los regex de
/// pasosCompletadosFromMensaje.
class EventWidgetState {
  /// idle | running | paused | completed | cancelled | error | missing
  ///
  /// 'missing' es propio del widget (no viene del backend): el evento ya no
  /// existe en DynamoDB, probablemente porque lo borraron o renombraron.
  final String status;

  final int pasosCompletados;
  final int totalPasos;
  final String mensaje;

  /// Solo para grupo: último estado comandado (optimista). null en los demás.
  final bool? groupOn;

  /// Mensaje corto del último error, para mostrar en el widget.
  final String? lastError;

  const EventWidgetState({
    required this.status,
    this.pasosCompletados = 0,
    this.totalPasos = 0,
    this.mensaje = '',
    this.groupOn,
    this.lastError,
  });

  bool get isRunning => status == 'running';
  bool get isPaused => status == 'paused';
  bool get isIdle => status == 'idle';
  bool get isMissing => status == 'missing';
  bool get isActive => isRunning || isPaused;

  /// 0..100 listo para RemoteViews.setProgressBar().
  int get progressPercent {
    if (totalPasos <= 0) return 0;
    final p = (pasosCompletados / totalPasos * 100).round();
    return p.clamp(0, 100);
  }

  factory EventWidgetState.idle() => const EventWidgetState(status: 'idle');

  factory EventWidgetState.missing() => const EventWidgetState(
        status: 'missing',
        mensaje: 'El evento ya no existe',
      );

  /// Construye el estado del widget a partir del modelo de la app.
  ///
  /// IMPORTANTE: EventoEstado.pasosCompletadosFromMensaje parsea `mensaje`.
  /// Si el EventoEstado viene de DynamoDB (donde `mensaje` NO se guarda), hay
  /// que haberlo sintetizado antes — ver eventoEstadoDesdeDynamo().
  factory EventWidgetState.fromEventoEstado(EventoEstado e) {
    return EventWidgetState(
      status: e.status,
      pasosCompletados: e.pasosCompletadosFromMensaje,
      totalPasos: e.totalPasos,
      mensaje: e.mensaje,
      lastError: e.error,
    );
  }

  EventWidgetState copyWith({
    String? status,
    int? pasosCompletados,
    int? totalPasos,
    String? mensaje,
    bool? groupOn,
    String? lastError,
  }) {
    return EventWidgetState(
      status: status ?? this.status,
      pasosCompletados: pasosCompletados ?? this.pasosCompletados,
      totalPasos: totalPasos ?? this.totalPasos,
      mensaje: mensaje ?? this.mensaje,
      groupOn: groupOn ?? this.groupOn,
      lastError: lastError ?? this.lastError,
    );
  }
}

/// Reconstruye un EventoEstado a partir del `estado_ejecucion` crudo de
/// DynamoDB, **sintetizando el campo `mensaje`**.
///
/// Por qué: queryEventosControlPorCadena/DeRiego devuelven status, paso_actual,
/// total_pasos y pasos_completados, pero NO `mensaje` (no está en la tabla).
/// Como todos los getters de progreso de EventoEstado parsean `mensaje`, si lo
/// dejamos vacío el progreso da 0 aunque haya 5 de 7 pasos hechos.
///
/// Se replica el mismo formato que arma loadInitialEventosState() en mqtt.dart,
/// para que el regex `(\d+)\s+pasos?\s+completados?` lo enganche igual.
EventoEstado? eventoEstadoDesdeDynamo(Map<String, dynamic>? estadoEjecucion) {
  if (estadoEjecucion == null) return null;

  final String status = estadoEjecucion['status'] ?? 'idle';
  final int pasoActual = estadoEjecucion['paso_actual'] ?? 0;
  final int totalPasos = estadoEjecucion['total_pasos'] ?? 0;
  final List<dynamic> pasosCompletados =
      estadoEjecucion['pasos_completados'] ?? const [];

  final mensaje = '${pasosCompletados.length} pasos completados de $totalPasos'
      '${status == 'paused' ? ' - Pausado' : ''}';

  return EventoEstado(
    status: status,
    pasoActual: pasoActual,
    totalPasos: totalPasos,
    mensaje: mensaje,
    timestamp: DateTime.now().millisecondsSinceEpoch,
  );
}
