import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../Devices/calefactores.dart';
import '../Devices/detectores.dart';
import '../Devices/relay.dart';
import '../aws/dynamo/dynamo.dart';
import '../aws/dynamo/dynamo_certificates.dart';
import '../aws/mqtt/mqtt.dart';
import '../master.dart';
import 'stored_data.dart';

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

  @override
  void initState() {
    super.initState();
    printLog('HOSTIAAAAAAAAAAAAAAAAAAAAAAAA');
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
        if (deviceType == '022000' || deviceType == '027000') {
          navigatorKey.currentState?.pushReplacementNamed('/calefactor');
        } else if (deviceType == '015773') {
          navigatorKey.currentState?.pushReplacementNamed('/detector');
        } else if (deviceType == '020010') {
          navigatorKey.currentState?.pushReplacementNamed('/domotica');
        } else if (deviceType == '027313') {
          navigatorKey.currentState?.pushReplacementNamed('/relay');
        }
      } else {
        showToast('Error en el dispositivo, intente nuevamente');
        myDevice.device.disconnect();
      }
    });
  }

  Future<bool> precharge() async {
    try {
      printLog('Estoy precargando');
      android ? await myDevice.device.requestMtu(255) : null;
      toolsValues = await myDevice.toolsUuid.read();
      printLog('Valores tools: $toolsValues');
      printLog('Valores info: $infoValues');
      if (!previusConnections.contains(deviceName)) {
        previusConnections.add(deviceName);
        saveDeviceList(previusConnections);
        topicsToSub.add(
            'devices_tx/${command(deviceName)}/${extractSerialNumber(deviceName)}');
        saveTopicList(topicsToSub);
        subToTopicMQTT(
            'devices_tx/${command(deviceName)}/${extractSerialNumber(deviceName)}');

        if (deviceType != '020010') {
          alexaDevices.add(deviceName);
          saveAlexaDevices(alexaDevices);
          putDevicesForAlexa(service, currentUserEmail, alexaDevices);
        }
      }

      setupToken(
          command(deviceName), extractSerialNumber(deviceName), deviceName);

      printLog('Equipo: $deviceType');

      await queryItems(
          service, command(deviceName), extractSerialNumber(deviceName));

      discNotfActivated = configNotiDsc.keys.toList().contains(deviceName);

      //Si es un calefactor
      if (deviceType == '022000' || deviceType == '027000') {
        varsValues = await myDevice.varsUuid.read();
        var parts2 = utf8.decode(varsValues).split(':');
        printLog('Valores Vars: $parts2');
        var list = await loadDevicesForDistanceControl();
        canControlDistance =
            list.contains(deviceName) ? true : parts2[0] == '0';
        printLog(
            'Puede utilizar el control por distancia: $canControlDistance');
        turnOn = parts2[2] == '1';
        trueStatus = parts2[4] == '1';
        nightMode = parts2[5] == '1';
        printLog('Estado: $turnOn');

        var parts3 = utf8.decode(toolsValues).split(':');
        final regex = RegExp(r'\((\d+)\)');
        final match = regex.firstMatch(parts3[2]);
        int users = int.parse(match!.group(1).toString());
        printLog('Hay $users conectados');
        userConnected = users > 1;
        lastUser = users;
        owner = globalDATA[
                    '${command(deviceName)}/${extractSerialNumber(deviceName)}']![
                'owner'] ??
            '';
        printLog('Owner actual: $owner');
        adminDevices = await getSecondaryAdmins(
            service, command(deviceName), extractSerialNumber(deviceName));
        printLog('Administradores: $adminDevices');

        if (owner != '') {
          if (owner == currentUserEmail) {
            deviceOwner = true;
          } else {
            deviceOwner = false;
            if (userConnected) {
            } else {
              if (adminDevices.contains(currentUserEmail)) {
                secondaryAdmin = true;
              } else {
                secondaryAdmin = false;
              }
            }
          }
        } else {
          deviceOwner = true;
        }

        await analizePayment(
            command(deviceName), extractSerialNumber(deviceName));

        if (payAT) {
          activatedAT = globalDATA[
                      '${command(deviceName)}/${extractSerialNumber(deviceName)}']
                  ?['AT'] ??
              false;
          tenant = globalDATA[
                      '${command(deviceName)}/${extractSerialNumber(deviceName)}']
                  ?['tenant'] ==
              currentUserEmail;
        } else {
          activatedAT = false;
          tenant = false;
        }

        if (canControlDistance) {
          distOffValue = globalDATA[
                      '${command(deviceName)}/${extractSerialNumber(deviceName)}']![
                  'distanceOff'] ??
              100.0;
          distOnValue = globalDATA[
                      '${command(deviceName)}/${extractSerialNumber(deviceName)}']![
                  'distanceOn'] ??
              3000.0;
          isTaskScheduled = await loadControlValue();
        }

        globalDATA
            .putIfAbsent(
                '${command(deviceName)}/${extractSerialNumber(deviceName)}',
                () => {})
            .addAll({"w_status": turnOn});
        globalDATA
            .putIfAbsent(
                '${command(deviceName)}/${extractSerialNumber(deviceName)}',
                () => {})
            .addAll({"f_status": trueStatus});

        saveGlobalData(globalDATA);
      } else if (deviceType == '015773') {
        //Si soy un detector
        workValues = await myDevice.workUuid.read();
        printLog('Valores work: $workValues');

        ppmCO = workValues[5] + (workValues[6] << 8);
        ppmCH4 = workValues[7] + (workValues[8] << 8);
        picoMaxppmCO = workValues[9] + (workValues[10] << 8);
        picoMaxppmCH4 = workValues[11] + (workValues[12] << 8);
        promedioppmCO = workValues[17] + (workValues[18] << 8);
        promedioppmCH4 = workValues[19] + (workValues[20] << 8);
        daysToExpire = workValues[21] + (workValues[22] << 8);

        globalDATA
            .putIfAbsent(
                '${command(deviceName)}/${extractSerialNumber(deviceName)}',
                () => {})
            .addAll({"ppmCO": ppmCO});
        globalDATA
            .putIfAbsent(
                '${command(deviceName)}/${extractSerialNumber(deviceName)}',
                () => {})
            .addAll({"ppmCH4": ppmCH4});
        globalDATA
            .putIfAbsent(
                '${command(deviceName)}/${extractSerialNumber(deviceName)}',
                () => {})
            .addAll({"alert": workValues[4] == 1});
        saveGlobalData(globalDATA);
      } else if (deviceType == '020010') {
        ioValues = await myDevice.ioUuid.read();
        printLog('Valores IO: $ioValues');

        owner = globalDATA[
                    '${command(deviceName)}/${extractSerialNumber(deviceName)}']![
                'owner'] ??
            '';
        printLog('Owner actual: $owner');
        adminDevices = await getSecondaryAdmins(
            service, command(deviceName), extractSerialNumber(deviceName));
        printLog('Administradores: $adminDevices');

        if (owner != '') {
          if (owner == currentUserEmail) {
            deviceOwner = true;
          } else {
            deviceOwner = false;
            if (userConnected) {
            } else {
              if (adminDevices.contains(currentUserEmail)) {
                secondaryAdmin = true;
              } else {
                secondaryAdmin = false;
              }
            }
          }
        } else {
          deviceOwner = true;
        }

        await analizePayment(
            command(deviceName), extractSerialNumber(deviceName));

        if (payAT) {
          activatedAT = globalDATA[
                      '${command(deviceName)}/${extractSerialNumber(deviceName)}']
                  ?['AT'] ??
              false;
          tenant = globalDATA[
                      '${command(deviceName)}/${extractSerialNumber(deviceName)}']
                  ?['tenant'] ==
              currentUserEmail;
        } else {
          activatedAT = false;
          tenant = false;
        }
      } else if (deviceType == '027313') {
        printLog('Cuerito quemado');
        varsValues = await myDevice.varsUuid.read();
        var parts2 = utf8.decode(varsValues).split(':');
        printLog('Valores vars: $parts2');
        turnOn = parts2[1] == '1';

        isNC = globalDATA[
                    '${command(deviceName)}/${extractSerialNumber(deviceName)}']![
                'isNC'] ??
            false;

        owner = globalDATA[
                    '${command(deviceName)}/${extractSerialNumber(deviceName)}']![
                'owner'] ??
            '';
        printLog('Owner actual: $owner');
        adminDevices = await getSecondaryAdmins(
            service, command(deviceName), extractSerialNumber(deviceName));
        printLog('Administradores: $adminDevices');

        if (owner != '') {
          if (owner == currentUserEmail) {
            deviceOwner = true;
          } else {
            deviceOwner = false;
            if (userConnected) {
            } else {
              if (adminDevices.contains(currentUserEmail)) {
                secondaryAdmin = true;
              } else {
                secondaryAdmin = false;
              }
            }
          }
        } else {
          deviceOwner = true;
        }

        await analizePayment(
            command(deviceName), extractSerialNumber(deviceName));

        if (payAT) {
          activatedAT = globalDATA[
                      '${command(deviceName)}/${extractSerialNumber(deviceName)}']
                  ?['AT'] ??
              false;
          tenant = globalDATA[
                      '${command(deviceName)}/${extractSerialNumber(deviceName)}']
                  ?['tenant'] ==
              currentUserEmail;
        } else {
          activatedAT = false;
          tenant = false;
        }

        var list = await loadDevicesForDistanceControl();
        canControlDistance =
            list.contains(deviceName) ? true : parts2[0] == '0';
        printLog(
            'Puede utilizar el control por distancia: $canControlDistance');

        if (canControlDistance) {
          distOffValue = globalDATA[
                      '${command(deviceName)}/${extractSerialNumber(deviceName)}']![
                  'distanceOff'] ??
              100.0;
          distOnValue = globalDATA[
                      '${command(deviceName)}/${extractSerialNumber(deviceName)}']![
                  'distanceOn'] ??
              3000.0;
          isTaskScheduled = await loadControlValue();
        }
      }

      return Future.value(true);
    } catch (e, stackTrace) {
      printLog('Error en la precarga $e $stackTrace');
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
                  'assets/dragon.gif',
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
                      style: const TextStyle(color: color3, fontSize: 12),
                    )),
                const SizedBox(height: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
