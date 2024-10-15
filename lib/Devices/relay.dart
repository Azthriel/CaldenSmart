import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../aws/mqtt/mqtt.dart';
import '../master.dart';
import '../stored_data.dart';

// VARIABLES \\

late bool tracking;
bool isNC = false;

// CLASES \\

class RelayPage extends StatefulWidget {
  const RelayPage({super.key});
  @override
  RelayPageState createState() => RelayPageState();
}

class RelayPageState extends State<RelayPage> {
  var parts2 = utf8.decode(varsValues).split(':');
  late double tempValue;

  @override
  void initState() {
    super.initState();

    tracking = devicesToTrack.contains(deviceName);

    if (deviceOwner) {
      if (vencimientoAdmSec < 10 && vencimientoAdmSec > 0) {
        showPaymentTest(true, vencimientoAdmSec, navigatorKey.currentContext!);
      }

      if (vencimientoAT < 10 && vencimientoAT > 0) {
        showPaymentTest(false, vencimientoAT, navigatorKey.currentContext!);
      }
    }

    nickname = nicknamesMap[deviceName] ?? deviceName;

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
        turnOn = parts[0] == '1';
      });
    });

    myDevice.device.cancelWhenDisconnected(trueStatusSub);
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

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, A) {
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
      child: Scaffold(
          appBar: AppBar(
            backgroundColor: color3,
            title: GestureDetector(
              onTap: () async {
                TextEditingController nicknameController =
                    TextEditingController(text: nickname);
                showAlertDialog(
                  context,
                  const Text(
                    'Editar identificación del dispositivo',
                    style: TextStyle(color: color0),
                  ),
                  TextField(
                    style: const TextStyle(color: color0),
                    cursorColor: const Color(0xFFFFFFFF),
                    controller: nicknameController,
                    decoration: const InputDecoration(
                      hintText:
                          "Introduce tu nueva identificación del dispositivo",
                      hintStyle: TextStyle(color: color0),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: color0),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: color0),
                      ),
                    ),
                  ),
                  <Widget>[
                    TextButton(
                      style: const ButtonStyle(
                        foregroundColor: WidgetStatePropertyAll(
                          color0,
                        ),
                      ),
                      child: const Text('Cancelar'),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                    TextButton(
                      style: const ButtonStyle(
                        foregroundColor: WidgetStatePropertyAll(
                          color0,
                        ),
                      ),
                      child: const Text('Guardar'),
                      onPressed: () {
                        setState(() {
                          String newNickname = nicknameController.text;
                          nickname = newNickname;
                          nicknamesMap[deviceName] = newNickname;
                          saveNicknamesMap(nicknamesMap);
                          printLog('$nicknamesMap');
                        });
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                );
              },
              child: Row(
                children: [
                  Text(
                    nickname,
                    style: const TextStyle(color: color0),
                  ),
                  const SizedBox(width: 3),
                  const Icon(Icons.edit, size: 20, color: color0)
                ],
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new),
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
                          Image.asset('assets/dragon.gif',
                              width: 100, height: 100),
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
            actions: [
              IconButton(
                icon: Icon(wifiIcon, color: color0),
                onPressed: () {
                  wifiText(context);
                },
              ),
            ],
          ),
          backgroundColor: color1,
          resizeToAvoidBottomInset: false,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  isNC
                      ? turnOn
                          ? 'ABIERTO'
                          : 'CERRADO'
                      : turnOn
                          ? 'CERRADO'
                          : 'ABIERTO',
                  style: const TextStyle(
                      color: color3, fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(
                  height: 50,
                ),
                Transform.scale(
                  scale: 3.0,
                  child: Switch(
                    value: turnOn,
                    onChanged: (value) {
                      turnDeviceOn(value);
                      setState(() {
                        turnOn = value;
                      });
                    },
                  ),
                ),
                const SizedBox(
                  height: 80,
                ),
                const Text(
                  'Trackeo:',
                  style: TextStyle(
                      color: color3, fontSize: 22, fontWeight: FontWeight.bold),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color3,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 40, vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30.0),
                    ),
                    elevation: 5,
                  ),
                  onPressed: () {
                    if (tracking) {
                      {
                        setState(() {
                          tracking = false;
                        });

                        devicesToTrack.remove(deviceName);

                        saveDeviceListToTrack(devicesToTrack);
                      }
                    } else {
                      showAlertDialog(
                        context,
                        const Text(
                          '¿Estás seguro que quiere iniciar el trackeo Bluetooth?',
                        ),
                        const Text(
                          'Habilitar está función hará que la aplicación usé más recursos de lo común, si a pesar de esto decides utilizarlo es bajo tu responsabilidad.',
                        ),
                        [
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            child: const Text('Cancelar'),
                          ),
                          TextButton(
                            onPressed: () async {
                              setState(() {
                                tracking = true;
                              });
                              devicesToTrack.add(deviceName);
                              saveDeviceListToTrack(devicesToTrack);
                              SharedPreferences prefs =
                                  await SharedPreferences.getInstance();
                              bool hasInitService =
                                  prefs.getBool('hasInitService') ?? false;
                              printLog(
                                  'Se inició el servicio? $hasInitService');
                              if (!hasInitService) {
                                printLog('Empiezo');
                                await initializeService();
                                printLog('Acabe');
                              }
                              await Future.delayed(const Duration(seconds: 30));
                              final backService = FlutterBackgroundService();
                              printLog('Xd');
                              backService.invoke('trackLocation');
                              Navigator.pop(
                                  navigatorKey.currentContext ?? context);
                            },
                            child: const Text(
                              'Aceptar',
                            ),
                          )
                        ],
                      );
                    }
                  },
                  child: Text(
                    tracking ? 'Dejar de tackear' : 'Iniciar trackeo',
                    style: const TextStyle(
                      color: color0,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
          )),
    );
  }
}
