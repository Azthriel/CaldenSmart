// VARIABLES \\
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../aws/mqtt/mqtt.dart';
import '../master.dart';
import '../stored_data.dart';

List<String> tipo = [];
List<String> estado = [];
List<bool> alertIO = [];
List<String> common = [];
List<String> valores = [];
late bool tracking;

// FUNCIONES \\

void controlOut(bool value, int index) {
  String fun = '$index#${value ? '1' : '0'}';
  myDevice.ioUuid.write(fun.codeUnits);

  String fun2 =
      '${tipo[index] == 'Entrada' ? '1' : '0'}:${value ? '1' : '0'}:${common[index]}';
  String topic =
      'devices_rx/${command(deviceName)}/${extractSerialNumber(deviceName)}';
  String topic2 =
      'devices_tx/${command(deviceName)}/${extractSerialNumber(deviceName)}';
  String message = jsonEncode({'io$index': fun2});
  sendMessagemqtt(topic, message);
  sendMessagemqtt(topic2, message);
  estado[index] = value ? '1' : '0';
  for (int i = 0; i < estado.length; i++) {
    String device =
        '${tipo[i] == 'Salida' ? '0' : '1'}:${estado[i]}:${common[i]}';
    globalDATA['${command(deviceName)}/${extractSerialNumber(deviceName)}']![
        'io$i'] = device;
  }

  saveGlobalData(globalDATA);
}

Future<void> changeModes(BuildContext context) {
  var parts = utf8.decode(ioValues).split('/');
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        backgroundColor: const Color(0xff1f1d20),
        title: const Text(
          'Cambiar modo:',
          style:
              TextStyle(color: Color(0xffa79986), fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < parts.length; i++) ...[
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xff4b2427),
                    borderRadius: BorderRadius.circular(20),
                    border: const Border(
                      bottom: BorderSide(color: Color(0xffa79986), width: 1),
                      right: BorderSide(color: Color(0xffa79986), width: 1),
                      left: BorderSide(color: Color(0xffa79986), width: 1),
                      top: BorderSide(color: Color(0xffa79986), width: 1),
                    ),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          subNicknamesMap['$deviceName/-/${parts[i]}'] ??
                              '${tipo[i]} ${i + 1}',
                          style: const TextStyle(
                              color: Color(0xffa79986),
                              fontSize: 25,
                              fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(
                          height: 5,
                        ),
                        tipo[i] == 'Entrada'
                            ? const Text(
                                '    ¿Cambiar de entrada a salida?    ',
                                style: TextStyle(
                                  color: Color(0xffa79986),
                                ),
                              )
                            : const Text(
                                '    ¿Cambiar de salida a entrada?    ',
                                style: TextStyle(
                                  color: Color(0xffa79986),
                                ),
                              ),
                        const SizedBox(
                          height: 10,
                        ),
                        TextButton(
                          onPressed: () {
                            String fun =
                                '${command(deviceName)}[13]($i#${tipo[i] == 'Entrada' ? '0' : '1'})';
                            printLog(fun);
                            myDevice.toolsUuid.write(fun.codeUnits);
                            Navigator.of(dialogContext).pop();
                          },
                          child: const Text(
                            'CAMBIAR',
                            style: TextStyle(
                              color: Color(0xffa79986),
                            ),
                          ),
                        ),
                        tipo[i] == 'Entrada'
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  const SizedBox(
                                    width: 30,
                                  ),
                                  const Text(
                                    'Estado común: ',
                                    style: TextStyle(
                                      color: Color(0xffa79986),
                                    ),
                                  ),
                                  Text(
                                    common[i],
                                    style: const TextStyle(
                                        color: Color(0xffa79986),
                                        fontWeight: FontWeight.bold),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    onPressed: () {
                                      String data =
                                          '${command(deviceName)}[14]($i#${common[i] == '1' ? '0' : '1'})';
                                      printLog(data);
                                      myDevice.toolsUuid.write(data.codeUnits);
                                      Navigator.of(dialogContext).pop();
                                    },
                                    icon: const Icon(
                                      Icons.change_circle_outlined,
                                      color: Color(0xffa79986),
                                    ),
                                  ),
                                  const SizedBox(
                                    width: 5,
                                  ),
                                ],
                              )
                            : const SizedBox(
                                height: 0,
                              ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(
                  height: 10,
                ),
              ],
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            style: const ButtonStyle(
              foregroundColor: WidgetStatePropertyAll(
                Color(0xffa79986),
              ),
            ),
            child: const Text('Cerrar'),
            onPressed: () {
              Navigator.of(dialogContext).pop();
            },
          ),
        ],
      );
    },
  );
}

Future<void> iosChangeModes(BuildContext context) {
  var parts = utf8.decode(ioValues).split('/');
  return showCupertinoDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) {
      return CupertinoAlertDialog(
        title: const Text(
          'Cambiar modo:',
          style: TextStyle(
              color: CupertinoColors.label, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Divider(
                color: CupertinoColors.label,
              ),
              for (var i = 0; i < parts.length; i++) ...[
                // const Divider(
                //   color: CupertinoColors.label,
                // ),
                Card(
                  color: CupertinoColors.systemGrey2,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          subNicknamesMap['$deviceName/-/${parts[i]}'] ??
                              '${tipo[i]} ${i + 1}',
                          style: const TextStyle(
                              color: CupertinoColors.label,
                              fontSize: 25,
                              fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(
                          height: 5,
                        ),
                        tipo[i] == 'Entrada'
                            ? const Text(
                                ' ¿Cambiar de entrada a salida? ',
                                style: TextStyle(
                                  color: CupertinoColors.label,
                                ),
                              )
                            : const Text(
                                ' ¿Cambiar de salida a entrada? ',
                                style: TextStyle(
                                  color: CupertinoColors.label,
                                ),
                              ),
                        const SizedBox(
                          height: 10,
                        ),
                        TextButton(
                          onPressed: () {
                            String fun =
                                '${command(deviceName)}[13]($i#${tipo[i] == 'Entrada' ? '0' : '1'})';
                            printLog(fun);
                            myDevice.toolsUuid.write(fun.codeUnits);
                            Navigator.of(dialogContext).pop();
                          },
                          child: const Text(
                            'CAMBIAR',
                            style: TextStyle(
                              color: CupertinoColors.label,
                            ),
                          ),
                        ),
                        tipo[i] == 'Entrada'
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  const SizedBox(
                                    width: 30,
                                  ),
                                  const Text(
                                    'Estado común: ',
                                    style: TextStyle(
                                      color: CupertinoColors.label,
                                    ),
                                  ),
                                  Text(
                                    common[i],
                                    style: const TextStyle(
                                        color: CupertinoColors.label,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    onPressed: () {
                                      String data =
                                          '${command(deviceName)}[14]($i#${common[i] == '1' ? '0' : '1'})';
                                      printLog(data);
                                      myDevice.toolsUuid.write(data.codeUnits);
                                      Navigator.of(dialogContext).pop();
                                    },
                                    icon: const Icon(
                                      CupertinoIcons.refresh,
                                      color: CupertinoColors.label,
                                    ),
                                  ),
                                  const SizedBox(
                                    width: 5,
                                  ),
                                ],
                              )
                            : const SizedBox(
                                height: 0,
                              ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(
                  height: 10,
                ),
              ],
              // const Divider(
              //   color: CupertinoColors.label,
              // ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            style: const ButtonStyle(
              foregroundColor: WidgetStatePropertyAll(
                CupertinoColors.label,
              ),
            ),
            child: const Text('Cerrar'),
            onPressed: () {
              Navigator.of(dialogContext).pop();
            },
          ),
        ],
      );
    },
  );
}

// CLASES \\

class DomoticaPage extends StatefulWidget {
  const DomoticaPage({super.key});
  @override
  DomoticaPageState createState() => DomoticaPageState();
}

class DomoticaPageState extends State<DomoticaPage> {
  var parts = utf8.decode(ioValues).split('/');

  @override
  initState() {
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
    updateWifiValues(toolsValues);
    subscribeToWifiStatus();
    subToIO();
    processValues(ioValues);
    notificationMap.putIfAbsent(
        '${command(deviceName)}/${extractSerialNumber(deviceName)}',
        () => List<bool>.filled(4, false));
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
        });

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
      }
    }

    setState(() {});
  }

  void subscribeToWifiStatus() async {
    printLog('Se subscribio a wifi');
    await myDevice.toolsUuid.setNotifyValue(true);

    final wifiSub =
        myDevice.toolsUuid.onValueReceived.listen((List<int> status) {
      updateWifiValues(status);
    });

    myDevice.device.cancelWhenDisconnected(wifiSub);
  }

  void processValues(List<int> values) {
    var parts = utf8.decode(values).split('/');
    valores = parts;
    tipo.clear();
    estado.clear();
    common.clear();
    alertIO.clear();

    for (int i = 0; i < parts.length; i++) {
      var equipo = parts[i].split(':');
      tipo.add(equipo[0] == '0' ? 'Salida' : 'Entrada');
      estado.add(equipo[1]);
      common.add(equipo[2]);
      alertIO.add(estado[i] != common[i]);

      printLog(
          'En la posición $i el modo es ${tipo[i]} y su estado es ${estado[i]}');
      globalDATA
          .putIfAbsent(
              '${command(deviceName)}/${extractSerialNumber(deviceName)}',
              () => {})
          .addAll({'io$i': parts[i]});
    }

    saveGlobalData(globalDATA);
    setState(() {});
  }

  void subToIO() async {
    await myDevice.ioUuid.setNotifyValue(true);
    printLog('Subscrito a IO');

    var ioSub = myDevice.ioUuid.onValueReceived.listen((event) {
      printLog('Cambio en IO');
      processValues(event);
    });

    myDevice.device.cancelWhenDisconnected(ioSub);
  }

//!Visual
  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
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
      body: deviceOwner || secondaryAdmin
          ? ListView.builder(
              itemCount: parts.length,
              itemBuilder: (context, int index) {
                // bool entrada = tipo[index] == 'Entrada';
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      height: 10,
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xffa79986),
                        borderRadius: BorderRadius.circular(20),
                        border: const Border(
                          bottom:
                              BorderSide(color: Color(0xff4b2427), width: 5),
                          right: BorderSide(color: Color(0xff4b2427), width: 5),
                          left: BorderSide(color: Color(0xff4b2427), width: 5),
                          top: BorderSide(color: Color(0xff4b2427), width: 5),
                        ),
                      ),
                      width: width - 50,
                      height: 220,
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              const SizedBox(
                                width: 20,
                              ),
                              GestureDetector(
                                  onTap: () {},
                                  child: Row(
                                    children: [
                                      Text(
                                        subNicknamesMap[
                                                '$deviceName/-/$index'] ??
                                            '${tipo[index]} $index',
                                        style: const TextStyle(
                                            color: Color(0xff3e3d38),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 30),
                                        textAlign: TextAlign.start,
                                      ),
                                      const SizedBox(
                                        width: 3,
                                      ),
                                      const Icon(
                                        Icons.edit,
                                        size: 20,
                                        color: Color(0xff3e3d38),
                                      )
                                    ],
                                  )),
                              const Spacer(),
                              Text(
                                'Tipo: ${tipo[index]}',
                                style: const TextStyle(
                                    color: Color(0xff3e3d38),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(
                                width: 20,
                              ),
                            ],
                          ),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                height: 50,
                              ),
                              Transform.scale(
                                scale: 2.5,
                                child: Switch(
                                  trackOutlineColor:
                                      const WidgetStatePropertyAll(
                                          Color(0xff4b2427)),
                                  activeColor: const Color(0xff803e2f),
                                  activeTrackColor: const Color(0xff4b2427),
                                  inactiveThumbColor: const Color(0xff4b2427),
                                  inactiveTrackColor: const Color(0xff803e2f),
                                  value: estado[index] == '1',
                                  onChanged: (value) {
                                    controlOut(value, index);
                                  },
                                ),
                              ),
                              Switch(
                                value: tracking,
                                onChanged: (valor) {
                                  setState(() {
                                    tracking = valor;
                                  });

                                  if (tracking) {
                                    devicesToTrack.add(deviceName);
                                  } else {
                                    devicesToTrack.remove(deviceName);
                                  }

                                  entryToTrack.add('$deviceName/$index');

                                  saveDeviceListToTrack(devicesToTrack);
                                  saveEntryListToTrack(entryToTrack);
                                },
                              )
                            ],
                          ),
                          const SizedBox(
                            height: 10,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(
                      height: 10,
                    ),
                  ],
                );
              },
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'No sos el dueño del equipo.\nNo puedes modificar los parámetros',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 25, color: Color(0xffa79986)),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  style: const ButtonStyle(
                    backgroundColor: WidgetStatePropertyAll(
                      Color(0xff4b2427),
                    ),
                    foregroundColor: WidgetStatePropertyAll(
                      Color(0xffa79986),
                    ),
                  ),
                  onPressed: () async {
                    var phoneNumber = '5491162232619';
                    var message =
                        'Hola, te hablo en relación a mi equipo $deviceName.\nEste mismo me dice que no soy administrador.\n*Datos del equipo:*\nCódigo de producto: ${command(deviceName)}\nNúmero de serie: ${extractSerialNumber(deviceName)}\nAdministrador actúal: ${utf8.decode(infoValues).split(':')[4]}';
                    var whatsappUrl =
                        "whatsapp://send?phone=$phoneNumber&text=${Uri.encodeFull(message)}";
                    Uri uri = Uri.parse(whatsappUrl);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri);
                    } else {
                      showToast('No se pudo abrir WhatsApp');
                    }
                  },
                  child: const Text('Servicio técnico'),
                ),
              ],
            ),
    );
  }
}
