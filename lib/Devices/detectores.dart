import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:google_fonts/google_fonts.dart';
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
double brightnessLevel = 50.0;
bool alert = false;

// CLASES \\

class DetectorPage extends StatefulWidget {
  const DetectorPage({super.key});
  @override
  DetectorPageState createState() => DetectorPageState();
}

class DetectorPageState extends State<DetectorPage> {
  int _selectedIndex = 0;
  int _selectedNotificationOption = 0;
  bool _showNotificationOptions = false;
  bool _isNotificationActive = false;

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

  void _sendValueToBle(int value) async {
    try {
      final data = [value];
      myDevice.lightUuid.write(data, withoutResponse: true);
    } catch (e, stackTrace) {
      printLog('Error al mandar el valor del brillo $e $stackTrace');
      // handleManualError(e, stackTrace);
    }
  }

//!Visual
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
                false,
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
            // Página 1: Estado del Aire, Estado de conexión, Caducidad del sensor
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Estado del Aire
                  Expanded(
                    child: AnimatedOpacity(
                      opacity: 1.0,
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeInOut,
                      child: Card(
                        color: color3,
                        elevation: 6,
                        margin: const EdgeInsets.symmetric(vertical: 10.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                          side: BorderSide(
                            color: _textToShow == 'PELIGRO'
                                ? Colors.red[700]!
                                : Colors.green[700]!,
                            width: 2,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 500),
                                transitionBuilder: (Widget child,
                                    Animation<double> animation) {
                                  return ScaleTransition(
                                    scale: animation,
                                    child: child,
                                  );
                                },
                                child: Icon(
                                  _textToShow == 'PELIGRO'
                                      ? Icons.warning_amber_rounded
                                      : Icons.check_circle_rounded,
                                  key: ValueKey<String>(_textToShow),
                                  color: _textToShow == 'PELIGRO'
                                      ? Colors.red
                                      : Colors.green,
                                  size: 50,
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Estado del Aire',
                                      style: TextStyle(
                                        color: color0,
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      _textToShow,
                                      style: TextStyle(
                                        color: _textToShow == 'PELIGRO'
                                            ? Colors.red
                                            : Colors.green,
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
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
                  // Estado de conexión (Wifi)
                  Expanded(
                    child: AnimatedOpacity(
                      opacity: 1.0,
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeInOut,
                      child: Card(
                        color: color3,
                        elevation: 6,
                        margin: const EdgeInsets.symmetric(vertical: 10.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                          side: const BorderSide(
                            color: Color(0xFF10BB96),
                            width: 2,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 500),
                                transitionBuilder: (Widget child,
                                    Animation<double> animation) {
                                  return ScaleTransition(
                                    scale: animation,
                                    child: child,
                                  );
                                },
                                child: Icon(
                                  online ? Icons.wifi : Icons.wifi_off_outlined,
                                  key: ValueKey<bool>(online),
                                  color: const Color(0xFF10BB96),
                                  size: 50,
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Estado de conexión',
                                      style: TextStyle(
                                        color: color0,
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      online ? 'En Línea' : 'Desconectado',
                                      style: TextStyle(
                                        color: online
                                            ? const Color(0xFF10BB96)
                                            : Colors.red,
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
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
                  // Caducidad del sensor
                  Expanded(
                    child: AnimatedOpacity(
                      opacity: 1.0,
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeInOut,
                      child: Card(
                        color: color3,
                        elevation: 6,
                        margin: const EdgeInsets.symmetric(vertical: 10.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                          side: const BorderSide(
                            color: Color(0xFF18B2C7),
                            width: 2,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.timer,
                                color: Color(0xFF18B2C7),
                                size: 50,
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Caducidad del sensor',
                                      style: TextStyle(
                                        color: color0,
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      '$daysToExpire días restantes',
                                      style: const TextStyle(
                                        color: Color(0xFF18B2C7),
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
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
            ),
            // Página 2: Gas y CO
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Tarjeta de Gas
                  Expanded(
                    child: AnimatedOpacity(
                      opacity: 1.0,
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeInOut,
                      child: Card(
                        color: color3,
                        elevation: 6,
                        margin: const EdgeInsets.symmetric(vertical: 10.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                          side: const BorderSide(
                            color: Color(0xFF10BB96),
                            width: 2,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Row(
                            children: [
                              const Icon(
                                HugeIcons.strokeRoundedFire,
                                color: Color(0xFF10BB96),
                                size: 50,
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text(
                                      'GAS',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: color0,
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    const Text(
                                      'Atmósfera explosiva',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: color0,
                                        fontSize: 22,
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    const Divider(
                                      color: Colors.white54,
                                      thickness: 1,
                                    ),
                                    const SizedBox(height: 20),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          "${(ppmCH4 / 500).round()}%",
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 36,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        const Text(
                                          'LIE',
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 20,
                                          ),
                                        ),
                                      ],
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
                  // Tarjeta de CO
                  Expanded(
                    child: AnimatedOpacity(
                      opacity: 1.0,
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeInOut,
                      child: Card(
                        color: color3,
                        elevation: 6,
                        margin: const EdgeInsets.symmetric(vertical: 10.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                          side: const BorderSide(
                            color: Color(0xFF18B2C7),
                            width: 2,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.co2,
                                color: Color(0xFF18B2C7),
                                size: 60,
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text(
                                      'CO',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: color0,
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    const Text(
                                      'Monóxido de carbono',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: color0,
                                        fontSize: 22,
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    const Divider(
                                      color: Colors.white54,
                                      thickness: 1,
                                    ),
                                    const SizedBox(height: 20),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          ppmCO.toString(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 36,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        const Text(
                                          'PPM',
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 20,
                                          ),
                                        ),
                                      ],
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
            ),
            // Página 3: Pico Máximo PPM CH4 y Pico Máximo PPM CO
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Tarjeta Pico Máximo PPM CH4
                  Expanded(
                    child: AnimatedOpacity(
                      opacity: 1.0,
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeInOut,
                      child: Card(
                        color: color3,
                        elevation: 6,
                        margin: const EdgeInsets.symmetric(vertical: 10.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                          side: const BorderSide(
                            color: Color(0xFF10BB96),
                            width: 2,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.trending_up,
                                color: Color(0xFF10BB96),
                                size: 50,
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text(
                                      'Pico máximo',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: color0,
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    const Text(
                                      'PPM CH4',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: color0,
                                        fontSize: 22,
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    const Divider(
                                      color: Colors.white54,
                                      thickness: 1,
                                    ),
                                    const SizedBox(height: 20),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          picoMaxppmCH4.toString(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 36,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        const Text(
                                          'PPM',
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 20,
                                          ),
                                        ),
                                      ],
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
                  // Tarjeta Pico Máximo PPM CO
                  Expanded(
                    child: AnimatedOpacity(
                      opacity: 1.0,
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeInOut,
                      child: Card(
                        color: color3,
                        elevation: 6,
                        margin: const EdgeInsets.symmetric(vertical: 10.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                          side: const BorderSide(
                            color: Color(0xFF18B2C7),
                            width: 2,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.trending_up,
                                color: Color(0xFF18B2C7),
                                size: 50,
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text(
                                      'Pico máximo',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: color0,
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    const Text(
                                      'PPM CO',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: color0,
                                        fontSize: 22,
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    const Divider(
                                      color: Colors.white54,
                                      thickness: 1,
                                    ),
                                    const SizedBox(height: 20),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          promedioppmCO.toString(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 36,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        const Text(
                                          'PPM',
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 20,
                                          ),
                                        ),
                                      ],
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
            ),
            // Página 4: Promedio PPM CH4 y Promedio PPM CO
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Tarjeta Promedio PPM CH4
                  Expanded(
                    child: AnimatedOpacity(
                      opacity: 1.0,
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeInOut,
                      child: Card(
                        color: color3,
                        elevation: 6,
                        margin: const EdgeInsets.symmetric(vertical: 10.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                          side: const BorderSide(
                            color: Color(0xFF10BB96),
                            width: 2,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Row(
                            children: [
                              const Icon(
                                HugeIcons.strokeRoundedChartLineData03,
                                color: Color(0xFF10BB96),
                                size: 50,
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text(
                                      'Promedio',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: color0,
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    const Text(
                                      'PPM CH4',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: color0,
                                        fontSize: 22,
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    const Divider(
                                      color: Colors.white54,
                                      thickness: 1,
                                    ),
                                    const SizedBox(height: 20),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          promedioppmCH4.toString(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 36,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        const Text(
                                          'PPM',
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 20,
                                          ),
                                        ),
                                      ],
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
                  // Tarjeta Promedio PPM CO
                  Expanded(
                    child: AnimatedOpacity(
                      opacity: 1.0,
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeInOut,
                      child: Card(
                        color: color3,
                        elevation: 6,
                        margin: const EdgeInsets.symmetric(vertical: 10.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                          side: const BorderSide(
                            color: Color(0xFF18B2C7),
                            width: 2,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Row(
                            children: [
                              const Icon(
                                HugeIcons.strokeRoundedChartLineData03,
                                color: Color(0xFF18B2C7),
                                size: 50,
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text(
                                      'Promedio',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: color0,
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    const Text(
                                      'PPM CO',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: color0,
                                        fontSize: 22,
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    const Divider(
                                      color: Colors.white54,
                                      thickness: 1,
                                    ),
                                    const SizedBox(height: 20),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          promedioppmCO.toString(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 36,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        const Text(
                                          'PPM',
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 20,
                                          ),
                                        ),
                                      ],
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
            ),
            // Página 5: Modificar el brillo de la lámpara
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Título "Brillo del display" en la parte superior
                  Text(
                    'Brillo del display',
                    style: GoogleFonts.poppins(
                      textStyle: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey,
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Icono de la bombilla
                      Icon(
                        Icons.lightbulb,
                        size: 200,
                        color: Colors.yellow
                            .withOpacity((brightnessLevel + 20) / 120),
                      ),

                      const SizedBox(width: 20),

                      // Slider vertical para ajustar el brillo
                      Container(
                        height: 350,
                        width: 70,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(40),
                          color: Colors.grey.withOpacity(0.1),
                        ),
                        child: Stack(
                          alignment: Alignment.bottomCenter,
                          children: [
                            // Relleno de la barra con el gradiente
                            Align(
                              alignment: Alignment.bottomCenter,
                              child: Container(
                                width: 70,
                                height: (brightnessLevel > 0
                                    ? ((brightnessLevel / 100) * 350)
                                        .clamp(40, 350)
                                    : 40),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(40),
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFB7E2E7),
                                      Color(0xFFB2EBF2),
                                      Color(0xFF80DEEA),
                                      Color(0xFF26C6DA),
                                      Color(0xFF00ACC1),
                                    ],
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                  ),
                                ),
                              ),
                            ),

                            // Slider invisible que controla el relleno
                            Positioned.fill(
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 70,
                                  thumbShape: const RoundSliderThumbShape(
                                      enabledThumbRadius: 0),
                                  overlayShape: SliderComponentShape.noOverlay,
                                  thumbColor: Colors.transparent,
                                  activeTrackColor: Colors.transparent,
                                  inactiveTrackColor: Colors.transparent,
                                ),
                                child: RotatedBox(
                                  quarterTurns: 3,
                                  child: Slider(
                                    value: brightnessLevel,
                                    min: 0,
                                    max: 100,
                                    onChanged: (newValue) {
                                      setState(() {
                                        brightnessLevel = newValue;
                                      });

                                      _sendValueToBle(brightnessLevel.toInt());
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const Spacer(),

                  // versiones de hardware y software
                  Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 20),
                    decoration: BoxDecoration(
                      color: color3,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Versión de Hardware $hardwareVersion',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        textStyle: const TextStyle(
                          color: color0,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 20),
                    decoration: BoxDecoration(
                      color: color3,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Versión de Software $softwareVersion',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        textStyle: const TextStyle(
                          color: color0,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            //Página 6
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Título
                    Text(
                      'Configuraciones',
                      style: GoogleFonts.poppins(
                        textStyle: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueGrey,
                        ),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 30),

                    // Botón 1: Cambiar imagen del dispositivo
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          //TODO: acción para cambiar la imagen del dispositivo
                        },
                        style: ElevatedButton.styleFrom(
                          foregroundColor: color0,
                          backgroundColor: color3,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                            side: const BorderSide(
                              color: Color(0xFF10BB96),
                              width: 2,
                            ),
                          ),
                        ),
                        child: const Text(
                          'Cambiar imagen del dispositivo',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Botón 2: Activar/Desactivar notificación de desconexión
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (_isNotificationActive) {
                            showAlertDialog(
                              context,
                              true,
                              const Text('Confirmar Desactivación'),
                              const Text(
                                  '¿Estás seguro de que deseas desactivar la notificación de desconexión?'),
                              [
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                  },
                                  child: const Text('Cancelar'),
                                ),
                                TextButton(
                                  onPressed: () async {
                                    // Actualizar el estado para desactivar la notificación
                                    setState(() {
                                      _isNotificationActive = false;
                                      _showNotificationOptions = false;
                                    });

                                    // Actualizar la configuración: eliminar la configuración de notificación para el dispositivo actual
                                    configNotiDsc.removeWhere(
                                        (key, value) => key == deviceName);
                                    await saveconfigNotiDsc(configNotiDsc);

                                    if (context.mounted) {
                                      Navigator.of(context).pop();
                                    }
                                  },
                                  child: const Text('Aceptar'),
                                ),
                              ],
                            );
                          } else {
                            setState(() {
                              _showNotificationOptions =
                                  !_showNotificationOptions;
                            });
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          foregroundColor: color0,
                          backgroundColor: color3,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                            side: const BorderSide(
                              color: Color(0xFF10BB96),
                              width: 2,
                            ),
                          ),
                        ),
                        child: Text(
                          _isNotificationActive
                              ? 'Desactivar notificación de desconexión'
                              : 'Activar notificación de desconexión',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),

                    // Tarjeta con descripción y opciones de notificación
                    AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      child: _showNotificationOptions
                          ? Card(
                              color: color3,
                              elevation: 6,
                              margin: const EdgeInsets.symmetric(
                                  vertical: 10.0, horizontal: 20.0),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                                side: const BorderSide(
                                  color: Color(0xFF18B2C7),
                                  width: 2,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(20.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      'Selecciona cuándo deseas recibir una notificación en caso de que el dispositivo permanezca desconectado:',
                                      style: TextStyle(
                                        color: color0,
                                        fontSize: 16,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 20),
                                    RadioListTile<int>(
                                      value: 0,
                                      groupValue: _selectedNotificationOption,
                                      onChanged: (int? value) {
                                        setState(() {
                                          _selectedNotificationOption = value!;
                                        });
                                      },
                                      title: const Text(
                                        'Instantáneo',
                                        style: TextStyle(
                                          color: color0,
                                          fontSize: 18,
                                        ),
                                      ),
                                      activeColor: const Color(0xFF10BB96),
                                    ),
                                    RadioListTile<int>(
                                      value: 1,
                                      groupValue: _selectedNotificationOption,
                                      onChanged: (int? value) {
                                        setState(() {
                                          _selectedNotificationOption = value!;
                                        });
                                      },
                                      title: const Text(
                                        'Si permanece 10 minutos desconectado',
                                        style: TextStyle(
                                          color: color0,
                                          fontSize: 18,
                                        ),
                                      ),
                                      activeColor: const Color(0xFF10BB96),
                                    ),
                                    RadioListTile<int>(
                                      value: 2,
                                      groupValue: _selectedNotificationOption,
                                      onChanged: (int? value) {
                                        setState(() {
                                          _selectedNotificationOption = value!;
                                        });
                                      },
                                      title: const Text(
                                        'Si permanece 1 hora desconectado',
                                        style: TextStyle(
                                          color: color0,
                                          fontSize: 18,
                                        ),
                                      ),
                                      activeColor: const Color(0xFF10BB96),
                                    ),
                                    const SizedBox(height: 20),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed: () async {
                                          setState(() {
                                            _isNotificationActive = true;
                                            _showNotificationOptions = false;
                                          });

                                          configNotiDsc.addAll({
                                            deviceName:
                                                _selectedNotificationOption
                                          });
                                          await saveconfigNotiDsc(
                                              configNotiDsc);

                                          printLog(configNotiDsc);

                                          String displayTitle =
                                              'Notificación Activada';
                                          String displayMessage =
                                              'Has activado la notificación de desconexión con la opción seleccionada.';
                                          showNotification(displayTitle,
                                              displayMessage, 'noti');
                                        },
                                        style: ElevatedButton.styleFrom(
                                          foregroundColor: color0,
                                          backgroundColor:
                                              const Color(0xFF10BB96),
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 12),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                                30), // Bordes redondeados
                                          ),
                                        ),
                                        child: const Text(
                                          'Aceptar',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: CurvedNavigationBar(
          index: _selectedIndex,
          color: color3,
          items: const <Widget>[
            Icon(Icons.eco, size: 30, color: color0),
            Icon(Icons.local_fire_department, size: 30, color: color0),
            Icon(Icons.area_chart, size: 30, color: color0),
            Icon(Icons.bar_chart, size: 30, color: color0),
            Icon(Icons.lightbulb, size: 30, color: color0),
            Icon(Icons.settings, size: 30, color: color0),
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
