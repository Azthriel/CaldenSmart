import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Global/manager_screen.dart';
import '../aws/dynamo/dynamo.dart';
import '../aws/dynamo/dynamo_certificates.dart';
import '../aws/mqtt/mqtt.dart';
import '../master.dart';
import '../Global/stored_data.dart';

// CLASES \\

class Rele1i1oPage extends StatefulWidget {
  const Rele1i1oPage({super.key});
  @override
  Rele1i1oPageState createState() => Rele1i1oPageState();
}

class Rele1i1oPageState extends State<Rele1i1oPage> {
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
  bool _isAnimating = false;
  bool _isTutorialActive = false;

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
        globalKey: KeyManager.rele1i1o.estadoKey,
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: const Radius.circular(0),
        shapeFocus: ShapeFocus.oval,
        radius: 0,
        pageIndex: 0,
        child: const TutorialItemContent(
          title: 'Estado del equipo',
          content:
              'Podrás revisar el estado de las entradas y modificar el estado de las salidas',
        ),
      ),
      TutorialItem(
        globalKey: KeyManager.rele1i1o.titleKey,
        color: Colors.black.withValues(alpha: 0.6),
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
        globalKey: KeyManager.rele1i1o.wifiKey,
        color: Colors.black.withValues(alpha: 0.6),
        shapeFocus: ShapeFocus.oval,
        borderRadius: const Radius.circular(15.0),
        radius: 25,
        contentPosition: ContentPosition.below,
        pageIndex: 0,
        child: const TutorialItemContent(
          title: 'Menu Wifi',
          content:
              'Podrás observar el estado de la conexión wifi del dispositivo',
        ),
      ),
      TutorialItem(
        globalKey: KeyManager.rele1i1o.distanceKey,
        color: Colors.black.withValues(alpha: 0.6),
        shapeFocus: ShapeFocus.oval,
        borderRadius: const Radius.circular(0),
        radius: 0,
        pageIndex: 1,
        child: const TutorialItemContent(
          title: 'Control por distancia',
          content:
              'Podrás ajustar la distancia de encendido y apagado de tu dispositivo',
        ),
      ),
      TutorialItem(
        globalKey: KeyManager.rele1i1o.distanceBottomKey,
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: const Radius.circular(10),
        radius: 90,
        shapeFocus: ShapeFocus.oval,
        pageIndex: 1,
        child: const TutorialItemContent(
          title: 'Botón de encendido',
          content: 'Podrás activar esta función y configurar la distancia',
        ),
      ),
      TutorialItem(
        globalKey: KeyManager.rele1i1o.pinModeKey,
        color: Colors.black.withValues(alpha: 0.6),
        shapeFocus: ShapeFocus.oval,
        borderRadius: const Radius.circular(0),
        radius: 0,
        contentPosition: ContentPosition.below,
        pageIndex: 2,
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
        globalKey: KeyManager.managerScreen.adminKey,
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: const Radius.circular(0),
        shapeFocus: ShapeFocus.oval,
        pageIndex: 3,
        radius: 0,
        contentPosition: ContentPosition.below,
        child: const TutorialItemContent(
          title: 'Gestión',
          content: 'Podrás reclamar el equipo y gestionar sus funciones',
        ),
      ),
      if (!tenant) ...{
        TutorialItem(
          globalKey: KeyManager.managerScreen.claimKey,
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: const Radius.circular(20),
          shapeFocus: ShapeFocus.roundedSquare,
          pageIndex: 3,
          contentPosition: ContentPosition.below,
          child: const TutorialItemContent(
            title: 'Reclamar administrador',
            content:
                'Presiona este botón para reclamar la administración del equipo',
          ),
        ),
      },
      if (owner == currentUserEmail) ...{
        TutorialItem(
          globalKey: KeyManager.managerScreen.agreeAdminKey,
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: const Radius.circular(15),
          shapeFocus: ShapeFocus.roundedSquare,
          pageIndex: 3,
          contentPosition: ContentPosition.below,
          child: const TutorialItemContent(
            title: 'Añadir administradores secundarios',
            content: 'Podrás agregar correos secundarios hasta un límite de 3',
          ),
        ),
        TutorialItem(
          globalKey: KeyManager.managerScreen.viewAdminKey,
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: const Radius.circular(15),
          shapeFocus: ShapeFocus.roundedSquare,
          pageIndex: 3,
          contentPosition: ContentPosition.below,
          child: const TutorialItemContent(
            title: 'Ver administradores secundarios',
            content: 'Podrás ver o quitar los correos adicionales añadidos',
          ),
        ),
        TutorialItem(
          globalKey: KeyManager.managerScreen.habitKey,
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: const Radius.circular(15),
          shapeFocus: ShapeFocus.roundedSquare,
          pageIndex: 3,
          child: const TutorialItemContent(
            title: 'Alquiler temporario',
            content:
                'Puedes agregar el correo de tu inquilino al equipo y ajustarlo',
          ),
        ),
      },
      if (!tenant) ...{
        TutorialItem(
          globalKey: KeyManager.managerScreen.fastBotonKey,
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: const Radius.circular(20),
          shapeFocus: ShapeFocus.roundedSquare,
          pageIndex: 3,
          child: const TutorialItemContent(
            title: 'Accesso rápido',
            content: 'Podrás encender y apagar el dispositivo desde el menú',
          ),
        ),
        // TutorialItem(
        //   globalKey: KeyManager.managerScreen.discNotificationKey,
        //   color: Colors.black.withValues(alpha: 0.6),
        //   borderRadius: const Radius.circular(20),
        //   shapeFocus: ShapeFocus.roundedSquare,
        //   pageIndex: 3,
        //   child: const TutorialItemContent(
        //     title: 'Notificación de desconexión',
        //     content: 'Puedes establecer una alerta si el equipo se desconecta',
        //   ),
        // ),
      },
      TutorialItem(
        globalKey: KeyManager.managerScreen.imageKey,
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: const Radius.circular(20),
        shapeFocus: ShapeFocus.roundedSquare,
        pageIndex: 3,
        child: const TutorialItemContent(
          title: 'Imagen del dispositivo',
          content: 'Podrás ajustar la imagen del equipo en el menú',
        ),
      ),
    });
  }

  @override
  void initState() {
    super.initState();
    _selectedPins = List<bool>.filled(parts.length, false);
    _notis = notificationMap[
            '${DeviceManager.getProductCode(deviceName)}/${DeviceManager.extractSerialNumber(deviceName)}'] ??
        List<bool>.filled(parts.length, false);

    printLog(_notis, 'amarillo');

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
    updateWifiValues(toolsValues);
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
    printLog(fun);
    var parts = fun.split(':');
    final regex = RegExp(r'\((\d+)\)');
    final match = regex.firstMatch(parts[2]);
    int users = int.parse(match!.group(1).toString());
    printLog('Hay $users conectados');
    userConnected = users > 1;

    WifiNotifier wifiNotifier =
        Provider.of<WifiNotifier>(context, listen: false);

    if (parts[0] == 'WCS_CONNECTED') {
      atemp = false;
      nameOfWifi = parts[1];
      isWifiConnected = true;
      printLog('sis $isWifiConnected');
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
      printLog('non $isWifiConnected');

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
    printLog('Se subscribio a wifi');
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
    printLog('Valores: $parts', "Amarillo");
    tipo.clear();
    estado.clear();
    common.clear();
    alertIO.clear();

    tipo.add('Salida');
    estado.add(parts[0]);
    common.add('0');
    alertIO.add(false);

    var equipo = parts[1].split(':');
    tipo.add('Entrada');
    estado.add(equipo[0]);
    common.add(equipo[1]);
    alertIO.add(estado[1] != common[1]);

    for (int i = 0; i < 2; i++) {
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

    saveGlobalData(globalDATA);

    for (int i = 0; i < parts.length; i++) {
      if (tipo[i] == 'Salida') {
        String dv = '${deviceName}_$i';
        if (!alexaDevices.contains(dv)) {
          alexaDevices.add(dv);
          putDevicesForAlexa(service, currentUserEmail, alexaDevices);
        }
      }
    }

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

      await putSecondaryAdmins(
          service,
          DeviceManager.getProductCode(deviceName),
          DeviceManager.extractSerialNumber(deviceName),
          updatedAdmins);

      setState(() {
        adminDevices = updatedAdmins;
        emailController.clear();
      });

      showToast('Administrador añadido correctamente.');
    } catch (e) {
      printLog('Error al añadir administrador secundario: $e');
      showToast('Error al añadir el administrador. Inténtalo de nuevo.');
    }
  }

  Future<void> removeSecondaryAdmin(String email) async {
    try {
      List<String> updatedAdmins = List.from(adminDevices)..remove(email);

      await putSecondaryAdmins(
          service,
          DeviceManager.getProductCode(deviceName),
          DeviceManager.extractSerialNumber(deviceName),
          updatedAdmins);

      setState(() {
        adminDevices.remove(email);
      });

      showToast('Administrador eliminado correctamente.');
    } catch (e) {
      printLog('Error al eliminar administrador secundario: $e');
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
                    return tipo[index] == 'Salida'
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
        String data = '${DeviceManager.getProductCode(deviceName)}[5](1)';
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
      String data = '${DeviceManager.getProductCode(deviceName)}[5](0)';
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
        // Usamos un Completer para esperar a que el diálogo se cierre
        final completer = Completer<void>();

        showAlertDialog(
          navigatorKey.currentContext ?? context,
          false,
          const Text(
            'Habilita la ubicación todo el tiempo',
            style: TextStyle(color: Color(0xFFFFFFFF)),
          ),
          Text(
            '$appName utiliza tu ubicación, incluso cuando la app está cerrada o en desuso, para poder encender o apagar el calefactor en base a tu distancia con el mismo.',
            style: const TextStyle(
              color: Color(0xFFFFFFFF),
            ),
          ),
          <Widget>[
            TextButton(
              style: const ButtonStyle(
                foregroundColor: WidgetStatePropertyAll(Color(0xFFFFFFFF)),
              ),
              child: const Text('Habilitar'),
              onPressed: () async {
                try {
                  var permissionStatus4 =
                      await Permission.locationAlways.request();

                  if (!permissionStatus4.isGranted) {
                    await Permission.locationAlways.request();
                  }
                  permissionStatus4 = await Permission.locationAlways.status;

                  // Completa el Completer una vez que el permiso ha sido manejado
                  completer.complete();
                  Navigator.of(navigatorKey.currentContext ?? context).pop();
                } catch (e, s) {
                  printLog(e);
                  printLog(s);
                  completer.completeError(
                      e); // Completa con error si ocurre una excepción
                }
              },
            ),
          ],
        );

        // Espera a que el Completer se complete
        await completer.future;
      }

      // Vuelve a verificar el estado del permiso
      permissionStatus4 = await Permission.locationAlways.status;

      if (permissionStatus4.isGranted) {
        return true;
      } else {
        return false;
      }
    } catch (e, s) {
      printLog('Error al habilitar la ubicación: $e');
      printLog(s);
      return false;
    }
  }

  //! VISUAL
  @override
  Widget build(BuildContext context) {
    final TextStyle poppinsStyle = GoogleFonts.poppins();
    WifiNotifier wifiNotifier =
        Provider.of<WifiNotifier>(context, listen: false);

    bool isRegularUser = !deviceOwner && !secondaryAdmin;

    // si hay un usuario conectado al equipo no lo deje ingresar
    if (userConnected && lastUser > 1) {
      return const DeviceInUseScreen();
    }

    // Condición para mostrar la pantalla de acceso restringido
    if (isRegularUser && owner != '' && !tenant) {
      return const AccessDeniedScreen();
    }

    final List<Widget> pages = [
      //*- Página 1: Estado del Dispositivo -*\\
      SingleChildScrollView(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.8,
          child: Center(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20.0, vertical: 30.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  tipo.length + 1,
                  (index) {
                    if (index == tipo.length) {
                      return Padding(
                        padding: EdgeInsets.only(bottom: bottomBarHeight + 30),
                      );
                    }
                    bool entrada = tipo[index] == 'Entrada';
                    bool isOn = estado[index] == '1';
                    bool isPresenceControlled =
                        _selectedPins[index] && tracking;
                    return Column(
                      children: [
                        AnimatedContainer(
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
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const SizedBox(width: 6),
                                  GestureDetector(
                                    onTap: () async {
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
                                                putNicknames(
                                                    service,
                                                    currentUserEmail,
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
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.start,
                                      children: [
                                        SizedBox(
                                          width: 150,
                                          child: Text(
                                            nicknamesMap[
                                                    '${deviceName}_$index'] ??
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
                                            TextEditingController
                                                nicknameController =
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
                                                style: const TextStyle(
                                                    color: color0),
                                                cursorColor: color0,
                                                decoration: InputDecoration(
                                                  hintText:
                                                      "Nuevo nombre para ${tipo[index]} $index",
                                                  hintStyle: TextStyle(
                                                    color: color0.withValues(
                                                        alpha: 0.6),
                                                  ),
                                                  enabledBorder:
                                                      UnderlineInputBorder(
                                                    borderSide: BorderSide(
                                                      color: color0.withValues(
                                                          alpha: 0.5),
                                                    ),
                                                  ),
                                                  focusedBorder:
                                                      const UnderlineInputBorder(
                                                    borderSide: BorderSide(
                                                        color: color0),
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
                                                    style: TextStyle(
                                                        color: color0),
                                                  ),
                                                ),
                                                TextButton(
                                                  onPressed: () {
                                                    setState(() {
                                                      String newName =
                                                          nicknameController
                                                              .text;
                                                      nicknamesMap[
                                                              '${deviceName}_$index'] =
                                                          newName;
                                                      putNicknames(
                                                          service,
                                                          currentUserEmail,
                                                          nicknamesMap);
                                                    });
                                                    Navigator.of(context).pop();
                                                  },
                                                  child: const Text(
                                                    'Guardar',
                                                    style: TextStyle(
                                                        color: color0),
                                                  ),
                                                ),
                                              ],
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    'Tipo: ${tipo[index]}',
                                    style: const TextStyle(
                                      color: color0,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              entrada
                                  ? Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                                saveNotificationMap(
                                                    notificationMap);
                                              },
                                              icon: _notis[index]
                                                  ? Icon(
                                                      Icons.notifications_off,
                                                      color:
                                                          Colors.red.shade300,
                                                    )
                                                  : const Icon(
                                                      Icons
                                                          .notification_add_rounded,
                                                      color: Colors.green,
                                                    ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    )
                                  : Row(
                                      key: KeyManager.rele1i1o.estadoKey,
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Icon(
                                          isOn
                                              ? Icons.check_circle
                                              : Icons.cancel,
                                          color:
                                              isOn ? Colors.green : Colors.red,
                                          size: 40,
                                        ),
                                        GestureDetector(
                                          onTap: () {
                                            isPresenceControlled
                                                ? null
                                                : setState(() {
                                                    controlOut(!isOn, index);
                                                    estado[index] =
                                                        !isOn ? '1' : '0';
                                                  });
                                          },
                                          child: AnimatedContainer(
                                            duration: const Duration(
                                                milliseconds: 300),
                                            width: 55,
                                            height: 30,
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              color: isPresenceControlled
                                                  ? Colors.grey
                                                  : isOn
                                                      ? Colors
                                                          .greenAccent.shade400
                                                      : Colors.red.shade300,
                                            ),
                                            child: AnimatedAlign(
                                              duration: const Duration(
                                                  milliseconds: 300),
                                              alignment: isOn
                                                  ? Alignment.centerRight
                                                  : Alignment.centerLeft,
                                              curve: Curves.easeInOut,
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.all(3.0),
                                                child: Container(
                                                  width: 24,
                                                  height: 24,
                                                  decoration:
                                                      const BoxDecoration(
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
                              const SizedBox(height: 20),
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
                        ),
                        const SizedBox(height: 16.0),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),

      //*- Página 2: Trackeo Bluetooth -*\\

      // Stack(
      //   children: [
      //     SingleChildScrollView(
      //       child: Padding(
      //         padding:
      //             const EdgeInsets.symmetric(horizontal: 20.0, vertical: 30.0),
      //         child: Column(
      //           crossAxisAlignment: CrossAxisAlignment.center,
      //           children: [
      //             Text(
      //               'Control por presencia',
      //               style: GoogleFonts.poppins(
      //                 fontSize: 28,
      //                 fontWeight: FontWeight.bold,
      //                 color: color3,
      //               ),
      //               textAlign: TextAlign.center,
      //             ),
      //             const SizedBox(height: 40),
      //             GestureDetector(
      //               onTap: () {
      //                 if (deviceOwner || owner == '') {
      //                   if (isAgreeChecked) {
      //                     verifyPermission().then((accepted) async {
      //                       if (accepted) {
      //                         setState(() {
      //                           tracking = !tracking;
      //                         });
      //                         if (tracking) {
      //                           devicesToTrack.add(deviceName);
      //                           saveDeviceListToTrack(devicesToTrack);
      //                           SharedPreferences prefs =
      //                               await SharedPreferences.getInstance();
      //                           bool hasInitService =
      //                               prefs.getBool('hasInitService') ?? false;
      //                           if (!hasInitService) {
      //                             await initializeService();
      //                             await prefs.setBool('hasInitService', true);
      //                           }
      //                           await Future.delayed(
      //                               const Duration(seconds: 30));
      //                           printLog("Achi");
      //                           final backService = FlutterBackgroundService();
      //                           backService.invoke('presenceControl');
      //                         } else {
      //                           devicesToTrack.remove(deviceName);
      //                           saveDeviceListToTrack(devicesToTrack);
      //                           if (devicesToTrack.isEmpty) {
      //                             final backService =
      //                                 FlutterBackgroundService();
      //                             backService.invoke('CancelpresenceControl');
      //                           }
      //                         }
      //                       } else {
      //                         showToast(
      //                             'Debes habilitar la ubicación constante\npara el uso del\ncontrol por presencia');
      //                       }
      //                     });
      //                   } else {
      //                     showToast(
      //                         'Debes aceptar el uso de control por presencia');
      //                   }
      //                 } else {
      //                   showToast(
      //                       'No tienes permiso para realizar esta acción');
      //                 }
      //               },
      //               child: AnimatedContainer(
      //                 duration: const Duration(milliseconds: 500),
      //                 padding: const EdgeInsets.all(20),
      //                 decoration: BoxDecoration(
      //                   color: tracking ? Colors.greenAccent : Colors.redAccent,
      //                   shape: BoxShape.circle,
      //                   boxShadow: const [
      //                     BoxShadow(
      //                       color: Colors.black26,
      //                       blurRadius: 10,
      //                       offset: Offset(0, 5),
      //                     ),
      //                   ],
      //                 ),
      //                 child: Icon(
      //                   Icons.directions_walk,
      //                   size: 80,
      //                   color: tracking ? Colors.white : Colors.grey[300],
      //                 ),
      //               ),
      //             ),
      //             const SizedBox(height: 70),
      //             Card(
      //               shape: RoundedRectangleBorder(
      //                 borderRadius: BorderRadius.circular(20),
      //               ),
      //               elevation: 5,
      //               color: color3,
      //               child: Padding(
      //                 padding: const EdgeInsets.all(20.0),
      //                 child: Column(
      //                   crossAxisAlignment: CrossAxisAlignment.start,
      //                   children: [
      //                     Text(
      //                       'Habilitar esta función hará que la aplicación use más recursos de lo común, si a pesar de esto decides utilizarlo es bajo tu responsabilidad.',
      //                       style: GoogleFonts.poppins(
      //                         fontSize: 16,
      //                         color: color0,
      //                       ),
      //                     ),
      //                     const SizedBox(height: 10),
      //                     CheckboxListTile(
      //                       title: Text(
      //                         'Sí, estoy de acuerdo',
      //                         style: GoogleFonts.poppins(
      //                           fontSize: 16,
      //                           color: color0,
      //                         ),
      //                       ),
      //                       value: isAgreeChecked,
      //                       activeColor: color0,
      //                       onChanged: (bool? value) {
      //                         setState(() {
      //                           isAgreeChecked = value ?? false;
      //                           if (!isAgreeChecked && tracking) {
      //                             tracking = false;
      //                             devicesToTrack.remove(deviceName);
      //                             saveDeviceListToTrack(devicesToTrack);
      //                           }
      //                         });
      //                       },
      //                       controlAffinity: ListTileControlAffinity.leading,
      //                     ),
      //                   ],
      //                 ),
      //               ),
      //             ),
      //           ],
      //         ),
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

      //*- Página 3 - Control por distancia -*\\
      SingleChildScrollView(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.8,
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      key: KeyManager.rele1i1o.distanceKey,
                      'Control por distancia',
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: color3,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Activar control por distancia',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        color: color3,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 30),
                    GestureDetector(
                      key: KeyManager.rele1i1o.distanceBottomKey,
                      onTap: () {
                        if (deviceOwner || owner == '' || tenant) {
                          verifyPermission().then((result) {
                            if (result == true) {
                              setState(() {
                                isTaskScheduled[deviceName] =
                                    !(isTaskScheduled[deviceName] ?? false);
                              });
                              saveControlValue(isTaskScheduled);
                              controlTask(isTaskScheduled[deviceName] ?? false,
                                  deviceName);
                            } else {
                              showToast(
                                'Permitir ubicación todo el tiempo\nPara usar el control por distancia',
                              );
                              openAppSettings();
                            }
                          });
                        } else {
                          showToast('No tienes acceso a esta función');
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 500),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isTaskScheduled[deviceName] ?? false
                              ? Colors.greenAccent
                              : Colors.redAccent,
                          shape: BoxShape.circle,
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 10,
                              offset: Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Icon(
                            (isTaskScheduled[deviceName] ?? false)
                                ? Icons.check_circle_outline_rounded
                                : Icons.cancel_rounded,
                            size: 80,
                            color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 10),
                    AnimatedOpacity(
                      opacity: isTaskScheduled[deviceName] ?? false ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 500),
                      child: AnimatedSize(
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeInOut,
                        child: isTaskScheduled[deviceName] ?? false
                            ? Column(
                                children: [
                                  // Tarjeta de Distancia de apagado
                                  Card(
                                    color: color3.withValues(alpha: 0.9),
                                    elevation: 6,
                                    margin: const EdgeInsets.symmetric(
                                        vertical: 8.0, horizontal: 20.0),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(15),
                                      side: BorderSide(
                                        color: Color.lerp(
                                            Colors.blueAccent,
                                            Colors.redAccent,
                                            (distOffValue - 100) / 200)!,
                                        width: 2,
                                      ),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(10.0),
                                      child: Column(
                                        children: [
                                          const Text(
                                            'Distancia de apagado',
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: color1,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                distOffValue.round().toString(),
                                                style: const TextStyle(
                                                  fontSize: 24,
                                                  color: color1,
                                                ),
                                              ),
                                              const Text(
                                                ' Metros',
                                                style: TextStyle(
                                                  fontSize: 24,
                                                  color: color1,
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (!tenant) ...{
                                            SliderTheme(
                                              data: SliderTheme.of(context)
                                                  .copyWith(
                                                trackHeight: 20.0,
                                                thumbColor: color3,
                                                activeTrackColor:
                                                    Colors.blueAccent,
                                                inactiveTrackColor:
                                                    Colors.blueGrey[100],
                                                thumbShape:
                                                    const RoundSliderThumbShape(
                                                  enabledThumbRadius: 12.0,
                                                  elevation: 0.0,
                                                  pressedElevation: 0.0,
                                                ),
                                              ),
                                              child: Slider(
                                                activeColor: Colors.white,
                                                inactiveColor:
                                                    const Color(0xFFBDBDBD),
                                                value: distOffValue,
                                                divisions: 20,
                                                onChanged: (value) {
                                                  setState(() {
                                                    distOffValue = value;
                                                  });
                                                },
                                                onChangeEnd: (value) {
                                                  printLog(
                                                      'Valor enviado: ${value.round()}');
                                                  putDistanceOff(
                                                    service,
                                                    DeviceManager
                                                        .getProductCode(
                                                            deviceName),
                                                    DeviceManager
                                                        .extractSerialNumber(
                                                            deviceName),
                                                    value.toString(),
                                                  );
                                                },
                                                min: 100,
                                                max: 300,
                                              ),
                                            ),
                                          },
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 15),
                                  Card(
                                    color: color3.withValues(alpha: 0.9),
                                    elevation: 6,
                                    margin: const EdgeInsets.symmetric(
                                        vertical: 8.0, horizontal: 20.0),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(15),
                                      side: BorderSide(
                                        color: Color.lerp(
                                            Colors.blueAccent,
                                            Colors.redAccent,
                                            (distOnValue - 3000) / 2000)!,
                                        width: 2,
                                      ),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(10.0),
                                      child: Column(
                                        children: [
                                          const Text(
                                            'Distancia de encendido',
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: color1,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                distOnValue.round().toString(),
                                                style: const TextStyle(
                                                  fontSize: 24,
                                                  color: color1,
                                                ),
                                              ),
                                              const Text(
                                                ' Metros',
                                                style: TextStyle(
                                                  fontSize: 24,
                                                  color: color1,
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (!tenant) ...{
                                            SliderTheme(
                                              data: SliderTheme.of(context)
                                                  .copyWith(
                                                trackHeight: 20.0,
                                                thumbColor: color3,
                                                activeTrackColor:
                                                    Colors.blueAccent,
                                                inactiveTrackColor:
                                                    Colors.blueGrey[100],
                                                thumbShape:
                                                    const RoundSliderThumbShape(
                                                  enabledThumbRadius: 12.0,
                                                  elevation: 0.0,
                                                  pressedElevation: 0.0,
                                                ),
                                              ),
                                              child: Slider(
                                                activeColor: Colors.white,
                                                inactiveColor:
                                                    const Color(0xFFBDBDBD),
                                                value: distOnValue,
                                                divisions: 20,
                                                onChanged: (value) {
                                                  setState(() {
                                                    distOnValue = value;
                                                  });
                                                },
                                                onChangeEnd: (value) {
                                                  printLog(
                                                      'Valor enviado: ${value.round()}');
                                                  putDistanceOn(
                                                    service,
                                                    DeviceManager
                                                        .getProductCode(
                                                            deviceName),
                                                    DeviceManager
                                                        .extractSerialNumber(
                                                            deviceName),
                                                    value.toString(),
                                                  );
                                                },
                                                min: 3000,
                                                max: 5000,
                                              ),
                                            ),
                                          },
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : const SizedBox(),
                      ),
                    ),
                  ],
                ),
              ),
              if (!deviceOwner && owner != '' && !tenant)
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
        ),
      ),

      //*- Página 4: Cambiar pines -*\\

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
                  key: KeyManager.rele1i1o.pinModeKey,
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
                const SizedBox(height: 20),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Puedes cambiar entre Normal Abierto (NA) y Normal Cerrado (NC). Selecciona una opción:',
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
                                                    printLog(data);
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
                                                    printLog(data);
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
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          if (i == parts.length - 1) ...{
                            Padding(
                              padding:
                                  EdgeInsets.only(bottom: bottomBarHeight + 10),
                            ),
                          }
                        },
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

      //*- Página 5: Gestión del Equipo -*\\
      const ManagerScreen(),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, A) {
        if (_isTutorialActive) return;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            return AlertDialog(
              backgroundColor: const Color(0xFF252223),
              content: Row(
                children: [
                  Image.asset('assets/branch/dragon.gif',
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
                        putNicknames(service, currentUserEmail, nicknamesMap);
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
                  key: KeyManager.rele1i1o.titleKey,
                  child: Text(
                    nickname,
                    overflow: TextOverflow.ellipsis,
                    style: poppinsStyle.copyWith(color: color0),
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
              if (_isTutorialActive) return;

              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) {
                  return AlertDialog(
                    backgroundColor: const Color(0xFF252223),
                    content: Row(
                      children: [
                        Image.asset('assets/branch/dragon.gif',
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
            Icon(
              globalDATA['${DeviceManager.getProductCode(deviceName)}/${DeviceManager.extractSerialNumber(deviceName)}']![
                      'cstate']
                  ? Icons.cloud
                  : Icons.cloud_off,
              color: color0,
            ),
            IconButton(
              key: KeyManager.rele1i1o.wifiKey,
              icon: Icon(wifiNotifier.wifiIcon, color: color0),
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
                      Icon(Icons.bluetooth, size: 30, color: color0),
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
                          printLog('Tutorial is complete!', 'verde');
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
