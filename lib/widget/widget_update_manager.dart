import 'dart:async';
import 'package:caldensmart/logger.dart';
import 'widget_service.dart';

/// Manager para mantener los widgets actualizados con datos MQTT.
///
/// Corre un timer periódico que llama a [WidgetService.updateAllWidgets]
/// leyendo desde globalDATA (datos MQTT ya recibidos en el isolate principal).
class WidgetUpdateManager {
  static WidgetUpdateManager? _instance;
  static WidgetUpdateManager get instance =>
      _instance ??= WidgetUpdateManager._();

  WidgetUpdateManager._();

  Timer? _updateTimer;
  bool _isInitialized = false;

  /// Timestamp de la última actualización completada.
  /// Usado para el debounce de [forceUpdate].
  DateTime? _lastUpdate;

  /// Mínimo tiempo entre actualizaciones forzadas para evitar escrituras
  /// redundantes en SharedPrefs cuando los datos cambian rápido por MQTT.
  static const _minUpdateInterval = Duration(seconds: 3);

  /// Inicializar el manager de actualización de widgets
  Future<void> initialize() async {
    if (_isInitialized) return;

    printLog.i('Inicializando WidgetUpdateManager...');

    _updateTimer?.cancel();
    _updateTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _updateAllWidgets();
    });

    // Actualización inicial
    await _updateAllWidgets();

    _isInitialized = true;
    printLog.i('WidgetUpdateManager inicializado correctamente');
  }

  /// Actualizar todos los widgets (llamado periódicamente por el timer)
  Future<void> _updateAllWidgets() async {
    try {
      await WidgetService.updateAllWidgets();
      _lastUpdate = DateTime.now();
    } catch (e) {
      printLog.e('Error actualizando widgets: $e');
    }
  }

  /// Fuerza una actualización inmediata respetando un debounce mínimo.
  ///
  /// Útil para llamar desde el listener MQTT del isolate principal cuando
  /// llega un mensaje que cambia el estado de un dispositivo con widget.
  /// Sin el debounce, mensajes MQTT rápidos generarían decenas de escrituras
  /// en SharedPrefs en pocos segundos.
  Future<void> forceUpdate() async {
    final now = DateTime.now();
    if (_lastUpdate != null &&
        now.difference(_lastUpdate!) < _minUpdateInterval) {
      // Demasiado pronto — ignorar, el timer periódico lo cubrirá
      return;
    }
    await _updateAllWidgets();
  }

  /// Actualizar widget específico inmediatamente (sin debounce)
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
        _lastUpdate = DateTime.now();
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
    _lastUpdate = null;
    printLog.i('WidgetUpdateManager detenido');
  }
}
