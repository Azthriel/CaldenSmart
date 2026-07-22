import 'dart:convert';
import 'package:caldensmart/Global/stored_data.dart' show loadEmail;
import 'package:caldensmart/aws/dynamo/dynamo.dart';
import 'package:caldensmart/logger.dart';
import 'package:caldensmart/master.dart';
import 'package:caldensmart/widget/widget_handler.dart';
import 'package:caldensmart/widget/widget_models.dart';
import 'package:caldensmart/widget/widget_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Para MethodChannel
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';

class SelectDeviceScreen extends StatefulWidget {
  const SelectDeviceScreen({super.key});
  @override
  State<SelectDeviceScreen> createState() => _SelectDeviceScreenState();
}

class _SelectDeviceScreenState extends State<SelectDeviceScreen>
    with WidgetsBindingObserver {
  // Canal para hablar con Android (WidgetConfigActivity.kt)
  static const platform = MethodChannel('com.caldensmart.sime/widget_config');

  int? _widgetId;
  bool _isLoading = true;
  Map<String, bool> devicesToShow = {}; // Mapa ID -> esControl

  @override
  void initState() {
    super.initState();
    // Con engine cacheado (pre-calentado por MainApplication), este initState
    // corre UNA sola vez: al pre-calentar, cuando todavía NO hay una
    // WidgetConfigActivity attachada ni widgetId. Por eso escuchamos el ciclo
    // de vida: cuando la activity real se attachea y llega 'resumed',
    // re-pedimos el id y recién ahí cargamos.
    WidgetsBinding.instance.addObserver(this);
    _getWidgetId();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // La activity de config se attacheó (o volvió al frente) con un widgetId.
      _getWidgetId();
    }
  }

  // Pide el ID a la actividad nativa
  Future<void> _getWidgetId() async {
    try {
      final int widgetId = await platform.invokeMethod('getWidgetId');
      // 0 = INVALID_APPWIDGET_ID → estamos en el pre-calentado, sin activity.
      // No cargamos datos hasta tener un id real (evita queries al pedo).
      if (widgetId == 0) return;
      final bool isNew = widgetId != _widgetId;
      setState(() {
        _widgetId = widgetId;
      });
      printLog.d("Configurando Widget ID: $_widgetId");
      // Cargamos solo si es un widget nuevo (o el primero válido).
      if (isNew) _loadInitialData();
    } catch (e) {
      // MissingPluginException en el pre-calentado (aún no hay handler nativo)
      // u otro error: no cargamos, esperamos al 'resumed' de la activity real.
      printLog.e("getWidgetId aún no disponible: $e");
    }
  }

  Future<void> _loadInitialData() async {
    try {
      setState(() => _isLoading = true);

      await DeviceManager.init();

      currentUserEmail = await loadEmail();
      previusConnections = await getPreviusConnections(currentUserEmail);
      printLog.d('Previus connections: $previusConnections');
      List<String> orderedConnections = List.from(getOrderedDeviceList());
      printLog.d('Ordered connections: $orderedConnections');
      nicknamesMap = await getNicknames(currentUserEmail);

      // ── Fase 1: consultar TODOS los equipos en PARALELO ─────────────────────
      // Antes se hacía un `await queryItems` secuencial por equipo dentro del
      // for → con 31 equipos eran 31 consultas a DynamoDB una atrás de otra, y
      // la pantalla quedaba "clavada" cargando. Son consultas de red e
      // independientes (no BLE), así que se disparan todas juntas. Cada una
      // atrapa su propio error para que una falla no aborte el resto.
      await Future.wait(
        orderedConnections.map((device) async {
          final pc = DeviceManager.getProductCode(device);
          final sn = DeviceManager.extractSerialNumber(device);
          try {
            await queryItems(pc, sn);
          } catch (e) {
            printLog.e('Error consultando $pc/$sn: $e');
          }
        }),
      );

      // ── Fase 2: procesar los resultados (ya cacheados en globalDATA) ────────
      // Sin awaits: solo lee globalDATA que la fase 1 dejó poblado.
      for (String device in orderedConnections) {
        final pc = DeviceManager.getProductCode(device);
        final sn = DeviceManager.extractSerialNumber(device);
        Map<String, dynamic> deviceDATA = globalDATA['$pc/$sn'] ?? {};
        List<String> admins =
            List<String>.from(globalDATA['$pc/$sn']?['secondary_admin'] ?? []);
        String ownerEmail = globalDATA['$pc/$sn']?['owner'] ?? '';

        // Verificar si el usuario puede controlar el dispositivo
        bool canControlDevice = ownerEmail == currentUserEmail ||
            admins.contains(currentUserEmail) ||
            ownerEmail == '';

        if (canControlDevice) {
          bool ioDevice = false;

          // Verificar hasEntry para dispositivos que pueden tener entrada
          // Por defecto false si no existe (para compatibilidad con equipos viejos)
          bool hasEntry = deviceDATA['hasEntry'] ?? false;
          bool isRiego = deviceDATA['riegoActive'] == true;

          if (isRiego) continue; // Saltar dispositivos de riego

          deviceDATA.forEach((key, value) {
            if (key.startsWith('io') && value is String) {
              ioDevice = true;
              var decoded = jsonDecode(value);
              int pinType = int.tryParse(decoded['pinType'].toString()) ?? 0;
              int index = int.tryParse(decoded['index'].toString()) ?? 0;

              // pinType == 0 es salida (control)
              // pinType == 1 es entrada (visualización)
              bool isOutput = pinType == 0;

              // Solo mostrar entradas si hasEntry es true
              if (isOutput) {
                // Salidas siempre se muestran (son de control)
                devicesToShow.addAll({'${device}_$index': true});
              } else {
                // Entradas solo si hasEntry es true (son de visualización)
                if (pc == '027313_IOT' && !hasEntry) {
                } else {
                  devicesToShow.addAll({'${device}_$index': false});
                }
              }
              // Si pinType == 1 y hasEntry == false, no se agrega
            }
          });

          if (!ioDevice) {
            // Dispositivos que no son IO.
            // Excluir los que no deben tener widget (Riel, etc.)
            if (!shouldHaveWidget(pc)) continue;

            // Solo estos son de visualización pura (sin control on/off):
            // 023430_IOT = Termómetro, 015773_IOT = Detector
            // El roller (024011_IOT) SÍ es controlable (abre/cierra)
            bool onOffDevice = pc != '023430_IOT' && pc != '015773_IOT';
            devicesToShow.addAll({device: onOffDevice});
          }
        }
      }

      // ---------------------
    } catch (e) {
      printLog.e('Error cargando datos: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

// Función para guardar la configuración cuando el usuario elige un dispositivo
  Future<void> _onDeviceSelected(String deviceKey) async {
    if (_widgetId == null) return;

    try {
      setState(() => _isLoading = true);

      final String pc = DeviceManager.getProductCode(deviceKey.split('_')[0]);
      final String sn =
          DeviceManager.extractSerialNumber(deviceKey.split('_')[0]);

      // ── Nickname ────────────────────────────────────────────────────────
      String nickname;
      if (deviceKey.contains('_')) {
        final String bName = deviceKey.split('_')[0];
        final String bIdx = deviceKey.split('_')[1];
        final String bPc = DeviceManager.getProductCode(bName);
        final String bSn = DeviceManager.extractSerialNumber(bName);
        final bool bHasEntry = globalDATA['$bPc/$bSn']?['hasEntry'] ?? false;
        if (bIdx == '0' && !bHasEntry && bPc == '027313_IOT') {
          nickname = nicknamesMap[bName] ?? bName;
        } else {
          nickname = nicknamesMap[deviceKey] ??
              '${nicknamesMap[bName] ?? bName} pin $bIdx';
        }
      } else {
        nickname = nicknamesMap[deviceKey] ?? deviceKey;
      }

      // ── Tipo e índice IO ────────────────────────────────────────────────
      final WidgetType widgetType;
      int? ioIndex;

      if (deviceKey.contains('_')) {
        final int idx = int.tryParse(deviceKey.split('_')[1]) ?? 0;
        ioIndex = idx;
        final String ioKey = 'io$idx';
        final deviceData = globalDATA['$pc/$sn'];
        final ioRaw = deviceData?[ioKey];
        if (ioRaw != null) {
          final Map<String, dynamic> ioMap = ioRaw is String
              ? jsonDecode(ioRaw)
              : Map<String, dynamic>.from(ioRaw as Map);
          final bool isInput = (ioMap['pinType']?.toString() ?? '0') != '0';
          widgetType = isInput ? WidgetType.display : WidgetType.control;
        } else {
          widgetType = WidgetType.control;
        }
      } else {
        widgetType = getWidgetType(pc);
        ioIndex = null;
      }

      // ── Crear WidgetData ────────────────────────────────────────────────
      final widgetData = WidgetData(
        widgetId: _widgetId!,
        deviceName: deviceKey,
        productCode: pc,
        serialNumber: sn,
        nickname: nickname,
        type: widgetType,
        ioIndex: ioIndex,
      );

      // ── Construir estado inicial ─────────────────────────────────────────
      final WidgetDeviceState deviceState =
          WidgetService.extractDeviceState(pc, sn, ioIndex);

      // ── Guardar config y estado atómico ─────────────────────────────────
      // CRÍTICO: estos dos deben completarse antes de finishConfig
      await WidgetService.saveWidgetConfig(widgetData);
      await WidgetService.updateWidget(widgetData, deviceState);
      await registerWidgetId(_widgetId!);

      printLog.i(
          'Widget $_widgetId guardado: $nickname ($deviceKey) tipo=$widgetType');

      // ── Iniciar servicio de background (no bloquea el resultado) ─────────
      try {
        await initializeWidgetService().timeout(
          const Duration(seconds: 8),
          onTimeout: () => printLog
              .i('initializeWidgetService timeout, continúa de todas formas'),
        );
      } catch (e) {
        // No crítico: el WorkManager periódico lo levantará en el siguiente ciclo
        printLog.i('initializeWidgetService falló (no crítico): $e');
      }

      // ── Cerrar la actividad de config PRIMERO ────────────────────────────
      // finishConfig va antes de initializeWidgetService para que Android nunca
      // devuelva RESULT_CANCELED si el servicio tarda o falla.
      await platform.invokeMethod('finishConfig');
    } catch (e) {
      printLog.e('Error guardando configuración: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. Pantalla de Carga (Tu diseño)
    if (_isLoading) {
      return Scaffold(
        backgroundColor: color0,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Asegúrate de que esta imagen exista o usa un Icono por ahora
                // const Icon(Icons.download_for_offline_outlined,
                //     size: 100, color: color1),
                //onst SizedBox(height: 20),
                // Text(
                //   'Cargando dispositivos...',
                //   textAlign: TextAlign.center,
                //   style: GoogleFonts.poppins(
                //     fontSize: 16,
                //     fontWeight: FontWeight.bold,
                //     color: color1,
                //   ),
                // ),
                const SizedBox(height: 20),
                Image.asset('assets/branch/dragon.gif',
                    width: 150, height: 150),
              ],
            ),
          ),
        ),
      );
    }

    // 2. Pantalla de Selección
    return Scaffold(
      backgroundColor: color0,
      appBar: AppBar(
        title: Text('Selecciona un dispositivo',
            style: GoogleFonts.poppins(
                color: color0, fontWeight: FontWeight.bold)),
        backgroundColor: color1,
        iconTheme: const IconThemeData(color: color0),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              if (devicesToShow.isEmpty)
                Center(
                  child: Text("No hay dispositivos registrados",
                      style: GoogleFonts.poppins(color: Colors.white38)),
                )
              else
                ...devicesToShow.entries.map((device) {
                  String pc =
                      DeviceManager.getProductCode(device.key.split('_')[0]);
                  String sn = DeviceManager.extractSerialNumber(
                      device.key.split('_')[0]);
                  bool isOnline = globalDATA['$pc/$sn']?['cstate'] ?? false;

                  String nickname;
                  if (device.key.contains('_')) {
                    final String bName = device.key.split('_')[0];
                    final String bIdx = device.key.split('_')[1];
                    final String bPc = DeviceManager.getProductCode(bName);
                    final String bSn = DeviceManager.extractSerialNumber(bName);
                    final bool bHasEntry =
                        globalDATA['$bPc/$bSn']?['hasEntry'] ?? false;
                    if (bIdx == '0' && !bHasEntry && bPc == '027313_IOT') {
                      nickname = nicknamesMap[bName] ?? bName;
                    } else {
                      nickname = nicknamesMap[device.key] ??
                          '${nicknamesMap[bName] ?? bName} pin $bIdx';
                    }
                  } else {
                    nickname = nicknamesMap[device.key] ?? device.key;
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: InkWell(
                      onTap: () => _onDeviceSelected(device.key),
                      borderRadius: BorderRadius.circular(15),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E1E),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Colors.white10, width: 0.5),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              decoration: const BoxDecoration(
                                color: color1,
                                borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(15),
                                    topRight: Radius.circular(15)),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                      pc == '024011_IOT'
                                          ? HugeIcons.strokeRoundedArrowUpDown
                                          : device.value
                                              ? HugeIcons.strokeRoundedToggleOn
                                              : HugeIcons.strokeRoundedView,
                                      color: color0,
                                      size: 16),
                                  const SizedBox(width: 8),
                                  Text(
                                      pc == '024011_IOT'
                                          ? 'CORTINA'
                                          : device.value
                                              ? 'CONTROL'
                                              : 'LECTURA',
                                      style: GoogleFonts.poppins(
                                          color: color0,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.2)),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          nickname,
                                          style: GoogleFonts.poppins(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 5),
                                          decoration: BoxDecoration(
                                            color: isOnline
                                                ? Colors.green
                                                    .withValues(alpha: 0.1)
                                                : Colors.white
                                                    .withValues(alpha: 0.05),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                width: 7,
                                                height: 7,
                                                decoration: BoxDecoration(
                                                  color: isOnline
                                                      ? Colors.greenAccent
                                                      : color3,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                isOnline
                                                    ? 'En línea'
                                                    : 'Desconectado',
                                                style: GoogleFonts.poppins(
                                                  color: isOnline
                                                      ? Colors.greenAccent
                                                      : color3,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    HugeIcons.strokeRoundedArrowRight01,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}
