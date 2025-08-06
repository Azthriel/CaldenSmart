import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../master.dart';
import 'package:caldensmart/logger.dart';

class PermissionHandler extends StatefulWidget {
  const PermissionHandler({super.key});

  @override
  PermissionHandlerState createState() => PermissionHandlerState();
}

class PermissionHandlerState extends State<PermissionHandler> {
  Future<void> permissionCheckAndLogin() async {
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

    printLog.i('Ble: ${permissionStatus1.isGranted} /// $permissionStatus1');
    printLog
        .i('Ble Scan: ${permissionStatus2.isGranted} /// $permissionStatus2');
    printLog.i('Locate: ${permissionStatus3.isGranted} /// $permissionStatus3');
    printLog.i('Notif: ${permissionStatus4.isGranted} /// $permissionStatus4');

    if (permissionStatus1.isGranted &&
        permissionStatus2.isGranted &&
        permissionStatus3.isGranted) {
      await checkUserLoggedIn();
    } else if (permissionStatus3.isGranted && !android) {
      await checkUserLoggedIn();
    } else {
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Permisos requeridos'),
            content: const Text(
                'No se puede seguir sin los permisos\n Por favor activalos manualmente'),
            actions: [
              TextButton(
                child: const Text('Abrir opciones de la app'),
                onPressed: () => openAppSettings(),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> checkUserLoggedIn() async {
    try {
      var session = await Amplify.Auth.fetchAuthSession();
      if (session.isSignedIn) {
        // Actualizar tokens de todos los dispositivos del usuario
        try {
          await TokenManager.refreshAllDeviceTokens();
          printLog.i('Tokens actualizados exitosamente al iniciar la aplicación');
        } catch (e) {
          printLog.e('Error actualizando tokens al iniciar: $e');
          // No bloquear el flujo de la aplicación por errores en tokens
        }
        
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/menu');
        }
      } else {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/welcome');
        }
      }
    } catch (e) {
      printLog.i('Error verificando la autenticación: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      builder: (ctx, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: Hero(
                tag: 'dragonLogo',
                child: Image.asset(
                  'assets/branch/dragon.png',
                  width: MediaQuery.of(context).size.width * 0.25,
                  height: MediaQuery.of(context).size.height * 0.25,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          );
        } else if (snapshot.hasError) {
          return Center(
            child: Text(
              'Ocurrió el siguiente error: ${snapshot.error}',
              style: const TextStyle(fontSize: 18, color: Colors.white),
            ),
          );
        } else {
          return const Scaffold(
            backgroundColor: Colors.black,
          );
        }
      },
      future: permissionCheckAndLogin(),
    );
  }
}
