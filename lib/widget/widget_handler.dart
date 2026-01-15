import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:home_widget/home_widget.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:caldensmart/aws/mqtt/mqtt.dart';
import 'package:caldensmart/aws/dynamo/dynamo.dart';
import 'package:caldensmart/Global/stored_data.dart';
import 'package:caldensmart/logger.dart';

/// Stream subscription para mensajes MQTT de widgets
StreamSubscription? _widgetMqttSubscription;

/// Flag para evitar múltiples suscripciones
bool _isWidgetListenerActive = false;

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

  // Verificar que sea una acción de toggle
  if (uri.host == 'widget' && uri.path == '/toggle') {
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
  } else {
    printLog.i(
        'Widget callback: URI no coincide con toggle (host=${uri.host}, path=${uri.path})');
  }
}

/// Maneja el toggle de un widget específico
Future<void> _handleWidgetToggle(int widgetId) async {
  try {
    printLog.i('=== INICIO _handleWidgetToggle para widget $widgetId ===');

    // Mostrar loading inmediatamente
    await HomeWidget.saveWidgetData('widget_loading_$widgetId', true);
    await HomeWidget.updateWidget(
      qualifiedAndroidName: 'com.caldensmart.sime.widget.ControlWidgetProvider',
    );

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

    // Actualizar estado en SharedPreferences para refrescar el widget
    await HomeWidget.saveWidgetData('widget_status_$widgetId', newStatus);

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
  await HomeWidget.updateWidget(
    qualifiedAndroidName: 'com.caldensmart.sime.widget.ControlWidgetProvider',
  );
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

        // Actualizar el estado del widget
        await HomeWidget.saveWidgetData('widget_status_$widgetId', isOn);
        await HomeWidget.saveWidgetData('widget_online_$widgetId', isOnline);

        printLog
            .i('Widget $widgetId actualizado: isOn=$isOn, isOnline=$isOnline');
      }
    }

    // Actualizar todos los widgets
    await HomeWidget.updateWidget(
      qualifiedAndroidName: 'com.caldensmart.sime.widget.ControlWidgetProvider',
    );
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

/// Inicializa el servicio de widgets en background
/// Se llama cuando se crea un widget para asegurar que el servicio de MQTT esté activo
Future<void> initializeWidgetService() async {
  try {
    final backService = FlutterBackgroundService();

    // Marcar que el servicio debe iniciarse por widgets
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('widgetServiceEnabled', true);

    // Verificar si el servicio ya está corriendo
    final isRunning = await backService.isRunning();
    if (isRunning) {
      // Solo notificar que debe suscribirse a widgets
      backService.invoke('subscribeWidgets');
      printLog
          .i('Widget service: Servicio ya corriendo, suscribiendo a widgets');
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

  // Conectar a MQTT
  await setupMqtt();

  // Suscribirse a los topics de los widgets
  await subscribeToWidgetTopics();

  printLog.i('Widget background service: MQTT conectado y suscrito');

  // Mostrar notificación para que el usuario sepa que el servicio está activo
  // Esto es necesario para servicios en primer plano en Android

  service.on('stopService').listen((event) {
    disposeWidgetListener();
    service.stopSelf();
  });

  service.on('subscribeWidgets').listen((event) async {
    printLog.i('Widget service: recibida petición para suscribir widgets');
    await subscribeToWidgetTopics();
  });

  // Mantener el servicio activo con un timer periódico para reconexión MQTT si es necesario
  Timer.periodic(const Duration(minutes: 5), (timer) async {
    if (mqttAWSFlutterClient == null ||
        mqttAWSFlutterClient!.connectionStatus?.state !=
            MqttConnectionState.connected) {
      printLog.i('Widget service: Reconectando a MQTT...');
      await setupMqtt();
      await subscribeToWidgetTopics();
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

        // Actualizar datos de visualización
        await HomeWidget.saveWidgetData('widget_online_$widgetId', isOnline);

        if (displayTemp != null) {
          await HomeWidget.saveWidgetData(
              'widget_display_temp_$widgetId', displayTemp);
        }

        if (displayAlert != null) {
          await HomeWidget.saveWidgetData(
              'widget_display_alert_$widgetId', displayAlert);
        }

        printLog.i(
            'Widget visualización $widgetId actualizado: temp=$displayTemp, alert=$displayAlert');
      }
    }

    // Actualizar todos los widgets
    await HomeWidget.updateWidget(
      qualifiedAndroidName: 'com.caldensmart.sime.widget.ControlWidgetProvider',
    );
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
