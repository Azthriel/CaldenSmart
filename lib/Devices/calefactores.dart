import 'dart:convert';
import 'package:caldensmart/master.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../Global/manager_screen.dart';
import '../aws/dynamo/dynamo.dart';
import '../aws/dynamo/dynamo_certificates.dart';
import '../aws/mqtt/mqtt.dart';
import '../Global/stored_data.dart';

// CLASES \\

class CalefactorPage extends StatefulWidget {
  const CalefactorPage({super.key});

  @override
  CalefactorPageState createState() => CalefactorPageState();
}

class CalefactorPageState extends State<CalefactorPage> {
  var parts2 = utf8.decode(varsValues).split(':');

  late double tempValue;

  int _selectedIndex = 0;
  double result = 0.0;
  double? valueConsuption;

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
  bool ignite = false;

  String measure = DeviceManager.getProductCode(deviceName) == '022000_IOT'
      ? 'KW/h'
      : 'M³/h';
  IconData powerIconOn =
      DeviceManager.getProductCode(deviceName) == '022000_IOT'
          ? Icons.flash_on_rounded
          : HugeIcons.strokeRoundedFire;
  IconData powerIconOff =
      DeviceManager.getProductCode(deviceName) == '022000_IOT'
          ? Icons.flash_off_rounded
          : HugeIcons.strokeRoundedFire;

  TextEditingController emailController = TextEditingController();
  final TextEditingController costController = TextEditingController();
  final TextEditingController tenantController = TextEditingController();
  final PageController _pageController = PageController(initialPage: 0);
  final TextEditingController consuptionController = TextEditingController();

  DateTime? fechaSeleccionada;

  String tiempo = '';

  ///*- Elementos para tutoriales -*\\\
  List<TutorialItem> items = [];

  void initItems() {
    items.addAll({
      TutorialItem(
        globalKey: estadoKey,
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: const Radius.circular(0),
        shapeFocus: ShapeFocus.oval,
        contentPosition: ContentPosition.below,
        radius: 0,
        pageIndex: 0,
        child: const TutorialItemContent(
          title: 'Estado del equipo',
          content:
              'En esta pantalla podrás verificar si tu equipo está Apagado o encendido',
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
      TutorialItem(
        globalKey: bottomKey,
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: const Radius.circular(10),
        radius: 80,
        shapeFocus: ShapeFocus.oval,
        pageIndex: 0,
        child: const TutorialItemContent(
          title: 'Botón de encendido',
          content: 'Puedes encender o apagar el equipo al presionar el botón',
        ),
      ),
    });
    if (DeviceManager.getProductCode(deviceName) == '027000_IOT') {
      items.addAll({
        TutorialItem(
          globalKey: sparkKey,
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: const Radius.circular(10),
          radius: 50,
          shapeFocus: ShapeFocus.oval,
          pageIndex: 0,
          child: const TutorialItemContent(
            title: 'Chispero',
            content:
                'Podrás activar o desactivar el chispero apretando el botón',
          ),
        ),
      });
    }
    if (!tenant) {
      items.addAll({
        TutorialItem(
          globalKey: tempKey,
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: const Radius.circular(0),
          shapeFocus: ShapeFocus.oval,
          contentPosition: ContentPosition.below,
          pageIndex: 1,
          radius: 0,
          child: const TutorialItemContent(
            title: 'Temperatura',
            content:
                'En esta pantalla podrás ajustar la temperatura de corte del equipo',
          ),
        ),
        TutorialItem(
          globalKey: tempBarKey,
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: const Radius.circular(35),
          shapeFocus: ShapeFocus.roundedSquare,
          pageIndex: 1,
          child: const TutorialItemContent(
            title: 'Barra de temperatura',
            content:
                'Podrás manejar la temperatura a la que el equipo debe cortar',
          ),
        ),
      });
    } else {
      items.addAll({
        TutorialItem(
          globalKey: tempKey,
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: const Radius.circular(0),
          shapeFocus: ShapeFocus.oval,
          contentPosition: ContentPosition.below,
          pageIndex: 1,
          radius: 0,
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
        globalKey: distanceKey,
        color: Colors.black.withValues(alpha: 0.6),
        shapeFocus: ShapeFocus.oval,
        borderRadius: const Radius.circular(0),
        radius: 0,
        pageIndex: 2,
        child: const TutorialItemContent(
          title: 'Control por distancia',
          content:
              'Podrás ajustar la distancia de encendido y apagado de tu dispositivo',
        ),
      ),
      TutorialItem(
        globalKey: distanceBottomKey,
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: const Radius.circular(10),
        radius: 90,
        shapeFocus: ShapeFocus.oval,
        pageIndex: 2,
        child: const TutorialItemContent(
          title: 'Botón de encendido',
          content: 'Podrás activar esta función y configurar la distancia',
        ),
      ),
    });
    if (!tenant) {
      items.addAll({
        TutorialItem(
          globalKey: consumeKey,
          color: Colors.black.withValues(alpha: 0.6),
          shapeFocus: ShapeFocus.oval,
          borderRadius: const Radius.circular(0),
          radius: 0,
          contentPosition: ContentPosition.below,
          pageIndex: 3,
          child: const TutorialItemContent(
            title: 'Calculadora de consumo',
            content:
                'En esta pantalla puedes estimar el uso de tu equipo según tu tarifa',
          ),
        ),
        TutorialItem(
          globalKey: valorKey,
          color: Colors.black.withValues(alpha: 0.6),
          shapeFocus: ShapeFocus.roundedSquare,
          borderRadius: const Radius.circular(15.0),
          pageIndex: 3,
          child: const TutorialItemContent(
            title: 'Tarifa',
            content: 'Podrás ingresar el valor de tu tarifa',
          ),
        ),
      });
    } else {
      items.addAll({
        TutorialItem(
          globalKey: consumeKey,
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: const Radius.circular(0),
          shapeFocus: ShapeFocus.oval,
          contentPosition: ContentPosition.below,
          pageIndex: 3,
          radius: 0,
          child: const TutorialItemContent(
            title: 'Inquilino',
            content:
                'Ciertas funciones estan bloqueadas y solo el dueño puede acceder',
          ),
        ),
      });
    }
    if (valueConsuption == null && !tenant) {
      items.addAll({
        TutorialItem(
          globalKey: consuptionKey,
          color: Colors.black.withValues(alpha: 0.6),
          shapeFocus: ShapeFocus.roundedSquare,
          borderRadius: const Radius.circular(15.0),
          pageIndex: 3,
          child: const TutorialItemContent(
            title: 'Tarifa',
            content: 'Podrás ingresar el valor de tu tarifa',
          ),
        ),
      });
    }
    if (!tenant) {
      items.addAll({
        TutorialItem(
          globalKey: calculateKey,
          color: Colors.black.withValues(alpha: 0.6),
          shapeFocus: ShapeFocus.roundedSquare,
          borderRadius: const Radius.circular(15.0),
          pageIndex: 3,
          child: const TutorialItemContent(
            title: 'Calculo',
            content: 'Podrás ver el costo de consumo de tu equipo',
          ),
        ),
        TutorialItem(
          globalKey: mesKey,
          color: Colors.black.withValues(alpha: 0.6),
          shapeFocus: ShapeFocus.roundedSquare,
          borderRadius: const Radius.circular(15.0),
          pageIndex: 3,
          child: const TutorialItemContent(
            title: 'Mes de consumo',
            content: 'Podrás reiniciar el mes de consumo',
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
        radius: 0,
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
          pageIndex: 4,
          contentPosition: ContentPosition.below,
          child: const TutorialItemContent(
            title: 'Reclamar administrador',
            content:
                'Presiona este botón para reclamar la administración del equipo',
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
          pageIndex: 4,
          contentPosition: ContentPosition.above,
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
          pageIndex: 4,
          contentPosition: ContentPosition.above,
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
          pageIndex: 4,
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
          borderRadius: const Radius.circular(20),
          shapeFocus: ShapeFocus.roundedSquare,
          pageIndex: 4,
          child: const TutorialItemContent(
            title: 'Accesso rápido',
            content: 'Podrás encender y apagar el dispositivo desde el menú',
          ),
        ),
      });
    }

    if (!tenant) {
      items.addAll({
        TutorialItem(
          globalKey: discNotificationKey,
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: const Radius.circular(20),
          shapeFocus: ShapeFocus.roundedSquare,
          pageIndex: 4,
          child: const TutorialItemContent(
            title: 'Notificación de desconexión',
            content: 'Puedes establecer una alerta si el equipo se desconecta',
          ),
        ),
      });
    }
    items.addAll({
      TutorialItem(
        globalKey: ledKey,
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: const Radius.circular(20),
        shapeFocus: ShapeFocus.roundedSquare,
        pageIndex: 4,
        child: const TutorialItemContent(
          title: 'Modo del led',
          content: 'podrás cambiar entre el modo nocturno y diurno',
        ),
      ),
      TutorialItem(
        globalKey: imageKey,
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: const Radius.circular(20),
        shapeFocus: ShapeFocus.roundedSquare,
        pageIndex: 4,
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

    printLog('Valor temp: $tempValue');
    printLog('¿Encendido? $turnOn');
    printLog('¿Alquiler temporario? $activatedAT');
    printLog('¿Inquilino? $tenant');
    updateWifiValues(toolsValues);
    subscribeToWifiStatus();
    subscribeTrueStatus();
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

  void timeData() async {
    fechaSeleccionada = await cargarFechaGuardada(deviceName);
    List<int> list = await myDevice.varsUuid.read(timeout: 2);
    List<String> partes = utf8.decode(list).split(':');

    if (partes.length > 2) {
      tiempo = partes[3];
      printLog('Tiempo: ${utf8.decode(list).split(':')}');
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

        printLog('Estoy haciendo calculaciones místicas');

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

        printLog('Calculaciones terminadas');

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
      printLog('Llegaron cositas wifi');
      updateWifiValues(status);
    });

    myDevice.device.cancelWhenDisconnected(wifiSub);
  }

  void subscribeTrueStatus() async {
    printLog('Me subscribo a vars');
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
      printLog('Error al enviar valor a firebase $e $s');
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
                      printLog(e);
                      printLog(s);
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
      printLog('Error al habilitar la ubi: $e');
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
      Stack(
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: MediaQuery.of(context).size.height * 0.15,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  key: estadoKey,
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
                    key: bottomKey,
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
                if (DeviceManager.getProductCode(deviceName) ==
                    '027000_IOT') ...{
                  const SizedBox(
                    height: 30,
                  ),
                  GestureDetector(
                    key: sparkKey,
                    onLongPressStart: (LongPressStartDetails a) async {
                      setState(() {
                        ignite = true;
                      });
                      while (ignite) {
                        await Future.delayed(const Duration(milliseconds: 500));
                        if (!ignite) break;
                        String data = '027000_IOT[15](1)';
                        myDevice.toolsUuid.write(data.codeUnits);
                        printLog(data);
                      }
                    },
                    onLongPressEnd: (LongPressEndDetails a) {
                      setState(() {
                        ignite = false;
                      });
                      String data = '027000_IOT[15](0)';
                      myDevice.toolsUuid.write(data.codeUnits);
                      printLog(data);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.yellow[600],
                        shape: BoxShape.circle,
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 10,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.auto_awesome,
                        size: 30,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                  const Text(
                    'Chispero',
                    style: TextStyle(
                      color: Colors.black,
                    ),
                  )
                }
              ],
            ),
          ),
        ],
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
                  key: tempKey,
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
                        (tempValue - 10) / 30,
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
                            // Colors.white.withValues(alpha:0.2),
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
                          key: tempBarKey,
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
                                  height: (tempValue > 0
                                      ? ((tempValue / 100) * 900).clamp(40, 350)
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
                                      min: 10,
                                      max: 40,
                                      onChanged: (value) {
                                        setState(() {
                                          tempValue = value;
                                        });
                                      },
                                      onChangeEnd: (value) {
                                        printLog('$value');
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
          if (!isOwner && owner != '') ...[
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.7),
                child: const Center(
                  child: Text(
                    'No tienes acceso a esta función',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),

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
                      key: distanceKey,
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
                      key: distanceBottomKey,
                      onTap: () {
                        if (isOwner || owner == '' || tenant) {
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
                                  Card(
                                    color: color3..withValues(alpha: 0.9),
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
                                    color: color3..withValues(alpha: 0.9),
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
              if (!isOwner && owner != '' && !tenant)
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

      //*- Página 4 - Calculadora de consumo -*\\
      Stack(
        children: [
          SingleChildScrollView(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20.0, vertical: 30.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    key: consumeKey,
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
                    key: valorKey,
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
                      key: consuptionKey,
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
                    key: calculateKey,
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
                    key: mesKey,
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
          ),
          if (!isOwner && owner != '')
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.7),
                child: const Center(
                  child: Text(
                    'No tienes acceso a esta función',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                    ),
                  ),
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
                        saveNicknamesMap(nicknamesMap);
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
                    items: const <Widget>[
                      Icon(Icons.home, size: 30, color: color0),
                      Icon(Icons.thermostat, size: 30, color: color0),
                      Icon(Icons.location_on, size: 30, color: color0),
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
