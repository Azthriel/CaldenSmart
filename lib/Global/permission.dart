import 'package:caldensmart/Global/menu.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../master.dart';

class PermissionHandler extends StatefulWidget {
  const PermissionHandler({super.key});

  @override
  PermissionHandlerState createState() => PermissionHandlerState();
}

class PermissionHandlerState extends State<PermissionHandler> {
  Future<Widget> permissionCheck() async {
    var permissionStatus1 = await Permission.bluetoothConnect.request();

    if (!permissionStatus1.isGranted) {
      await Permission.bluetoothConnect.request();
    }
    permissionStatus1 = await Permission.bluetoothConnect.status;

    var permissionStatus2 = await Permission.bluetoothScan.request();

    if (!permissionStatus2.isGranted) {
      await Permission.bluetoothScan.request();
    }
    permissionStatus2 = await Permission.bluetoothScan.status;

    var permissionStatus3 = await Permission.location.request();

    if (!permissionStatus3.isGranted) {
      await Permission.location.request();
    }
    permissionStatus3 = await Permission.location.status;

    var permissionStatus4 = await Permission.notification.request();

    if (!permissionStatus4.isGranted) {
      await Permission.notification.request();
    }
    permissionStatus4 = await Permission.notification.status;

    // requestPermissionFCM();

    printLog('Ble: ${permissionStatus1.isGranted} /// $permissionStatus1');
    printLog('Ble Scan: ${permissionStatus2.isGranted} /// $permissionStatus2');
    printLog('Locate: ${permissionStatus3.isGranted} /// $permissionStatus3');
    printLog('Notif: ${permissionStatus4.isGranted} /// $permissionStatus4');

    if (permissionStatus1.isGranted &&
        permissionStatus2.isGranted &&
        permissionStatus3.isGranted) {
      return const MenuPage();
    } else if (permissionStatus3.isGranted && !android) {
      return const MenuPage();
    } else {
      return AlertDialog(
        title: const Text('Permisos requeridos'),
        content: const Text(
            'No se puede seguir sin los permisos\n Por favor activalos manualmente'),
        actions: [
          TextButton(
            child: const Text('Abrir opciones de la app'),
            onPressed: () => openAppSettings(),
          ),
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      builder: (ctx, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Ocurrió el siguiente error: ${snapshot.error}',
                style: const TextStyle(fontSize: 18),
              ),
            );
          } else {
            return snapshot.data as Widget;
          }
        }
        return const Center(
          child: CircularProgressIndicator(
            color: Color(0xFFBDBDBD),
          ),
        );
      },
      future: permissionCheck(),
    );
  }
}
