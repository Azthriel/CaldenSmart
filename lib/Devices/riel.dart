import 'dart:convert';
import 'package:caldensmart/aws/dynamo/dynamo.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../Global/manager_screen.dart';
import '../master.dart';
import 'package:caldensmart/logger.dart';

class RollerPage extends ConsumerStatefulWidget {
  const RollerPage({super.key});
  @override
  RollerPageState createState() => RollerPageState();
}

class RollerPageState extends ConsumerState<RollerPage> {
  int _selectedIndex = 0;

  final TextEditingController tenantController = TextEditingController();
  final PageController _pageController = PageController(initialPage: 0);

  TextEditingController rLargeController = TextEditingController();
  TextEditingController workController = TextEditingController();
  TextEditingController motorSpeedUpController = TextEditingController();
  TextEditingController motorSpeedDownController = TextEditingController();
  TextEditingController contrapulseController = TextEditingController();
  TextEditingController emailController = TextEditingController();

  bool showOptions = false;
  bool showSecondaryAdminFields = false;
  bool showAddAdminField = false;
  bool showSecondaryAdminList = false;
  bool showSmartResident = false;
  bool dOnOk = false;
  bool dOffOk = false;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();

    nickname = nicknamesMap[deviceName] ?? deviceName;
    showOptions = currentUserEmail == owner;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      updateWifiValues(toolsValues);
      if (shouldUpdateDevice) {
        await showUpdateDialog(context);
      }
    });
    subscribeToWifiStatus();
    subToVars();
  }

  @override
  void dispose() {
    _pageController.dispose();
    tenantController.dispose();
    rLargeController.dispose();
    workController.dispose();
    motorSpeedUpController.dispose();
    motorSpeedDownController.dispose();
    contrapulseController.dispose();
    emailController.dispose();
    super.dispose();
  }

  // FUNCIONES \\

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
    await myDevice.toolsUuid.setNotifyValue(true);

    final wifiSub =
        myDevice.toolsUuid.onValueReceived.listen((List<int> status) {
      updateWifiValues(status);
    });

    myDevice.device.cancelWhenDisconnected(wifiSub);
  }

  void subToVars() async {
    printLog.i('Me subscribo a vars');
    await myDevice.varsUuid.setNotifyValue(true);

    final varsSub =
        myDevice.varsUuid.onValueReceived.listen((List<int> status) {
      var parts = utf8.decode(status).split(':');
      // printLog.i(parts);
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
    printLog.i(data);
    myDevice.toolsUuid.write(data.codeUnits);
  }

  void setDistance(int pc) {
    String data = '${DeviceManager.getProductCode(deviceName)}[7]($pc%)';
    printLog.i(data);
    myDevice.toolsUuid.write(data.codeUnits);
  }

  void setRollerConfig(int type) {
    String data = '${DeviceManager.getProductCode(deviceName)}[8]($type)';
    myDevice.toolsUuid.write(data.codeUnits);
  }

  void setMotorSpeed(String rpm) {
    String data = '${DeviceManager.getProductCode(deviceName)}[10]($rpm)';
    printLog.i(data);
    myDevice.toolsUuid.write(data.codeUnits);
  }

  void setMicroStep(String uStep) {
    String data = '${DeviceManager.getProductCode(deviceName)}[11]($uStep)';
    printLog.i(data);
    myDevice.toolsUuid.write(data.codeUnits);
  }

  void setMotorCurrent(bool run, String value) {
    String data =
        '${DeviceManager.getProductCode(deviceName)}[12](${run ? '1' : '0'}#$value)';
    printLog.i(data);
    myDevice.toolsUuid.write(data.codeUnits);
  }

  void setFreeWheeling(bool active) {
    String data =
        '${DeviceManager.getProductCode(deviceName)}[14](${active ? '1' : '0'})';
    printLog.i(data);
    myDevice.toolsUuid.write(data.codeUnits);
  }

  void setTPWMTHRS(String value) {
    String data = '${DeviceManager.getProductCode(deviceName)}[15]($value)';
    printLog.i(data);
    myDevice.toolsUuid.write(data.codeUnits);
  }

  void setTCOOLTHRS(String value) {
    String data = '${DeviceManager.getProductCode(deviceName)}[16]($value)';
    printLog.i(data);
    myDevice.toolsUuid.write(data.codeUnits);
  }

  void setSGTHRS(String value) {
    String data = '${DeviceManager.getProductCode(deviceName)}[17]($value)';
    printLog.i(data);
    myDevice.toolsUuid.write(data.codeUnits);
  }

//! VISUAL
  @override
  Widget build(BuildContext context) {
    final TextStyle poppinsStyle = GoogleFonts.poppins();
    final wifiState = ref.watch(wifiProvider);

    bool isRegularUser = !deviceOwner && !secondaryAdmin;

    // si hay un usuario conectado al equipo no lo deje ingresar
    if (userConnected && lastUser > 1) {
      return const DeviceInUseScreen();
    }

    // Condición para mostrar la pantalla de acceso restringido
    if (isRegularUser && owner != '' && !tenant) {
      return const AccessDeniedScreen();
    }

    if (specialUser && !labProcessFinished) {
      return const LabProcessNotFinished();
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
                        printLog.i(data);
                      },
                      onLongPressEnd: (LongPressEndDetails a) {
                        String data =
                            '${DeviceManager.getProductCode(deviceName)}[7]($actualPosition%)';
                        myDevice.toolsUuid.write(data.codeUnits);
                        setState(() {
                          workingPosition = actualPosition;
                        });
                        printLog.i(data);
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
                        printLog.i(data);
                      },
                      onLongPressEnd: (LongPressEndDetails a) {
                        String data =
                            '${DeviceManager.getProductCode(deviceName)}[7]($actualPosition%)';
                        myDevice.toolsUuid.write(data.codeUnits);
                        setState(() {
                          workingPosition = actualPosition;
                        });
                        printLog.i(data);
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
      const ManagerScreen(),
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
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.only(left: 15),
                      child: const Text(
                        "Desconectando...",
                        style: TextStyle(color: Color(0xFFFFFFFF)),
                        overflow: TextOverflow.ellipsis,
                      ),
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
                  child: Text(
                    nickname,
                    overflow: TextOverflow.ellipsis,
                    style: poppinsStyle.copyWith(color: color0),
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
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.only(left: 15),
                            child: const Text(
                              "Desconectando...",
                              style: TextStyle(color: Color(0xFFFFFFFF)),
                              overflow: TextOverflow.ellipsis,
                            ),
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
              globalDATA['${DeviceManager.getProductCode(deviceName)}/${DeviceManager.extractSerialNumber(deviceName)}']
                          ?['cstate'] ??
                      false
                  ? Icons.cloud
                  : Icons.cloud_off,
              color: color0,
            ),
            IconButton(
              icon: Icon(wifiState.wifiIcon, color: color0),
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
              physics: _isAnimating
                  ? const NeverScrollableScrollPhysics()
                  : const BouncingScrollPhysics(),
              onPageChanged: onItemChanged,
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
                onTap: onItemTapped,
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
