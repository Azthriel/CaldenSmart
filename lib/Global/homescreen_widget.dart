// import 'dart:convert';
// import 'package:caldensmart/Global/stored_data.dart';
// import 'package:caldensmart/aws/mqtt/mqtt.dart';
// import 'package:caldensmart/master.dart';
// import 'package:home_widget/home_widget.dart';

// void widgetBackgroundCallback(Uri? uri) async {
//   if (uri != null) {
//     final action = uri.queryParameters['action'];
//     final deviceName = uri.queryParameters['device'];
//     if (action == 'toggleDevice' && deviceName != null) {
//       await loadValues();
//       if (deviceName.contains("Domotica") ||
//           deviceName.contains("Modulo") ||
//           (deviceName.contains("Rele") && deviceName.contains("_"))) {
//         List<String> parts = deviceName.split('_');
//         String deviceSerialNumber = DeviceManager.extractSerialNumber(parts[0]);
//         String productCode = DeviceManager.getProductCode(parts[0]);
//         String key = '$productCode/$deviceSerialNumber';
//         bool currentState = globalDATA[key]?['w_status'] ?? false;
//         bool newState = !currentState;
//         String comun = globalDATA[key]?['r_state'] ?? '0';

//         //Cambiamos el estado

//         String topic = 'devices_rx/$key';
//         String topic2 = 'devices_tx/$key';
//         String message = jsonEncode({
//           "w_status": newState,
//           "r_state": comun,
//           "index": parts[1],
//           "pinType": 0
//         });
//         sendMessagemqtt(topic, message);
//         sendMessagemqtt(topic2, message);
//       } else {
//         String deviceSerialNumber =
//             DeviceManager.extractSerialNumber(deviceName);
//         String productCode = DeviceManager.getProductCode(deviceName);
//         String key = '$productCode/$deviceSerialNumber';
//         bool currentState = globalDATA[key]?['w_status'] ?? false;
//         bool newState = !currentState;

//         //Cambiamos el estado

//         String topic = 'devices_rx/$key';
//         String topic2 = 'devices_tx/$key';
//         String message = jsonEncode({"w_status": newState});
//         sendMessagemqtt(topic, message);
//         sendMessagemqtt(topic2, message);
//       }
//     }
//   }
// }

// /// Recorre la lista de dispositivos y guarda su información en JSON para el widget
// Future<void> updateWidgetData() async {
//   Map<String, dynamic> widgetData = {};
//   for (String device in previusConnections) {
//     String deviceSerialNumber = DeviceManager.extractSerialNumber(device);
//     String productCode = DeviceManager.getProductCode(device);
//     String key = '$productCode/$deviceSerialNumber';
//     bool wStatus = globalDATA[key]?['w_status'] ?? false;
//     bool online = globalDATA[key]?['cstate'] ?? false;
//     widgetData[device] = {
//       'productCode': productCode,
//       'serial': deviceSerialNumber,
//       'w_status': wStatus,
//       'online': online,
//     };
//   }
//   String jsonData = jsonEncode(widgetData);
//   await HomeWidget.saveWidgetData<String>('wifiWidgetData', jsonData);
//   await HomeWidget.updateWidget(
//     name: 'HomeScreenWidgetProvider',
//     iOSName: 'HomeScreenWidgetProvider', // en caso de integrar en iOS
//   );
// }
