// import 'dart:async';

// import 'package:caldensmart/Global/homescreen_widget.dart';
// import 'package:caldensmart/Global/stored_data.dart';
// import 'package:caldensmart/master.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';

// class SelectDevice extends StatefulWidget {
//   const SelectDevice({super.key});

//   @override
//   SelectDeviceState createState() => SelectDeviceState();
// }

// class SelectDeviceState extends State<SelectDevice> {
//   Future<List<String>> fetchConnections() async {
//     previusConnections = await loadDeviceList();

//     return previusConnections;
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Center(
//           child: Text(
//             'Elige un dispositivo',
//             style: TextStyle(
//               color: color0,
//             ),
//           ),
//         ),
//         backgroundColor: color1,
//       ),
//       body: Container(
//         color: color0,
//         child: FutureBuilder<List<String>>(
//           future: fetchConnections(),
//           builder: (context, snapshot) {
//             if (snapshot.connectionState == ConnectionState.waiting) {
//               return const Center(
//                 child: CircularProgressIndicator(),
//               );
//             } else if (snapshot.hasError) {
//               return const Center(
//                 child: Text(
//                   'Error al cargar los dispositivos',
//                   style: TextStyle(color: Colors.red),
//                 ),
//               );
//             } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
//               return const Center(
//                 child: Text(
//                   'No hay dispositivos disponibles',
//                   style: TextStyle(color: color0),
//                 ),
//               );
//             } else {
//               final connections = snapshot.data!;
//               printLog(previusConnections, 'verde');
//               return ListView.builder(
//                 itemCount: connections.length,
//                 itemBuilder: (context, index) {
//                   bool isTapped = false;
//                   return StatefulBuilder(
//                     builder: (context, setState) {
//                       return GestureDetector(
//                         onTap: () async {
//                           setState(() {
//                             isTapped = true;
//                           });
//                           await Future.delayed(
//                               const Duration(milliseconds: 200));
//                           setState(() {
//                             isTapped = false;
//                           });

//                           await updateWidgetData(connections[index]);
//                           SystemNavigator.pop();
//                         },
//                         child: AnimatedContainer(
//                           duration: const Duration(milliseconds: 200),
//                           curve: Curves.easeInOut,
//                           margin: const EdgeInsets.symmetric(
//                               horizontal: 16, vertical: 8),
//                           padding: const EdgeInsets.all(20),
//                           decoration: BoxDecoration(
//                             color: isTapped
//                                 ? color1.withValues(alpha: 0.7)
//                                 : color1,
//                             borderRadius: BorderRadius.circular(12),
//                             boxShadow: isTapped
//                                 ? [
//                                     BoxShadow(
//                                       color:
//                                           Colors.black.withValues(alpha: 0.2),
//                                       blurRadius: 8,
//                                       offset: const Offset(0, 4),
//                                     ),
//                                   ]
//                                 : [],
//                           ),
//                           child: Text(
//                             connections[index],
//                             style: const TextStyle(
//                               color: color0,
//                               fontSize: 16,
//                             ),
//                           ),
//                         ),
//                       );
//                     },
//                   );
//                 },
//               );
//             }
//           },
//         ),
//       ),
//     );
//   }
// }