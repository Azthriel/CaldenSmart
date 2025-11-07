import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../aws/dynamo/dynamo.dart';
import '../aws/mqtt/mqtt.dart';
import '../master.dart';
import 'stored_data.dart';
import 'package:caldensmart/logger.dart';

class LoadingPage extends StatefulWidget {
  const LoadingPage({super.key});
  @override
  LoadState createState() => LoadState();
}

class LoadState extends State<LoadingPage> {
  BluetoothManager bluetoothManager = BluetoothManager();
  String _dots = '';
  int dot = 0;
  late Timer _dotTimer;
  final pc = DeviceManager.getProductCode(deviceName);
  final sn = DeviceManager.extractSerialNumber(deviceName);
  bool riego = false;

  @override
  void initState() {
    super.initState();
    printLog.i('HOSTIAAAAAAAAAAAAAAAAAAAAAAAA');

    _dotTimer =
        Timer.periodic(const Duration(milliseconds: 800), (Timer timer) {
      setState(
        () {
          dot++;
          if (dot >= 4) dot = 0;
          _dots = '.' * dot;
        },
      );
    });

    precharge().then((precharge) {
      if (precharge == true) {
        showToast('Dispositivo conectado exitosamente');
        if (riego) {
          navigatorKey.currentState?.pushReplacementNamed('/riego');
          return;
        }

        switch (pc) {
          case '022000_IOT' || '027000_IOT':
            navigatorKey.currentState?.pushReplacementNamed('/calefactor');
            break;
          case '015773_IOT':
            navigatorKey.currentState?.pushReplacementNamed('/detector');
            break;
          case '020010_IOT':
            navigatorKey.currentState?.pushReplacementNamed('/domotica');
            break;
          case '020020_IOT':
            navigatorKey.currentState?.pushReplacementNamed('/modulo');
            break;
          case '024011_IOT':
            navigatorKey.currentState?.pushReplacementNamed('/roller');
            break;
          case '027313_IOT':
            if (Versioner.isPosterior(hardwareVersion, '241220A')) {
              navigatorKey.currentState?.pushReplacementNamed('/rele1i1o');
            } else {
              navigatorKey.currentState?.pushReplacementNamed('/rele');
            }
            break;

          case '028000_IOT':
            navigatorKey.currentState?.pushReplacementNamed('/heladera');
            break;
          case '023430_IOT':
            navigatorKey.currentState?.pushReplacementNamed('/termometro');
            break;
          case '027345_IOT':
            navigatorKey.currentState?.pushReplacementNamed('/termotanque');
            break;
        }
      } else {
        showToast('Error en el dispositivo, intente nuevamente');
        bluetoothManager.device.disconnect();
      }
    });
  }

  @override
  void dispose() {
    _dotTimer.cancel();
    super.dispose();
  }

  Future<bool> precharge() async {
    try {
      printLog.i('Estoy precargando');
      android ? await bluetoothManager.device.requestMtu(255) : null;
      toolsValues = await bluetoothManager.toolsUuid.read();
      printLog.i('Valores tools: $toolsValues');
      printLog.i('Valores info: $infoValues');

      // Usar la función segura para agregar dispositivos
      String result = await safeAddDevice(currentUserEmail, deviceName);

      switch (result) {
        case 'added':
          // Dispositivo agregado exitosamente - agregar a listas locales
          todosLosDispositivos.add(MapEntry('individual', deviceName));
          topicsToSub.add('devices_tx/$pc/$sn');
          subToTopicMQTT('devices_tx/$pc/$sn');
          printLog.i('Dispositivo $deviceName agregado exitosamente');
          break;

        case 'exists':
          // Dispositivo ya existía - no hacer nada adicional
          printLog.i('Dispositivo $deviceName ya estaba registrado');
          break;

        case 'error':
          printLog.e(
              'No se pudo agregar el dispositivo $deviceName de forma segura');
          // Aquí podrías mostrar un mensaje al usuario o implementar lógica de recuperación
          break;
      }

      await addToActiveUsers(pc, sn, currentUserEmail);

      String ubi = (await Geolocator.getCurrentPosition()).toString();

      await saveLocation(pc, sn, ubi);

      await queryItems(pc, sn);

      if (softwareVersion != globalDATA['$pc/$sn']?['SoftwareVersion'] ||
          hardwareVersion != globalDATA['$pc/$sn']?['HardwareVersion']) {
        await putVersions(
          pc,
          sn,
          hardwareVersion,
          softwareVersion,
        );
        globalDATA
            .putIfAbsent('$pc/$sn', () => {})
            .addAll({"SoftwareVersion": softwareVersion});
        globalDATA
            .putIfAbsent('$pc/$sn', () => {})
            .addAll({"HardwareVersion": hardwareVersion});
      }

      riego = globalDATA['$pc/$sn']?['riegoActive'] ?? false;
      printLog.i('Riego activo: $riego', color: 'Naranja');

      canUseDevice = await checkAdminTimePermission(deviceName);

      specialUser = await isSpecialUser(currentUserEmail);

      labProcessFinished =
          globalDATA['$pc/$sn']?['LabProcessFinished'] ?? false;

      printLog.i('Usuario especial: $specialUser');

      discNotfActivated = configNotiDsc.keys.toList().contains(deviceName);

      var parts3 = utf8.decode(toolsValues).split(':');
      final regex = RegExp(r'\((\d+)\)');
      final match = regex.firstMatch(parts3[2]);
      int users = int.parse(match!.group(1).toString());
      lastUser = users;
      printLog.i('Hay $users conectados');
      userConnected = users > 1;

      quickAccesActivated = quickAccess.contains(deviceName);
      try {
        final fileName =
            await Versioner.fetchLatestFirmwareFile(pc, hardwareVersion);

        lastSV = Versioner.extractSV(fileName, hardwareVersion);

        printLog.i('Ultimo firmware: $lastSV', color: 'Naranja');

        if (lastSV != null) {
          shouldUpdateDevice =
              (lastSV != softwareVersion) || softwareVersion.contains('_F');
        }
      } catch (e) {
        printLog.e(
            'No se pudo verificar la versión de firmware desde GitHub: $e',
            color: 'Amarillo');
        printLog.i('Continuando sin verificación de actualizaciones...',
            color: 'Verde');

        lastSV = null;
        shouldUpdateDevice = false;
      }
      switch (pc) {
        case '022000_IOT' || '027000_IOT' || '027345_IOT':
          varsValues = await bluetoothManager.varsUuid.read();
          var parts2 = utf8.decode(varsValues).split(':');
          printLog.i('Valores Vars: $parts2', color: 'Naranja');

          if (parts2[0] == '0' || parts2[0] == '1') {
            distanceControlActive =
                globalDATA['$pc/$sn']?['distanceControlActive'] ?? false;

            tempValue = double.parse(parts2[1]);
            turnOn = parts2[2] == '1';
            trueStatus = parts2[4] == '1';
            nightMode = parts2[5] == '1';
            actualTemp = parts2[6];
            printLog.i('Estado: $turnOn');
          } else {
            distanceControlActive =
                globalDATA['$pc/$sn']?['distanceControlActive'] ?? false;

            tempValue = double.parse(parts2[0]);
            turnOn = parts2[1] == '1';
            trueStatus = parts2[3] == '1';
            nightMode = parts2[4] == '1';
            actualTemp = parts2[5];
            printLog.i('Estado: $turnOn');
          }

          owner = globalDATA['$pc/$sn']!['owner'] ?? '';
          printLog.i('Owner actual: $owner');
          adminDevices =
              (globalDATA['$pc/$sn']?['secondary_admin'] as List<dynamic>?)
                      ?.cast<String>() ??
                  [];
          printLog.i('Administradores: $adminDevices');

          if (owner != '') {
            if (owner == currentUserEmail) {
              deviceOwner = true;
            } else {
              deviceOwner = false;
              if (adminDevices.contains(currentUserEmail)) {
                secondaryAdmin = true;
              } else {
                secondaryAdmin = false;
              }
            }
          } else {
            deviceOwner = true;
          }

          await analizePayment(pc, sn);

          if (payAT) {
            activatedAT = globalDATA['$pc/$sn']?['AT'] ?? false;
            tenant = globalDATA['$pc/$sn']?['tenant'] == currentUserEmail;
          } else {
            activatedAT = false;
            tenant = false;
          }

          distOffValue = globalDATA['$pc/$sn']!['distanceOff'] ?? 100.0;
          distOnValue = globalDATA['$pc/$sn']!['distanceOn'] ?? 3000.0;

          globalDATA
              .putIfAbsent('$pc/$sn', () => {})
              .addAll({"w_status": turnOn});
          globalDATA
              .putIfAbsent('$pc/$sn', () => {})
              .addAll({"f_status": trueStatus});

          saveGlobalData(globalDATA);
          break;
        case '015773_IOT':
          workValues = await bluetoothManager.workUuid.read();
          printLog.i('Valores work: $workValues');

          ppmCO = workValues[5] + (workValues[6] << 8);
          ppmCH4 = workValues[7] + (workValues[8] << 8);
          picoMaxppmCO = workValues[9] + (workValues[10] << 8);
          picoMaxppmCH4 = workValues[11] + (workValues[12] << 8);
          promedioppmCO = workValues[17] + (workValues[18] << 8);
          promedioppmCH4 = workValues[19] + (workValues[20] << 8);
          daysToExpire = workValues[21] + (workValues[22] << 8);

          globalDATA.putIfAbsent('$pc/$sn', () => {}).addAll({"ppmCO": ppmCO});
          globalDATA
              .putIfAbsent('$pc/$sn', () => {})
              .addAll({"ppmCH4": ppmCH4});
          globalDATA
              .putIfAbsent('$pc/$sn', () => {})
              .addAll({"alert": workValues[4] == 1});
          saveGlobalData(globalDATA);
          break;
        case '020010_IOT':
          ioValues = await bluetoothManager.ioUuid.read();
          printLog.i('Valores IO: $ioValues || ${utf8.decode(ioValues)}');
          varsValues = await bluetoothManager.varsUuid.read();
          printLog.i('Valores VARS: $varsValues || ${utf8.decode(varsValues)}');

          distanceControlActive =
              globalDATA['$pc/$sn']?['distanceControlActive'] ?? false;

          owner = globalDATA['$pc/$sn']!['owner'] ?? '';
          printLog.i('Owner actual: $owner');
          adminDevices =
              (globalDATA['$pc/$sn']?['secondary_admin'] as List<dynamic>?)
                      ?.cast<String>() ??
                  [];
          printLog.i('Administradores: $adminDevices');

          if (owner != '') {
            if (owner == currentUserEmail) {
              deviceOwner = true;
            } else {
              deviceOwner = false;
              if (adminDevices.contains(currentUserEmail)) {
                secondaryAdmin = true;
              } else {
                secondaryAdmin = false;
              }
            }
          } else {
            deviceOwner = true;
          }

          await analizePayment(pc, sn);

          if (payAT) {
            activatedAT = globalDATA['$pc/$sn']?['AT'] ?? false;
            tenant = globalDATA['$pc/$sn']?['tenant'] == currentUserEmail;
          } else {
            activatedAT = false;
            tenant = false;
          }

          distOffValue = globalDATA['$pc/$sn']!['distanceOff'] ?? 100.0;
          distOnValue = globalDATA['$pc/$sn']!['distanceOn'] ?? 3000.0;

          break;
        case '020020_IOT':
          ioValues = await bluetoothManager.ioUuid.read();
          printLog.i('Valores IO: $ioValues || ${utf8.decode(ioValues)}');
          varsValues = await bluetoothManager.varsUuid.read();
          printLog.i('Valores VARS: $varsValues || ${utf8.decode(varsValues)}');

          distanceControlActive =
              globalDATA['$pc/$sn']?['distanceControlActive'] ?? false;

          owner = globalDATA['$pc/$sn']!['owner'] ?? '';
          printLog.i('Owner actual: $owner');
          adminDevices =
              (globalDATA['$pc/$sn']?['secondary_admin'] as List<dynamic>?)
                      ?.cast<String>() ??
                  [];
          printLog.i('Administradores: $adminDevices');

          if (owner != '') {
            if (owner == currentUserEmail) {
              deviceOwner = true;
            } else {
              deviceOwner = false;
              if (adminDevices.contains(currentUserEmail)) {
                secondaryAdmin = true;
              } else {
                secondaryAdmin = false;
              }
            }
          } else {
            deviceOwner = true;
          }

          await analizePayment(
            pc,
            sn,
          );

          if (payAT) {
            activatedAT = globalDATA['$pc/$sn']?['AT'] ?? false;
            tenant = globalDATA['$pc/$sn']?['tenant'] == currentUserEmail;
          } else {
            activatedAT = false;
            tenant = false;
          }

          distOffValue = globalDATA['$pc/$sn']!['distanceOff'] ?? 100.0;
          distOnValue = globalDATA['$pc/$sn']!['distanceOn'] ?? 3000.0;
          break;
        case '027313_IOT':
          if (Versioner.isPosterior(hardwareVersion, '241220A')) {
            ioValues = await bluetoothManager.ioUuid.read();
            printLog.i('Valores IO: $ioValues || ${utf8.decode(ioValues)}');
            varsValues = await bluetoothManager.varsUuid.read();
            printLog
                .i('Valores VARS: $varsValues || ${utf8.decode(varsValues)}');
          } else {
            varsValues = await bluetoothManager.varsUuid.read();
            printLog
                .i('Valores VARS: $varsValues || ${utf8.decode(varsValues)}');
            var parts2 = utf8.decode(varsValues).split(':');
            turnOn = parts2[1] == '1';
          }

          distanceControlActive =
              globalDATA['$pc/$sn']?['distanceControlActive'] ?? false;
          distOffValue = globalDATA['$pc/$sn']!['distanceOff'] ?? 100.0;
          distOnValue = globalDATA['$pc/$sn']!['distanceOn'] ?? 3000.0;

          isNC = globalDATA['$pc/$sn']!['isNC'] ?? false;

          owner = globalDATA['$pc/$sn']!['owner'] ?? '';
          printLog.i('Owner actual: $owner');
          adminDevices =
              (globalDATA['$pc/$sn']?['secondary_admin'] as List<dynamic>?)
                      ?.cast<String>() ??
                  [];
          printLog.i('Administradores: $adminDevices');

          if (owner != '') {
            if (owner == currentUserEmail) {
              deviceOwner = true;
            } else {
              deviceOwner = false;
              if (adminDevices.contains(currentUserEmail)) {
                secondaryAdmin = true;
              } else {
                secondaryAdmin = false;
              }
            }
          } else {
            deviceOwner = true;
          }

          await analizePayment(
            pc,
            sn,
          );

          if (payAT) {
            activatedAT = globalDATA['$pc/$sn']?['AT'] ?? false;
            tenant = globalDATA['$pc/$sn']?['tenant'] == currentUserEmail;
          } else {
            activatedAT = false;
            tenant = false;
          }

          break;
        case '024011_IOT':
          varsValues = await bluetoothManager.varsUuid.read();
          printLog.i('Valores VARS: $varsValues || ${utf8.decode(varsValues)}');
          distanceControlActive =
              globalDATA['$pc/$sn']?['distanceControlActive'] ?? false;
          owner = globalDATA['$pc/$sn']!['owner'] ?? '';
          printLog.i('Owner actual: $owner');
          adminDevices =
              (globalDATA['$pc/$sn']?['secondary_admin'] as List<dynamic>?)
                      ?.cast<String>() ??
                  [];
          printLog.i('Administradores: $adminDevices');

          if (owner != '') {
            if (owner == currentUserEmail) {
              deviceOwner = true;
            } else {
              deviceOwner = false;
              if (adminDevices.contains(currentUserEmail)) {
                secondaryAdmin = true;
              } else {
                secondaryAdmin = false;
              }
            }
          } else {
            deviceOwner = true;
          }

          await analizePayment(
            pc,
            sn,
          );

          if (payAT) {
            activatedAT = globalDATA['$pc/$sn']?['AT'] ?? false;
            tenant = globalDATA['$pc/$sn']?['tenant'] == currentUserEmail;
          } else {
            activatedAT = false;
            tenant = false;
          }

          rollerSavedLength = globalDATA['$pc/$sn']!['rollerSavedLength'] ?? '';

          break;
        case '028000_IOT':
          varsValues = await bluetoothManager.varsUuid.read();
          var parts2 = utf8.decode(varsValues).split(':');
          printLog.i('Valores Vars: $parts2');
          distanceControlActive =
              globalDATA['$pc/$sn']?['distanceControlActive'] ?? false;
          turnOn = parts2[2] == '1';
          trueStatus = parts2[4] == '1';
          printLog.i('Estado: $turnOn');
          owner = globalDATA['$pc/$sn']!['owner'] ?? '';
          printLog.i('Owner actual: $owner');
          adminDevices =
              (globalDATA['$pc/$sn']?['secondary_admin'] as List<dynamic>?)
                      ?.cast<String>() ??
                  [];
          printLog.i('Administradores: $adminDevices');

          if (owner != '') {
            if (owner == currentUserEmail) {
              deviceOwner = true;
            } else {
              deviceOwner = false;
              if (adminDevices.contains(currentUserEmail)) {
                secondaryAdmin = true;
              } else {
                secondaryAdmin = false;
              }
            }
          } else {
            deviceOwner = true;
          }

          await analizePayment(
            pc,
            sn,
          );

          if (payAT) {
            activatedAT = globalDATA['$pc/$sn']?['AT'] ?? false;
            tenant = globalDATA['$pc/$sn']?['tenant'] == currentUserEmail;
          } else {
            activatedAT = false;
            tenant = false;
          }

          distOffValue = globalDATA['$pc/$sn']!['distanceOff'] ?? 100.0;
          distOnValue = globalDATA['$pc/$sn']!['distanceOn'] ?? 3000.0;

          globalDATA
              .putIfAbsent('$pc/$sn', () => {})
              .addAll({"w_status": turnOn});
          globalDATA
              .putIfAbsent('$pc/$sn', () => {})
              .addAll({"f_status": trueStatus});

          saveGlobalData(globalDATA);
          break;
        case '023430_IOT':
          varsValues = await bluetoothManager.varsUuid.read();
          var partes = utf8.decode(varsValues).split(':');
          printLog.i('Valores VARS: $varsValues || ${utf8.decode(varsValues)}');
          actualTemp = partes[0];
          // offsetTemp = partes[1];
          awsInit = partes[2] == '1';
          alertMaxFlag = partes[3] == '1';
          alertMinFlag = partes[4] == '1';
          alertMaxTemp = partes[5];
          alertMinTemp = partes[6];
          // tempMap = partes[7] == '1';
          break;
        default:
          printLog.i('Dispositivo no reconocido');
          return Future.value(false);
      }

      return Future.value(true);
    } catch (e, stackTrace) {
      printLog.e('Error en la precarga $e $stackTrace');
      showToast('Error en la precarga');
      // handleManualError('$e', '$stackTrace');
      return Future.value(false);
    }
  }

//!Visual
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: color1,
      body: Center(
        child: Stack(
          alignment: AlignmentDirectional.center,
          children: <Widget>[
            Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/branch/dragon.gif',
                  width: 150,
                  height: 150,
                ),
                const SizedBox(height: 20),
                RichText(
                  text: TextSpan(
                    text: 'Cargando',
                    style: const TextStyle(
                      color: color0,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    children: <TextSpan>[
                      TextSpan(
                        text: _dots,
                        style: const TextStyle(
                          color: color0,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Text(
                    'Versión $appVersionNumber',
                    style: const TextStyle(
                      color: color0,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(
                  height: 20,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
