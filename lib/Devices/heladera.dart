import 'dart:async';
import 'dart:convert';
import 'package:caldensmart/master.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caldensmart/widget/widget_handler.dart';
import '../Global/manager_screen.dart';
import '../aws/dynamo/dynamo.dart';
import '../aws/mqtt/mqtt.dart';
import '../Global/stored_data.dart';
import 'package:caldensmart/logger.dart';

// CLASES \\

class HeladeraPage extends ConsumerStatefulWidget {
  const HeladeraPage({super.key});

  @override
  HeladeraPageState createState() => HeladeraPageState();
}

class HeladeraPageState extends ConsumerState<HeladeraPage> {
  var parts2 = utf8.decode(varsValues).split(':');

  final String pc = DeviceManager.getProductCode(deviceName);
  final String sn = DeviceManager.extractSerialNumber(deviceName);

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

  String measure = 'KW/h';
  IconData powerIconOn = HugeIcons.strokeRoundedSnow;

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
        globalKey: keys['heladera:estado']!,
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
        globalKey: keys['heladera:titulo']!,
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
        globalKey: keys['heladera:wifi']!,
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
        globalKey: keys['heladera:servidor']!,
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
        globalKey: keys['heladera:boton']!,
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
        globalKey: keys['heladera:temperatura']!,
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
          globalKey: keys['heladera:corte']!,
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
      TutorialItem(
        globalKey: keys['heladera:controlDistancia']!,
        shapeFocus: ShapeFocus.roundedSquare,
        borderRadius: const Radius.circular(30),
        pageIndex: 2,
        focusMargin: 15.0,
        child: const TutorialItemContent(
          title: 'Control por distancia',
          content:
              'Podrás ajustar la distancia de encendido y apagado de tu dispositivo',
        ),
      ),
      TutorialItem(
        globalKey: keys['heladera:controlBoton']!,
        borderRadius: const Radius.circular(10),
        shapeFocus: ShapeFocus.oval,
        pageIndex: 2,
        focusMargin: 20.0,
        child: const TutorialItemContent(
          title: 'Botón de encendido',
          content: 'Podrás activar esta función y configurar la distancia',
        ),
      ),
      if (!tenant) ...{
        TutorialItem(
          globalKey: keys['heladera:consumo']!,
          shapeFocus: ShapeFocus.roundedSquare,
          borderRadius: const Radius.circular(30),
          contentPosition: ContentPosition.below,
          focusMargin: 0.0,
          pageIndex: 3,
          child: const TutorialItemContent(
            title: 'Calculadora de consumo',
            content:
                'En esta pantalla puedes estimar el uso de tu equipo según tu tarifa',
          ),
        ),
        TutorialItem(
          globalKey: keys['heladera:valor']!,
          shapeFocus: ShapeFocus.roundedSquare,
          borderRadius: const Radius.circular(15.0),
          pageIndex: 3,
          child: const TutorialItemContent(
            title: 'Tarifa',
            content: 'Podrás ingresar el valor de tu tarifa',
          ),
        ),
      } else ...{
        TutorialItem(
          globalKey: keys['heladera:consumo']!,
          borderRadius: const Radius.circular(0),
          shapeFocus: ShapeFocus.oval,
          contentPosition: ContentPosition.below,
          pageIndex: 3,
          child: const TutorialItemContent(
            title: 'Inquilino',
            content:
                'Ciertas funciones estan bloqueadas y solo el dueño puede acceder',
          ),
        ),
      },
      if (valueConsuption == null && !tenant) ...{
        TutorialItem(
          globalKey: keys['heladera:consumoManual']!,
          shapeFocus: ShapeFocus.roundedSquare,
          borderRadius: const Radius.circular(15.0),
          pageIndex: 3,
          child: const TutorialItemContent(
            title: 'Tarifa',
            content: 'Podrás ingresar el valor de tu tarifa',
          ),
        ),
      },
      if (!tenant) ...{
        TutorialItem(
          globalKey: keys['heladera:calcular']!,
          shapeFocus: ShapeFocus.roundedSquare,
          borderRadius: const Radius.circular(15.0),
          pageIndex: 3,
          child: const TutorialItemContent(
            title: 'Calculo',
            content: 'Podrás ver el costo de consumo de tu equipo',
          ),
        ),
        TutorialItem(
          globalKey: keys['heladera:mes']!,
          shapeFocus: ShapeFocus.roundedSquare,
          borderRadius: const Radius.circular(15.0),
          pageIndex: 3,
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
        pageIndex: 4,
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
          pageIndex: 4,
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
          pageIndex: 4,
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
          pageIndex: 4,
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
          pageIndex: 4,
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
          pageIndex: 4,
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
          pageIndex: 4,
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
          pageIndex: 4,
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

    // printLog.i('Valor temp: $tempValue');
    // printLog.i('¿Encendido? $turnOn');
    // printLog.i('¿Alquiler temporario? $activatedAT');
    // printLog.i('¿Inquilino? $tenant');
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
    List<int> list = await bluetoothManager.varsUuid.read(timeout: 2);
    List<String> partes = utf8.decode(list).split(':');

    if (partes.length > 2) {
      tiempo = partes[3];
      //printLog.i('Tiempo: ${utf8.decode(list).split(':')}');
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

        // printLog.i('Estoy haciendo calculaciones místicas');

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

        // printLog.i('Calculaciones terminadas');

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
    // printLog.i(fun);
    var parts = fun.split(':');
    final regex = RegExp(r'\((\d+)\)');
    final match = regex.firstMatch(parts[2]);
    int users = int.parse(match!.group(1).toString());
    // printLog.i('Hay $users conectados');
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
    // printLog.i('Se subscribio a wifi');
    await bluetoothManager.toolsUuid.setNotifyValue(true);

    final wifiSub =
        bluetoothManager.toolsUuid.onValueReceived.listen((List<int> status) {
      //  printLog.i('Llegaron cositas wifi');
      updateWifiValues(status);
    });

    bluetoothManager.device.cancelWhenDisconnected(wifiSub);
  }

  void subscribeTrueStatus() async {
    // printLog.i('Me subscribo a vars');
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

    try {
      String topic = 'devices_rx/$pc/$sn';
      String topic2 = 'devices_tx/$pc/$sn';
      String message = jsonEncode({'w_status': on});
      sendMessagemqtt(topic, message);
      sendMessagemqtt(topic2, message);

      // Registrar uso si es administrador secundario
      await registerAdminUsage(
          deviceName, on ? 'Encendió heladera' : 'Apagó heladera');
    } catch (e, s) {
      printLog
          .e('Error al ${on ? 'encender heladera' : 'apagar heladera'} $e $s');
    }
  }

  void controlTask() async {
    if (distanceControlActive) {
      // Programar la tarea.
      try {
        showToast('Recuerda tener la ubicación encendida.');
        putDistanceControl(pc, sn, true);
        List<String> deviceControl =
            await getDevicesInDistanceControl(currentUserEmail);
        deviceControl.add(deviceName);
        putDevicesInDistanceControl(currentUserEmail, deviceControl);
        // printLog.i(
        //     'Hay ${deviceControl.length} equipos con el control x distancia');

        if (deviceControl.length == 1) {
          await initializeService();
          final backService = FlutterBackgroundService();
          await backService.startService();
          backService.invoke('distanceControl');
          // printLog.i('Servicio iniciado a las ${DateTime.now()}');
        }
      } catch (e) {
        showToast('Error al iniciar control por distancia.');
        printLog.e('Error al setear la ubicación $e');
      }
    } else {
      // Cancelar la tarea.
      showToast('Se cancelo el control por distancia');
      putDistanceControl(pc, sn, false);
      List<String> deviceControl =
          await getDevicesInDistanceControl(currentUserEmail);
      deviceControl.remove(deviceName);
      putDevicesInDistanceControl(currentUserEmail, deviceControl);
      // printLog.i(
      //     'Quedan ${deviceControl.length} equipos con el control x distancia');

      if (deviceControl.isEmpty) {
        // Verificar si hay widgets activos antes de detener el servicio
        await tryStopBackgroundService();
        backTimerDS?.cancel();
        // printLog.i('Servicio apagado');
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
          true,
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
                  printLog.e(e);
                  printLog.t(s);
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
      printLog.e('Error al habilitar la ubicación: $e');
      printLog.t(s);
      return false;
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
                  key: keys['heladera:estado']!,
                  'Estado de la heladera',
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: color1,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                GestureDetector(
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
                    key: keys['heladera:boton']!,
                    duration: const Duration(milliseconds: 500),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: turnOn
                          ? (trueStatus
                              ? Colors.lightBlueAccent.shade400
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
                            isHeating: trueStatus, icon: powerIconOn)
                        : const ImageIcon(AssetImage(CaldenIcons.snowOff),
                            size: 80, color: color0),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text.rich(
                      TextSpan(
                        text: turnOn
                            ? (trueStatus ? 'Enfriando' : 'Encendido')
                            : 'Apagado',
                        style: GoogleFonts.poppins(
                          color: turnOn
                              ? (trueStatus
                                  ? Colors.lightBlueAccent.shade400
                                  : Colors.green)
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
                  key: keys['heladera:temperatura']!,
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
                          HugeIcons.strokeRoundedThermometerCold,
                          size: MediaQuery.of(context).size.width * 0.5,
                          color: Color.lerp(
                            Colors.blueAccent,
                            Colors.lightBlueAccent,
                            (tempValue + 30) / 60,
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
                          key: keys['heladera:corte']!,
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
                                  height: (tempValue > -30
                                      ? (((tempValue + 30) / 60) * 350)
                                          .clamp(40, 350)
                                      : 40),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(40),
                                    gradient: const LinearGradient(
                                      colors: [
                                        Colors.blueAccent,
                                        Colors.lightBlueAccent,
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
                                      min: -30,
                                      max: 30,
                                      onChanged: (value) {
                                        setState(() {
                                          tempValue = value;
                                        });
                                      },
                                      onChangeEnd: (value) {
                                        // printLog.i('$value');
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
                      key: keys['heladera:controlDistancia']!,
                      'Control por distancia',
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: color1,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Activar control por distancia',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        color: color1,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 30),
                    GestureDetector(
                      onTap: () {
                        if (isOwner || owner == '') {
                          verifyPermission().then((result) {
                            if (result == true) {
                              setState(() {
                                distanceControlActive = !distanceControlActive;
                              });

                              controlTask();
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
                        key: keys['heladera:controlBoton']!,
                        duration: const Duration(milliseconds: 500),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: distanceControlActive
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
                            distanceControlActive
                                ? HugeIcons.strokeRoundedCheckmarkCircle02
                                : HugeIcons.strokeRoundedCancelCircle,
                            size: 80,
                            color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 10),
                    AnimatedOpacity(
                      opacity: distanceControlActive ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 500),
                      child: AnimatedSize(
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeInOut,
                        child: distanceControlActive
                            ? Column(
                                children: [
                                  Card(
                                    color: color1..withValues(alpha: 0.9),
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
                                              color: color0,
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
                                                  color: color0,
                                                ),
                                              ),
                                              const Text(
                                                ' Metros',
                                                style: TextStyle(
                                                  fontSize: 24,
                                                  color: color0,
                                                ),
                                              ),
                                            ],
                                          ),
                                          SliderTheme(
                                            data: SliderTheme.of(context)
                                                .copyWith(
                                              trackHeight: 20.0,
                                              thumbColor: color1,
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
                                                // printLog.i(
                                                //     'Valor enviado: ${value.round()}');
                                                putDistanceOff(
                                                  pc,
                                                  sn,
                                                  value.toString(),
                                                );
                                              },
                                              min: 100,
                                              max: 300,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 15),
                                  Card(
                                    color: color1..withValues(alpha: 0.9),
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
                                              color: color0,
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
                                                  color: color0,
                                                ),
                                              ),
                                              const Text(
                                                ' Metros',
                                                style: TextStyle(
                                                  fontSize: 24,
                                                  color: color0,
                                                ),
                                              ),
                                            ],
                                          ),
                                          SliderTheme(
                                            data: SliderTheme.of(context)
                                                .copyWith(
                                              trackHeight: 20.0,
                                              thumbColor: color1,
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
                                                // printLog.i(
                                                //     'Valor enviado: ${value.round()}');
                                                putDistanceOn(
                                                  pc,
                                                  sn,
                                                  value.toString(),
                                                );
                                              },
                                              min: 3000,
                                              max: 5000,
                                            ),
                                          ),
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

      //*- Página 4 - Nueva funcionalidad con ingreso de valores y cálculo -*\\
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
                  key: keys['heladera:consumo']!,
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
                  key: keys['heladera:valor']!,
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
                    key: keys['heladera:consumoManual']!,
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
                  key: keys['heladera:calcular']!,
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
                  key: keys['heladera:mes']!,
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

      //*- Página 5: Gestión del Equipo -*\\
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
            key: keys['heladera:titulo']!,
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
                  cursorColor: color0,
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
                const Icon(HugeIcons.strokeRoundedPen01,
                    size: 20, color: color0)
              ],
            ),
          ),
          leading: IconButton(
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
                    color: color0,
                    size: 35,
                    key: keys['heladera:servidor']!,
                  )
                : ImageIcon(
                    const AssetImage(CaldenIcons.cloudOff),
                    color: color0,
                    size: 25,
                    key: keys['heladera:servidor']!,
                  ),
            IconButton(
              key: keys['heladera:wifi']!,
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
                        Icon(HugeIcons.strokeRoundedHome11,
                            size: 30, color: color0),
                        ImageIcon(AssetImage(CaldenIcons.termometro),
                            size: 30, color: color0),
                        Icon(HugeIcons.strokeRoundedLocation06,
                            size: 30, color: color0),
                        Icon(HugeIcons.strokeRoundedCalculate,
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
                          // printLog.i('Tutorial is complete!');
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
