import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../aws/dynamo/dynamo.dart';
import '../aws/dynamo/dynamo_certificates.dart';
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
  MyDevice myDevice = MyDevice();
  String _dots = '';
  int dot = 0;
  late Timer _dotTimer;
  String pc = DeviceManager.getProductCode(deviceName);

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
        switch (pc) {
          case '022000_IOT' || '027000_IOT' || '041220_IOT':
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
          case '050217_IOT':
            navigatorKey.currentState?.pushReplacementNamed('/millenium');
            break;
          case '028000_IOT':
            navigatorKey.currentState?.pushReplacementNamed('/heladera');
            break;
        }
      } else {
        showToast('Error en el dispositivo, intente nuevamente');
        myDevice.device.disconnect();
      }
    });
  }

  Future<bool> precharge() async {
    try {
      printLog.i('Estoy precargando');
      android ? await myDevice.device.requestMtu(255) : null;
      toolsValues = await myDevice.toolsUuid.read();
      printLog.i('Valores tools: $toolsValues');
      printLog.i('Valores info: $infoValues');
      if (!previusConnections.contains(deviceName)) {
        previusConnections.add(deviceName);
        putPreviusConnections(service, currentUserEmail, previusConnections);
        todosLosDispositivos.add(MapEntry('individual', deviceName));
        topicsToSub.add(
            'devices_tx/${DeviceManager.getProductCode(deviceName)}/${DeviceManager.extractSerialNumber(deviceName)}');
        subToTopicMQTT(
            'devices_tx/${DeviceManager.getProductCode(deviceName)}/${DeviceManager.extractSerialNumber(deviceName)}');
      }

      setupToken(DeviceManager.getProductCode(deviceName),
          DeviceManager.extractSerialNumber(deviceName), deviceName);

      String ubi = (await Geolocator.getCurrentPosition()).toString();

      await saveLocation(service, DeviceManager.getProductCode(deviceName),
          DeviceManager.extractSerialNumber(deviceName), ubi);

      await queryItems(service, DeviceManager.getProductCode(deviceName),
          DeviceManager.extractSerialNumber(deviceName));

      discNotfActivated = configNotiDsc.keys.toList().contains(deviceName);

      var parts3 = utf8.decode(toolsValues).split(':');
      final regex = RegExp(r'\((\d+)\)');
      final match = regex.firstMatch(parts3[2]);
      int users = int.parse(match!.group(1).toString());
      printLog.i('Hay $users conectados');
      userConnected = users > 1;

      quickAccesActivated = quickAccess.contains(deviceName);

      final fileName = await Versioner.fetchLatestFirmwareFile(
          DeviceManager.getProductCode(deviceName), hardwareVersion);

      lastSV = Versioner.extractSV(fileName, hardwareVersion);

      printLog.i('Ultimo firmware: $lastSV', color: 'Naranja');

      if (lastSV != null) {
        shouldUpdateDevice =
            (lastSV != softwareVersion) || softwareVersion.contains('_F');
      }

      switch (pc) {
        case '022000_IOT' || '027000_IOT' || '041220_IOT':
          varsValues = await myDevice.varsUuid.read();
          var parts2 = utf8.decode(varsValues).split(':');
          printLog.i('Valores Vars: $parts2');
          var list = await loadDevicesForDistanceControl();
          canControlDistance =
              list.contains(deviceName) ? true : parts2[0] == '0';
          printLog.i(
              'Puede utilizar el control por distancia: $canControlDistance');
          turnOn = parts2[2] == '1';
          trueStatus = parts2[4] == '1';
          nightMode = parts2[5] == '1';
          printLog.i('Estado: $turnOn');
          // if (parts2.length >= 9) {
          //   manualControl = factoryMode ? parts2[9] == '1' : parts2[8] == '1';
          // }
          if (parts2.length > 10) {
            wifiUnstable = parts2[10] == '1';
          }
          lastUser = users;
          owner = globalDATA[
                      '${DeviceManager.getProductCode(deviceName)}/${DeviceManager.extractSerialNumber(deviceName)}']![
                  'owner'] ??
              '';
          printLog.i('Owner actual: $owner');
          adminDevices = await getSecondaryAdmins(
              service,
              DeviceManager.getProductCode(deviceName),
              DeviceManager.extractSerialNumber(deviceName));
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

          await analizePayment(DeviceManager.getProductCode(deviceName),
              DeviceManager.extractSerialNumber(deviceName));

          if (payAT) {
            activatedAT = globalDATA[
                        '${DeviceManager.getProductCode(deviceName)}/${DeviceManager.extractSerialNumber(deviceName)}']
                    ?['AT'] ??
                false;
            tenant = globalDATA[
                        '${DeviceManager.getProductCode(deviceName)}/${DeviceManager.extractSerialNumber(deviceName)}']
                    ?['tenant'] ==
                currentUserEmail;
          } else {
            activatedAT = false;
            tenant = false;
          }

          if (canControlDistance) {
            distOffValue = globalDATA[
                        '${DeviceManager.getProductCode(deviceName)}/${DeviceManager.extractSerialNumber(deviceName)}']![
                    'distanceOff'] ??
                100.0;
            distOnValue = globalDATA[
                        '${DeviceManager.getProductCode(deviceName)}/${DeviceManager.extractSerialNumber(deviceName)}']![
                    'distanceOn'] ??
                3000.0;
            isTaskScheduled = await loadControlValue();
          }

          globalDATA
              .putIfAbsent(
                  '${DeviceManager.getProductCode(deviceName)}/${DeviceManager.extractSerialNumber(deviceName)}',
                  () => {})
              .addAll({"w_status": turnOn});
          globalDATA
              .putIfAbsent(
                  '${DeviceManager.getProductCode(deviceName)}/${DeviceManager.extractSerialNumber(deviceName)}',
                  () => {})
              .addAll({"f_status": trueStatus});

          saveGlobalData(globalDATA);
          break;
        case '015773_IOT':
          workValues = await myDevice.workUuid.read();
          printLog.i('Valores work: $workValues');

          ppmCO = workValues[5] + (workValues[6] << 8);
          ppmCH4 = workValues[7] + (workValues[8] << 8);
          picoMaxppmCO = workValues[9] + (workValues[10] << 8);
          picoMaxppmCH4 = workValues[11] + (workValues[12] << 8);
          promedioppmCO = workValues[17] + (workValues[18] << 8);
          promedioppmCH4 = workValues[19] + (workValues[20] << 8);
          daysToExpire = workValues[21] + (workValues[22] << 8);

          globalDATA
              .putIfAbsent(
                  '${DeviceManager.getProductCode(deviceName)}/${DeviceManager.extractSerialNumber(deviceName)}',
                  () => {})
              .addAll({"ppmCO": ppmCO});
          globalDATA
              .putIfAbsent(
                  '${DeviceManager.getProductCode(deviceName)}/${DeviceManager.extractSerialNumber(deviceName)}',
                  () => {})
              .addAll({"ppmCH4": ppmCH4});
          globalDATA
              .putIfAbsent(
                  '${DeviceManager.getProductCode(deviceName)}/${DeviceManager.extractSerialNumber(deviceName)}',
                  () => {})
              .addAll({"alert": workValues[4] == 1});
          saveGlobalData(globalDATA);
          break;
        case '020010_IOT':
          ioValues = await myDevice.ioUuid.read();
          printLog.i('Valores IO: $ioValues || ${utf8.decode(ioValues)}');
          varsValues = await myDevice.varsUuid.read();
          printLog.i('Valores VARS: $varsValues || ${utf8.decode(varsValues)}');
          var parts = utf8.decode(varsValues).split(':');
          var list = await loadDevicesForDistanceControl();
          canControlDistance =
              list.contains(deviceName) ? true : parts[0] == '0';
          printLog.i(
              'Puede utilizar el control por distancia: $canControlDistance');

          owner = globalDATA[
                      '${DeviceManager.getProductCode(deviceName)}/${DeviceManager.extractSerialNumber(deviceName)}']![
                  'owner'] ??
              '';
          printLog.i('Owner actual: $owner');
          adminDevices = await getSecondaryAdmins(
              service,
              DeviceManager.getProductCode(deviceName),
              DeviceManager.extractSerialNumber(deviceName));
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

          await analizePayment(DeviceManager.getProductCode(deviceName),
              DeviceManager.extractSerialNumber(deviceName));

          if (payAT) {
            activatedAT = globalDATA[
                        '${DeviceManager.getProductCode(deviceName)}/${DeviceManager.extractSerialNumber(deviceName)}']
                    ?['AT'] ??
                false;
            tenant = globalDATA[
                        '${DeviceManager.getProductCode(deviceName)}/${DeviceManager.extractSerialNumber(deviceName)}']
                    ?['tenant'] ==
                currentUserEmail;
          } else {
            activatedAT = false;
            tenant = false;
          }

          if (canControlDistance) {
            distOffValue = globalDATA[
                        '${DeviceManager.getProductCode(deviceName)}/${DeviceManager.extractSerialNumber(deviceName)}']![
                    'distanceOff'] ??
                100.0;
            distOnValue = globalDATA[
                        '${DeviceManager.getProductCode(deviceName)}/${DeviceManager.extractSerialNumber(deviceName)}']![
                    'distanceOn'] ??
                3000.0;
            isTaskScheduled = await loadControlValue();
          }
          break;
        case '020020_IOT':
          ioValues = await myDevice.ioUuid.read();
          printLog.i('Valores IO: $ioValues || ${utf8.decode(ioValues)}');
          varsValues = await myDevice.varsUuid.read();
          printLog.i('Valores VARS: $varsValues || ${utf8.decode(varsValues)}');
          var parts = utf8.decode(varsValues).split(':');
          var list = await loadDevicesForDistanceControl();
          canControlDistance =
              list.contains(deviceName) ? true : parts[0] == '0';
          printLog.i(
              'Puede utilizar el control por distancia: $canControlDistance');

          owner = globalDATA[
                      '${DeviceManager.getProductCode(deviceName)}/${DeviceManager.extractSerialNumber(deviceName)}']![
                  'owner'] ??
              '';
          printLog.i('Owner actual: $owner');
          adminDevices = await getSecondaryAdmins(
              service,
              DeviceManager.getProductCode(deviceName),
              DeviceManager.extractSerialNumber(deviceName));
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

          await analizePayment(DeviceManager.getProductCode(deviceName),
              DeviceManager.extractSerialNumber(deviceName));

          if (payAT) {
            activatedAT = globalDATA[
                        '${DeviceManager.getProductCode(deviceName)}/${DeviceManager.extractSerialNumber(deviceName)}']
                    ?['AT'] ??
                false;
            tenant = globalDATA[
                        '${DeviceManager.getProductCode(deviceName)}/${DeviceManager.extractSerialNumber(deviceName)}']
                    ?['tenant'] ==
                currentUserEmail;
          } else {
            activatedAT = false;
            tenant = false;
          }

          if (canControlDistance) {
            distOffValue = globalDATA[
                        '${DeviceManager.getProductCode(deviceName)}/${DeviceManager.extractSerialNumber(deviceName)}']![
                    'distanceOff'] ??
                100.0;
            distOnValue = globalDATA[
                        '${DeviceManager.getProductCode(deviceName)}/${DeviceManager.extractSerialNumber(deviceName)}']![
                    'distanceOn'] ??
                3000.0;
            isTaskScheduled = await loadControlValue();
          }
          break;
        case '027313_IOT':
          if (Versioner.isPosterior(hardwareVersion, '241220A')) {
            ioValues = await myDevice.ioUuid.read();
            printLog.i('Valores IO: $ioValues || ${utf8.decode(ioValues)}');
            varsValues = await myDevice.varsUuid.read();
            printLog
                .i('Valores VARS: $varsValues || ${utf8.decode(varsValues)}');
          } else {
            varsValues = await myDevice.varsUuid.read();
            printLog
                .i('Valores VARS: $varsValues || ${utf8.decode(varsValues)}');
            var parts2 = utf8.decode(varsValues).split(':');
            turnOn = parts2[1] == '1';
          }
          var parts = utf8.decode(varsValues).split(':');

          var list = await loadDevicesForDistanceControl();
          canControlDistance =
              list.contains(deviceName) ? true : parts[0] == '0';
          printLog.i(
              'Puede utilizar el control por distancia: $canControlDistance');

          if (canControlDistance) {
            distOffValue = globalDATA[
                        '${DeviceManager.getProductCode(deviceName)}/${DeviceManager.extractSerialNumber(deviceName)}']![
                    'distanceOff'] ??
                100.0;
            distOnValue = globalDATA[
                        '${DeviceManager.getProductCode(deviceName)}/${DeviceManager.extractSerialNumber(deviceName)}']![
                    'distanceOn'] ??
                3000.0;
            isTaskScheduled = await loadControlValue();
          }

          isNC = globalDATA[
                      '${DeviceManager.getProductCode(deviceName)}/${DeviceManager.extractSerialNumber(deviceName)}']![
                  'isNC'] ??
              false;

          owner = globalDATA[
                      '${DeviceManager.getProductCode(deviceName)}/${DeviceManager.extractSerialNumber(deviceName)}']![
                  'owner'] ??
              '';
          printLog.i('Owner actual: $owner');
          adminDevices = await getSecondaryAdmins(
              service,
              DeviceManager.getProductCode(deviceName),
              DeviceManager.extractSerialNumber(deviceName));
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

          await analizePayment(DeviceManager.getProductCode(deviceName),
              DeviceManager.extractSerialNumber(deviceName));

          if (payAT) {
            activatedAT = globalDATA[
                        '${DeviceManager.getProductCode(deviceName)}/${DeviceManager.extractSerialNumber(deviceName)}']
                    ?['AT'] ??
                false;
            tenant = globalDATA[
                        '${DeviceManager.getProductCode(deviceName)}/${DeviceManager.extractSerialNumber(deviceName)}']
                    ?['tenant'] ==
                currentUserEmail;
          } else {
            activatedAT = false;
            tenant = false;
          }

          break;
        case '024011_IOT':
          varsValues = await myDevice.varsUuid.read();
          printLog.i('Valores VARS: $varsValues || ${utf8.decode(varsValues)}');
          var parts = utf8.decode(varsValues).split(':');
          var list = await loadDevicesForDistanceControl();
          canControlDistance =
              list.contains(deviceName) ? true : parts[0] == '0';
          printLog.i(
              'Puede utilizar el control por distancia: $canControlDistance');
          owner = globalDATA[
                      '${DeviceManager.getProductCode(deviceName)}/${DeviceManager.extractSerialNumber(deviceName)}']![
                  'owner'] ??
              '';
          printLog.i('Owner actual: $owner');
          adminDevices = await getSecondaryAdmins(
              service,
              DeviceManager.getProductCode(deviceName),
              DeviceManager.extractSerialNumber(deviceName));
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

          await analizePayment(DeviceManager.getProductCode(deviceName),
              DeviceManager.extractSerialNumber(deviceName));

          if (payAT) {
            activatedAT = globalDATA[
                        '${DeviceManager.getProductCode(deviceName)}/${DeviceManager.extractSerialNumber(deviceName)}']
                    ?['AT'] ??
                false;
            tenant = globalDATA[
                        '${DeviceManager.getProductCode(deviceName)}/${DeviceManager.extractSerialNumber(deviceName)}']
                    ?['tenant'] ==
                currentUserEmail;
          } else {
            activatedAT = false;
            tenant = false;
          }

          rollerSavedLength = globalDATA[
                      '${DeviceManager.getProductCode(deviceName)}/${DeviceManager.extractSerialNumber(deviceName)}']![
                  'rollerSavedLength'] ??
              '';

          break;
        case '050217_IOT' || '028000_IOT':
          varsValues = await myDevice.varsUuid.read();
          var parts2 = utf8.decode(varsValues).split(':');
          printLog.i('Valores Vars: $parts2');
          var list = await loadDevicesForDistanceControl();
          canControlDistance =
              list.contains(deviceName) ? true : parts2[0] == '0';
          printLog.i(
              'Puede utilizar el control por distancia: $canControlDistance');
          turnOn = parts2[2] == '1';
          trueStatus = parts2[4] == '1';
          printLog.i('Estado: $turnOn');
          lastUser = users;
          owner = globalDATA[
                      '${DeviceManager.getProductCode(deviceName)}/${DeviceManager.extractSerialNumber(deviceName)}']![
                  'owner'] ??
              '';
          printLog.i('Owner actual: $owner');
          adminDevices = await getSecondaryAdmins(
              service,
              DeviceManager.getProductCode(deviceName),
              DeviceManager.extractSerialNumber(deviceName));
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

          await analizePayment(DeviceManager.getProductCode(deviceName),
              DeviceManager.extractSerialNumber(deviceName));

          if (payAT) {
            activatedAT = globalDATA[
                        '${DeviceManager.getProductCode(deviceName)}/${DeviceManager.extractSerialNumber(deviceName)}']
                    ?['AT'] ??
                false;
            tenant = globalDATA[
                        '${DeviceManager.getProductCode(deviceName)}/${DeviceManager.extractSerialNumber(deviceName)}']
                    ?['tenant'] ==
                currentUserEmail;
          } else {
            activatedAT = false;
            tenant = false;
          }

          if (canControlDistance) {
            distOffValue = globalDATA[
                        '${DeviceManager.getProductCode(deviceName)}/${DeviceManager.extractSerialNumber(deviceName)}']![
                    'distanceOff'] ??
                100.0;
            distOnValue = globalDATA[
                        '${DeviceManager.getProductCode(deviceName)}/${DeviceManager.extractSerialNumber(deviceName)}']![
                    'distanceOn'] ??
                3000.0;
            isTaskScheduled = await loadControlValue();
          }

          globalDATA
              .putIfAbsent(
                  '${DeviceManager.getProductCode(deviceName)}/${DeviceManager.extractSerialNumber(deviceName)}',
                  () => {})
              .addAll({"w_status": turnOn});
          globalDATA
              .putIfAbsent(
                  '${DeviceManager.getProductCode(deviceName)}/${DeviceManager.extractSerialNumber(deviceName)}',
                  () => {})
              .addAll({"f_status": trueStatus});

          saveGlobalData(globalDATA);
          break;
      }

      return Future.value(true);
    } catch (e, stackTrace) {
      printLog.i('Error en la precarga $e $stackTrace');
      showToast('Error en la precarga');
      // handleManualError('$e', '$stackTrace');
      return Future.value(false);
    }
  }

  @override
  void dispose() {
    _dotTimer.cancel();
    super.dispose();
  }

//!Visual
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: color3,
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
                      color: color1,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    children: <TextSpan>[
                      TextSpan(
                        text: _dots,
                        style: const TextStyle(
                          color: color1,
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
                      color: color1,
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
