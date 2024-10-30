import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../aws/dynamo/dynamo.dart';
import '../aws/dynamo/dynamo_certificates.dart';
import '../aws/mqtt/mqtt.dart';
import '../master.dart';
import '../stored_data.dart';

//TODO: Modifique y agregue la ventana que faltaba para relé

// VARIABLES \\
late bool tracking;
bool isNC = false;
bool isAgreeChecked = false;

// CLASES \\

class RelayPage extends StatefulWidget {
  const RelayPage({super.key});
  @override
  RelayPageState createState() => RelayPageState();
}

class RelayPageState extends State<RelayPage> {
  bool showSecondaryAdminFields = false;
  bool showAddAdminField = false;
  bool showSecondaryAdminList = false;
  bool showSmartResident = false;
  bool dOnOk = false;
  bool dOffOk = false;
  bool showOptions = false;
  bool _isNotificationActive = false;
  bool _showNotificationOptions = false;
  TextEditingController emailController = TextEditingController();
  int _selectedNotificationOption = 0;
  int _page = 0;
  final PageController _pageController = PageController(initialPage: 0);
  final TextEditingController tenantController = TextEditingController();
  final TextEditingController tenantDistanceOn = TextEditingController();

  @override
  void initState() {
    super.initState();

    tracking = devicesToTrack.contains(deviceName);
    nickname = nicknamesMap[deviceName] ?? deviceName;

    showOptions = currentUserEmail == owner;

    printLog('¿Encendido? $turnOn');
    printLog('¿Alquiler temporario? $activatedAT');
    printLog('¿Inquilino? $tenant');

    updateWifiValues(toolsValues);
    subscribeToWifiStatus();
    subscribeTrueStatus();
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

      await putSecondaryAdmins(service, command(deviceName),
          extractSerialNumber(deviceName), updatedAdmins);

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

      await putSecondaryAdmins(service, command(deviceName),
          extractSerialNumber(deviceName), updatedAdmins);

      setState(() {
        adminDevices.remove(email);
      });

      showToast('Administrador eliminado correctamente.');
    } catch (e) {
      printLog('Error al eliminar administrador secundario: $e');
      showToast('Error al eliminar el administrador. Inténtalo de nuevo.');
    }
  }

  bool isValidEmail(String email) {
    final RegExp emailRegex = RegExp(
      r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@"
      r"[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)*$",
    );
    return emailRegex.hasMatch(email);
  }

  void updateWifiValues(List<int> data) {
    var fun = utf8.decode(data); //Wifi status | wifi ssid | ble status(users)
    fun = fun.replaceAll(RegExp(r'[^\x20-\x7E]'), '');
    printLog(fun);
    var parts = fun.split(':');
    if (parts[0] == 'WCS_CONNECTED') {
      atemp = false;
      nameOfWifi = parts[1];
      isWifiConnected = true;
      printLog('sis $isWifiConnected');
      setState(() {
        textState = 'CONECTADO';
        statusColor = Colors.green;
        wifiIcon = Icons.wifi;
        errorMessage = '';
        errorSintax = '';
        werror = false;
      });
    } else if (parts[0] == 'WCS_DISCONNECTED') {
      isWifiConnected = false;
      printLog('non $isWifiConnected');

      nameOfWifi = '';

      setState(() {
        textState = 'DESCONECTADO';
        statusColor = Colors.red;
        wifiIcon = Icons.wifi_off;
      });

      if (atemp) {
        setState(() {
          wifiIcon = Icons.warning_amber_rounded;
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
    printLog('Se subscribió a wifi');
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
        turnOn = parts[0] == '1';
      });
    });

    myDevice.device.cancelWhenDisconnected(trueStatusSub);
  }

  void turnDeviceOn(bool on) async {
    int fun = on ? 1 : 0;
    String data = '${command(deviceName)}[11]($fun)';
    myDevice.toolsUuid.write(data.codeUnits);
    globalDATA['${command(deviceName)}/${extractSerialNumber(deviceName)}']![
        'w_status'] = on;
    saveGlobalData(globalDATA);
    try {
      String topic =
          'devices_rx/${command(deviceName)}/${extractSerialNumber(deviceName)}';
      String topic2 =
          'devices_tx/${command(deviceName)}/${extractSerialNumber(deviceName)}';
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
        String data = '${command(deviceName)}[5](1)';
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
      String data = '${command(deviceName)}[5](0)';
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

        //TODO: cambie el showdialog que habia por un showAlertDialog generico
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

    // Determinamos el rol del usuario actual
    bool isOwner = currentUserEmail == owner;
    bool isSecondaryAdmin = adminDevices.contains(currentUserEmail);
    bool isRegularUser = !isOwner && !isSecondaryAdmin;

    //TODO: pantalla de usuario conectado

    // si hay un usuario conectado al equipo no lo deje ingresar
    if (userConnected) {
      return const DeviceInUseScreen();
    }

    // Condición para mostrar la pantalla de acceso restringido
    if (isRegularUser && owner != '') {
      return const AccessDeniedScreen();
    }

    final List<Widget> pages = [
      //TODO: en la pagina uno, los colores e iconos del boton cambian dependiendo si es NC o NA
      //*- Página 1: Estado del Dispositivo -*\\
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
                        showToast(
                            'No tienes permiso para realizar esta acción');
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: turnOn
                            ? (isNC ? Colors.greenAccent : Colors.redAccent)
                            : (isNC ? Colors.redAccent : Colors.greenAccent),
                        shape: BoxShape.circle,
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 10,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                      child: AnimatedCrossFade(
                        firstChild: Icon(
                          isNC ? Icons.lock_open : Icons.lock,
                          size: 80,
                          color: Colors.white,
                        ),
                        secondChild: Icon(
                          isNC ? Icons.lock : Icons.lock_open,
                          size: 80,
                          color: Colors.white,
                        ),
                        crossFadeState: turnOn
                            ? CrossFadeState.showFirst
                            : CrossFadeState.showSecond,
                        duration: const Duration(milliseconds: 500),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    isNC
                        ? (turnOn ? 'ABIERTO' : 'CERRADO')
                        : (turnOn ? 'CERRADO' : 'ABIERTO'),
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: color3,
                    ),
                  ),
                  const SizedBox(height: 50),
                  if (isOwner || owner == '')
                    // Solo el propietario ve la tarjeta de NA y NC
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: 5,
                      color: color3,
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'Puedes cambiar entre Normal Abierto (NO) y Normal Cerrado (NC). Selecciona una opción:',
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
                                borderRadius: BorderRadius.circular(30.0),
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
                                          isNC = false;
                                        });
                                        saveNC(
                                          service,
                                          command(deviceName),
                                          extractSerialNumber(deviceName),
                                          false,
                                        );
                                      },
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: !isNC
                                              ? color0
                                              : Colors.transparent,
                                          borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(28),
                                            bottomLeft: Radius.circular(28),
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            'Normal Abierto',
                                            style: GoogleFonts.poppins(
                                              fontSize: 14,
                                              color: !isNC ? color3 : color0,
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
                                        setState(() {
                                          isNC = true;
                                        });
                                        saveNC(
                                          service,
                                          command(deviceName),
                                          extractSerialNumber(deviceName),
                                          true,
                                        );
                                      },
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: isNC
                                              ? color0
                                              : Colors.transparent,
                                          borderRadius: const BorderRadius.only(
                                            topRight: Radius.circular(28),
                                            bottomRight: Radius.circular(28),
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            'Normal Cerrado',
                                            style: GoogleFonts.poppins(
                                              fontSize: 14,
                                              color: isNC ? color3 : color0,
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
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (isRegularUser && owner != '')
            Container(
              color: Colors.black.withOpacity(0.7),
              child: const Center(
                child: Text(
                  'No tienes acceso a esta función',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              ),
            ),
        ],
      ),

      //*- Página 2: Trackeo Bluetooth -*\\
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
                    'Trackeo Bluetooth',
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: color3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  GestureDetector(
                    onTap: () async {
                      if (isOwner || owner == '') {
                        if (isAgreeChecked) {
                          setState(() {
                            tracking = !tracking;
                          });

                          if (tracking) {
                            devicesToTrack.add(deviceName);
                            saveDeviceListToTrack(devicesToTrack);

                            SharedPreferences prefs =
                                await SharedPreferences.getInstance();
                            bool hasInitService =
                                prefs.getBool('hasInitService') ?? false;

                            if (!hasInitService) {
                              await initializeService();
                              await prefs.setBool('hasInitService', true);
                            }

                            await Future.delayed(const Duration(seconds: 30));

                            final backService = FlutterBackgroundService();
                            backService.invoke('trackLocation');
                          } else {
                            devicesToTrack.remove(deviceName);
                            saveDeviceListToTrack(devicesToTrack);
                          }
                        } else {
                          showToast('Debes aceptar el uso de trackeo');
                        }
                      } else {
                        showToast(
                            'No tienes permiso para realizar esta acción');
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: tracking ? Colors.greenAccent : Colors.redAccent,
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
                        HugeIcons.strokeRoundedRoute02,
                        size: 80,
                        color: tracking ? Colors.white : Colors.grey[300],
                      ),
                    ),
                  ),
                  const SizedBox(height: 100),
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 5,
                    color: color3,
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Habilitar esta función hará que la aplicación use más recursos de lo común, si a pesar de esto decides utilizarlo es bajo tu responsabilidad.',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              color: color0,
                            ),
                          ),
                          const SizedBox(height: 10),
                          CheckboxListTile(
                            title: Text(
                              'Sí, estoy de acuerdo',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                color: color0,
                              ),
                            ),
                            value: isAgreeChecked,
                            activeColor: color0,
                            onChanged: (bool? value) {
                              setState(() {
                                isAgreeChecked = value ?? false;
                                if (!isAgreeChecked && tracking) {
                                  tracking = false;
                                  devicesToTrack.remove(deviceName);
                                  saveDeviceListToTrack(devicesToTrack);
                                }
                              });
                            },
                            controlAffinity: ListTileControlAffinity.leading,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!isOwner && owner != '')
            Container(
              color: Colors.black.withOpacity(0.7),
              child: const Center(
                child: Text(
                  'No tienes acceso a esta función',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              ),
            ),
        ],
      ),

      //TODO: implemente la pantalla faltante para rele
      //*- Página 3 - Control por distancia -*\\
      Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
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
                  onTap: () {
                    if (isOwner || owner == '') {
                      verifyPermission().then((result) {
                        if (result == true) {
                          setState(() {
                            isTaskScheduled[deviceName] =
                                !(isTaskScheduled[deviceName] ?? false);
                          });
                          saveControlValue(isTaskScheduled);
                          controlTask(
                              isTaskScheduled[deviceName] ?? false, deviceName);
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
                                color: color3.withOpacity(0.9),
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
                                      SliderTheme(
                                        data: SliderTheme.of(context).copyWith(
                                          trackHeight: 20.0,
                                          thumbColor: color3,
                                          activeTrackColor: Colors.blueAccent,
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
                                              command(deviceName),
                                              extractSerialNumber(deviceName),
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
                                color: color3.withOpacity(0.9),
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
                                      SliderTheme(
                                        data: SliderTheme.of(context).copyWith(
                                          trackHeight: 20.0,
                                          thumbColor: color3,
                                          activeTrackColor: Colors.blueAccent,
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
                                              command(deviceName),
                                              extractSerialNumber(deviceName),
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
          if (!isOwner && owner != '')
            Container(
              color: Colors.black.withOpacity(0.7),
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
      SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 30.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
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
                onTap: () async {
                  if (isOwner) {
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
                                command(deviceName),
                                extractSerialNumber(deviceName),
                                '',
                              );
                              myDevice.device.disconnect();
                              Navigator.of(context).pop();
                              setState(() {
                                isOwner = false;
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
                        command(deviceName),
                        extractSerialNumber(deviceName),
                        currentUserEmail,
                      );
                      setState(() {
                        owner = currentUserEmail;
                        isOwner = true;
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
                    isOwner
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
                            //! Opciones adicionales existentes (isOwner)
                            if (isOwner) ...[
                              //! Opción 2 - Añadir administradores secundarios
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    showSecondaryAdminFields =
                                        !showSecondaryAdminFields;
                                  });
                                },
                                borderRadius: BorderRadius.circular(15),
                                child: Container(
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 10),
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
                                onTap: () {
                                  setState(() {
                                    showSecondaryAdminList =
                                        !showSecondaryAdminList;
                                  });
                                },
                                borderRadius: BorderRadius.circular(15),
                                child: Container(
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 10),
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
                                onTap: () {
                                  if (activatedAT) {
                                    saveATData(
                                      service,
                                      command(deviceName),
                                      extractSerialNumber(deviceName),
                                      false,
                                      '',
                                      distOnValue.round().toString(),
                                      distOffValue.round().toString(),
                                    );
                                    setState(() {});
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
                                                  '¡Hola! Me comunico porque busco habilitar la opción de "Habitante inteligente" en mi equipo $deviceName\nCódigo de Producto: ${command(deviceName)}\nNúmero de Serie: ${extractSerialNumber(deviceName)}\nDueño actual del equipo: $owner';
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
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 10),
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
                                          fontSize: 15,
                                          color: color0,
                                        ),
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
                                                    color: color0,
                                                  ),
                                                  decoration: InputDecoration(
                                                    labelText:
                                                        "Email del inquilino",
                                                    labelStyle:
                                                        GoogleFonts.poppins(
                                                      color: color0,
                                                    ),
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
                                                Text(
                                                  'Distancia de apagado (${distOffValue.round()} metros)',
                                                  style: GoogleFonts.poppins(
                                                    color: color0,
                                                  ),
                                                ),
                                                Slider(
                                                  value: distOffValue,
                                                  min: 100,
                                                  max: 300,
                                                  divisions: 200,
                                                  activeColor: color0,
                                                  inactiveColor:
                                                      color0.withOpacity(0.3),
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
                                                    color: color0,
                                                  ),
                                                ),
                                                Slider(
                                                  value: distOnValue,
                                                  min: 3000,
                                                  max: 5000,
                                                  divisions: 200,
                                                  activeColor: color0,
                                                  inactiveColor:
                                                      color0.withOpacity(0.3),
                                                  onChanged: (double value) {
                                                    setState(() {
                                                      distOnValue = value;
                                                      dOnOk = true;
                                                    });
                                                  },
                                                ),
                                                const SizedBox(height: 20),
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
                                                              command(
                                                                  deviceName),
                                                              extractSerialNumber(
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
                                                            setState(() {});
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
                                                            fontSize: 16,
                                                          ),
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
                                                            fontSize: 16,
                                                          ),
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

                              //TODO: Agrego opcion de notificacion
                              //! Opción 5 - activar notificación
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () async {
                                    if (_isNotificationActive) {
                                      showAlertDialog(
                                        context,
                                        true,
                                        Text(
                                          'Confirmar Desactivación',
                                          style: GoogleFonts.poppins(),
                                        ),
                                        Text(
                                          '¿Estás seguro de que deseas desactivar la notificación de desconexión?',
                                          style: GoogleFonts.poppins(),
                                        ),
                                        [
                                          TextButton(
                                            onPressed: () {
                                              Navigator.of(context).pop();
                                            },
                                            child: Text(
                                              'Cancelar',
                                              style: GoogleFonts.poppins(),
                                            ),
                                          ),
                                          TextButton(
                                            onPressed: () async {
                                              setState(() {
                                                _isNotificationActive = false;
                                                _showNotificationOptions =
                                                    false;
                                              });

                                              configNotiDsc.removeWhere(
                                                  (key, value) =>
                                                      key == deviceName);
                                              await saveconfigNotiDsc(
                                                  configNotiDsc);

                                              if (context.mounted) {
                                                Navigator.of(context).pop();
                                              }
                                            },
                                            child: Text(
                                              'Aceptar',
                                              style: GoogleFonts.poppins(),
                                            ),
                                          ),
                                        ],
                                      );
                                    } else {
                                      setState(() {
                                        _showNotificationOptions =
                                            !_showNotificationOptions;
                                      });
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    foregroundColor: color0,
                                    backgroundColor: color3,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 15, horizontal: 20),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _isNotificationActive
                                              ? 'Desactivar notificación de desconexión'
                                              : 'Activar notificación de desconexión',
                                          style: GoogleFonts.poppins(
                                            textStyle: const TextStyle(
                                              fontSize: 16,
                                              color: color0,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Icon(
                                        _showNotificationOptions
                                            ? Icons.arrow_drop_up
                                            : Icons.arrow_drop_down,
                                        color: color0,
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              const SizedBox(height: 30),

                              AnimatedSize(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                                child: _showNotificationOptions
                                    ? Card(
                                        color: color3,
                                        elevation: 6,
                                        margin: const EdgeInsets.symmetric(
                                            vertical: 10.0, horizontal: 20.0),
                                        child: Padding(
                                          padding: const EdgeInsets.all(20.0),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                'Selecciona cuándo deseas recibir una notificación en caso de que el dispositivo permanezca desconectado:',
                                                style: GoogleFonts.poppins(
                                                  textStyle: const TextStyle(
                                                    color: color0,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                              const SizedBox(height: 20),
                                              RadioListTile<int>(
                                                value: 0,
                                                groupValue:
                                                    _selectedNotificationOption,
                                                onChanged: (int? value) {
                                                  setState(() {
                                                    _selectedNotificationOption =
                                                        value!;
                                                  });
                                                },
                                                title: Text(
                                                  'Instantáneo',
                                                  style: GoogleFonts.poppins(
                                                    textStyle: const TextStyle(
                                                      color: color0,
                                                      fontSize: 18,
                                                    ),
                                                  ),
                                                ),
                                                activeColor: color0,
                                              ),
                                              RadioListTile<int>(
                                                value: 1,
                                                groupValue:
                                                    _selectedNotificationOption,
                                                onChanged: (int? value) {
                                                  setState(() {
                                                    _selectedNotificationOption =
                                                        value!;
                                                  });
                                                },
                                                title: Text(
                                                  'Si permanece 10 minutos desconectado',
                                                  style: GoogleFonts.poppins(
                                                    textStyle: const TextStyle(
                                                      color: color0,
                                                      fontSize: 18,
                                                    ),
                                                  ),
                                                ),
                                                activeColor: color0,
                                              ),
                                              RadioListTile<int>(
                                                value: 2,
                                                groupValue:
                                                    _selectedNotificationOption,
                                                onChanged: (int? value) {
                                                  setState(() {
                                                    _selectedNotificationOption =
                                                        value!;
                                                  });
                                                },
                                                title: Text(
                                                  'Si permanece 1 hora desconectado',
                                                  style: GoogleFonts.poppins(
                                                    textStyle: const TextStyle(
                                                      color: color0,
                                                      fontSize: 18,
                                                    ),
                                                  ),
                                                ),
                                                activeColor: color0,
                                              ),
                                              const SizedBox(height: 20),
                                              SizedBox(
                                                width: double.infinity,
                                                child: ElevatedButton(
                                                  onPressed: () async {
                                                    setState(() {
                                                      _isNotificationActive =
                                                          true;
                                                      _showNotificationOptions =
                                                          false;
                                                    });

                                                    configNotiDsc.addAll({
                                                      deviceName:
                                                          _selectedNotificationOption
                                                    });
                                                    await saveconfigNotiDsc(
                                                        configNotiDsc);

                                                    printLog(configNotiDsc);

                                                    String displayTitle =
                                                        'Notificación Activada';
                                                    String displayMessage =
                                                        'Has activado la notificación de desconexión con la opción seleccionada.';
                                                    showNotification(
                                                        displayTitle,
                                                        displayMessage,
                                                        'noti');
                                                  },
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                    foregroundColor: color3,
                                                    backgroundColor: color0,
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        vertical: 12),
                                                    shape:
                                                        RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              30),
                                                    ),
                                                  ),
                                                  child: Text(
                                                    'Aceptar',
                                                    style: GoogleFonts.poppins(
                                                      textStyle:
                                                          const TextStyle(
                                                        fontSize: 18,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      )
                                    : const SizedBox.shrink(),
                              ),
                            ],
                          ],
                        )
                      : const SizedBox(),
                ),
              ),
              const SizedBox(height: 30),

              //TODO: agregue opcion para cambiar imagen
              SizedBox(
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
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text(
                    'Cambiar imagen del dispositivo',
                    style: TextStyle(
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
            ],
          ),
        ),
      ),
    ];

    //TODO: al desconectar sin tocar la flecha sigue diciendo desconectando y no se cierra la app
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, A) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            return AlertDialog(
              backgroundColor: const Color(0xFF252223),
              content: Row(
                children: [
                  Image.asset('assets/dragon.gif', width: 100, height: 100),
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
                Text(
                  nickname,
                  style: poppinsStyle.copyWith(color: color0),
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
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) {
                  return AlertDialog(
                    backgroundColor: const Color(0xFF252223),
                    content: Row(
                      children: [
                        Image.asset('assets/dragon.gif',
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
              icon: Icon(wifiIcon, color: color0),
              onPressed: () {
                wifiText(context);
              },
            ),
          ],
        ),
        backgroundColor: color1,
        resizeToAvoidBottomInset: false,
        body: PageView(
          controller: _pageController,
          onPageChanged: (index) {
            setState(() {
              _page = index;
            });
          },
          children: pages,
        ),
        bottomNavigationBar: CurvedNavigationBar(
          index: _page,
          height: 75.0,
          items: const <Widget>[
            Icon(Icons.home, size: 30, color: color0),
            Icon(Icons.bluetooth, size: 30, color: color0),
            Icon(Icons.location_on, size: 30, color: color0),
            Icon(Icons.settings, size: 30, color: color0),
          ],
          color: color3,
          buttonBackgroundColor: color3,
          backgroundColor: Colors.transparent,
          animationCurve: Curves.easeInOut,
          animationDuration: const Duration(milliseconds: 600),
          onTap: (index) {
            setState(() {
              _page = index;
              _pageController.animateToPage(index,
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeInOut);
            });
          },
          letIndexChange: (index) => true,
        ),
      ),
    );
  }
}
