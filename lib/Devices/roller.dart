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

  bool _isPressingUp = false;
  bool _isPressingDown = false;

  String? _activeQuickButton; // 'abrir' | 'cerrar' | null

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
    rollerSavedLength = globalDATA['$pc/$sn']?['rollerSavedLength'] ?? '';
    processValues(varsValues);
    subscribeToWifiStatus();
    subToVars();

    if (bluetoothManager.hasLoggerBle) getRecordedData(deviceName);
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
    if (!rollerMoving) {
      _activeQuickButton = null;
    }
    // awsInit = partes[16] == '1';
  }

  Future<void> _sendPositionMqtt(int position) async {
    final String topic = 'devices_rx/$pc/$sn';
    final String topic2 = 'devices_tx/$pc/$sn';
    final String message = jsonEncode({'working_position': '$position%'});

    final bool result = await sendMQTTMessageWithPermission(
      deviceName,
      message,
      topic,
      topic2,
      'Cambió posición del roller a $position%',
    );

    if (!result) {
      showToast('No tienes permisos de controlar el equipo');
    }
  }

  void setDistance(int position) {
    final String data = '$pc[7]($position%)';
    bluetoothManager.toolsUuid.write(data.codeUnits);
    _sendPositionMqtt(position);
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
              AbsorbPointer(
                absorbing: _activeQuickButton != null,
                child: CurtainAnimation(
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
              ),
              const SizedBox(height: 20),
              AbsorbPointer(
                absorbing: _activeQuickButton != null,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onLongPressStart: (LongPressStartDetails a) {
                          if (_activeQuickButton != null) return;
                          setState(() {
                            workingPosition = 0;
                            _isPressingUp = true;
                          });
                          setDistance(0);
                        },
                        onLongPressEnd: (LongPressEndDetails a) {
                          setState(() {
                            workingPosition = actualPosition;
                            _isPressingUp = false;
                          });
                          setDistance(actualPosition);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          decoration: BoxDecoration(
                            color: _activeQuickButton != null
                                ? Colors.grey.shade800
                                : _isPressingUp
                                    ? color4
                                    : color1,
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
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(HugeIcons.strokeRoundedArrowUp02,
                                  color: _isPressingUp ? color1 : color0),
                              const SizedBox(width: 8),
                              Text(
                                'Subir',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: _isPressingUp ? color1 : color0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    // DESPUÉS
                    Expanded(
                      child: GestureDetector(
                        onLongPressStart: (LongPressStartDetails a) {
                          if (_activeQuickButton != null) return;
                          setState(() {
                            workingPosition = 100;
                            _isPressingDown = true;
                          });
                          setDistance(100);
                        },
                        onLongPressEnd: (LongPressEndDetails a) {
                          setState(() {
                            workingPosition = actualPosition;
                            _isPressingDown = false;
                          });
                          setDistance(actualPosition);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          decoration: BoxDecoration(
                            color: _activeQuickButton != null
                                ? Colors.grey.shade800
                                : _isPressingDown
                                    ? color4
                                    : color1,
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
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(HugeIcons.strokeRoundedArrowDown02,
                                  color: _isPressingDown ? color1 : color0),
                              const SizedBox(width: 8),
                              Text(
                                'Bajar',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: _isPressingDown ? color1 : color0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // ── ABRIR CORTINA ──
                  Expanded(
                    child: GestureDetector(
                      onTap: _activeQuickButton == 'cerrar'
                          ? null // el otro está activo, bloqueado
                          : () {
                              setState(() => _activeQuickButton = 'abrir');
                              setDistance(0);
                              workingPosition = 0;
                              printLog.i("abrir cortina 0%");
                            },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: _activeQuickButton == 'abrir'
                              ? Colors.red.shade600
                              : _activeQuickButton == 'cerrar'
                                  ? Colors.grey.shade800
                                  : color1,
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
                        child: Center(
                          child: Text(
                            'Abrir cortina',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _activeQuickButton == 'cerrar'
                                  ? Colors.grey.shade600
                                  : color0,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  // ── CERRAR CORTINA ──
                  Expanded(
                    child: GestureDetector(
                      onTap: _activeQuickButton == 'abrir'
                          ? null // el otro está activo, bloqueado
                          : () {
                              setState(() => _activeQuickButton = 'cerrar');
                              setDistance(100);
                              workingPosition = 100;
                              printLog.i("cerrar cortina 100%");
                            },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: _activeQuickButton == 'cerrar'
                              ? Colors.red.shade600
                              : _activeQuickButton == 'abrir'
                                  ? Colors.grey.shade800
                                  : color1,
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
                        child: Center(
                          child: Text(
                            'Cerrar cortina',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _activeQuickButton == 'abrir'
                                  ? Colors.grey.shade600
                                  : color0,
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Configuración',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: color1,
                ),
              ),
              const SizedBox(height: 16),

              // TARJETA 1: MOTOR Y VELOCIDAD
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: color1,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Encabezado Motor
                    const Row(
                      children: [
                        Icon(HugeIcons.strokeRoundedSettings01,
                            color: color0, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'MOTOR Y MOVIMIENTO',
                          style: TextStyle(
                              color: color0,
                              fontWeight: FontWeight.bold,
                              fontSize: 14),
                        ),
                      ],
                    ),
                    Divider(color: color0.withValues(alpha: 0.1), height: 24),

                    // Fila: Polaridad
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Sentido de Rotación',
                                style: TextStyle(color: color0, fontSize: 15)),
                            Text(
                              rollerPolarity == '1' ? 'Invertido' : 'Normal',
                              style: const TextStyle(
                                  color: color3,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              rollerPolarity =
                                  rollerPolarity == '0' ? '1' : '0';
                            });
                            setRollerConfig(rollerPolarity == '1' ? 1 : 0);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: rollerPolarity == '1'
                                  ? color3
                                  : Colors.transparent,
                              border: Border.all(
                                  color: rollerPolarity == '1'
                                      ? color3
                                      : color0.withValues(alpha: 0.3)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(HugeIcons.strokeRoundedExchange01,
                                color: color0, size: 20),
                          ),
                        ),
                      ],
                    ),
                    Divider(color: color0.withValues(alpha: 0.1), height: 24),

                    // Fila: Velocidad
                    const Text('Velocidad',
                        style: TextStyle(color: color0, fontSize: 15)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        // Botón Baja
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() => rollerRPM = '70');
                              setMotorSpeed(rollerRPM);
                            },
                            child: Container(
                              margin: const EdgeInsets.only(right: 4),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: rollerRPM == '70'
                                    ? color3
                                    : Colors.transparent,
                                border: Border.all(
                                    color: rollerRPM == '70'
                                        ? color3
                                        : color0.withValues(alpha: 0.2)),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'Baja',
                                style: TextStyle(
                                    color: rollerRPM == '70'
                                        ? color0
                                        : color0.withValues(alpha: 0.6),
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ),
                        // Botón Media
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() => rollerRPM = '150');
                              setMotorSpeed(rollerRPM);
                            },
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: rollerRPM == '150'
                                    ? color3
                                    : Colors.transparent,
                                border: Border.all(
                                    color: rollerRPM == '150'
                                        ? color3
                                        : color0.withValues(alpha: 0.2)),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'Media',
                                style: TextStyle(
                                    color: rollerRPM == '150'
                                        ? color0
                                        : color0.withValues(alpha: 0.6),
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ),
                        // Botón Alta
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() => rollerRPM = '280');
                              setMotorSpeed(rollerRPM);
                            },
                            child: Container(
                              margin: const EdgeInsets.only(left: 4),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: rollerRPM == '280'
                                    ? color3
                                    : Colors.transparent,
                                border: Border.all(
                                    color: rollerRPM == '280'
                                        ? color3
                                        : color0.withValues(alpha: 0.2)),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'Alta',
                                style: TextStyle(
                                    color: rollerRPM == '280'
                                        ? color0
                                        : color0.withValues(alpha: 0.6),
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // TARJETA 2: CALIBRACIÓN (FLUJO DE PRUEBA AMIGABLE)
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: color1,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(HugeIcons.strokeRoundedRuler,
                            color: color0, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'CALIBRACIÓN DE RECORRIDO',
                          style: TextStyle(
                              color: color0,
                              fontWeight: FontWeight.bold,
                              fontSize: 14),
                        ),
                      ],
                    ),
                    Divider(color: color0.withValues(alpha: 0.1), height: 24),
                    if (rollerSavedLength == '') ...{
                      if (rollerEnd == null) ...{
                        const Text('Paso 1 de 2: Límite Inferior',
                            style: TextStyle(
                                color: color3,
                                fontWeight: FontWeight.bold,
                                fontSize: 14)),
                        const SizedBox(height: 8),
                        Text(
                          'Primero, bajá la cortina hasta donde quieras que llegue al cerrarse del todo. Una vez ahí, guardá la posición.',
                          style: TextStyle(
                              color: color0.withValues(alpha: 0.8),
                              fontSize: 14,
                              height: 1.4),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () async {
                            final vars = await bluetoothManager.varsUuid.read();
                            final grades =
                                int.parse(utf8.decode(vars).split(':')[12]);
                            rollerEnd = grades;
                            setState(() {
                              endSaved = true;
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: color3,
                            minimumSize: const Size(double.infinity, 45),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Guardar posición de abajo',
                              style: TextStyle(
                                  color: color0, fontWeight: FontWeight.bold)),
                        ),
                      } else ...{
                        // Paso 2
                        const Text('Paso 2 de 2: Límite Superior',
                            style: TextStyle(
                                color: color3,
                                fontWeight: FontWeight.bold,
                                fontSize: 14)),
                        const SizedBox(height: 8),
                        Text(
                          '¡Genial! Ahora subí la cortina hasta el tope máximo deseado y guardá esta última posición.',
                          style: TextStyle(
                              color: color0.withValues(alpha: 0.8),
                              fontSize: 14,
                              height: 1.4),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () async {
                            final vars = await bluetoothManager.varsUuid.read();
                            final grades =
                                int.parse(utf8.decode(vars).split(':')[12]);
                            rollerStart = grades;
                            setState(() {
                              rollerSavedLength =
                                  '${rollerEnd! - rollerStart!}';
                            });
                            setLarge(int.parse(rollerSavedLength));
                            await putRollerLength(pc, sn, rollerSavedLength);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade600,
                            minimumSize: const Size(double.infinity, 45),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Guardar posición de arriba',
                              style: TextStyle(
                                  color: color0, fontWeight: FontWeight.bold)),
                        ),
                      }
                    } else ...{
                      Row(
                        children: [
                          const Icon(HugeIcons.strokeRoundedCheckmarkBadge01,
                              color: Colors.green, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('¡Cortina configurada!',
                                    style: TextStyle(
                                        color: color0,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16)),
                                Text('Ya guardamos las medidas exactas.',
                                    style: TextStyle(
                                        color: color0.withValues(alpha: 0.6),
                                        fontSize: 13)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: () {
                          // Flujo simulado: Resetear
                          setState(() {
                            rollerSavedLength = '';
                            rollerEnd = null;
                            rollerStart = null;
                            endSaved = false;
                          });
                        },
                        icon: const Icon(HugeIcons.strokeRoundedRefresh,
                            color: color0, size: 18),
                        label: const Text('Volver a tomar medidas',
                            style: TextStyle(
                                color: color0, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          side:
                              BorderSide(color: color0.withValues(alpha: 0.3)),
                          minimumSize: const Size(double.infinity, 45),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    },
                  ],
                ),
              ),
              const SizedBox(height: 40),
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
              child: SafeArea(
                child: CurvedNavigationBar(
                  index: _selectedIndex,
                  height: 75.0,
                  items: const <Widget>[
                    Icon(HugeIcons.strokeRoundedHome11,
                        size: 30, color: color0),
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
