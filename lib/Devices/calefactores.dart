import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../aws/mqtt/mqtt.dart';
import '../master.dart';
import '../stored_data.dart';
import 'package:hugeicons/hugeicons.dart';

// VARIABLES \\

bool alreadySubTools = false;
Map<String, bool> isTaskScheduled = {};
bool trueStatus = false;
late bool nightMode;
late bool canControlDistance;

// CLASES \\

class CalefactorPage extends StatefulWidget {
  const CalefactorPage({super.key});
  @override
  CalefactorPageState createState() => CalefactorPageState();
}

class CalefactorPageState extends State<CalefactorPage> {
  var parts2 = utf8.decode(varsValues).split(':');
  late double tempValue;

  @override
  void initState() {
    super.initState();

    if (deviceOwner) {
      if (vencimientoAdmSec < 10 && vencimientoAdmSec > 0) {
        showPaymentTest(true, vencimientoAdmSec, navigatorKey.currentContext!);
      }

      if (vencimientoAT < 10 && vencimientoAT > 0) {
        showPaymentTest(false, vencimientoAT, navigatorKey.currentContext!);
      }
    }

    nickname = nicknamesMap[deviceName] ?? deviceName;
    tempValue = double.parse(parts2[1]);

    printLog('Valor temp: $tempValue');
    printLog('¿Encendido? $turnOn');
    printLog('¿Alquiler temporario? $activatedAT');
    printLog('¿Inquilino? $tenant');
    updateWifiValues(toolsValues);
    subscribeToWifiStatus();
    subscribeTrueStatus();
  }

  void updateWifiValues(List<int> data) {
    var fun = utf8.decode(data); //Wifi status | wifi ssid | ble status(users)
    fun = fun.replaceAll(RegExp(r'[^\x20-\x7E]'), '');
    printLog(fun);
    var parts = fun.split(':');
    if (parts[0] == 'WCS_CONNECTED') {
      atemp = false;
      nameOfWifi = parts[1];
      isWifiConnected = true;
      printLog('sis $isWifiConnected');
      setState(() {
        textState = 'CONECTADO';
        statusColor = Colors.green;
        wifiIcon = Icons.wifi;
        errorMessage = '';
        errorSintax = '';
        werror = false;
      });
    } else if (parts[0] == 'WCS_DISCONNECTED') {
      isWifiConnected = false;
      printLog('non $isWifiConnected');

      nameOfWifi = '';

      setState(() {
        textState = 'DESCONECTADO';
        statusColor = Colors.red;
        wifiIcon = Icons.wifi_off;
      });

      if (atemp) {
        setState(() {
          wifiIcon = Icons.warning_amber_rounded;
          werror = true;
          if (parts[1] == '202' || parts[1] == '15') {
            errorMessage = 'Contraseña incorrecta';
          } else if (parts[1] == '201') {
            errorMessage = 'La red especificada no existe';
          } else if (parts[1] == '1') {
            errorMessage = 'Error desconocido';
          } else {
            errorMessage = parts[1];
          }

          errorSintax = getWifiErrorSintax(int.parse(parts[1]));
        });
      }
    }

    setState(() {});
  }

  void subscribeToWifiStatus() async {
    printLog('Se subscribio a wifi');
    await myDevice.toolsUuid.setNotifyValue(true);

    final wifiSub =
        myDevice.toolsUuid.onValueReceived.listen((List<int> status) {
      printLog('Llegaron cositas wifi');
      updateWifiValues(status);
    });

    myDevice.device.cancelWhenDisconnected(wifiSub);
  }

  void subscribeTrueStatus() async {
    printLog('Me subscribo a vars');
    await myDevice.varsUuid.setNotifyValue(true);

    final trueStatusSub =
        myDevice.varsUuid.onValueReceived.listen((List<int> status) {
      var parts = utf8.decode(status).split(':');
      setState(() {
        if (parts[0] == '1') {
          trueStatus = true;
        } else {
          trueStatus = false;
        }
      });
    });

    myDevice.device.cancelWhenDisconnected(trueStatusSub);
  }

  void sendTemperature(int temp) {
    String data = '${command(deviceName)}[7]($temp)';
    myDevice.toolsUuid.write(data.codeUnits);
  }

  void turnDeviceOn(bool on) async {
    int fun = on ? 1 : 0;
    String data = '${command(deviceName)}[11]($fun)';
    myDevice.toolsUuid.write(data.codeUnits);
    globalDATA['${command(deviceName)}/${extractSerialNumber(deviceName)}']![
        'w_status'] = on;
    saveGlobalData(globalDATA);
    try {
      String topic =
          'devices_rx/${command(deviceName)}/${extractSerialNumber(deviceName)}';
      String topic2 =
          'devices_tx/${command(deviceName)}/${extractSerialNumber(deviceName)}';
      String message = jsonEncode({'w_status': on});
      sendMessagemqtt(topic, message);
      sendMessagemqtt(topic2, message);
    } catch (e, s) {
      printLog('Error al enviar valor a firebase $e $s');
    }
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      showToast('La ubicación esta desactivada\nPor favor enciendala');
      return Future.error('Los servicios de ubicación están deshabilitados.');
    }
    // Cuando los permisos están OK, obtenemos la ubicación actual
    return await Geolocator.getCurrentPosition();
  }

  void controlTask(bool value, String device) async {
    setState(() {
      isTaskScheduled.addAll({device: value});
    });
    if (isTaskScheduled[device]!) {
      // Programar la tarea.
      try {
        showToast('Recuerda tener la ubicación encendida.');
        String data = '${command(deviceName)}[5](1)';
        myDevice.toolsUuid.write(data.codeUnits);
        List<String> deviceControl = await loadDevicesForDistanceControl();
        deviceControl.add(deviceName);
        saveDevicesForDistanceControl(deviceControl);
        printLog(
            'Hay ${deviceControl.length} equipos con el control x distancia');
        Position position = await _determinePosition();
        Map<String, double> maplatitude = await loadLatitude();
        maplatitude.addAll({deviceName: position.latitude});
        savePositionLatitude(maplatitude);
        Map<String, double> maplongitude = await loadLongitud();
        maplongitude.addAll({deviceName: position.longitude});
        savePositionLongitud(maplongitude);

        if (deviceControl.length == 1) {
          await initializeService();
          final backService = FlutterBackgroundService();
          await backService.startService();
          backService.invoke('distanceControl');
          printLog('Servicio iniciado a las ${DateTime.now()}');
        }
      } catch (e) {
        showToast('Error al iniciar control por distancia.');
        printLog('Error al setear la ubicación $e');
      }
    } else {
      // Cancelar la tarea.
      showToast('Se cancelo el control por distancia');
      String data = '${command(deviceName)}[5](0)';
      myDevice.toolsUuid.write(data.codeUnits);
      List<String> deviceControl = await loadDevicesForDistanceControl();
      deviceControl.remove(deviceName);
      saveDevicesForDistanceControl(deviceControl);
      printLog(
          'Quedan ${deviceControl.length} equipos con el control x distancia');
      Map<String, double> maplatitude = await loadLatitude();
      maplatitude.remove(deviceName);
      savePositionLatitude(maplatitude);
      Map<String, double> maplongitude = await loadLongitud();
      maplongitude.remove(deviceName);
      savePositionLongitud(maplongitude);

      if (deviceControl.isEmpty) {
        final backService = FlutterBackgroundService();
        backService.invoke("stopService");
        backTimerDS?.cancel();
        printLog('Servicio apagado');
      }
    }
  }

  Future<bool> verifyPermission() async {
    try {
      var permissionStatus4 = await Permission.locationAlways.status;
      if (!permissionStatus4.isGranted) {
        await showDialog<void>(
          context: navigatorKey.currentContext ?? context,
          barrierDismissible: false,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              backgroundColor: const Color(0xFF252223),
              title: const Text(
                'Habilita la ubicación todo el tiempo',
                style: TextStyle(color: Color(0xFFFFFFFF)),
              ),
              content: Text(
                '$appName utiliza tu ubicación, incluso cuando la app esta cerrada o en desuso, para poder encender o apagar el calefactor en base a tu distancia con el mismo.',
                style: const TextStyle(
                  color: Color(0xFFFFFFFF),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  style: const ButtonStyle(
                    foregroundColor: WidgetStatePropertyAll(
                      Color(0xFFFFFFFF),
                    ),
                  ),
                  child: const Text('Habilitar'),
                  onPressed: () async {
                    try {
                      var permissionStatus4 =
                          await Permission.locationAlways.request();

                      if (!permissionStatus4.isGranted) {
                        await Permission.locationAlways.request();
                      }
                      permissionStatus4 =
                          await Permission.locationAlways.status;
                    } catch (e, s) {
                      printLog(e);
                      printLog(s);
                    }
                    Navigator.of(navigatorKey.currentContext ?? context)
                        .pop(); // Cierra el AlertDialog
                  },
                ),
              ],
            );
          },
        );
      }

      permissionStatus4 = await Permission.locationAlways.status;

      if (permissionStatus4.isGranted) {
        return true;
      } else {
        return false;
      }
    } catch (e, s) {
      printLog('Error al habilitar la ubi: $e');
      printLog(s);
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: color1,
      appBar: AppBar(
        backgroundColor: color3,
        title: const Text(
          'Hola',
          style: TextStyle(
            color: color0,
          ),
        ),
        leading: IconButton(
          icon: const Icon(HugeIcons.strokeRoundedArrowLeft02),
          color: color0,
          onPressed: () {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) {
                return AlertDialog(
                  backgroundColor: const Color(0xFF252223),
                  content: Row(
                    children: [
                      Image.asset('assets/dragon.gif', width: 100, height: 100),
                      Container(
                        margin: const EdgeInsets.only(left: 15),
                        child: const Text(
                          "Desconectando...",
                          style: TextStyle(color: Color(0xFFFFFFFF)),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
            Future.delayed(const Duration(seconds: 2), () async {
              await myDevice.device.disconnect();
              if (context.mounted) {
                Navigator.pop(context);
                Navigator.pushReplacementNamed(context, '/menu');
              }
            });
            return;
          },
        ),
      ),
      body: const Center(
        child: Text(''),
      ),
    );
  }
}
