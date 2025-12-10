import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:home_widget/home_widget.dart';
import 'package:caldensmart/master.dart';
import 'package:caldensmart/logger.dart';
import 'widget_models.dart';
import 'widget_channel.dart';

/// Servicio para gestionar widgets de la app
class WidgetService {
  static const String _widgetConfigPrefix = 'CSWidgetConfig_';
  static const String _widgetListKey = 'CSWidgetList';

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

  /// Actualizar el estado de un widget en la pantalla de inicio
  static Future<void> updateWidget(
      WidgetData widgetData, WidgetDeviceState state) async {
    try {
      printLog.i('Actualizando widget ${widgetData.widgetId}: ${widgetData.nickname}, online=${state.online}, status=${state.status}');
      
      // Guardar datos directamente en SharedPreferences nativo usando MethodChannel
      await WidgetChannel.saveWidgetData(widgetData.widgetId, 'nickname', widgetData.nickname);
      await WidgetChannel.saveWidgetData(widgetData.widgetId, 'online', state.online);
      await WidgetChannel.saveWidgetData(widgetData.widgetId, 'status', state.status);
      await WidgetChannel.saveWidgetData(widgetData.widgetId, 'type', widgetData.type.toString());

      // Datos específicos según el tipo
      if (widgetData.type == WidgetType.display) {
        if (state.temperature != null) {
          await WidgetChannel.saveWidgetData(widgetData.widgetId, 'temperature', state.temperature!);
        }

        if (state.alert != null) {
          await WidgetChannel.saveWidgetData(widgetData.widgetId, 'alert', state.alert!);
        }

        if (state.ppmCO != null) {
          await WidgetChannel.saveWidgetData(widgetData.widgetId, 'ppmCO', state.ppmCO!);
        }

        if (state.ppmCH4 != null) {
          await WidgetChannel.saveWidgetData(widgetData.widgetId, 'ppmCH4', state.ppmCH4!);
        }
      }

      printLog.i('Datos guardados en SharedPreferences nativo, actualizando widget ${widgetData.widgetId}');

      // Actualizar el widget nativo unificado
      await HomeWidget.updateWidget(
        androidName: 'widget.CaldenSmartWidgetProvider',
      );

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

              // Verificar si es entrada o salida
              String pinType = ioMap['pinType']?.toString() ?? '0';
              bool isInput = pinType != '0';
              bool wStatus = ioMap['w_status'] ?? false;

              bool status;
              bool? alert;

              if (isInput) {
                // Para entradas, determinar estado de alerta
                String rState = (ioMap['r_state'] ?? '0').toString();
                bool isClosed =
                    (wStatus && rState == '1') || (!wStatus && rState != '1');
                status = isClosed;
                alert = !isClosed;
              } else {
                // Para salidas
                status = wStatus;
                alert = null;
              }

              state = WidgetDeviceState(
                online: deviceData['cstate'] ?? false,
                status: status,
                alert: alert,
              );
            } else {
              state = WidgetDeviceState(
                online: false,
                status: false,
              );
            }
          } else {
            // Dispositivos normales
            bool online = deviceData['cstate'] ?? false;
            bool status = deviceData['w_status'] ?? false;

            // Datos específicos según el tipo de dispositivo
            String? temperature;
            bool? alert;
            int? ppmCO;
            int? ppmCH4;

            if (widgetData.productCode == '015773_IOT') {
              // Detector
              ppmCO = deviceData['ppmco'];
              ppmCH4 = deviceData['ppmch4'];
              alert = deviceData['alert'] == 1;
            } else if (widgetData.productCode == '023430_IOT') {
              // Termómetro
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

      // printLog.i('Todos los widgets actualizados');
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

    // Para dispositivos con múltiples salidas/entradas
    if (ioIndex != null) {
      final ioData = deviceData['io$ioIndex'];
      if (ioData != null) {
        Map<String, dynamic> ioMap = {};
        if (ioData is String) {
          ioMap = jsonDecode(ioData);
        } else if (ioData is Map) {
          ioMap = Map<String, dynamic>.from(ioData);
        }

        // Verificar si es entrada o salida
        String pinType = ioMap['pinType']?.toString() ?? '0';
        bool isInput = pinType != '0'; // pinType == '1' es entrada
        bool wStatus = ioMap['w_status'] ?? false;

        bool status;
        bool? alert;

        if (isInput) {
          // Para entradas, el estado de alerta se determina por w_status y r_state
          String rState = (ioMap['r_state'] ?? '0').toString();

          // Lógica de alerta para entradas (mismo que wifi.dart):
          // - Si w_status == true y r_state == '1' → Cerrado (sin alerta)
          // - Si w_status == true y r_state != '1' → Abierto (alerta)
          // - Si w_status == false y r_state == '1' → Abierto (alerta)
          // - Si w_status == false y r_state != '1' → Cerrado (sin alerta)
          bool isClosed =
              (wStatus && rState == '1') || (!wStatus && rState != '1');
          status = isClosed; // Cerrado = true, Abierto = false
          alert = !isClosed; // Alerta cuando está abierto
        } else {
          // Para salidas, usar w_status directamente
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

    // Dispositivos normales
    bool online = deviceData['cstate'] ?? false;
    bool status = deviceData['w_status'] ?? false;

    // Datos específicos según el tipo de dispositivo
    String? temperature;
    bool? alert;
    int? ppmCO;
    int? ppmCH4;

    if (productCode == '015773_IOT') {
      // Detector
      ppmCO = deviceData['ppmco'];
      ppmCH4 = deviceData['ppmch4'];
      alert = deviceData['alert'] == 1;
    } else if (productCode == '023430_IOT') {
      // Termómetro
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
