import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Global/manager_screen.dart';
import '../aws/dynamo/dynamo.dart';
import '../aws/mqtt/mqtt.dart';
import '../master.dart';
import '../Global/stored_data.dart';
import 'package:caldensmart/logger.dart';

class DomoticaPage extends ConsumerStatefulWidget {
  const DomoticaPage({super.key});
  @override
  DomoticaPageState createState() => DomoticaPageState();
}

class DomoticaPageState extends ConsumerState<DomoticaPage> {
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
  late List<bool> _selectedPins;
  late List<bool> _notis;
  TextEditingController emailController = TextEditingController();
  TextEditingController passController = TextEditingController();
  final TextEditingController modulePassController = TextEditingController();
  final PageController _pageController = PageController(initialPage: 0);
  final TextEditingController tenantController = TextEditingController();

  int _selectedIndex = 0;

  ///*- Elementos para tutoriales -*\\\
  List<TutorialItem> items = [];

  void initItems() {
    items.addAll({
      TutorialItem(
        globalKey: keys['domotica:estado']!,
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
        globalKey: keys['domotica:titulo']!,
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
        globalKey: keys['domotica:wifi']!,
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
        globalKey: keys['domotica:servidor']!,
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
      TutorialItem(
        globalKey: keys['domotica:modoPines']!,
        shapeFocus: ShapeFocus.roundedSquare,
        borderRadius: const Radius.circular(30),
        contentPosition: ContentPosition.below,
        focusMargin: 15,
        pageIndex: 1,
        child: !tenant
            ? const TutorialItemContent(
                title: 'Cambio de modo de pines',
                content:
                    'si introduces la clave del manual podrás modificar el estado comun de las salidas',
              )
            : const TutorialItemContent(
                title: 'Inquilino',
                content:
                    'Ciertas funciones estan bloqueadas y solo el dueño puede acceder',
              ),
      ),
      TutorialItem(
        globalKey: keys['managerScreen:titulo']!,
        borderRadius: const Radius.circular(15),
        shapeFocus: ShapeFocus.roundedSquare,
        focusMargin: 15,
        pageIndex: 2,
        contentPosition: ContentPosition.below,
        child: const TutorialItemContent(
          title: 'Gestión',
          content: 'Podrás reclamar el equipo y gestionar sus funciones',
        ),
      ),
      if (!tenant) ...{
        TutorialItem(
          globalKey: keys['managerScreen:reclamar']!,
          borderRadius: const Radius.circular(20),
          shapeFocus: ShapeFocus.roundedSquare,
          pageIndex: 2,
          contentPosition: ContentPosition.below,
          child: const TutorialItemContent(
            title: 'Reclamar administrador',
            content: 'Podras reclamar la administración del equipo',
          ),
        ),
      },
      if (owner == currentUserEmail) ...{
        TutorialItem(
          globalKey: keys['managerScreen:agregarAdmin']!,
          borderRadius: const Radius.circular(15),
          shapeFocus: ShapeFocus.roundedSquare,
          pageIndex: 2,
          contentPosition: ContentPosition.below,
          child: const TutorialItemContent(
            title: 'Añadir administradores secundarios',
            content: 'Podrás agregar correos secundarios hasta un límite de 3',
          ),
        ),
        TutorialItem(
          globalKey: keys['managerScreen:verAdmin']!,
          borderRadius: const Radius.circular(15),
          shapeFocus: ShapeFocus.roundedSquare,
          pageIndex: 2,
          contentPosition: ContentPosition.below,
          child: const TutorialItemContent(
            title: 'Ver administradores secundarios',
            content: 'Podrás ver o quitar los correos adicionales añadidos',
          ),
        ),
        TutorialItem(
          globalKey: keys['managerScreen:alquiler']!,
          borderRadius: const Radius.circular(15),
          shapeFocus: ShapeFocus.roundedSquare,
          pageIndex: 2,
          child: const TutorialItemContent(
            title: 'Alquiler temporario',
            content:
                'Puedes agregar el correo de tu inquilino al equipo y ajustarlo',
          ),
        ),
      },
      if (!tenant) ...{
        TutorialItem(
          globalKey: keys['managerScreen:accesoRapido']!,
          borderRadius: const Radius.circular(20),
          shapeFocus: ShapeFocus.roundedSquare,
          pageIndex: 2,
          child: const TutorialItemContent(
            title: 'Accesso rápido',
            content: 'Podrás encender y apagar el dispositivo desde el menú',
          ),
        ),
        // TutorialItem(
        //   globalKey: keys['managerScreen:desconexionNotificacion']!,
        //
        //   borderRadius: const Radius.circular(20),
        //   shapeFocus: ShapeFocus.roundedSquare,
        //   pageIndex: isPinMode ? 2 : 1,
        //   child: const TutorialItemContent(
        //     title: 'Notificación de desconexión',
        //     content: 'Puedes establecer una alerta si el equipo se desconecta',
        //   ),
        // ),
      },
      TutorialItem(
        globalKey: keys['managerScreen:imagen']!,
        borderRadius: const Radius.circular(20),
        shapeFocus: ShapeFocus.roundedSquare,
        pageIndex: 2,
        child: const TutorialItemContent(
          title: 'Imagen del dispositivo',
          content: 'Podrás ajustar la imagen del equipo en el menú',
        ),
      ),
    });
  }

  ///*- Elementos para tutoriales -*\\\

  @override
  void initState() {
    super.initState();
    _selectedPins = List<bool>.filled(parts.length, false);
    _notis = notificationMap[
            '${DeviceManager.getProductCode(deviceName)}/${DeviceManager.extractSerialNumber(deviceName)}'] ??
        List<bool>.filled(parts.length, false);

    printLog.i(_notis);

    tracking = devicesToTrack.contains(deviceName);

    processSelectedPins();

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

  Future<void> processSelectedPins() async {
    List<String> pins = await loadPinToTrack(deviceName);

    setState(() {
      for (int i = 0; i < pins.length; i++) {
        pins.contains(i.toString())
            ? _selectedPins[i] = true
            : _selectedPins[i] = false;
      }
    });
  }

  void controlOut(bool value, int index) {
    String fun = '$index#${value ? '1' : '0'}';
    myDevice.ioUuid.write(fun.codeUnits);
    String topic =
        'devices_rx/${DeviceManager.getProductCode(deviceName)}/${DeviceManager.extractSerialNumber(deviceName)}';
    String topic2 =
        'devices_tx/${DeviceManager.getProductCode(deviceName)}/${DeviceManager.extractSerialNumber(deviceName)}';
    String message = jsonEncode({
      'pinType': tipo[index] == 'Salida' ? '0' : '1',
      'index': index,
      'w_status': value,
      'r_state': common[index],
    });
    sendMessagemqtt(topic, message);
    sendMessagemqtt(topic2, message);

    globalDATA
        .putIfAbsent(
            '${DeviceManager.getProductCode(deviceName)}/${DeviceManager.extractSerialNumber(deviceName)}',
            () => {})
        .addAll({'io$index': message});

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
    await myDevice.toolsUuid.setNotifyValue(true);

    final wifiSub =
        myDevice.toolsUuid.onValueReceived.listen((List<int> status) {
      updateWifiValues(status);
    });

    myDevice.device.cancelWhenDisconnected(wifiSub);
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

        globalDATA
            .putIfAbsent(
                '${DeviceManager.getProductCode(deviceName)}/${DeviceManager.extractSerialNumber(deviceName)}',
                () => {})
            .addAll({
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

        globalDATA
            .putIfAbsent(
                '${DeviceManager.getProductCode(deviceName)}/${DeviceManager.extractSerialNumber(deviceName)}',
                () => {})
            .addAll({
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

        globalDATA
            .putIfAbsent(
                '${DeviceManager.getProductCode(deviceName)}/${DeviceManager.extractSerialNumber(deviceName)}',
                () => {})
            .addAll({
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

    for (int i = 0; i < parts.length; i++) {
      if (tipo[i] == 'Salida') {
        String dv = '${deviceName}_$i';
        if (!alexaDevices.contains(dv)) {
          alexaDevices.add(dv);
          putDevicesForAlexa(currentUserEmail, alexaDevices);
        }
      }
    }
  }

  void subToIO() async {
    await myDevice.ioUuid.setNotifyValue(true);
    printLog.i('Subscrito a IO');

    var ioSub = myDevice.ioUuid.onValueReceived.listen((event) {
      printLog.i('Cambio en IO');
      processValues(event);
    });

    myDevice.device.cancelWhenDisconnected(ioSub);
  }

  Future<void> openTrackingDialog() async {
    bool fun = false;
    List<bool> tempSelectedPins = List<bool>.from(_selectedPins);

    await showGeneralDialog(
      context: context,
      barrierDismissible: false, // Cambiado de true a false
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withValues(alpha: 0.5),
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
                          color: Colors.black.withValues(alpha: 0.5),
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
                                            nicknamesMap[
                                                    '${deviceName}_$index'] ??
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
                                    // *** Eliminado el botón "Cancelar" ***
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
                                              if (_selectedPins[i] &&
                                                  !pins
                                                      .contains(i.toString())) {
                                                pins.add(i.toString());
                                              }
                                            }
                                          });
                                          await savePinToTrack(
                                              pins, deviceName);

                                          printLog.i(
                                              'When haces tus momos en flutter :v');
                                          fun = true;
                                          context.mounted
                                              ? Navigator.of(context).pop()
                                              : printLog.i("Contextn't");
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
                              shadowColor: Colors.black.withValues(alpha: 0.4),
                              child: CircleAvatar(
                                radius: 50,
                                backgroundColor: color3,
                                child: Image.asset(
                                  'assets/branch/dragon.png',
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

    printLog.i('ME WHEN YOUR MOM WHEN ME WHEN YOUR MOM $fun');
    if (fun) {
      printLog.i('Pov: Sos re onichan mal');
      setState(() {
        tracking = true;
      });
      devicesToTrack.add(deviceName);
      await saveDeviceListToTrack(devicesToTrack);
      printLog.i('Equipo $devicesToTrack');
      SharedPreferences prefs = await SharedPreferences.getInstance();
      bool hasInitService = prefs.getBool('hasInitService') ?? false;
      printLog.i('Se inició el servicio? $hasInitService');
      if (!hasInitService) {
        printLog.i('Empiezo');
        await initializeService();
        printLog.i('Acabe');
      }

      await Future.delayed(const Duration(seconds: 30));
      final backService = FlutterBackgroundService();
      printLog.i('Xd');
      backService.invoke('presenceControl');
    }
  }

  bool isValidEmail(String email) {
    final RegExp emailRegex = RegExp(
      r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@"
      r"[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)*$",
    );
    return emailRegex.hasMatch(email);
  }

  Future<void> addSecondaryAdmin(String email) async {
    if (!isValidEmail(email)) {
      showToast('Por favor, introduce un correo electrónico válido.');
      return;
    }

    if (adminDevices.contains(email)) {
      showToast('Este administrador ya está añadido.');
      return;
    }

    try {
      List<String> updatedAdmins = List.from(adminDevices)..add(email);

      await putSecondaryAdmins(DeviceManager.getProductCode(deviceName),
          DeviceManager.extractSerialNumber(deviceName), updatedAdmins);

      setState(() {
        adminDevices = updatedAdmins;
        emailController.clear();
      });

      showToast('Administrador añadido correctamente.');
    } catch (e) {
      printLog.i('Error al añadir administrador secundario: $e');
      showToast('Error al añadir el administrador. Inténtalo de nuevo.');
    }
  }

  Future<void> removeSecondaryAdmin(String email) async {
    try {
      List<String> updatedAdmins = List.from(adminDevices)..remove(email);

      await putSecondaryAdmins(DeviceManager.getProductCode(deviceName),
          DeviceManager.extractSerialNumber(deviceName), updatedAdmins);

      setState(() {
        adminDevices.remove(email);
      });

      showToast('Administrador eliminado correctamente.');
    } catch (e) {
      printLog.i('Error al eliminar administrador secundario: $e');
      showToast('Error al eliminar el administrador. Inténtalo de nuevo.');
    }
  }

  Future<int?> showPinSelectionDialog(BuildContext context) async {
    int? selectedPin;
    return showDialog<int>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              backgroundColor: color3,
              title: Text(
                'Selecciona un pin',
                style: GoogleFonts.poppins(
                  color: color0,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SingleChildScrollView(
                child: ListBody(
                  children: List.generate(parts.length, (index) {
                    var equipo = parts[index].split(':');
                    printLog.i(equipo);
                    return equipo[0] == '0'
                        ? RadioListTile<int>(
                            title: Text(
                              nicknamesMap['${deviceName}_$index'] ??
                                  'Salida $index',
                              style: GoogleFonts.poppins(
                                color: color0,
                                fontSize: 16,
                              ),
                            ),
                            value: index,
                            groupValue: selectedPin,
                            activeColor: color6,
                            onChanged: (int? value) {
                              setState(() {
                                selectedPin = value;
                              });
                            },
                          )
                        : const SizedBox.shrink();
                  }),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: Text(
                    'Aceptar',
                    style: GoogleFonts.poppins(color: color6),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop(selectedPin);
                  },
                ),
              ],
            );
          },
        );
      },
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

    final List<Widget> pages = [
      //*- Página 1 entradas/salidas -*\\
      SingleChildScrollView(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.8,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: ListView.separated(
              itemCount: tipo.length + 1,
              separatorBuilder: (context, index) => const SizedBox(height: 20),
              itemBuilder: (context, index) {
                if (index == tipo.length) {
                  return Padding(
                    padding: EdgeInsets.only(bottom: bottomBarHeight + 30),
                  );
                }
                bool entrada = tipo[index] == 'Entrada';
                bool isOn = estado[index] == '1';
                bool isPresenceControlled = _selectedPins[index] && tracking;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  decoration: BoxDecoration(
                    color: color3,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const SizedBox(width: 6),
                          Expanded(
                            child: GestureDetector(
                              onTap: () async {
                                TextEditingController nicknameController =
                                    TextEditingController(
                                  text: nicknamesMap['${deviceName}_$index'] ??
                                      '${tipo[index]} $index',
                                );
                                showAlertDialog(
                                  context,
                                  false,
                                  Text(
                                    'Editar Nombre',
                                    style: GoogleFonts.poppins(color: color0),
                                  ),
                                  TextField(
                                    controller: nicknameController,
                                    style: const TextStyle(color: color0),
                                    cursorColor: color0,
                                    decoration: InputDecoration(
                                      hintText:
                                          "Nuevo nombre para ${tipo[index]} $index",
                                      hintStyle: TextStyle(
                                        color: color0.withValues(alpha: 0.6),
                                      ),
                                      enabledBorder: UnderlineInputBorder(
                                        borderSide: BorderSide(
                                          color: color0.withValues(alpha: 0.5),
                                        ),
                                      ),
                                      focusedBorder: const UnderlineInputBorder(
                                        borderSide: BorderSide(color: color0),
                                      ),
                                    ),
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
                                      onPressed: () {
                                        setState(() {
                                          String newName =
                                              nicknameController.text;
                                          nicknamesMap['${deviceName}_$index'] =
                                              newName;
                                          putNicknames(
                                              currentUserEmail, nicknamesMap);
                                        });
                                        Navigator.of(context).pop();
                                      },
                                      child: const Text(
                                        'Guardar',
                                        style: TextStyle(color: color0),
                                      ),
                                    ),
                                  ],
                                );
                              },
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      nicknamesMap['${deviceName}_$index'] ??
                                          '${tipo[index]} $index',
                                      style: GoogleFonts.poppins(
                                        color: color0,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.edit,
                                      size: 22,
                                      color: color0,
                                    ),
                                    onPressed: () {
                                      TextEditingController nicknameController =
                                          TextEditingController(
                                        text: nicknamesMap[
                                                '${deviceName}_$index'] ??
                                            '${tipo[index]} $index',
                                      );
                                      showAlertDialog(
                                        context,
                                        false,
                                        Text(
                                          'Editar Nombre',
                                          style: GoogleFonts.poppins(
                                              color: color0),
                                        ),
                                        TextField(
                                          controller: nicknameController,
                                          style: const TextStyle(color: color0),
                                          cursorColor: color0,
                                          decoration: InputDecoration(
                                            hintText:
                                                "Nuevo nombre para ${tipo[index]} $index",
                                            hintStyle: TextStyle(
                                              color:
                                                  color0.withValues(alpha: 0.6),
                                            ),
                                            enabledBorder: UnderlineInputBorder(
                                              borderSide: BorderSide(
                                                color: color0.withValues(
                                                    alpha: 0.5),
                                              ),
                                            ),
                                            focusedBorder:
                                                const UnderlineInputBorder(
                                              borderSide:
                                                  BorderSide(color: color0),
                                            ),
                                          ),
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
                                            onPressed: () {
                                              setState(() {
                                                String newName =
                                                    nicknameController.text;
                                                nicknamesMap[
                                                        '${deviceName}_$index'] =
                                                    newName;
                                                putNicknames(currentUserEmail,
                                                    nicknamesMap);
                                              });
                                              Navigator.of(context).pop();
                                            },
                                            child: const Text(
                                              'Guardar',
                                              style: TextStyle(color: color0),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      entrada
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Center(
                                  child: Icon(
                                    alertIO[index]
                                        ? Icons.new_releases
                                        : Icons.new_releases,
                                    color: alertIO[index]
                                        ? Colors.red
                                        : Colors.grey,
                                    size: 40,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _notis[index]
                                          ? '¿Desactivar notificaciones?'
                                          : '¿Activar notificaciones?',
                                      style: const TextStyle(
                                        color: color0,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () {
                                        bool activated = _notis[index];
                                        setState(() {
                                          activated = !activated;
                                          _notis[index] = activated;
                                        });
                                        notificationMap[
                                                '${DeviceManager.getProductCode(deviceName)}/${DeviceManager.extractSerialNumber(deviceName)}'] =
                                            _notis;
                                        saveNotificationMap(notificationMap);
                                      },
                                      icon: _notis[index]
                                          ? const Icon(
                                              Icons.notifications_off,
                                              color: color6,
                                            )
                                          : const Icon(
                                              Icons.notification_add_rounded,
                                              color: Colors.green,
                                            ),
                                    ),
                                  ],
                                ),
                              ],
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Icon(
                                  isOn ? Icons.check_circle : Icons.cancel,
                                  color: isOn ? Colors.green : Colors.red,
                                  size: 40,
                                ),
                                GestureDetector(
                                  onTap: () {
                                    isPresenceControlled
                                        ? null
                                        : setState(() {
                                            controlOut(!isOn, index);
                                            estado[index] = !isOn ? '1' : '0';
                                          });
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    width: 55,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(20),
                                      color: isPresenceControlled
                                          ? Colors.grey
                                          : isOn
                                              ? Colors.greenAccent.shade400
                                              : color6,
                                    ),
                                    child: AnimatedAlign(
                                      duration:
                                          const Duration(milliseconds: 300),
                                      alignment: isOn
                                          ? Alignment.centerRight
                                          : Alignment.centerLeft,
                                      curve: Curves.easeInOut,
                                      child: Padding(
                                        padding: const EdgeInsets.all(3.0),
                                        child: Container(
                                          width: 24,
                                          height: 24,
                                          decoration: const BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                      if (isPresenceControlled) ...{
                        Container(
                          decoration: BoxDecoration(
                            color: color1,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Center(
                            child: Text(
                              'Desactiva control por presencia para utilizar esta función',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: color3,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      },
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),

      //*- Página 2 trackeo -*\\

      // Stack(
      //   children: [
      //     Center(
      //       child: Column(
      //         mainAxisAlignment: MainAxisAlignment.center,
      //         crossAxisAlignment: CrossAxisAlignment.center,
      //         children: [
      //           Text(
      //             tracking
      //                 ? 'Control por presencia iniciado'
      //                 : 'Control por presencia desactivado',
      //             style: GoogleFonts.poppins(
      //               fontSize: 28,
      //               fontWeight: FontWeight.bold,
      //               color: color3,
      //             ),
      //             textAlign: TextAlign.center,
      //           ),
      //           const SizedBox(height: 40),
      //           GestureDetector(
      //             onTap: isAgreeChecked
      //                 ? () {
      //                     if (tracking) {
      //                       showAlertDialog(
      //                         context,
      //                         false,
      //                         const Text(
      //                             '¿Seguro que quiere cancelar el control por presencia?'),
      //                         const Text(
      //                             'Deshabilitar hará que puedas controlarlo manualmente.\nSi quieres volver a utilizar control por presencia deberás habilitarlo nuevamente'),
      //                         [
      //                           TextButton(
      //                             onPressed: () {
      //                               Navigator.pop(context);
      //                             },
      //                             child: const Text('Cancelar'),
      //                           ),
      //                           TextButton(
      //                             onPressed: () async {
      //                               setState(() {
      //                                 tracking = false;
      //                               });
      //                               devicesToTrack.remove(deviceName);
      //                               saveDeviceListToTrack(devicesToTrack);
      //                               List<String> jijeo = [];
      //                               savePinToTrack(jijeo, deviceName);
      //                               context.mounted
      //                                   ? Navigator.of(context).pop()
      //                                   : printLog.i("Contextn't");
      //                             },
      //                             child: const Text('Aceptar'),
      //                           ),
      //                         ],
      //                       );
      //                     } else {
      //                       openTrackingDialog();
      //                       setState(() {
      //                         tracking = true;
      //                       });
      //                     }
      //                   }
      //                 : null,
      //             child: AnimatedContainer(
      //               duration: const Duration(milliseconds: 500),
      //               padding: const EdgeInsets.all(20),
      //               decoration: BoxDecoration(
      //                 color: tracking ? Colors.greenAccent : Colors.redAccent,
      //                 shape: BoxShape.circle,
      //                 boxShadow: const [
      //                   BoxShadow(
      //                     color: Colors.black26,
      //                     blurRadius: 10,
      //                     offset: Offset(0, 5),
      //                   ),
      //                 ],
      //               ),
      //               child: const Icon(
      //                 Icons.directions_walk,
      //                 size: 80,
      //                 color: Colors.white,
      //               ),
      //             ),
      //           ),
      //           const SizedBox(height: 60),
      //           Card(
      //             shape: RoundedRectangleBorder(
      //               borderRadius: BorderRadius.circular(20),
      //             ),
      //             elevation: 5,
      //             color: color3,
      //             child: Padding(
      //               padding: const EdgeInsets.all(20.0),
      //               child: Column(
      //                 crossAxisAlignment: CrossAxisAlignment.start,
      //                 children: [
      //                   Text(
      //                     'Habilitar esta función hará que la aplicación use más recursos de lo común. Si decides utilizarla, es bajo tu responsabilidad.',
      //                     style: GoogleFonts.poppins(
      //                       fontSize: 16,
      //                       color: color0,
      //                     ),
      //                   ),
      //                   const SizedBox(height: 10),
      //                   CheckboxListTile(
      //                     title: Text(
      //                       'Sí, estoy de acuerdo',
      //                       style: GoogleFonts.poppins(
      //                         fontSize: 16,
      //                         color: color0,
      //                       ),
      //                     ),
      //                     value: isAgreeChecked,
      //                     activeColor: color0,
      //                     onChanged: (bool? value) {
      //                       if (value == false && tracking) {
      //                         // Mostrar el diálogo de confirmación si el usuario intenta desmarcar mientras el trackeo está activado
      //                         showAlertDialog(
      //                           context,
      //                           false,
      //                           const Text(
      //                             '¿Seguro que quiere cancelar el control por presencia?',
      //                           ),
      //                           const Text(
      //                             'Deshabilitar hará que puedas controlarlo manualmente.\nSi quieres volver a utilizar control por presencia deberás habilitarlo nuevamente',
      //                           ),
      //                           [
      //                             TextButton(
      //                               onPressed: () {
      //                                 // Cerrar el diálogo sin cambiar el estado del checkbox
      //                                 Navigator.pop(context);
      //                               },
      //                               child: const Text('Cancelar'),
      //                             ),
      //                             TextButton(
      //                               onPressed: () {
      //                                 // Confirmación: desmarcar checkbox y detener el trackeo
      //                                 setState(() {
      //                                   isAgreeChecked = false;
      //                                   tracking = false;
      //                                 });
      //                                 devicesToTrack.remove(deviceName);
      //                                 saveDeviceListToTrack(devicesToTrack);
      //                                 Navigator.pop(context);
      //                               },
      //                               child: const Text('Aceptar'),
      //                             ),
      //                           ],
      //                         );
      //                       } else {
      //                         // Permitir el cambio si el checkbox se está marcando o si el trackeo está desactivado
      //                         setState(() {
      //                           isAgreeChecked = value ?? false;
      //                         });
      //                       }
      //                     },
      //                     controlAffinity: ListTileControlAffinity.leading,
      //                   ),
      //                 ],
      //               ),
      //             ),
      //           ),
      //         ],
      //       ),
      //     ),
      //     if (!deviceOwner && owner != '')
      //       Container(
      //         color: Colors.black.withValues(alpha: 0.7),
      //         child: const Center(
      //           child: Text(
      //             'No tienes acceso a esta función',
      //             style: TextStyle(color: Colors.white, fontSize: 18),
      //           ),
      //         ),
      //       ),
      //   ],
      // ),

      Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 30,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  key: keys['domotica:modoPines']!,
                  'Cambio de Modo de Pines',
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: color3,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                Card(
                  color: color3,
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 500),
                          child: isPasswordCorrect
                              ? const Icon(
                                  HugeIcons.strokeRoundedSquareUnlock02,
                                  color: color0,
                                  size: 40,
                                  key: ValueKey('open_lock'),
                                )
                              : const Icon(
                                  HugeIcons.strokeRoundedSquareLock02,
                                  color: color0,
                                  size: 40,
                                  key: ValueKey('closed_lock'),
                                ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Ingresa la contraseña del módulo ubicada en el manual',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            color: color0,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: modulePassController,
                          style: const TextStyle(color: color0, fontSize: 16),
                          cursorColor: color0,
                          obscureText: true,
                          onChanged: (value) {
                            setState(() {
                              isPasswordCorrect = value == '53494d45';
                            });
                          },
                          decoration: InputDecoration(
                            prefixIcon: Icon(
                              Icons.key,
                              color: color0.withValues(alpha: 0.7),
                            ),
                            hintText: "Contraseña",
                            hintStyle: TextStyle(
                              color: color0.withValues(alpha: 0.6),
                            ),
                            enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(
                                color: color0.withValues(alpha: 0.5),
                              ),
                            ),
                            focusedBorder: const UnderlineInputBorder(
                              borderSide: BorderSide(
                                color: color0,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                if (isPasswordCorrect)
                  FloatingActionButton.extended(
                    onPressed: () {
                      setState(() {
                        isChangeModeVisible = !isChangeModeVisible;
                      });
                    },
                    backgroundColor: color3,
                    foregroundColor: color0,
                    icon: const Icon(Icons.settings, color: color0),
                    label: Text(
                      'Cambiar modo de pines',
                      style: GoogleFonts.poppins(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                const SizedBox(height: 30),
                if (isChangeModeVisible && isPasswordCorrect)
                  Column(
                    children: [
                      for (var i = 0; i < parts.length; i++) ...[
                        if (tipo[i] == 'Entrada') ...{
                          Card(
                            color: color3,
                            elevation: 6,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0, vertical: 24.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    nicknamesMap['${deviceName}_${parts[i]}'] ??
                                        '${tipo[i]} $i',
                                    style: GoogleFonts.poppins(
                                      color: color0,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Puedes cambiar entre Normal Abierto (NA) y Normal Cerrado (NC)',
                                        style: GoogleFonts.poppins(
                                          fontSize: 16,
                                          color: color0,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 20),
                                      Container(
                                        height: 40,
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(30.0),
                                          border: Border.all(
                                            color: color0,
                                            width: 2,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: GestureDetector(
                                                onTap: () {
                                                  setState(() {
                                                    String data =
                                                        '${DeviceManager.getProductCode(deviceName)}[14]($i#0)';
                                                    printLog.i(data);
                                                    myDevice.toolsUuid
                                                        .write(data.codeUnits);
                                                    common[i] = '0';
                                                  });
                                                  //TODO normal abierto
                                                },
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    color: common[i] == '0'
                                                        ? color0
                                                        : Colors.transparent,
                                                    borderRadius:
                                                        const BorderRadius.only(
                                                      topLeft:
                                                          Radius.circular(28),
                                                      bottomLeft:
                                                          Radius.circular(28),
                                                    ),
                                                  ),
                                                  child: Center(
                                                    child: Text(
                                                      'Normal Abierto',
                                                      style:
                                                          GoogleFonts.poppins(
                                                        fontSize: 14,
                                                        color: common[i] == '0'
                                                            ? color3
                                                            : color0,
                                                      ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Container(
                                              width: 2,
                                              color: color0,
                                            ),
                                            Expanded(
                                              child: GestureDetector(
                                                onTap: () {
                                                  //TODO normal cerrado
                                                  setState(() {
                                                    String data =
                                                        '${DeviceManager.getProductCode(deviceName)}[14]($i#1)';
                                                    printLog.i(data);
                                                    myDevice.toolsUuid
                                                        .write(data.codeUnits);
                                                    common[i] = '1';
                                                  });
                                                },
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    color: common[i] == '1'
                                                        ? color0
                                                        : Colors.transparent,
                                                    borderRadius:
                                                        const BorderRadius.only(
                                                      topRight:
                                                          Radius.circular(28),
                                                      bottomRight:
                                                          Radius.circular(28),
                                                    ),
                                                  ),
                                                  child: Center(
                                                    child: Text(
                                                      'Normal Cerrado',
                                                      style:
                                                          GoogleFonts.poppins(
                                                        fontSize: 14,
                                                        color: common[i] == '1'
                                                            ? color3
                                                            : color0,
                                                      ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
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
                                  const SizedBox(height: 10),
                                  if (Versioner.isPrevious(
                                      hardwareVersion, '240422A')) ...{
                                    const Divider(),
                                    const SizedBox(height: 10),
                                    Center(
                                      child: Text(
                                        tipo[i] == 'Entrada'
                                            ? '¿Cambiar de entrada a salida?'
                                            : '¿Cambiar de salida a entrada?',
                                        style: GoogleFonts.poppins(
                                          color: color0,
                                          fontSize: 16,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Center(
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          foregroundColor: color3,
                                          backgroundColor: color0,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 24.0, vertical: 12.0),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                        ),
                                        onPressed: () {
                                          String fun =
                                              '${DeviceManager.getProductCode(deviceName)}[13]($i#${tipo[i] == 'Entrada' ? '0' : '1'})';
                                          printLog.i(fun);
                                          myDevice.toolsUuid
                                              .write(fun.codeUnits);
                                        },
                                        child: const Text(
                                          'CAMBIAR',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                  },
                                ],
                              ),
                            ),
                          ),
                        },
                        const SizedBox(height: 20),
                        if (i == parts.length - 1) ...{
                          Padding(
                            padding:
                                EdgeInsets.only(bottom: bottomBarHeight + 10),
                          ),
                        }
                      ],
                    ],
                  ),
              ],
            ),
          ),
          if (!deviceOwner && owner != '')
            Container(
              color: Colors.black.withValues(alpha: 0.7),
              child: const Center(
                child: Text(
                  'No tienes acceso a esta función',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              ),
            ),
        ],
      ),

      //*- Página 4: Gestión del Equipo -*\\
      const ManagerScreen(),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, A) {
        if (_isTutorialActive) return;
        showDisconnectDialog(context);
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
                  key: keys['domotica:titulo']!,
                  child: Text(
                    nickname,
                    overflow: TextOverflow.ellipsis,
                    style: poppinsStyle.copyWith(color: color0),
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
            key: keys['domotica:estado']!,
            icon: const Icon(Icons.arrow_back_ios_new),
            color: color0,
            onPressed: () {
              if (_isTutorialActive) return;

              showDisconnectDialog(context);
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
            Icon(
              key: keys['domotica:servidor']!,
              globalDATA['${DeviceManager.getProductCode(deviceName)}/${DeviceManager.extractSerialNumber(deviceName)}']
                          ?['cstate'] ??
                      false
                  ? Icons.cloud
                  : Icons.cloud_off,
              color: color0,
            ),
            IconButton(
              key: keys['domotica:wifi']!,
              icon: Icon(wifiState.wifiIcon, color: color0),
              onPressed: () {
                if (_isTutorialActive) return;

                wifiText(context);
              },
            ),
          ],
        ),
        backgroundColor: color1,
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
                  child: CurvedNavigationBar(
                    index: _selectedIndex,
                    height: 75.0,
                    items: const <Widget>[
                      Icon(Icons.home, size: 30, color: color0),
                      //const Icon(Icons.bluetooth, size: 30, color: color0),
                      Icon(Icons.input, size: 30, color: color0),
                      Icon(Icons.settings, size: 30, color: color0),
                    ],
                    color: color3,
                    buttonBackgroundColor: color3,
                    backgroundColor: Colors.transparent,
                    animationCurve: Curves.easeInOut,
                    animationDuration: const Duration(milliseconds: 600),
                    onTap: onItemTapped,
                    letIndexChange: (index) => true,
                  ),
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: Visibility(
          visible: tutorial,
          child: AnimatedSlide(
            offset: _isTutorialActive ? const Offset(1.5, 0) : Offset.zero,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
            child: Padding(
              padding: EdgeInsets.only(bottom: bottomBarHeight + 20),
              child: FloatingActionButton(
                onPressed: () {
                  items = [];
                  hardwareVersion == '240422A' ? isPinMode = true : null;
                  initItems();
                  setState(() {
                    _isAnimating = true;
                    _selectedIndex = 0;
                    _isTutorialActive = true;
                  });
                  _pageController
                      .animateToPage(
                    0,
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeInOut,
                  )
                      .then((_) {
                    setState(() {
                      _isAnimating = false;
                    });
                    if (context.mounted) {
                      Tutorial.showTutorial(
                        context,
                        items,
                        _pageController,
                        onTutorialComplete: () {
                          setState(() {
                            _isTutorialActive = false;
                          });
                          printLog.i('Tutorial is complete!');
                        },
                      );
                    }
                  });
                },
                backgroundColor: color6,
                shape: const CircleBorder(),
                child: const Icon(Icons.help, size: 30, color: color0),
              ),
            ),
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      ),
    );
  }
}
