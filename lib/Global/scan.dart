import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:caldensmart/Global/watchers.dart';
import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import '../master.dart';
import '../aws/mqtt/mqtt.dart';
import 'package:caldensmart/logger.dart';

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
  Map<String, int> deviceRssi = {};
  Set<String> lostDevices = {};
  Timer? _updateTimer;
  bool _needsUpdate = false;
  Timer? _cleanupTimer;
  int connectionTry = 0;
  final TextEditingController searchController = TextEditingController();
  late AnimationController _animationController;
  final EasyRefreshController _controller = EasyRefreshController(
    controlFinishRefresh: true,
  );
  StreamSubscription<List<ScanResult>>? listener;
  String? _touchedDeviceId;
  String? _connectingDeviceId;

  @override
  void initState() {
    super.initState();
    BluetoothWatcher().start();
    List<dynamic> lista = dbData['Keywords'] ?? [];
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
    _cleanupTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        _removeLostDevices();
      }
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    _cleanupTimer?.cancel();
    _animationController.dispose();
    searchController.dispose();
    _controller.dispose();
    listener?.cancel();
    BluetoothWatcher().dispose();
    super.dispose();
  }

  Icon _signal(int rssi, {bool isLost = false}) {
    if (isLost) {
      return const Icon(HugeIcons.strokeRoundedFullSignal,
          color: Colors.white, size: 24);
    }
    if (rssi >= -60) {
      // Mejor señal: FullSignalIconPlus
      return const Icon(HugeIcons.strokeRoundedMediumSignal,
          color: Colors.white, size: 24);
    } else if (rssi >= -75) {
      // Señal media: MediumSignalIcon
      return const Icon(HugeIcons.strokeRoundedLowSignal,
          color: Colors.white, size: 24);
    } else {
      // Señal baja: LowSignalIcon
      return const Icon(HugeIcons.strokeRoundedSignalFull02,
          color: Colors.white, size: 24);
    }
  }

  void scan() async {
    printLog.i('Jiji');
    if (bluetoothOn) {
      printLog.i('Entre a escanear');
      toastFlag = false;
      try {
        FlutterBluePlus.isScanningNow ? FlutterBluePlus.stopScan() : null;
        await FlutterBluePlus.startScan(
          withKeywords: keywords,
          androidUsesFineLocation: true,
          continuousUpdates: true,
        );

        listener = FlutterBluePlus.scanResults.listen(
          (results) {
            if (!mounted) return;
            _processScanResults(results);
          },
        );
      } catch (e, stackTrace) {
        printLog.e('Error al escanear $e $stackTrace');
        showToast('Error al escanear, intentelo nuevamente');
      }
    }
  }

  void _processScanResults(List<ScanResult> results) {
    bool hasChanges = false;

    for (ScanResult result in results) {
      deviceRssi[result.device.remoteId.toString()] = result.rssi;

      if (!devices.any((device) => device.remoteId == result.device.remoteId)) {
        devices.add(result.device);
        hasChanges = true;
      }

      // Si el dispositivo vuelve a aparecer, quitarlo de la lista de perdidos
      String deviceId = result.device.remoteId.toString();
      if (lostDevices.contains(deviceId)) {
        lostDevices.remove(deviceId);
        hasChanges = true;
      }

      lastSeenDevices[result.device.remoteId.toString()] = result.timeStamp;
    }

    // Solo actualizar UI si hay cambios y usando debouncing
    if (hasChanges && !_needsUpdate) {
      _needsUpdate = true;
      _updateTimer?.cancel();
      _updateTimer = Timer(const Duration(milliseconds: 300), () {
        if (mounted && _needsUpdate) {
          setState(() {
            sortedDevices = List.from(devices);
            _needsUpdate = false;
          });
        }
      });
    }

    // Llamar a _removeLostDevices con menos frecuencia
    if (mounted) {
      _removeLostDevices();
    }
  }

  void _removeLostDevices() {
    if (!context.mounted) return;

    DateTime now = DateTime.now();
    List<String> devicesToMarkAsLost = [];

    // Identificar dispositivos a marcar como perdidos
    for (var device in devices) {
      final lastSeen = lastSeenDevices[device.remoteId.toString()];
      String deviceId = device.remoteId.toString();

      if (lastSeen != null &&
          now.difference(lastSeen).inSeconds > 12 &&
          !lostDevices.contains(deviceId)) {
        devicesToMarkAsLost.add(deviceId);
        // printLog.i('Marcando como perdido: ${device.platformName}');
      }
    }

    //  Solo actualizar si hay dispositivos que marcar como perdidos
    if (devicesToMarkAsLost.isNotEmpty || lostDevices.isNotEmpty) {
      setState(() {
        lostDevices.addAll(devicesToMarkAsLost);
        sortedDevices = List.from(devices);
      });
    }
  }

  void connectToDevice(BluetoothDevice device) async {
    if (isConnecting) return;

    setState(() {
      isConnecting = true;
      _connectingDeviceId = device.remoteId.toString();
    });
    try {
      printLog.i('Marca de tiempo ${DateTime.now().toIso8601String()}');
      await device.connect(timeout: const Duration(seconds: 6));
      deviceName = device.platformName;

      //printLog.i('Teoricamente estoy conectado');

      BluetoothManager bluetoothManager = BluetoothManager();

      // Setup global connection listener instead of local one
      var conenctionSub =
          device.connectionState.listen((BluetoothConnectionState state) {
        printLog.i('Estado de conexión: $state');
        switch (state) {
          case BluetoothConnectionState.connected:
            {
              if (!quickAction) {
                if (!connectionFlag) {
                  connectionFlag = true;
                  FlutterBluePlus.isScanningNow
                      ? FlutterBluePlus.stopScan()
                      : null;
                  bluetoothManager.setup(device).then((valor) {
                    printLog.i('RETORNASHE $valor');
                    connectionTry = 0;
                    if (valor) {
                      // Setup local connection listener for normal connections
                      _setupNormalConnectionListener(device);
                      navigatorKey.currentState
                          ?.pushReplacementNamed('/loading');
                    } else {
                      if (mounted) {
                        setState(() {
                          isConnecting = false;
                          _connectingDeviceId = null;
                          connectionFlag = false;
                        });
                      }
                      printLog.i('Fallo en el setup');
                      showToast('Error en el dispositivo, intente nuevamente');
                      bluetoothManager.device.disconnect();
                    }
                  });
                } else {
                  printLog.i('Las chistosadas se apoderan del mundo');
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
      if (mounted) {
        setState(() {
          isConnecting = false;
          _connectingDeviceId = null;
        });
      }
      if (connectionTry < 3) {
        printLog.e('Retry');
        connectionTry++;
        connectToDevice(device);
      } else {
        connectionTry = 0;
        if (e is FlutterBluePlusException && e.code == 133) {
          printLog.i('Error específico de Android con código 133: $e');
          showToast('Error de conexión, intentelo nuevamente');
        } else {
          printLog.i('Error al conectar: $e $stackTrace');
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
            lostDevices.clear();
            lastSeenDevices.clear();
            _connectingDeviceId = null;
            isConnecting = false;
          })
        : null;
    scan();
    _controller.finishRefresh();
  }

  /// Configura el listener de conexión para conexiones normales (no acciones rápidas)
  void _setupNormalConnectionListener(BluetoothDevice device) {
    StreamSubscription<BluetoothConnectionState>? localConnectionSub;

    localConnectionSub =
        device.connectionState.listen((BluetoothConnectionState state) {
      printLog.i('Estado de conexión normal: $state');

      if (state == BluetoothConnectionState.disconnected) {
        printLog.e('Dispositivo desconectado - Conexión normal');

        // Mostrar toast
        showToast('Dispositivo desconectado');

        // Limpiar variables globales
        cleanGlobalDeviceVariables();

        // Navegar al menú
        navigatorKey.currentState?.pushReplacementNamed('/menu');

        // Cancelar este listener ya que la conexión terminó
        localConnectionSub?.cancel();
      }
    });

    // Asegurar que el listener se cancele cuando el dispositivo se desconecte
    device.cancelWhenDisconnected(localConnectionSub, delayed: true);
  }

  void _runQuickAction(BluetoothDevice device, bool newValue) async {
    // printLog.i("=== INICIANDO ACCIÓN RÁPIDA ===");
    // printLog.i("Dispositivo: ${device.platformName}");
    // printLog.i("Nuevo valor: $newValue");

    setState(() {
      quickAction = true;
    });

    try {
      await _quickConnectAndSend(device, newValue)
          .timeout(const Duration(seconds: 15));

      // Solo si fue exitoso, actualizar el switch visualmente
      final String productCode =
          DeviceManager.getProductCode(device.platformName);
      final String serialNumber =
          DeviceManager.extractSerialNumber(device.platformName);
      setState(() {
        if (productCode == '020010_IOT' ||
            productCode == '020020_IOT' ||
            (productCode == '027313_IOT' &&
                Versioner.isPosterior(
                    globalDATA['$productCode/$serialNumber']
                            ?['HardwareVersion'] ??
                        '999999A',
                    '241220A'))) {
          // Para estos productos, actualizar el JSON específico del pin
          try {
            String pinValue = pinQuickAccess[device.platformName] ?? '0';
            String ioKey = 'io${int.tryParse(pinValue) ?? 0}';
            String? existingJson =
                globalDATA['$productCode/$serialNumber']?[ioKey];

            if (existingJson != null) {
              Map<String, dynamic>? decoded = jsonDecode(existingJson);
              if (decoded != null) {
                decoded['w_status'] = newValue;
                globalDATA['$productCode/$serialNumber']?[ioKey] =
                    jsonEncode(decoded);
              }
            }
          } catch (e) {
            printLog.e('Error actualizando JSON específico: $e');
          }
        } else {
          // Para otros productos, actualizar w_status directamente
          globalDATA['$productCode/$serialNumber']?['w_status'] = newValue;
        }

        quickAction = false;
      });

      showToast('Comando enviado correctamente');
    } catch (e) {
      printLog.e("Error en acción rápida: $e");

      setState(() {
        quickAction = false;
      });

      if (e is TimeoutException) {
        printLog.i("Timeout en acción rápida después de 15 segundos");
        showToast('Timeout: Operación muy lenta, cancelada');
      } else {
        showToast('Error en acción rápida');
      }
    }
  }

  Future<void> _quickConnectAndSend(
      BluetoothDevice device, bool newValue) async {
    final String deviceName = device.platformName;
    final String productCode = DeviceManager.getProductCode(deviceName);
    final String serialNumber = DeviceManager.extractSerialNumber(deviceName);

    // NO actualizar globalDATA aquí - solo si es exitoso
    await device.connect(
      timeout: const Duration(seconds: 6),
    );
    if (device.isConnected) {
      printLog.i(
        "Arranca por la derecha la maquina del sexo tilin",
      );
      BluetoothManager bluetoothManager = BluetoothManager();
      bluetoothManager.setup(device).then((valor) async {
        printLog.i('RETORNASHE $valor');
        connectionTry = 0;
        if (valor) {
          printLog.i(
            "Tengo sexo en monopatin",
          );
          // printLog.i(
          //     "Voy a ${newValue ? 'Encender' : 'Apagar'} el equipo $deviceName");

          if (productCode == '020010_IOT' ||
              productCode == '020020_IOT' ||
              (productCode == '027313_IOT' &&
                  Versioner.isPosterior(
                      globalDATA['$productCode/$serialNumber']
                              ?['HardwareVersion'] ??
                          '999999A',
                      '241220A'))) {
            String pinValue = pinQuickAccess[deviceName] ?? '0';
            String fun = '$pinValue#${newValue ? '1' : '0'}';
            bluetoothManager.ioUuid.write(fun.codeUnits);
            String topic = 'devices_rx/$productCode/$serialNumber';
            String topic2 = 'devices_tx/$productCode/$serialNumber';
            String message = jsonEncode({
              'index': int.parse(pinValue),
              'w_status': newValue,
              'r_state': "0",
              'pinType': 0
            });
            sendMessagemqtt(topic, message);
            sendMessagemqtt(topic2, message);

            globalDATA
                .putIfAbsent('$productCode/$serialNumber', () => {})
                .addAll({'io${pinQuickAccess[device.platformName]!}': message});
          } else {
            int fun = newValue ? 1 : 0;
            String data = '$productCode[11]($fun)';
            bluetoothManager.toolsUuid.write(data.codeUnits);
            globalDATA['$productCode/$serialNumber']!['w_status'] = newValue;

            try {
              String topic = 'devices_rx/$productCode/$serialNumber';
              String topic2 = 'devices_tx/$productCode/$serialNumber';
              String message = jsonEncode({'w_status': newValue});
              sendMessagemqtt(topic, message);
              sendMessagemqtt(topic2, message);
            } catch (e, s) {
              printLog.e('Error al enviar valor en cdBLE $e $s');
            }
          }
          await bluetoothManager.device.disconnect();
          printLog.i(
            "¿Se me cayo la pichula? ${device.isDisconnected}",
          );
        } else {
          printLog.e('Fallo en el setup');
          showToast("Error con el acceso rápido\nIntente nuevamente");
          bluetoothManager.device.disconnect();
        }
      }).catchError((e, s) {
        printLog.e('Error en setup del dispositivo: $e');
        printLog.e('Stack trace: $s');
        showToast("Error con el acceso rápido\nIntente nuevamente");
        bluetoothManager.device.disconnect();
      });
    } else {
      printLog.e(
        "Fallecio el sexo",
      );
      showToast("Error con el acceso rápido\nIntente nuevamente");
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredDevices = sortedDevices.where((device) {
      final deviceName = nicknamesMap[device.platformName]?.toLowerCase() ??
          device.platformName.toLowerCase();
      return deviceName.contains(searchQuery);
    }).toList();

    try {
      return Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: color0,
        appBar: AppBar(
          backgroundColor: color1,
          title: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6.0),
            child: AnimSearchBar(
              width: MediaQuery.of(context).size.width * 0.8,
              textController: searchController,
              onSuffixTap: () {
                setState(() {
                  printLog.i('ANASHARDO TERRARIUM EPICARDOPOLIS');
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
                HugeIcons.strokeRoundedCancel01,
                color: color1,
              ),
              prefixIcon: toggle == 1
                  ? const Icon(
                      HugeIcons.strokeRoundedArrowLeft02,
                      color: color1,
                    )
                  : const Icon(
                      HugeIcons.strokeRoundedSearch01,
                      color: color1,
                    ),
              animationDurationInMilli: 400,
              color: color0,
              textFieldColor: color0,
              searchIconColor: color1,
              textFieldIconColor: color1,
              style: const TextStyle(
                color: color1,
              ),
              onTap: () {
                setState(() {
                  printLog.i('Eso Tilin si fuera campana, tilin tilin');
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
            textStyle: TextStyle(color: color1),
            iconTheme: IconThemeData(color: color1),
          ),
          onRefresh: () async {
            reescan();
          },
          child: filteredDevices.isEmpty
              ? ListView(
                  children: [
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              HugeIcons.strokeRoundedSearch01,
                              size: 80,
                              color: color1,
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'No se encontraron equipos nuevos',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: color1,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Puedes usar el menú de WiFi para controlar tus equipos desde cualquier distancia',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                color: color1,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: color1.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: color1.withValues(alpha: 0.3)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    HugeIcons.strokeRoundedDrag01,
                                    size: 24,
                                    color: color1,
                                  ),
                                  SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      'Desliza hacia abajo para escanear de nuevo',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: color1,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: color1.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: color1.withValues(alpha: 0.2)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    HugeIcons.strokeRoundedWifi02,
                                    size: 24,
                                    color: color1,
                                  ),
                                  SizedBox(width: 8),
                                  Icon(
                                    HugeIcons.strokeRoundedSwipeRight01,
                                    size: 20,
                                    color: color1,
                                  ),
                                  SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      'Desliza hacia la derecha para ir al menú WiFi',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: color1,
                                        fontWeight: FontWeight.w400,
                                      ),
                                      textAlign: TextAlign.center,
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
                )
              : ListView.builder(
                  itemCount: filteredDevices.length,
                  itemBuilder: (context, index) {
                    try {
                      final device = filteredDevices[index];
                      final imagePath = deviceImages[device.platformName];
                      final isTouched =
                          _touchedDeviceId == device.remoteId.toString();
                      final productCode =
                          DeviceManager.getProductCode(device.platformName);
                      final serialNumber = DeviceManager.extractSerialNumber(
                          device.platformName);
                      final rssi = deviceRssi[device.remoteId.toString()] ?? 0;

                      final isLost =
                          lostDevices.contains(device.remoteId.toString());

                      List<dynamic> admins =
                          globalDATA['$productCode/$serialNumber']
                                  ?['secondary_admin'] ??
                              [];
                      bool owner = globalDATA['$productCode/$serialNumber']
                                  ?['owner'] ==
                              currentUserEmail ||
                          admins.contains(currentUserEmail) ||
                          globalDATA['$productCode/$serialNumber']?['owner'] ==
                              '' ||
                          globalDATA['$productCode/$serialNumber']?['owner'] ==
                              null;
                      bool condicion = productCode != '015773_IOT' &&
                          owner &&
                          quickAccess.contains(device.platformName) &&
                          !isLost;

                      bool estadoWState = (productCode == '020010_IOT' ||
                              productCode == '020020_IOT' ||
                              (productCode == '027313_IOT' &&
                                  Versioner.isPosterior(
                                      globalDATA['$productCode/$serialNumber']
                                              ?['HardwareVersion'] ??
                                          '999999A',
                                      '241220A')))
                          ? () {
                              try {
                                String? jsonString = globalDATA[
                                        '$productCode/$serialNumber']?[
                                    'io${int.tryParse(pinQuickAccess[device.platformName] ?? '0') ?? 0}'];
                                if (jsonString != null) {
                                  Map<String, dynamic>? decoded =
                                      jsonDecode(jsonString);
                                  return decoded?['w_status'] ?? false;
                                }
                                return false;
                              } catch (e) {
                                return false;
                              }
                            }()
                          : (globalDATA['$productCode/$serialNumber']
                                  ?['w_status'] ??
                              false);

                      bool isThisDeviceLoading =
                          _connectingDeviceId == device.remoteId.toString();

                      return FadeTransition(
                        opacity: _animationController
                            .drive(CurveTween(curve: Curves.easeOut)),
                        child: ScaleTransition(
                          scale: _animationController
                              .drive(CurveTween(curve: Curves.easeOut)),
                          child: GestureDetector(
                            onTapDown: (isLost || isConnecting)
                                ? null
                                : (_) {
                                    setState(() {
                                      _touchedDeviceId =
                                          device.remoteId.toString();
                                    });
                                  },
                            onTap: (isLost || isConnecting)
                                ? (isLost
                                    ? () => showToast(
                                        'Dispositivo fuera de alcance...')
                                    : () => showToast(
                                        'Actualmente estas intentando conectarte a un equipo'))
                                : () {
                                    setState(() {
                                      _touchedDeviceId =
                                          device.remoteId.toString();
                                    });

                                    Future.delayed(
                                        const Duration(milliseconds: 200), () {
                                      if (mounted) {
                                        setState(() {
                                          _touchedDeviceId = null;
                                        });
                                      }
                                    });

                                    showToast(
                                        'Intentando conectarse al equipo');
                                    connectToDevice(device);
                                  },
                            onTapUp: (isLost || isConnecting)
                                ? null
                                : (_) {
                                    Future.delayed(
                                        const Duration(milliseconds: 200), () {
                                      setState(() {
                                        _touchedDeviceId = null;
                                      });
                                    });
                                  },
                            onTapCancel: (isLost || isConnecting)
                                ? null
                                : () {
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
                                  child: Opacity(
                                    opacity: isLost ? 0.4 : 1.0,
                                    child: Card(
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(15.0),
                                        side: BorderSide(
                                          color: isLost ? Colors.grey : color4,
                                          width: 2.0,
                                        ),
                                      ),
                                      elevation: isLost ? 2 : 8,
                                      child: ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(15.0),
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
                                                      Colors.black.withValues(
                                                          alpha: 0.7),
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
                                              child: Container(
                                                constraints: BoxConstraints(
                                                    maxWidth:
                                                        MediaQuery.of(context)
                                                                .size
                                                                .width *
                                                            0.6),
                                                child: Text(
                                                  nicknamesMap[device
                                                          .platformName] ??
                                                      DeviceManager
                                                          .getComercialName(
                                                        device.platformName,
                                                      ),
                                                  maxLines: 2,
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
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: Colors.black
                                                      .withValues(alpha: 0.6),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    const Icon(
                                                      HugeIcons
                                                          .strokeRoundedBluetooth,
                                                      size: 20,
                                                      color: Colors.white,
                                                    ),
                                                    const SizedBox(width: 10),
                                                    _signal(rssi,
                                                        isLost: isLost),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            Positioned(
                                              bottom: 16,
                                              right: 16,
                                              child: condicion
                                                  ? (quickAction
                                                      ? const CircularProgressIndicator(
                                                          color: color0)
                                                      : Transform.scale(
                                                          scale: 1.33,
                                                          child: Switch(
                                                            value: estadoWState,
                                                            activeThumbColor:
                                                                color0,
                                                            onChanged: (bool
                                                                    newValue) =>
                                                                _runQuickAction(
                                                                    device,
                                                                    newValue),
                                                          ),
                                                        ))
                                                  : const SizedBox(
                                                      width: 60,
                                                      height: 36,
                                                    ),
                                            ),
                                            if (isThisDeviceLoading) ...{
                                              Positioned.fill(
                                                child: Container(
                                                  color: Colors.black
                                                      .withValues(alpha: 0.4),
                                                  child: Center(
                                                    child: Image.asset(
                                                      'assets/branch/dragon.gif',
                                                      width: 150,
                                                      height: 150,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            }
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    } catch (e, s) {
                      printLog.e('Error al construir el dispositivo: $e');
                      printLog.t('Stack trace: $s');
                      return const SizedBox.shrink();
                    }
                  },
                ),
        ),
      );
    } catch (e, s) {
      printLog.e('Error en ScanPage: $e');
      printLog.t('Stack trace: $s');
      return const Scaffold(
        backgroundColor: color0,
        body: Center(
          child: Text(
            'Error al cargar la página de escaneo',
            style: TextStyle(color: color1, fontSize: 20),
          ),
        ),
      );
    }
  }
}
