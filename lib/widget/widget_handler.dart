import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:ui';
import 'package:caldensmart/widget/widget_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:home_widget/home_widget.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:caldensmart/aws/mqtt/mqtt.dart';
import 'package:caldensmart/aws/dynamo/dynamo.dart';
import 'package:caldensmart/Global/stored_data.dart';
import 'package:caldensmart/master.dart';
import 'package:caldensmart/logger.dart';
import 'package:caldensmart/widget/widget_service.dart';

/// Constantes para widgets iOS
const String iOSWidgetName = 'ControlWidget';
const String iOSAppGroupId = 'group.com.caldensmart.sime';
const String androidWidgetName =
    'com.caldensmart.sime.widget.ControlWidgetProvider';

/// Helper para actualizar widgets en ambas plataformas
Future<void> updateAllWidgets() async {
  if (Platform.isAndroid) {
    await HomeWidget.updateWidget(
      qualifiedAndroidName: androidWidgetName,
    );
  } else if (Platform.isIOS) {
    await HomeWidget.updateWidget(
      iOSName: iOSWidgetName,
    );
  }
}

/// Stream subscription para mensajes MQTT de widgets
StreamSubscription? _widgetMqttSubscription;

/// Flag para evitar múltiples suscripciones
bool _isWidgetListenerActive = false;

/// Flag para indicar que el servicio está completamente inicializado
/// Los widgets no deben permitir interacción hasta que esto sea true
bool _isServiceReady = false;

/// Verifica si el servicio está listo para procesar interacciones de widgets
Future<bool> isWidgetServiceReady() async {
  // Primero verificar el caché en memoria
  if (_isServiceReady) return true;

  try {
    final prefs = await SharedPreferences.getInstance();
    _isServiceReady = prefs.getBool('widget_service_ready') ?? false;
    return _isServiceReady;
  } catch (e) {
    return false;
  }
}

/// Marca el servicio como listo o no listo
Future<void> setWidgetServiceReady(bool ready) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('widget_service_ready', ready);
    _isServiceReady = ready;

    // Actualizar todos los widgets para reflejar el nuevo estado
    await HomeWidget.saveWidgetData('widget_service_ready', ready);
    await updateAllWidgets();

    printLog.i('Widget service ready: $ready');
  } catch (e) {
    printLog.e('Error setting widget service ready: $e');
  }
}

/// Refresca el timestamp de todos los widgets y marca el servicio como ready.
/// Llamado desde WorkManager vía HomeWidgetBackgroundIntent("/update") cada 15 minutos.
///
/// NO hace llamadas a DynamoDB (el isolate de backgroundCallback no tiene
/// credenciales AWS inicializadas). Su objetivo es:
///   1. Evitar que el dato quede "stale" (ts > 20 min → effectiveOnline = false).
///   2. Resetear widget_service_ready = true para quitar "Iniciando...".
///   3. Limpiar flags de loading/initializing que pudieran haber quedado colgados.
Future<void> _handleWidgetBackgroundUpdate() async {
  try {
    printLog.i('Background update: refrescando timestamps de widgets...');

    final widgetIds = await WidgetService.getWidgetIds();

    if (widgetIds.isEmpty) {
      printLog.i('Background update: no hay widgets configurados');
      // Igual marcar ready para limpiar cualquier "Iniciando..." huérfano
      await HomeWidget.saveWidgetData('widget_service_ready', true);
      await updateAllWidgets();
      return;
    }

    int refreshed = 0;
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    for (final widgetId in widgetIds) {
      try {
        final jsonStr =
            await HomeWidget.getWidgetData<String>('widget_state_$widgetId');

        if (jsonStr != null && jsonStr.isNotEmpty) {
          final map = Map<String, dynamic>.from(jsonDecode(jsonStr));

          // Actualizar timestamp → evita detección de stale en Kotlin
          map['ts'] = nowMs;
          // Limpiar flags que podrían haberse quedado colgados
          map['initializing'] = false;
          map['loading'] = false;

          await HomeWidget.saveWidgetData(
              'widget_state_$widgetId', jsonEncode(map));
          refreshed++;
        }
      } catch (e) {
        printLog.e('Background update: error refrescando widget $widgetId: $e');
      }
    }

    // Marcar servicio como ready: hay datos válidos guardados
    await HomeWidget.saveWidgetData('widget_service_ready', true);

    // Disparar redibujado visual en el launcher
    await updateAllWidgets();

    printLog.i(
        'Background update: $refreshed/${widgetIds.length} widgets refrescados');
  } catch (e) {
    printLog.e('Error en _handleWidgetBackgroundUpdate: $e');
  }
}

/// Callback que se ejecuta cuando el widget es presionado en background
/// Esta función debe ser top-level (no dentro de una clase)
@pragma('vm:entry-point')
Future<void> backgroundCallback(Uri? uri) async {
  // Asegurar que Flutter esté inicializado (importante para background)
  WidgetsFlutterBinding.ensureInitialized();

  printLog.i('Widget background callback: $uri');

  if (uri == null) {
    printLog.e('Widget callback: URI es null');
    return;
  }

  printLog.i('URI scheme: ${uri.scheme}, host: ${uri.host}, path: ${uri.path}');

  // Manejar diferentes acciones
  if (uri.host == 'widget') {
    if (uri.path == '/toggle') {
      // Toggle de un widget
      final widgetIdStr = uri.queryParameters['widgetId'];
      printLog.i('Widget callback: widgetId string = $widgetIdStr');

      if (widgetIdStr == null) {
        printLog.e('Widget callback: widgetId es null');
        return;
      }

      final widgetId = int.tryParse(widgetIdStr);
      if (widgetId == null) {
        printLog.e('Widget callback: no se pudo parsear widgetId');
        return;
      }

      printLog.i('Widget callback: procesando toggle para widget $widgetId');
      await _handleWidgetToggle(widgetId);
    } else if (uri.path == '/open') {
      // ← NUEVO
      final widgetId = int.tryParse(uri.queryParameters['widgetId'] ?? '');
      if (widgetId != null) await _handleRollerCommand(widgetId, 0);
    } else if (uri.path == '/close') {
      // ← NUEVO
      final widgetId = int.tryParse(uri.queryParameters['widgetId'] ?? '');
      if (widgetId != null) await _handleRollerCommand(widgetId, 100);
    } else if (uri.path == '/position') {
      // Roller: frenar en posición actual (isMoving → manda posición corriente)
      final widgetId = int.tryParse(uri.queryParameters['widgetId'] ?? '');
      final pos = int.tryParse(uri.queryParameters['pos'] ?? '');
      if (widgetId != null && pos != null) {
        await _handleRollerCommand(widgetId, pos);
      }
    }
  } else if (uri.path == '/checkAndStop') {
    printLog.i(
        'Widget callback: verificando widgets y deteniendo servicio si es necesario');
    await _handleCheckAndStopService();
  } else if (uri.path == '/update') {
    // Llamado por WorkManager (WidgetUpdateWorker) cada 15 min
    // Refresca el timestamp de los widgets para evitar que queden "stale"
    // y marca widget_service_ready = true para eliminar "Iniciando..."
    printLog.i('Widget callback: background update solicitado por WorkManager');
    await _handleWidgetBackgroundUpdate();
  } else {
    printLog.i(
        'Widget callback: URI no coincide con ninguna acción conocida (path=${uri.path})');
  }
}

/// Envía comando de posición MQTT para un widget roller (024011_IOT)
/// position: 0 = abrir, 100 = cerrar
Future<void> _handleRollerCommand(int widgetId, int position) async {
  try {
    printLog.i('=== ROLLER COMMAND widget $widgetId → $position% ===');

    final isReady = await isWidgetServiceReady();
    if (!isReady) {
      printLog.i('Roller widget $widgetId: servicio no listo, ignorando');
      return;
    }

    // Loading visual
    await HomeWidget.saveWidgetData('widget_loading_$widgetId', true);
    await updateAllWidgets();

    // Leer pc/sn del widget
    final pc = await HomeWidget.getWidgetData<String>('widget_pc_$widgetId');
    final sn = await HomeWidget.getWidgetData<String>('widget_sn_$widgetId');

    if (pc == null || sn == null) {
      printLog.e('Roller widget $widgetId: datos incompletos');
      await _hideWidgetLoading(widgetId);
      return;
    }

    // Verificar calibración desde el estado atómico guardado
    final jsonStr =
        await HomeWidget.getWidgetData<String>('widget_state_$widgetId');
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final map = Map<String, dynamic>.from(jsonDecode(jsonStr));
        final bool calibrated = map['isCalibrated'] ?? false;
        if (!calibrated) {
          printLog
              .i('Roller widget $widgetId: no calibrado, ignorando comando');
          await _hideWidgetLoading(widgetId);
          return;
        }
      } catch (_) {}
    }

    // Conectar MQTT si hace falta
    if (mqttAWSFlutterClient == null ||
        mqttAWSFlutterClient!.connectionStatus?.state !=
            MqttConnectionState.connected) {
      final connected = await setupMqtt();
      if (!connected) {
        printLog.e('Roller widget $widgetId: no se pudo conectar a MQTT');
        await _hideWidgetLoading(widgetId);
        return;
      }
    }

    final topicRx = 'devices_rx/$pc/$sn';
    final topicTx = 'devices_tx/$pc/$sn';
    final message = jsonEncode({'working_position': '$position%'});

    sendMessagemqtt(topicRx, message);
    sendMessagemqtt(topicTx, message);

    printLog.i('Roller widget $widgetId: MQTT enviado → $position%');

    // Actualizar estado optimista en SharedPrefs
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final map = Map<String, dynamic>.from(jsonDecode(jsonStr));
        map['rollerPosition'] = position;
        map['status'] = position >= 50;
        map['ts'] = DateTime.now().millisecondsSinceEpoch;
        await HomeWidget.saveWidgetData(
            'widget_state_$widgetId', jsonEncode(map));
      } catch (_) {}
    }

    await _hideWidgetLoading(widgetId);
  } catch (e) {
    printLog.e('Error en roller command widget $widgetId: $e');
    await _hideWidgetLoading(widgetId);
  }
}

/// Verifica si quedan widgets activos y detiene el servicio si es necesario
Future<void> _handleCheckAndStopService() async {
  try {
    printLog.i('Verificando widgets activos después de eliminación...');

    final hasWidgets = await hasActiveWidgets();

    if (!hasWidgets) {
      printLog.i(
          'No hay widgets activos, verificando si se puede detener el servicio');

      // Invocar al servicio de background para que verifique y se detenga
      final backService = FlutterBackgroundService();
      final isRunning = await backService.isRunning();

      if (isRunning) {
        backService.invoke('checkWidgetsAndStop');
        printLog.i('Notificado al servicio para verificar y detener');
      } else {
        printLog.i('El servicio no está corriendo');
      }
    } else {
      printLog.i('Aún hay widgets activos, el servicio continúa');
    }
  } catch (e) {
    printLog.e('Error verificando widgets: $e');
  }
}

/// Maneja el toggle de un widget específico
Future<void> _handleWidgetToggle(int widgetId) async {
  try {
    printLog.i('=== INICIO _handleWidgetToggle para widget $widgetId ===');

    // Verificar si el servicio está listo
    final isReady = await isWidgetServiceReady();
    if (!isReady) {
      printLog.i('Widget $widgetId: Servicio no está listo, ignorando toggle');
      // Mostrar estado de inicializando al usuario
      await HomeWidget.saveWidgetData('widget_initializing_$widgetId', true);
      await updateAllWidgets();

      // Esperar un momento y limpiar el estado
      await Future.delayed(const Duration(seconds: 2));
      await HomeWidget.saveWidgetData('widget_initializing_$widgetId', false);
      await updateAllWidgets();
      return;
    }

    // Mostrar loading inmediatamente
    await HomeWidget.saveWidgetData('widget_loading_$widgetId', true);
    await updateAllWidgets();

    // Leer datos del widget desde SharedPreferences
    final pc = await HomeWidget.getWidgetData<String>('widget_pc_$widgetId');
    final sn = await HomeWidget.getWidgetData<String>('widget_sn_$widgetId');
    final isPin =
        await HomeWidget.getWidgetData<bool>('widget_is_pin_$widgetId') ??
            false;
    final pinIndex =
        await HomeWidget.getWidgetData<String>('widget_pin_index_$widgetId') ??
            '';
    final currentStatus =
        await HomeWidget.getWidgetData<bool>('widget_status_$widgetId') ??
            false;
    final isControl =
        await HomeWidget.getWidgetData<bool>('widget_is_control_$widgetId') ??
            false;

    printLog.i(
        'Widget $widgetId datos: pc=$pc, sn=$sn, isPin=$isPin, pinIndex=$pinIndex, currentStatus=$currentStatus, isControl=$isControl');

    if (pc == null || sn == null) {
      printLog.e('Widget $widgetId: datos incompletos (pc=$pc, sn=$sn)');
      await _hideWidgetLoading(widgetId);
      return;
    }

    // Solo toggle si es un dispositivo de control
    if (!isControl) {
      printLog.i('Widget $widgetId: no es un dispositivo de control, saliendo');
      await _hideWidgetLoading(widgetId);
      return;
    }

    // Calcular nuevo estado (toggle)
    final newStatus = !currentStatus;
    printLog.i('Widget $widgetId: toggle de $currentStatus -> $newStatus');

    // Asegurar conexión MQTT (importante para cuando la app está cerrada)
    printLog.i('Widget $widgetId: verificando conexión MQTT...');
    if (mqttAWSFlutterClient == null) {
      printLog
          .i('Widget $widgetId: mqttAWSFlutterClient es null, conectando...');
    } else {
      printLog.i(
          'Widget $widgetId: estado MQTT actual = ${mqttAWSFlutterClient!.connectionStatus?.state}');
    }

    if (mqttAWSFlutterClient == null ||
        mqttAWSFlutterClient!.connectionStatus?.state !=
            MqttConnectionState.connected) {
      printLog.i('Widget: Conectando a MQTT...');
      final connected = await setupMqtt();
      if (!connected) {
        printLog.e('Widget: No se pudo conectar a MQTT');
        await _hideWidgetLoading(widgetId);
        return;
      }
      printLog.i('Widget: MQTT conectado exitosamente');
    }

    // Construir topics MQTT
    final topicRx = 'devices_rx/$pc/$sn';
    final topicTx = 'devices_tx/$pc/$sn';
    printLog.i('Widget $widgetId: topics - rx=$topicRx, tx=$topicTx');

    // Construir mensaje según el tipo de dispositivo
    String message;
    if (isPin && pinIndex.isNotEmpty) {
      // Dispositivo con pin (IO)
      final index = int.tryParse(pinIndex) ?? 0;
      message = jsonEncode({
        'pinType': 0,
        'index': index,
        'w_status': newStatus,
        'r_state': '0', // Por defecto
      });
      printLog.i('Widget $widgetId: Toggle pin $index -> $newStatus');
    } else {
      // Dispositivo normal
      message = jsonEncode({'w_status': newStatus});
      printLog.i('Widget $widgetId: Toggle dispositivo -> $newStatus');
    }

    printLog.i('Widget $widgetId: enviando mensaje MQTT: $message');

    // Enviar mensaje MQTT
    sendMessagemqtt(topicRx, message);
    sendMessagemqtt(topicTx, message);

    printLog.i('Widget $widgetId: mensaje MQTT enviado');

    // Actualizar estado optimista: legacy key Y JSON atómico.
    // Kotlin lee el JSON atómico primero; sin esto el widget no refleja el toggle.
    await HomeWidget.saveWidgetData('widget_status_$widgetId', newStatus);
    final toggleJsonStr =
        await HomeWidget.getWidgetData<String>('widget_state_$widgetId');
    if (toggleJsonStr != null && toggleJsonStr.isNotEmpty) {
      try {
        final toggleMap =
            Map<String, dynamic>.from(jsonDecode(toggleJsonStr));
        toggleMap['status'] = newStatus;
        toggleMap['ts'] = DateTime.now().millisecondsSinceEpoch;
        await HomeWidget.saveWidgetData(
            'widget_state_$widgetId', jsonEncode(toggleMap));
      } catch (_) {}
    }

    // Ocultar loading y actualizar widget
    await _hideWidgetLoading(widgetId);

    printLog.i('Widget $widgetId: Toggle completado exitosamente');
  } catch (e) {
    printLog.e('Error en widget toggle: $e');
    // Asegurarse de ocultar loading en caso de error
    await _hideWidgetLoading(widgetId);
  }
}

/// Oculta el indicador de loading del widget
Future<void> _hideWidgetLoading(int widgetId) async {
  await HomeWidget.saveWidgetData('widget_loading_$widgetId', false);
  await updateAllWidgets();
}

/// Actualiza todos los widgets que coincidan con el dispositivo dado
Future<void> updateWidgetsForDevice(
    String pc, String sn, bool isOn, bool isOnline,
    {int? pinIndex}) async {
  try {
    // Obtener todos los widget IDs almacenados
    // home_widget no tiene una API para listar todos los widgets, así que usaremos un enfoque diferente
    // Guardaremos una lista de widget IDs activos

    final widgetIdsJson =
        await HomeWidget.getWidgetData<String>('active_widget_ids');
    if (widgetIdsJson == null || widgetIdsJson.isEmpty) return;

    final List<dynamic> widgetIds = jsonDecode(widgetIdsJson);

    for (var widgetId in widgetIds) {
      final widgetPc =
          await HomeWidget.getWidgetData<String>('widget_pc_$widgetId');
      final widgetSn =
          await HomeWidget.getWidgetData<String>('widget_sn_$widgetId');
      final widgetIsPin =
          await HomeWidget.getWidgetData<bool>('widget_is_pin_$widgetId') ??
              false;
      final widgetPinIndex = await HomeWidget.getWidgetData<String>(
              'widget_pin_index_$widgetId') ??
          '';

      // Verificar si este widget corresponde al dispositivo que cambió
      if (widgetPc == pc && widgetSn == sn) {
        // Si es un dispositivo con pin, verificar que sea el mismo pin
        if (pinIndex != null && widgetIsPin) {
          if (widgetPinIndex != pinIndex.toString()) continue;
        }

        // Actualizar legacy keys
        await HomeWidget.saveWidgetData('widget_status_$widgetId', isOn);
        await HomeWidget.saveWidgetData('widget_online_$widgetId', isOnline);

        // Actualizar JSON atómico: Kotlin lo lee con prioridad sobre legacy keys.
        // Sin esto los cambios de estado por MQTT nunca se reflejan visualmente.
        final atomicStr =
            await HomeWidget.getWidgetData<String>('widget_state_$widgetId');
        if (atomicStr != null && atomicStr.isNotEmpty) {
          try {
            final atomicMap =
                Map<String, dynamic>.from(jsonDecode(atomicStr));
            atomicMap['status'] = isOn;
            atomicMap['online'] = isOnline;
            atomicMap['ts'] = DateTime.now().millisecondsSinceEpoch;
            await HomeWidget.saveWidgetData(
                'widget_state_$widgetId', jsonEncode(atomicMap));
          } catch (_) {}
        }

        printLog
            .i('Widget $widgetId actualizado: isOn=$isOn, isOnline=$isOnline');
      }
    }

    // Actualizar todos los widgets
    await updateAllWidgets();
  } catch (e) {
    printLog.e('Error actualizando widgets: $e');
  }
}

/// Registra un widget ID en la lista de widgets activos
Future<void> registerWidgetId(int widgetId) async {
  try {
    final widgetIdsJson =
        await HomeWidget.getWidgetData<String>('active_widget_ids');
    List<dynamic> widgetIds = [];

    if (widgetIdsJson != null && widgetIdsJson.isNotEmpty) {
      widgetIds = jsonDecode(widgetIdsJson);
    }

    if (!widgetIds.contains(widgetId)) {
      widgetIds.add(widgetId);
      await HomeWidget.saveWidgetData(
          'active_widget_ids', jsonEncode(widgetIds));
      printLog
          .i('Widget $widgetId registrado. Total widgets: ${widgetIds.length}');
    }
  } catch (e) {
    printLog.e('Error registrando widget: $e');
  }
}

/// Elimina un widget ID de la lista de widgets activos
Future<void> unregisterWidgetId(int widgetId) async {
  try {
    final widgetIdsJson =
        await HomeWidget.getWidgetData<String>('active_widget_ids');
    if (widgetIdsJson == null || widgetIdsJson.isEmpty) return;

    List<dynamic> widgetIds = jsonDecode(widgetIdsJson);
    widgetIds.remove(widgetId);

    await HomeWidget.saveWidgetData('active_widget_ids', jsonEncode(widgetIds));
    printLog
        .i('Widget $widgetId eliminado. Total widgets: ${widgetIds.length}');

    // Si no quedan widgets, detener el servicio
    if (widgetIds.isEmpty) {
      await stopWidgetService();
    }
  } catch (e) {
    printLog.e('Error eliminando widget: $e');
  }
}

/// Verifica si hay widgets activos
Future<bool> hasActiveWidgets() async {
  try {
    final widgetIdsJson =
        await HomeWidget.getWidgetData<String>('active_widget_ids');
    if (widgetIdsJson == null || widgetIdsJson.isEmpty) return false;

    final List<dynamic> widgetIds = jsonDecode(widgetIdsJson);
    return widgetIds.isNotEmpty;
  } catch (e) {
    return false;
  }
}

/// Obtiene los topics MQTT que necesitan los widgets activos
Future<Set<String>> getWidgetTopics() async {
  final Set<String> topics = {};

  try {
    final widgetIdsJson =
        await HomeWidget.getWidgetData<String>('active_widget_ids');
    if (widgetIdsJson == null || widgetIdsJson.isEmpty) return topics;

    final List<dynamic> widgetIds = jsonDecode(widgetIdsJson);

    for (var widgetId in widgetIds) {
      final pc = await HomeWidget.getWidgetData<String>('widget_pc_$widgetId');
      final sn = await HomeWidget.getWidgetData<String>('widget_sn_$widgetId');

      if (pc != null && sn != null) {
        topics.add('devices_tx/$pc/$sn');
      }
    }
  } catch (e) {
    printLog.e('Error obteniendo topics de widgets: $e');
  }

  return topics;
}

/// Obtiene el estado real de cada widget desde DynamoDB y actualiza los widgets
/// Esta función se llama al inicializar el servicio para sincronizar el estado real
Future<void> syncWidgetsWithDatabase() async {
  try {
    printLog.i('Sincronizando widgets con base de datos...');

    final widgetIdsJson =
        await HomeWidget.getWidgetData<String>('active_widget_ids');
    if (widgetIdsJson == null || widgetIdsJson.isEmpty) {
      printLog.i('No hay widgets activos para sincronizar');
      return;
    }

    final List<dynamic> widgetIds = jsonDecode(widgetIdsJson);
    printLog.i('Sincronizando ${widgetIds.length} widgets');

    for (var widgetId in widgetIds) {
      try {
        final pc =
            await HomeWidget.getWidgetData<String>('widget_pc_$widgetId');
        final sn =
            await HomeWidget.getWidgetData<String>('widget_sn_$widgetId');
        final isPin =
            await HomeWidget.getWidgetData<bool>('widget_is_pin_$widgetId') ??
                false;
        final pinIndex = await HomeWidget.getWidgetData<String>(
                'widget_pin_index_$widgetId') ??
            '';

        if (pc == null || sn == null) {
          printLog.e('Widget $widgetId: datos incompletos, saltando');
          continue;
        }

        // FIX: Cargar la configuración completa (nickname, tipo, etc.) desde
        // WidgetService para que el JSON atómico tenga TODOS los campos que
        // necesita Kotlin. Sin esto, el JSON solo tiene online/status/alert
        // y Kotlin muestra el estado "sin configurar" por nickname vacío.
        final widgetConfig =
            await WidgetService.loadWidgetConfig(widgetId as int);

        printLog.i('Widget $widgetId: consultando $pc/$sn');

        // Hacer queryItem para obtener el estado real del dispositivo
        await queryItems(pc, sn);

        // Obtener datos del globalDATA que fue actualizado por queryItems
        final deviceData = globalDATA['$pc/$sn'];

        if (deviceData == null) {
          printLog.e('Widget $widgetId: no se encontraron datos para $pc/$sn');
          // Guardar solo online=false pero preservar nickname si existe
          await HomeWidget.saveWidgetData('widget_online_$widgetId', false);
          continue;
        }

        bool isOnline = deviceData['cstate'] ?? false;
        bool isOn = false;
        String? displayTemp;
        bool displayAlert = false;

        // Campos específicos del roller (se rellenan solo para 024011_IOT)
        bool? rollerCalibrated;
        int? rollerPos;
        bool? rollerMovingState;

        if (isPin && pinIndex.isNotEmpty) {
          // Dispositivo con pin (IO)
          final ioData = deviceData['io$pinIndex'];
          if (ioData != null) {
            Map<String, dynamic> ioMap = {};
            if (ioData is String) {
              ioMap = jsonDecode(ioData);
            } else if (ioData is Map) {
              ioMap = Map<String, dynamic>.from(ioData);
            }

            int pinType =
                int.tryParse(ioMap['pinType']?.toString() ?? '0') ?? 0;
            bool wStatus = ioMap['w_status'] ?? false;
            int rState = int.tryParse(ioMap['r_state']?.toString() ?? '0') ?? 0;

            if (pinType == 0) {
              // Salida (control)
              isOn = wStatus;
            } else {
              // Entrada (visualización)
              displayAlert =
                  (wStatus && rState == 0) || (!wStatus && rState == 1);
            }
          }
        } else if (pc == '024011_IOT') {
          // ── Roller ────────────────────────────────────────────────────────
          rollerCalibrated = deviceData['isCalibrated'] ?? false;
          rollerPos = deviceData['actual_position'] ?? -1;
          rollerMovingState = deviceData['moving'] ?? false;
          isOn = (rollerPos != null && rollerPos >= 50);
          printLog.i(
              'Widget $widgetId roller: calibrated=$rollerCalibrated, pos=$rollerPos, moving=$rollerMovingState');
        } else {
          // Dispositivos normales
          if (pc == '023430_IOT') {
            // Termómetro
            displayTemp = deviceData['actualTemp']?.toString();
          } else if (pc == '015773_IOT') {
            // Detector
            int alertValue =
                int.tryParse(deviceData['alert']?.toString() ?? '0') ?? 0;
            displayAlert = alertValue == 1 || deviceData['alert'] == true;
          } else {
            // Otros dispositivos de control
            isOn = deviceData['w_status'] ?? false;
          }
        }

        // FIX: Usar WidgetService.updateWidget para escribir el estado completo
        // (incluyendo nickname, isControl, productCode, ts, etc.) de una sola vez.
        // Antes solo se guardaban las claves individuales online/status/alert,
        // y el JSON atómico quedaba sin nickname → Kotlin mostraba "sin configurar".
        if (widgetConfig != null) {
          final deviceState = WidgetDeviceState(
            online: isOnline,
            status: isOn,
            temperature: displayTemp,
            alert: displayAlert ? true : null,
            isCalibrated: rollerCalibrated,
            rollerPosition: rollerPos,
            isMoving: rollerMovingState,
          );
          await WidgetService.updateWidget(widgetConfig, deviceState);
        } else {
          // Fallback: guardar claves individuales si no hay config
          await HomeWidget.saveWidgetData('widget_online_$widgetId', isOnline);
          await HomeWidget.saveWidgetData('widget_status_$widgetId', isOn);
          if (displayTemp != null) {
            await HomeWidget.saveWidgetData(
                'widget_display_temp_$widgetId', displayTemp);
          }
          await HomeWidget.saveWidgetData(
              'widget_display_alert_$widgetId', displayAlert);
        }

        printLog.i(
            'Widget $widgetId sincronizado: online=$isOnline, status=$isOn, temp=$displayTemp, alert=$displayAlert');
      } catch (e) {
        printLog.e('Error sincronizando widget $widgetId: $e');
      }
    }

    // Actualizar todos los widgets nativos
    // (WidgetService.updateWidget ya llama a updateAllWidgets por cada widget,
    // pero este call final asegura que todos se redibujen si el loop fue rápido)
    await updateAllWidgets();

    printLog.i('Sincronización de widgets completada');
  } catch (e) {
    printLog.e('Error en sincronización de widgets: $e');
  }
}

/// Inicializa el servicio de widgets en background
/// Se llama cuando se crea un widget para asegurar que el servicio de MQTT esté activo
Future<void> initializeWidgetService() async {
  try {
    // Solicitar exclusión de optimización de batería
    if (android) {
      try {
        final status = await Permission.ignoreBatteryOptimizations.status;
        if (!status.isGranted) {
          final completer = Completer<void>();

          showAlertDialog(
            navigatorKey.currentContext!,
            false,
            const Text(
              'Optimización de batería',
              style: TextStyle(color: Color(0xFFFFFFFF)),
            ),
            Text(
              '$appName utiliza un servicio en segundo plano para mantener los widgets actualizados.\n\nPara que funcionen correctamente, es necesario desactivar la optimización de batería.',
              style: const TextStyle(
                color: Color(0xFFFFFFFF),
              ),
            ),
            <Widget>[
              TextButton(
                style: const ButtonStyle(
                  foregroundColor: WidgetStatePropertyAll(Color(0xFFFFFFFF)),
                ),
                child: const Text('Deshabilitar'),
                onPressed: () async {
                  try {
                    await Permission.ignoreBatteryOptimizations.request();
                    printLog.i(
                        'Exclusión de optimización de batería solicitada para widgets');
                    completer.complete();
                    Navigator.of(navigatorKey.currentContext!).pop();
                  } catch (e, s) {
                    printLog.e('Error solicitando exclusión de batería: $e');
                    printLog.t(s);
                    completer.completeError(e);
                  }
                },
              ),
            ],
          );

          await completer.future;
        }
      } catch (e) {
        printLog.e('Error verificando optimización de batería: $e');
      }
    }

    final backService = FlutterBackgroundService();

    // Marcar que el servicio debe iniciarse por widgets
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('widgetServiceEnabled', true);

    // Verificar si el servicio ya está corriendo
    final isRunning = await backService.isRunning();
    if (isRunning) {
      // Notificar que debe suscribirse a widgets y sincronizar
      backService.invoke('subscribeAndSyncWidgets');
      printLog.i(
          'Widget service: Servicio ya corriendo, suscribiendo y sincronizando widgets');
      return;
    }

    // Usar initializeService de master.dart que ya configura el servicio correctamente
    // La función onStart del servicio ya llama a subscribeToWidgetTopics()
    printLog.i('Widget service: Iniciando servicio de background...');

    // Importamos e iniciamos usando la configuración existente de master.dart
    // El servicio ya está configurado para escuchar 'subscribeWidgets'
    await backService.configure(
      iosConfiguration: IosConfiguration(
        autoStart: false,
      ),
      androidConfiguration: AndroidConfiguration(
        notificationChannelId: 'caldenSmart',
        foregroundServiceNotificationId: 888,
        initialNotificationTitle: 'Caldén Smart',
        initialNotificationContent: 'Manteniendo widgets actualizados',
        onStart: onWidgetServiceStart,
        autoStart: false,
        isForegroundMode: true,
        foregroundServiceTypes: [AndroidForegroundType.dataSync],
      ),
    );

    await backService.startService();
    printLog.i('Widget service: Servicio iniciado correctamente');
  } catch (e) {
    printLog.e('Error inicializando widget service: $e');
  }
}

/// Función de inicio del servicio específica para widgets
/// Esta función debe ser top-level (pública) para funcionar como callback del servicio
@pragma('vm:entry-point')
void onWidgetServiceStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  printLog.i('Widget background service: iniciando...');

  // Marcar servicio como NO listo mientras se inicializa
  await setWidgetServiceReady(false);

  // Conectar a MQTT
  final mqttConnected = await setupMqtt();

  if (!mqttConnected) {
    printLog.e('Widget background service: Error conectando a MQTT');
    // Intentar reconectar después de un delay
    await Future.delayed(const Duration(seconds: 5));
    await setupMqtt();
  }

  // Suscribirse a los topics de los widgets
  await subscribeToWidgetTopics();

  // Sincronizar widgets con el estado real desde la base de datos
  await syncWidgetsWithDatabase();

  // Marcar servicio como LISTO
  await setWidgetServiceReady(true);

  printLog.i('Widget background service: MQTT conectado y suscrito - LISTO');

  // Mostrar notificación para que el usuario sepa que el servicio está activo
  // Esto es necesario para servicios en primer plano en Android

  service.on('stopService').listen((event) async {
    await setWidgetServiceReady(false);
    disposeWidgetListener();
    service.stopSelf();
  });

  service.on('subscribeWidgets').listen((event) async {
    printLog.i('Widget service: recibida petición para suscribir widgets');
    await subscribeToWidgetTopics();
  });

  // Listener para suscribir Y sincronizar (cuando se agrega un nuevo widget)
  service.on('subscribeAndSyncWidgets').listen((event) async {
    printLog.i(
        'Widget service: recibida petición para suscribir y sincronizar widgets');
    _isWidgetListenerActive = false; // nuevo widget → forzar re-suscripción
    await subscribeToWidgetTopics();
    await syncWidgetsWithDatabase();
    await setWidgetServiceReady(true);
  });

  // Listener para verificar si quedan widgets activos (llamado cuando se elimina un widget)
  service.on('checkWidgetsAndStop').listen((event) async {
    printLog.i('Widget service: verificando si quedan widgets activos');
    final hasWidgets = await hasActiveWidgets();
    if (!hasWidgets) {
      printLog.i(
          'Widget service: no hay widgets, verificando control por distancia');
      await stopWidgetService();
    } else {
      printLog.i('Widget service: aún hay widgets activos');
    }
  });

  // Mantener el servicio activo con un timer periódico para reconexión MQTT si es necesario
  // Heartbeat cada 5 minutos para mejor disponibilidad del servicio
  Timer.periodic(const Duration(minutes: 5), (timer) async {
    try {
      if (mqttAWSFlutterClient == null ||
          mqttAWSFlutterClient!.connectionStatus?.state !=
              MqttConnectionState.connected) {
        printLog.i('Widget service: MQTT desconectado, reconectando...');
        await setWidgetServiceReady(false);

        final reconnected = await setupMqtt();
        if (reconnected) {
          // Resetear flag: el cliente MQTT es nuevo y necesita re-suscribirse.
          // Sin esto subscribeToWidgetTopics() retorna inmediatamente y no
          // recibe mensajes del nuevo cliente.
          _isWidgetListenerActive = false;
          await subscribeToWidgetTopics();
          await syncWidgetsWithDatabase();
          await setWidgetServiceReady(true);
          printLog.i('Widget service: Reconexión exitosa');
        } else {
          printLog.e('Widget service: Falló reconexión, reintentando en 30s');
          await Future.delayed(const Duration(seconds: 30));
          final retry = await setupMqtt();
          if (retry) {
            _isWidgetListenerActive = false;
            await subscribeToWidgetTopics();
            await syncWidgetsWithDatabase();
            await setWidgetServiceReady(true);
          }
        }
      }
    } catch (e) {
      printLog.e('Error en heartbeat del servicio: $e');
    }
  });
}

/// Detiene el servicio de widgets si no hay más widgets activos
/// Verifica si hay equipos de control por distancia antes de detener
Future<void> stopWidgetService() async {
  try {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('widgetServiceEnabled', false);

    // Verificar si hay equipos de control por distancia activos
    String currentUserEmail = await loadEmail();
    List<String> deviceControl = [];

    try {
      deviceControl = await getDevicesInDistanceControl(currentUserEmail);
    } catch (e) {
      printLog.e('Error obteniendo dispositivos de control por distancia: $e');
    }

    // Solo detener si no hay control por distancia activo
    if (deviceControl.isEmpty) {
      final backService = FlutterBackgroundService();
      final isRunning = await backService.isRunning();
      if (isRunning) {
        backService.invoke('stopService');
        printLog.i(
            'Widget service: detenido (no hay widgets ni control por distancia)');
      }
    } else {
      printLog.i(
          'Widget service: NO se detiene porque hay ${deviceControl.length} equipos con control por distancia');
    }
  } catch (e) {
    printLog.e('Error deteniendo widget service: $e');
  }
}

/// Suscribe a los topics MQTT necesarios para los widgets
/// Esta función se llama desde el servicio de background
Future<void> subscribeToWidgetTopics() async {
  if (_isWidgetListenerActive) return;

  try {
    final topics = await getWidgetTopics();
    if (topics.isEmpty) return;

    // Asegurar conexión MQTT
    if (mqttAWSFlutterClient == null ||
        mqttAWSFlutterClient!.connectionStatus?.state !=
            MqttConnectionState.connected) {
      printLog.i('Widget MQTT: Conectando...');
      final connected = await setupMqtt();
      if (!connected) {
        printLog.e('Widget MQTT: No se pudo conectar');
        return;
      }
    }

    // Suscribirse a cada topic
    for (var topic in topics) {
      printLog.i('Widget MQTT: Suscribiendo a $topic');
      mqttAWSFlutterClient!.subscribe(topic, MqttQos.atMostOnce);
    }

    // Escuchar mensajes para widgets (versión background-safe)
    _widgetMqttSubscription?.cancel();
    _widgetMqttSubscription = mqttAWSFlutterClient!.updates!.listen((c) {
      _handleWidgetMqttMessage(c);
    });

    _isWidgetListenerActive = true;
    printLog.i('Widget MQTT: Listener activo para ${topics.length} topics');
  } catch (e) {
    printLog.e('Error suscribiendo a topics de widgets: $e');
  }
}

/// Maneja los mensajes MQTT para actualizar widgets (versión background-safe)
void _handleWidgetMqttMessage(
    List<MqttReceivedMessage<MqttMessage>> messages) async {
  try {
    final MqttPublishMessage recMess =
        messages[0].payload as MqttPublishMessage;
    final String topic = messages[0].topic;
    final parts = topic.split('/');

    if (parts.length < 3) return;

    final String pc = parts[1];
    final String sn = parts[2];

    final List<int> messageBytes = recMess.payload.message;
    final String messageString = utf8.decode(messageBytes);

    try {
      final Map<String, dynamic> messageMap = json.decode(messageString) ?? {};

      // Detectar si es un dispositivo con pin (IO)
      bool specialDevice = messageMap.keys.contains('index') &&
          !messageMap.keys.contains('cstate');

      if (specialDevice) {
        int index = messageMap['index'];
        int pinType = messageMap['pinType'] ?? 0;
        bool wStatus = messageMap['w_status'] ?? false;
        int rState = int.tryParse(messageMap['r_state'].toString()) ?? 0;

        if (pinType == 0) {
          // Salida (control) - actualizar estado on/off
          updateWidgetsForDevice(pc, sn, wStatus, true, pinIndex: index);
        } else {
          // Entrada (visualización) - calcular estado de alerta
          // Alerta si: (w_status == true && r_state == 0) || (w_status == false && r_state == 1)
          bool isAlert = (wStatus && rState == 0) || (!wStatus && rState == 1);
          updateWidgetsForDeviceDisplay(pc, sn, true,
              pinIndex: index, displayAlert: isAlert);
        }
      } else {
        // Dispositivos normales
        if (messageMap.containsKey('actualTemp')) {
          // Termómetro
          String temp = messageMap['actualTemp'].toString();
          updateWidgetsForDeviceDisplay(pc, sn, true, displayTemp: temp);
        } else if (messageMap.containsKey('alert')) {
          // Detector 015773_IOT
          // alert viene como 0 o 1 en el mapa
          int alertValue = int.tryParse(messageMap['alert'].toString()) ?? 0;
          bool alert = alertValue == 1;
          updateWidgetsForDeviceDisplay(pc, sn, true, displayAlert: alert);
        } else if (messageMap.containsKey('w_status') ||
            messageMap.containsKey('cstate')) {
          bool isOn = messageMap['w_status'] ?? false;
          bool isOnline = messageMap['cstate'] ?? true;
          updateWidgetsForDevice(pc, sn, isOn, isOnline);
        }
      }

      // ── Roller MQTT ──────────────────────────────────────────────────────────
      // El device manda 'is_calibrated' (snake_case), no 'isCalibrated'.
      final bool isRollerMessage = messageMap.containsKey('actual_position') ||
          messageMap.containsKey('isCalibrated') ||
          messageMap.containsKey('is_calibrated') ||
          messageMap.containsKey('moving');

      if (isRollerMessage) {
        // BUG FIX: usar active_widget_ids (HomeWidget SharedPrefs, siempre fresco)
        // en vez de WidgetService.getWidgetIds() (SharedPreferences normal con caché
        // por isolate → en el background service puede estar vacío).
        final rollerWidgetIdsJson =
            await HomeWidget.getWidgetData<String>('active_widget_ids');
        if (rollerWidgetIdsJson != null && rollerWidgetIdsJson.isNotEmpty) {
          final List<dynamic> rollerWidgetIds = jsonDecode(rollerWidgetIdsJson);
          for (final wid in rollerWidgetIds) {
            final wpc =
                await HomeWidget.getWidgetData<String>('widget_pc_$wid');
            final wsn =
                await HomeWidget.getWidgetData<String>('widget_sn_$wid');
            if (wpc == pc && wsn == sn) {
              final jsonStr =
                  await HomeWidget.getWidgetData<String>('widget_state_$wid');
              if (jsonStr != null && jsonStr.isNotEmpty) {
                try {
                  final map = Map<String, dynamic>.from(jsonDecode(jsonStr));
                  if (messageMap.containsKey('actual_position')) {
                    final int pos =
                        messageMap['actual_position'] as int? ?? -1;
                    final int prevPos = map['rollerPosition'] as int? ?? -1;
                    map['rollerPosition'] = pos;
                    map['status'] = pos >= 50;
                    // Calcular dirección comparando posición anterior vs actual
                    // pos 0 = abierto (arriba), pos 100 = cerrado (abajo)
                    // pos disminuye → está subiendo (abriendo) ↑
                    // pos aumenta  → está bajando (cerrando) ↓
                    if (pos >= 0 && prevPos >= 0 && pos != prevPos) {
                      map['rollerDirection'] = pos < prevPos ? 1 : -1;
                    }
                    printLog.i(
                        'Roller widget $wid: actual_position=$pos, status=${pos >= 50}');
                  }
                  // El device manda 'is_calibrated' (snake_case)
                  if (messageMap.containsKey('is_calibrated') ||
                      messageMap.containsKey('isCalibrated')) {
                    final calibrated = messageMap['is_calibrated'] ??
                        messageMap['isCalibrated'];
                    map['isCalibrated'] = calibrated == true;
                  }
                  if (messageMap.containsKey('moving')) {
                    map['isMoving'] = messageMap['moving'] == true;
                    printLog.i(
                        'Roller widget $wid: moving=${messageMap['moving']}');
                  }
                  map['ts'] = DateTime.now().millisecondsSinceEpoch;
                  await HomeWidget.saveWidgetData(
                      'widget_state_$wid', jsonEncode(map));
                } catch (e) {
                  printLog.e('Roller widget $wid: error actualizando JSON: $e');
                }
              }
            }
          }
        }
        await updateAllWidgets();
        return;
      }

      printLog.i('Widget MQTT: Procesado mensaje de $pc/$sn');
    } catch (e) {
      printLog.e('Widget MQTT: Error decodificando mensaje: $e');
    }
  } catch (e) {
    printLog.e('Widget MQTT: Error procesando mensaje: $e');
  }
}

/// Actualiza widgets de visualización (solo lectura)
Future<void> updateWidgetsForDeviceDisplay(String pc, String sn, bool isOnline,
    {int? pinIndex, String? displayTemp, bool? displayAlert}) async {
  try {
    final widgetIdsJson =
        await HomeWidget.getWidgetData<String>('active_widget_ids');
    if (widgetIdsJson == null || widgetIdsJson.isEmpty) return;

    final List<dynamic> widgetIds = jsonDecode(widgetIdsJson);

    for (var widgetId in widgetIds) {
      final widgetPc =
          await HomeWidget.getWidgetData<String>('widget_pc_$widgetId');
      final widgetSn =
          await HomeWidget.getWidgetData<String>('widget_sn_$widgetId');
      final widgetIsPin =
          await HomeWidget.getWidgetData<bool>('widget_is_pin_$widgetId') ??
              false;
      final widgetPinIndex = await HomeWidget.getWidgetData<String>(
              'widget_pin_index_$widgetId') ??
          '';
      final isControl =
          await HomeWidget.getWidgetData<bool>('widget_is_control_$widgetId') ??
              false;

      // Solo actualizar widgets de visualización
      if (isControl) continue;

      // Verificar si este widget corresponde al dispositivo que cambió
      if (widgetPc == pc && widgetSn == sn) {
        // Si es un dispositivo con pin, verificar que sea el mismo pin
        if (pinIndex != null && widgetIsPin) {
          if (widgetPinIndex != pinIndex.toString()) continue;
        }

        // Actualizar datos de visualización (legacy keys)
        await HomeWidget.saveWidgetData('widget_online_$widgetId', isOnline);

        if (displayTemp != null) {
          await HomeWidget.saveWidgetData(
              'widget_display_temp_$widgetId', displayTemp);
        }

        if (displayAlert != null) {
          await HomeWidget.saveWidgetData(
              'widget_display_alert_$widgetId', displayAlert);
        }

        // Actualizar JSON atómico: Kotlin lo lee con prioridad sobre legacy keys.
        final dispAtomicStr =
            await HomeWidget.getWidgetData<String>('widget_state_$widgetId');
        if (dispAtomicStr != null && dispAtomicStr.isNotEmpty) {
          try {
            final dispMap =
                Map<String, dynamic>.from(jsonDecode(dispAtomicStr));
            dispMap['online'] = isOnline;
            if (displayTemp != null) dispMap['displayTemp'] = displayTemp;
            if (displayAlert != null) dispMap['displayAlert'] = displayAlert;
            dispMap['ts'] = DateTime.now().millisecondsSinceEpoch;
            await HomeWidget.saveWidgetData(
                'widget_state_$widgetId', jsonEncode(dispMap));
          } catch (_) {}
        }

        printLog.i(
            'Widget visualización $widgetId actualizado: temp=$displayTemp, alert=$displayAlert');
      }
    }

    // Actualizar todos los widgets
    await updateAllWidgets();
  } catch (e) {
    printLog.e('Error actualizando widgets de visualización: $e');
  }
}

/// Limpia los recursos del listener de widgets
void disposeWidgetListener() {
  _widgetMqttSubscription?.cancel();
  _widgetMqttSubscription = null;
  _isWidgetListenerActive = false;
}

/// Verifica si se puede detener el servicio de background
/// Retorna true si no hay widgets activos Y no hay equipos de control por distancia
/// Esta función debe usarse desde los dispositivos antes de detener el servicio
Future<bool> canStopBackgroundService() async {
  try {
    // Verificar widgets activos
    bool widgetsActive = await hasActiveWidgets();

    if (widgetsActive) {
      printLog.i('No se puede detener el servicio: hay widgets activos');
      return false;
    }

    // Verificar control por distancia
    String currentUserEmail = await loadEmail();
    List<String> deviceControl =
        await getDevicesInDistanceControl(currentUserEmail);

    if (deviceControl.isNotEmpty) {
      printLog.i(
          'No se puede detener el servicio: hay ${deviceControl.length} equipos con control por distancia');
      return false;
    }

    printLog.i(
        'Se puede detener el servicio: no hay widgets ni control por distancia');
    return true;
  } catch (e) {
    printLog.e('Error verificando si se puede detener el servicio: $e');
    // En caso de error, es más seguro no detener el servicio
    return false;
  }
}

/// Intenta detener el servicio de background si no hay widgets ni control por distancia activos
/// Esta función debe llamarse cuando se cancela el control por distancia
Future<void> tryStopBackgroundService() async {
  try {
    bool canStop = await canStopBackgroundService();

    if (canStop) {
      final backService = FlutterBackgroundService();
      final isRunning = await backService.isRunning();
      if (isRunning) {
        backService.invoke('stopService');
        printLog.i('Servicio de background detenido');
      }
    }
  } catch (e) {
    printLog.e('Error intentando detener el servicio: $e');
  }
}