import 'dart:async';
import 'package:caldensmart/logger.dart';
import 'widget_service.dart';

/// Manager para mantener los widgets actualizados con datos MQTT
class WidgetUpdateManager {
  static WidgetUpdateManager? _instance;
  static WidgetUpdateManager get instance => _instance ??= WidgetUpdateManager._();

  WidgetUpdateManager._();

  Timer? _updateTimer;
  bool _isInitialized = false;

  /// Inicializar el manager de actualización de widgets
  Future<void> initialize() async {
    if (_isInitialized) return;

    printLog.i('Inicializando WidgetUpdateManager...');

    // Actualizar widgets cada 10 segundos
    _updateTimer?.cancel();
    _updateTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _updateAllWidgets();
    });

    // Actualización inicial
    await _updateAllWidgets();

    _isInitialized = true;
    printLog.i('WidgetUpdateManager inicializado correctamente');
  }

  /// Actualizar todos los widgets
  Future<void> _updateAllWidgets() async {
    try {
      await WidgetService.updateAllWidgets();
    } catch (e) {
      printLog.e('Error actualizando widgets: $e');
    }
  }

  /// Actualizar widget específico inmediatamente
  Future<void> updateWidget(int widgetId) async {
    try {
      final widgetData = await WidgetService.loadWidgetConfig(widgetId);
      if (widgetData != null) {
        final deviceState = WidgetService.extractDeviceState(
          widgetData.productCode,
          widgetData.serialNumber,
          widgetData.ioIndex,
        );
        await WidgetService.updateWidget(widgetData, deviceState);
      }
    } catch (e) {
      printLog.e('Error actualizando widget $widgetId: $e');
    }
  }

  /// Detener el manager
  void dispose() {
    _updateTimer?.cancel();
    _updateTimer = null;
    _isInitialized = false;
    printLog.i('WidgetUpdateManager detenido');
  }
}
