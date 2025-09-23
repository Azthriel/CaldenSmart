import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../Global/manager_screen.dart';
import '../aws/dynamo/dynamo.dart';
import '../aws/mqtt/mqtt.dart';
import '../master.dart';
import '../Global/stored_data.dart';
import 'package:caldensmart/logger.dart';

class RiegoPage extends ConsumerStatefulWidget {
  const RiegoPage({super.key});
  @override
  RiegoPageState createState() => RiegoPageState();
}

class RiegoPageState extends ConsumerState<RiegoPage> {
  var parts = utf8.decode(ioValues).split('/');
  bool isChangeModeVisible = false;
  bool showOptions = false;
  bool showSecondaryAdminFields = false;
  bool showAddAdminField = false;
  bool showSecondaryAdminList = false;
  bool showSmartResident = false;
  bool dOnOk = false;
  bool dOffOk = false;

  bool isAgreeChecked = false;
  bool isPasswordCorrect = false;
  bool _isTutorialActive = false;
  bool isPinMode = false;
  bool _isAnimating = false;
  bool _isPumpShuttingDown =
      false; // Para rastrear si la bomba se está apagando
  bool _isAutoStarting =
      false; // Para rastrear si está iniciando zona+bomba automáticamente
  TextEditingController emailController = TextEditingController();
  TextEditingController passController = TextEditingController();
  final TextEditingController modulePassController = TextEditingController();
  final PageController _pageController = PageController(initialPage: 0);
  final TextEditingController tenantController = TextEditingController();

  // para riego
  bool isRutina = false;
  bool isExtension = false;
  bool isRain = false;
  TextEditingController routineNameController = TextEditingController();

  late List<String> zoneOrder;
  late List<TextEditingController> minutesControllers;
  late List<bool> zoneEnabled;
  late List<bool> selectedExtensions;
  late List<String> extensionesEncontradas;
  late Map<String, String> zones;

  List<String> extensionesVinculadas = [];
  List<String> extensionesTemporales = [];

  int _selectedIndex = 0;

  final String pc = DeviceManager.getProductCode(deviceName);
  final String sn = DeviceManager.extractSerialNumber(deviceName);

  ///*- Elementos para tutoriales -*\\\
  List<TutorialItem> items = [];

  void initItems() {
    items.addAll({
      TutorialItem(
        globalKey: keys['riego:estado']!,
        pageIndex: 0,
        fullBackground: true,
        contentPosition: ContentPosition.below,
        child: const TutorialItemContent(
          title: 'Entradas y Salidas',
          content:
              'Podrás revisar el estado de las entradas y modificar el estado de las salidas',
        ),
      ),
      TutorialItem(
        globalKey: keys['riego:titulo']!,
        shapeFocus: ShapeFocus.roundedSquare,
        borderRadius: const Radius.circular(10.0),
        contentPosition: ContentPosition.below,
        pageIndex: 0,
        child: const TutorialItemContent(
          title: 'Nombre del equipo',
          content:
              'Podrás ponerle un apodo tocando en cualquier parte del nombre',
        ),
      ),
      TutorialItem(
        globalKey: keys['riego:wifi']!,
        shapeFocus: ShapeFocus.oval,
        borderRadius: const Radius.circular(30.0),
        contentPosition: ContentPosition.below,
        pageIndex: 0,
        child: const TutorialItemContent(
          title: 'Menu Wifi',
          content:
              'Podrás observar el estado de la conexión wifi del dispositivo',
        ),
      ),
      TutorialItem(
        globalKey: keys['riego:servidor']!,
        shapeFocus: ShapeFocus.oval,
        borderRadius: const Radius.circular(15.0),
        contentPosition: ContentPosition.below,
        pageIndex: 0,
        focusMargin: 15,
        child: const TutorialItemContent(
          title: 'Conexión al servidor',
          content:
              'Podrás observar el estado de la conexión del dispositivo con el servidor',
        ),
      ),
    });
  }

  ///*- Elementos para tutoriales -*\\\

  @override
  void initState() {
    super.initState();

    extensionesVinculadas =
        List<String>.from(globalDATA['$pc/$sn']?['riegoExtensions'] ?? []);

    searchExtensions();

    zoneOrder = [];
    minutesControllers = [];
    zoneEnabled = [];
    zones = {};

    //printLog.i(_notis);

    tracking = devicesToTrack.contains(deviceName);

    showOptions = currentUserEmail == owner;

    if (deviceOwner) {
      if (vencimientoAdmSec < 10 && vencimientoAdmSec > 0) {
        showPaymentTest(true, vencimientoAdmSec, navigatorKey.currentContext!);
      }

      if (vencimientoAT < 10 && vencimientoAT > 0) {
        showPaymentTest(false, vencimientoAT, navigatorKey.currentContext!);
      }
    }

    nickname = nicknamesMap[deviceName] ?? deviceName;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      updateWifiValues(toolsValues);
      if (shouldUpdateDevice) {
        await showUpdateDialog(context);
      }
    });
    subscribeToWifiStatus();
    subToIO();
    processValues(ioValues);
    // notificationMap.putIfAbsent(
    //     '${DeviceManager.getProductCode(deviceName)}/${DeviceManager.extractSerialNumber(deviceName)}',
    //     () => List<bool>.filled(parts.length, false));

    // WidgetsBinding.instance.addPostFrameCallback((_) async {
    //   if (shouldUpdateDevice) {
    //     await showUpdateDialog(context);
    //   }
    // });
  }

  @override
  void dispose() {
    _pageController.dispose();
    tenantController.dispose();
    passController.dispose();
    emailController.dispose();
    modulePassController.dispose();
    super.dispose();
  }

  void searchExtensions() {
    extensionesEncontradas = globalDATA.entries
        .where((entry) =>
            (entry.key.startsWith('020020_IOT/') ||
                entry.key.startsWith('020010_IOT/') ||
                entry.key.startsWith('027313_IOT/')) &&
            entry.value['owner'] == currentUserEmail &&
            entry.value['riegoActive'] == true &&
            (entry.value['riegoMaster'] == null ||
                entry.value['riegoMaster'] == '') &&
            entry.key != '$pc/$sn')
        .map((entry) {
      String pc = entry.key.split('/')[0];
      String sn = entry.key.split('/')[1];
      return DeviceManager.recoverDeviceName(pc, sn);
    }).toList();
    printLog.d(extensionesEncontradas, color: 'violeta');
  }

  String getZoneLabel(String deviceId) {
    int zoneCounter = 1;
    for (int i = 1; i < tipo.length; i++) {
      if (tipo[i] == 'Salida') {
        String tempDeviceId = '${deviceName}_$i';
        if (tempDeviceId == deviceId) {
          return 'Zona $zoneCounter';
        }
        zoneCounter++;
      }
    }
    for (String extension in extensionesVinculadas) {
      String key =
          '${DeviceManager.getProductCode(extension)}/${DeviceManager.extractSerialNumber(extension)}';
      Map<String, dynamic> extensionData = globalDATA[key] ?? {};
      List<String> extensionOutputs = [];
      extensionData.forEach((k, v) {
        if (k.startsWith('io') && v is String) {
          try {
            var decoded = jsonDecode(v);
            if (decoded['pinType'] == '0') {
              String outputIndex = k.replaceAll('io', '');
              extensionOutputs.add(outputIndex);
            }
          } catch (e) {
            // Error handling
          }
        }
      });
      extensionOutputs.sort((a, b) => int.parse(a).compareTo(int.parse(b)));
      for (String outputIndex in extensionOutputs) {
        String tempDeviceId = '${extension}_$outputIndex';
        if (tempDeviceId == deviceId) {
          return 'Zona $zoneCounter';
        }
        zoneCounter++;
      }
    }
    return deviceId;
  }

  void onItemChanged(int index) {
    if (!_isAnimating) {
      setState(() {
        _isAnimating = true;
        _selectedIndex = index;
      });

      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          setState(() {
            _isAnimating = false;
          });
        }
      });
    }
  }

  void onItemTapped(int index) {
    if (_selectedIndex != index && !_isAnimating) {
      setState(() {
        _isAnimating = true;
      });

      _pageController
          .animateToPage(
        index,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      )
          .then((_) {
        if (mounted) {
          setState(() {
            _selectedIndex = index;
            _isAnimating = false;
          });
        }
      });
    }
  }

  // Función para verificar si hay alguna zona encendida
  bool _hasActiveZones() {
    // Verificar zonas del dispositivo principal (índice > 0 porque 0 es la bomba)
    for (int i = 1; i < estado.length; i++) {
      if (tipo[i] == 'Salida' && estado[i] == '1') {
        return true;
      }
    }

    // Verificar zonas de extensiones vinculadas
    for (String extension in extensionesVinculadas) {
      String key =
          '${DeviceManager.getProductCode(extension)}/${DeviceManager.extractSerialNumber(extension)}';
      Map<String, dynamic> extensionData = globalDATA[key] ?? {};

      bool hasActiveExtensionZone = false;
      extensionData.forEach((k, v) {
        if (k.startsWith('io') && v is String) {
          try {
            var decoded = jsonDecode(v);
            if (decoded['pinType'] == '0' && decoded['w_status'] == true) {
              hasActiveExtensionZone = true;
            }
          } catch (e) {
            // Error handling
          }
        }
      });

      if (hasActiveExtensionZone) {
        return true;
      }
    }

    return false;
  }

  // Función para contar cuántas zonas están encendidas
  int _countActiveZones() {
    int count = 0;

    // Contar zonas del dispositivo principal
    for (int i = 1; i < estado.length; i++) {
      if (tipo[i] == 'Salida' && estado[i] == '1') {
        count++;
      }
    }

    // Contar zonas de extensiones vinculadas
    for (String extension in extensionesVinculadas) {
      String key =
          '${DeviceManager.getProductCode(extension)}/${DeviceManager.extractSerialNumber(extension)}';
      Map<String, dynamic> extensionData = globalDATA[key] ?? {};

      extensionData.forEach((k, v) {
        if (k.startsWith('io') && v is String) {
          try {
            var decoded = jsonDecode(v);
            if (decoded['pinType'] == '0' && decoded['w_status'] == true) {
              count++;
            }
          } catch (e) {
            // Error handling
          }
        }
      });
    }

    return count;
  }

  // Función para apagar automáticamente la bomba
  void _turnOffPump() {
    if (estado.isNotEmpty && estado[0] == '1') {
      controlOut(false, 0);
      setState(() {
        estado[0] = '0';
      });
    }
  }

  // Función para controlar salidas de extensiones
  void controlExtensionOut(bool value, String extension, int outputIndex,
      {bool skipAutoLogic = false}) {
    // Verificar si freeBomb está en false
    bool freeBomb = globalDATA['$pc/$sn']?['freeBomb'] ?? false;

    // Si skipAutoLogic es false y freeBomb es false, aplicar lógica automática
    if (!skipAutoLogic && !freeBomb && !value) {
      // Si se está apagando una zona, verificar si queda solo esta encendida
      if (_countActiveZones() == 1) {
        String key =
            '${DeviceManager.getProductCode(extension)}/${DeviceManager.extractSerialNumber(extension)}';
        Map<String, dynamic> extensionData = globalDATA[key] ?? {};
        String ioKey = 'io$outputIndex';

        if (extensionData[ioKey] != null) {
          try {
            var decoded = jsonDecode(extensionData[ioKey]);
            if (decoded['w_status'] == true) {
              // Apagar la bomba automáticamente si solo queda esta zona encendida
              Future.delayed(const Duration(milliseconds: 100), () {
                _turnOffPump();
              });
            }
          } catch (e) {
            // Error handling
          }
        }
      }
    }

    // Actualizar el estado de la extensión
    String key =
        '${DeviceManager.getProductCode(extension)}/${DeviceManager.extractSerialNumber(extension)}';
    String message = jsonEncode({
      'pinType': '0',
      'index': outputIndex,
      'w_status': value,
      'r_state': '0',
    });

    globalDATA.putIfAbsent(key, () => {}).addAll({'io$outputIndex': message});
    saveGlobalData(globalDATA);

    // Enviar comando MQTT si la extensión está conectada
    String extensionPc = DeviceManager.getProductCode(extension);
    String extensionSn = DeviceManager.extractSerialNumber(extension);
    String topic = 'devices_rx/$extensionPc/$extensionSn';
    String topic2 = 'devices_tx/$extensionPc/$extensionSn';
    sendMessagemqtt(topic, message);
    sendMessagemqtt(topic2, message);
  }

  void controlOut(bool value, int index, {bool skipAutoLogic = false}) {
    // Verificar si freeBomb está en false
    bool freeBomb = globalDATA['$pc/$sn']?['freeBomb'] ?? false;

    // Si skipAutoLogic es true, saltar toda la lógica automática
    if (!skipAutoLogic && !freeBomb) {
      // Si es la bomba (índice 0) y freeBomb es false
      if (index == 0) {
        // Si se intenta encender la bomba, verificar que haya zonas activas
        if (value && !_hasActiveZones()) {
          // No permitir encender la bomba si no hay zonas activas
          return;
        }
      }

      // Si es una zona (índice > 0) y freeBomb es false
      if (index > 0 && tipo[index] == 'Salida') {
        // Si se está apagando una zona, verificar si queda solo esta encendida
        if (!value && _countActiveZones() == 1 && estado[index] == '1') {
          // Apagar la bomba automáticamente si solo queda esta zona encendida
          Future.delayed(const Duration(milliseconds: 100), () {
            _turnOffPump();
          });
        }
      }
    }

    String fun = '$index#${value ? '1' : '0'}';
    bluetoothManager.ioUuid.write(fun.codeUnits);
    String topic = 'devices_rx/$pc/$sn';
    String topic2 = 'devices_tx/$pc/$sn';
    String message = jsonEncode({
      'pinType': tipo[index] == 'Salida' ? '0' : '1',
      'index': index,
      'w_status': value,
      'r_state': common[index],
    });
    sendMessagemqtt(topic, message);
    sendMessagemqtt(topic2, message);

    globalDATA.putIfAbsent('$pc/$sn', () => {}).addAll({'io$index': message});

    saveGlobalData(globalDATA);
  }

  void updateWifiValues(List<int> data) {
    var fun = utf8.decode(data); //Wifi status | wifi ssid | ble status(users)
    fun = fun.replaceAll(RegExp(r'[^\x20-\x7E]'), '');
    printLog.i(fun);
    var parts = fun.split(':');
    final regex = RegExp(r'\((\d+)\)');
    final match = regex.firstMatch(parts[2]);
    int users = int.parse(match!.group(1).toString());
    printLog.i('Hay $users conectados');
    userConnected = users > 1;

    final wifiNotifier = ref.read(wifiProvider.notifier);

    if (parts[0] == 'WCS_CONNECTED') {
      atemp = false;
      nameOfWifi = parts[1];
      isWifiConnected = true;
      printLog.i('sis $isWifiConnected');
      errorMessage = '';
      errorSintax = '';
      werror = false;
      if (parts.length > 3) {
        signalPower = int.tryParse(parts[3]) ?? -30;
      } else {
        signalPower = -30;
      }
      wifiNotifier.updateStatus(
          'CONECTADO', Colors.green, wifiPower(signalPower));
    } else if (parts[0] == 'WCS_DISCONNECTED') {
      isWifiConnected = false;
      printLog.i('non $isWifiConnected');

      nameOfWifi = '';
      wifiNotifier.updateStatus(
          'DESCONECTADO', Colors.red, Icons.signal_wifi_off);

      if (atemp) {
        setState(() {
          wifiNotifier.updateStatus(
              'DESCONECTADO', Colors.red, Icons.warning_amber_rounded);
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
    printLog.i('Se subscribio a wifi');
    await bluetoothManager.toolsUuid.setNotifyValue(true);

    final wifiSub =
        bluetoothManager.toolsUuid.onValueReceived.listen((List<int> status) {
      updateWifiValues(status);
    });

    bluetoothManager.device.cancelWhenDisconnected(wifiSub);
  }

  void processValues(List<int> values) {
    ioValues = values;
    var parts = utf8.decode(values).split('/');
    printLog.i('Valores: $parts');
    tipo.clear();
    estado.clear();
    common.clear();
    alertIO.clear();

    if (hardwareVersion == '240422A') {
      for (int i = 0; i < parts.length; i++) {
        var equipo = parts[i].split(':');
        tipo.add(equipo[0] == '0' ? 'Salida' : 'Entrada');
        estado.add(equipo[1]);
        common.add(equipo[2]);
        alertIO.add(estado[i] != common[i]);

        globalDATA.putIfAbsent('$pc/$sn', () => {}).addAll({
          'io$i': jsonEncode({
            'pinType': tipo[i] == 'Salida' ? '0' : '1',
            'index': i,
            'w_status': estado[i] == '1',
            'r_state': common[i],
          })
        });

        printLog.i(
            'En la posición $i el modo es ${tipo[i]} y su estado es ${estado[i]}');
      }
      setState(() {});
    } else {
      for (int i = 0; i < 4; i++) {
        tipo.add('Salida');
        estado.add(parts[i]);
        common.add('0');
        alertIO.add(false);

        globalDATA.putIfAbsent('$pc/$sn', () => {}).addAll({
          'io$i': jsonEncode({
            'pinType': tipo[i] == 'Salida' ? '0' : '1',
            'index': i,
            'w_status': estado[i] == '1',
            'r_state': common[i],
          })
        });
      }

      for (int j = 4; j < 8; j++) {
        var equipo = parts[j].split(':');
        tipo.add('Entrada');
        estado.add(equipo[0]);
        common.add(equipo[1]);
        alertIO.add(estado[j] != common[j]);

        globalDATA.putIfAbsent('$pc/$sn', () => {}).addAll({
          'io$j': jsonEncode({
            'pinType': tipo[j] == 'Salida' ? '0' : '1',
            'index': j,
            'w_status': estado[j] == '1',
            'r_state': common[j],
          })
        });

        printLog.i('¿La entrada $j esta en alerta?: ${alertIO[j]}');
      }
      setState(() {});
    }

    saveGlobalData(globalDATA);
  }

  void subToIO() async {
    await bluetoothManager.ioUuid.setNotifyValue(true);
    printLog.i('Subscrito a IO');

    var ioSub = bluetoothManager.ioUuid.onValueReceived.listen((event) {
      printLog.i('Cambio en IO');
      processValues(event);
    });

    bluetoothManager.device.cancelWhenDisconnected(ioSub);
  }

  bool isValidEmail(String email) {
    final RegExp emailRegex = RegExp(
      r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@"
      r"[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)*$",
    );
    return emailRegex.hasMatch(email);
  }

  // Pantalla que se muestra cuando el dispositivo es una extensión
  Widget _buildExtensionScreen(BuildContext context, String masterNickname,
      TextStyle poppinsStyle, dynamic wifiState) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, A) {
        if (_isTutorialActive) return;
        showDisconnectDialog(context);
        Future.delayed(const Duration(seconds: 2), () async {
          await bluetoothManager.device.disconnect();
          if (context.mounted) {
            Navigator.pop(context);
            Navigator.pushReplacementNamed(context, '/menu');
          }
        });
        return;
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: color1,
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
                    style: ButtonStyle(
                      foregroundColor: WidgetStateProperty.all(color0),
                    ),
                    child: const Text('Cancelar'),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                  TextButton(
                    style: ButtonStyle(
                      foregroundColor: WidgetStateProperty.all(color0),
                    ),
                    child: const Text('Guardar'),
                    onPressed: () {
                      setState(() {
                        String newNickname = nicknameController.text;
                        nickname = newNickname;
                        nicknamesMap[deviceName] = newNickname;
                        putNicknames(currentUserEmail, nicknamesMap);
                      });
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              );
            },
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 30,
                    width: 2,
                    child: AutoScrollingText(
                      text: nickname,
                      style: poppinsStyle.copyWith(color: color0),
                      velocity: 50,
                    ),
                  ),
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
              showDisconnectDialog(context);
              Future.delayed(const Duration(seconds: 2), () async {
                await bluetoothManager.device.disconnect();
                if (context.mounted) {
                  Navigator.pop(context);
                  Navigator.pushReplacementNamed(context, '/menu');
                }
              });
              return;
            },
          ),
          actions: [
            Icon(
              globalDATA['${DeviceManager.getProductCode(deviceName)}/${DeviceManager.extractSerialNumber(deviceName)}']
                          ?['cstate'] ??
                      false
                  ? Icons.cloud
                  : Icons.cloud_off,
              color: color0,
            ),
            IconButton(
              icon: Icon(wifiState.wifiIcon, color: color0),
              onPressed: () {
                wifiText(context);
              },
            ),
          ],
        ),
        backgroundColor: color0,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Card(
              color: color1,
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.extension,
                      size: 64,
                      color: color0,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Dispositivo Extensión',
                      style: poppinsStyle.copyWith(
                        color: color0,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Este dispositivo es una extensión y solo puede ser controlado desde su equipo maestro.',
                      style: poppinsStyle.copyWith(
                        color: color0,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: color0,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.router,
                            color: color1,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Equipo Maestro:',
                                style: poppinsStyle.copyWith(
                                  color: color1,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                masterNickname,
                                style: poppinsStyle.copyWith(
                                  color: color1,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Conéctese al equipo maestro para controlar esta extensión.',
                      style: poppinsStyle.copyWith(
                        color: color0,
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

//!Visual
  @override
  Widget build(BuildContext context) {
    final TextStyle poppinsStyle = GoogleFonts.poppins();
    final wifiState = ref.watch(wifiProvider);

    bool isRegularUser = !deviceOwner && !secondaryAdmin;

    // si hay un usuario conectado al equipo no lo deje ingresar
    if (userConnected && lastUser > 1) {
      return const DeviceInUseScreen();
    }
    // si no eres dueño del equipo
    if (isRegularUser && owner != '' && !tenant) {
      return const AccessDeniedScreen();
    }

    if (specialUser && !labProcessFinished) {
      return const LabProcessNotFinished();
    }

    // Verificar si este dispositivo es una extensión
    String? riegoMaster = globalDATA['$pc/$sn']?['riegoMaster'];
    printLog.d('Riego Master: $riegoMaster', color: 'naranja');
    if (riegoMaster != null && riegoMaster.isNotEmpty && riegoMaster != '') {
      String masterNickname = nicknamesMap[riegoMaster] ?? riegoMaster;
      return _buildExtensionScreen(
          context, masterNickname, poppinsStyle, wifiState);
    }

    //printLog.d(globalDATA, color: 'verde');

    final List<Widget> pages = [
      //*- Página 1: Riego manual -*\\
      SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: Text(
                'Riego manual',
                style: TextStyle(
                    color: color1, fontSize: 28, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Card(
                color: color1,
                child: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.9,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 5),
                      const Center(
                        child: Text(
                          'Panel de control',
                          style: TextStyle(
                              color: color0,
                              fontSize: 16,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Center(
                        child: Text(
                          'Estado de la bomba',
                          style: TextStyle(color: color0, fontSize: 16),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Center(
                        child: Container(
                          width: MediaQuery.of(context).size.width * 0.8,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16.0, vertical: 8.0),
                          decoration: BoxDecoration(
                            color: color0,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: color0.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(children: [
                                Icon(
                                  HugeIcons.strokeRoundedShutDown,
                                  color: color1,
                                  size: 25,
                                ),
                                SizedBox(width: 10),
                                Text(
                                  'Bomba',
                                  style: TextStyle(
                                      color: color1,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500),
                                ),
                              ]),
                              Switch(
                                value: estado.isNotEmpty && estado[0] == '1',
                                onChanged: (value) {
                                  // Si hay un proceso de apagado en curso, no permitir acciones
                                  if (_isPumpShuttingDown) {
                                    showToast(
                                        'Espere, la bomba se está apagando...');
                                    return;
                                  }

                                  // Si hay un proceso de encendido automático en curso, no permitir acciones
                                  if (_isAutoStarting) {
                                    showToast(
                                        'Espere, se está iniciando automáticamente...');
                                    return;
                                  }

                                  // Verificar si freeBomb está en false
                                  bool freeBomb = globalDATA['$pc/$sn']
                                          ?['freeBomb'] ??
                                      false;

                                  // Si freeBomb es false y se intenta encender la bomba
                                  if (!freeBomb &&
                                      value &&
                                      !_hasActiveZones()) {
                                    // Mostrar mensaje informativo al usuario
                                    showToast(
                                        'Para encender la bomba primero debe activar al menos una zona de riego');
                                    return;
                                  }

                                  setState(() {
                                    controlOut(value, 0);
                                    estado[0] = value ? '1' : '0';
                                  });
                                },
                                activeColor: Colors.green,
                                inactiveThumbColor: () {
                                  bool freeBomb = globalDATA['$pc/$sn']
                                          ?['freeBomb'] ??
                                      false;
                                  // Si freeBomb está desactivado y no hay zonas activas, mostrar en gris
                                  if (!freeBomb && !_hasActiveZones()) {
                                    return Colors.grey;
                                  }
                                  return Colors.red;
                                }(),
                                inactiveTrackColor: () {
                                  bool freeBomb = globalDATA['$pc/$sn']
                                          ?['freeBomb'] ??
                                      false;
                                  // Si freeBomb está desactivado y no hay zonas activas, track también en gris
                                  if (!freeBomb && !_hasActiveZones()) {
                                    return Colors.grey.withValues(alpha: 0.3);
                                  }
                                  return null; // Color por defecto
                                }(),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Center(
                        child: Text(
                          'Estado de las zonas',
                          style: TextStyle(color: color0, fontSize: 16),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...() {
                        List<Widget> widgets = [];
                        for (int i = 1; i < tipo.length; i++) {
                          if (tipo[i] == 'Salida') {
                            String zoneLabel = 'Zona $i';
                            String deviceId = '${deviceName}_$i';
                            if (!zones.containsKey(zoneLabel)) {
                              zones[zoneLabel] = deviceId;
                            }

                            widgets.add(
                              Center(
                                child: Container(
                                  width:
                                      MediaQuery.of(context).size.width * 0.8,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16.0, vertical: 8.0),
                                  decoration: BoxDecoration(
                                    color: color0,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                        color: color0.withValues(alpha: 0.3)),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(children: [
                                        const Icon(
                                          HugeIcons.strokeRoundedDroplet,
                                          color: color1,
                                          size: 25,
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          zoneLabel,
                                          style: const TextStyle(
                                            color: color1,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ]),
                                      Switch(
                                        value: estado.isNotEmpty &&
                                            estado[i] == '1',
                                        onChanged: (value) {
                                          // Si hay un proceso de apagado en curso, no permitir acciones
                                          if (_isPumpShuttingDown) {
                                            showToast(
                                                'Espere, la bomba se está apagando...');
                                            return;
                                          }

                                          // Si hay un proceso de encendido automático en curso, no permitir acciones
                                          if (_isAutoStarting) {
                                            showToast(
                                                'Espere, se está iniciando automáticamente...');
                                            return;
                                          }

                                          // Verificar si freeBomb está en false
                                          bool freeBomb = globalDATA['$pc/$sn']
                                                  ?['freeBomb'] ??
                                              false;

                                          if (!freeBomb) {
                                            if (value) {
                                              // Encendiendo zona: primero zona, luego bomba (con delay)
                                              setState(() {
                                                controlOut(value, i,
                                                    skipAutoLogic: true);
                                                estado[i] = '1';
                                              });

                                              // Si la bomba está apagada, encenderla después de 1 segundo
                                              if (estado.isNotEmpty &&
                                                  estado[0] == '0') {
                                                setState(() {
                                                  _isAutoStarting = true;
                                                });

                                                Future.delayed(
                                                    const Duration(seconds: 1),
                                                    () {
                                                  if (mounted) {
                                                    controlOut(true, 0,
                                                        skipAutoLogic: true);
                                                    setState(() {
                                                      estado[0] = '1';
                                                      _isAutoStarting = false;
                                                    });
                                                  }
                                                });
                                              }
                                            } else {
                                              // Apagando zona: primero bomba (si es necesario), luego zona (con delay)
                                              // Si solo queda esta zona encendida, apagar bomba primero
                                              if (_countActiveZones() == 1 &&
                                                  estado[i] == '1') {
                                                setState(() {
                                                  _isPumpShuttingDown = true;
                                                });

                                                controlOut(false, 0,
                                                    skipAutoLogic: true);
                                                setState(() {
                                                  estado[0] = '0';
                                                });

                                                // Apagar zona después de 1 segundo
                                                Future.delayed(
                                                    const Duration(seconds: 1),
                                                    () {
                                                  if (mounted) {
                                                    controlOut(value, i,
                                                        skipAutoLogic: true);
                                                    setState(() {
                                                      estado[i] = '0';
                                                      _isPumpShuttingDown =
                                                          false;
                                                    });
                                                  }
                                                });
                                              } else {
                                                // Si hay otras zonas activas, apagar inmediatamente
                                                setState(() {
                                                  controlOut(value, i,
                                                      skipAutoLogic: true);
                                                  estado[i] = '0';
                                                });
                                              }
                                            }
                                          } else {
                                            // freeBomb está activo, funcionamiento normal
                                            setState(() {
                                              controlOut(value, i);
                                              estado[i] = value ? '1' : '0';
                                            });
                                          }
                                        },
                                        activeColor: Colors.green,
                                        inactiveThumbColor: Colors.red,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                            widgets.add(const SizedBox(height: 20));
                          }
                        }
                        return widgets;
                      }(),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Divider(color: color1, thickness: 1),
            const SizedBox(height: 10),
            if (extensionesVinculadas.isNotEmpty) ...{
              const Center(
                child: Text(
                  'Extensiones Vinculadas',
                  style: TextStyle(
                      color: color1, fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 10),
              ListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: extensionesVinculadas.map((extension) {
                  String key =
                      '${DeviceManager.getProductCode(extension)}/${DeviceManager.extractSerialNumber(extension)}';
                  Map<String, dynamic> extensionData = globalDATA[key] ?? {};
                  List<MapEntry<String, dynamic>> outputs = [];
                  bool isExtensionConnected = extensionData['cstate'] ?? false;
                  extensionData.forEach((k, v) {
                    if (k.startsWith('io') && v is String) {
                      try {
                        var decoded = jsonDecode(v);
                        if (decoded['pinType'] == '0') {
                          outputs.add(MapEntry(k, decoded));
                        }
                      } catch (e) {
                        printLog.e('Error decodificando datos I/O: $e');
                      }
                    }
                  });
                  outputs.sort((a, b) {
                    int indexA = int.tryParse(a.key.replaceAll('io', '')) ?? 0;
                    int indexB = int.tryParse(b.key.replaceAll('io', '')) ?? 0;
                    return indexA.compareTo(indexB);
                  });
                  return Card(
                    key: ValueKey(extension),
                    color: color1,
                    margin: const EdgeInsets.only(bottom: 16.0),
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width * 0.9,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Center(
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          isExtensionConnected
                                              ? Icons.cloud
                                              : Icons.cloud_off,
                                          color: isExtensionConnected
                                              ? Colors.green
                                              : Colors.red,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: Text(
                                            nicknamesMap[extension] ??
                                                extension,
                                            style: const TextStyle(
                                              color: color0,
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () {
                                    showAlertDialog(
                                      context,
                                      false,
                                      const Text(
                                        'Eliminar Extensión',
                                        style: TextStyle(color: color0),
                                      ),
                                      Text(
                                        '¿Estás seguro de que deseas eliminar la extensión "${nicknamesMap[extension] ?? extension}"?',
                                        style: const TextStyle(color: color0),
                                      ),
                                      <Widget>[
                                        TextButton(
                                          onPressed: () {
                                            Navigator.of(context).pop();
                                          },
                                          child: const Text(
                                            'Cancelar',
                                            style: TextStyle(color: color0),
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: () async {
                                            bool isUsedInRoutine = false;
                                            String routinesUsingExtension = '';
                                            final rutinasDelEquipo =
                                                eventosCreados.where((evento) {
                                              return evento['evento'] ==
                                                      'cadena' &&
                                                  evento['creator'] ==
                                                      deviceName;
                                            }).toList();
                                            for (var rutina
                                                in rutinasDelEquipo) {
                                              final pasos =
                                                  rutina['pasos'] as List? ??
                                                      [];
                                              for (var paso in pasos) {
                                                if (paso is Map) {
                                                  final devices =
                                                      paso['devices']
                                                              as List? ??
                                                          [];
                                                  for (String device
                                                      in devices) {
                                                    if (device.startsWith(
                                                        extension)) {
                                                      isUsedInRoutine = true;
                                                      if (routinesUsingExtension
                                                          .isNotEmpty) {
                                                        routinesUsingExtension +=
                                                            ', ';
                                                      }
                                                      routinesUsingExtension +=
                                                          rutina['title']
                                                                  as String? ??
                                                              'Sin nombre';
                                                      break;
                                                    }
                                                  }
                                                  if (isUsedInRoutine) break;
                                                }
                                              }
                                              if (isUsedInRoutine) break;
                                            }
                                            if (isUsedInRoutine) {
                                              Navigator.of(context).pop();
                                              showToast(
                                                  'No se puede eliminar la extensión "$extension". Está siendo utilizada en: $routinesUsingExtension');
                                            } else {
                                              // Eliminar riegoMaster de la extensión
                                              String extensionPc =
                                                  DeviceManager.getProductCode(
                                                      extension);
                                              String extensionSn = DeviceManager
                                                  .extractSerialNumber(
                                                      extension);
                                              await putRiegoMaster(
                                                  extensionPc, extensionSn, '');

                                              setState(() {
                                                extensionesVinculadas
                                                    .remove(extension);
                                              });

                                              // Actualizar la lista de extensiones en el maestro
                                              await putRiegoExtensions(pc, sn,
                                                  extensionesVinculadas);

                                              if (context.mounted) {
                                                Navigator.of(context).pop();
                                              }
                                              showToast(
                                                  'Extensión eliminada correctamente');
                                            }
                                          },
                                          child: const Text(
                                            'Eliminar',
                                            style: TextStyle(color: Colors.red),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.red,
                                    size: 24,
                                  ),
                                  tooltip: 'Eliminar extensión',
                                ),
                              ],
                            ),
                            const SizedBox(height: 15),
                            if (outputs.isNotEmpty) ...{
                              ...outputs.asMap().entries.map((entry) {
                                int outputIndex = entry.key;
                                MapEntry<String, dynamic> output = entry.value;
                                bool isOn = output.value['w_status'] ?? false;
                                int baseZoneCount = 0;
                                for (int i = 1; i < tipo.length; i++) {
                                  if (tipo[i] == 'Salida') {
                                    baseZoneCount++;
                                  }
                                }
                                int previousExtensionZones = 0;
                                int currentExtensionIndex =
                                    extensionesVinculadas.indexOf(extension);
                                for (int i = 0;
                                    i < currentExtensionIndex;
                                    i++) {
                                  String prevExtension =
                                      extensionesVinculadas[i];
                                  String prevKey =
                                      '${DeviceManager.getProductCode(prevExtension)}/${DeviceManager.extractSerialNumber(prevExtension)}';
                                  Map<String, dynamic> prevExtensionData =
                                      globalDATA[prevKey] ?? {};
                                  prevExtensionData.forEach((k, v) {
                                    if (k.startsWith('io') && v is String) {
                                      try {
                                        var decoded = jsonDecode(v);
                                        if (decoded['pinType'] == '0') {
                                          previousExtensionZones++;
                                        }
                                      } catch (e) {
                                        // Error handling
                                      }
                                    }
                                  });
                                }
                                int zoneNumber = baseZoneCount +
                                    previousExtensionZones +
                                    outputIndex +
                                    1;
                                String zoneLabel = 'Zona $zoneNumber';
                                String deviceId = '${extension}_$outputIndex';
                                if (!zones.containsKey(zoneLabel)) {
                                  zones[zoneLabel] = deviceId;
                                }
                                return Center(
                                  child: Container(
                                    width:
                                        MediaQuery.of(context).size.width * 0.8,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16.0, vertical: 8.0),
                                    margin: const EdgeInsets.only(bottom: 20),
                                    decoration: BoxDecoration(
                                      color: isExtensionConnected
                                          ? color0
                                          : Colors.grey[300],
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                          color: isExtensionConnected
                                              ? color0.withValues(alpha: 0.3)
                                              : Colors.grey
                                                  .withValues(alpha: 0.3)),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(children: [
                                          Icon(
                                            HugeIcons.strokeRoundedDroplet,
                                            color: isExtensionConnected
                                                ? color1
                                                : Colors.grey,
                                            size: 25,
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            zoneLabel,
                                            style: TextStyle(
                                                color: isExtensionConnected
                                                    ? color1
                                                    : Colors.grey,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w500),
                                          ),
                                        ]),
                                        Switch(
                                          value: isExtensionConnected
                                              ? isOn
                                              : false,
                                          onChanged: isExtensionConnected
                                              ? (value) {
                                                  // Si hay un proceso de apagado en curso, no permitir acciones
                                                  if (_isPumpShuttingDown) {
                                                    showToast(
                                                        'Espere, la bomba se está apagando...');
                                                    return;
                                                  }

                                                  // Si hay un proceso de encendido automático en curso, no permitir acciones
                                                  if (_isAutoStarting) {
                                                    showToast(
                                                        'Espere, se está iniciando automáticamente...');
                                                    return;
                                                  }

                                                  // Verificar si freeBomb está en false
                                                  bool freeBomb =
                                                      globalDATA['$pc/$sn']
                                                              ?['freeBomb'] ??
                                                          false;

                                                  int outputIndex = int.parse(
                                                      output.key.replaceAll(
                                                          'io', ''));

                                                  if (!freeBomb) {
                                                    if (value) {
                                                      // Encendiendo extensión: primero extensión, luego bomba (con delay)
                                                      setState(() {
                                                        controlExtensionOut(
                                                            value,
                                                            extension,
                                                            outputIndex,
                                                            skipAutoLogic:
                                                                true);
                                                      });

                                                      // Si la bomba está apagada, encenderla después de 1 segundo
                                                      if (estado.isNotEmpty &&
                                                          estado[0] == '0') {
                                                        setState(() {
                                                          _isAutoStarting =
                                                              true;
                                                        });

                                                        Future.delayed(
                                                            const Duration(
                                                                seconds: 1),
                                                            () {
                                                          if (mounted) {
                                                            controlOut(true, 0,
                                                                skipAutoLogic:
                                                                    true);
                                                            setState(() {
                                                              estado[0] = '1';
                                                              _isAutoStarting =
                                                                  false;
                                                            });
                                                          }
                                                        });
                                                      }
                                                    } else {
                                                      // Apagando extensión: verificar si es la última zona activa
                                                      // Si solo queda esta zona de extensión activa, apagar bomba primero
                                                      if (_countActiveZones() ==
                                                          1) {
                                                        String key =
                                                            '${DeviceManager.getProductCode(extension)}/${DeviceManager.extractSerialNumber(extension)}';
                                                        Map<String, dynamic>
                                                            extensionData =
                                                            globalDATA[key] ??
                                                                {};
                                                        String ioKey =
                                                            'io$outputIndex';

                                                        bool isLastActiveZone =
                                                            false;
                                                        if (extensionData[
                                                                ioKey] !=
                                                            null) {
                                                          try {
                                                            var decoded =
                                                                jsonDecode(
                                                                    extensionData[
                                                                        ioKey]);
                                                            if (decoded[
                                                                    'w_status'] ==
                                                                true) {
                                                              isLastActiveZone =
                                                                  true;
                                                            }
                                                          } catch (e) {
                                                            // Error handling
                                                          }
                                                        }

                                                        if (isLastActiveZone) {
                                                          setState(() {
                                                            _isPumpShuttingDown =
                                                                true;
                                                          });

                                                          // Apagar bomba primero
                                                          controlOut(false, 0,
                                                              skipAutoLogic:
                                                                  true);
                                                          setState(() {
                                                            estado[0] = '0';
                                                          });

                                                          // Apagar extensión después de 1 segundo
                                                          Future.delayed(
                                                              const Duration(
                                                                  seconds: 1),
                                                              () {
                                                            if (mounted) {
                                                              setState(() {
                                                                controlExtensionOut(
                                                                    value,
                                                                    extension,
                                                                    outputIndex,
                                                                    skipAutoLogic:
                                                                        true);
                                                                _isPumpShuttingDown =
                                                                    false;
                                                              });
                                                            }
                                                          });
                                                        } else {
                                                          // Si hay otras zonas activas, apagar inmediatamente
                                                          setState(() {
                                                            controlExtensionOut(
                                                                value,
                                                                extension,
                                                                outputIndex,
                                                                skipAutoLogic:
                                                                    true);
                                                          });
                                                        }
                                                      } else {
                                                        // Si hay otras zonas activas, apagar inmediatamente
                                                        setState(() {
                                                          controlExtensionOut(
                                                              value,
                                                              extension,
                                                              outputIndex,
                                                              skipAutoLogic:
                                                                  true);
                                                        });
                                                      }
                                                    }
                                                  } else {
                                                    // freeBomb está activo, funcionamiento normal
                                                    setState(() {
                                                      controlExtensionOut(
                                                          value,
                                                          extension,
                                                          outputIndex);
                                                    });
                                                  }
                                                }
                                              : null,
                                          activeColor: Colors.green,
                                          inactiveThumbColor:
                                              isExtensionConnected
                                                  ? Colors.red
                                                  : Colors.grey,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            } else ...{
                              Text(
                                isExtensionConnected
                                    ? 'No se encontraron salidas en esta extensión'
                                    : 'Extensión desconectada - No se pueden controlar las zonas',
                                style: TextStyle(
                                  color: isExtensionConnected
                                      ? color0
                                      : Colors.grey[600],
                                  fontSize: 14,
                                  fontStyle: FontStyle.italic,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            },
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            } else ...{
              const Center(child: Text('No hay extensiones agregadas')),
            },
            SizedBox(
              height:
                  bottomBarHeight + MediaQuery.of(context).padding.bottom + 100,
            ),
          ],
        ),
      ),

      //*- Página 2: Riego automático -*\\
      SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // const Center(
            //   child: Text(
            //     'Riego automático',
            //     style: TextStyle(
            //         color: color1, fontSize: 28, fontWeight: FontWeight.bold),
            //   ),
            // ),
            const SizedBox(height: 20),
            if (isRutina == false && isExtension == false) ...{
              Column(
                children: [
                  const SizedBox(height: 100),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Card(
                        //   color:
                        //       globalDATA['${DeviceManager.getProductCode(deviceName)}/${DeviceManager.extractSerialNumber(deviceName)}']
                        //                   ?['cstate'] ??
                        //               false
                        //           ? Colors.black
                        //           : Colors.grey,
                        //   elevation: 8,
                        //   shape: RoundedRectangleBorder(
                        //     borderRadius: BorderRadius.circular(20),
                        //   ),
                        //   child: SizedBox(
                        //     width: MediaQuery.of(context).size.width * 0.8,
                        //     child: Padding(
                        //       padding: const EdgeInsets.all(20),
                        //       child: GestureDetector(
                        //         onTap: () {
                        //           routineNameController.clear();
                        //           isRain = false;
                        //           zoneOrder.clear();
                        //           minutesControllers.clear();
                        //           zoneEnabled.clear();

                        //           zones.clear();

                        //           int zoneCounter = 1;
                        //           for (int i = 1; i < tipo.length; i++) {
                        //             if (tipo[i] == 'Salida') {
                        //               String zoneLabel = 'Zona $zoneCounter';
                        //               String deviceId = '${deviceName}_$i';
                        //               zones[zoneLabel] = deviceId;
                        //               zoneOrder.add(deviceId);
                        //               minutesControllers.add(
                        //                   TextEditingController(text: '5'));
                        //               zoneEnabled.add(true);
                        //               zoneCounter++;
                        //             }
                        //           }

                        //           for (String extension
                        //               in extensionesVinculadas) {
                        //             String key =
                        //                 '${DeviceManager.getProductCode(extension)}/${DeviceManager.extractSerialNumber(extension)}';
                        //             Map<String, dynamic> extensionData =
                        //                 globalDATA[key] ?? {};

                        //             List<String> extensionOutputs = [];
                        //             extensionData.forEach((k, v) {
                        //               if (k.startsWith('io') && v is String) {
                        //                 try {
                        //                   var decoded = jsonDecode(v);
                        //                   if (decoded['pinType'] == '0') {
                        //                     String outputIndex =
                        //                         k.replaceAll('io', '');
                        //                     extensionOutputs.add(outputIndex);
                        //                   }
                        //                 } catch (e) {
                        //                   printLog.e(
                        //                       'Error decodificando datos I/O: $e');
                        //                 }
                        //               }
                        //             });

                        //             extensionOutputs.sort((a, b) =>
                        //                 int.parse(a).compareTo(int.parse(b)));
                        //             for (String outputIndex
                        //                 in extensionOutputs) {
                        //               String zoneLabel = 'Zona $zoneCounter';
                        //               String deviceId =
                        //                   '${extension}_$outputIndex';
                        //               zones[zoneLabel] = deviceId;
                        //               zoneOrder.add(deviceId);
                        //               minutesControllers.add(
                        //                   TextEditingController(text: '5'));
                        //               zoneEnabled.add(true);
                        //               zoneCounter++;
                        //             }
                        //           }

                        //           setState(() {
                        //             isRutina = true;
                        //           });
                        //         },
                        //         child: const Text(
                        //           'Crear rutina',
                        //           style: TextStyle(
                        //             color: Colors.white,
                        //             fontSize: 18,
                        //             fontWeight: FontWeight.bold,
                        //           ),
                        //           textAlign: TextAlign.center,
                        //         ),
                        //       ),
                        //     ),
                        //   ),
                        // ),
                        const SizedBox(height: 10),
                        Card(
                          color:
                              globalDATA['${DeviceManager.getProductCode(deviceName)}/${DeviceManager.extractSerialNumber(deviceName)}']
                                          ?['cstate'] ??
                                      false
                                  ? Colors.black
                                  : Colors.grey,
                          elevation: 8,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: SizedBox(
                            width: MediaQuery.of(context).size.width * 0.8,
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: GestureDetector(
                                onTap: () {
                                  searchExtensions();
                                  setState(() {
                                    isExtension = true;
                                  });
                                },
                                child: const Text(
                                  'Añadir extensión',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            },
            // vista de rutinas creadas
            if (isRutina == false && isExtension == false) ...{
              () {
                final rutinasDelEquipo = eventosCreados.where((evento) {
                  return evento['evento'] == 'cadena' &&
                      evento['creator'] == deviceName;
                }).toList();
                if (rutinasDelEquipo.isNotEmpty) {
                  return Column(
                    children: [
                      const SizedBox(height: 25),
                      const Divider(color: color1, thickness: 1.5),
                      const SizedBox(height: 16),
                      const Text(
                        'Rutinas creadas',
                        style: TextStyle(
                          color: color1,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ...rutinasDelEquipo.map((rutina) {
                        final title =
                            rutina['title'] as String? ?? 'Sin nombre';
                        final pasos = rutina['pasos'] as List? ?? [];
                        final isRain = rutina['isRain'] as bool? ?? false;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: Card(
                            color: color1,
                            elevation: 6,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          title,
                                          style: const TextStyle(
                                            color: color0,
                                            fontSize: 17,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () {
                                          showAlertDialog(
                                            context,
                                            false,
                                            const Text(
                                              'Confirmar eliminación',
                                              style: TextStyle(color: color0),
                                            ),
                                            Text(
                                              '¿Estás seguro de que quieres eliminar la rutina "$title"?',
                                              style: const TextStyle(
                                                  color: color0),
                                            ),
                                            <Widget>[
                                              TextButton(
                                                style: ButtonStyle(
                                                  foregroundColor:
                                                      WidgetStateProperty.all(
                                                          color0),
                                                ),
                                                child: const Text('Cancelar'),
                                                onPressed: () {
                                                  Navigator.of(context).pop();
                                                },
                                              ),
                                              TextButton(
                                                style: ButtonStyle(
                                                  foregroundColor:
                                                      WidgetStateProperty.all(
                                                          Colors.red),
                                                ),
                                                child: const Text('Eliminar'),
                                                onPressed: () {
                                                  setState(() {
                                                    eventosCreados.removeWhere(
                                                        (evento) =>
                                                            evento['title'] ==
                                                                title &&
                                                            evento['creator'] ==
                                                                deviceName);
                                                    //TODO borrar rutinas de la base
                                                    // putEventos(
                                                    //     currentUserEmail,
                                                    //     eventosCreados);
                                                    // deleteEventoControlPorCadena(
                                                    //     currentUserEmail,
                                                    //     title);
                                                    todosLosDispositivos
                                                        .removeWhere((entry) =>
                                                            entry.key == title);
                                                  });
                                                  Navigator.of(context).pop();
                                                  showToast('Rutina eliminada');
                                                },
                                              ),
                                            ],
                                          );
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.red
                                                .withValues(alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: const Icon(
                                            Icons.delete_outline,
                                            color: Colors.red,
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Container(
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 0),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: color0,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black
                                              .withValues(alpha: 0.05),
                                          blurRadius: 2,
                                          offset: const Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          isRain
                                              ? Icons.water_drop_outlined
                                              : Icons.wb_sunny_outlined,
                                          color: color1,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            isRain
                                                ? 'No se ejecutará en días de lluvia'
                                                : 'Se ejecutará aunque llueva',
                                            style: const TextStyle(
                                              color: color1,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Configuración de zonas:',
                                    style: TextStyle(
                                      color: color0,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  ...pasos.asMap().entries.map((entry) {
                                    final index = entry.key;
                                    final paso = entry.value;

                                    String zoneName = 'Zona desconocida';
                                    int minutes = 5;
                                    if (paso is Map) {
                                      final devices = paso['devices'] as List?;
                                      if (devices != null &&
                                          devices.isNotEmpty) {
                                        String deviceId =
                                            devices.first.toString();
                                        zoneName = getZoneLabel(deviceId);
                                      }
                                      final stepDelay = paso['stepDelay'];
                                      if (stepDelay is Duration) {
                                        minutes = stepDelay.inMinutes;
                                      }
                                    }

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 6),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: color0,
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black
                                                .withValues(alpha: 0.05),
                                            blurRadius: 2,
                                            offset: const Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 26,
                                            height: 26,
                                            decoration: BoxDecoration(
                                              color: color1,
                                              borderRadius:
                                                  BorderRadius.circular(13),
                                            ),
                                            child: Center(
                                              child: Text(
                                                '${index + 1}',
                                                style: const TextStyle(
                                                  color: color0,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              zoneName,
                                              style: const TextStyle(
                                                color: color1,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color:
                                                  color1.withValues(alpha: 0.1),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              '$minutes min',
                                              style: const TextStyle(
                                                color: color1,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  })
                                ],
                              ),
                            ),
                          ),
                        );
                      })
                    ],
                  );
                } else {
                  return const SizedBox.shrink();
                }
              }(),
            },

            // visual de creación de rutina
            if (isRutina == true && isExtension == false) ...{
              Center(
                child: Card(
                  color: color1,
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width * 0.92,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 16),
                        const Text(
                          'Nueva rutina de riego',
                          style: TextStyle(
                              color: color0,
                              fontSize: 18,
                              fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 18),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Text(
                                'Nombre de la rutina',
                                style: TextStyle(
                                  color: color0,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: routineNameController,
                                style: const TextStyle(
                                  color: color1,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                                decoration: InputDecoration(
                                  fillColor: color0,
                                  filled: true,
                                  hintText:
                                      'Ej: Riego mañanero, Jardín frontal...',
                                  hintStyle: TextStyle(
                                    color: color1.withValues(alpha: 0.6),
                                    fontSize: 15,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: color0,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Divider(
                          color: color0,
                          thickness: 1,
                          indent: 16,
                          endIndent: 16,
                        ),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Container(
                            decoration: BoxDecoration(
                              color: color0,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.water_drop_outlined,
                                  color: isRain ? Colors.blue : color1,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Text(
                                    'No ejecutar en días de lluvia',
                                    style: TextStyle(
                                      color: color1,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Switch(
                                  value: isRain,
                                  onChanged: (value) {
                                    setState(() {
                                      isRain = value;
                                    });
                                  },
                                  activeColor: Colors.blue,
                                  inactiveThumbColor: Colors.grey,
                                  activeTrackColor:
                                      Colors.blue.withValues(alpha: 0.3),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Divider(
                          color: color0,
                          thickness: 1,
                          indent: 16,
                          endIndent: 16,
                        ),
                        const SizedBox(height: 16),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                'Configuración de zonas',
                                style: TextStyle(
                                  color: color0,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 6),
                              Text(
                                'Arrastra para reordenar • Ajusta tiempo • Activa/desactiva zonas',
                                style: TextStyle(
                                  color: color0,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: ReorderableListView(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            proxyDecorator: (Widget child, int index,
                                Animation<double> animation) {
                              return Material(
                                color: Colors.transparent,
                                child: Transform.scale(
                                  scale: 1.02,
                                  child: child,
                                ),
                              );
                            },
                            onReorder: (oldIndex, newIndex) {
                              setState(() {
                                if (newIndex > oldIndex) {
                                  newIndex -= 1;
                                }
                                final item = zoneOrder.removeAt(oldIndex);
                                final controller =
                                    minutesControllers.removeAt(oldIndex);
                                final enabled = zoneEnabled.removeAt(oldIndex);
                                zoneOrder.insert(newIndex, item);
                                minutesControllers.insert(newIndex, controller);
                                zoneEnabled.insert(newIndex, enabled);
                              });
                            },
                            children: List.generate(zoneOrder.length, (index) {
                              String deviceId = zoneOrder[index];
                              String zoneLabel = zones.keys.firstWhere(
                                (key) => zones[key] == deviceId,
                                orElse: () => deviceId,
                              );

                              return Container(
                                key: ValueKey('${zoneOrder[index]}_$index'),
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: zoneEnabled[index]
                                      ? color0
                                      : Colors.grey.shade400,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.08),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: zoneEnabled[index]
                                            ? color1.withValues(alpha: 0.1)
                                            : Colors.white
                                                .withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        Icons.drag_indicator,
                                        color: zoneEnabled[index]
                                            ? color1
                                            : Colors.white,
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        zoneLabel,
                                        style: TextStyle(
                                          color: zoneEnabled[index]
                                              ? color1
                                              : Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 4,
                                      child: Container(
                                        height: 40,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border: Border.all(
                                            color: Colors.grey.shade300,
                                            width: 1.2,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black
                                                  .withValues(alpha: 0.04),
                                              blurRadius: 3,
                                              offset: const Offset(0, 1),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          children: [
                                            GestureDetector(
                                              onTap: () {
                                                int currentValue = int.tryParse(
                                                        minutesControllers[
                                                                index]
                                                            .text) ??
                                                    0;
                                                if (currentValue > 1) {
                                                  minutesControllers[index]
                                                          .text =
                                                      (currentValue - 1)
                                                          .toString();
                                                }
                                              },
                                              child: Container(
                                                width: 28,
                                                height: 28,
                                                decoration: BoxDecoration(
                                                  color: Colors.grey.shade100,
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: const Icon(
                                                  Icons.remove,
                                                  size: 14,
                                                  color: color1,
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              child: Container(
                                                alignment: Alignment.center,
                                                child: TextField(
                                                  controller:
                                                      minutesControllers[index],
                                                  textAlign: TextAlign.center,
                                                  keyboardType:
                                                      TextInputType.number,
                                                  inputFormatters: [
                                                    FilteringTextInputFormatter
                                                        .digitsOnly,
                                                    LengthLimitingTextInputFormatter(
                                                        3),
                                                  ],
                                                  style: const TextStyle(
                                                    color: color1,
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                  decoration:
                                                      const InputDecoration(
                                                    border: InputBorder.none,
                                                    contentPadding:
                                                        EdgeInsets.zero,
                                                    isDense: true,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Text(
                                              'min',
                                              style: TextStyle(
                                                color: Colors.grey.shade700,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            GestureDetector(
                                              onTap: () {
                                                int currentValue = int.tryParse(
                                                        minutesControllers[
                                                                index]
                                                            .text) ??
                                                    0;
                                                if (currentValue < 999) {
                                                  minutesControllers[index]
                                                          .text =
                                                      (currentValue + 1)
                                                          .toString();
                                                }
                                              },
                                              child: Container(
                                                width: 28,
                                                height: 28,
                                                decoration: BoxDecoration(
                                                  color: Colors.grey.shade100,
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: const Icon(
                                                  Icons.add,
                                                  size: 14,
                                                  color: color1,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          zoneEnabled[index] =
                                              !zoneEnabled[index];
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: zoneEnabled[index]
                                              ? Colors.green.shade100
                                              : Colors.red.shade100,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border: Border.all(
                                            color: zoneEnabled[index]
                                                ? Colors.green
                                                : Colors.red,
                                            width: 1.2,
                                          ),
                                        ),
                                        child: Icon(
                                          zoneEnabled[index]
                                              ? Icons.check_circle
                                              : Icons.cancel,
                                          color: zoneEnabled[index]
                                              ? Colors.green
                                              : Colors.red,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ),
                        ),
                        if (zoneEnabled.contains(false))
                          Padding(
                            padding: const EdgeInsets.only(
                              left: 20,
                              right: 20,
                              top: 12,
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.orange.withValues(alpha: 0.4),
                                ),
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: Colors.orange,
                                    size: 18,
                                  ),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Algunas zonas están desactivadas y no se incluirán en la rutina',
                                      style: TextStyle(
                                        color: Colors.orange,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 24),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () {
                                    setState(() {
                                      isRutina = false;
                                      routineNameController.clear();
                                      isRain = false;
                                    });
                                  },
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: color0,
                                    side: const BorderSide(
                                        color: color0, width: 1.5),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: const Text(
                                    'Cancelar',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () async {
                                    if (routineNameController.text
                                        .trim()
                                        .isEmpty) {
                                      showToast(
                                          'Por favor, asigna un nombre a la rutina');
                                      return;
                                    }

                                    final enabledZones = <String>[];
                                    for (int i = 0; i < zoneOrder.length; i++) {
                                      if (zoneEnabled[i]) {
                                        enabledZones.add(zoneOrder[i]);
                                      }
                                    }

                                    if (enabledZones.isEmpty) {
                                      showToast(
                                          'Debe habilitar al menos una zona');
                                      return;
                                    }

                                    final pasos = enabledZones.map((zone) {
                                      final index = zoneOrder.indexOf(zone);
                                      final minutes = int.tryParse(
                                              minutesControllers[index].text) ??
                                          5;
                                      return {
                                        'devices': [zone],
                                        'actions': {zone: true},
                                        'stepDelay': Duration(minutes: minutes),
                                        'stepDelayUnit': 'min',
                                      };
                                    }).toList();

                                    final riegoEvent = {
                                      'evento': 'cadena',
                                      'title':
                                          routineNameController.text.trim(),
                                      'creator': deviceName,
                                      'deviceGroup': enabledZones,
                                      'pasos': pasos,
                                      'isRain': isRain,
                                    };

                                    eventosCreados.add(riegoEvent);
                                    todosLosDispositivos.add(MapEntry(
                                      riegoEvent['title'] as String,
                                      enabledZones.join(','),
                                    ));

                                    //TODO añadir rutina a la base
                                    // final pasosToDynamo =
                                    //     enabledZones.map((zone) {
                                    //   final index = zoneOrder.indexOf(zone);
                                    //   final minutes = int.tryParse(
                                    //           minutesControllers[index]
                                    //               .text) ??
                                    //       5;
                                    //   return {
                                    //     'paso_index':
                                    //         enabledZones.indexOf(zone),
                                    //     'ejecutores': {zone: true},
                                    //     'delay': minutes * 60,
                                    //   };
                                    // }).toList();

                                    // putEventoControlPorCadena(
                                    //   currentUserEmail,
                                    //   routineNameController.text.trim(),
                                    //   pasosToDynamo,
                                    // );
                                    // putEventos(
                                    //     currentUserEmail, eventosCreados);

                                    printLog.d(eventosCreados, color: 'verde');
                                    setState(() {
                                      isRutina = false;
                                      routineNameController.clear();
                                      for (var controller
                                          in minutesControllers) {
                                        controller.text = '5';
                                      }
                                      zoneEnabled = List<bool>.filled(
                                              zoneOrder.length, true)
                                          .toList();
                                      isRain = false;
                                    });

                                    showToast(
                                        'Rutina de riego creada correctamente');
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: color0,
                                    foregroundColor: color1,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.check, size: 18),
                                      SizedBox(width: 6),
                                      Text(
                                        'Crear rutina',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            },

            //visual de añadir extensiones
            if (isRutina == false && isExtension == true) ...{
              Center(
                child: Card(
                  color: color1,
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width * 0.92,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 20),
                        const Text(
                          'Añadir Extensiones',
                          style: TextStyle(
                            color: color0,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.0),
                          child: Text(
                            'Solo podras seleccionar las extensiones que tengas reclamada su propiedad',
                            style: TextStyle(
                              color: color0,
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (extensionesEncontradas.isEmpty) ...{
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Container(
                              padding: const EdgeInsets.all(16.0),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    Border.all(color: Colors.red, width: 1.5),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.warning,
                                    color: Colors.red,
                                    size: 24,
                                  ),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'No tienes extensiones reclamadas. Reclama la propiedad de al menos una extensión para poder añadirla.',
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        } else ...{
                          () {
                            return ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: extensionesEncontradas.length,
                              itemBuilder: (context, index) {
                                String moduleName =
                                    extensionesEncontradas[index];
                                bool isSelected =
                                    extensionesTemporales.contains(moduleName);
                                return ListTile(
                                  leading: const Icon(Icons.devices_other,
                                      color: color0),
                                  title: Text(
                                    nicknamesMap[moduleName] ?? moduleName,
                                    style: const TextStyle(
                                      color: color0,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  trailing: Checkbox(
                                    value: isSelected,
                                    onChanged: (bool? value) {
                                      setState(() {
                                        if (value == true) {
                                          if (!extensionesTemporales
                                              .contains(moduleName)) {
                                            extensionesTemporales
                                                .add(moduleName);
                                          }
                                        } else {
                                          extensionesTemporales
                                              .remove(moduleName);
                                        }
                                      });
                                    },
                                    activeColor: Colors.red,
                                    checkColor: color0,
                                  ),
                                  onTap: () {
                                    setState(() {
                                      if (extensionesTemporales
                                          .contains(moduleName)) {
                                        extensionesTemporales
                                            .remove(moduleName);
                                      } else {
                                        extensionesTemporales.add(moduleName);
                                      }
                                    });
                                    printLog.d(extensionesTemporales,
                                        color: 'naranja');
                                  },
                                );
                              },
                            );
                          }(),
                        },
                        const SizedBox(height: 20),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () {
                                    setState(() {
                                      isExtension = false;
                                      extensionesTemporales.clear();
                                    });
                                  },
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: color0,
                                    side: const BorderSide(
                                        color: color0, width: 1.5),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: const Text(
                                    'Cancelar',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                    onPressed: () async {
                                      // Verificación: si no hay extensiones seleccionadas
                                      if (extensionesTemporales.isEmpty) {
                                        showToast(
                                            'Debe seleccionar al menos una extensión para añadir');
                                        return;
                                      }
                                      // Guardar las extensiones y establecer riegoMaster
                                      for (String extension
                                          in extensionesTemporales) {
                                        if (!extensionesVinculadas
                                            .contains(extension)) {
                                          extensionesVinculadas.add(extension);

                                          // Establecer riegoMaster en la extensión
                                          String extensionPc =
                                              DeviceManager.getProductCode(
                                                  extension);
                                          String extensionSn =
                                              DeviceManager.extractSerialNumber(
                                                  extension);
                                          await putRiegoMaster(extensionPc,
                                              extensionSn, deviceName);
                                        }
                                      }

                                      // Actualizar la lista de extensiones en el dispositivo maestro
                                      await putRiegoExtensions(
                                          pc, sn, extensionesVinculadas);

                                      setState(() {
                                        isExtension = false;
                                        extensionesTemporales.clear();
                                      });
                                      showToast(
                                          'Extensiones añadidas correctamente');
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          extensionesTemporales.isEmpty
                                              ? Colors.grey
                                              : color0,
                                      foregroundColor:
                                          extensionesTemporales.isEmpty
                                              ? Colors.grey[600]
                                              : color1,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    child: const Text(
                                      'Añadir Extensión',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    )),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            },
            SizedBox(
              height:
                  bottomBarHeight + MediaQuery.of(context).padding.bottom + 100,
            ),
          ],
        ),
      ),

      //*- Página 3: Gestión del Equipo -*\\
      const ManagerScreen(),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, A) {
        if (_isTutorialActive) return;
        showDisconnectDialog(context);
        Future.delayed(const Duration(seconds: 2), () async {
          await bluetoothManager.device.disconnect();
          if (context.mounted) {
            Navigator.pop(context);
            Navigator.pushReplacementNamed(context, '/menu');
          }
        });
        return;
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: color1,
          title: GestureDetector(
            onTap: () async {
              if (_isTutorialActive) return;
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
                    style: ButtonStyle(
                      foregroundColor: WidgetStateProperty.all(color0),
                    ),
                    child: const Text('Cancelar'),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                  TextButton(
                    style: ButtonStyle(
                      foregroundColor: WidgetStateProperty.all(color0),
                    ),
                    child: const Text('Guardar'),
                    onPressed: () {
                      setState(() {
                        String newNickname = nicknameController.text;
                        nickname = newNickname;
                        nicknamesMap[deviceName] = newNickname;
                        putNicknames(currentUserEmail, nicknamesMap);
                      });
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              );
            },
            child: Row(
              children: [
                Expanded(
                  key: keys['riego:titulo']!,
                  child: SizedBox(
                    height: 30,
                    width: 2,
                    child: AutoScrollingText(
                      text: nickname,
                      style: poppinsStyle.copyWith(color: color0),
                      velocity: 50,
                    ),
                  ),
                  // ScrollingText(
                  //   text: nickname,
                  //   style: poppinsStyle.copyWith(color: color0),
                  // ),
                ),
                const SizedBox(width: 3),
                const Icon(Icons.edit, size: 20, color: color0)
              ],
            ),
          ),
          leading: IconButton(
            key: keys['riego:estado']!,
            icon: const Icon(Icons.arrow_back_ios_new),
            color: color0,
            onPressed: () {
              if (_isTutorialActive) return;
              showDisconnectDialog(context);
              Future.delayed(const Duration(seconds: 2), () async {
                await bluetoothManager.device.disconnect();
                if (context.mounted) {
                  Navigator.pop(context);
                  Navigator.pushReplacementNamed(context, '/menu');
                }
              });
              return;
            },
          ),
          actions: [
            Icon(
              key: keys['riego:servidor']!,
              globalDATA['${DeviceManager.getProductCode(deviceName)}/${DeviceManager.extractSerialNumber(deviceName)}']
                          ?['cstate'] ??
                      false
                  ? Icons.cloud
                  : Icons.cloud_off,
              color: color0,
            ),
            IconButton(
              key: keys['riego:wifi']!,
              icon: Icon(wifiState.wifiIcon, color: color0),
              onPressed: () {
                if (_isTutorialActive) return;

                wifiText(context);
              },
            ),
          ],
        ),
        backgroundColor: color0,
        resizeToAvoidBottomInset: false,
        body: IgnorePointer(
          ignoring: _isTutorialActive,
          child: Stack(
            children: [
              PageView(
                controller: _pageController,
                physics: _isAnimating || _isTutorialActive
                    ? const NeverScrollableScrollPhysics()
                    : const BouncingScrollPhysics(),
                onPageChanged: onItemChanged,
                children: pages,
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: IgnorePointer(
                  ignoring: _isTutorialActive,
                  child: SafeArea(
                    child: CurvedNavigationBar(
                      index: _selectedIndex,
                      height: 75.0,
                      items: const <Widget>[
                        Icon(Icons.home, size: 30, color: color0),
                        //const Icon(Icons.bluetooth, size: 30, color: color0),
                        Icon(Icons.input, size: 30, color: color0),
                        Icon(Icons.settings, size: 30, color: color0),
                      ],
                      color: color1,
                      buttonBackgroundColor: color1,
                      backgroundColor: Colors.transparent,
                      animationCurve: Curves.easeInOut,
                      animationDuration: const Duration(milliseconds: 600),
                      onTap: onItemTapped,
                      letIndexChange: (index) => true,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: MediaQuery.of(context).padding.bottom,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
        // floatingActionButton: Visibility(
        //   visible: tutorial,
        //   child: AnimatedSlide(
        //     offset: _isTutorialActive ? const Offset(1.5, 0) : Offset.zero,
        //     duration: const Duration(milliseconds: 400),
        //     curve: Curves.easeInOut,
        //     child: Padding(
        //       padding: EdgeInsets.only(bottom: bottomBarHeight + 20),
        //       child: FloatingActionButton(
        //         onPressed: () {
        //           items = [];
        //           hardwareVersion == '240422A' ? isPinMode = true : null;
        //           initItems();
        //           setState(() {
        //             _isAnimating = true;
        //             _selectedIndex = 0;
        //             _isTutorialActive = true;
        //           });
        //           _pageController
        //               .animateToPage(
        //             0,
        //             duration: const Duration(milliseconds: 600),
        //             curve: Curves.easeInOut,
        //           )
        //               .then((_) {
        //             setState(() {
        //               _isAnimating = false;
        //             });
        //             if (context.mounted) {
        //               Tutorial.showTutorial(
        //                 context,
        //                 items,
        //                 _pageController,
        //                 onTutorialComplete: () {
        //                   setState(() {
        //                     _isTutorialActive = false;
        //                   });
        //                   printLog.i('Tutorial is complete!');
        //                 },
        //               );
        //             }
        //           });
        //         },
        //         backgroundColor: color4,
        //         shape: const CircleBorder(),
        //         child: const Icon(Icons.help, size: 30, color: color0),
        //       ),
        //     ),
        //   ),
        // ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      ),
    );
  }
}
