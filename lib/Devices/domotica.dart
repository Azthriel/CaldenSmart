import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../aws/dynamo/dynamo.dart';
import '../aws/dynamo/dynamo_certificates.dart';
import '../aws/mqtt/mqtt.dart';
import '../master.dart';
import '../Global/stored_data.dart';

class DomoticaPage extends StatefulWidget {
  const DomoticaPage({super.key});
  @override
  DomoticaPageState createState() => DomoticaPageState();
}

class DomoticaPageState extends State<DomoticaPage> {
  var parts = utf8.decode(ioValues).split('/');
  bool isChangeModeVisible = false;
  bool showOptions = false;
  bool showSecondaryAdminFields = false;
  bool showAddAdminField = false;
  bool showSecondaryAdminList = false;
  bool showSmartResident = false;
  bool dOnOk = false;
  bool dOffOk = false;
  bool _showNotificationOptions = false;
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
  int _selectedNotificationOption = 0;
  int _selectedIndex = 0;

  ///*- Elementos para tutoriales -*\\\
  List<TutorialItem> items = [];

  //*- Keys para funciones de la appbar -*\\
  final titleKey = GlobalKey(); // key para el nombre del equipo
  final wifiKey = GlobalKey(); // key para el wifi del equipo
  //*- Keys para funciones de la appbar -*\\

  //*- Keys estado del dispositivo -*\\
  final estadoKey = GlobalKey(); // key para la pantalla de estado
  //*- Keys estado del dispositivo-*\\

  //*- Keys para cambio de Modo de Pines -*\\
  final pinModeKey = GlobalKey(); // key para el cambio de modo de pines
  //*- Keys para cambio de Modo de Pines -*\\

  //*- Keys para gestión -*\\
  final adminKey = GlobalKey(); // key para la pantalla de gestión
  final claimKey = GlobalKey(); // key para el boton de reclamar admin
  final fastBotonKey = GlobalKey(); // key para el boton de acceso rápido
  final imageKey = GlobalKey(); // key para la imagen del equipo
  //*- Keys para gestión -*\\

  //*- Keys para gestión siendo admin-*\\
  final agreeAdminKey =
      GlobalKey(); // key para el boton de agregar administradores
  final viewAdminKey = GlobalKey(); // key para ver la lista de administradores
  final habitKey = GlobalKey(); // key para el boton de habitantes
  final fastAccessKey = GlobalKey(); // key para el boton de acceso rápido
  //*- Keys para gestión siendo admin-*\\

  void initItems() {
    items.addAll({
      TutorialItem(
        globalKey: estadoKey,
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: const Radius.circular(0),
        shapeFocus: ShapeFocus.oval,
        radius: 0,
        pageIndex: 0,
        contentPosition: ContentPosition.below,
        child: const TutorialItemContent(
          title: 'Entradas y Salidas',
          content:
              'Podrás revisar el estado de las entradas y modificar el estado de las salidas',
        ),
      ),
      TutorialItem(
        globalKey: titleKey,
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
        globalKey: wifiKey,
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
    });
    if (hardwareVersion == '240422A') {
      isPinMode = true;
      items.addAll({
        TutorialItem(
          globalKey: pinModeKey,
          color: Colors.black.withValues(alpha: 0.6),
          shapeFocus: ShapeFocus.oval,
          borderRadius: const Radius.circular(0),
          radius: 0,
          contentPosition: ContentPosition.below,
          pageIndex: 1,
          child: const TutorialItemContent(
            title: 'Cambio de modo de pines',
            content:
                'si introduces la clave del manual podrás modificar el estado comun de los pines y alterar las entradas/salidas',
          ),
        ),
      });
    }
    items.addAll({
      TutorialItem(
        globalKey: adminKey,
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: const Radius.circular(0),
        shapeFocus: ShapeFocus.oval,
        pageIndex: 4,
        radius: isPinMode ? 2 : 1,
        contentPosition: ContentPosition.below,
        child: const TutorialItemContent(
          title: 'Gestión',
          content: 'Podrás reclamar el equipo y gestionar sus funciones',
        ),
      ),
      TutorialItem(
        globalKey: claimKey,
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: const Radius.circular(20),
        shapeFocus: ShapeFocus.roundedSquare,
        pageIndex: isPinMode ? 2 : 1,
        contentPosition: ContentPosition.below,
        child: const TutorialItemContent(
          title: 'Reclamar administrador',
          content: 'Podras reclamar la administración del equipo',
        ),
      ),
    });
    // SOLO PARA LOS ADMINS
    if (currentUserEmail == owner) {
      items.addAll({
        TutorialItem(
          globalKey: agreeAdminKey,
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: const Radius.circular(15),
          shapeFocus: ShapeFocus.roundedSquare,
          pageIndex: isPinMode ? 2 : 1,
          contentPosition: ContentPosition.below,
          child: const TutorialItemContent(
            title: 'Añadir administradores secundarios',
            content: 'Podrás agregar correos secundarios hasta un límite de 3',
          ),
        ),
        TutorialItem(
          globalKey: viewAdminKey,
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: const Radius.circular(15),
          shapeFocus: ShapeFocus.roundedSquare,
          pageIndex: isPinMode ? 2 : 1,
          contentPosition: ContentPosition.below,
          child: const TutorialItemContent(
            title: 'Ver administradores secundarios',
            content: 'Podrás ver o quitar los correos adicionales añadidos',
          ),
        ),
        TutorialItem(
          globalKey: habitKey,
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: const Radius.circular(15),
          shapeFocus: ShapeFocus.roundedSquare,
          pageIndex: isPinMode ? 2 : 1,
          child: const TutorialItemContent(
            title: 'Habitante inteligente',
            content:
                'Puedes agregar el correo de tu inquilino al equipo y ajustarlo',
          ),
        ),
      });
    }
    items.addAll({
      TutorialItem(
        globalKey: fastBotonKey,
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: const Radius.circular(20),
        shapeFocus: ShapeFocus.roundedSquare,
        pageIndex: isPinMode ? 2 : 1,
        child: const TutorialItemContent(
          title: 'Accesso rápido',
          content: 'Podrás encender y apagar el dispositivo desde el menú',
        ),
      ),
      TutorialItem(
        globalKey: fastAccessKey,
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: const Radius.circular(20),
        shapeFocus: ShapeFocus.roundedSquare,
        pageIndex: isPinMode ? 2 : 1,
        child: const TutorialItemContent(
          title: 'Notificación de desconexión',
          content: 'Puedes establecer una alerta si el equipo se desconecta',
        ),
      ),
      TutorialItem(
        globalKey: imageKey,
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: const Radius.circular(20),
        shapeFocus: ShapeFocus.roundedSquare,
        pageIndex: isPinMode ? 2 : 1,
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

        printLog(
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

        printLog('¿La entrada $j esta en alerta?: ${alertIO[j]}');
      }

      setState(() {});
    }

    saveGlobalData(globalDATA);

    for (int i = 0; i < parts.length; i++) {
      if (tipo[i] == 'Salida') {
        String dv = '${deviceName}_$i';
        if (!alexaDevices.contains(dv)) {
          alexaDevices.add(dv);
          saveAlexaDevices(alexaDevices);
          putDevicesForAlexa(service, currentUserEmail, alexaDevices);
        }
      }
    }
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
                    var equipo = parts[index].split(':');
                    printLog(equipo);
                    return equipo[0] == '0'
                        ? RadioListTile<int>(
                            title: Text(
                              subNicknamesMap['$deviceName/-/$index'] ??
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
    double bottomBarHeight = kBottomNavigationBarHeight;
    WifiNotifier wifiNotifier =
        Provider.of<WifiNotifier>(context, listen: false);

    bool isRegularUser = !deviceOwner && !secondaryAdmin;

    // si hay un usuario conectado al equipo no lo deje ingresar
    if (userConnected && lastUser > 1) {
      return const DeviceInUseScreen();
    }
    // si no eres dueño del equipo
    if (isRegularUser && owner != '' && !tenant) {
      return const AccessDeniedScreen();
    }

    final List<Widget> pages = [
      //*- página 1 entradas/salidas -*\\
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
                          GestureDetector(
                            onTap: () async {
                              TextEditingController nicknameController =
                                  TextEditingController(
                                text: subNicknamesMap['$deviceName/-/$index'] ??
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
                                        subNicknamesMap[
                                            '$deviceName/-/$index'] = newName;
                                        saveSubNicknamesMap(subNicknamesMap);
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
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 160,
                                  child: ScrollingText(
                                    text: subNicknamesMap[
                                            '$deviceName/-/$index'] ??
                                        '${tipo[index]} $index',
                                    style: GoogleFonts.poppins(
                                      color: color0,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    // overflow: TextOverflow.ellipsis,
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
                                      text: subNicknamesMap[
                                              '$deviceName/-/$index'] ??
                                          '${tipo[index]} $index',
                                    );
                                    showAlertDialog(
                                      context,
                                      false,
                                      Text(
                                        'Editar Nombre',
                                        style:
                                            GoogleFonts.poppins(color: color0),
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
                                              color:
                                                  color0.withValues(alpha: 0.5),
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
                                              subNicknamesMap[
                                                      '$deviceName/-/$index'] =
                                                  newName;
                                              saveSubNicknamesMap(
                                                  subNicknamesMap);
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
                                          ? Icon(
                                              Icons.notifications_off,
                                              color: Colors.red.shade300,
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
                                              : Colors.red.shade300,
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

      //TODO se quita temporalmente
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
      //                                   : printLog("Contextn't");
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

      if (hardwareVersion == '240422A') ...{
        //*- página 3: Cambiar pines -*\\

        SingleChildScrollView(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.8,
            child: Stack(
              children: [
                SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20.0, vertical: 30.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          key: pinModeKey,
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
                                  style: const TextStyle(
                                      color: color0, fontSize: 16),
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          subNicknamesMap[
                                                  '$deviceName/-/${parts[i]}'] ??
                                              '${tipo[i]} $i',
                                          style: GoogleFonts.poppins(
                                            color: color0,
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        if (tipo[i] == 'Salida') ...{
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Alternar entre Normal Abierto y Normal Cerrado',
                                                style: GoogleFonts.poppins(
                                                  color: color0,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              const SizedBox(height: 12),
                                              Container(
                                                height: 40,
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          30.0),
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
                                                          // NORMAL Abierto

                                                          String message =
                                                              jsonEncode({
                                                            'pinType': '0',
                                                            'index': i,
                                                            'w_status':
                                                                estado[i] ==
                                                                    '1',
                                                            'r_state': 0,
                                                          });

                                                          // Envías por MQTT
                                                          String topicRx =
                                                              'devices_rx/${DeviceManager.getProductCode(deviceName)}/${DeviceManager.extractSerialNumber(deviceName)}';
                                                          String topicTx =
                                                              'devices_tx/${DeviceManager.getProductCode(deviceName)}/${DeviceManager.extractSerialNumber(deviceName)}';
                                                          sendMessagemqtt(
                                                              topicRx, message);
                                                          sendMessagemqtt(
                                                              topicTx, message);

                                                          // Guardas en globalDATA
                                                          globalDATA
                                                              .putIfAbsent(
                                                            '${DeviceManager.getProductCode(deviceName)}/${DeviceManager.extractSerialNumber(deviceName)}',
                                                            () => {},
                                                          )
                                                              .addAll({
                                                            'io$i': message
                                                          });
                                                          saveGlobalData(
                                                              globalDATA);

                                                          setState(() {
                                                            common[i] = '0';
                                                          });
                                                        },
                                                        child: Container(
                                                          decoration:
                                                              BoxDecoration(
                                                            color: common[i] ==
                                                                    '0'
                                                                ? color0
                                                                : Colors
                                                                    .transparent,
                                                            borderRadius:
                                                                const BorderRadius
                                                                    .only(
                                                              topLeft: Radius
                                                                  .circular(28),
                                                              bottomLeft: Radius
                                                                  .circular(28),
                                                            ),
                                                          ),
                                                          child: Center(
                                                            child: Text(
                                                              'Normal Abierto',
                                                              style: GoogleFonts
                                                                  .poppins(
                                                                fontSize: 14,
                                                                color:
                                                                    common[i] ==
                                                                            '0'
                                                                        ? color3
                                                                        : color0,
                                                              ),
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
                                                          // NORMAL Cerrado

                                                          // pones los valores
                                                          String message =
                                                              jsonEncode({
                                                            'pinType': '0',
                                                            'index': i,
                                                            'w_status':
                                                                estado[i] ==
                                                                    '1',
                                                            'r_state': '1',
                                                          });

                                                          // Envías por MQTT
                                                          String topicRx =
                                                              'devices_rx/${DeviceManager.getProductCode(deviceName)}/${DeviceManager.extractSerialNumber(deviceName)}';
                                                          String topicTx =
                                                              'devices_tx/${DeviceManager.getProductCode(deviceName)}/${DeviceManager.extractSerialNumber(deviceName)}';
                                                          sendMessagemqtt(
                                                              topicRx, message);
                                                          sendMessagemqtt(
                                                              topicTx, message);

                                                          // Guardas globalDATA
                                                          globalDATA
                                                              .putIfAbsent(
                                                            '${DeviceManager.getProductCode(deviceName)}/${DeviceManager.extractSerialNumber(deviceName)}',
                                                            () => {},
                                                          )
                                                              .addAll({
                                                            'io$i': message
                                                          });
                                                          saveGlobalData(
                                                              globalDATA);

                                                          setState(() {
                                                            common[i] = '1';
                                                          });
                                                        },
                                                        child: Container(
                                                          decoration:
                                                              BoxDecoration(
                                                            color: common[i] ==
                                                                    '1'
                                                                ? color0
                                                                : Colors
                                                                    .transparent,
                                                            borderRadius:
                                                                const BorderRadius
                                                                    .only(
                                                              topRight: Radius
                                                                  .circular(28),
                                                              bottomRight:
                                                                  Radius
                                                                      .circular(
                                                                          28),
                                                            ),
                                                          ),
                                                          child: Center(
                                                            child: Text(
                                                              'Normal Cerrado',
                                                              style: GoogleFonts
                                                                  .poppins(
                                                                fontSize: 14,
                                                                color:
                                                                    common[i] ==
                                                                            '1'
                                                                        ? color3
                                                                        : color0,
                                                              ),
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
                                          const SizedBox(height: 20),
                                        },
                                        const SizedBox(height: 8),
                                        Text(
                                          tipo[i] == 'Entrada'
                                              ? '¿Cambiar de entrada a salida?'
                                              : '¿Cambiar de salida a entrada?',
                                          style: GoogleFonts.poppins(
                                            color: color0,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        if (tipo[i] == 'Entrada')
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                'Estado común:',
                                                style: GoogleFonts.poppins(
                                                  color: color0,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              Text(
                                                common[i],
                                                style: GoogleFonts.poppins(
                                                  color: color0,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              IconButton(
                                                onPressed: () {
                                                  String data =
                                                      '${DeviceManager.getProductCode(deviceName)}[14]($i#${common[i] == '1' ? '0' : '1'})';
                                                  printLog(data);
                                                  myDevice.toolsUuid
                                                      .write(data.codeUnits);
                                                },
                                                icon: const Icon(
                                                  Icons.change_circle_outlined,
                                                  color: color0,
                                                ),
                                              ),
                                            ],
                                          ),
                                        const SizedBox(height: 12),
                                        Center(
                                          child: ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              foregroundColor: color3,
                                              backgroundColor: color0,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 24.0,
                                                      vertical: 12.0),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                            ),
                                            onPressed: () {
                                              String fun =
                                                  '${DeviceManager.getProductCode(deviceName)}[13]($i#${tipo[i] == 'Entrada' ? '0' : '1'})';
                                              printLog(fun);
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
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                if (i == parts.length - 1) ...{
                                  Padding(
                                    padding: EdgeInsets.only(
                                        bottom: bottomBarHeight + 10),
                                  ),
                                }
                              ],
                            ],
                          ),
                      ],
                    ),
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
          ),
        ),
      },

      //*- Página 4: Gestión del Equipo -*\\
      SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 30.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                key: adminKey,
                'Gestión del equipo',
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: color3,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              //! Opción - Reclamar propiedad del equipo o dejar de ser propietario
              InkWell(
                key: claimKey,
                onTap: () async {
                  if (currentUserEmail == owner) {
                    // Opción para dejar de ser propietario
                    showAlertDialog(
                      context,
                      false,
                      const Text(
                        '¿Dejar de ser administrador del equipo?',
                      ),
                      const Text(
                        'Esto hará que otras personas puedan conectarse al dispositivo y modificar sus parámetros',
                      ),
                      <Widget>[
                        TextButton(
                          child: const Text('Cancelar'),
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                        ),
                        TextButton(
                          child: const Text('Aceptar'),
                          onPressed: () {
                            try {
                              putOwner(
                                service,
                                DeviceManager.getProductCode(deviceName),
                                DeviceManager.extractSerialNumber(deviceName),
                                '',
                              );

                              Navigator.of(context).pop();
                              setState(() {
                                owner = '';
                                deviceOwner = false;
                                showOptions = false;
                              });
                            } catch (e, s) {
                              printLog('Error al borrar owner $e Trace: $s');
                              showToast('Error al borrar el administrador.');
                            }
                          },
                        ),
                      ],
                    );
                  } else if (owner == '') {
                    // No hay propietario, el usuario puede reclamar
                    try {
                      putOwner(
                        service,
                        DeviceManager.getProductCode(deviceName),
                        DeviceManager.extractSerialNumber(deviceName),
                        currentUserEmail,
                      );
                      setState(() {
                        owner = currentUserEmail;
                        deviceOwner = true;
                        showOptions = true;
                      });
                      showToast('Ahora eres el propietario del equipo');
                    } catch (e, s) {
                      printLog('Error al agregar owner $e Trace: $s');
                      showToast('Error al agregar el administrador.');
                    }
                  } else {
                    // Ya hay un propietario
                    showToast('El equipo ya esta reclamado');
                  }
                },
                borderRadius: BorderRadius.circular(15),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 600),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: color6,
                    shape: BoxShape.rectangle,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 10,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Text(
                    currentUserEmail == owner
                        ? 'Dejar de ser dueño del equipo'
                        : 'Reclamar propiedad del equipo',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              //! Opciones adicionales con animación
              AnimatedSize(
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeInOut,
                child: AnimatedOpacity(
                  opacity: showOptions ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 600),
                  child: showOptions
                      ? Column(
                          children: [
                            //! Opciones adicionales existentes (deviceOwner)
                            if (deviceOwner) ...[
                              //! Opción 2 - Añadir administradores secundarios
                              InkWell(
                                key: agreeAdminKey,
                                onTap: () {
                                  setState(() {
                                    showSecondaryAdminFields =
                                        !showSecondaryAdminFields;
                                  });
                                },
                                borderRadius: BorderRadius.circular(15),
                                child: Container(
                                  padding: const EdgeInsets.all(15),
                                  decoration: BoxDecoration(
                                    color: color3,
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Añadir administradores\nsecundarios',
                                        style: GoogleFonts.poppins(
                                          fontSize: 15,
                                          color: color0,
                                        ),
                                      ),
                                      Icon(
                                        showSecondaryAdminFields
                                            ? Icons.arrow_drop_up
                                            : Icons.arrow_drop_down,
                                        color: color0,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              AnimatedSize(
                                duration: const Duration(milliseconds: 600),
                                curve: Curves.easeInOut,
                                child: showSecondaryAdminFields
                                    ? Column(
                                        children: [
                                          AnimatedOpacity(
                                            opacity: showSecondaryAdminFields
                                                ? 1.0
                                                : 0.0,
                                            duration: const Duration(
                                                milliseconds: 600),
                                            child: TextField(
                                              controller: emailController,
                                              cursorColor: color3,
                                              style: GoogleFonts.poppins(
                                                color: color3,
                                              ),
                                              decoration: InputDecoration(
                                                labelText: 'Correo electrónico',
                                                labelStyle: GoogleFonts.poppins(
                                                  fontSize: 16,
                                                  color: color3,
                                                ),
                                                filled: true,
                                                fillColor: Colors.transparent,
                                                focusedBorder:
                                                    OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(15),
                                                  borderSide: const BorderSide(
                                                    color: color3,
                                                    width: 2,
                                                  ),
                                                ),
                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(15),
                                                  borderSide: const BorderSide(
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          InkWell(
                                            onTap: () {
                                              if (emailController
                                                  .text.isNotEmpty) {
                                                addSecondaryAdmin(
                                                    emailController.text
                                                        .trim());
                                              }
                                            },
                                            borderRadius:
                                                BorderRadius.circular(15),
                                            child: Container(
                                              padding: const EdgeInsets.all(15),
                                              decoration: BoxDecoration(
                                                color: color3,
                                                borderRadius:
                                                    BorderRadius.circular(15),
                                              ),
                                              child: Center(
                                                child: Text(
                                                  'Añadir administrador',
                                                  style: GoogleFonts.poppins(
                                                    color: color0,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      )
                                    : const SizedBox(),
                              ),
                              const SizedBox(height: 10),
                              //! Opción 3 - Ver administradores secundarios
                              InkWell(
                                key: viewAdminKey,
                                onTap: () {
                                  setState(() {
                                    showSecondaryAdminList =
                                        !showSecondaryAdminList;
                                  });
                                },
                                borderRadius: BorderRadius.circular(15),
                                child: Container(
                                  padding: const EdgeInsets.all(15),
                                  decoration: BoxDecoration(
                                    color: color3,
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Ver administradores\nsecundarios',
                                        style: GoogleFonts.poppins(
                                          fontSize: 15,
                                          color: color0,
                                        ),
                                      ),
                                      Icon(
                                        showSecondaryAdminList
                                            ? Icons.arrow_drop_up
                                            : Icons.arrow_drop_down,
                                        color: color0,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              AnimatedSize(
                                duration: const Duration(milliseconds: 600),
                                curve: Curves.easeInOut,
                                child: showSecondaryAdminList
                                    ? adminDevices.isEmpty
                                        ? Text(
                                            'No hay administradores secundarios.',
                                            style: GoogleFonts.poppins(
                                              fontSize: 16,
                                              color: color3,
                                            ),
                                          )
                                        : Column(
                                            children: adminDevices.map((email) {
                                              return AnimatedContainer(
                                                duration: const Duration(
                                                    milliseconds: 300),
                                                curve: Curves.easeInOut,
                                                margin:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 5),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 10,
                                                        horizontal: 15),
                                                decoration: BoxDecoration(
                                                  color: color3,
                                                  borderRadius:
                                                      BorderRadius.circular(15),
                                                  border: Border.all(
                                                    color: color0,
                                                    width: 2,
                                                  ),
                                                  boxShadow: const [
                                                    BoxShadow(
                                                      color: Colors.black12,
                                                      blurRadius: 4,
                                                      offset: Offset(2, 2),
                                                    ),
                                                  ],
                                                ),
                                                child: Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        email,
                                                        style:
                                                            GoogleFonts.poppins(
                                                          fontSize: 16,
                                                          color: color0,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                      ),
                                                    ),
                                                    IconButton(
                                                      icon: const Icon(
                                                          Icons.delete,
                                                          color: color5),
                                                      onPressed: () {
                                                        removeSecondaryAdmin(
                                                            email);
                                                      },
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }).toList(),
                                          )
                                    : const SizedBox(),
                              ),
                              const SizedBox(height: 10),
                              //! Opción 4 - Habitante inteligente
                              InkWell(
                                key: habitKey,
                                onTap: () {
                                  if (activatedAT) {
                                    setState(() {
                                      showSmartResident = !showSmartResident;
                                    });
                                  } else {
                                    if (!payAT) {
                                      showAlertDialog(
                                        context,
                                        true,
                                        Text(
                                          'Actualmente no tienes habilitado este beneficio',
                                          style: GoogleFonts.poppins(
                                              color: color0),
                                        ),
                                        Text(
                                          'En caso de requerirlo puedes solicitarlo vía mail',
                                          style: GoogleFonts.poppins(
                                              color: color0),
                                        ),
                                        [
                                          TextButton(
                                            style: TextButton.styleFrom(
                                              foregroundColor:
                                                  const Color(0xFFFFFFFF),
                                            ),
                                            onPressed: () async {
                                              String cuerpo =
                                                  '¡Hola! Me comunico porque busco habilitar la opción de "Habitante inteligente" en mi equipo $deviceName\nCódigo de Producto: ${DeviceManager.getProductCode(deviceName)}\nNúmero de Serie: ${DeviceManager.extractSerialNumber(deviceName)}\nDueño actual del equipo: $owner';
                                              final Uri emailLaunchUri = Uri(
                                                scheme: 'mailto',
                                                path:
                                                    'cobranzas@ibsanitarios.com.ar',
                                                query:
                                                    encodeQueryParameters(<String,
                                                        String>{
                                                  'subject':
                                                      'Habilitación habitante inteligente',
                                                  'body': cuerpo,
                                                  'CC':
                                                      'pablo@intelligentgas.com.ar'
                                                }),
                                              );
                                              if (await canLaunchUrl(
                                                  emailLaunchUri)) {
                                                await launchUrl(emailLaunchUri);
                                              } else {
                                                showToast(
                                                    'No se pudo enviar el correo electrónico');
                                              }
                                              navigatorKey.currentState?.pop();
                                            },
                                            child: const Text('Solicitar'),
                                          ),
                                        ],
                                      );
                                    } else {
                                      setState(() {
                                        showSmartResident = !showSmartResident;
                                      });
                                    }
                                  }
                                },
                                borderRadius: BorderRadius.circular(15),
                                child: Container(
                                  padding: const EdgeInsets.all(15),
                                  decoration: BoxDecoration(
                                    color: color3,
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Habitante inteligente',
                                        style: GoogleFonts.poppins(
                                            fontSize: 15, color: color0),
                                      ),
                                      Icon(
                                        showSmartResident
                                            ? Icons.arrow_drop_up
                                            : Icons.arrow_drop_down,
                                        color: color0,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              AnimatedSize(
                                duration: const Duration(milliseconds: 600),
                                curve: Curves.easeInOut,
                                child: showSmartResident && payAT
                                    ? Column(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(20),
                                            margin:
                                                const EdgeInsets.only(top: 20),
                                            decoration: BoxDecoration(
                                              color: color3,
                                              borderRadius:
                                                  BorderRadius.circular(15),
                                              boxShadow: const [
                                                BoxShadow(
                                                  color: Colors.black26,
                                                  blurRadius: 5,
                                                  offset: Offset(0, 3),
                                                ),
                                              ],
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Configura los parámetros del alquiler',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                    color: color0,
                                                  ),
                                                ),
                                                const SizedBox(height: 20),
                                                TextField(
                                                  controller: tenantController,
                                                  keyboardType: TextInputType
                                                      .emailAddress,
                                                  style: GoogleFonts.poppins(
                                                      color: color0),
                                                  decoration: InputDecoration(
                                                    labelText:
                                                        "Email del inquilino",
                                                    labelStyle:
                                                        GoogleFonts.poppins(
                                                            color: color0),
                                                    enabledBorder:
                                                        OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              15),
                                                      borderSide:
                                                          const BorderSide(
                                                              color: color0),
                                                    ),
                                                    focusedBorder:
                                                        OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              15),
                                                      borderSide:
                                                          const BorderSide(
                                                              color: color0),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(height: 20),
                                                // Mostrar el email actual solo si existe
                                                if (activatedAT)
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.all(
                                                            15),
                                                    decoration: BoxDecoration(
                                                      color: color3,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              15),
                                                      border: Border.all(
                                                          color: color0,
                                                          width: 2),
                                                      boxShadow: const [
                                                        BoxShadow(
                                                          color: Colors.black12,
                                                          blurRadius: 4,
                                                          offset: Offset(2, 2),
                                                        ),
                                                      ],
                                                    ),
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          'Inquilino actual:',
                                                          style: GoogleFonts
                                                              .poppins(
                                                            fontSize: 16,
                                                            color: color0,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            height: 5),
                                                        Row(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .spaceBetween,
                                                          children: [
                                                            Expanded(
                                                              child: Text(
                                                                globalDATA[
                                                                        '${DeviceManager.getProductCode(deviceName)}/${DeviceManager.extractSerialNumber(deviceName)}']
                                                                    ?['tenant'],
                                                                style:
                                                                    GoogleFonts
                                                                        .poppins(
                                                                  fontSize: 14,
                                                                  color: color0,
                                                                ),
                                                              ),
                                                            ),
                                                            IconButton(
                                                              icon: const Icon(
                                                                  Icons.delete,
                                                                  color: Colors
                                                                      .redAccent),
                                                              onPressed:
                                                                  () async {
                                                                await saveATData(
                                                                  service,
                                                                  DeviceManager
                                                                      .getProductCode(
                                                                          deviceName),
                                                                  DeviceManager
                                                                      .extractSerialNumber(
                                                                          deviceName),
                                                                  false,
                                                                  '',
                                                                  '3000',
                                                                  '100',
                                                                );
                                                                setState(() {
                                                                  tenantController
                                                                      .clear();
                                                                  globalDATA[
                                                                          '${DeviceManager.getProductCode(deviceName)}/${DeviceManager.extractSerialNumber(deviceName)}']
                                                                      ?[
                                                                      'tenant'] = '';
                                                                  activatedAT =
                                                                      false;
                                                                  dOnOk = false;
                                                                  dOffOk =
                                                                      false;
                                                                });
                                                                showToast(
                                                                    "Inquilino eliminado correctamente.");
                                                              },
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                  ),

                                                const SizedBox(height: 10),

                                                // Distancia de apagado y encendido sliders
                                                Text(
                                                  'Distancia de apagado (${distOffValue.round()} metros)',
                                                  style: GoogleFonts.poppins(
                                                      color: color0),
                                                ),
                                                Slider(
                                                  value: distOffValue,
                                                  min: 100,
                                                  max: 300,
                                                  divisions: 200,
                                                  activeColor: color0,
                                                  inactiveColor: color0
                                                      .withValues(alpha: 0.3),
                                                  onChanged: (double value) {
                                                    setState(() {
                                                      distOffValue = value;
                                                      dOffOk = true;
                                                    });
                                                  },
                                                ),
                                                const SizedBox(height: 10),
                                                Text(
                                                  'Distancia de encendido (${distOnValue.round()} metros)',
                                                  style: GoogleFonts.poppins(
                                                      color: color0),
                                                ),
                                                Slider(
                                                  value: distOnValue,
                                                  min: 3000,
                                                  max: 5000,
                                                  divisions: 200,
                                                  activeColor: color0,
                                                  inactiveColor: color0
                                                      .withValues(alpha: 0.3),
                                                  onChanged: (double value) {
                                                    setState(() {
                                                      distOnValue = value;
                                                      dOnOk = true;
                                                    });
                                                  },
                                                ),
                                                const SizedBox(height: 20),

                                                // Botones de Activar y Cancelar
                                                Center(
                                                  child: Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      TextButton(
                                                        onPressed: () {
                                                          if (dOnOk &&
                                                              dOffOk &&
                                                              tenantController
                                                                  .text
                                                                  .isNotEmpty) {
                                                            saveATData(
                                                              service,
                                                              DeviceManager
                                                                  .getProductCode(
                                                                      deviceName),
                                                              DeviceManager
                                                                  .extractSerialNumber(
                                                                      deviceName),
                                                              true,
                                                              tenantController
                                                                  .text
                                                                  .trim(),
                                                              distOnValue
                                                                  .round()
                                                                  .toString(),
                                                              distOffValue
                                                                  .round()
                                                                  .toString(),
                                                            );

                                                            setState(() {
                                                              activatedAT =
                                                                  true;
                                                              globalDATA['${DeviceManager.getProductCode(deviceName)}/${DeviceManager.extractSerialNumber(deviceName)}']
                                                                      ?[
                                                                      'tenant'] =
                                                                  tenantController
                                                                      .text
                                                                      .trim();
                                                            });
                                                            showToast(
                                                                'Configuración guardada para el inquilino.');
                                                          } else {
                                                            showToast(
                                                                'Por favor, completa todos los campos');
                                                          }
                                                        },
                                                        style: TextButton
                                                            .styleFrom(
                                                          backgroundColor:
                                                              color0,
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  horizontal:
                                                                      30,
                                                                  vertical: 15),
                                                          shape:
                                                              RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        15),
                                                          ),
                                                        ),
                                                        child: Text(
                                                          'Activar',
                                                          style: GoogleFonts
                                                              .poppins(
                                                                  color: color3,
                                                                  fontSize: 16),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 20),
                                                      TextButton(
                                                        onPressed: () {
                                                          setState(() {
                                                            showSmartResident =
                                                                false;
                                                          });
                                                        },
                                                        style: TextButton
                                                            .styleFrom(
                                                          backgroundColor:
                                                              color0,
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  horizontal:
                                                                      30,
                                                                  vertical: 15),
                                                          shape:
                                                              RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        15),
                                                          ),
                                                        ),
                                                        child: Text(
                                                          'Cancelar',
                                                          style: GoogleFonts
                                                              .poppins(
                                                                  color: color3,
                                                                  fontSize: 16),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      )
                                    : const SizedBox(),
                              ),
                              const SizedBox(height: 10),
                            ],
                          ],
                        )
                      : const SizedBox(),
                ),
              ),
              const SizedBox(
                height: 30,
              ),

              SizedBox(
                key: fastBotonKey,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    // Mostrar el diálogo para seleccionar un pin al activar acceso rápido
                    if (!quickAccesActivated) {
                      int? selectedPin = await showPinSelectionDialog(context);

                      if (selectedPin != null) {
                        pinQuickAccess
                            .addAll({deviceName: selectedPin.toString()});
                        quickAccess.add(deviceName);
                        await savequickAccess(quickAccess);
                        await savepinQuickAccess(pinQuickAccess);
                        setState(() {
                          quickAccesActivated = true;
                        });
                      }
                    } else {
                      quickAccess.remove(deviceName);
                      pinQuickAccess.remove(deviceName);
                      await savequickAccess(quickAccess);
                      await savepinQuickAccess(pinQuickAccess);
                      setState(() {
                        quickAccesActivated = false;
                      });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    foregroundColor: color0,
                    backgroundColor: color3,
                    padding: const EdgeInsets.symmetric(
                        vertical: 11, horizontal: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Text(
                    quickAccesActivated
                        ? 'Desactivar acceso rápido'
                        : 'Activar acceso rápido',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              //! activar notificación
              if (owner == '' || deviceOwner || secondaryAdmin) ...{
                ElevatedButton(
                  key: fastAccessKey,
                  onPressed: () async {
                    if (discNotfActivated) {
                      showAlertDialog(
                        context,
                        true,
                        Text(
                          'Confirmar Desactivación',
                          style: GoogleFonts.poppins(color: color0),
                        ),
                        Text(
                          '¿Estás seguro de que deseas desactivar la notificación de desconexión?',
                          style: GoogleFonts.poppins(color: color0),
                        ),
                        [
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            child: Text(
                              'Cancelar',
                              style: GoogleFonts.poppins(color: color0),
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              // Actualizar el estado para desactivar la notificación
                              setState(() {
                                discNotfActivated = false;
                                _showNotificationOptions = false;
                              });

                              // Eliminar la configuración de notificación para el dispositivo actual
                              configNotiDsc.removeWhere(
                                  (key, value) => key == deviceName);
                              await saveconfigNotiDsc(configNotiDsc);

                              if (context.mounted) {
                                Navigator.of(context).pop();
                              }
                            },
                            child: Text(
                              'Aceptar',
                              style: GoogleFonts.poppins(color: color0),
                            ),
                          ),
                        ],
                      );
                    } else {
                      setState(() {
                        _showNotificationOptions = !_showNotificationOptions;
                      });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    foregroundColor: color0,
                    backgroundColor: color3,
                    padding: const EdgeInsets.symmetric(
                        vertical: 11, horizontal: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        discNotfActivated
                            ? 'Desactivar notificación de desconexión'
                            : 'Activar notificación de desconexión',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          color: color0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              },
              // Tarjeta de opciones de notificación
              AnimatedSize(
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeInOut,
                child: _showNotificationOptions
                    ? Container(
                        padding: const EdgeInsets.all(20),
                        margin: const EdgeInsets.only(top: 20),
                        decoration: BoxDecoration(
                          color: color3,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Selecciona cuándo deseas recibir una notificación en caso de que el equipo se desconecte:',
                              style: GoogleFonts.poppins(
                                  color: color0, fontSize: 16),
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
                              activeColor: color1,
                              title: Text(
                                'Instantáneo',
                                style: GoogleFonts.poppins(color: color0),
                              ),
                            ),
                            RadioListTile<int>(
                              value: 10,
                              groupValue: _selectedNotificationOption,
                              onChanged: (int? value) {
                                setState(() {
                                  _selectedNotificationOption = value!;
                                });
                              },
                              activeColor: color1,
                              title: Text(
                                'Si permanece 10 minutos desconectado',
                                style: GoogleFonts.poppins(color: color0),
                              ),
                            ),
                            RadioListTile<int>(
                              value: 60,
                              groupValue: _selectedNotificationOption,
                              onChanged: (int? value) {
                                setState(() {
                                  _selectedNotificationOption = value!;
                                });
                              },
                              activeColor: color1,
                              title: Text(
                                'Si permanece 1 hora desconectado',
                                style: GoogleFonts.poppins(color: color0),
                              ),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton(
                              onPressed: () async {
                                setState(() {
                                  discNotfActivated = true;
                                  _showNotificationOptions = false;
                                });

                                configNotiDsc[deviceName] =
                                    _selectedNotificationOption;
                                await saveconfigNotiDsc(configNotiDsc);

                                showNotification(
                                  'Notificación Activada',
                                  'Has activado la notificación de desconexión con la opción seleccionada.',
                                  'noti',
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: color0,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 15, horizontal: 15),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                              child: Text(
                                'Aceptar',
                                style: GoogleFonts.poppins(
                                    color: color3, fontSize: 16),
                              ),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),

              const SizedBox(height: 10),

              SizedBox(
                key: imageKey,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    ImageManager.openImageOptions(context, deviceName, () {
                      setState(() {
                        // La UI se reconstruirá automáticamente para mostrar la nueva imagen
                      });
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    foregroundColor: color0,
                    backgroundColor: color3,
                    padding: const EdgeInsets.symmetric(
                        vertical: 11, horizontal: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text(
                    'Cambiar imagen del dispositivo',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              Container(
                width: MediaQuery.of(context).size.width * 1.5,
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                decoration: BoxDecoration(
                  color: color3,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Versión de Hardware: $hardwareVersion',
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
                width: MediaQuery.of(context).size.width * 1.5,
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                decoration: BoxDecoration(
                  color: color3,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Versión de Software: $softwareVersion',
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
              Padding(
                padding: EdgeInsets.only(bottom: bottomBarHeight + 30),
              ),
            ],
          ),
        ),
      ),
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
                        saveNicknamesMap(nicknamesMap);
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
                  key: titleKey,
                  child: ScrollingText(
                    text: nickname,
                    style: poppinsStyle.copyWith(color: color0),
                  ),
                ),
                const SizedBox(width: 3),
                const Icon(Icons.edit, size: 20, color: color0)
              ],
            ),
          ),
          leading: IconButton(
            key: estadoKey,
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
            IconButton(
              key: wifiKey,
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
                    items: <Widget>[
                      const Icon(Icons.home, size: 30, color: color0),
                      //const Icon(Icons.bluetooth, size: 30, color: color0),
                      if (hardwareVersion == '240422A') ...{
                        const Icon(Icons.input, size: 30, color: color0),
                      },
                      const Icon(Icons.settings, size: 30, color: color0),
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
