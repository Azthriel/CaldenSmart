import 'dart:convert';
import 'package:caldensmart/aws/dynamo/dynamo.dart';
import 'package:caldensmart/master.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../Global/manager_screen.dart';
import '../aws/mqtt/mqtt.dart';
import '../Global/stored_data.dart';
import 'package:caldensmart/logger.dart';

// CLASES \\

class TermotanquePage extends ConsumerStatefulWidget {
  const TermotanquePage({super.key});

  @override
  TermotanquePageState createState() => TermotanquePageState();
}

class TermotanquePageState extends ConsumerState<TermotanquePage> {
  List<String> parts2 = utf8.decode(varsValues).split(':');
  final String pc = DeviceManager.getProductCode(deviceName);
  final String sn = DeviceManager.extractSerialNumber(deviceName);

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
        globalKey: keys['termotanque:estado']!,
        borderRadius: const Radius.circular(30),
        shapeFocus: ShapeFocus.roundedSquare,
        contentPosition: ContentPosition.below,
        focusMargin: 15.0,
        pageIndex: 0,
        child: const TutorialItemContent(
          title: 'Estado del equipo',
          content:
              'En esta pantalla podrás verificar si tu equipo está Apagado o encendido',
        ),
      ),
      TutorialItem(
        globalKey: keys['termotanque:titulo']!,
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
        globalKey: keys['termotanque:wifi']!,
        shapeFocus: ShapeFocus.oval,
        borderRadius: const Radius.circular(15.0),
        contentPosition: ContentPosition.below,
        pageIndex: 0,
        child: const TutorialItemContent(
          title: 'Menu Wifi',
          content:
              'Podrás observar el estado de la conexión wifi del dispositivo',
        ),
      ),
      TutorialItem(
        globalKey: keys['termotanque:servidor']!,
        shapeFocus: ShapeFocus.oval,
        borderRadius: const Radius.circular(15.0),
        contentPosition: ContentPosition.below,
        pageIndex: 0,
        focusMargin: 15.0,
        child: const TutorialItemContent(
          title: 'Conexión al servidor',
          content:
              'Podrás observar el estado de la conexión del dispositivo con el servidor',
        ),
      ),
      TutorialItem(
        globalKey: keys['termotanque:boton']!,
        borderRadius: const Radius.circular(10),
        shapeFocus: ShapeFocus.oval,
        pageIndex: 0,
        focusMargin: 20.0,
        child: const TutorialItemContent(
          title: 'Botón de encendido',
          content: 'Puedes encender o apagar el equipo al presionar el botón',
        ),
      ),
      TutorialItem(
        globalKey: keys['termotanque:temperatura']!,
        borderRadius: const Radius.circular(30),
        shapeFocus: ShapeFocus.roundedSquare,
        focusMargin: 15.0,
        contentPosition: ContentPosition.below,
        pageIndex: 1,
        child: !tenant
            ? const TutorialItemContent(
                title: 'Temperatura',
                content:
                    'En esta pantalla podrás ajustar la temperatura de corte del equipo',
              )
            : const TutorialItemContent(
                title: 'Inquilino',
                content:
                    'Ciertas funciones estan bloqueadas y solo el dueño puede acceder',
              ),
      ),
      if (!tenant) ...{
        TutorialItem(
          globalKey: keys['termotanque:corte']!,
          borderRadius: const Radius.circular(35),
          shapeFocus: ShapeFocus.roundedSquare,
          pageIndex: 1,
          focusMargin: 15.0,
          child: const TutorialItemContent(
            title: 'Barra de temperatura',
            content:
                'Podrás manejar la temperatura a la que el equipo debe cortar',
          ),
        ),
      },
      if (!tenant) ...{
        TutorialItem(
          globalKey: keys['termotanque:consumo']!,
          shapeFocus: ShapeFocus.roundedSquare,
          borderRadius: const Radius.circular(30),
          contentPosition: ContentPosition.below,
          focusMargin: 0.0,
          pageIndex: 2,
          child: const TutorialItemContent(
            title: 'Calculadora de consumo',
            content:
                'En esta pantalla puedes estimar el uso de tu equipo según tu tarifa',
          ),
        ),
        TutorialItem(
          globalKey: keys['termotanque:valor']!,
          shapeFocus: ShapeFocus.roundedSquare,
          borderRadius: const Radius.circular(15.0),
          pageIndex: 2,
          child: const TutorialItemContent(
            title: 'Tarifa',
            content: 'Podrás ingresar el valor de tu tarifa',
          ),
        ),
      } else ...{
        TutorialItem(
          globalKey: keys['termotanque:consumo']!,
          borderRadius: const Radius.circular(0),
          shapeFocus: ShapeFocus.oval,
          contentPosition: ContentPosition.below,
          pageIndex: 2,
          child: const TutorialItemContent(
            title: 'Inquilino',
            content:
                'Ciertas funciones estan bloqueadas y solo el dueño puede acceder',
          ),
        ),
      },
      if (valueConsuption == null && !tenant) ...{
        TutorialItem(
          globalKey: keys['termotanque:consumoManual']!,
          shapeFocus: ShapeFocus.roundedSquare,
          borderRadius: const Radius.circular(15.0),
          pageIndex: 2,
          child: const TutorialItemContent(
            title: 'Tarifa',
            content: 'Podrás ingresar el valor de tu tarifa',
          ),
        ),
      },
      if (!tenant) ...{
        TutorialItem(
          globalKey: keys['termotanque:calcular']!,
          shapeFocus: ShapeFocus.roundedSquare,
          borderRadius: const Radius.circular(15.0),
          pageIndex: 2,
          child: const TutorialItemContent(
            title: 'Calculo',
            content: 'Podrás ver el costo de consumo de tu equipo',
          ),
        ),
        TutorialItem(
          globalKey: keys['termotanque:mes']!,
          shapeFocus: ShapeFocus.roundedSquare,
          borderRadius: const Radius.circular(15.0),
          pageIndex: 2,
          child: const TutorialItemContent(
            title: 'Mes de consumo',
            content: 'Podrás reiniciar el mes de consumo',
          ),
        ),
      },
      TutorialItem(
        globalKey: keys['managerScreen:titulo']!,
        borderRadius: const Radius.circular(10),
        shapeFocus: ShapeFocus.roundedSquare,
        pageIndex: 3,
        focusMargin: 15.0,
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
          globalKey: keys['managerScreen:agregarAdmin']!,
          borderRadius: const Radius.circular(15),
          shapeFocus: ShapeFocus.roundedSquare,
          pageIndex: 3,
          contentPosition: ContentPosition.below,
          buttonAction: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: color0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 17),
            ),
            onPressed: () {
              launchEmail(
                'comercial@caldensmart.com',
                'Habilitación Administradores secundarios extras en $appName',
                '¡Hola! Me comunico porque busco habilitar la opción de "Administradores secundarios extras" en mi equipo ${DeviceManager.getComercialName(deviceName)}\nCódigo de Producto: ${DeviceManager.getProductCode(deviceName)}\nNúmero de Serie: ${DeviceManager.extractSerialNumber(deviceName)}\nDueño actual del equipo: $owner',
              );
            },
            child: const Text(
              'Enviar mail',
              style: TextStyle(color: color1),
            ),
          ),
          child: const TutorialItemContent(
            title: 'Añadir administradores secundarios',
            content:
                'Podrás agregar correos secundarios hasta un límite de tres, en caso de querer extenderlo debes contactarte con comercial@caldensmart.com',
          ),
        ),
        TutorialItem(
          globalKey: keys['managerScreen:verAdmin']!,
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
          globalKey: keys['managerScreen:alquiler']!,
          borderRadius: const Radius.circular(15),
          shapeFocus: ShapeFocus.roundedSquare,
          pageIndex: 3,
          child: const TutorialItemContent(
            title: 'Alquiler temporario',
            content:
                'Puedes agregar el correo de tu inquilino al equipo y ajustarlo',
          ),
        ),
        if (adminDevices.isNotEmpty) ...{
          TutorialItem(
            globalKey: keys['managerScreen:historialAdmin']!,
            borderRadius: const Radius.circular(15),
            shapeFocus: ShapeFocus.roundedSquare,
            pageIndex: 4,
            child: const TutorialItemContent(
              title: 'Historial de administradores secundarios',
              content:
                  'Se veran las acciones ejecutadas por cada uno con su respectiva flecha',
            ),
          ),
          TutorialItem(
            globalKey: keys['managerScreen:horariosAdmin']!,
            borderRadius: const Radius.circular(15),
            shapeFocus: ShapeFocus.roundedSquare,
            pageIndex: 4,
            child: const TutorialItemContent(
              title: 'Horarios de administradores secundarios',
              content:
                  'Configura el rango de horarios y dias que podra accionar el equipo',
            ),
          ),
          TutorialItem(
            globalKey: keys['managerScreen:wifiAdmin']!,
            borderRadius: const Radius.circular(15),
            shapeFocus: ShapeFocus.roundedSquare,
            pageIndex: 4,
            child: const TutorialItemContent(
              title: 'Wifi de administradores secundarios',
              content:
                  'Podras restringirle a los administradores secundarios el uso del menu wifi',
            ),
          ),
        },
      },
      if (!tenant) ...{
        TutorialItem(
          globalKey: keys['managerScreen:accesoRapido']!,
          borderRadius: const Radius.circular(20),
          shapeFocus: ShapeFocus.roundedSquare,
          pageIndex: 3,
          child: const TutorialItemContent(
            title: 'Accesso rápido',
            content: 'Podrás encender y apagar el dispositivo desde el menú',
          ),
        ),
      },
      if (!tenant) ...{
        TutorialItem(
          globalKey: keys['managerScreen:desconexionNotificacion']!,
          borderRadius: const Radius.circular(20),
          shapeFocus: ShapeFocus.roundedSquare,
          pageIndex: 3,
          child: const TutorialItemContent(
            title: 'Notificación de desconexión',
            content:
                'Puedes establecer una alerta si el equipo se desconecta, en el siguiente paso verás un ejemplo de la misma',
          ),
        ),
        TutorialItem(
          globalKey: keys['managerScreen:ejemploNoti']!,
          borderRadius: const Radius.circular(20),
          shapeFocus: ShapeFocus.roundedSquare,
          pageIndex: 3,
          fullBackground: true,
          onStepReached: () {
            setState(() {
              showNotification(
                  '¡El equipo ${nicknamesMap[deviceName] ?? deviceName} se desconecto!',
                  'Se detecto una desconexión a las ${DateTime.now().hour >= 10 ? DateTime.now().hour : '0${DateTime.now().hour}'}:${DateTime.now().minute >= 10 ? DateTime.now().minute : '0${DateTime.now().minute}'} del ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                  'noti');
            });
          },
          child: const TutorialItemContent(
            title: 'Ejemplo de notificación',
            content: '',
          ),
        ),
      },
      TutorialItem(
        globalKey: keys['managerScreen:imagen']!,
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


  ///*- Elementos para tutoriales -*\\\

  @override
  void initState() {
    super.initState();
    timeData();

    if (deviceOwner) {
      if (vencimientoAdmSec < 10 && vencimientoAdmSec > 0) {
        showPaymentText(true, vencimientoAdmSec, navigatorKey.currentContext!);
      }

      if (vencimientoAT < 10 && vencimientoAT > 0) {
        showPaymentText(false, vencimientoAT, navigatorKey.currentContext!);
      }
    }

    showOptions = currentUserEmail == owner;

    nickname = nicknamesMap[deviceName] ?? deviceName;
    tempValue = double.parse(parts2[1]);

    valueConsuption = equipmentConsumption(pc);

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

    addDeviceToCore(deviceName);
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
    List<int> list = await bluetoothManager.varsUuid.read(timeout: 2);
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
      printLog.i('Llegaron cositas wifi');
      updateWifiValues(status);
    });

    bluetoothManager.device.cancelWhenDisconnected(wifiSub);
  }

  void subscribeTrueStatus() async {
    printLog.i('Me subscribo a vars');
    await bluetoothManager.varsUuid.setNotifyValue(true);

    final trueStatusSub =
        bluetoothManager.varsUuid.onValueReceived.listen((List<int> status) {
      var parts = utf8.decode(status).split(':');
      setState(() {
        if (parts[0] == '1') {
          trueStatus = true;
        } else {
          trueStatus = false;
        }
      });
    });

    bluetoothManager.device.cancelWhenDisconnected(trueStatusSub);
  }

  void sendTemperature(int temp) {
    String data = '$pc[7]($temp)';
    bluetoothManager.toolsUuid.write(data.codeUnits);
  }

  void turnDeviceOn(bool on) async {
    // Verificar permisos horarios para administradores secundarios
    bool hasPermission = await checkAdminTimePermission(deviceName);
    if (!hasPermission) {
      return; // No ejecutar si no tiene permisos
    }

    int fun = on ? 1 : 0;
    String data = '$pc[11]($fun)';
    bluetoothManager.toolsUuid.write(data.codeUnits);
    globalDATA['$pc/$sn']!['w_status'] = on;
    saveGlobalData(globalDATA);
    try {
      String topic = 'devices_rx/$pc/$sn';
      String topic2 = 'devices_tx/$pc/$sn';
      String message = jsonEncode({'w_status': on});
      sendMessagemqtt(topic, message);
      sendMessagemqtt(topic2, message);

      // Registrar uso si es administrador secundario
      await registerAdminUsage(
          deviceName, on ? 'Encendió termotanque' : 'Apagó termotanque');
    } catch (e, s) {
      printLog.i('Error al enviar valor a firebase $e $s');
    }
  }

  //! VISUAL
  @override
  Widget build(BuildContext context) {
    final TextStyle poppinsStyle = GoogleFonts.poppins();
    final wifiState = ref.watch(wifiProvider);

    bool isOwner = currentUserEmail == owner;
    bool isSecondaryAdmin = adminDevices.contains(currentUserEmail);
    bool isRegularUser = !isOwner && !isSecondaryAdmin;

    if (!canUseDevice) {
      return const NotAllowedScreen();
    }

    // si hay un usuario conectado al equipo no lo deje ingresar
    if (userConnected && lastUser > 1) {
      return const DeviceInUseScreen();
    }

    if (isRegularUser && owner != '' && !tenant) {
      return const AccessDeniedScreen();
    }

    if (specialUser && !labProcessFinished) {
      return const LabProcessNotFinished();
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
                  key: keys['termotanque:estado']!,
                  'Estado del Dispositivo',
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: color1,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                GestureDetector(
                  key: keys['termotanque:boton']!,
                  onTap: () async {
                    if (isOwner || isSecondaryAdmin || owner == '') {
                      // Verificar permisos horarios para administradores secundarios
                      bool hasPermission =
                          await checkAdminTimePermission(deviceName);
                      if (hasPermission) {
                        turnDeviceOn(!turnOn);
                        setState(() {
                          turnOn = !turnOn;
                        });
                      }
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
                  key: keys['termotanque:temperatura']!,
                  'Temperatura de corte',
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: color1,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Column(
                      children: [
                        Icon(
                          Icons.thermostat_rounded,
                          size: MediaQuery.of(context).size.width * 0.5,
                          color: Color.lerp(
                            Colors.blueAccent,
                            Colors.redAccent,
                            (tempValue - 15) / 55,
                          ),
                        ),
                        if (specialUser) ...[
                          Text(
                            'Temperatura actual:\n$actualTemp °C',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: color1,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                        ],
                      ],
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
                              color: color1,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          key: keys['termotanque:corte']!,
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
                const SizedBox(height: 120)
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
                  key: keys['termotanque:consumo']!,
                  'Calculadora de Consumo',
                  style: GoogleFonts.poppins(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: color1,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 50),
                Container(
                  key: keys['termotanque:valor']!,
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20.0, vertical: 10.0),
                  decoration: BoxDecoration(
                    color: color1.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: color1, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: color1.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    keyboardType: TextInputType.number,
                    controller: costController,
                    style: GoogleFonts.poppins(
                      color: color1,
                      fontSize: 22,
                    ),
                    cursorColor: color1,
                    decoration: InputDecoration(
                      labelText: 'Ingresa valor $measure',
                      labelStyle: GoogleFonts.poppins(
                        color: color1,
                        fontSize: 18,
                      ),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                if (valueConsuption == null) ...[
                  const SizedBox(height: 30),
                  Container(
                    key: keys['termotanque:consumoManual']!,
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20.0, vertical: 10.0),
                    decoration: BoxDecoration(
                      color: color1.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: color1, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: color1.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      keyboardType: TextInputType.number,
                      controller: consuptionController,
                      style: GoogleFonts.poppins(
                        color: color1,
                        fontSize: 22,
                      ),
                      cursorColor: color1,
                      decoration: InputDecoration(
                        labelText: 'Ingresa consumo del equipo',
                        labelStyle: GoogleFonts.poppins(
                          color: color1,
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
                      color: color1,
                      strokeWidth: 4,
                    ),
                  ),
                  Visibility(
                    visible: !loading,
                    child: Text(
                      '\$$result',
                      style: GoogleFonts.poppins(
                        fontSize: 50,
                        color: color1,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            offset: const Offset(0, 3),
                            blurRadius: 8,
                            color: color1.withValues(alpha: 0.5),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 30),
                ElevatedButton(
                  key: keys['termotanque:calcular']!,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color1,
                    foregroundColor: color0,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 35, vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    shadowColor: color1.withValues(alpha: 0.4),
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
                  key: keys['termotanque:mes']!,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color1,
                    foregroundColor: color0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 35,
                      vertical: 20,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    shadowColor: color1.withValues(alpha: 0.4),
                    elevation: 8,
                  ),
                  onPressed: (isOwner || owner == '')
                      ? () {
                          guardarFecha(deviceName).then(
                            (value) => setState(() {
                              fechaSeleccionada = DateTime.now();
                            }),
                          );
                          String data = '$pc[10](0)';
                          bluetoothManager.toolsUuid.write(data.codeUnits);
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
                    'Último reinicio: ${fechaSeleccionada?.day ?? 5}/${fechaSeleccionada?.month ?? 11}/${fechaSeleccionada?.year ?? 2004}',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: color1,
                    ),
                  )
                else
                  const SizedBox(),
                const SizedBox(height: 120),
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
      ManagerScreen(deviceName: deviceName),
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
                  key: keys['termotanque:titulo']!,
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
              key: keys['termotanque:servidor']!,
              globalDATA['$pc/$sn']?['cstate'] ?? false
                  ? Icons.cloud
                  : Icons.cloud_off,
              color: color0,
            ),
            IconButton(
              key: keys['termotanque:wifi']!,
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
                        Icon(Icons.thermostat, size: 30, color: color0),
                        Icon(Icons.calculate, size: 30, color: color0),
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
                backgroundColor: color4,
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
