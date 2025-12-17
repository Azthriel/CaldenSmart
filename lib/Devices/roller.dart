import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import '../Global/manager_screen.dart';
import '../aws/dynamo/dynamo.dart';
import '../master.dart';
import 'package:caldensmart/logger.dart';

class RollerPage extends ConsumerStatefulWidget {
  const RollerPage({super.key});
  @override
  RollerPageState createState() => RollerPageState();
}

class RollerPageState extends ConsumerState<RollerPage> {
  int _selectedIndex = 0;

  final String pc = DeviceManager.getProductCode(deviceName);
  final String sn = DeviceManager.extractSerialNumber(deviceName);

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

  int? rollerEnd;
  int? rollerStart;
  int? totalGrades;

  bool endSaved = false;

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
    processValues(varsValues);
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
    //printLog.i(fun);
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
    //printLog.i('Se subscribio a wifi');
    await bluetoothManager.toolsUuid.setNotifyValue(true);

    final wifiSub =
        bluetoothManager.toolsUuid.onValueReceived.listen((List<int> status) {
      updateWifiValues(status);
    });

    bluetoothManager.device.cancelWhenDisconnected(wifiSub);
  }

  void subToVars() async {
   // printLog.i('Me subscribo a vars');
    await bluetoothManager.varsUuid.setNotifyValue(true);

    final varsSub =
        bluetoothManager.varsUuid.onValueReceived.listen((List<int> status) {
      var parts = utf8.decode(status).split(':');
      // printLog.i('Posición nueva: ${parts[0]}');
      if (context.mounted) {
        setState(() {
          actualPosition = int.parse(parts[0]);
          rollerMoving = parts[1] == '1';
        });
      }
    });

    bluetoothManager.device.cancelWhenDisconnected(varsSub);
  }

  void processValues(List<int> values) {
    List<String> partes = utf8.decode(values).split(':');

    distanceControlActive = partes[0] == '1';
    rollerlength = partes[1];
    rollerPolarity = partes[2];
    rollerRPM = partes[3];
    // rollerMicroStep = partes[4];
    // rollerIMAX = partes[5];
    // rollerIRMSRUN = partes[6];
    // rollerIRMSHOLD = partes[7];
    // rollerFreewheeling = partes[8] == '1';
    // rollerTPWMTHRS = partes[9];
    // rollerTCOOLTHRS = partes[10];
    // rollerSGTHRS = partes[11];
    actualPositionGrades = int.parse(partes[12]);
    actualPosition = int.parse(partes[13]);
    workingPosition = int.parse(partes[14]);
    rollerMoving = partes[15] == '1';
    // awsInit = partes[16] == '1';
  }

  void setDistance(int pc) {
    String data = '$pc[7]($pc%)';
   // printLog.i(data);
    bluetoothManager.toolsUuid.write(data.codeUnits);
  }

  void setLarge(int grades) {
    String data = '$pc[7]($grades)';
    //printLog.i(data);
    bluetoothManager.toolsUuid.write(data.codeUnits);
  }

  void setRollerConfig(int type) {
    String data = '$pc[8]($type)';
    bluetoothManager.toolsUuid.write(data.codeUnits);
  }

  void setMotorSpeed(String rpm) {
    String data = '$pc[10]($rpm)';
   // printLog.i(data);
    bluetoothManager.toolsUuid.write(data.codeUnits);
  }

//! VISUAL
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
                  color: color1,
                ),
              ),
              const SizedBox(height: 20),
              CurtainAnimation(
                position: actualPosition,
                onTapDown: (details) {
                  RenderBox box = context.findRenderObject() as RenderBox;
                  Offset localPosition =
                      box.globalToLocal(details.globalPosition);
                  double relativeHeight = (localPosition.dy - 200) / 250;
                  int newPosition =
                      (relativeHeight * 100).clamp(0, 100).round();

                  setState(() {
                    workingPosition = newPosition;
                    setDistance(newPosition);
                  });
                },
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: GestureDetector(
                      onLongPressStart: (LongPressStartDetails a) {
                        String data = '$pc[7](0%)';
                        bluetoothManager.toolsUuid.write(data.codeUnits);
                        setState(() {
                          workingPosition = 0;
                        });
                        printLog.i(data);
                      },
                      onLongPressEnd: (LongPressEndDetails a) {
                        String data = '$pc[7]($actualPosition%)';
                        bluetoothManager.toolsUuid.write(data.codeUnits);
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
                              color: color1,
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
                                Icon(HugeIcons.strokeRoundedArrowUp02,
                                    color: color0),
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
                        String data = '$pc[7](100%)';
                        bluetoothManager.toolsUuid.write(data.codeUnits);
                        setState(() {
                          workingPosition = 100;
                        });
                        printLog.i(data);
                      },
                      onLongPressEnd: (LongPressEndDetails a) {
                        String data = '$pc[7]($actualPosition%)';
                        bluetoothManager.toolsUuid.write(data.codeUnits);
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
                              color: color1,
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
                                Icon(HugeIcons.strokeRoundedArrowDown02,
                                    color: color0),
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
              Text(
                'Configuración de parámetros',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color1,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(
                height: 20,
              ),
              // Polaridad del Roller Section
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15.0),
                ),
                color: color1,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    spacing: 10,
                    children: [
                      const Text(
                        'Polaridad del Roller',
                        style: TextStyle(
                          fontSize: 18.0,
                          color: color0,
                          fontWeight: FontWeight.bold,
                        ),
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
                          backgroundColor: color4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: const Text(
                          'Invertir',
                          style: TextStyle(color: color0),
                        ),
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
                color: color1,
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
                              rollerRPM = '50';
                              setMotorSpeed('50');
                              showToast("Velocidad baja");
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: const Text(
                              'Baja',
                              style: TextStyle(color: color0),
                            ),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            onPressed: () {
                              rollerRPM = '150';
                              setMotorSpeed('150');
                              showToast('Velocidad media');
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: const Text(
                              'Media',
                              style: TextStyle(color: color0),
                            ),
                          ),
                          const SizedBox(
                            width: 10,
                          ),
                          ElevatedButton(
                            onPressed: () {
                              rollerRPM = '250';
                              setMotorSpeed('250');
                              showToast("Velocidad alta");
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: color3,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: const Text(
                              'Alta',
                              style: TextStyle(color: color0),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Configuración del Roller Section
              Text(
                'Configuración del\nlargo de la cortina',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color1,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(
                height: 10,
              ),
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15.0),
                ),
                color: color1,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      if (rollerSavedLength == '') ...{
                        if (rollerEnd == null && !endSaved) ...{
                          Text(
                            'Lo primero que debes hacer es mover la cortina al final de su recorrido y presionar el botón de abajo para guardar la posición.',
                            style: GoogleFonts.poppins(
                              fontSize: 18.0,
                              color: color0,
                              fontWeight: FontWeight.normal,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(
                            height: 20,
                          ),
                          ElevatedButton(
                            onPressed: () async {
                              printLog.i("Guardo fin");
                              List<int> fun =
                                  await bluetoothManager.varsUuid.read();
                              processValues(fun);
                              rollerEnd = actualPositionGrades;
                              endSaved = true;

                              printLog.i("Fin en grados: $rollerEnd");
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: color4,
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
                        } else if (rollerStart == null && endSaved) ...{
                          Text(
                            'Luego de eso se debe mover la cortina al inicio de su recorrido y presionar el botón de abajo para guardar la posición.',
                            style: GoogleFonts.poppins(
                              fontSize: 18.0,
                              color: color0,
                              fontWeight: FontWeight.normal,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(
                            height: 20,
                          ),
                          ElevatedButton(
                            onPressed: () async {
                              printLog.i("Guardo inicio");
                              List<int> fun =
                                  await bluetoothManager.varsUuid.read();
                              processValues(fun);
                              rollerStart = actualPositionGrades;

                              printLog.i("Inicio en grados: $rollerStart");
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: color4,
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
                        } else if (rollerEnd != null &&
                            rollerStart != null) ...{
                          Text(
                            'Ahora envía el largo de la cortina.',
                            style: GoogleFonts.poppins(
                              fontSize: 18.0,
                              color: color0,
                              fontWeight: FontWeight.normal,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(
                            height: 10,
                          ),
                          ElevatedButton(
                            onPressed: () async {
                              printLog.i("Envio largo");
                              int largo = rollerEnd! - rollerStart!;
                              printLog.i("Largo: $largo");
                              putRollerLength(pc, sn, largo.toString());

                              setLarge(largo);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: color4,
                              minimumSize: const Size(double.infinity, 50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: const Text(
                              'Enviar largo de la cortina',
                              style: TextStyle(fontSize: 16, color: color0),
                            ),
                          ),
                        },
                      } else ...{
                        Text(
                          rollerSavedLength == rollerlength
                              ? 'El largo de la cortina se configuro correctamente'
                              : 'El largo de la cortina no coincide con el configurado, por favor configurarlo nuevamente',
                          style: GoogleFonts.poppins(
                            fontSize: 18.0,
                            color: color0,
                            fontWeight: FontWeight.normal,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(
                          height: 20,
                        ),
                        ElevatedButton(
                          onPressed: () {
                            rollerSavedLength = '';
                            setState(() {});
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: color4,
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: const Text(
                            'Volver a configurar largo',
                            style: TextStyle(fontSize: 16, color: color0),
                          ),
                        ),
                      },
                      const SizedBox(
                        height: 10,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(
                height: 100,
              ),
            ],
          ),
        ),
      ),

      //*- Página 3: Gestión del Equipo -*\\
      ManagerScreen(deviceName: deviceName),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, A) {
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
                  HugeIcons.strokeRoundedPen01,
                  size: 20,
                  color: color0,
                )
              ],
            ),
          ),
          leading: IconButton(
            icon: const Icon(HugeIcons.strokeRoundedArrowLeft02),
            color: color0,
            onPressed: () {
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
                ? const ImageIcon(
                    AssetImage(CaldenIcons.cloud),
                    size: 35,
                    color: color0,
                  )
                : const ImageIcon(
                    AssetImage(CaldenIcons.cloudOff),
                    size: 25,
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
        backgroundColor: color0,
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
                  Icon(HugeIcons.strokeRoundedHome07, size: 30, color: color0),
                  Icon(HugeIcons.strokeRoundedWrench01,
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
