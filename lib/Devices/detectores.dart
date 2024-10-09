import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:hugeicons/hugeicons.dart';
import '../master.dart';
import '../stored_data.dart';

// VARIABLES \\

List<int> workValues = [];
int lastCO = 0;
int lastCH4 = 0;
int ppmCO = 0;
int ppmCH4 = 0;
int picoMaxppmCO = 0;
int picoMaxppmCH4 = 0;
int promedioppmCO = 0;
int promedioppmCH4 = 0;
int daysToExpire = 0;
bool alert = false;

// CLASES \\

class DetectorPage extends StatefulWidget {
  const DetectorPage({super.key});
  @override
  DetectorPageState createState() => DetectorPageState();
}

class DetectorPageState extends State<DetectorPage> {
  bool alert = false;
  String _textToShow = 'AIRE PURO';
  bool online =
      globalDATA['${command(deviceName)}/${extractSerialNumber(deviceName)}']![
              'cstate'] ??
          false;

  @override
  void initState() {
    super.initState();

    nickname = nicknamesMap[deviceName] ?? deviceName;
    _subscribeToWorkCharacteristic();
    subscribeToWifiStatus();
    updateWifiValues(toolsValues);
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
      online = true;
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
      online = false;
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
      updateWifiValues(status);
    });

    myDevice.device.cancelWhenDisconnected(wifiSub);
  }

  void _subscribeToWorkCharacteristic() async {
    await myDevice.workUuid.setNotifyValue(true);
    printLog('Me suscribí a work');
    final workSub =
        myDevice.workUuid.onValueReceived.listen((List<int> status) {
      printLog('Cositas: $status');
      setState(() {
        alert = status[4] == 1;
        ppmCO = status[5] + (status[6] << 8);
        ppmCH4 = status[7] + (status[8] << 8);
        picoMaxppmCO = status[9] + (status[10] << 8);
        picoMaxppmCH4 = status[11] + (status[12] << 8);
        promedioppmCO = status[17] + (status[18] << 8);
        promedioppmCH4 = status[19] + (status[20] << 8);
        daysToExpire = status[21] + (status[22] << 8);
        printLog('Parte baja CO: ${status[9]} // Parte alta CO: ${status[10]}');
        printLog('PPMCO: $ppmCO');
        printLog(
            'Parte baja CH4: ${status[11]} // Parte alta CH4: ${status[12]}');
        printLog('PPMCH4: $ppmCH4');
        printLog('Alerta: $alert');
        _textToShow = alert ? 'PELIGRO' : 'AIRE PURO';
        printLog(_textToShow);
      });
    });

    myDevice.device.cancelWhenDisconnected(workSub);
  }

  //*-Funciones de deslizamiento entre pantallas-*\\
  int _selectedIndex = 0; // Índice del ícono seleccionado
  final PageController _pageController = PageController();

  void _onItemTapped(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    setState(() {
      _selectedIndex = index;
    });
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
          if(context.mounted){
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
              setupToken(command(deviceName), extractSerialNumber(deviceName),
                  deviceName);
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
        body: PageView(
          controller: _pageController,
          onPageChanged: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          children: [
            Column(
              children: [
                Expanded(
                  flex: 1,
                  child: SizedBox(
                    width: 350,
                    height: 100,
                    child: Card(
                      color: color3,
                      elevation: 4,
                      margin: const EdgeInsets.symmetric(vertical: 18.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color: _textToShow == 'PELIGRO'
                              ? Colors.red[700]!
                              : Colors.green[700]!,
                          width: 2,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(
                              _textToShow == 'PELIGRO'
                                  ? HugeIcons.strokeRoundedHouse01
                                  : HugeIcons.strokeRoundedHouse01,
                              color: color0,
                              size: 50,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    'Estado del Aire',
                                    style:
                                        TextStyle(color: color0, fontSize: 22),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    _textToShow,
                                    style: TextStyle(
                                      color: _textToShow == 'PELIGRO'
                                          ? Colors.red
                                          : Colors.green,
                                      fontSize: 35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: SizedBox(
                    width: 350,
                    height: 100,
                    child: Card(
                      color: color3,
                      elevation: 4,
                      margin: const EdgeInsets.symmetric(vertical: 18.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color: online ? Colors.blue[700]! : Colors.red[700]!,
                          width: 2,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(
                              online
                                  ? HugeIcons.strokeRoundedHouse01
                                  : Icons.wifi_off_outlined,
                              color: color0,
                              size: 50,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    'Estado de conexión',
                                    style:
                                        TextStyle(color: color0, fontSize: 22),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    online ? 'En Línea' : 'Desconectado',
                                    style: TextStyle(
                                      color: online ? Colors.green : Colors.red,
                                      fontSize: 30,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: SizedBox(
                    width: 350,
                    height: 100,
                    child: Card(
                      color: color3,
                      elevation: 4,
                      margin: const EdgeInsets.symmetric(vertical: 18.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color: Colors.orange[700]!,
                          width: 2,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Icon(
                              HugeIcons.strokeRoundedHouse01,
                              color: color0,
                              size: 50,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    'Caducidad del sensor',
                                    style:
                                        TextStyle(color: color0, fontSize: 22),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    '$daysToExpire días restantes',
                                    style: const TextStyle(
                                      color: Color.fromARGB(255, 199, 138, 25),
                                      fontSize: 23,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // Nueva Página 2
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () async {
                      await initializeService();
                      final backService = FlutterBackgroundService();

                      backService.invoke('trackLocation');
                    },
                    child: const Text('Test'),
                  ),
                ],
              ),
            ),
            // Nueva Página 3
            const Center(child: Text('Página 3')),
            // Nueva Página 4
            const Center(child: Text('Página 4')),
          ],
        ),
        bottomNavigationBar: CurvedNavigationBar(
          index: _selectedIndex,
          color: color3,
          items: const <Widget>[
            Icon(HugeIcons.strokeRoundedHouse01, size: 30, color: color0),
            Icon(HugeIcons.strokeRoundedHouse01, size: 30, color: color0),
            Icon(HugeIcons.strokeRoundedHouse01, size: 30, color: color0),
            Icon(HugeIcons.strokeRoundedHouse01, size: 30, color: color0),
          ],
          onTap: (index) {
            _onItemTapped(index);
          },
          backgroundColor: color1,
        ),
      ),
    );
  }
}
