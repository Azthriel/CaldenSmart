import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
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
  bool _showPassword = false;

  final String pc = DeviceManager.getProductCode(deviceName);
  final String sn = DeviceManager.extractSerialNumber(deviceName);

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
        globalKey: keys['domotica:activarNoti']!,
        borderRadius: const Radius.circular(30),
        shapeFocus: ShapeFocus.roundedSquare,
        contentPosition: ContentPosition.below,
        focusMargin: 15.0,
        pageIndex: 0,
        contentOffsetY: -500,
        fullBackground: true,
        child: const TutorialItemContent(
          title: 'Notificación de alarma',
          content:
              'En la entrada podrás activar una notificación para cuando cambie su estado como la siguiente...',
        ),
      ),
      TutorialItem(
        globalKey: keys['domotica:ejemploAlerta']!,
        borderRadius: const Radius.circular(20),
        shapeFocus: ShapeFocus.roundedSquare,
        contentPosition: ContentPosition.below,
        contentOffsetY: -500,
        pageIndex: 0,
        fullBackground: true,
        onStepReached: () {
          setState(() {
            showNotification(
                '¡ALERTA EN ${nicknamesMap[deviceName] ?? deviceName}!',
                'La Entrada 1 disparó una alarma.\nA las ${DateTime.now().hour >= 10 ? DateTime.now().hour : '0${DateTime.now().hour}'}:${DateTime.now().minute >= 10 ? DateTime.now().minute : '0${DateTime.now().minute}'} del ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                soundOfNotification[DeviceManager.getProductCode(deviceName)] ??
                    'alarm2');
          });
        },
        child: const TutorialItemContent(
          title: 'Ejemplo de notificación',
          content: '',
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
          pageIndex: 2,
          child: const TutorialItemContent(
            title: 'Accesso rápido',
            content: 'Podrás encender y apagar el dispositivo desde el menú',
          ),
        ),
        TutorialItem(
          globalKey: keys['managerScreen:desconexionNotificacion']!,
          borderRadius: const Radius.circular(20),
          shapeFocus: ShapeFocus.roundedSquare,
          pageIndex: 2,
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
          pageIndex: 2,
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
    _notis =
        notificationMap['$pc/$sn'] ?? List<bool>.filled(parts.length, false);

    //printLog.i(_notis);

    tracking = devicesToTrack.contains(deviceName);

    showOptions = currentUserEmail == owner;

    if (deviceOwner) {
      if (vencimientoAdmSec < 10 && vencimientoAdmSec > 0) {
        showPaymentText(true, vencimientoAdmSec, navigatorKey.currentContext!);
      }

      if (vencimientoAT < 10 && vencimientoAT > 0) {
        showPaymentText(false, vencimientoAT, navigatorKey.currentContext!);
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

  Future<bool> controlOut(bool value, int index) async {
    // Verificar permisos horarios para administradores secundarios
    bool hasPermission = await checkAdminTimePermission(deviceName);
    if (!hasPermission) {
      return false; // No ejecutar si no tiene permisos
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

    // Registrar uso si es administrador secundario
    String action = value ? 'Encendió salida $index' : 'Apagó salida $index';
    await registerAdminUsage(deviceName, action);

    return true;
  }

  void updateWifiValues(List<int> data) {
    var fun = utf8.decode(data); //Wifi status | wifi ssid | ble status(users)
    fun = fun.replaceAll(RegExp(r'[^\x20-\x7E]'), '');
    //printLog.i(fun);
    var parts = fun.split(':');
    final regex = RegExp(r'\((\d+)\)');
    final match = regex.firstMatch(parts[2]);
    int users = int.parse(match!.group(1).toString());
    //printLog.i('Hay $users conectados');
    userConnected = users > 1;

    final wifiNotifier = ref.read(wifiProvider.notifier);

    if (parts[0] == 'WCS_CONNECTED') {
      atemp = false;
      nameOfWifi = parts[1];
      isWifiConnected = true;
      // printlog.i('sis $isWifiConnected');
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
      // printlog.i('non $isWifiConnected');

      nameOfWifi = '';
      wifiNotifier.updateStatus(
          'DESCONECTADO', Colors.red, HugeIcons.strokeRoundedWifiOff02);

      if (atemp) {
        setState(() {
          wifiNotifier.updateStatus(
              'DESCONECTADO', Colors.red, HugeIcons.strokeRoundedAlert02);
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
    //printLog.i('Se subscribio a wifi');
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
    //printLog.i('Valores: $parts');
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

        // printLog.i(
        //     'En la posición $i el modo es ${tipo[i]} y su estado es ${estado[i]}');
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

        //printLog.i('¿La entrada $j esta en alerta?: ${alertIO[j]}');
      }

      setState(() {});
    }

    for (int i = 0; i < parts.length; i++) {
      if (tipo[i] == 'Salida') {
        String dv = '${deviceName}_$i';
        addDeviceToCore(dv);
      }
    }
  }

  void subToIO() async {
    await bluetoothManager.ioUuid.setNotifyValue(true);
    //printLog.i('Subscrito a IO');

    var ioSub = bluetoothManager.ioUuid.onValueReceived.listen((event) {
      //printLog.i('Cambio en IO');
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

//!Visual
  @override
  Widget build(BuildContext context) {
    final TextStyle poppinsStyle = GoogleFonts.poppins();
    final wifiState = ref.watch(wifiProvider);

    bool isRegularUser = !deviceOwner && !secondaryAdmin;

    if (!canUseDevice) {
      return const NotAllowedScreen();
    }

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
          key: keys['domotica:activarNoti']!,
          height: MediaQuery.of(context).size.height * 0.8,
          child: Padding(
            key: keys['domotica:ejemploAlerta']!,
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
                    color: color1,
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
                                    child: AutoScrollingText(
                                      velocity: 50,
                                      text: nicknamesMap[
                                              '${deviceName}_$index'] ??
                                          '${tipo[index]} $index',
                                      style: GoogleFonts.poppins(
                                        color: color0,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      HugeIcons.strokeRoundedPen01,
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
                                        ? HugeIcons.strokeRoundedAlertCircle
                                        : HugeIcons.strokeRoundedAlertCircle,
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
                                        notificationMap['$pc/$sn'] = _notis;
                                        saveNotificationMap(notificationMap);
                                      },
                                      icon: _notis[index]
                                          ? const Icon(
                                              HugeIcons
                                                  .strokeRoundedNotificationOff01,
                                              color: color4,
                                            )
                                          : const Icon(
                                              HugeIcons
                                                  .strokeRoundedNotification01,
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
                                  isOn
                                      ? HugeIcons.strokeRoundedCheckmarkCircle02
                                      : HugeIcons.strokeRoundedCancelCircle,
                                  color: isOn ? Colors.green : Colors.red,
                                  size: 40,
                                ),
                                GestureDetector(
                                  onTap: () async {
                                    if (isPresenceControlled) {
                                      return;
                                    }

                                    bool success =
                                        await controlOut(!isOn, index);
                                    if (success) {
                                      setState(() {
                                        estado[index] = !isOn ? '1' : '0';
                                      });
                                    }
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
                                              : color4,
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
                            color: color0,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Center(
                            child: Text(
                              'Desactiva control por presencia para utilizar esta función',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: color1,
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

      //*- Página 2: Modo de Pines -*\\
      GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
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
                      color: color1,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  Card(
                    color: color1,
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
                                ? const ImageIcon(
                                    AssetImage(CaldenIcons.unLock),
                                    color: color0,
                                    size: 40,
                                    key: ValueKey('open_lock'),
                                  )
                                : const Icon(
                                    HugeIcons.strokeRoundedSquareLock01,
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
                            obscureText: !_showPassword,
                            onChanged: (value) {
                              setState(() {
                                isPasswordCorrect = value == '53494d45';
                              });
                            },
                            decoration: InputDecoration(
                              prefixIcon: Icon(
                                HugeIcons.strokeRoundedKey01,
                                color: color0.withValues(alpha: 0.7),
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _showPassword
                                      ? HugeIcons.strokeRoundedView
                                      : HugeIcons.strokeRoundedViewOff,
                                  color: color0.withValues(alpha: 0.7),
                                ),
                                onPressed: () {
                                  setState(() {
                                    _showPassword = !_showPassword;
                                  });
                                },
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
                          printLog.d(isChangeModeVisible, color: 'naranja');
                        });
                      },
                      backgroundColor: color1,
                      foregroundColor: color0,
                      icon: const Icon(HugeIcons.strokeRoundedSettings02,
                          color: color0),
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
                          Card(
                            color: color1,
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
                                  if (tipo[i] == 'Entrada' ||
                                      Versioner.isPosterior(
                                          hardwareVersion, '240423A')) ...{
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
                                                          '$pc[14]($i#0)';
                                                      // printLog.i(data);
                                                      bluetoothManager.toolsUuid
                                                          .write(
                                                              data.codeUnits);
                                                      common[i] = '0';
                                                    });
                                                  },
                                                  child: Container(
                                                    decoration: BoxDecoration(
                                                      color: common[i] == '0'
                                                          ? color0
                                                          : Colors.transparent,
                                                      borderRadius:
                                                          const BorderRadius
                                                              .only(
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
                                                          color:
                                                              common[i] == '0'
                                                                  ? color1
                                                                  : color0,
                                                        ),
                                                        overflow: TextOverflow
                                                            .ellipsis,
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
                                                    setState(() {
                                                      String data =
                                                          '$pc[14]($i#1)';
                                                      // printLog.i(data);
                                                      bluetoothManager.toolsUuid
                                                          .write(
                                                              data.codeUnits);
                                                      common[i] = '1';
                                                    });
                                                  },
                                                  child: Container(
                                                    decoration: BoxDecoration(
                                                      color: common[i] == '1'
                                                          ? color0
                                                          : Colors.transparent,
                                                      borderRadius:
                                                          const BorderRadius
                                                              .only(
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
                                                          color:
                                                              common[i] == '1'
                                                                  ? color1
                                                                  : color0,
                                                        ),
                                                        overflow: TextOverflow
                                                            .ellipsis,
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
                                  const SizedBox(height: 10),
                                  if (Versioner.isPrevious(
                                      hardwareVersion, '240423A')) ...{
                                    if (tipo[i] == 'Entrada') ...{
                                      const Divider(),
                                      const SizedBox(height: 10),
                                    },
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
                                          foregroundColor: color1,
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
                                              '$pc[13]($i#${tipo[i] == 'Entrada' ? '0' : '1'})';
                                          //printLog.i(fun);
                                          bluetoothManager.toolsUuid
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
                avoidKeyboard: true,
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
                const Icon(HugeIcons.strokeRoundedPen01,
                    size: 20, color: color0)
              ],
            ),
          ),
          leading: IconButton(
            key: keys['domotica:estado']!,
            icon: const Icon(HugeIcons.strokeRoundedArrowLeft02),
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
            globalDATA['$pc/$sn']?['cstate'] ?? false
                ? ImageIcon(
                    const AssetImage(CaldenIcons.cloud),
                    size: 35,
                    color: color0,
                    key: keys['domotica:servidor']!,
                  )
                : ImageIcon(
                    const AssetImage(CaldenIcons.cloudOff),
                    size: 25,
                    color: color0,
                    key: keys['domotica:servidor']!,
                  ),
            IconButton(
              key: keys['domotica:wifi']!,
              icon: wifiState.wifiIcon is String
                  ? ImageIcon(AssetImage(wifiState.wifiIcon),
                      color: color0, size: 24)
                  : Icon(wifiState.wifiIcon, color: color0, size: 24),
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
              NotificationListener<ScrollNotification>(
                onNotification: (scrollNotification) {
                  if (scrollNotification is UserScrollNotification) {
                    FocusScope.of(context).unfocus();
                  }
                  return false;
                },
                child: PageView(
                  controller: _pageController,
                  physics: _isAnimating || _isTutorialActive
                      ? const NeverScrollableScrollPhysics()
                      : const BouncingScrollPhysics(),
                  onPageChanged: onItemChanged,
                  children: pages,
                ),
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
                        Icon(HugeIcons.strokeRoundedHome11,
                            size: 30, color: color0),
                        Icon(HugeIcons.strokeRoundedShare01,
                            size: 30, color: color0),
                        Icon(HugeIcons.strokeRoundedSettings02,
                            size: 30, color: color0),
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
                          //  printLog.i('Tutorial is complete!');
                        },
                      );
                    }
                  });
                },
                backgroundColor: color4,
                shape: const CircleBorder(),
                child: const Icon(HugeIcons.strokeRoundedHelpCircle,
                    size: 30, color: color0),
              ),
            ),
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      ),
    );
  }
}
