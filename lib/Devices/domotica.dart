import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../aws/mqtt/mqtt.dart';
import '../master.dart';
import '../stored_data.dart';

// VARIABLES \\

List<String> tipo = [];
List<String> estado = [];
List<bool> alertIO = [];
List<String> common = [];
List<String> valores = [];
late bool tracking;
late List<bool> _selectedPins;

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

    processSelectedPins();

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

  Future<void> processSelectedPins() async {
    List<String> pins = await loadPinToTrack(deviceName);
    _selectedPins = List<bool>.filled(parts.length, false);

    for (int i = 0; i < pins.length; i++) {
      pins.contains(i.toString())
          ? _selectedPins[i] = true
          : _selectedPins[i] = false;
    }
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

  Future<void> _openTrackingDialog() async {
    bool fun = false;
    List<bool> tempSelectedPins = List<bool>.from(_selectedPins);

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (BuildContext context, Animation<double> animation,
          Animation<double> secondaryAnimation) {
        double screenWidth = MediaQuery.of(context).size.width;
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: 300.0,
                  maxWidth: screenWidth - 20,
                ),
                child: IntrinsicWidth(
                  child: Container(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          spreadRadius: 1,
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Card(
                      color: color3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30.0),
                      ),
                      elevation: 24,
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.topCenter,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 70, 20, 20),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Center(
                                  child: DefaultTextStyle(
                                    style: GoogleFonts.poppins(
                                      color: color0,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    child: const Text(
                                      'Selecciona los pines para trackear',
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Center(
                                  child: SingleChildScrollView(
                                    child: ListBody(
                                      children:
                                          List.generate(parts.length, (index) {
                                        return CheckboxListTile(
                                          title: Text(
                                            subNicknamesMap[
                                                    '$deviceName/-/$index'] ??
                                                'Pin $index',
                                            style: GoogleFonts.poppins(
                                              color: color0,
                                              fontSize: 16,
                                            ),
                                          ),
                                          value: tempSelectedPins[index],
                                          activeColor: color6,
                                          onChanged: (bool? value) {
                                            setState(() {
                                              tempSelectedPins[index] =
                                                  value ?? false;
                                            });
                                          },
                                        );
                                      }),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 30),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    TextButton(
                                      style: TextButton.styleFrom(
                                        foregroundColor: color0,
                                        backgroundColor: color3,
                                      ),
                                      onPressed: () {
                                        fun = false;
                                        Navigator.of(context).pop();
                                      },
                                      child: const Text('Cancelar'),
                                    ),
                                    const SizedBox(width: 10),
                                    TextButton(
                                      style: TextButton.styleFrom(
                                        foregroundColor: color0,
                                        backgroundColor: color3,
                                      ),
                                      onPressed: () async {
                                        if (tempSelectedPins.contains(true)) {
                                          List<String> pins =
                                              await loadPinToTrack(deviceName);
                                          setState(() {
                                            _selectedPins = List<bool>.from(
                                                tempSelectedPins);

                                            for (int i = 0;
                                                i < _selectedPins.length;
                                                i++) {
                                              _selectedPins[i] &&
                                                      !pins.contains(
                                                          i.toString())
                                                  ? pins.add(i.toString())
                                                  : null;
                                            }
                                          });
                                          await savePinToTrack(
                                              pins, deviceName);

                                          printLog(
                                              'When haces tus momos en flutter :v');
                                          fun = true;
                                          context.mounted
                                              ? Navigator.of(context).pop()
                                              : printLog("Contextn't");
                                        } else {
                                          showToast(
                                              'Por favor, selecciona al menos una opción.');
                                        }
                                      },
                                      child: const Text('Guardar'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Positioned(
                            top: -50,
                            child: Material(
                              elevation: 10,
                              shape: const CircleBorder(),
                              shadowColor: Colors.black.withOpacity(0.4),
                              child: CircleAvatar(
                                radius: 50,
                                backgroundColor: color3,
                                child: Image.asset(
                                  'assets/dragon.png',
                                  width: 60,
                                  height: 60,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOut,
          ),
          child: ScaleTransition(
            scale: CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOut,
            ),
            child: child,
          ),
        );
      },
    );

    printLog('ME WHEN YOUR MOM WHEN ME WHEN YOUR MOM $fun');
    if (fun) {
      printLog('Pov: Sos re onichan mal');
      setState(() {
        tracking = true;
      });
      devicesToTrack.add(deviceName);
      await saveDeviceListToTrack(devicesToTrack);
      printLog('Equipo $devicesToTrack');
      SharedPreferences prefs = await SharedPreferences.getInstance();
      bool hasInitService = prefs.getBool('hasInitService') ?? false;
      printLog('Se inició el servicio? $hasInitService');
      if (!hasInitService) {
        printLog('Empiezo');
        await initializeService();
        printLog('Acabe');
      }

      await Future.delayed(const Duration(seconds: 30));
      final backService = FlutterBackgroundService();
      printLog('Xd');
      backService.invoke('trackLocation');
    }
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
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: color3,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30.0),
              ),
              elevation: 5,
            ),
            onPressed: () {
              if (tracking) {
                {
                  showAlertDialog(
                    context,
                    const Text(
                      '¿Seguro que quiere cancelar el tackeo?',
                    ),
                    const Text(
                      'Deshabilitar hará que puedas controlarlo manual.\nSi quieres volver a utilizar el trackeo deberás habilitarlo nuevamente',
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
                            tracking = false;
                          });
                          devicesToTrack.remove(deviceName);
                          saveDeviceListToTrack(devicesToTrack);
                          List<String> jijeo = [];
                          savePinToTrack(jijeo, deviceName);

                          context.mounted
                              ? Navigator.of(context).pop()
                              : printLog("Contextn't");
                        },
                        child: const Text(
                          'Aceptar',
                        ),
                      )
                    ],
                  );
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
                        context.mounted
                            ? Navigator.of(context).pop()
                            : printLog("Contextn't");
                        await _openTrackingDialog();
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
                      height: 250,
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
                              const SizedBox(
                                height: 10,
                              ),
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

                // bool entrada = tipo[index] == 'Entrada';
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
