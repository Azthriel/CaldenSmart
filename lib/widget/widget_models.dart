import 'dart:convert';

/// Modelo para representar los datos de un widget
class WidgetData {
  final int widgetId;
  final String deviceName;
  final String productCode;
  final String serialNumber;
  final String nickname;
  final WidgetType type;
  final int? ioIndex; // Para dispositivos de múltiples salidas (domotica, modulo, etc)

  WidgetData({
    required this.widgetId,
    required this.deviceName,
    required this.productCode,
    required this.serialNumber,
    required this.nickname,
    required this.type,
    this.ioIndex,
  });

  String get deviceKey => '$productCode/$serialNumber';

  Map<String, dynamic> toJson() {
    return {
      'widgetId': widgetId,
      'deviceName': deviceName,
      'productCode': productCode,
      'serialNumber': serialNumber,
      'nickname': nickname,
      'type': type.toString(),
      'ioIndex': ioIndex,
    };
  }

  factory WidgetData.fromJson(Map<String, dynamic> json) {
    return WidgetData(
      widgetId: json['widgetId'],
      deviceName: json['deviceName'],
      productCode: json['productCode'],
      serialNumber: json['serialNumber'],
      nickname: json['nickname'],
      type: WidgetType.values.firstWhere(
        (e) => e.toString() == json['type'],
        orElse: () => WidgetType.control,
      ),
      ioIndex: json['ioIndex'],
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory WidgetData.fromJsonString(String jsonString) =>
      WidgetData.fromJson(jsonDecode(jsonString));
}

/// Tipos de widgets disponibles
enum WidgetType {
  /// Widget de visualización de datos (termómetros, detectores)
  display,

  /// Widget de control (todos los demás dispositivos)
  control,
}

/// Determinar el tipo de widget según el código de producto
WidgetType getWidgetType(String productCode) {
  switch (productCode) {
    case '015773_IOT': // Detector
    case '023430_IOT': // Termómetro
      return WidgetType.display;

    default:
      return WidgetType.control;
  }
}

/// Determinar si un dispositivo debe tener widget
bool shouldHaveWidget(String productCode) {
  switch (productCode) {
    case '027131_IOT': // Riel - NO tiene widget
    case '024011_IOT': // Roll - NO tiene widget
      return false;
    default:
      return true;
  }
}

/// Clase auxiliar para los datos del dispositivo en el widget
class WidgetDeviceState {
  final bool online;
  final bool status; // w_status
  final String? temperature; // Para termómetros
  final bool? alert; // Para detectores
  final int? ppmCO; // Para detectores
  final int? ppmCH4; // Para detectores

  WidgetDeviceState({
    required this.online,
    required this.status,
    this.temperature,
    this.alert,
    this.ppmCO,
    this.ppmCH4,
  });

  Map<String, dynamic> toJson() {
    return {
      'online': online,
      'status': status,
      'temperature': temperature,
      'alert': alert,
      'ppmCO': ppmCO,
      'ppmCH4': ppmCH4,
    };
  }

  factory WidgetDeviceState.fromJson(Map<String, dynamic> json) {
    return WidgetDeviceState(
      online: json['online'] ?? false,
      status: json['status'] ?? false,
      temperature: json['temperature'],
      alert: json['alert'],
      ppmCO: json['ppmCO'],
      ppmCH4: json['ppmCH4'],
    );
  }
}
