import 'dart:convert';
import 'dart:io' show Platform;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:home_widget/home_widget.dart';
import 'package:caldensmart/master.dart';
import 'package:caldensmart/logger.dart';
import 'widget_models.dart';

/// Constantes para widgets iOS
const String _iOSWidgetName = 'ControlWidget';
const String _androidWidgetName = 'com.caldensmart.sime.widget.ControlWidgetProvider';

/// Servicio para gestionar widgets de la app
class WidgetService {
  static const String _widgetConfigPrefix = 'CSWidgetConfig_';
  static const String _widgetListKey = 'CSWidgetList';

  /// Helper para actualizar widgets en ambas plataformas
  static Future<void> _updatePlatformWidgets() async {
    if (Platform.isAndroid) {
      await HomeWidget.updateWidget(
        qualifiedAndroidName: _androidWidgetName,
      );
    } else if (Platform.isIOS) {
      await HomeWidget.updateWidget(
        iOSName: _iOSWidgetName,
      );
    }
  }

  /// Guardar configuración de un widget
  static Future<void> saveWidgetConfig(WidgetData widgetData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_widgetConfigPrefix${widgetData.widgetId}';
      await prefs.setString(key, widgetData.toJsonString());

      // Agregar a la lista de widgets
      List<int> widgetIds = await getWidgetIds();
      if (!widgetIds.contains(widgetData.widgetId)) {
        widgetIds.add(widgetData.widgetId);
        await prefs.setStringList(
            _widgetListKey, widgetIds.map((e) => e.toString()).toList());
      }

      printLog.i('Widget ${widgetData.widgetId} configurado correctamente');
    } catch (e) {
      printLog.e('Error guardando configuración de widget: $e');
    }
  }

  /// Cargar configuración de un widget
  static Future<WidgetData?> loadWidgetConfig(int widgetId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_widgetConfigPrefix$widgetId';
      final jsonString = prefs.getString(key);

      if (jsonString != null) {
        return WidgetData.fromJsonString(jsonString);
      }
      return null;
    } catch (e) {
      printLog.e('Error cargando configuración de widget: $e');
      return null;
    }
  }

  /// Eliminar configuración de un widget
  static Future<void> deleteWidgetConfig(int widgetId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_widgetConfigPrefix$widgetId';
      await prefs.remove(key);

      // Remover de la lista de widgets
      List<int> widgetIds = await getWidgetIds();
      widgetIds.remove(widgetId);
      await prefs.setStringList(
          _widgetListKey, widgetIds.map((e) => e.toString()).toList());

      printLog.i('Widget $widgetId eliminado correctamente');
    } catch (e) {
      printLog.e('Error eliminando configuración de widget: $e');
    }
  }

  /// Obtener todos los IDs de widgets configurados
  static Future<List<int>> getWidgetIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stringList = prefs.getStringList(_widgetListKey) ?? [];
      return stringList.map((e) => int.parse(e)).toList();
    } catch (e) {
      printLog.e('Error obteniendo lista de widgets: $e');
      return [];
    }
  }

  /// Obtener todas las configuraciones de widgets
  static Future<List<WidgetData>> getAllWidgetConfigs() async {
    try {
      List<int> widgetIds = await getWidgetIds();
      List<WidgetData> configs = [];

      for (int widgetId in widgetIds) {
        final config = await loadWidgetConfig(widgetId);
        if (config != null) {
          configs.add(config);
        }
      }

      return configs;
    } catch (e) {
      printLog.e('Error obteniendo configuraciones de widgets: $e');
      return [];
    }
  }

  /// Actualizar el estado de un widget en la pantalla de inicio.
  ///
  /// FIX: Guardado atómico — todos los campos en un único JSON para evitar
  /// que onUpdate() lea un estado parcialmente escrito si el WorkManager
  /// se dispara en medio de los awaits secuenciales.
  static Future<void> updateWidget(
      WidgetData widgetData, WidgetDeviceState state) async {
    try {
      printLog.i(
        'Actualizando widget ${widgetData.widgetId}: ${widgetData.nickname}, '
        'online=${state.online}, status=${state.status}',
      );

      final bool isControl = widgetData.type == WidgetType.control;

      // ── Construir el estado completo en un único mapa ──────────────────
      final Map<String, dynamic> stateMap = {
        'nickname': widgetData.nickname,
        'isControl': isControl,
        'online': state.online,
        'status': state.status,
        'loading': false,
        'initializing': false,
        'productCode': widgetData.productCode,
        'isDisplayType': widgetData.type == WidgetType.display,
        // Timestamp de la última actualización (ms desde epoch).
        // ControlWidgetProvider lo usa para detectar datos obsoletos.
        'ts': DateTime.now().millisecondsSinceEpoch,
      };

      if (state.temperature != null) stateMap['displayTemp'] = state.temperature;
      if (state.alert != null)       stateMap['displayAlert'] = state.alert;
      if (state.ppmCO != null)       stateMap['ppmCO'] = state.ppmCO;
      if (state.ppmCH4 != null)      stateMap['ppmCH4'] = state.ppmCH4;

      // ── UNA sola escritura → sin race condition ────────────────────────
      await HomeWidget.saveWidgetData(
        'widget_state_${widgetData.widgetId}',
        jsonEncode(stateMap),
      );

      // Mantener claves individuales para backward-compat con _handleWidgetToggle
      // (lee widget_status y widget_is_control directamente)
      await HomeWidget.saveWidgetData(
          'widget_status_${widgetData.widgetId}', state.status);
      await HomeWidget.saveWidgetData(
          'widget_is_control_${widgetData.widgetId}', isControl);

      printLog.i(
          'Datos guardados atómicamente, actualizando widget nativo ${widgetData.widgetId}');

      // ── Disparar redibujado del widget nativo ──────────────────────────
      await _updatePlatformWidgets();

      printLog.i('Widget ${widgetData.widgetId} actualizado correctamente');
    } catch (e, stackTrace) {
      printLog.e('Error actualizando widget: $e');
      printLog.e('Stack trace: $stackTrace');
    }
  }

  /// Actualizar todos los widgets con datos de globalDATA
  static Future<void> updateAllWidgets() async {
    try {
      List<WidgetData> widgets = await getAllWidgetConfigs();

      for (WidgetData widgetData in widgets) {
        final deviceData = globalDATA[widgetData.deviceKey];

        if (deviceData != null) {
          WidgetDeviceState state;

          // Para dispositivos con múltiples salidas/entradas
          if (widgetData.ioIndex != null) {
            final ioData = deviceData['io${widgetData.ioIndex}'];
            if (ioData != null) {
              Map<String, dynamic> ioMap = {};
              if (ioData is String) {
                ioMap = jsonDecode(ioData);
              } else if (ioData is Map) {
                ioMap = Map<String, dynamic>.from(ioData);
              }

              String pinType = ioMap['pinType']?.toString() ?? '0';
              bool isInput = pinType != '0';
              bool wStatus = ioMap['w_status'] ?? false;

              bool status;
              bool? alert;

              if (isInput) {
                String rState = (ioMap['r_state'] ?? '0').toString();
                bool isClosed =
                    (wStatus && rState == '1') || (!wStatus && rState != '1');
                status = isClosed;
                alert = !isClosed;
              } else {
                status = wStatus;
                alert = null;
              }

              state = WidgetDeviceState(
                online: deviceData['cstate'] ?? false,
                status: status,
                alert: alert,
              );
            } else {
              state = WidgetDeviceState(online: false, status: false);
            }
          } else {
            // Dispositivos normales
            bool online = deviceData['cstate'] ?? false;
            bool status = deviceData['w_status'] ?? false;

            String? temperature;
            bool? alert;
            int? ppmCO;
            int? ppmCH4;

            if (widgetData.productCode == '015773_IOT') {
              ppmCO = deviceData['ppmco'];
              ppmCH4 = deviceData['ppmch4'];
              alert = deviceData['alert'] == 1;
            } else if (widgetData.productCode == '023430_IOT') {
              temperature = deviceData['actualTemp']?.toString();
            }

            state = WidgetDeviceState(
              online: online,
              status: status,
              temperature: temperature,
              alert: alert,
              ppmCO: ppmCO,
              ppmCH4: ppmCH4,
            );
          }

          await updateWidget(widgetData, state);
        }
      }
    } catch (e) {
      printLog.e('Error actualizando todos los widgets: $e');
    }
  }

  /// Extraer datos del dispositivo para actualizar widget
  static WidgetDeviceState extractDeviceState(
      String productCode, String serialNumber, int? ioIndex) {
    final deviceKey = '$productCode/$serialNumber';
    final deviceData = globalDATA[deviceKey];

    if (deviceData == null) {
      return WidgetDeviceState(online: false, status: false);
    }

    if (ioIndex != null) {
      final ioData = deviceData['io$ioIndex'];
      if (ioData != null) {
        Map<String, dynamic> ioMap = {};
        if (ioData is String) {
          ioMap = jsonDecode(ioData);
        } else if (ioData is Map) {
          ioMap = Map<String, dynamic>.from(ioData);
        }

        String pinType = ioMap['pinType']?.toString() ?? '0';
        bool isInput = pinType != '0';
        bool wStatus = ioMap['w_status'] ?? false;

        bool status;
        bool? alert;

        if (isInput) {
          String rState = (ioMap['r_state'] ?? '0').toString();
          bool isClosed =
              (wStatus && rState == '1') || (!wStatus && rState != '1');
          status = isClosed;
          alert = !isClosed;
        } else {
          status = wStatus;
          alert = null;
        }

        return WidgetDeviceState(
          online: deviceData['cstate'] ?? false,
          status: status,
          alert: alert,
        );
      } else {
        return WidgetDeviceState(online: false, status: false);
      }
    }

    bool online = deviceData['cstate'] ?? false;
    bool status = deviceData['w_status'] ?? false;

    String? temperature;
    bool? alert;
    int? ppmCO;
    int? ppmCH4;

    if (productCode == '015773_IOT') {
      ppmCO = deviceData['ppmco'];
      ppmCH4 = deviceData['ppmch4'];
      alert = deviceData['alert'] == 1;
    } else if (productCode == '023430_IOT') {
      temperature = deviceData['actualTemp']?.toString();
    }

    return WidgetDeviceState(
      online: online,
      status: status,
      temperature: temperature,
      alert: alert,
      ppmCO: ppmCO,
      ppmCH4: ppmCH4,
    );
  }
}