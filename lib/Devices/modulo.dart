import 'dart:convert';

import 'package:caldensmart/Global/stored_data.dart';
import 'package:caldensmart/aws/dynamo/dynamo.dart';
import 'package:caldensmart/aws/dynamo/dynamo_certificates.dart';
import 'package:caldensmart/aws/mqtt/mqtt.dart';
import 'package:caldensmart/master.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../Global/manager_screen.dart';

class ModuloPage extends StatefulWidget {
  const ModuloPage({super.key});

  @override
  ModuloPageState createState() => ModuloPageState();
}

class ModuloPageState extends State<ModuloPage> {
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
  bool isPinMode = false;
  late List<bool> _selectedPins;

  TextEditingController emailController = TextEditingController();
  TextEditingController passController = TextEditingController();
  final TextEditingController modulePassController = TextEditingController();
  final TextEditingController tenantController = TextEditingController();
  final PageController _pageController = PageController(initialPage: 0);

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
    if (!tenant) {
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
                'si introduces la clave del manual podrás modificar el estado comun de las salidas',
          ),
        ),
      });
    } else {
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
            title: 'Inquilino',
            content:
                'Ciertas funciones estan bloqueadas y solo el dueño puede acceder',
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
        radius: 0,
        pageIndex: 2,
        contentPosition: ContentPosition.below,
        child: const TutorialItemContent(
          title: 'Gestión',
          content: 'Podrás reclamar el equipo y gestionar sus funciones',
        ),
      ),
    });
    if (!tenant) {
      items.addAll({
        TutorialItem(
          globalKey: claimKey,
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: const Radius.circular(20),
          shapeFocus: ShapeFocus.roundedSquare,
          pageIndex: 2,
          contentPosition: ContentPosition.below,
          child: const TutorialItemContent(
            title: 'Reclamar administrador',
            content: 'podras reclamar la administración del equipo',
          ),
        ),
      });
    }

    // SOLO PARA LOS ADMINS
    if (owner == currentUserEmail) {
      items.addAll({
        TutorialItem(
          globalKey: agreeAdminKey,
          color: Colors.black.withValues(alpha: 0.6),
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
          globalKey: viewAdminKey,
          color: Colors.black.withValues(alpha: 0.6),
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
          globalKey: habitKey,
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: const Radius.circular(15),
          shapeFocus: ShapeFocus.roundedSquare,
          pageIndex: 2,
          child: const TutorialItemContent(
            title: 'Alquiler temporario',
            content:
                'Puedes agregar el correo de tu inquilino al equipo y ajustarlo',
          ),
        ),
      });
    }
    if (!tenant) {
      items.addAll({
        TutorialItem(
          globalKey: fastBotonKey,
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: const Radius.circular(40),
          shapeFocus: ShapeFocus.roundedSquare,
          pageIndex: 2,
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
          pageIndex: 2,
          child: const TutorialItemContent(
            title: 'Notificación de desconexión',
            content: 'Puedes establecer una alerta si el equipo se desconecta',
          ),
        ),
      });
    }

    items.addAll({
      TutorialItem(
        globalKey: imageKey,
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: const Radius.circular(40),
        shapeFocus: ShapeFocus.roundedSquare,
        pageIndex: 2,
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
    notificationMap.putIfAbsent(
        '${DeviceManager.getProductCode(deviceName)}/${DeviceManager.extractSerialNumber(deviceName)}',
        () => List<bool>.filled(4, false));

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

    for (int i = 0; i < 2; i++) {
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
          'pinType': '0',
          'index': i,
          'w_status': estado[i] == '1',
          'r_state': common[i],
        })
      });
    }

    for (int j = 2; j < 4; j++) {
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
          'pinType': '1',
          'index': j,
          'w_status': estado[j] == '1',
          'r_state': common[j],
        })
      });

      printLog('¿La entrada $j esta en alerta?: ${alertIO[j]}');
    }

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
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (int index = 0; index < 2; index++) ...{
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: () async {
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
                                            color:
                                                color0.withValues(alpha: 0.5),
                                          ),
                                        ),
                                        focusedBorder:
                                            const UnderlineInputBorder(
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
                                        TextEditingController
                                            nicknameController =
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
                                            style: GoogleFonts.poppins(
                                                color: color0),
                                          ),
                                          TextField(
                                            controller: nicknameController,
                                            style:
                                                const TextStyle(color: color0),
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Icon(
                                (estado[index] == '1')
                                    ? Icons.check_circle
                                    : Icons.cancel,
                                color: (estado[index] == '1')
                                    ? Colors.green
                                    : Colors.red,
                                size: 40,
                              ),
                              GestureDetector(
                                onTap: () {
                                  (_selectedPins[index] && tracking)
                                      ? null
                                      : setState(() {
                                          controlOut(
                                              !(estado[index] == '1'), index);
                                          estado[index] =
                                              !(estado[index] == '1')
                                                  ? '1'
                                                  : '0';
                                        });
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  width: 55,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    color: (_selectedPins[index] && tracking)
                                        ? Colors.grey
                                        : (estado[index] == '1')
                                            ? Colors.greenAccent.shade400
                                            : Colors.red.shade300,
                                  ),
                                  child: AnimatedAlign(
                                    duration: const Duration(milliseconds: 300),
                                    alignment: (estado[index] == '1')
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
                          const SizedBox(height: 20),
                          if (_selectedPins[index] && tracking) ...{
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
                    const SizedBox(height: 20),
                  },
                  for (int index = 2; index < 5; index++) ...{
                    if (index == 4) ...{
                      Padding(
                        padding: EdgeInsets.only(bottom: bottomBarHeight + 30),
                      ),
                    } else ...{
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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const SizedBox(width: 6),
                                GestureDetector(
                                  onTap: () async {
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
                                  child: SizedBox(
                                    height: 30,
                                    width: 180,
                                    child: ScrollingText(
                                      text: subNicknamesMap[
                                              '$deviceName/-/$index'] ??
                                          '${tipo[index]} $index',
                                      style: GoogleFonts.poppins(
                                        color: color0,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.edit,
                                  size: 22,
                                  color: color0,
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
                            Column(
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
                                      notificationMap[
                                                  '${DeviceManager.getProductCode(deviceName)}/${DeviceManager.extractSerialNumber(deviceName)}']![
                                              index]
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
                                        bool activated = notificationMap[
                                                '${DeviceManager.getProductCode(deviceName)}/${DeviceManager.extractSerialNumber(deviceName)}']![
                                            index];
                                        setState(() {
                                          activated = !activated;
                                          notificationMap[
                                                  '${DeviceManager.getProductCode(deviceName)}/${DeviceManager.extractSerialNumber(deviceName)}']![
                                              index] = activated;
                                        });
                                        saveNotificationMap(notificationMap);
                                      },
                                      icon: notificationMap[
                                                  '${DeviceManager.getProductCode(deviceName)}/${DeviceManager.extractSerialNumber(deviceName)}']![
                                              index]
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
                          ],
                        ),
                      ),
                    },
                    const SizedBox(height: 20),
                  },
                ],
              ),
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

      //*- página 3: Cambiar pines -*\\

      Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 30,
            ),
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
                      for (int i = 2; i < 5; i++) ...[
                        if (i == 4) ...{
                          Padding(
                            padding:
                                EdgeInsets.only(bottom: bottomBarHeight + 10),
                          ),
                        } else ...{
                          Card(
                            color: color3,
                            elevation: 6,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                                vertical: 24.0,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                                  const SizedBox(height: 20),
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
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Center(
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        foregroundColor: color3,
                                        backgroundColor: color0,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 24.0,
                                          vertical: 12.0,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                      ),
                                      onPressed: () {
                                        String data =
                                            '${DeviceManager.getProductCode(deviceName)}[14]($i#${common[i] == '1' ? '0' : '1'})';
                                        printLog(data);
                                        myDevice.toolsUuid
                                            .write(data.codeUnits);
                                      },
                                      child: const Text(
                                        'CAMBIAR',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
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
                      const Icon(Icons.bluetooth, size: 30, color: color0),
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
