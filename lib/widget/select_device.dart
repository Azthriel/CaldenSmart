// import 'dart:convert';
// import 'package:caldensmart/Global/stored_data.dart' show loadEmail;
// import 'package:caldensmart/aws/dynamo/dynamo.dart';
// import 'package:caldensmart/logger.dart';
// import 'package:caldensmart/master.dart';
// import 'package:caldensmart/widget/homescreen_widget.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart'; // Para MethodChannel
// import 'package:google_fonts/google_fonts.dart';
// import 'package:hugeicons/hugeicons.dart';
// import 'package:home_widget/home_widget.dart';

// class SelectDeviceScreen extends StatefulWidget {
//   const SelectDeviceScreen({super.key});

//   @override
//   State<SelectDeviceScreen> createState() => _SelectDeviceScreenState();
// }

// class _SelectDeviceScreenState extends State<SelectDeviceScreen> {
//   // Canal para hablar con Android (WidgetConfigActivity.kt)
//   static const platform = MethodChannel('com.caldensmart.sime/widget_config');

//   int? _widgetId;
//   bool _isLoading = true;
//   String currentUserEmail = '';
//   List<String> previusConnections = []; // Lista de IDs de dispositivos
//   Map<String, String> nicknamesMap = {}; // Mapa ID -> Apodo
//   Map<String, bool> devicesToShow =
//       {}; // Dispositivos a mostrar (True -> Control | False -> Solo lectura)
//   // Map<String, dynamic> globalDATA = {}; // Tu estructura de datos global

//   @override
//   void initState() {
//     super.initState();
//     // 1. Primero obtenemos el ID del widget desde Android
//     _getWidgetId();
//   }

//   // Pide el ID a la actividad nativa
//   Future<void> _getWidgetId() async {
//     try {
//       final int widgetId = await platform.invokeMethod('getWidgetId');
//       setState(() {
//         _widgetId = widgetId;
//       });
//       printLog.d("Configurando Widget ID: $_widgetId");

//       // 2. Una vez tenemos ID, cargamos tus datos
//       _loadInitialData();
//     } on PlatformException catch (e) {
//       printLog.e("Error obteniendo Widget ID: '${e.message}'.");
//       // Si falla, igual cargamos datos para pruebas, pero no podremos guardar
//       _loadInitialData();
//     }
//   }

//   Future<void> _loadInitialData() async {
//     try {
//       setState(() => _isLoading = true);

//       await DeviceManager.init();

//       currentUserEmail = await loadEmail();
//       previusConnections = await getPreviusConnections(currentUserEmail);
//       nicknamesMap = await getNicknames(currentUserEmail);
//       for (String device in previusConnections) {
//         final pc = DeviceManager.getProductCode(device);
//         final sn = DeviceManager.extractSerialNumber(device);
//         await queryItems(pc, sn);
//         Map<String, dynamic> deviceDATA = globalDATA['$pc/$sn'] ?? {};
//         List<String> admins =
//             List<String>.from(globalDATA['$pc/$sn']?['secondary_admin'] ?? []);
//         String ownerEmail = globalDATA['$pc/$sn']?['owner'] ?? '';
//         bool canControlDevice = ownerEmail == currentUserEmail ||
//             admins.contains(currentUserEmail) ||
//             ownerEmail == '';
//         if (canControlDevice) {
//           bool ioDevice = false;
//           deviceDATA.forEach((key, value) {
//             if (key.startsWith('io') && value is String) {
//               ioDevice = true;
//               var decoded = jsonDecode(value);
//               devicesToShow.addAll({
//                 '${device}_${decoded['index'] ?? 0}':
//                     decoded['pinType'].toString() == '0'
//               });
//             }
//           });
//           if (!ioDevice) {
//             bool onOffDevice = pc != '023430_IOT' &&
//                 pc != '015773_IOT' &&
//                 pc != '024011_IOT' &&
//                 pc != '027131_IOT';
//             devicesToShow.addAll({device: onOffDevice});
//           }
//         }
//       }

//       // ---------------------
//     } catch (e) {
//       printLog.e('Error cargando datos: $e');
//     } finally {
//       if (mounted) {
//         setState(() => _isLoading = false);
//       }
//     }
//   }

// // Función para guardar la configuración cuando el usuario elige un dispositivo
//   Future<void> _onDeviceSelected(String deviceKey) async {
//     if (_widgetId == null) return;

//     try {
//       setState(() => _isLoading = true);

//       // 1. Recuperar datos necesarios
//       String nickname = '';
//       if (deviceKey.contains('_')) {
//         nickname = nicknamesMap[deviceKey] ??
//             '${nicknamesMap[deviceKey.split('_')[0]] ?? deviceKey.split('_')[0]} pin ${deviceKey.split('_')[1]}';
//       } else {
//         nickname = nicknamesMap[deviceKey] ?? deviceKey;
//       }

//       bool isControl = devicesToShow[deviceKey] ?? false;

//       // LOGICA DE ESTADO INICIAL
//       // Intentamos obtener el estado actual de globalDATA para que el widget nazca actualizado
//       String pc = DeviceManager.getProductCode(deviceKey.split('_')[0]);
//       String sn = DeviceManager.extractSerialNumber(deviceKey.split('_')[0]);

//       // Estado de conexión
//       bool isOnline = globalDATA['$pc/$sn']?['cstate'] ?? false;

//       // Estado encendido/apagado (Solo ejemplo, ajusta según tu lógica real de pines)
//       bool isOn = false;
//       if (isControl) {
//         if (deviceKey.contains('_')) {
//           // Es un pin
//           String pinIndex = deviceKey.split('_')[1];
//           String ioKey = 'io$pinIndex';
//           String? ioData = globalDATA['$pc/$sn']?[ioKey];
//           if (ioData != null) {
//             var decoded = jsonDecode(ioData);
//             isOn = decoded['w_status'] == true;
//           }
//         } else {
//           // Dispositivo principal
//           isOn = globalDATA['$pc/$sn']?['w_status'] == true;
//         }
//       }

//       // 2. Guardar las preferencias
//       await HomeWidget.saveWidgetData('widget_device_$_widgetId', deviceKey);
//       await HomeWidget.saveWidgetData('widget_nickname_$_widgetId', nickname);
//       await HomeWidget.saveWidgetData(
//           'widget_is_control_$_widgetId', isControl);

//       printLog.d("Guardando widget $_widgetId para: $nickname ($deviceKey)");

//       // 3. Renderizar
//       await _renderAndUpdateWidget(
//         title: nickname,
//         statusText: isOnline ? "En línea" : "Desconectado",
//         isControl: isControl,
//         isOn: isOn,
//       );

//       // 4. Finalizar
//       await platform.invokeMethod('finishConfig');
//     } catch (e) {
//       printLog.e("Error guardando configuración: $e");
//       setState(() => _isLoading = false);
//     }
//   }

//   Future<void> _renderAndUpdateWidget({
//     required String title,
//     required String statusText,
//     required bool isControl,
//     required bool isOn,
//   }) async {
//     await Future.delayed(const Duration(milliseconds: 500));

//     // 1. Flutter saca la foto y la guarda como 'widget_snapshot'
//     await HomeWidget.renderFlutterWidget(
//       Theme(
//         data: ThemeData(useMaterial3: true),
//         child: DeviceWidgetCard(
//           title: title,
//           statusText: statusText,
//           isControl: isControl,
//           isOn: isOn,
//         ),
//       ),
//       key: 'widget_snapshot', // <--- Nombre del archivo
//       logicalSize: const Size(320, 400),
//       pixelRatio: 2.0,
//     );

//     // 2. Le decimos a Android: "Busca el archivo 'widget_snapshot' y ponlo en 'widget_image'"
//     await HomeWidget.updateWidget(
//       name: 'widget_snapshot',
//       qualifiedAndroidName: 'com.caldensmart.sime.widget.ControlWidgetProvider',
//       androidName: 'widget_image',
//     );

//     printLog.i("Widget renderizado y enviado a Android");
//   }

//   @override
//   Widget build(BuildContext context) {
//     // 1. Pantalla de Carga (Tu diseño)
//     if (_isLoading) {
//       return Scaffold(
//         backgroundColor: color0,
//         body: Center(
//           child: Padding(
//             padding: const EdgeInsets.all(20),
//             child: Column(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 // Asegúrate de que esta imagen exista o usa un Icono por ahora
//                 const Icon(Icons.downloading,
//                     size: 100, color: color1), // Placeholder
//                 const SizedBox(height: 20),
//                 Text(
//                   'Cargando dispositivos...',
//                   textAlign: TextAlign.center,
//                   style: GoogleFonts.poppins(
//                     fontSize: 16,
//                     fontWeight: FontWeight.bold,
//                     color: color1,
//                   ),
//                 ),
//                 const SizedBox(height: 20),
//                 Image.asset('assets/branch/dragon.gif',
//                     width: 150, height: 150),
//               ],
//             ),
//           ),
//         ),
//       );
//     }

//     // 2. Pantalla de Selección
//     return Scaffold(
//       backgroundColor: color0,
//       appBar: AppBar(
//         title: Text('Selecciona un dispositivo',
//             style: GoogleFonts.poppins(color: color0)),
//         backgroundColor: color1,
//         iconTheme: const IconThemeData(color: color0),
//       ),
//       body: SingleChildScrollView(
//         child: Padding(
//           padding: const EdgeInsets.all(16.0),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.stretch,
//             children: [
//               if (devicesToShow.isEmpty)
//                 Center(
//                   child: Text(
//                     "No hay dispositivos registrados",
//                     style: GoogleFonts.poppins(color: color0),
//                   ),
//                 )
//               else
//                 ...devicesToShow.entries.map((device) {
//                   bool isOnline = globalDATA[
//                               '${DeviceManager.getProductCode(device.key)}/${DeviceManager.extractSerialNumber(device.key)}']
//                           ?['cstate'] ??
//                       false;
//                   String nickname = '';
//                   if (device.key.contains('_')) {
//                     nickname = nicknamesMap[device.key] ??
//                         '${nicknamesMap[device.key.split('_')[0]] ?? device.key.split('_')[0]} pin ${device.key.split('_')[1]}';
//                   } else {
//                     nickname = nicknamesMap[device.key] ?? device.key;
//                   }
//                   return Padding(
//                     padding: const EdgeInsets.symmetric(vertical: 8.0),
//                     child: InkWell(
//                       // Hice el Container clickeable
//                       onTap: () => _onDeviceSelected(device.key),
//                       child: Container(
//                         decoration: BoxDecoration(
//                           color: color1,
//                           borderRadius: BorderRadius.circular(12.0),
//                           border: Border.all(color: color4),
//                         ),
//                         padding: const EdgeInsets.all(16.0),
//                         child: Row(
//                           children: [
//                             Expanded(
//                               child: Column(
//                                 crossAxisAlignment: CrossAxisAlignment.start,
//                                 children: [
//                                   Text(
//                                     nickname,
//                                     style: GoogleFonts.poppins(
//                                       color: color0,
//                                       fontSize: 16,
//                                       fontWeight: FontWeight.w600,
//                                     ),
//                                   ),
//                                   const SizedBox(height: 8),
//                                   Row(
//                                     children: [
//                                       Icon(
//                                         isOnline
//                                             ? HugeIcons.strokeRoundedInternet
//                                             : HugeIcons.strokeRoundedNoInternet,
//                                         color: isOnline
//                                             ? Colors.green
//                                             : Colors.red,
//                                         size: 20,
//                                       ),
//                                       const SizedBox(width: 6),
//                                       Text(
//                                         isOnline ? 'En línea' : 'Desconectado',
//                                         style: GoogleFonts.poppins(
//                                           color: color0,
//                                           fontSize: 14,
//                                         ),
//                                       ),
//                                     ],
//                                   ),
//                                 ],
//                               ),
//                             ),
//                             const SizedBox(width: 16),
//                             Text(
//                               device.value ? 'Control' : 'Lectura',
//                               style: GoogleFonts.poppins(
//                                 color: color0,
//                                 fontSize: 14,
//                               ),
//                             ),
//                             const SizedBox(width: 8),
//                             Icon(
//                               device.value
//                                   ? HugeIcons.strokeRoundedToggleOn
//                                   : HugeIcons.strokeRoundedView,
//                               color: color0,
//                               size: 30,
//                             ),
//                           ],
//                         ),
//                       ),
//                     ),
//                   );
//                 }),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
