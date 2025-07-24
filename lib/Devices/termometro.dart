import 'dart:convert';

import 'package:caldensmart/Global/manager_screen.dart';
import 'package:caldensmart/aws/dynamo/dynamo.dart';
import 'package:caldensmart/logger.dart';
import 'package:caldensmart/master.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

class TermometroPage extends ConsumerStatefulWidget {
  const TermometroPage({super.key});
  @override
  ConsumerState<TermometroPage> createState() => TermometroPageState();
}

class TermometroPageState extends ConsumerState<TermometroPage> {
  final PageController _pageController = PageController();
  int _selectedIndex = 0;
  bool _isAnimating = false;
  bool _isTutorialActive = false;
  List<TutorialItem> items = [];

  void initItems() {
    items.addAll({
      TutorialItem(
        globalKey: keys['termometro:estado']!,
        borderRadius: const Radius.circular(30),
        shapeFocus: ShapeFocus.roundedSquare,
        fullBackground: true,
        contentPosition: ContentPosition.above,
        focusMargin: 15.0,
        pageIndex: 0,
        child: const TutorialItemContent(
          title: 'Termómetro',
          content:
              'En esta pantalla podrás ver los datos del termómetro a tiempo real',
        ),
      ),
      TutorialItem(
        globalKey: keys['termometro:temperaturaActual']!,
        borderRadius: const Radius.circular(30),
        shapeFocus: ShapeFocus.roundedSquare,
        contentPosition: ContentPosition.below,
        focusMargin: 15.0,
        pageIndex: 0,
        child: const TutorialItemContent(
          title: 'Temperatura Actual',
          content:
              'En este apartado podrás ver la temperatura actual del termómetro',
        ),
      ),
      TutorialItem(
        globalKey: keys['termometro:alertaMaxima']!,
        borderRadius: const Radius.circular(30),
        shapeFocus: ShapeFocus.roundedSquare,
        contentPosition: ContentPosition.above,
        focusMargin: 15.0,
        pageIndex: 0,
        contentOffsetY: -100,
        child: const TutorialItemContent(
          title: 'Alertas',
          content:
              'El termómetro en caso de estar por encima o por debajo de los valores establecidos, te enviará una alerta',
        ),
      ),
      TutorialItem(
        globalKey: keys['termometro:configAlertas']!,
        borderRadius: const Radius.circular(30),
        shapeFocus: ShapeFocus.roundedSquare,
        fullBackground: true,
        contentPosition: ContentPosition.above,
        focusMargin: 15.0,
        pageIndex: 1,
        child: const TutorialItemContent(
          title: 'Estado del equipo',
          content:
              'En esta pantalla podrás configurar las alertas del termómetro',
        ),
      ),
      TutorialItem(
        globalKey: keys['termometro:configMax']!,
        borderRadius: const Radius.circular(30),
        shapeFocus: ShapeFocus.roundedSquare,
        contentPosition: ContentPosition.below,
        focusMargin: 15.0,
        pageIndex: 1,
        child: const TutorialItemContent(
          title: 'Configuración máxima',
          content:
              'Configura la alerta máxima del termómetro, si se alcanza este valor, se enviará una alerta',
        ),
      ),
      TutorialItem(
        globalKey: keys['termometro:configMin']!,
        borderRadius: const Radius.circular(30),
        shapeFocus: ShapeFocus.roundedSquare,
        contentPosition: ContentPosition.above,
        contentOffsetY: -100,
        focusMargin: 15.0,
        pageIndex: 1,
        child: const TutorialItemContent(
          title: 'Configuración mínima',
          content:
              'Configura la alerta mínima del termómetro, si se alcanza este valor, se enviará una alerta',
        ),
      ),
      TutorialItem(
        globalKey: keys['managerScreen:titulo']!,
        borderRadius: const Radius.circular(30),
        shapeFocus: ShapeFocus.roundedSquare,
        contentPosition: ContentPosition.below,
        focusMargin: 15.0,
        pageIndex: 2,
        child: const TutorialItemContent(
          title: 'Gestión del equipo',
          content: 'En esta pantalla podrás ver y cambiar detalles del equipo',
        ),
      ),
      TutorialItem(
        globalKey: keys['managerScreen:imagen']!,
        borderRadius: const Radius.circular(30),
        shapeFocus: ShapeFocus.roundedSquare,
        contentPosition: ContentPosition.below,
        focusMargin: 15.0,
        pageIndex: 2,
        child: const TutorialItemContent(
          title: 'Imagen del equipo',
          content:
              'Aquí podrás cambiar la imagen del equipo en el menú principal',
        ),
      ),
    });
  }

  @override
  void initState() {
    super.initState();

    nickname = nicknamesMap[deviceName] ?? deviceName;

    subscribeToWifiStatus();
    subscribeToVars();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      updateWifiValues(toolsValues);
      if (shouldUpdateDevice) {
        await showUpdateDialog(context);
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
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
      // printLog.i('sis $isWifiConnected');
      errorMessage = '';
      errorSintax = '';
      werror = false;
      parts.length > 3
          ? signalPower = int.tryParse(parts[3]) ?? -30
          : signalPower = -30;
      parts.length > 4 ? wifiUnstable = parts[4] == '1' : wifiUnstable = false;

      wifiNotifier.updateStatus(
          'CONECTADO', Colors.green, wifiPower(signalPower));
    } else if (parts[0] == 'WCS_DISCONNECTED') {
      isWifiConnected = false;
      // printLog.i('non $isWifiConnected');

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
      // printLog.i('Llegaron cositas wifi');
      updateWifiValues(status);
    });

    myDevice.device.cancelWhenDisconnected(wifiSub);
  }

  void subscribeToVars() async {
    printLog.i('Me subscribo a vars');
    await myDevice.varsUuid.setNotifyValue(true);

    final trueStatusSub =
        myDevice.varsUuid.onValueReceived.listen((List<int> status) {
      var parts = utf8.decode(status).split(':');

      if (parts.length == 4) {
        setState(() {
          actualTemp = parts[0];
          // offsetTemp = parts[1];
          alertMaxFlag = parts[2] == '1';
          alertMinFlag = parts[3] == '1';
        });
      }
    });

    myDevice.device.cancelWhenDisconnected(trueStatusSub);
  }

  void _showAlertDialog(String type) {
    String title =
        type == 'max' ? 'Configurar Alerta Máxima' : 'Configurar Alerta Mínima';
    String currentValue = type == 'max' ? alertMaxTemp : alertMinTemp;
    Color dialogColor = type == 'max' ? Colors.red : Colors.orange;

    TextEditingController tempController =
        TextEditingController(text: currentValue);

    showAlertDialog(
      context,
      false,
      Text(
        title,
        style: const TextStyle(color: color0),
      ),
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Introduce el valor de temperatura ${type == 'max' ? 'máxima' : 'mínima'} en grados Celsius',
            style:
                TextStyle(color: color0.withValues(alpha: 0.8), fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          TextField(
            style: const TextStyle(color: color0),
            cursorColor: dialogColor,
            controller: tempController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              hintText: "Ej: 25.5",
              hintStyle: TextStyle(color: color0.withValues(alpha: 0.5)),
              suffixText: "°C",
              suffixStyle: TextStyle(color: dialogColor),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: dialogColor),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: dialogColor, width: 2),
              ),
            ),
          ),
        ],
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
            foregroundColor: WidgetStateProperty.all(dialogColor),
          ),
          child: const Text('Guardar'),
          onPressed: () {
            String newValue = tempController.text.trim();

            // Validar que sea un número válido
            double? tempValue = double.tryParse(newValue);
            if (tempValue == null) {
              // Mostrar error si no es un número válido
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Por favor introduce un número válido'),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }

            setState(() {
              if (type == 'max') {
                alertMaxTemp = newValue;
                String data =
                    '${DeviceManager.getProductCode(deviceName)}[7]($newValue)';
                printLog.i('Enviando: $data');
                myDevice.toolsUuid.write(data.codeUnits);
              } else {
                alertMinTemp = newValue;
                String data =
                    '${DeviceManager.getProductCode(deviceName)}[8]($newValue)';
                printLog.i('Enviando: $data');
                myDevice.toolsUuid.write(data.codeUnits);
              }
            });
            printLog.i(
                'Nuevo valor de alerta ${type == 'max' ? 'máxima' : 'mínima'}: $newValue°C');

            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final TextStyle poppinsStyle = GoogleFonts.poppins();
    final wifiState = ref.watch(wifiProvider);

    if (userConnected && lastUser > 1) {
      return const DeviceInUseScreen();
    }

    if (specialUser && !labProcessFinished) {
      return const LabProcessNotFinished();
    }

    final List<Widget> pages = [
      //*- Página 1 - Estado del dispositivo -*\\
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14.0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final screenHeight = constraints.maxHeight;
            final tempCardHeight = screenHeight * 0.45;

            return Column(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                // Temperatura Actual - Más grande
                AnimatedOpacity(
                  opacity: 1.0,
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeInOut,
                  child: SizedBox(
                    height: tempCardHeight,
                    child: Card(
                      color: color3,
                      elevation: 6,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                        side: const BorderSide(
                          color: color6,
                          width: 2,
                        ),
                      ),
                      child: Padding(
                        key: keys['termometro:temperaturaActual']!,
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.thermostat_rounded,
                              color: color6,
                              size: 80,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Temperatura Actual',
                              style: TextStyle(
                                color: color0,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              key: keys['termometro:estado']!,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  '${actualTemp.isEmpty ? "0" : actualTemp}°C',
                                  style: const TextStyle(
                                    color: color6,
                                    fontSize: 48,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Alertas en una fila horizontal con tamaño fijo
                SizedBox(
                  key: keys['termometro:alertaMaxima']!,
                  height: screenHeight * 0.25,
                  child: Row(
                    children: [
                      // Alerta Máxima
                      Expanded(
                        child: AnimatedOpacity(
                          opacity: 1.0,
                          duration: const Duration(milliseconds: 800),
                          curve: Curves.easeInOut,
                          child: Card(
                            color: color3,
                            elevation: 6,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                              side: BorderSide(
                                color: alertMaxFlag ? color5 : color2,
                                width: 2,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 500),
                                    transitionBuilder: (Widget child,
                                        Animation<double> animation) {
                                      return ScaleTransition(
                                          scale: animation, child: child);
                                    },
                                    child: Icon(
                                      alertMaxFlag
                                          ? Icons.warning_amber_rounded
                                          : Icons.keyboard_arrow_up_rounded,
                                      key: ValueKey<bool>(alertMaxFlag),
                                      color: alertMaxFlag ? color5 : color2,
                                      size: 32,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  const Flexible(
                                    child: Text(
                                      'Alerta Máxima',
                                      style: TextStyle(
                                        color: color0,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Flexible(
                                    child: Text(
                                      alertMaxTemp.isEmpty
                                          ? "No configurado"
                                          : "$alertMaxTemp°C",
                                      style: TextStyle(
                                        color: color0.withValues(alpha: 0.8),
                                        fontSize: 11,
                                      ),
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Alerta Mínima
                      Expanded(
                        child: AnimatedOpacity(
                          opacity: 1.0,
                          duration: const Duration(milliseconds: 800),
                          curve: Curves.easeInOut,
                          child: Card(
                            color: color3,
                            elevation: 6,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                              side: BorderSide(
                                color: alertMinFlag ? color6 : color2,
                                width: 2,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 500),
                                    transitionBuilder: (Widget child,
                                        Animation<double> animation) {
                                      return ScaleTransition(
                                          scale: animation, child: child);
                                    },
                                    child: Icon(
                                      alertMinFlag
                                          ? Icons.warning_amber_rounded
                                          : Icons.keyboard_arrow_down_rounded,
                                      key: ValueKey<bool>(alertMinFlag),
                                      color: alertMinFlag ? color6 : color2,
                                      size: 32,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  const Flexible(
                                    child: Text(
                                      'Alerta Mínima',
                                      style: TextStyle(
                                        color: color0,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Flexible(
                                    child: Text(
                                      alertMinTemp.isEmpty
                                          ? "No configurado"
                                          : "$alertMinTemp°C",
                                      style: TextStyle(
                                        color: color0.withValues(alpha: 0.8),
                                        fontSize: 11,
                                      ),
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            );
          },
        ),
      ),

      //*- Página 2: Configuraciones -*\\
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14.0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final screenHeight = constraints.maxHeight;
            final cardHeight = screenHeight * 0.25;

            return Column(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Configuración Alerta Máxima
                AnimatedOpacity(
                  opacity: 1.0,
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeInOut,
                  child: GestureDetector(
                    onTap: () => _showAlertDialog('max'),
                    child: SizedBox(
                      height: cardHeight,
                      child: Card(
                        key: keys['termometro:configAlertas']!,
                        color: color3,
                        elevation: 6,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                          side: BorderSide(
                            color: alertMaxFlag ? color5 : color2,
                            width: 2,
                          ),
                        ),
                        child: Padding(
                          key: keys['termometro:configMax']!,
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            children: [
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 500),
                                transitionBuilder: (Widget child,
                                    Animation<double> animation) {
                                  return ScaleTransition(
                                      scale: animation, child: child);
                                },
                                child: Icon(
                                  alertMaxFlag
                                      ? Icons.warning_amber_rounded
                                      : Icons.keyboard_arrow_up_rounded,
                                  key: ValueKey<bool>(alertMaxFlag),
                                  color: alertMaxFlag ? color5 : color2,
                                  size: 50,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Expanded(
                                          child: Text(
                                            'Configurar Alerta Máxima',
                                            style: TextStyle(
                                              color: color0,
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Icon(
                                          Icons.edit,
                                          color: color0.withValues(alpha: 0.6),
                                          size: 16,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      alertMaxFlag ? 'ACTIVADA' : 'Normal',
                                      style: TextStyle(
                                        color: alertMaxFlag ? color5 : color2,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      'Límite: ${alertMaxTemp.isEmpty ? "No configurado" : "$alertMaxTemp°C"}',
                                      style: TextStyle(
                                        color: color0.withValues(alpha: 0.8),
                                        fontSize: 12,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Configuración Alerta Mínima
                AnimatedOpacity(
                  opacity: 1.0,
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeInOut,
                  child: GestureDetector(
                    onTap: () => _showAlertDialog('min'),
                    child: SizedBox(
                      height: cardHeight,
                      child: Card(
                        color: color3,
                        elevation: 6,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                          side: BorderSide(
                            color: alertMinFlag ? color6 : color2,
                            width: 2,
                          ),
                        ),
                        child: Padding(
                          key: keys['termometro:configMin']!,
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            children: [
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 500),
                                transitionBuilder: (Widget child,
                                    Animation<double> animation) {
                                  return ScaleTransition(
                                      scale: animation, child: child);
                                },
                                child: Icon(
                                  alertMinFlag
                                      ? Icons.warning_amber_rounded
                                      : Icons.keyboard_arrow_down_rounded,
                                  key: ValueKey<bool>(alertMinFlag),
                                  color: alertMinFlag ? color6 : color2,
                                  size: 50,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Expanded(
                                          child: Text(
                                            'Configurar Alerta Mínima',
                                            style: TextStyle(
                                              color: color0,
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Icon(
                                          Icons.edit,
                                          color: color0.withValues(alpha: 0.6),
                                          size: 16,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      alertMinFlag ? 'ACTIVADA' : 'Normal',
                                      style: TextStyle(
                                        color: alertMinFlag ? color6 : color2,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      'Límite: ${alertMinTemp.isEmpty ? "No configurado" : "$alertMinTemp°C"}',
                                      style: TextStyle(
                                        color: color0.withValues(alpha: 0.8),
                                        fontSize: 12,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 50),
              ],
            );
          },
        ),
      ),

      //*- Página 3: Gestión del Equipo -*\\
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
                  //key: keys['termometros:titulo']!,
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
              //key: keys['termometros:servidor']!,
              globalDATA['${DeviceManager.getProductCode(deviceName)}/${DeviceManager.extractSerialNumber(deviceName)}']
                          ?['cstate'] ??
                      false
                  ? Icons.cloud
                  : Icons.cloud_off,
              color: color0,
            ),
            IconButton(
              //key: keys['termometros:wifi']!,
              icon: Icon(wifiState.wifiIcon, color: color0),
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
                      Icon(Icons.thermostat, size: 30, color: color0),
                      Icon(Icons.tune, size: 30, color: color0),
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
