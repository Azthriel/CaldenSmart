import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:ui';
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
bool _isServiceReady = false;

/// Verifica si el servicio está listo para procesar interacciones de widgets
Future<bool> isWidgetServiceReady() async {
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

    await HomeWidget.saveWidgetData('widget_service_ready', ready);
    await updateAllWidgets();

    printLog.i('Widget service ready: $ready');
  } catch (e) {
    printLog.e('Error setting widget service ready: $e');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers para guardado atómico del estado del widget
// FIX: En lugar de N awaits secuenciales (que crean race conditions cuando
//      ControlWidgetProvider lee en medio de las escrituras), guardamos todo
//      el estado en UN ÚNICO JSON bajo la clave widget_state_<id>.
// ─────────────────────────────────────────────────────────────────────────────

/// Lee el mapa de estado actual para un widget (o {} si no existe)
Future<Map<String, dynamic>> _readWidgetState(dynamic widgetId) async {
  final existing =
      await HomeWidget.getWidgetData<String>('widget_state_$widgetId');
  if (existing == null || existing.isEmpty) return {};
  try {
    return Map<String, dynamic>.from(jsonDecode(existing));
  } catch (_) {
    return {};
  }
}

/// Escribe atómicamente varios campos del estado del widget.
/// Siempre actualiza el timestamp para que ControlWidgetProvider sepa
/// cuándo fue la última actualización real.
Future<void> _writeWidgetState(
    dynamic widgetId, Map<String, dynamic> fields) async {
  final state = await _readWidgetState(widgetId);
  state.addAll(fields);
  state['ts'] = DateTime.now().millisecondsSinceEpoch;
  await HomeWidget.saveWidgetData('widget_state_$widgetId', jsonEncode(state));
}

// ─────────────────────────────────────────────────────────────────────────────

/// Callback que se ejecuta cuando el widget es presionado en background.
/// Esta función debe ser top-level (no dentro de una clase).
@pragma('vm:entry-point')
Future<void> backgroundCallback(Uri? uri) async {
  WidgetsFlutterBinding.ensureInitialized();

  printLog.i('Widget background callback: $uri');

  if (uri == null) {
    printLog.e('Widget callback: URI es null');
    return;
  }

  printLog.i('URI scheme: ${uri.scheme}, host: ${uri.host}, path: ${uri.path}');

  if (uri.host == 'widget') {
    if (uri.path == '/toggle') {
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
    } else if (uri.path == '/update') {
      // FIX: WorkManager dispara este intent para que el isolate de Dart
      //      sincronice el estado real desde la base de datos y actualice
      //      los widgets. Esto resuelve el caso donde el background service
      //      fue matado y los datos en SharedPrefs quedaron obsoletos.
      printLog.i('Widget callback: sincronizando datos desde WorkManager');
      try {
        await syncWidgetsWithDatabase();
        printLog.i('Widget callback: sincronización completada');
      } catch (e) {
        printLog.e('Widget callback: error en sincronización: $e');
      }
    } else if (uri.path == '/checkAndStop') {
      printLog.i(
          'Widget callback: verificando widgets y deteniendo servicio si es necesario');
      await _handleCheckAndStopService();
    } else {
      printLog.i(
          'Widget callback: URI no coincide con ninguna acción conocida (path=${uri.path})');
    }
  } else {
    printLog
        .i('Widget callback: URI no coincide con widget (host=${uri.host})');
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

    final isReady = await isWidgetServiceReady();
    if (!isReady) {
      printLog.i('Widget $widgetId: Servicio no está listo, ignorando toggle');
      await _writeWidgetState(widgetId, {'initializing': true});
      await updateAllWidgets();

      await Future.delayed(const Duration(seconds: 2));
      await _writeWidgetState(widgetId, {'initializing': false});
      await updateAllWidgets();
      return;
    }

    // Mostrar loading inmediatamente (atómico)
    await _writeWidgetState(widgetId, {'loading': true});
    await updateAllWidgets();

    // Las claves de configuración (pc, sn, isPin, pinIndex, isControl) se leen
    // individualmente porque son escritas en tiempo de configuración y no tienen
    // el problema de race condition (no cambian mientras el widget existe).
    final pc = await HomeWidget.getWidgetData<String>('widget_pc_$widgetId');
    final sn = await HomeWidget.getWidgetData<String>('widget_sn_$widgetId');
    final isPin =
        await HomeWidget.getWidgetData<bool>('widget_is_pin_$widgetId') ??
            false;
    final pinIndex =
        await HomeWidget.getWidgetData<String>('widget_pin_index_$widgetId') ??
            '';
    final isControl =
        await HomeWidget.getWidgetData<bool>('widget_is_control_$widgetId') ??
            false;

    // FIX: Leer el status actual desde el JSON atómico primero; si no existe,
    //      fallback a la clave individual (backward compat).
    bool currentStatus = false;
    final stateJson =
        await HomeWidget.getWidgetData<String>('widget_state_$widgetId');
    if (stateJson != null && stateJson.isNotEmpty) {
      try {
        final stateMap = jsonDecode(stateJson) as Map<String, dynamic>;
        currentStatus = stateMap['status'] as bool? ?? false;
      } catch (_) {
        currentStatus =
            await HomeWidget.getWidgetData<bool>('widget_status_$widgetId') ??
                false;
      }
    } else {
      currentStatus =
          await HomeWidget.getWidgetData<bool>('widget_status_$widgetId') ??
              false;
    }

    printLog.i(
        'Widget $widgetId datos: pc=$pc, sn=$sn, isPin=$isPin, pinIndex=$pinIndex, '
        'currentStatus=$currentStatus, isControl=$isControl');

    if (pc == null || sn == null) {
      printLog.e('Widget $widgetId: datos incompletos (pc=$pc, sn=$sn)');
      await _hideWidgetLoading(widgetId);
      return;
    }

    if (!isControl) {
      printLog.i('Widget $widgetId: no es un dispositivo de control, saliendo');
      await _hideWidgetLoading(widgetId);
      return;
    }

    final newStatus = !currentStatus;
    printLog.i('Widget $widgetId: toggle de $currentStatus -> $newStatus');

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

    final topicRx = 'devices_rx/$pc/$sn';
    final topicTx = 'devices_tx/$pc/$sn';
    printLog.i('Widget $widgetId: topics - rx=$topicRx, tx=$topicTx');

    String message;
    if (isPin && pinIndex.isNotEmpty) {
      final index = int.tryParse(pinIndex) ?? 0;
      message = jsonEncode({
        'pinType': 0,
        'index': index,
        'w_status': newStatus,
        'r_state': '0',
      });
      printLog.i('Widget $widgetId: Toggle pin $index -> $newStatus');
    } else {
      message = jsonEncode({'w_status': newStatus});
      printLog.i('Widget $widgetId: Toggle dispositivo -> $newStatus');
    }

    printLog.i('Widget $widgetId: enviando mensaje MQTT: $message');
    sendMessagemqtt(topicRx, message);
    sendMessagemqtt(topicTx, message);
    printLog.i('Widget $widgetId: mensaje MQTT enviado');

    // FIX: Actualizar el estado atómicamente (status + ts en una sola escritura)
    await _writeWidgetState(widgetId, {
      'status': newStatus,
      'loading': false,
    });
    // Mantener clave individual para backward compat
    await HomeWidget.saveWidgetData('widget_status_$widgetId', newStatus);

    await updateAllWidgets();
    printLog.i('Widget $widgetId: Toggle completado exitosamente');
  } catch (e) {
    printLog.e('Error en widget toggle: $e');
    await _hideWidgetLoading(widgetId);
  }
}

/// Oculta el indicador de loading del widget (atómico)
Future<void> _hideWidgetLoading(int widgetId) async {
  await _writeWidgetState(widgetId, {'loading': false, 'initializing': false});
  await updateAllWidgets();
}

/// Actualiza todos los widgets que coincidan con el dispositivo dado
Future<void> updateWidgetsForDevice(
    String pc, String sn, bool isOn, bool isOnline,
    {int? pinIndex}) async {
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

      if (widgetPc == pc && widgetSn == sn) {
        if (pinIndex != null && widgetIsPin) {
          if (widgetPinIndex != pinIndex.toString()) continue;
        }

        // FIX: escritura atómica → una sola operación en SharedPrefs
        await _writeWidgetState(widgetId, {
          'status': isOn,
          'online': isOnline,
        });
        // Backward compat para _handleWidgetToggle
        await HomeWidget.saveWidgetData('widget_status_$widgetId', isOn);

        printLog
            .i('Widget $widgetId actualizado: isOn=$isOn, isOnline=$isOnline');
      }
    }

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

/// Obtiene el estado real de cada widget desde DynamoDB y actualiza los widgets.
/// Es llamada al inicializar el servicio para sincronizar el estado real,
/// y también desde backgroundCallback cuando WorkManager dispara /update.
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

        printLog.i('Widget $widgetId: consultando $pc/$sn');

        await queryItems(pc, sn);

        final deviceData = globalDATA['$pc/$sn'];

        if (deviceData == null) {
          printLog.e('Widget $widgetId: no se encontraron datos para $pc/$sn');
          // FIX: escritura atómica incluso para el caso de error
          await _writeWidgetState(widgetId, {'online': false});
          continue;
        }

        bool isOnline = deviceData['cstate'] ?? false;
        bool isOn = false;
        String? displayTemp;
        bool displayAlert = false;

        if (isPin && pinIndex.isNotEmpty) {
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
              isOn = wStatus;
            } else {
              displayAlert =
                  (wStatus && rState == 0) || (!wStatus && rState == 1);
            }
          }
        } else {
          if (pc == '023430_IOT') {
            displayTemp = deviceData['actualTemp']?.toString();
          } else if (pc == '015773_IOT') {
            int alertValue =
                int.tryParse(deviceData['alert']?.toString() ?? '0') ?? 0;
            displayAlert = alertValue == 1 || deviceData['alert'] == true;
          } else {
            isOn = deviceData['w_status'] ?? false;
          }
        }

        // FIX: todos los campos en una única escritura atómica con timestamp
        final fieldsToWrite = <String, dynamic>{
          'online': isOnline,
          'status': isOn,
          'displayAlert': displayAlert,
        };
        if (displayTemp != null) fieldsToWrite['displayTemp'] = displayTemp;

        await _writeWidgetState(widgetId, fieldsToWrite);
        // Backward compat
        await HomeWidget.saveWidgetData('widget_status_$widgetId', isOn);

        printLog
            .i('Widget $widgetId sincronizado: online=$isOnline, status=$isOn, '
                'temp=$displayTemp, alert=$displayAlert');
      } catch (e) {
        printLog.e('Error sincronizando widget $widgetId: $e');
      }
    }

    await updateAllWidgets();
    printLog.i('Sincronización de widgets completada');
  } catch (e) {
    printLog.e('Error en sincronización de widgets: $e');
  }
}

/// Inicializa el servicio de widgets en background
Future<void> initializeWidgetService() async {
  try {
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

    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('widgetServiceEnabled', true);

    final isRunning = await backService.isRunning();
    if (isRunning) {
      backService.invoke('subscribeAndSyncWidgets');
      printLog.i(
          'Widget service: Servicio ya corriendo, suscribiendo y sincronizando widgets');
      return;
    }

    printLog.i('Widget service: Iniciando servicio de background...');

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
@pragma('vm:entry-point')
void onWidgetServiceStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  printLog.i('Widget background service: iniciando...');

  await setWidgetServiceReady(false);

  final mqttConnected = await setupMqtt();

  if (!mqttConnected) {
    printLog.e('Widget background service: Error conectando a MQTT');
    await Future.delayed(const Duration(seconds: 5));
    await setupMqtt();
  }

  await subscribeToWidgetTopics();
  await syncWidgetsWithDatabase();
  await setWidgetServiceReady(true);

  printLog.i('Widget background service: MQTT conectado y suscrito - LISTO');

  service.on('stopService').listen((event) async {
    await setWidgetServiceReady(false);
    disposeWidgetListener();
    service.stopSelf();
  });

  service.on('subscribeWidgets').listen((event) async {
    printLog.i('Widget service: recibida petición para suscribir widgets');
    await subscribeToWidgetTopics();
  });

  service.on('subscribeAndSyncWidgets').listen((event) async {
    printLog.i(
        'Widget service: recibida petición para suscribir y sincronizar widgets');
    await subscribeToWidgetTopics();
    await syncWidgetsWithDatabase();
  });

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

  // Heartbeat cada 5 minutos para reconexión MQTT si es necesario
  Timer.periodic(const Duration(minutes: 5), (timer) async {
    try {
      if (mqttAWSFlutterClient == null ||
          mqttAWSFlutterClient!.connectionStatus?.state !=
              MqttConnectionState.connected) {
        printLog.i('Widget service: MQTT desconectado, reconectando...');
        await setWidgetServiceReady(false);

        final reconnected = await setupMqtt();
        if (reconnected) {
          await subscribeToWidgetTopics();
          await syncWidgetsWithDatabase();
          await setWidgetServiceReady(true);
          printLog.i('Widget service: Reconexión exitosa');
        } else {
          printLog.e('Widget service: Falló reconexión, reintentando en 30s');
          await Future.delayed(const Duration(seconds: 30));
          final retry = await setupMqtt();
          if (retry) {
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
Future<void> stopWidgetService() async {
  try {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('widgetServiceEnabled', false);

    String currentUserEmail = await loadEmail();
    List<String> deviceControl = [];

    try {
      deviceControl = await getDevicesInDistanceControl(currentUserEmail);
    } catch (e) {
      printLog.e('Error obteniendo dispositivos de control por distancia: $e');
    }

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
Future<void> subscribeToWidgetTopics() async {
  if (_isWidgetListenerActive) return;

  try {
    final topics = await getWidgetTopics();

    if (topics.isEmpty) return;

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

    for (var topic in topics) {
      printLog.i('Widget MQTT: Suscribiendo a $topic');
      mqttAWSFlutterClient!.subscribe(topic, MqttQos.atMostOnce);
    }

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
void _handleWidgetMqttMessage(List<MqttReceivedMessage<MqttMessage>> messages) {
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

      bool specialDevice = messageMap.keys.contains('index') &&
          !messageMap.keys.contains('cstate');

      if (specialDevice) {
        int index = messageMap['index'];
        int pinType = messageMap['pinType'] ?? 0;
        bool wStatus = messageMap['w_status'] ?? false;
        int rState = int.tryParse(messageMap['r_state'].toString()) ?? 0;

        if (pinType == 0) {
          updateWidgetsForDevice(pc, sn, wStatus, true, pinIndex: index);
        } else {
          bool isAlert = (wStatus && rState == 0) || (!wStatus && rState == 1);
          updateWidgetsForDeviceDisplay(pc, sn, true,
              pinIndex: index, displayAlert: isAlert);
        }
      } else {
        if (messageMap.containsKey('actualTemp')) {
          String temp = messageMap['actualTemp'].toString();
          updateWidgetsForDeviceDisplay(pc, sn, true, displayTemp: temp);
        } else if (messageMap.containsKey('alert')) {
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

      if (isControl) continue;

      if (widgetPc == pc && widgetSn == sn) {
        if (pinIndex != null && widgetIsPin) {
          if (widgetPinIndex != pinIndex.toString()) continue;
        }

        // FIX: escritura atómica
        final fields = <String, dynamic>{'online': isOnline};
        if (displayTemp != null) fields['displayTemp'] = displayTemp;
        if (displayAlert != null) fields['displayAlert'] = displayAlert;
        await _writeWidgetState(widgetId, fields);

        printLog.i(
            'Widget visualización $widgetId actualizado: temp=$displayTemp, alert=$displayAlert');
      }
    }

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
Future<bool> canStopBackgroundService() async {
  try {
    bool widgetsActive = await hasActiveWidgets();

    if (widgetsActive) {
      printLog.i('No se puede detener el servicio: hay widgets activos');
      return false;
    }

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
    return false;
  }
}

/// Intenta detener el servicio de background si no hay widgets ni control por distancia activos
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
