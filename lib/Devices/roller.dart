import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../Global/stored_data.dart';
import '../aws/dynamo/dynamo.dart';
import '../aws/dynamo/dynamo_certificates.dart';
import '../master.dart';

class RollerPage extends StatefulWidget {
  const RollerPage({super.key});
  @override
  RollerPageState createState() => RollerPageState();
}

class RollerPageState extends State<RollerPage> {
  int _selectedIndex = 0;
  int _selectedNotificationOption = 0;

  final TextEditingController tenantController = TextEditingController();
  final TextEditingController tenantDistanceOn = TextEditingController();
  final PageController _pageController = PageController(initialPage: 0);

  TextEditingController rLargeController = TextEditingController();
  TextEditingController workController = TextEditingController();
  TextEditingController motorSpeedUpController = TextEditingController();
  TextEditingController motorSpeedDownController = TextEditingController();
  TextEditingController contrapulseController = TextEditingController();
  TextEditingController emailController = TextEditingController();

  bool showOptions = false;
  bool _showNotificationOptions = false;
  bool showSecondaryAdminFields = false;
  bool showAddAdminField = false;
  bool showSecondaryAdminList = false;
  bool showSmartResident = false;
  bool dOnOk = false;
  bool dOffOk = false;

  @override
  void initState() {
    super.initState();

    nickname = nicknamesMap[deviceName] ?? deviceName;
    showOptions = currentUserEmail == owner;

    updateWifiValues(toolsValues);
    subscribeToWifiStatus();
    subToVars();
  }

  @override
  void dispose() {
    _pageController.dispose();
    tenantController.dispose();
    tenantDistanceOn.dispose();
    rLargeController.dispose();
    workController.dispose();
    motorSpeedUpController.dispose();
    motorSpeedDownController.dispose();
    contrapulseController.dispose();
    emailController.dispose();
    super.dispose();
  }

  // FUNCIONES \\

  void _onItemTapped(int index) {
    if ((index - _selectedIndex).abs() > 1) {
      _pageController.jumpToPage(index);
    } else {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    }
    setState(() {
      _selectedIndex = index;
    });
  }

  void updateWifiValues(List<int> data) {
    var fun =
        utf8.decode(data); //Wifi status | wifi ssid | ble status | nickname
    fun = fun.replaceAll(RegExp(r'[^\x20-\x7E]'), '');
    printLog(fun);
    var parts = fun.split(':');
    if (parts[0] == 'WCS_CONNECTED') {
      nameOfWifi = parts[1];
      isWifiConnected = true;
      printLog('sis $isWifiConnected');
      setState(() {
        textState = 'CONECTADO';
        statusColor = Colors.green;
        wifiIcon = Icons.wifi;
      });
    } else if (parts[0] == 'WCS_DISCONNECTED') {
      isWifiConnected = false;
      printLog('non $isWifiConnected');

      setState(() {
        textState = 'DESCONECTADO';
        statusColor = Colors.red;
        wifiIcon = Icons.wifi_off;
      });

      if (parts[0] == 'WCS_DISCONNECTED' && atemp == true) {
        //If comes from subscription, parts[1] = reason of error.
        setState(() {
          wifiIcon = Icons.warning_amber_rounded;
        });

        if (parts[1] == '202' || parts[1] == '15') {
          errorMessage = 'Contraseña incorrecta';
        } else if (parts[1] == '201') {
          errorMessage = 'La red especificada no existe';
        } else if (parts[1] == '1') {
          errorMessage = 'Error desconocido';
        } else {
          errorMessage = parts[1];
        }

        if (int.tryParse(parts[1]) != null) {
          errorSintax = getWifiErrorSintax(int.parse(parts[1]));
        }
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

  bool isValidEmail(String email) {
    final RegExp emailRegex = RegExp(
      r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@"
      r"[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)*$",
    );
    return emailRegex.hasMatch(email);
  }

  void subToVars() async {
    printLog('Me subscribo a vars');
    await myDevice.varsUuid.setNotifyValue(true);

    final varsSub =
        myDevice.varsUuid.onValueReceived.listen((List<int> status) {
      var parts = utf8.decode(status).split(':');
      // printLog(parts);
      if (context.mounted) {
        setState(() {
          actualPosition = int.parse(parts[0]);
          rollerMoving = parts[1] == '1';
        });
      }
    });

    myDevice.device.cancelWhenDisconnected(varsSub);
  }

  void setRange(int mm) {
    String data = '${DeviceManager.getProductCode(deviceName)}[7]($mm)';
    printLog(data);
    myDevice.toolsUuid.write(data.codeUnits);
  }

  void setDistance(int pc) {
    String data = '${DeviceManager.getProductCode(deviceName)}[7]($pc%)';
    printLog(data);
    myDevice.toolsUuid.write(data.codeUnits);
  }

  void setRollerConfig(int type) {
    String data = '${DeviceManager.getProductCode(deviceName)}[8]($type)';
    myDevice.toolsUuid.write(data.codeUnits);
  }

  void setMotorSpeed(String rpm) {
    String data = '${DeviceManager.getProductCode(deviceName)}[10]($rpm)';
    printLog(data);
    myDevice.toolsUuid.write(data.codeUnits);
  }

  void setMicroStep(String uStep) {
    String data = '${DeviceManager.getProductCode(deviceName)}[11]($uStep)';
    printLog(data);
    myDevice.toolsUuid.write(data.codeUnits);
  }

  void setMotorCurrent(bool run, String value) {
    String data =
        '${DeviceManager.getProductCode(deviceName)}[12](${run ? '1' : '0'}#$value)';
    printLog(data);
    myDevice.toolsUuid.write(data.codeUnits);
  }

  void setFreeWheeling(bool active) {
    String data =
        '${DeviceManager.getProductCode(deviceName)}[14](${active ? '1' : '0'})';
    printLog(data);
    myDevice.toolsUuid.write(data.codeUnits);
  }

  void setTPWMTHRS(String value) {
    String data = '${DeviceManager.getProductCode(deviceName)}[15]($value)';
    printLog(data);
    myDevice.toolsUuid.write(data.codeUnits);
  }

  void setTCOOLTHRS(String value) {
    String data = '${DeviceManager.getProductCode(deviceName)}[16]($value)';
    printLog(data);
    myDevice.toolsUuid.write(data.codeUnits);
  }

  void setSGTHRS(String value) {
    String data = '${DeviceManager.getProductCode(deviceName)}[17]($value)';
    printLog(data);
    myDevice.toolsUuid.write(data.codeUnits);
  }

//! VISUAL
  @override
  Widget build(BuildContext context) {
    final TextStyle poppinsStyle = GoogleFonts.poppins();

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
      //*- Página 1 cortina -*\\
      SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Estado de la cortina',
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: color3,
                ),
              ),
              const SizedBox(height: 20),

              //TODO Riel center
              CurtainAnimationRielCenter(
                position: actualPosition,
                onTapDown: (details) {
                  RenderBox box = context.findRenderObject() as RenderBox;
                  Offset localPosition =
                      box.globalToLocal(details.globalPosition);

                  double containerWidth =
                      MediaQuery.of(context).size.width * 0.8;
                  double centerX = containerWidth / 2;
                  double distanceFromCenter = (localPosition.dx - 50) - centerX;

                  double relativePosition =
                      1.0 - (distanceFromCenter.abs() / centerX);
                  int newPosition =
                      (relativePosition * 100).clamp(0, 100).round();

                  setState(() {
                    workingPosition = newPosition;
                    setDistance(newPosition);
                  });
                },
              ),

              //TODO riel de izquierda a derecha
              // CurtainAnimationRielLeft(
              //   position: actualPosition,
              //   onTapDown: (details) {
              //     RenderBox box = context.findRenderObject() as RenderBox;
              //     Offset localPosition =
              //         box.globalToLocal(details.globalPosition);
              //     double relativeWidth = (localPosition.dx - 50) /
              //         (MediaQuery.of(context).size.width * 0.8);
              //     int newPosition = (relativeWidth * 100).clamp(0, 100).round();

              //     setState(() {
              //       workingPosition = newPosition;
              //       setDistance(newPosition);
              //     });
              //   },
              // ),

              //TODO riel de derecha a izquierda
              //       CurtainAnimationRielRight(
              //   position: actualPosition,
              //   onTapDown: (details) {
              //     RenderBox box = context.findRenderObject() as RenderBox;
              //     Offset localPosition = box.globalToLocal(details.globalPosition);
              //     double relativeWidth = 1.0 - ((localPosition.dx - 50) / (MediaQuery.of(context).size.width * 0.8));
              //     int newPosition = (relativeWidth * 100).clamp(0, 100).round();

              //     setState(() {
              //       workingPosition = newPosition;
              //       setDistance(newPosition);
              //     });
              //   },
              // ),

              //TODO Roll
              // CurtainAnimation(
              //   position: actualPosition,
              //   onTapDown: (details) {
              //     RenderBox box = context.findRenderObject() as RenderBox;
              //     Offset localPosition =
              //         box.globalToLocal(details.globalPosition);
              //     double relativeHeight = (localPosition.dy - 200) / 250;
              //     int newPosition =
              //         (relativeHeight * 100).clamp(0, 100).round();

              //     setState(() {
              //       workingPosition = newPosition;
              //       setDistance(newPosition);
              //     });
              //   },
              // ),

              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: GestureDetector(
                      onLongPressStart: (LongPressStartDetails a) {
                        String data =
                            '${DeviceManager.getProductCode(deviceName)}[7](0%)';
                        myDevice.toolsUuid.write(data.codeUnits);
                        setState(() {
                          workingPosition = 0;
                        });
                        printLog(data);
                      },
                      onLongPressEnd: (LongPressEndDetails a) {
                        String data =
                            '${DeviceManager.getProductCode(deviceName)}[7]($actualPosition%)';
                        myDevice.toolsUuid.write(data.codeUnits);
                        setState(() {
                          workingPosition = actualPosition;
                        });
                        printLog(data);
                      },
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {},
                          borderRadius: BorderRadius.circular(30.0),
                          splashColor: Colors.white.withValues(alpha: 0.2),
                          child: Container(
                            decoration: BoxDecoration(
                              color: color3,
                              borderRadius: BorderRadius.circular(30.0),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black26,
                                  offset: Offset(0, 4),
                                  blurRadius: 5.0,
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 15.0),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.arrow_upward, color: color0),
                                SizedBox(width: 8),
                                Text(
                                  'Subir',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: color0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: GestureDetector(
                      onLongPressStart: (LongPressStartDetails a) {
                        String data =
                            '${DeviceManager.getProductCode(deviceName)}[7](100%)';
                        myDevice.toolsUuid.write(data.codeUnits);
                        setState(() {
                          workingPosition = 100;
                        });
                        printLog(data);
                      },
                      onLongPressEnd: (LongPressEndDetails a) {
                        String data =
                            '${DeviceManager.getProductCode(deviceName)}[7]($actualPosition%)';
                        myDevice.toolsUuid.write(data.codeUnits);
                        setState(() {
                          workingPosition = actualPosition;
                        });
                        printLog(data);
                      },
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {},
                          borderRadius: BorderRadius.circular(30.0),
                          splashColor: Colors.white.withValues(alpha: 0.2),
                          child: Container(
                            decoration: BoxDecoration(
                              color: color3,
                              borderRadius: BorderRadius.circular(30.0),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black26,
                                  offset: Offset(0, 4),
                                  blurRadius: 5.0,
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 15.0),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.arrow_downward, color: color0),
                                SizedBox(width: 8),
                                Text(
                                  'Bajar',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: color0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),

      //*- Página 2: Configuración de parametros-*\\
      SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15.0),
                ),
                color: color3,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Largo del Roller',
                            style: TextStyle(
                              fontSize: 18.0,
                              color: color0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text(
                                rollerlength,
                                style: const TextStyle(
                                  fontSize: 28.0,
                                  color: color0,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 5),
                              const Text(
                                'mm',
                                style: TextStyle(
                                  fontSize: 16.0,
                                  color: color0,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      ElevatedButton(
                        onPressed: () {
                          showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  backgroundColor: color3,
                                  title: const Text('Modificar largo (mm)',
                                      style: TextStyle(color: color0)),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      TextField(
                                        controller: rLargeController,
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                            label: Text(
                                          'Ingresar tamaño:',
                                          style: TextStyle(
                                              fontWeight: FontWeight.normal,
                                              color: color0),
                                        )),
                                        onSubmitted: (value) {
                                          int? valor = int.tryParse(
                                              rLargeController.text);
                                          if (valor != null) {
                                            setRange(valor);
                                            setState(() {
                                              rollerlength = value;
                                            });
                                          } else {
                                            showToast('Valor no permitido');
                                          }
                                          rLargeController.clear();
                                          navigatorKey.currentState?.pop();
                                        },
                                      ),
                                    ],
                                  ),
                                  actions: [
                                    TextButton(
                                        onPressed: () {
                                          int? valor = int.tryParse(
                                              rLargeController.text);
                                          if (valor != null) {
                                            setRange(valor);
                                            setState(() {
                                              rollerlength =
                                                  rLargeController.text;
                                            });
                                          } else {
                                            showToast('Valor no permitido');
                                          }
                                          rLargeController.clear();
                                          navigatorKey.currentState?.pop();
                                        },
                                        child: const Text(
                                          'Modificar',
                                          style: TextStyle(color: color0),
                                        ))
                                  ],
                                );
                              });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: color6,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: const Text('Modificar',
                            style: TextStyle(color: color0)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Polaridad del Roller Section
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15.0),
                ),
                color: color3,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Polaridad del Roller',
                            style: TextStyle(
                              fontSize: 18.0,
                              color: color0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            rollerPolarity,
                            style: const TextStyle(
                              fontSize: 28.0,
                              color: color0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton(
                        onPressed: () {
                          setRollerConfig(1);
                          rollerPolarity == '0'
                              ? rollerPolarity = '1'
                              : rollerPolarity = '0';
                          context.mounted ? setState(() {}) : null;
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: color6,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: const Text('Invertir',
                            style: TextStyle(color: color0)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Velocidad del Motor Section
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15.0),
                ),
                color: color3,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Text(
                        'Velocidad del Motor',
                        style: TextStyle(
                          fontSize: 18.0,
                          color: color0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton(
                            onPressed: () {
                              //TODO Configurar velocidad
                              rollerRPM = '100';
                              setMotorSpeed('100');
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: const Text('Bajo',
                                style: TextStyle(color: color0)),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            onPressed: () {
                              //TODO Configurar velocidad
                              rollerRPM = '100';
                              setMotorSpeed('100');
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: const Text('Medio',
                                style: TextStyle(color: color0)),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            onPressed: () {
                              //TODO Configurar velocidad
                              rollerRPM = '100';
                              setMotorSpeed('100');
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: color5,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: const Text('Alto',
                                style: TextStyle(color: color0)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Configuración del Roller Section
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15.0),
                ),
                color: color3,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          setRollerConfig(0);
                          setState(() {
                            workingPosition = 0;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: color6,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: const Text(
                          'Guardar inicio',
                          style: TextStyle(fontSize: 16, color: color0),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: () {
                          //TODO Guardar fin logica
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: color6,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: const Text(
                          'Guardar fin',
                          style: TextStyle(fontSize: 16, color: color0),
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

      //*- Página 3: Gestión del Equipo -*\\
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
                              myDevice.device.disconnect();
                              Navigator.of(context).pop();
                              setState(() {
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
                            //! Opciones adicionales existentes (isOwner)
                            if (deviceOwner) ...[
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
                              //! Opción 5 - activar notificación
                              InkWell(
                                onTap: () async {
                                  if (discNotfActivated) {
                                    showAlertDialog(
                                      context,
                                      true,
                                      Text(
                                        'Confirmar Desactivación',
                                        style:
                                            GoogleFonts.poppins(color: color0),
                                      ),
                                      Text(
                                        '¿Estás seguro de que deseas desactivar la notificación de desconexión?',
                                        style:
                                            GoogleFonts.poppins(color: color0),
                                      ),
                                      [
                                        TextButton(
                                          onPressed: () {
                                            Navigator.of(context).pop();
                                          },
                                          child: Text(
                                            'Cancelar',
                                            style: GoogleFonts.poppins(
                                                color: color0),
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
                                            style: GoogleFonts.poppins(
                                                color: color0),
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
                                        discNotfActivated
                                            ? 'Desactivar notificación\nde desconexión'
                                            : 'Activar notificación\nde desconexión',
                                        style: GoogleFonts.poppins(
                                            fontSize: 15, color: color0),
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
                                          borderRadius:
                                              BorderRadius.circular(15),
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
                                              groupValue:
                                                  _selectedNotificationOption,
                                              onChanged: (int? value) {
                                                setState(() {
                                                  _selectedNotificationOption =
                                                      value!;
                                                });
                                              },
                                              activeColor: color1,
                                              title: Text(
                                                'Instantáneo',
                                                style: GoogleFonts.poppins(
                                                    color: color0),
                                              ),
                                            ),
                                            RadioListTile<int>(
                                              value: 10,
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
                                                    color: color0),
                                              ),
                                            ),
                                            RadioListTile<int>(
                                              value: 60,
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
                                                    color: color0),
                                              ),
                                            ),
                                            const SizedBox(height: 20),
                                            ElevatedButton(
                                              onPressed: () async {
                                                setState(() {
                                                  discNotfActivated = true;
                                                  _showNotificationOptions =
                                                      false;
                                                });

                                                configNotiDsc[deviceName] =
                                                    _selectedNotificationOption;
                                                await saveconfigNotiDsc(
                                                    configNotiDsc);

                                                showNotification(
                                                  'Notificación Activada',
                                                  'Has activado la notificación de desconexión con la opción seleccionada.',
                                                  'noti',
                                                );
                                              },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: color0,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 15),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(15),
                                                ),
                                              ),
                                              child: Text(
                                                'Aceptar',
                                                style: GoogleFonts.poppins(
                                                    color: color3,
                                                    fontSize: 16),
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : const SizedBox.shrink(),
                              ),
                              const SizedBox(height: 20),
                            ],
                          ],
                        )
                      : const SizedBox(),
                ),
              ),
              const SizedBox(height: 30),

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
                  child: ScrollingText(
                    text: nickname,
                    style: poppinsStyle.copyWith(
                      color: color0,
                    ),
                  ),
                ),
                const SizedBox(width: 3),
                const Icon(
                  Icons.edit,
                  size: 20,
                  color: color0,
                )
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
              icon: Icon(wifiIcon, color: color0),
              onPressed: () {
                wifiText(context);
              },
            ),
          ],
        ),
        backgroundColor: color1,
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            PageView(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
              children: pages,
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: CurvedNavigationBar(
                index: _selectedIndex,
                height: 75.0,
                items: const <Widget>[
                  Icon(Icons.home, size: 30, color: color0),
                  Icon(Icons.bluetooth, size: 30, color: color0),
                  Icon(Icons.settings, size: 30, color: color0),
                ],
                color: color3,
                buttonBackgroundColor: color3,
                backgroundColor: Colors.transparent,
                animationCurve: Curves.easeInOut,
                animationDuration: const Duration(milliseconds: 600),
                onTap: (index) {
                  _onItemTapped(index);
                },
                letIndexChange: (index) => true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

//*- Diseño de la cortina Roller-*\\
class CurtainAnimation extends StatelessWidget {
  final int position;
  final Function(TapDownDetails) onTapDown;

  const CurtainAnimation({
    super.key,
    required this.position,
    required this.onTapDown,
  });

  @override
  Widget build(BuildContext context) {
    double curtainHeight = (position / 100) * 250;

    return GestureDetector(
      onTapDown: onTapDown,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: 300,
        decoration: const BoxDecoration(
          color: Colors.transparent,
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 320,
              child: Image.asset(
                'assets/misc/parteSuperior.png',
                fit: BoxFit.cover,
              ),
            ),
            Positioned(
              top: 19,
              left: 20,
              right: 20,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOut,
                height: curtainHeight,
                child: Image.asset(
                  'assets/misc/persiana.jpg',
                  fit: BoxFit.cover,
                  width: double.infinity,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
//*- Diseño de la cortina Roller-*\\

//*- Diseño de la cortina Riel Left -*\\
class CurtainAnimationRielLeft extends StatelessWidget {
  final int position;
  final Function(TapDownDetails) onTapDown;

  const CurtainAnimationRielLeft({
    super.key,
    required this.position,
    required this.onTapDown,
  });

  @override
  Widget build(BuildContext context) {
    double curtainWidth =
        (position / 100) * MediaQuery.of(context).size.width * 0.8;

    return GestureDetector(
      onTapDown: onTapDown,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: 300,
        decoration: const BoxDecoration(
          color: Colors.transparent,
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.centerLeft,
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 30,
              child: Image.asset(
                'assets/misc/barrielRiel.png',
                fit: BoxFit.cover,
              ),
            ),
            Positioned(
              top: 13,
              left: 10,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOut,
                width: curtainWidth,
                height: 270,
                child: Image.asset(
                  'assets/misc/cortinaRiel.jpg',
                  fit: BoxFit.cover,
                  height: double.infinity,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
//*- Diseño de la cortina Riel Left -*\\

//*- Diseño de la cortina Riel Right -*\\
class CurtainAnimationRielRight extends StatelessWidget {
  final int position;
  final Function(TapDownDetails) onTapDown;

  const CurtainAnimationRielRight({
    super.key,
    required this.position,
    required this.onTapDown,
  });

  @override
  Widget build(BuildContext context) {
    double curtainWidth =
        (position / 100) * MediaQuery.of(context).size.width * 0.8;

    return GestureDetector(
      onTapDown: onTapDown,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: 300,
        decoration: const BoxDecoration(
          color: Colors.transparent,
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.centerRight,
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 30,
              child: Image.asset(
                'assets/misc/barrielRiel.png',
                fit: BoxFit.cover,
              ),
            ),
            Positioned(
              top: 13,
              right: 10,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOut,
                width: curtainWidth,
                height: 270,
                child: Image.asset(
                  'assets/misc/cortinaRiel.jpg',
                  fit: BoxFit.cover,
                  height: double.infinity,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
//*- Diseño de la cortina Riel Right -*\\

//*- Diseño de la cortina Riel Center -*\\
class CurtainAnimationRielCenter extends StatelessWidget {
  final int position;
  final Function(TapDownDetails) onTapDown;

  const CurtainAnimationRielCenter({
    super.key,
    required this.position,
    required this.onTapDown,
  });

  @override
  Widget build(BuildContext context) {
    double curtainWidth = (position / 100) *
        MediaQuery.of(context).size.width *
        0.4; // Cada lado ocupa un 40% del ancho

    return GestureDetector(
      onTapDown: onTapDown,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: 300,
        decoration: const BoxDecoration(
          color: Colors.transparent,
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 30,
              child: Image.asset(
                'assets/misc/barrielRiel.png',
                fit: BoxFit.cover,
              ),
            ),
            // Cortina izquierda
            Positioned(
              top: 13,
              left: 10,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOut,
                width: curtainWidth,
                height: 270,
                child: Image.asset(
                  'assets/misc/cortinaRiel.jpg',
                  fit: BoxFit.cover,
                  height: double.infinity,
                ),
              ),
            ),
            // Cortina derecha
            Positioned(
              top: 13,
              right: 10,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOut,
                width: curtainWidth,
                height: 270,
                child: Image.asset(
                  'assets/misc/cortinaRiel.jpg',
                  fit: BoxFit.cover,
                  height: double.infinity,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

//*- Diseño de la cortina Riel Center -*\\
