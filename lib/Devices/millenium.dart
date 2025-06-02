import 'dart:convert';
import 'package:caldensmart/aws/dynamo/dynamo.dart';
import 'package:caldensmart/aws/dynamo/dynamo_certificates.dart';
import 'package:caldensmart/master.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../Global/manager_screen.dart';
import '../aws/mqtt/mqtt.dart';
import '../Global/stored_data.dart';
import 'package:caldensmart/logger.dart';

// CLASES \\

class MilleniumPage extends StatefulWidget {
  const MilleniumPage({super.key});

  @override
  MilleniumPageState createState() => MilleniumPageState();
}

class MilleniumPageState extends State<MilleniumPage> {
  List<String> parts2 = utf8.decode(varsValues).split(':');

  bool showSecondaryAdminFields = false;
  bool showAddAdminField = false;
  bool showSecondaryAdminList = false;
  bool showSmartResident = false;
  bool dOnOk = false;
  bool dOffOk = false;
  bool showOptions = false;
  bool _isAnimating = false;
  bool buttonPressed = false;
  bool _isTutorialActive = false;
  late bool loading;

  String tiempo = '';
  String measure = 'KW/h';

  IconData powerIconOn = Icons.water_drop;
  IconData powerIconOff = Icons.format_color_reset;

  int _selectedIndex = 0;

  double result = 0.0;
  double? valueConsuption;

  late double tempValue;

  TextEditingController emailController = TextEditingController();
  final TextEditingController costController = TextEditingController();
  final TextEditingController tenantController = TextEditingController();
  final PageController _pageController = PageController(initialPage: 0);
  final TextEditingController consuptionController = TextEditingController();

  DateTime? fechaSeleccionada;

  ///*- Elementos para tutoriales -*\\\
  List<TutorialItem> items = [];

  void initItems() {
    items.addAll({
      TutorialItem(
        globalKey: KeyManager.millenium.estadoKey,
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: const Radius.circular(0),
        shapeFocus: ShapeFocus.oval,
        radius: 0,
        pageIndex: 0,
        child: const TutorialItemContent(
          title: 'Estado del equipo',
          content:
              'En esta pantalla podrás verificar si tu equipo está Apagado o encendido',
        ),
      ),
      TutorialItem(
        globalKey: KeyManager.millenium.titleKey,
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
        globalKey: KeyManager.millenium.wifiKey,
        color: Colors.black.withValues(alpha: 0.6),
        shapeFocus: ShapeFocus.oval,
        borderRadius: const Radius.circular(15.0),
        radius: 25,
        contentPosition: ContentPosition.below,
        pageIndex: 0,
        child: const TutorialItemContent(
          title: 'Menu Wifi',
          content: 'Podrás observar el estado de la conexión wifi del equipo',
        ),
      ),
      TutorialItem(
        globalKey: KeyManager.millenium.bottomKey,
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: const Radius.circular(10),
        radius: 90,
        shapeFocus: ShapeFocus.oval,
        pageIndex: 0,
        child: const TutorialItemContent(
          title: 'Botón de encendido',
          content: 'Puedes encender o apagar el equipo al presionar el botón',
        ),
      ),
      TutorialItem(
        globalKey: KeyManager.millenium.tempKey,
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: const Radius.circular(0),
        shapeFocus: ShapeFocus.oval,
        contentPosition: ContentPosition.below,
        pageIndex: 1,
        radius: 0,
        child: const TutorialItemContent(
          title: 'Temperatura',
          content:
              'En esta pantalla podras controlar la temperatura de corte del equipo',
        ),
      ),
      TutorialItem(
        globalKey: KeyManager.millenium.tempBarKey,
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: const Radius.circular(35),
        shapeFocus: ShapeFocus.roundedSquare,
        pageIndex: 1,
        child: const TutorialItemContent(
          title: 'Barra de temperatura',
          content:
              'Podras controlar la temperatura a la cual el equipo debe cortar',
        ),
      ),
      TutorialItem(
        globalKey: KeyManager.millenium.consumeKey,
        color: Colors.black.withValues(alpha: 0.6),
        shapeFocus: ShapeFocus.oval,
        borderRadius: const Radius.circular(0),
        radius: 0,
        contentPosition: ContentPosition.below,
        pageIndex: 2,
        child: const TutorialItemContent(
          title: 'Calculadora de consumo',
          content:
              'En esta pantalla puedes estimar el uso de tu equipo según tu tarifa',
        ),
      ),
      TutorialItem(
        globalKey: KeyManager.millenium.valorKey,
        color: Colors.black.withValues(alpha: 0.6),
        shapeFocus: ShapeFocus.roundedSquare,
        borderRadius: const Radius.circular(15.0),
        pageIndex: 2,
        child: const TutorialItemContent(
          title: 'Tarifa',
          content: 'Podrás ingresar el valor de tu tarifa',
        ),
      ),
      if (valueConsuption == null) ...{
        TutorialItem(
          globalKey: KeyManager.millenium.consuptionKey,
          color: Colors.black.withValues(alpha: 0.6),
          shapeFocus: ShapeFocus.roundedSquare,
          borderRadius: const Radius.circular(15.0),
          pageIndex: 2,
          child: const TutorialItemContent(
            title: 'Tarifa',
            content: 'Podrás ingresar el valor de tu tarifa',
          ),
        ),
      },
      TutorialItem(
        globalKey: KeyManager.millenium.calculateKey,
        color: Colors.black.withValues(alpha: 0.6),
        shapeFocus: ShapeFocus.roundedSquare,
        borderRadius: const Radius.circular(15.0),
        pageIndex: 2,
        child: const TutorialItemContent(
          title: 'Calculo',
          content: 'Podrás ver el costo de consumo de tu equipo',
        ),
      ),
      TutorialItem(
        globalKey: KeyManager.millenium.mesKey,
        color: Colors.black.withValues(alpha: 0.6),
        shapeFocus: ShapeFocus.roundedSquare,
        borderRadius: const Radius.circular(15.0),
        pageIndex: 2,
        child: const TutorialItemContent(
          title: 'Mes de consumo',
          content: 'Podrás reiniciar el mes de consumo',
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
      if (currentUserEmail == owner) ...{
        TutorialItem(
          globalKey: KeyManager.managerScreen.agreeAdminKey,
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: const Radius.circular(15),
          shapeFocus: ShapeFocus.roundedSquare,
          pageIndex: 3,
          contentPosition: ContentPosition.above,
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
          contentPosition: ContentPosition.above,
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
    timeData();

    if (deviceOwner) {
      if (vencimientoAdmSec < 10 && vencimientoAdmSec > 0) {
        showPaymentTest(true, vencimientoAdmSec, navigatorKey.currentContext!);
      }

      if (vencimientoAT < 10 && vencimientoAT > 0) {
        showPaymentTest(false, vencimientoAT, navigatorKey.currentContext!);
      }
    }

    showOptions = currentUserEmail == owner;

    nickname = nicknamesMap[deviceName] ?? deviceName;
    tempValue = double.parse(parts2[1]);

    valueConsuption =
        equipmentConsumption(DeviceManager.getProductCode(deviceName));

    printLog.i('Valor temp: $tempValue');
    printLog.i('¿Encendido? $turnOn');
    printLog.i('¿Alquiler temporario? $activatedAT');
    printLog.i('¿Inquilino? $tenant');
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      updateWifiValues(toolsValues);
      if (shouldUpdateDevice) {
        await showUpdateDialog(context);
      }
    });
    subscribeToWifiStatus();
    subscribeTrueStatus();

    if (!alexaDevices.contains(deviceName)) {
      alexaDevices.add(deviceName);
      putDevicesForAlexa(service, currentUserEmail, alexaDevices);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    tenantController.dispose();
    costController.dispose();
    emailController.dispose();
    consuptionController.dispose();
    super.dispose();
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

  void timeData() async {
    fechaSeleccionada = await cargarFechaGuardada(deviceName);
    List<int> list = await myDevice.varsUuid.read(timeout: 2);
    List<String> partes = utf8.decode(list).split(':');

    if (partes.length > 2) {
      tiempo = partes[3];
      printLog.i('Tiempo: ${utf8.decode(list).split(':')}');
    } else {
      timeData();
    }
  }

  void makeCompute() async {
    if (tiempo != '') {
      if (costController.text.isNotEmpty) {
        setState(() {
          buttonPressed = true;
          loading = true;
        });

        printLog.i('Estoy haciendo calculaciones místicas');

        if (valueConsuption != null) {
          result = double.parse(tiempo) *
              valueConsuption! *
              double.parse(costController.text.trim());
        } else {
          result = double.parse(tiempo) *
              double.parse(consuptionController.text.trim()) *
              double.parse(costController.text.trim());
        }

        await Future.delayed(const Duration(seconds: 1));

        printLog.i('Calculaciones terminadas');

        if (context.mounted) {
          setState(() {
            loading = false;
          });
        }
      } else {
        showToast('Primero debes ingresar un valor kW/h');
      }
    } else {
      showToast(
          'Error al hacer el cálculo\nPor favor cierra y vuelve a abrir el menú');
    }
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

    WifiNotifier wifiNotifier =
        Provider.of<WifiNotifier>(context, listen: false);

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
      printLog.i('Llegaron cositas wifi');
      updateWifiValues(status);
    });

    myDevice.device.cancelWhenDisconnected(wifiSub);
  }

  void subscribeTrueStatus() async {
    printLog.i('Me subscribo a vars');
    await myDevice.varsUuid.setNotifyValue(true);

    final trueStatusSub =
        myDevice.varsUuid.onValueReceived.listen((List<int> status) {
      var parts = utf8.decode(status).split(':');
      setState(() {
        if (parts[0] == '1') {
          trueStatus = true;
        } else {
          trueStatus = false;
        }
      });
    });

    myDevice.device.cancelWhenDisconnected(trueStatusSub);
  }

  void sendTemperature(int temp) {
    String data = '${DeviceManager.getProductCode(deviceName)}[7]($temp)';
    myDevice.toolsUuid.write(data.codeUnits);
  }

  void turnDeviceOn(bool on) async {
    int fun = on ? 1 : 0;
    String data = '${DeviceManager.getProductCode(deviceName)}[11]($fun)';
    myDevice.toolsUuid.write(data.codeUnits);
    globalDATA[
            '${DeviceManager.getProductCode(deviceName)}/${DeviceManager.extractSerialNumber(deviceName)}']![
        'w_status'] = on;
    saveGlobalData(globalDATA);
    try {
      String topic =
          'devices_rx/${DeviceManager.getProductCode(deviceName)}/${DeviceManager.extractSerialNumber(deviceName)}';
      String topic2 =
          'devices_tx/${DeviceManager.getProductCode(deviceName)}/${DeviceManager.extractSerialNumber(deviceName)}';
      String message = jsonEncode({'w_status': on});
      sendMessagemqtt(topic, message);
      sendMessagemqtt(topic2, message);
    } catch (e, s) {
      printLog.i('Error al enviar valor a firebase $e $s');
    }
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
        printLog.i(
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
          printLog.i('Servicio iniciado a las ${DateTime.now()}');
        }
      } catch (e) {
        showToast('Error al iniciar control por distancia.');
        printLog.i('Error al setear la ubicación $e');
      }
    } else {
      // Cancelar la tarea.
      showToast('Se cancelo el control por distancia');
      String data = '${DeviceManager.getProductCode(deviceName)}[5](0)';
      myDevice.toolsUuid.write(data.codeUnits);
      List<String> deviceControl = await loadDevicesForDistanceControl();
      deviceControl.remove(deviceName);
      saveDevicesForDistanceControl(deviceControl);
      printLog.i(
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
        printLog.i('Servicio apagado');
      }
    }
  }

  Future<bool> verifyPermission() async {
    try {
      var permissionStatus4 = await Permission.locationAlways.status;
      if (!permissionStatus4.isGranted) {
        await showDialog<void>(
          context: navigatorKey.currentContext ?? context,
          barrierDismissible: false,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              backgroundColor: const Color(0xFF252223),
              title: const Text(
                'Habilita la ubicación todo el tiempo',
                style: TextStyle(color: Color(0xFFFFFFFF)),
              ),
              content: Text(
                '$appName utiliza tu ubicación, incluso cuando la app esta cerrada o en desuso, para poder encender o apagar el calefactor en base a tu distancia con el mismo.',
                style: const TextStyle(
                  color: Color(0xFFFFFFFF),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  style: const ButtonStyle(
                    foregroundColor: WidgetStatePropertyAll(
                      Color(0xFFFFFFFF),
                    ),
                  ),
                  child: const Text('Habilitar'),
                  onPressed: () async {
                    try {
                      var permissionStatus4 =
                          await Permission.locationAlways.request();

                      if (!permissionStatus4.isGranted) {
                        await Permission.locationAlways.request();
                      }
                      permissionStatus4 =
                          await Permission.locationAlways.status;
                    } catch (e, s) {
                      printLog.i(e);
                      printLog.i(s);
                    }
                    Navigator.of(navigatorKey.currentContext ?? context)
                        .pop(); // Cierra el AlertDialog
                  },
                ),
              ],
            );
          },
        );
      }

      permissionStatus4 = await Permission.locationAlways.status;

      if (permissionStatus4.isGranted) {
        return true;
      } else {
        return false;
      }
    } catch (e, s) {
      printLog.i('Error al habilitar la ubi: $e');
      printLog.i(s);
      return false;
    }
  }

  //! VISUAL
  @override
  Widget build(BuildContext context) {
    final TextStyle poppinsStyle = GoogleFonts.poppins();
    WifiNotifier wifiNotifier =
        Provider.of<WifiNotifier>(context, listen: false);

    bool isOwner = currentUserEmail == owner;
    bool isSecondaryAdmin = adminDevices.contains(currentUserEmail);
    bool isRegularUser = !isOwner && !isSecondaryAdmin;

    // si hay un usuario conectado al equipo no lo deje ingresar
    if (userConnected && lastUser > 1) {
      return const DeviceInUseScreen();
    }

    if (isRegularUser && owner != '' && !tenant) {
      return const AccessDeniedScreen();
    }

    final List<Widget> pages = [
      //*- Página 1 - Estado del dispositivo -*\\
      SingleChildScrollView(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.8,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  key: KeyManager.millenium.estadoKey,
                  'Estado del Dispositivo',
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: color3,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                GestureDetector(
                  key: KeyManager.millenium.bottomKey,
                  onTap: () {
                    if (isOwner || isSecondaryAdmin || owner == '') {
                      turnDeviceOn(!turnOn);
                      setState(() {
                        turnOn = !turnOn;
                      });
                    } else {
                      showToast('No tienes permiso para realizar esta acción');
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: turnOn
                          ? (trueStatus
                              ? Colors.amber[600]
                              : Colors.greenAccent)
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
                    child: turnOn
                        ? AnimatedIconWidget(
                            isHeating: trueStatus,
                            icon: powerIconOn,
                          )
                        : Icon(powerIconOff, size: 80, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text.rich(
                      TextSpan(
                        text: turnOn
                            ? (trueStatus ? 'Calentando' : 'Encendido')
                            : 'Apagado',
                        style: GoogleFonts.poppins(
                          color: turnOn
                              ? (trueStatus ? Colors.amber[600] : Colors.green)
                              : Colors.red,
                          fontSize: 30,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),

      //*- Pagina 2 - Temperatura de corte -*\\
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
                  key: KeyManager.millenium.tempKey,
                  'Temperatura de corte',
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: color3,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.thermostat_rounded,
                      size: 200,
                      color: Color.lerp(
                        Colors.blueAccent,
                        Colors.redAccent,
                        (tempValue - 15) / 55,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8.0),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${tempValue.round()}°C',
                            style: GoogleFonts.poppins(
                              fontSize: 24,
                              color: color3,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          key: KeyManager.millenium.tempBarKey,
                          height: 350,
                          width: 70,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(40),
                            color: Colors.grey.withValues(alpha: 0.1),
                          ),
                          child: Stack(
                            alignment: Alignment.bottomCenter,
                            children: [
                              Align(
                                alignment: Alignment.bottomCenter,
                                child: Container(
                                  width: 70,
                                  height: (tempValue > 15
                                      ? (((tempValue - 15) / 55) * 350)
                                          .clamp(40, 350)
                                      : 40),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(40),
                                    gradient: const LinearGradient(
                                      colors: [
                                        Colors.blueAccent,
                                        Colors.redAccent,
                                      ],
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                    ),
                                  ),
                                ),
                              ),
                              Positioned.fill(
                                child: SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    trackHeight: 70,
                                    thumbShape: const RoundSliderThumbShape(
                                      enabledThumbRadius: 0,
                                    ),
                                    overlayShape:
                                        SliderComponentShape.noOverlay,
                                    thumbColor: Colors.transparent,
                                    activeTrackColor: Colors.transparent,
                                    inactiveTrackColor: Colors.transparent,
                                  ),
                                  child: RotatedBox(
                                    quarterTurns: 3,
                                    child: Slider(
                                      value: tempValue,
                                      min: 15,
                                      max: 70,
                                      onChanged: (value) {
                                        setState(() {
                                          tempValue = value;
                                        });
                                      },
                                      onChangeEnd: (value) {
                                        printLog.i('$value');
                                        sendTemperature(value.round());
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
                  ],
                ),
              ],
            ),
          ),
          if (!isOwner && owner != '')
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

      //*- Página 3 - Nueva funcionalidad con ingreso de valores y cálculo -*\\
      Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 30,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  key: KeyManager.millenium.consumeKey,
                  'Calculadora de Consumo',
                  style: GoogleFonts.poppins(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: color3,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 50),
                Container(
                  key: KeyManager.millenium.valorKey,
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20.0, vertical: 10.0),
                  decoration: BoxDecoration(
                    color: color3.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: color3, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: color3.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    keyboardType: TextInputType.number,
                    controller: costController,
                    style: GoogleFonts.poppins(
                      color: color3,
                      fontSize: 22,
                    ),
                    cursorColor: color3,
                    decoration: InputDecoration(
                      labelText: 'Ingresa valor $measure',
                      labelStyle: GoogleFonts.poppins(
                        color: color3,
                        fontSize: 18,
                      ),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                if (valueConsuption == null) ...[
                  const SizedBox(height: 30),
                  Container(
                    key: KeyManager.millenium.consuptionKey,
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20.0, vertical: 10.0),
                    decoration: BoxDecoration(
                      color: color3.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: color3, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: color3.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      keyboardType: TextInputType.number,
                      controller: consuptionController,
                      style: GoogleFonts.poppins(
                        color: color3,
                        fontSize: 22,
                      ),
                      cursorColor: color3,
                      decoration: InputDecoration(
                        labelText: 'Ingresa consumo del equipo',
                        labelStyle: GoogleFonts.poppins(
                          color: color3,
                          fontSize: 18,
                        ),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ],
                if (buttonPressed) ...[
                  const SizedBox(height: 30),
                  Visibility(
                    visible: loading,
                    child: const CircularProgressIndicator(
                      color: color3,
                      strokeWidth: 4,
                    ),
                  ),
                  Visibility(
                    visible: !loading,
                    child: Text(
                      '\$$result',
                      style: GoogleFonts.poppins(
                        fontSize: 50,
                        color: color3,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            offset: const Offset(0, 3),
                            blurRadius: 8,
                            color: color3.withValues(alpha: 0.5),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 30),
                ElevatedButton(
                  key: KeyManager.millenium.calculateKey,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color3,
                    foregroundColor: color0,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 35, vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    shadowColor: color3.withValues(alpha: 0.4),
                    elevation: 8,
                  ),
                  onPressed: (isOwner || owner == '')
                      ? () {
                          if (valueConsuption != null) {
                            if (costController.text.isNotEmpty) {
                              makeCompute();
                            } else {
                              showToast('Por favor ingresa un valor');
                            }
                          } else {
                            if (costController.text.isNotEmpty &&
                                consuptionController.text.isNotEmpty) {
                              makeCompute();
                            } else {
                              showToast(
                                  'Por favor ingresa valores en ambos campos');
                            }
                          }
                        }
                      : null,
                  child: Text(
                    'Hacer cálculo',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  key: KeyManager.millenium.mesKey,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color3,
                    foregroundColor: color0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 35,
                      vertical: 20,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    shadowColor: color3.withValues(alpha: 0.4),
                    elevation: 8,
                  ),
                  onPressed: (isOwner || owner == '')
                      ? () {
                          guardarFecha(deviceName).then(
                            (value) => setState(() {
                              fechaSeleccionada = DateTime.now();
                            }),
                          );
                          String data =
                              '${DeviceManager.getProductCode(deviceName)} ';
                          myDevice.toolsUuid.write(data.codeUnits);
                        }
                      : null,
                  child: Text(
                    'Reiniciar mes',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 25),
                if (fechaSeleccionada != null)
                  Text(
                    'Último reinicio: ${fechaSeleccionada!.day}/${fechaSeleccionada!.month}/${fechaSeleccionada!.year}',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: color3,
                    ),
                  )
                else
                  const SizedBox(),
              ],
            ),
          ),
          if (!isOwner && owner != '')
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
                  key: KeyManager.millenium.titleKey,
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
              key: KeyManager.millenium.wifiKey,
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
                      Icon(Icons.thermostat, size: 30, color: color0),
                      Icon(Icons.calculate, size: 30, color: color0),
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
