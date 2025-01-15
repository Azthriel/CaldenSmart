import 'dart:async';
import 'dart:io';
import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import '../master.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => ScanPageState();
}

class ScanPageState extends State<ScanPage>
    with SingleTickerProviderStateMixin {
  List<BluetoothDevice> devices = [];
  List<BluetoothDevice> sortedDevices = [];
  BluetoothDevice? connectedDevice;
  bool isConnecting = false;
  String searchQuery = '';
  bool toastFlag = false;
  int connectionTry = 0;
  final TextEditingController searchController = TextEditingController();
  late AnimationController _animationController;
  final EasyRefreshController _controller = EasyRefreshController(
    controlFinishRefresh: true,
  );
  StreamSubscription<List<ScanResult>>? listener;
  String? _touchedDeviceId;

  @override
  void initState() {
    super.initState();
    startBluetoothMonitoring();
    startLocationMonitoring();
    List<dynamic> lista = fbData['Keywords'] ??
        [
          'Detector',
          'Domotica',
          'Domótica',
          'Electrico',
          'Eléctrico',
          'Radiador',
          'Gas',
          'Rele',
          'Relé',
          'Roll',
          'Millenium',
          'Modulo',
          'Riel'
        ];
    keywords = lista.map((item) => item.toString()).toList();
    scan();

    searchController.addListener(() {
      setState(() {
        searchQuery = searchController.text.toLowerCase();
      });
    });

    if (context.mounted) {
      _animationController = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 1),
      )..forward();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    searchController.dispose();
    _controller.dispose();
    listener?.cancel();
    super.dispose();
  }

  void scan() {
    printLog('Jiji');
    if (bluetoothOn) {
      printLog('Entre a escanear');
      toastFlag = false;
      try {
        FlutterBluePlus.isScanningNow ? FlutterBluePlus.stopScan() : null;
        FlutterBluePlus.startScan(
          withKeywords: keywords,
          androidUsesFineLocation: true,
          continuousUpdates: true,
          removeIfGone: const Duration(seconds: 30),
        );

        listener = FlutterBluePlus.scanResults.listen(
          (results) {
            for (ScanResult result in results) {
              if (!devices
                  .any((device) => device.remoteId == result.device.remoteId)) {
                if (navigatorKey.currentContext?.mounted ?? context.mounted) {
                  setState(() {
                    devices.add(result.device);
                    devices.sort(
                      (a, b) => a.platformName.compareTo(b.platformName),
                    );
                    sortedDevices = devices;
                  });
                }
              }
              lastSeenDevices[result.device.remoteId.toString()] =
                  DateTime.now();
            }
            if (context.mounted) {
              _removeLostDevices();
            }
          },
        );
      } catch (e, stackTrace) {
        printLog('Error al escanear $e $stackTrace');
        showToast('Error al escanear, intentelo nuevamente');
      }
    }
  }

  void _removeLostDevices() {
    if (!context.mounted) {
      return;
    }
    DateTime now = DateTime.now();
    if (context.mounted) {
      setState(() {
        devices.removeWhere((device) {
          final lastSeen = lastSeenDevices[device.remoteId.toString()];
          if (lastSeen != null && now.difference(lastSeen).inSeconds > 30) {
            printLog('Borre ${device.platformName}');
            lastSeenDevices.remove(device.remoteId.toString());
            return true;
          }
          return false;
        });
        sortedDevices = devices;
      });
    }
  }

  void connectToDevice(BluetoothDevice device) async {
    try {
      await device.connect(timeout: const Duration(seconds: 6));
      deviceName = device.platformName;
      myDeviceid = device.remoteId.toString();

      printLog('Teoricamente estoy conectado');

      MyDevice myDevice = MyDevice();

      var conenctionSub =
          device.connectionState.listen((BluetoothConnectionState state) {
        printLog('Estado de conexión: $state');
        switch (state) {
          case BluetoothConnectionState.disconnected:
            {
              if (!quickAction) {
                printLog("Para que mierda hago yo las cosas DIOS", "cyan");
                if (!toastFlag) {
                  showToast('Dispositivo desconectado');
                  toastFlag = true;
                }
                nameOfWifi = '';
                connectionFlag = false;
                printLog(
                    'Razon: ${myDevice.device.disconnectReason?.description}');
                navigatorKey.currentState?.pushReplacementNamed('/menu');
              }
              break;
            }
          case BluetoothConnectionState.connected:
            {
              if (!quickAction) {
                printLog("Para que mierda hago yo las cosas DIOS", "cyan");
                if (!connectionFlag) {
                  connectionFlag = true;
                  FlutterBluePlus.isScanningNow
                      ? FlutterBluePlus.stopScan()
                      : null;
                  myDevice.setup(device).then((valor) {
                    printLog('RETORNASHE $valor');
                    connectionTry = 0;
                    if (valor) {
                      navigatorKey.currentState
                          ?.pushReplacementNamed('/loading');
                    } else {
                      connectionFlag = false;
                      printLog('Fallo en el setup');
                      showToast('Error en el dispositivo, intente nuevamente');
                      myDevice.device.disconnect();
                    }
                  });
                } else {
                  printLog('Las chistosadas se apoderan del mundo');
                }
              }
              break;
            }
          default:
            break;
        }
      });
      device.cancelWhenDisconnected(conenctionSub, delayed: true);
    } catch (e, stackTrace) {
      if (connectionTry < 3) {
        printLog('Retry');
        connectionTry++;
        connectToDevice(device);
      } else {
        connectionTry = 0;
        if (e is FlutterBluePlusException && e.code == 133) {
          printLog('Error específico de Android con código 133: $e');
          showToast('Error de conexión, intentelo nuevamente');
        } else {
          printLog('Error al conectar: $e $stackTrace');
          showToast('Error al conectar, intentelo nuevamente');
        }
      }
    }
  }

  void reescan() async {
    FlutterBluePlus.isScanningNow ? await FlutterBluePlus.stopScan() : null;
    await Future.delayed(const Duration(seconds: 2));
    context.mounted
        ? setState(() {
            devices.clear();
          })
        : null;
    scan();
    _controller.finishRefresh();
  }

  @override
  Widget build(BuildContext context) {
    final filteredDevices = sortedDevices.where((device) {
      final deviceName = nicknamesMap[device.platformName]?.toLowerCase() ??
          device.platformName.toLowerCase();
      return deviceName.contains(searchQuery);
    }).toList();

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: color1,
      appBar: AppBar(
        backgroundColor: color3,
        title: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          child: AnimSearchBar(
            width: MediaQuery.of(context).size.width * 0.8,
            textController: searchController,
            onSuffixTap: () {
              setState(() {
                printLog('ANASHARDO TERRARIUM EPICARDOPOLIS');
                searchQuery = '';
                toggle = 0;
              });
            },
            onSubmitted: (value) {
              setState(() {
                searchQuery = value.toLowerCase();
              });
            },
            rtl: false,
            autoFocus: true,
            helpText: "",
            suffixIcon: const Icon(
              Icons.clear,
              color: color3,
            ),
            prefixIcon: toggle == 1
                ? const Icon(
                    Icons.arrow_back_ios,
                    color: color3,
                  )
                : const Icon(
                    Icons.search,
                    color: color3,
                  ),
            animationDurationInMilli: 400,
            color: color0,
            textFieldColor: color0,
            searchIconColor: color3,
            textFieldIconColor: color3,
            style: const TextStyle(
              color: color3,
            ),
            onTap: () {
              setState(() {
                printLog('Eso Tilin si fuera campana, tilin tilin');
                toggle = 1;
              });
            },
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(HugeIcons.strokeRoundedUserCircle, size: 40.0),
            color: color0,
            onPressed: () {
              navigatorKey.currentState?.pushNamed('/profile');
            },
          ),
        ],
      ),
      body: EasyRefresh(
        controller: _controller,
        header: const ClassicHeader(
          dragText: 'Desliza para escanear',
          armedText:
              'Suelta para escanear\nO desliza para arriba para cancelar',
          readyText: 'Escaneando dispositivos',
          processingText: 'Escaneando dispositivos',
          processedText: 'Escaneo completo',
          showMessage: false,
          textStyle: TextStyle(color: color3),
          iconTheme: IconThemeData(color: color3),
        ),
        onRefresh: () async {
          reescan();
        },
        child: filteredDevices.isEmpty
            ? ListView(
                children: const [
                  Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(
                        child: Text(
                          'Deslice el dedo hacia abajo para buscar nuevos dispositivos cercanos',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: color3,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : ListView.builder(
                itemCount: filteredDevices.length,
                itemBuilder: (context, index) {
                  final device = filteredDevices[index];
                  final imagePath = deviceImages[device.platformName];
                  final isTouched =
                      _touchedDeviceId == device.remoteId.toString();

                  List<dynamic> admins = globalDATA[
                              '${DeviceManager.getProductCode(device.platformName)}/${DeviceManager.extractSerialNumber(device.platformName)}']
                          ?['secondary_admin'] ??
                      [];
                  bool owner = globalDATA[
                                  '${DeviceManager.getProductCode(device.platformName)}/${DeviceManager.extractSerialNumber(device.platformName)}']
                              ?['owner'] ==
                          currentUserEmail ||
                      admins.contains(device.platformName) ||
                      globalDATA['${DeviceManager.getProductCode(device.platformName)}/${DeviceManager.extractSerialNumber(device.platformName)}']
                              ?['owner'] ==
                          '' ||
                      globalDATA['${DeviceManager.getProductCode(device.platformName)}/${DeviceManager.extractSerialNumber(device.platformName)}']
                              ?['owner'] ==
                          null;
                  bool condicion =
                      DeviceManager.getProductCode(device.platformName) !=
                              '015773_IOT' &&
                          owner &&
                          quickAccess.contains(device.platformName);

                  return FadeTransition(
                    opacity: _animationController
                        .drive(CurveTween(curve: Curves.easeOut)),
                    child: ScaleTransition(
                      scale: _animationController
                          .drive(CurveTween(curve: Curves.easeOut)),
                      child: GestureDetector(
                        onTapDown: (_) {
                          setState(() {
                            _touchedDeviceId = device.remoteId.toString();
                          });
                        },
                        onTap: () {
                          setState(() {
                            _touchedDeviceId = device.remoteId.toString();
                          });

                          Future.delayed(const Duration(milliseconds: 200), () {
                            setState(() {
                              _touchedDeviceId = null;
                            });
                          });

                          showToast('Intentando conectarse al equipo');
                          connectToDevice(device);
                        },
                        onTapUp: (_) {
                          Future.delayed(const Duration(milliseconds: 200), () {
                            setState(() {
                              _touchedDeviceId = null;
                            });
                          });
                        },
                        onTapCancel: () {
                          setState(() {
                            _touchedDeviceId = null;
                          });
                        },
                        child: AnimatedScale(
                          scale: isTouched ? 0.95 : 1.0,
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOut,
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: AspectRatio(
                              aspectRatio: 1.5,
                              child: Card(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15.0),
                                ),
                                elevation: 8,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(15.0),
                                  child: Stack(
                                    children: [
                                      Positioned.fill(
                                        child: imagePath != null
                                            ? Image.file(
                                                File(imagePath),
                                                fit: BoxFit.cover,
                                              )
                                            : Image.asset(
                                                ImageManager.rutaDeImagen(
                                                  device.platformName,
                                                ),
                                                fit: BoxFit.cover,
                                              ),
                                      ),
                                      Positioned.fill(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                Colors.transparent,
                                                Colors.black
                                                    .withValues(alpha: 0.7),
                                              ],
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        top: 16,
                                        left: 16,
                                        child: SizedBox(
                                          width: 270,
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  nicknamesMap[device
                                                          .platformName] ??
                                                      DeviceManager
                                                          .getComercialName(
                                                        device.platformName,
                                                      ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: GoogleFonts.poppins(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 22,
                                                    color: Colors.white,
                                                    shadows: const [
                                                      Shadow(
                                                        offset:
                                                            Offset(-1.5, -1.5),
                                                        color: Colors.black,
                                                      ),
                                                      Shadow(
                                                        offset:
                                                            Offset(1.5, -1.5),
                                                        color: Colors.black,
                                                      ),
                                                      Shadow(
                                                        offset:
                                                            Offset(1.5, 1.5),
                                                        color: Colors.black,
                                                      ),
                                                      Shadow(
                                                        offset:
                                                            Offset(-1.5, 1.5),
                                                        color: Colors.black,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        bottom: 16,
                                        left: 16,
                                        right: 16,
                                        child: Text(
                                          device.platformName,
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        top: 16,
                                        right: 16,
                                        child: Container(
                                          padding: const EdgeInsets.all(4.0),
                                          decoration: const BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            HugeIcons
                                                .strokeRoundedBluetoothCircle,
                                            size: 30,
                                            color: Colors.black,
                                          ),
                                        ),
                                      ),
                                      if (condicion) ...[
                                        Positioned(
                                          bottom: 16,
                                          right: 16,
                                          child: quickAction
                                              ? const CircularProgressIndicator(
                                                  color: color1,
                                                )
                                              : Transform.scale(
                                                  scale: 1.33,
                                                  child: Switch(
                                                    value: globalDATA[
                                                                '${DeviceManager.getProductCode(device.platformName)}/${DeviceManager.extractSerialNumber(device.platformName)}']
                                                            ?['w_status'] ??
                                                        false,
                                                    activeColor: color1,
                                                    onChanged:
                                                        (bool newValue) async {
                                                      setState(() {
                                                        quickAction = true;
                                                        globalDATA['${DeviceManager.getProductCode(device.platformName)}/${DeviceManager.extractSerialNumber(device.platformName)}']
                                                                ?['w_status'] =
                                                            newValue;
                                                      });
                                                      await device.connect(
                                                        timeout: const Duration(
                                                            seconds: 6),
                                                      );
                                                      if (device.isConnected) {
                                                        printLog(
                                                            "Arranca por la derecha la maquina del sexo tilin",
                                                            "cyan");
                                                        MyDevice myDevice =
                                                            MyDevice();
                                                        myDevice
                                                            .setup(device)
                                                            .then(
                                                                (valor) async {
                                                          printLog(
                                                              'RETORNASHE $valor');
                                                          connectionTry = 0;
                                                          if (valor) {
                                                            printLog(
                                                                "Tengo sexo en monopatin",
                                                                "cyan");
                                                            await controlDeviceBLE(
                                                                device
                                                                    .platformName,
                                                                newValue);
                                                            await myDevice
                                                                .device
                                                                .disconnect();
                                                            setState(() {
                                                              quickAction =
                                                                  false;
                                                            });
                                                            printLog(
                                                                "¿Se me cayo la pichula? ${device.isDisconnected}",
                                                                "cyan");
                                                          } else {
                                                            printLog(
                                                                'Fallo en el setup');
                                                            showToast(
                                                                "Error con el acceso rápido\nIntente nuevamente");
                                                            myDevice.device
                                                                .disconnect();
                                                          }
                                                        });
                                                      } else {
                                                        printLog(
                                                          "Fallecio el sexo",
                                                          "cyan",
                                                        );
                                                        showToast(
                                                            "Error con el acceso rápido\nIntente nuevamente");
                                                      }
                                                    },
                                                  ),
                                                ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
