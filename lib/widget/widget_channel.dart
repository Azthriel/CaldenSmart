import 'package:flutter/services.dart';
import 'package:caldensmart/logger.dart';
import 'package:caldensmart/master.dart';

/// Channel para comunicarse con el código nativo de widgets
class WidgetChannel {
  static const MethodChannel _channel =
      MethodChannel('com.caldensmart.sime/widget');

  /// Inicializar el handler para navegación desde Android
  static void initialize() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'navigateToConfig') {
        final widgetId = call.arguments['widgetId'] as int?;
        if (widgetId != null) {
          printLog.i('Navegando a configuración de widget: $widgetId');
          // Navegar a la pantalla de configuración
          navigatorKey.currentState?.pushNamed(
            '/widgetConfig',
            arguments: widgetId,
          );
        }
      }
    });
  }

  /// Verificar si estamos en modo de configuración de widget
  static Future<bool> isWidgetConfiguration() async {
    try {
      final bool? isConfig = await _channel.invokeMethod('isWidgetConfiguration');
      return isConfig ?? false;
    } catch (e) {
      printLog.e('Error checking widget configuration: $e');
      return false;
    }
  }

  /// Obtener el widget ID desde el intent (Android)
  static Future<int?> getWidgetId() async {
    try {
      final int? widgetId = await _channel.invokeMethod('getWidgetId');
      return widgetId;
    } catch (e) {
      printLog.e('Error getting widget ID: $e');
      return null;
    }
  }

  /// Limpiar el widget ID después de usarlo
  static Future<void> clearWidgetId() async {
    try {
      await _channel.invokeMethod('clearWidgetId');
    } catch (e) {
      printLog.e('Error clearing widget ID: $e');
    }
  }

  /// Finalizar la configuración del widget con éxito
  static Future<void> finishWidgetConfiguration(int widgetId) async {
    try {
      await _channel.invokeMethod('finishWidgetConfiguration', {'widgetId': widgetId});
      printLog.i('Widget configuration finished for widget $widgetId');
    } catch (e) {
      printLog.e('Error finishing widget configuration: $e');
    }
  }

  /// Guardar datos del widget directamente en SharedPreferences nativo
  static Future<void> saveWidgetData(int widgetId, String key, dynamic value) async {
    try {
      String type;
      if (value is String) {
        type = 'string';
      } else if (value is bool) {
        type = 'bool';
      } else if (value is int) {
        type = 'int';
      } else {
        printLog.e('Unsupported value type: ${value.runtimeType}');
        return;
      }
      
      await _channel.invokeMethod('saveWidgetData', {
        'widgetId': widgetId,
        'key': key,
        'value': value,
        'type': type,
      });
      printLog.i('Widget data saved via native channel: widget_${widgetId}_$key = $value');
    } catch (e) {
      printLog.e('Error saving widget data: $e');
    }
  }
}
