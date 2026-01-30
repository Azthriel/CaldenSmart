import 'dart:convert';
import 'package:caldensmart/Global/stored_data.dart' show loadEmail;
import 'package:caldensmart/aws/dynamo/dynamo.dart';
import 'package:caldensmart/logger.dart';
import 'package:caldensmart/master.dart';
import 'package:caldensmart/widget/widget_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Para MethodChannel
import 'package:google_fonts/google_fonts.dart';
import 'package:home_widget/home_widget.dart';
import 'package:hugeicons/hugeicons.dart';

class SelectDeviceScreen extends StatefulWidget {
  const SelectDeviceScreen({super.key});
  @override
  State<SelectDeviceScreen> createState() => _SelectDeviceScreenState();
}

class _SelectDeviceScreenState extends State<SelectDeviceScreen> {
  // Canal para hablar con Android (WidgetConfigActivity.kt)
  static const platform = MethodChannel('com.caldensmart.sime/widget_config');

  int? _widgetId;
  bool _isLoading = true;
  String currentUserEmail = '';
  List<String> previusConnections = []; // Lista de IDs de dispositivos
  Map<String, String> nicknamesMap = {}; // Mapa ID -> Apodo
  Map<String, bool> devicesToShow = {}; // Mapa ID -> esControl

  @override
  void initState() {
    super.initState();
    // 1. Primero obtenemos el ID del widget desde Android
    _getWidgetId();
  }

  // Pide el ID a la actividad nativa
  Future<void> _getWidgetId() async {
    try {
      final int widgetId = await platform.invokeMethod('getWidgetId');
      setState(() {
        _widgetId = widgetId;
      });
      printLog.d("Configurando Widget ID: $_widgetId");

      // 2. Cargamos los datos (el widget usará su diseño XML por defecto hasta que se seleccione un dispositivo)
      _loadInitialData();
    } on PlatformException catch (e) {
      printLog.e("Error obteniendo Widget ID: '${e.message}'.");
      // Si falla, igual cargamos datos para pruebas, pero no podremos guardar
      _loadInitialData();
    }
  }

  Future<void> _loadInitialData() async {
    try {
      setState(() => _isLoading = true);

      await DeviceManager.init();

      currentUserEmail = await loadEmail();
      previusConnections = await getPreviusConnections(currentUserEmail);
      nicknamesMap = await getNicknames(currentUserEmail);
      for (String device in previusConnections) {
        final pc = DeviceManager.getProductCode(device);
        final sn = DeviceManager.extractSerialNumber(device);
        await queryItems(pc, sn);
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
          // Por defecto true si no existe (para compatibilidad con equipos viejos)
          bool hasEntry = deviceDATA['hasEntry'] ?? true;

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
              } else if (hasEntry) {
                // Entradas solo si hasEntry es true (son de visualización)
                devicesToShow.addAll({'${device}_$index': false});
              }
              // Si pinType == 1 y hasEntry == false, no se agrega
            }
          });

          if (!ioDevice) {
            // Dispositivos que no son IO
            // Estos dispositivos no tienen control on/off:
            // 023430_IOT = Termómetro (visualización)
            // 015773_IOT = Detector (visualización)
            // 024011_IOT = Modulo (sin control directo)
            // 027131_IOT = Termotanque (sin control on/off)
            bool onOffDevice = pc != '023430_IOT' &&
                pc != '015773_IOT' &&
                pc != '024011_IOT' &&
                pc != '027131_IOT';
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

      // 1. Recuperar datos necesarios
      String nickname = '';
      if (deviceKey.contains('_')) {
        nickname = nicknamesMap[deviceKey] ??
            '${nicknamesMap[deviceKey.split('_')[0]] ?? deviceKey.split('_')[0]} pin ${deviceKey.split('_')[1]}';
      } else {
        nickname = nicknamesMap[deviceKey] ?? deviceKey;
      }

      bool isControl = devicesToShow[deviceKey] ?? false;

      // LOGICA DE ESTADO INICIAL
      // Intentamos obtener el estado actual de globalDATA para que el widget nazca actualizado
      String pc = DeviceManager.getProductCode(deviceKey.split('_')[0]);
      String sn = DeviceManager.extractSerialNumber(deviceKey.split('_')[0]);

      // Estado de conexión
      bool isOnline = globalDATA['$pc/$sn']?['cstate'] ?? false;

      // Estado encendido/apagado
      bool isOn = false;

      // Variables para widgets de visualización
      String? displayTemp;
      bool displayAlert = false;
      bool isDisplayType = false;

      if (isControl) {
        // Dispositivos de control
        if (deviceKey.contains('_')) {
          // Es un pin de salida (control)
          String pinIndex = deviceKey.split('_')[1];
          String ioKey = 'io$pinIndex';
          String? ioData = globalDATA['$pc/$sn']?[ioKey];
          if (ioData != null) {
            var decoded = jsonDecode(ioData);
            isOn = decoded['w_status'] == true;
          }
        } else {
          // Dispositivo principal
          isOn = globalDATA['$pc/$sn']?['w_status'] == true;
        }
      } else {
        // Dispositivos de visualización (solo lectura)
        isDisplayType = true;

        if (pc == '023430_IOT') {
          // Termómetro - mostrar temperatura
          var temp = globalDATA['$pc/$sn']?['actualTemp'];
          if (temp != null) {
            displayTemp = temp.toString();
          }
        } else if (pc == '015773_IOT') {
          // Detector - mostrar alerta
          displayAlert = globalDATA['$pc/$sn']?['alert'] == 1 ||
              globalDATA['$pc/$sn']?['alert'] == true;
        } else if (deviceKey.contains('_')) {
          // Dispositivo IO con entrada (sensor de apertura, etc.)
          // Para 020010_IOT, 020020_IOT, 027313_IOT con pinType == 1
          String pinIndex = deviceKey.split('_')[1];
          String ioKey = 'io$pinIndex';
          String? ioData = globalDATA['$pc/$sn']?[ioKey];
          if (ioData != null) {
            var decoded = jsonDecode(ioData);
            bool wStatus = decoded['w_status'] == true;
            int rState = int.tryParse(decoded['r_state'].toString()) ?? 0;

            // Lógica de alerta para entradas:
            // Alerta si: (w_status == true && r_state == 0) || (w_status == false && r_state == 1)
            displayAlert =
                (wStatus && rState == 0) || (!wStatus && rState == 1);
          }
        }
      }

      // Determinar si es un dispositivo con pin
      bool isPin = deviceKey.contains('_');
      String pinIndex = isPin ? deviceKey.split('_')[1] : '';

      // 2. Guardar las preferencias para el widget nativo
      await HomeWidget.saveWidgetData('widget_device_$_widgetId', deviceKey);
      await HomeWidget.saveWidgetData('widget_nickname_$_widgetId', nickname);
      await HomeWidget.saveWidgetData(
          'widget_is_control_$_widgetId', isControl);
      await HomeWidget.saveWidgetData('widget_online_$_widgetId', isOnline);
      await HomeWidget.saveWidgetData('widget_status_$_widgetId', isOn);

      // Datos adicionales para el toggle MQTT
      await HomeWidget.saveWidgetData('widget_pc_$_widgetId', pc);
      await HomeWidget.saveWidgetData('widget_sn_$_widgetId', sn);
      await HomeWidget.saveWidgetData('widget_is_pin_$_widgetId', isPin);
      await HomeWidget.saveWidgetData('widget_pin_index_$_widgetId', pinIndex);

      // Datos de visualización específicos
      await HomeWidget.saveWidgetData(
          'widget_is_display_type_$_widgetId', isDisplayType);
      if (displayTemp != null) {
        await HomeWidget.saveWidgetData(
            'widget_display_temp_$_widgetId', displayTemp);
      }
      await HomeWidget.saveWidgetData(
          'widget_display_alert_$_widgetId', displayAlert);

      // Registrar el widget ID para poder actualizarlo desde MQTT
      await registerWidgetId(_widgetId!);

      // Iniciar el servicio de background para mantener el widget actualizado
      await initializeWidgetService();

      printLog.d("Guardando widget $_widgetId para: $nickname ($deviceKey)");

      // 3. Actualizar el widget nativo (sin renderFlutterWidget)
      await HomeWidget.updateWidget(
        qualifiedAndroidName:
            'com.caldensmart.sime.widget.ControlWidgetProvider',
      );

      printLog.i("Widget nativo actualizado correctamente");

      // 4. Finalizar
      await platform.invokeMethod('finishConfig');
    } catch (e) {
      printLog.e("Error guardando configuración: $e");
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

                  String nickname = device.key.contains('_')
                      ? (nicknamesMap[device.key] ??
                          '${nicknamesMap[device.key.split('_')[0]] ?? device.key.split('_')[0]} pin ${device.key.split('_')[1]}')
                      : (nicknamesMap[device.key] ?? device.key);

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
                                      device.value
                                          ? HugeIcons.strokeRoundedToggleOn
                                          : HugeIcons.strokeRoundedView,
                                      color: color0,
                                      size: 16),
                                  const SizedBox(width: 8),
                                  Text(device.value ? 'CONTROL' : 'LECTURA',
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
                                        Text(nickname,
                                            style: GoogleFonts.poppins(
                                                color: Colors.white,
                                                fontSize: 18,
                                                fontWeight: FontWeight.w600)),
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
                                                      fontWeight:
                                                          FontWeight.w500)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                      HugeIcons.strokeRoundedArrowRight01,
                                      color: Colors.white,
                                      size: 16),
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
