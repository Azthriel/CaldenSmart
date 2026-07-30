import 'dart:convert';
import 'package:caldensmart/global/stored_data.dart' show loadEmail;
import 'package:caldensmart/aws/dynamo/dynamo.dart';
import 'package:caldensmart/logger.dart';
import 'package:caldensmart/master.dart';
import 'package:caldensmart/widget/widget_handler.dart';
import 'package:caldensmart/widget/widget_models.dart';
import 'package:caldensmart/widget/widget_service.dart';
import 'package:caldensmart/widget/event_widget_models.dart';
import 'package:caldensmart/widget/event_widget_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Para MethodChannel
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';

/// Opción de evento widgetizable en la lista.
class _EventOption {
  final EventWidgetKind kind;
  final String name;

  /// Equipos que integran el evento. Se guarda en el widget para poder contar
  /// desde el background cuántos están caídos.
  final List<String> deviceGroup;

  const _EventOption(this.kind, this.name, this.deviceGroup);
}

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

  /// Bloquea toda la pantalla. Se libera apenas están los eventos, que salen de
  /// un solo getItem; los equipos siguen cargando abajo con su propio spinner.
  bool _isLoading = true;

  /// Los equipos necesitan una query por equipo (31 en paralelo en el peor
  /// caso). No tiene sentido que retrasen la lista de eventos.
  bool _devicesLoading = true;

  /// Se pone en true mientras se guarda la configuración elegida.
  bool _isSaving = false;

  /// La sesión anterior terminó en finishConfig.
  ///
  /// Hace falta porque el engine está CACHEADO: al cerrarse la activity este
  /// State NO se destruye, se queda con los flags como quedaron. Sin esto,
  /// `_isSaving` quedaba en true para siempre y la próxima vez que se abría la
  /// config la pantalla se clavaba en el dragón.
  ///
  /// También cubre el caso de que Android reasigne el MISMO appWidgetId (pasa
  /// al borrar un widget y crear otro): ahí `widgetId != _widgetId` da false y
  /// sin este flag no se recargaría nada.
  bool _configDone = false;

  Map<String, bool> devicesToShow = {}; // Mapa ID -> esControl
  List<_EventOption> eventsToShow = [];

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

      final bool needsReload = _configDone || widgetId != _widgetId;
      _configDone = false;

      setState(() {
        _widgetId = widgetId;
        // Se limpia SIEMPRE: si venía en true de la config anterior, el build
        // se quedaba en la pantalla de carga sin salida.
        _isSaving = false;
      });
      printLog.d("Configurando Widget ID: $_widgetId (recarga: $needsReload)");
      if (needsReload) _loadInitialData();
    } catch (e) {
      // MissingPluginException en el pre-calentado (aún no hay handler nativo)
      // u otro error: no cargamos, esperamos al 'resumed' de la activity real.
      printLog.e("getWidgetId aún no disponible: $e");
    }
  }

  Future<void> _loadInitialData() async {
    // Reset por si se reconfigura el mismo engine con otro widget.
    devicesToShow = {};
    eventsToShow = [];
    setState(() {
      _isLoading = true;
      _devicesLoading = true;
    });

    currentUserEmail = await loadEmail();

    // ── Eventos primero: un solo getItem sobre Alexa-Devices ──────────────
    await _loadEvents();
    if (mounted) setState(() => _isLoading = false);

    // ── Equipos después, sin bloquear la UI ───────────────────────────────
    await _loadDevices();
    if (mounted) setState(() => _devicesLoading = false);
  }

  /// Carga los eventos widgetizables del usuario.
  ///
  /// Se filtran clima / horario / disparador: son eventos automáticos que
  /// dispara el backend solo, así que un widget para "activarlos a mano" no
  /// tendría sentido. Quedan cadena, riego y grupo, que son los que en la
  /// pantalla wifi tienen botón de activación manual.
  Future<void> _loadEvents() async {
    try {
      final eventos = await getEventos(currentUserEmail);
      final List<_EventOption> options = [];

      for (final ev in eventos) {
        final kind = eventWidgetKindFromEvento(ev['evento']?.toString());
        if (kind == null) continue;
        final nombre = ev['title']?.toString() ?? '';
        if (nombre.isEmpty) continue;
        options.add(
          _EventOption(kind, nombre, parseDeviceGroup(ev['deviceGroup'])),
        );
      }

      // Orden estable: por tipo y después alfabético.
      options.sort((a, b) {
        final c = a.kind.index.compareTo(b.kind.index);
        return c != 0 ? c : a.name.compareTo(b.name);
      });

      eventsToShow = options;
      printLog.d('Eventos widgetizables: ${eventsToShow.length}');
    } catch (e) {
      printLog.e('Error cargando eventos: $e');
    }
  }

  Future<void> _loadDevices() async {
    try {
      await DeviceManager.init();

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
    } catch (e) {
      printLog.e('Error cargando equipos: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Guardado
  // ══════════════════════════════════════════════════════════════════════════

  /// Guarda un widget de EVENTO.
  Future<void> _onEventSelected(_EventOption option) async {
    if (_widgetId == null) return;

    try {
      setState(() => _isSaving = true);

      final data = EventWidgetData(
        widgetId: _widgetId!,
        kind: option.kind,
        eventName: option.name,
        email: currentUserEmail,
        nickname: option.name,
      );

      await saveEventWidgetConfig(data);
      // Estado provisorio para que el widget no nazca en blanco.
      await writeEventWidgetState(data, EventWidgetState.idle(),
          immediate: true);
      await registerEventWidgetId(_widgetId!);

      // Traer el estado real desde DynamoDB. Si la cadena ya venía corriendo,
      // el widget aparece con la barra en su punto en vez de arrancar en idle.
      // 20s y no 8: el sync consulta el cstate de CADA integrante. Con un
      // grupo de 8 equipos son 8 consultas, y si expira el widget nace sin
      // el conteo de desconectados hasta el próximo /update del WorkManager
      // (que bajo Doze puede tardar 40 min).
      try {
        await syncEventWidgetsWithDatabase()
            .timeout(const Duration(seconds: 20));
      } catch (e) {
        printLog.e('Sync inicial de evento falló: $e');
      }

      printLog.i('Widget $_widgetId guardado: evento ${option.kind.label} '
          '"${option.name}" con ${option.deviceGroup.length} equipos: '
          '${option.deviceGroup}');

      await _startServiceAndFinish();
    } catch (e) {
      printLog.e('Error guardando configuración de evento: $e');
      if (mounted) setState(() => _isSaving = false);
    }
  }

// Función para guardar la configuración cuando el usuario elige un dispositivo
  Future<void> _onDeviceSelected(String deviceKey) async {
    if (_widgetId == null) return;

    try {
      setState(() => _isSaving = true);

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

      await _startServiceAndFinish();
    } catch (e) {
      printLog.e('Error guardando configuración: $e');
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// Arranca el servicio de background y cierra la activity de config.
  /// Común a equipos y eventos.
  Future<void> _startServiceAndFinish() async {
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

    // Marcar ANTES de cerrar: el State sobrevive al finish (engine cacheado) y
    // la próxima apertura tiene que reiniciar todo.
    _configDone = true;
    await platform.invokeMethod('finishConfig');
  }

  // ══════════════════════════════════════════════════════════════════════════
  // UI
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    // 1. Pantalla de Carga
    if (_isLoading || _isSaving) {
      return Scaffold(
        backgroundColor: color0,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                Image.asset('assets/branch/dragon.gif',
                    width: 150, height: 150),
              ],
            ),
          ),
        ),
      );
    }

    final bool nadaQueMostrar =
        eventsToShow.isEmpty && devicesToShow.isEmpty && !_devicesLoading;

    // 2. Pantalla de Selección
    return Scaffold(
      backgroundColor: color0,
      appBar: AppBar(
        title: Text('Elegí qué controlar',
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (nadaQueMostrar)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: Text("No hay nada para mostrar",
                        style: GoogleFonts.poppins(color: Colors.white38)),
                  ),
                ),

              // ── EVENTOS ────────────────────────────────────────────────
              if (eventsToShow.isNotEmpty) ...[
                _sectionHeader('EVENTOS', HugeIcons.strokeRoundedFlash),
                ...eventsToShow.map(_buildEventCard),
                const SizedBox(height: 8),
              ],

              // ── EQUIPOS ────────────────────────────────────────────────
              if (eventsToShow.isNotEmpty || devicesToShow.isNotEmpty)
                _sectionHeader('EQUIPOS', HugeIcons.strokeRoundedHome01),

              if (_devicesLoading)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Column(
                      children: [
                        const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: color1),
                        ),
                        const SizedBox(height: 12),
                        Text('Cargando equipos...',
                            style: GoogleFonts.poppins(
                                color: Colors.white38, fontSize: 12)),
                      ],
                    ),
                  ),
                )
              else if (devicesToShow.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text("No hay dispositivos registrados",
                        style: GoogleFonts.poppins(color: Colors.white38)),
                  ),
                )
              else
                ...devicesToShow.entries.map(_buildDeviceCard),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 4),
      child: Row(
        children: [
          Icon(icon, color: color1, size: 18),
          const SizedBox(width: 8),
          Text(title,
              style: GoogleFonts.poppins(
                color: color1,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.4,
              )),
          const SizedBox(width: 12),
          Expanded(child: Container(height: 1, color: Colors.white10)),
        ],
      ),
    );
  }

  Widget _buildEventCard(_EventOption option) {
    final IconData icon;
    final String label;

    switch (option.kind) {
      case EventWidgetKind.cadena:
        icon = HugeIcons.strokeRoundedLink01;
        label = 'CADENA';

      case EventWidgetKind.riego:
        icon = HugeIcons.strokeRoundedWaterEnergy;
        label = 'RIEGO';

      case EventWidgetKind.grupo:
        icon = HugeIcons.strokeRoundedGridView;
        label = 'GRUPO';
    }

    const String subtitle = 'Controla tus eventos desde la pantalla principal.';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: InkWell(
        onTap: () => _onEventSelected(option),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: const BoxDecoration(
                  color: color1,
                  borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(15),
                      topRight: Radius.circular(15)),
                ),
                child: Row(
                  children: [
                    Icon(icon, color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    Text(label,
                        style: GoogleFonts.poppins(
                            color: Colors.white,
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            option.name,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            subtitle,
                            style: GoogleFonts.poppins(
                              color: Colors.white38,
                              fontSize: 12,
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
  }

  Widget _buildDeviceCard(MapEntry<String, bool> device) {
    String pc = DeviceManager.getProductCode(device.key.split('_')[0]);
    String sn = DeviceManager.extractSerialNumber(device.key.split('_')[0]);
    bool isOnline = globalDATA['$pc/$sn']?['cstate'] ?? false;

    String nickname;
    if (device.key.contains('_')) {
      final String bName = device.key.split('_')[0];
      final String bIdx = device.key.split('_')[1];
      final String bPc = DeviceManager.getProductCode(bName);
      final String bSn = DeviceManager.extractSerialNumber(bName);
      final bool bHasEntry = globalDATA['$bPc/$bSn']?['hasEntry'] ?? false;
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                                  ? Colors.green.withValues(alpha: 0.1)
                                  : Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    color:
                                        isOnline ? Colors.greenAccent : color3,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  isOnline ? 'En línea' : 'Desconectado',
                                  style: GoogleFonts.poppins(
                                    color:
                                        isOnline ? Colors.greenAccent : color3,
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
  }
}
