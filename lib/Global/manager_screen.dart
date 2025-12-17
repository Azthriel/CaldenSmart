import 'dart:convert';
import 'package:caldensmart/secret.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';
import '../aws/dynamo/dynamo.dart';
import '../master.dart';
import 'stored_data.dart';
import 'package:caldensmart/logger.dart';
import 'package:hugeicons/hugeicons.dart';

class ManagerScreen extends StatefulWidget {
  const ManagerScreen({
    super.key,
    required this.deviceName,
    this.needsAppbar = false,
  });
  final String deviceName;
  final bool needsAppbar;

  @override
  ManagerScreenState createState() => ManagerScreenState();
}

class ManagerScreenState extends State<ManagerScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController tenantController = TextEditingController();

  bool showSecondaryAdminFields = false;
  bool showSecondaryAdminList = false;
  bool showSmartResident = false;
  bool dOnOk = false;
  bool dOffOk = false;
  bool showNotificationOptions = false;
  int selectedNotificationOption = 0;

  // Variables para control de bomba
  bool showBombaControl = false;
  final TextEditingController bombaController = TextEditingController();

  // Variables para historial de uso y restricciones horarias
  bool showUsageHistory = false;
  bool showTimeRestrictions = false;
  bool showWifiRestrictions = false;
  List<Map<String, dynamic>> usageHistory = [];
  Map<String, Map<String, dynamic>> timeRestrictions = {};
  Map<String, Map<String, dynamic>> wifiRestrictions = {};
  String selectedAdminForRestrictions = '';

  // Variables para consultas de clima
  Map<String, dynamic>? weatherData;
  bool isWeatherLoading = false;

  @override
  void dispose() {
    emailController.dispose();
    tenantController.dispose();
    bombaController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    discNotfActivated = configNotiDsc.keys.toList().contains(widget.deviceName);
    quickAccesActivated = quickAccess.contains(widget.deviceName);
    _loadUsageHistory();
    _loadTimeRestrictions();
    _loadWifiRestrictions();
    _makeQueryIfNeeded();
    _determineIfIsSpecialUser();
  }

  Future<void> _determineIfIsSpecialUser() async {
    specialUser = await isSpecialUser(currentUserEmail);
    if (mounted) setState(() {});
  }

  Future<void> _makeQueryIfNeeded() async {
    if (widget.needsAppbar) {
      final String pc = DeviceManager.getProductCode(widget.deviceName);
      final String sn = DeviceManager.extractSerialNumber(widget.deviceName);
      await queryItems(pc, sn);
    }
  }

  // Métodos para historial de uso
  Future<void> _loadUsageHistory() async {
    try {
      final String pc = DeviceManager.getProductCode(widget.deviceName);
      final String sn = DeviceManager.extractSerialNumber(widget.deviceName);

      List<Map<String, dynamic>> history =
          await getParsedAdminUsageHistory(pc, sn);
      setState(() {
        usageHistory = history;
      });
    } catch (e) {
      printLog.e('Error cargando historial de uso: $e');
    }
  }

  // Métodos para restricciones horarias
  Future<void> _loadTimeRestrictions() async {
    try {
      final String pc = DeviceManager.getProductCode(widget.deviceName);
      final String sn = DeviceManager.extractSerialNumber(widget.deviceName);

      Map<String, Map<String, dynamic>> restrictions =
          await getAdminTimeRestrictions(pc, sn);
      setState(() {
        timeRestrictions = restrictions;
      });
    } catch (e) {
      printLog.e('Error cargando restricciones horarias: $e');
    }
  }

  Future<void> _saveTimeRestrictions() async {
    try {
      String pc = DeviceManager.getProductCode(widget.deviceName);
      String sn = DeviceManager.extractSerialNumber(widget.deviceName);

      await putAdminTimeRestrictions(pc, sn, timeRestrictions);
      showToast('Restricciones horarias guardadas correctamente');
    } catch (e) {
      printLog.e('Error guardando restricciones horarias: $e');
      showToast('Error al guardar las restricciones horarias');
    }
  }

  void _showTimeRestrictionDialog(String adminEmail) {
    Map<String, dynamic> currentRestriction = timeRestrictions[adminEmail] ??
        {
          'enabled': false,
          'startHour': 8,
          'startMinute': 0,
          'endHour': 16,
          'endMinute': 0,
          'weekdays': [1, 2, 3, 4, 5], // Lunes a Viernes por defecto
        };

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.0),
                side: const BorderSide(color: color4, width: 2.0),
              ),
              backgroundColor: color1,
              title: Text(
                'Restricciones horarias para $adminEmail',
                style: GoogleFonts.poppins(
                  color: color0,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Switch para habilitar/deshabilitar restricciones
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Activar restricciones:',
                          style: GoogleFonts.poppins(color: color0),
                        ),
                        Switch(
                          value: currentRestriction['enabled'],
                          onChanged: (value) {
                            setDialogState(() {
                              currentRestriction['enabled'] = value;
                            });
                          },
                          activeThumbColor: color4,
                        ),
                      ],
                    ),
                    if (currentRestriction['enabled']) ...[
                      const SizedBox(height: 20),
                      // Selección de horarios con diseño mejorado
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: color0.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: color0.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Hora de inicio
                            Text(
                              'Hora de inicio:',
                              style: GoogleFonts.poppins(
                                color: color0,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Dropdown de horas compacto
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: color0.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: color0.withValues(alpha: 0.3)),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<int>(
                                      value: currentRestriction['startHour'],
                                      isDense: true,
                                      style: GoogleFonts.poppins(
                                          color: color0, fontSize: 16),
                                      dropdownColor: color1,
                                      items: List.generate(24, (index) {
                                        return DropdownMenuItem(
                                          value: index,
                                          child: Text(
                                            index.toString().padLeft(2, '0'),
                                            style: GoogleFonts.poppins(
                                                color: color0),
                                          ),
                                        );
                                      }),
                                      onChanged: (value) {
                                        setDialogState(() {
                                          currentRestriction['startHour'] =
                                              value!;
                                        });
                                      },
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 8),
                                  child: Text(
                                    ':',
                                    style: GoogleFonts.poppins(
                                      color: color0,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                // Dropdown de minutos compacto
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: color0.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: color0.withValues(alpha: 0.3)),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<int>(
                                      value: currentRestriction['startMinute'],
                                      isDense: true,
                                      style: GoogleFonts.poppins(
                                          color: color0, fontSize: 16),
                                      dropdownColor: color1,
                                      items: [0, 15, 30, 45].map((minute) {
                                        return DropdownMenuItem(
                                          value: minute,
                                          child: Text(
                                            minute.toString().padLeft(2, '0'),
                                            style: GoogleFonts.poppins(
                                                color: color0),
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (value) {
                                        setDialogState(() {
                                          currentRestriction['startMinute'] =
                                              value!;
                                        });
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Hora de fin
                            Text(
                              'Hora de fin:',
                              style: GoogleFonts.poppins(
                                color: color0,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Dropdown de horas compacto
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: color0.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: color0.withValues(alpha: 0.3)),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<int>(
                                      value: currentRestriction['endHour'],
                                      isDense: true,
                                      style: GoogleFonts.poppins(
                                          color: color0, fontSize: 16),
                                      dropdownColor: color1,
                                      items: List.generate(24, (index) {
                                        return DropdownMenuItem(
                                          value: index,
                                          child: Text(
                                            index.toString().padLeft(2, '0'),
                                            style: GoogleFonts.poppins(
                                                color: color0),
                                          ),
                                        );
                                      }),
                                      onChanged: (value) {
                                        setDialogState(() {
                                          currentRestriction['endHour'] =
                                              value!;
                                        });
                                      },
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 8),
                                  child: Text(
                                    ':',
                                    style: GoogleFonts.poppins(
                                      color: color0,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                // Dropdown de minutos compacto
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: color0.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: color0.withValues(alpha: 0.3)),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<int>(
                                      value: currentRestriction['endMinute'],
                                      isDense: true,
                                      style: GoogleFonts.poppins(
                                          color: color0, fontSize: 16),
                                      dropdownColor: color1,
                                      items: [0, 15, 30, 45].map((minute) {
                                        return DropdownMenuItem(
                                          value: minute,
                                          child: Text(
                                            minute.toString().padLeft(2, '0'),
                                            style: GoogleFonts.poppins(
                                                color: color0),
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (value) {
                                        setDialogState(() {
                                          currentRestriction['endMinute'] =
                                              value!;
                                        });
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Días de la semana
                      Text(
                        'Días permitidos:',
                        style: GoogleFonts.poppins(
                            color: color0, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 5,
                        children: [
                          for (int day = 1; day <= 7; day++)
                            FilterChip(
                              label: Text(_getDayName(day)),
                              selected: (currentRestriction['weekdays'] as List)
                                  .contains(day),
                              onSelected: (selected) {
                                setDialogState(() {
                                  List<int> weekdays = List<int>.from(
                                      currentRestriction['weekdays']);
                                  if (selected) {
                                    weekdays.add(day);
                                  } else {
                                    weekdays.remove(day);
                                  }
                                  currentRestriction['weekdays'] = weekdays;
                                });
                              },
                              selectedColor: color4,
                              checkmarkColor: color0,
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text(
                    'Cancelar',
                    style: GoogleFonts.poppins(color: color4),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      timeRestrictions[adminEmail] =
                          Map.from(currentRestriction);
                    });
                    _saveTimeRestrictions();
                    Navigator.of(context).pop();
                  },
                  child: Text(
                    'Guardar',
                    style: GoogleFonts.poppins(color: color4),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _getDayName(int day) {
    const days = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
    return days[day - 1];
  }

  // Métodos para restricciones de WiFi
  Future<void> _loadWifiRestrictions() async {
    try {
      String pc = DeviceManager.getProductCode(widget.deviceName);
      String sn = DeviceManager.extractSerialNumber(widget.deviceName);

      Map<String, Map<String, dynamic>> restrictions =
          await getAdminWifiRestrictions(pc, sn);
      setState(() {
        wifiRestrictions = restrictions;
      });
    } catch (e) {
      printLog.e('Error cargando restricciones de WiFi: $e');
    }
  }

  Future<void> _saveWifiRestrictions() async {
    try {
      String pc = DeviceManager.getProductCode(widget.deviceName);
      String sn = DeviceManager.extractSerialNumber(widget.deviceName);

      // Guardar cada restricción individualmente
      for (String adminEmail in wifiRestrictions.keys) {
        await saveAdminWifiRestrictions(
            pc, sn, adminEmail, wifiRestrictions[adminEmail]!);
      }
      showToast('Restricciones de WiFi guardadas correctamente');
    } catch (e) {
      printLog.e('Error guardando restricciones de WiFi: $e');
      showToast('Error al guardar las restricciones de WiFi');
    }
  }

  void _showWifiRestrictionDialog(String adminEmail) {
    Map<String, dynamic> currentRestriction = wifiRestrictions[adminEmail] ??
        {
          'enabled': false,
        };

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.0),
                side: const BorderSide(color: color4, width: 2.0),
              ),
              backgroundColor: color1,
              title: Text(
                'Restricciones de WiFi para $adminEmail',
                style: GoogleFonts.poppins(
                  color: color0,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Switch para habilitar/deshabilitar restricciones
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Restringir uso por WiFi:',
                          style: GoogleFonts.poppins(
                              color: color0, fontWeight: FontWeight.bold),
                        ),
                        Switch(
                          value: currentRestriction['enabled'] ?? false,
                          onChanged: (bool value) {
                            setDialogState(() {
                              currentRestriction['enabled'] = value;
                            });
                          },
                          activeThumbColor: color3,
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    if (currentRestriction['enabled'] ?? false) ...[
                      Text(
                        'El administrador no podrá acceder al panel de WiFi cuando esta restricción esté habilitada.',
                        style: GoogleFonts.poppins(
                          color: color0.withValues(alpha: 0.8),
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ] else ...[
                      Text(
                        'El administrador tiene acceso completo al panel de WiFi.',
                        style: GoogleFonts.poppins(
                          color: color0.withValues(alpha: 0.8),
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancelar',
                    style: GoogleFonts.poppins(color: color0),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      wifiRestrictions[adminEmail] =
                          Map.from(currentRestriction);
                    });
                    _saveWifiRestrictions();
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: color3),
                  child: Text(
                    'Guardar',
                    style: GoogleFonts.poppins(color: color0),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _formatDateTime(String isoString) {
    try {
      DateTime dateTime = DateTime.parse(isoString);
      return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      printLog.e('Error al formatear la fecha: $e');
      return 'Fecha inválida';
    }
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

      await putSecondaryAdmins(DeviceManager.getProductCode(widget.deviceName),
          DeviceManager.extractSerialNumber(widget.deviceName), updatedAdmins);

      setState(() {
        adminDevices = updatedAdmins;
        globalDATA[
                '${DeviceManager.getProductCode(widget.deviceName)}/${DeviceManager.extractSerialNumber(widget.deviceName)}']
            ?['secondary_admin'] = adminDevices;
        emailController.clear();
      });

      showToast('Administrador añadido correctamente.');
    } catch (e) {
      printLog.e('Error al añadir administrador secundario: $e');
      showToast('Error al añadir el administrador. Inténtalo de nuevo.');
    }
  }

  Future<void> removeSecondaryAdmin(String email) async {
    try {
      List<String> updatedAdmins = List.from(adminDevices)..remove(email);

      await putSecondaryAdmins(DeviceManager.getProductCode(widget.deviceName),
          DeviceManager.extractSerialNumber(widget.deviceName), updatedAdmins);

      globalDATA[
              '${DeviceManager.getProductCode(widget.deviceName)}/${DeviceManager.extractSerialNumber(widget.deviceName)}']
          ?['secondary_admin'] = updatedAdmins;

      setState(() {
        adminDevices.remove(email);
      });

      showToast('Administrador eliminado correctamente.');
    } catch (e) {
      printLog.e('Error al eliminar administrador secundario: $e');
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

  Future<int?> showPinSelectionDialog(BuildContext context) async {
    int? selectedPin;
    return showDialog<int>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            String productCode =
                DeviceManager.getProductCode(widget.deviceName);
            String serialNumber =
                DeviceManager.extractSerialNumber(widget.deviceName);
            String deviceKey = '$productCode/$serialNumber';
            Map<String, dynamic> deviceDATA = globalDATA[deviceKey] ?? {};

            List<int> availablePins = [];

            // Buscar todas las claves que empiecen con "io" y extraer el número
            for (String key in deviceDATA.keys) {
              if (key.startsWith('io') && key.length > 2) {
                try {
                  int pinIndex = int.parse(key.substring(2));
                  Map<String, dynamic> ioMap = jsonDecode(deviceDATA[key]);
                  String pinType = ioMap['pinType']?.toString() ?? '1';
                  // Solo agregar si es salida (pinType == '0')
                  if (pinType == '0') {
                    availablePins.add(pinIndex);
                  }
                } catch (e) {
                  printLog.e('Error parsing $key: $e');
                }
              }
            }

            // Ordenar los pines para mostrarlos en orden
            availablePins.sort();

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.0),
                side: const BorderSide(color: color4, width: 2.0),
              ),
              backgroundColor: color1,
              title: Text(
                'Selecciona un pin',
                style: GoogleFonts.poppins(
                  color: color0,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SingleChildScrollView(
                child: RadioGroup<int>(
                  groupValue: selectedPin,
                  onChanged: (int? value) {
                    setState(() {
                      selectedPin = value;
                    });
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: availablePins.map((index) {
                      return RadioListTile<int>(
                        title: Text(
                          nicknamesMap['${widget.deviceName}_$index'] ??
                              'Salida $index',
                          style: GoogleFonts.poppins(
                            color: color0,
                            fontSize: 16,
                          ),
                        ),
                        value: index,
                        activeColor: color4,
                      );
                    }).toList(),
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: Text(
                    'Aceptar',
                    style: GoogleFonts.poppins(color: color4),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop(selectedPin);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Metodos para consulta de clima
  Map<String, double>? extractCoordinates(String locationString) {
    try {
      // Formato esperado: "Latitude: -34.6233784, Longitude: -58.5565867"
      final latMatch =
          RegExp(r'Latitude:\s*([-+]?\d+\.?\d*)').firstMatch(locationString);
      final lonMatch =
          RegExp(r'Longitude:\s*([-+]?\d+\.?\d*)').firstMatch(locationString);

      if (latMatch != null && lonMatch != null) {
        final lat = double.parse(latMatch.group(1)!);
        final lon = double.parse(lonMatch.group(1)!);
        return {'lat': lat, 'lon': lon};
      }
      return null;
    } catch (e) {
      printLog.e('Error extrayendo coordenadas: $e');
      return null;
    }
  }

  String formatUnixTime(int timestamp) {
    final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<void> fetchWeatherData(double lat, double lon) async {
    try {
      final url = Uri.parse(
          'https://api.openweathermap.org/data/3.0/onecall?lat=$lat&lon=$lon&appid=$climaAPI&units=metric&lang=es');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // printLog.i('=== RESPUESTA DE LA API DE CLIMA ===',
        //     color: Colors.greenAccent);
        // printLog.i(data, color: Colors.greenAccent);
        // printLog.i('===================================',
        //     color: Colors.greenAccent);

        setState(() {
          weatherData = data;
        });
      } else {
        printLog.e('Error en la API: ${response.statusCode}',
            color: Colors.red);
        printLog.e('Respuesta: ${response.body}', color: Colors.red);
      }
    } catch (e) {
      printLog.e('Error haciendo request a la API: $e', color: Colors.red);
    }
  }

  void _showDeviceClima() async {
    if (isWeatherLoading) return;

    setState(() {
      isWeatherLoading = true;
    });

    final String pc = DeviceManager.getProductCode(widget.deviceName);
    final String sn = DeviceManager.extractSerialNumber(widget.deviceName);
    String location = globalDATA['$pc/$sn']?['deviceLocation'] ?? 'unknown';
    final coords = extractCoordinates(location);
    if (coords != null) {
      await fetchWeatherData(coords['lat']!, coords['lon']!);
      if (weatherData != null) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.0),
                side: const BorderSide(color: color4, width: 2.0),
              ),
              backgroundColor: color1,
              title: Text(
                'Clima del Equipo',
                style: GoogleFonts.poppins(
                  color: color0,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildWeatherItem(
                        'Temperatura', '${weatherData!['current']['temp']}°C'),
                    _buildWeatherItem('Sensación Térmica',
                        '${weatherData!['current']['feels_like']}°C'),
                    _buildWeatherItem(
                        'Humedad', '${weatherData!['current']['humidity']}%'),
                    _buildWeatherItem('Presión',
                        '${weatherData!['current']['pressure']} hPa'),
                    _buildWeatherItem('Viento',
                        '${weatherData!['current']['wind_speed']} m/s'),
                    _buildWeatherItem('Dirección del viento',
                        '${weatherData!['current']['wind_deg']}°'),
                    _buildWeatherItem(
                        'Nubosidad', '${weatherData!['current']['clouds']}%'),
                    _buildWeatherItem(
                        'UV Index', '${weatherData!['current']['uvi']}'),
                    _buildWeatherItem('Visibilidad',
                        '${weatherData!['current']['visibility']} m'),
                    _buildWeatherItem('Amanecer',
                        formatUnixTime(weatherData!['current']['sunrise'])),
                    _buildWeatherItem('Atardecer',
                        formatUnixTime(weatherData!['current']['sunset'])),
                    _buildWeatherItem('Descripción',
                        '${weatherData!['current']['weather'][0]['description']}'),
                    _buildWeatherItem('Tipo principal',
                        '${weatherData!['current']['weather'][0]['main']}'),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text(
                    'Cerrar',
                    style: GoogleFonts.poppins(color: color4),
                  ),
                ),
              ],
            );
          },
        );
      } else {
        showToast('No se pudo obtener la información del clima.');
      }
    } else {
      showToast('Las coordenadas del dispositivo no son válidas.');
    }

    if (mounted) {
      setState(() {
        isWeatherLoading = false;
      });
    }
  }

  Widget _buildWeatherItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$label:',
            style: GoogleFonts.poppins(
              color: color0,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: GoogleFonts.poppins(
                color: color0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String pc = DeviceManager.getProductCode(widget.deviceName);
    final String sn = DeviceManager.extractSerialNumber(widget.deviceName);
    final String hv =
        globalDATA['$pc/$sn']?['HardwareVersion'] ?? 'Desconocida';
    final String sv =
        globalDATA['$pc/$sn']?['SoftwareVersion'] ?? 'Desconocida';
    owner = globalDATA['$pc/$sn']?['owner'] ?? '';
    tenant = globalDATA['$pc/$sn']?['tenant'] == currentUserEmail;
    adminDevices =
        List<String>.from(globalDATA['$pc/$sn']?['secondary_admin'] ?? []);

    return Scaffold(
      backgroundColor: color0,
      appBar: widget.needsAppbar
          ? AppBar(
              backgroundColor: color1,
              iconTheme: const IconThemeData(color: color0),
              title: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 30,
                      width: 2,
                      child: AutoScrollingText(
                        text: widget.deviceName,
                        style: GoogleFonts.poppins(
                          color: color0,
                        ),
                        velocity: 50,
                      ),
                    ),
                  ),
                  const SizedBox(width: 3),
                ],
              ),
              actions: [
                IconButton(
                  icon:
                      const Icon(HugeIcons.strokeRoundedShare08, color: color0),
                  onPressed: () {
                    _showDeviceQR();
                  },
                ),
              ],
              leading: IconButton(
                icon: const Icon(HugeIcons.strokeRoundedArrowLeft01),
                color: color0,
                onPressed: () {
                  Navigator.of(context).pop();
                  return;
                },
              ),
            )
          : null,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 30.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                key: keys['managerScreen:titulo']!,
                'Gestión del equipo',
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: color1,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: pc == '015773_IOT' ? 0 : 40),
              //! Opción - Reclamar propiedad del equipo o dejar de ser propietario
              if (!tenant &&
                  (owner == currentUserEmail || owner == '') &&
                  pc != '015773_IOT' &&
                  pc != '023430_IOT') ...{
                InkWell(
                  key: keys['managerScreen:reclamar']!,
                  onTap: () async {
                    if (owner == currentUserEmail) {
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
                                  pc,
                                  sn,
                                  '',
                                );
                                Navigator.of(context).pop();

                                saveATData(
                                  pc,
                                  sn,
                                  false,
                                  '',
                                  '3000',
                                  '100',
                                );

                                setState(() {
                                  owner = '';
                                  deviceOwner = false;
                                  globalDATA['$pc/$sn']?['owner'] = '';
                                });
                              } catch (e, s) {
                                printLog
                                    .e('Error al borrar owner $e Trace: $s');
                                showToast('Error al borrar el administrador.');
                              }
                            },
                          ),
                        ],
                      );
                    } else if (owner == '') {
                      try {
                        putOwner(
                          pc,
                          sn,
                          currentUserEmail,
                        );
                        setState(() {
                          owner = currentUserEmail;
                          globalDATA['$pc/$sn']?['owner'] = currentUserEmail;
                          deviceOwner = true;
                        });
                        showToast('Ahora eres el propietario del equipo');
                      } catch (e, s) {
                        printLog.e('Error al agregar owner $e Trace: $s');
                        showToast('Error al agregar el administrador.');
                      }
                    } else {
                      showToast('El equipo ya esta reclamado');
                    }
                  },
                  borderRadius: BorderRadius.circular(15),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 600),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: color4,
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
                      owner == currentUserEmail
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
              },
              const SizedBox(height: 20),
              //! Opciones adicionales con animación
              AnimatedSize(
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeInOut,
                child: AnimatedOpacity(
                  opacity: owner == currentUserEmail ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 600),
                  child: owner == currentUserEmail
                      ? Column(
                          children: [
                            //! Opciones adicionales existentes (isOwner)
                            if (owner == currentUserEmail) ...[
                              //! Opción 2 - Añadir administradores secundarios
                              InkWell(
                                key: keys['managerScreen:agregarAdmin']!,
                                onTap: () {
                                  setState(() {
                                    showSecondaryAdminFields =
                                        !showSecondaryAdminFields;
                                  });
                                },
                                borderRadius: BorderRadius.circular(15),
                                child: Container(
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 0),
                                  padding: const EdgeInsets.all(15),
                                  decoration: BoxDecoration(
                                    color: color1,
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
                                            ? HugeIcons.strokeRoundedArrowUp01
                                            : HugeIcons
                                                .strokeRoundedArrowDown01,
                                        color: color0,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
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
                                              cursorColor: color1,
                                              style: GoogleFonts.poppins(
                                                color: color1,
                                              ),
                                              decoration: InputDecoration(
                                                labelText: 'Correo electrónico',
                                                labelStyle: GoogleFonts.poppins(
                                                  fontSize: 16,
                                                  color: color1,
                                                ),
                                                filled: true,
                                                fillColor: Colors.transparent,
                                                focusedBorder:
                                                    OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(15),
                                                  borderSide: const BorderSide(
                                                    color: color1,
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
                                                if (adminDevices.length < 3) {
                                                  addSecondaryAdmin(
                                                    emailController.text.trim(),
                                                  );
                                                } else {
                                                  printLog
                                                      .i('¿Pago? $payAdmSec');
                                                  if (payAdmSec) {
                                                    if (adminDevices.length <
                                                        6) {
                                                      addSecondaryAdmin(
                                                        emailController.text
                                                            .trim(),
                                                      );
                                                    } else {
                                                      showToast(
                                                          'No puedes añadir más de 6 administradores secundarios');
                                                    }
                                                  } else {
                                                    showAlertDialog(
                                                      context,
                                                      true,
                                                      Text(
                                                        'Actualmente no tienes habilitado este beneficio',
                                                        style:
                                                            GoogleFonts.poppins(
                                                                color: color0),
                                                      ),
                                                      Text(
                                                        'En caso de requerirlo puedes solicitarlo vía mail',
                                                        style:
                                                            GoogleFonts.poppins(
                                                                color: color0),
                                                      ),
                                                      [
                                                        TextButton(
                                                          style: TextButton
                                                              .styleFrom(
                                                            foregroundColor:
                                                                const Color(
                                                                    0xFFFFFFFF),
                                                          ),
                                                          onPressed: () async {
                                                            String cuerpo =
                                                                '¡Hola! Me comunico porque busco habilitar la opción de "Administradores secundarios extras" en mi equipo ${widget.deviceName}\nCódigo de Producto: $pc\nNúmero de Serie: $sn\nDueño actual del equipo: $owner';

                                                            try {
                                                              launchEmail(
                                                                  'cobranzas@ibsanitarios.com.ar',
                                                                  'Habilitación Administradores secundarios extras',
                                                                  cuerpo,
                                                                  cc: 'pablo@intelligentgas.com.ar');
                                                            } catch (e) {
                                                              printLog.e(
                                                                  'Error al enviar email: $e');
                                                              showToast(
                                                                  'No se pudo enviar el correo electrónico');
                                                            }
                                                            navigatorKey
                                                                .currentState
                                                                ?.pop();
                                                          },
                                                          child: const Text(
                                                              'Solicitar'),
                                                        ),
                                                      ],
                                                    );
                                                  }
                                                }
                                              } else {
                                                showToast(
                                                    'Por favor, introduce un correo electrónico.');
                                              }
                                            },
                                            borderRadius:
                                                BorderRadius.circular(15),
                                            child: Container(
                                              padding: const EdgeInsets.all(15),
                                              decoration: BoxDecoration(
                                                color: color1,
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
                                key: keys['managerScreen:verAdmin']!,
                                onTap: () {
                                  setState(() {
                                    showSecondaryAdminList =
                                        !showSecondaryAdminList;
                                  });
                                },
                                borderRadius: BorderRadius.circular(15),
                                child: Container(
                                  padding: const EdgeInsets.all(15),
                                  decoration: BoxDecoration(
                                    color: color1,
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
                                            ? HugeIcons.strokeRoundedArrowUp01
                                            : HugeIcons
                                                .strokeRoundedArrowDown01,
                                        color: color0,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              AnimatedSize(
                                duration: const Duration(milliseconds: 600),
                                curve: Curves.easeInOut,
                                child: showSecondaryAdminList
                                    ? adminDevices.isEmpty
                                        ? Text(
                                            'No hay administradores secundarios.',
                                            style: GoogleFonts.poppins(
                                              fontSize: 16,
                                              color: color1,
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
                                                  color: color1,
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
                                                          HugeIcons
                                                              .strokeRoundedDelete02,
                                                          color: color3),
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
                              //! Opción 4 - Alquiler temporario
                              InkWell(
                                key: keys['managerScreen:alquiler']!,
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
                                                  '¡Hola! Me comunico porque busco habilitar la opción de "Alquiler temporario" en mi equipo ${widget.deviceName}\nCódigo de Producto: $pc\nNúmero de Serie: $sn\nDueño actual del equipo: $owner';

                                              try {
                                                launchEmail(
                                                    'cobranzas@ibsanitarios.com.ar',
                                                    'Habilitación Alquiler temporario',
                                                    cuerpo,
                                                    cc: 'pablo@intelligentgas.com.ar');
                                              } catch (e) {
                                                printLog.e(
                                                    'Error al enviar email: $e');
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
                                  padding: const EdgeInsets.all(15),
                                  decoration: BoxDecoration(
                                    color: color1,
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Alquiler temporario',
                                        style: GoogleFonts.poppins(
                                            fontSize: 15, color: color0),
                                      ),
                                      Icon(
                                        showSmartResident
                                            ? HugeIcons.strokeRoundedArrowUp01
                                            : HugeIcons
                                                .strokeRoundedArrowDown01,
                                        color: color0,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
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
                                              color: color1,
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
                                                      color: color1,
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
                                                                        '$pc/$sn']
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
                                                                HugeIcons
                                                                    .strokeRoundedDelete02,
                                                                color: Colors
                                                                    .redAccent,
                                                              ),
                                                              onPressed:
                                                                  () async {
                                                                await saveATData(
                                                                  pc,
                                                                  sn,
                                                                  false,
                                                                  '',
                                                                  '3000',
                                                                  '100',
                                                                );

                                                                setState(() {
                                                                  tenantController
                                                                      .clear();
                                                                  globalDATA[
                                                                          '$pc/$sn']
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
                                                if (pc != '020010_IOT' &&
                                                    pc != '050217_IOT' &&
                                                    pc != '020010_IOT') ...{
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
                                                      color: color0,
                                                    ),
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
                                                },
                                                // Botones de Activar y Cancelar
                                                Center(
                                                  child: Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      TextButton(
                                                        onPressed: () {
                                                          if (tenantController
                                                              .text
                                                              .isNotEmpty) {
                                                            saveATData(
                                                              pc,
                                                              sn,
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
                                                              globalDATA['$pc/$sn']
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
                                                                  color: color1,
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
                                                                  color: color1,
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
                              //! Opción 5 - Historial de uso de administradores secundarios
                              if (adminDevices.isNotEmpty) ...[
                                InkWell(
                                  key: keys['managerScreen:historialAdmin']!,
                                  onTap: () {
                                    setState(() {
                                      showUsageHistory = !showUsageHistory;
                                    });
                                    if (showUsageHistory) {
                                      _loadUsageHistory();
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(15),
                                  child: Container(
                                    padding: const EdgeInsets.all(15),
                                    decoration: BoxDecoration(
                                      color: color1,
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Historial de uso\nadministradores',
                                          style: GoogleFonts.poppins(
                                            fontSize: 15,
                                            color: color0,
                                          ),
                                        ),
                                        Icon(
                                          showUsageHistory
                                              ? HugeIcons.strokeRoundedArrowUp01
                                              : HugeIcons
                                                  .strokeRoundedArrowDown01,
                                          color: color0,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                AnimatedSize(
                                  duration: const Duration(milliseconds: 600),
                                  curve: Curves.easeInOut,
                                  child: showUsageHistory
                                      ? Container(
                                          padding: const EdgeInsets.all(20),
                                          decoration: BoxDecoration(
                                            color: color1,
                                            borderRadius:
                                                BorderRadius.circular(15),
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
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Últimas actividades:',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 16,
                                                  color: color0,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 15),
                                              if (usageHistory.isEmpty)
                                                Text(
                                                  'No hay actividades registradas',
                                                  style: GoogleFonts.poppins(
                                                    color: color0,
                                                    fontStyle: FontStyle.italic,
                                                  ),
                                                )
                                              else
                                                Container(
                                                  constraints:
                                                      const BoxConstraints(
                                                          maxHeight: 300),
                                                  child: ListView.builder(
                                                    shrinkWrap: true,
                                                    itemCount:
                                                        usageHistory.length,
                                                    itemBuilder:
                                                        (context, index) {
                                                      final record =
                                                          usageHistory[index];
                                                      return Container(
                                                        margin: const EdgeInsets
                                                            .only(bottom: 10),
                                                        padding:
                                                            const EdgeInsets
                                                                .all(12),
                                                        decoration:
                                                            BoxDecoration(
                                                          color:
                                                              color0.withValues(
                                                                  alpha: 0.1),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(10),
                                                        ),
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Text(
                                                              record['email'] ??
                                                                  'Usuario desconocido',
                                                              style: GoogleFonts
                                                                  .poppins(
                                                                color: color0,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                fontSize: 14,
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                                height: 4),
                                                            Text(
                                                              record['action'] ??
                                                                  'Acción desconocida',
                                                              style: GoogleFonts
                                                                  .poppins(
                                                                color: color0,
                                                                fontSize: 13,
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                                height: 4),
                                                            Text(
                                                              _formatDateTime(
                                                                  record['timestamp'] ??
                                                                      ''),
                                                              style: GoogleFonts
                                                                  .poppins(
                                                                color: color0
                                                                    .withValues(
                                                                        alpha:
                                                                            0.7),
                                                                fontSize: 12,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                ),
                                            ],
                                          ),
                                        )
                                      : const SizedBox(),
                                ),
                                const SizedBox(height: 10),
                                //! Opción 6 - Restricciones horarias de administradores secundarios
                                InkWell(
                                  key: keys['managerScreen:horariosAdmin']!,
                                  onTap: () {
                                    setState(() {
                                      showTimeRestrictions =
                                          !showTimeRestrictions;
                                    });
                                    if (showTimeRestrictions) {
                                      _loadTimeRestrictions();
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(15),
                                  child: Container(
                                    padding: const EdgeInsets.all(15),
                                    decoration: BoxDecoration(
                                      color: color1,
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Restricciones horarias\nadministradores',
                                          style: GoogleFonts.poppins(
                                            fontSize: 15,
                                            color: color0,
                                          ),
                                        ),
                                        Icon(
                                          showTimeRestrictions
                                              ? HugeIcons.strokeRoundedArrowUp01
                                              : HugeIcons
                                                  .strokeRoundedArrowDown01,
                                          color: color0,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                AnimatedSize(
                                  duration: const Duration(milliseconds: 600),
                                  curve: Curves.easeInOut,
                                  child: showTimeRestrictions
                                      ? Container(
                                          padding: const EdgeInsets.all(20),
                                          decoration: BoxDecoration(
                                            color: color1,
                                            borderRadius:
                                                BorderRadius.circular(15),
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
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Configurar horarios permitidos:',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 16,
                                                  color: color0,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 15),
                                              ...adminDevices.map(
                                                (email) {
                                                  Map<String, dynamic>
                                                      restriction =
                                                      timeRestrictions[email] ??
                                                          {};
                                                  bool isRestricted =
                                                      restriction['enabled'] ??
                                                          false;

                                                  return Container(
                                                    margin:
                                                        const EdgeInsets.only(
                                                            bottom: 15),
                                                    padding:
                                                        const EdgeInsets.all(
                                                            15),
                                                    decoration: BoxDecoration(
                                                      color: color0.withValues(
                                                          alpha: 0.1),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              10),
                                                      border: Border.all(
                                                        color: isRestricted
                                                            ? color3
                                                            : color0.withValues(
                                                                alpha: 0.3),
                                                        width: 2,
                                                      ),
                                                    ),
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Row(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .spaceBetween,
                                                          children: [
                                                            Expanded(
                                                              child: Text(
                                                                email,
                                                                style:
                                                                    GoogleFonts
                                                                        .poppins(
                                                                  color: color0,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                  fontSize: 14,
                                                                ),
                                                              ),
                                                            ),
                                                            IconButton(
                                                                onPressed: () {
                                                                  _showTimeRestrictionDialog(
                                                                      email);
                                                                },
                                                                icon:
                                                                    const Icon(
                                                                  HugeIcons
                                                                      .strokeRoundedSettings01,
                                                                  color: color4,
                                                                ))
                                                          ],
                                                        ),
                                                        if (isRestricted) ...[
                                                          const SizedBox(
                                                              height: 10),
                                                          Text(
                                                            'Horario: ${restriction['startHour'].toString().padLeft(2, '0')}:${restriction['startMinute'].toString().padLeft(2, '0')} - ${restriction['endHour'].toString().padLeft(2, '0')}:${restriction['endMinute'].toString().padLeft(2, '0')}',
                                                            style: GoogleFonts
                                                                .poppins(
                                                              color: color0,
                                                              fontSize: 12,
                                                            ),
                                                          ),
                                                          Text(
                                                            'Días: ${(restriction['weekdays'] as List).map((d) => _getDayName(d)).join(', ')}',
                                                            style: GoogleFonts
                                                                .poppins(
                                                              color: color0,
                                                              fontSize: 12,
                                                            ),
                                                          ),
                                                        ] else
                                                          Text(
                                                            'Sin restricciones',
                                                            style: GoogleFonts
                                                                .poppins(
                                                              color: color0
                                                                  .withValues(
                                                                      alpha:
                                                                          0.7),
                                                              fontSize: 12,
                                                              fontStyle:
                                                                  FontStyle
                                                                      .italic,
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                  );
                                                },
                                              ),
                                            ],
                                          ),
                                        )
                                      : const SizedBox(),
                                ),
                                const SizedBox(height: 10),
                                //! Opción 7 - Restricciones de WiFi para administradores secundarios
                                InkWell(
                                  key: keys['managerScreen:wifiAdmin']!,
                                  onTap: () {
                                    setState(() {
                                      showWifiRestrictions =
                                          !showWifiRestrictions;
                                    });
                                    if (showWifiRestrictions) {
                                      _loadWifiRestrictions();
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(15),
                                  child: Container(
                                    padding: const EdgeInsets.all(15),
                                    decoration: BoxDecoration(
                                      color: color1,
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Restringir uso por WiFi\nadministradores',
                                          style: GoogleFonts.poppins(
                                            fontSize: 15,
                                            color: color0,
                                          ),
                                        ),
                                        Icon(
                                          showWifiRestrictions
                                              ? HugeIcons.strokeRoundedArrowUp01
                                              : HugeIcons
                                                  .strokeRoundedArrowDown01,
                                          color: color0,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                AnimatedSize(
                                  duration: const Duration(milliseconds: 600),
                                  curve: Curves.easeInOut,
                                  child: showWifiRestrictions
                                      ? Container(
                                          padding: const EdgeInsets.all(20),
                                          decoration: BoxDecoration(
                                            color: color1,
                                            borderRadius:
                                                BorderRadius.circular(15),
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
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Configurar restricciones de WiFi:',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 16,
                                                  color: color0,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 15),
                                              ...adminDevices.map(
                                                (email) {
                                                  Map<String, dynamic>
                                                      restriction =
                                                      wifiRestrictions[email] ??
                                                          {};
                                                  bool isRestricted =
                                                      restriction['enabled'] ??
                                                          false;

                                                  return Container(
                                                    margin:
                                                        const EdgeInsets.only(
                                                            bottom: 15),
                                                    padding:
                                                        const EdgeInsets.all(
                                                            15),
                                                    decoration: BoxDecoration(
                                                      color: color0.withValues(
                                                          alpha: 0.1),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              10),
                                                      border: Border.all(
                                                        color: isRestricted
                                                            ? Colors.red
                                                            : color0.withValues(
                                                                alpha: 0.3),
                                                        width: 2,
                                                      ),
                                                    ),
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Row(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .spaceBetween,
                                                          children: [
                                                            Expanded(
                                                              child: Text(
                                                                email,
                                                                style:
                                                                    GoogleFonts
                                                                        .poppins(
                                                                  color: color0,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                  fontSize: 14,
                                                                ),
                                                              ),
                                                            ),
                                                            IconButton(
                                                                onPressed: () {
                                                                  _showWifiRestrictionDialog(
                                                                      email);
                                                                },
                                                                icon:
                                                                    const Icon(
                                                                  HugeIcons
                                                                      .strokeRoundedDelete02,
                                                                  color: color4,
                                                                ))
                                                          ],
                                                        ),
                                                        if (isRestricted) ...[
                                                          const SizedBox(
                                                              height: 10),
                                                          Text(
                                                            'No puede acceder al WiFi',
                                                            style: GoogleFonts
                                                                .poppins(
                                                              color: Colors.red,
                                                              fontSize: 12,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                          ),
                                                        ] else
                                                          Text(
                                                            'Acceso completo al WiFi',
                                                            style: GoogleFonts
                                                                .poppins(
                                                              color: color0
                                                                  .withValues(
                                                                      alpha:
                                                                          0.7),
                                                              fontSize: 12,
                                                              fontStyle:
                                                                  FontStyle
                                                                      .italic,
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                  );
                                                },
                                              ),
                                            ],
                                          ),
                                        )
                                      : const SizedBox(),
                                ),
                              ],
                            ],
                          ],
                        )
                      : const SizedBox(),
                ),
              ),
              const SizedBox(height: 30),
              if (!tenant &&
                  pc != '027131_IOT' &&
                  pc != '024011_IOT' &&
                  pc != '015773_IOT' &&
                  pc != '023430_IOT' &&
                  globalDATA['$pc/$sn']?['riegoActive'] != true) ...[
                SizedBox(
                  key: keys['managerScreen:accesoRapido']!,
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (pc == '020010_IOT' ||
                          pc == '020020_IOT' ||
                          (pc == '027313_IOT' &&
                              Versioner.isPosterior(
                                  hardwareVersion, '241220A'))) {
                        if (!quickAccesActivated) {
                          int? selectedPin =
                              await showPinSelectionDialog(context);

                          if (selectedPin != null) {
                            pinQuickAccess.addAll(
                                {widget.deviceName: selectedPin.toString()});
                            quickAccess.add(widget.deviceName);
                            await savequickAccess(quickAccess);
                            await savepinQuickAccess(pinQuickAccess);
                            setState(() {
                              quickAccesActivated = true;
                            });
                          }
                        } else {
                          quickAccess.remove(widget.deviceName);
                          pinQuickAccess.remove(widget.deviceName);
                          await savequickAccess(quickAccess);
                          await savepinQuickAccess(pinQuickAccess);
                          setState(() {
                            quickAccesActivated = false;
                          });
                        }
                      } else {
                        if (!quickAccesActivated) {
                          quickAccess.add(widget.deviceName);
                          await savequickAccess(quickAccess);
                          setState(() {
                            quickAccesActivated = true;
                          });
                        } else {
                          quickAccess.remove(widget.deviceName);
                          await savequickAccess(quickAccess);
                          setState(() {
                            quickAccesActivated = false;
                          });
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      foregroundColor: color0,
                      backgroundColor: color1,
                      padding: const EdgeInsets.symmetric(
                          vertical: 11, horizontal: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: Text(
                      quickAccesActivated
                          ? 'Desactivar acceso rápido'
                          : 'Activar acceso rápido',
                      style: GoogleFonts.poppins(
                        color: color0,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              SizedBox(height: 0, key: keys['managerScreen:ejemploNoti']!),

              //! activar notificación de desconexión
              if (owner == '' ||
                  owner == currentUserEmail ||
                  secondaryAdmin) ...{
                ElevatedButton(
                  key: keys['managerScreen:desconexionNotificacion']!,
                  onPressed: () async {
                    if (discNotfActivated) {
                      showAlertDialog(
                        context,
                        true,
                        Text(
                          'Confirmar Desactivación',
                          style: GoogleFonts.poppins(color: color0),
                          textAlign: TextAlign.center,
                        ),
                        Text(
                          '¿Estás seguro de que deseas desactivar la notificación de desconexión?',
                          style: GoogleFonts.poppins(color: color0),
                          textAlign: TextAlign.center,
                        ),
                        [
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            child: Text(
                              'Cancelar',
                              style: GoogleFonts.poppins(color: color0),
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              // Actualizar el estado para desactivar la notificación
                              setState(() {
                                discNotfActivated = false;
                                showNotificationOptions = false;
                              });

                              // Eliminar la configuración de notificación para el dispositivo actual
                              configNotiDsc.removeWhere(
                                  (key, value) => key == widget.deviceName);
                              await saveconfigNotiDsc(configNotiDsc);

                              if (context.mounted) {
                                Navigator.of(context).pop();
                              }
                            },
                            child: Text(
                              'Aceptar',
                              style: GoogleFonts.poppins(color: color0),
                            ),
                          ),
                        ],
                      );
                    } else {
                      // Verificar si la red es inestable antes de permitir activar la notificación
                      bool networkIsUnstable = isWifiNetworkUnstable(pc, sn);

                      if (networkIsUnstable) {
                        showAlertDialog(
                          context,
                          true,
                          Text(
                            'Red inestable detectada',
                            style: GoogleFonts.poppins(color: color0),
                            textAlign: TextAlign.center,
                          ),
                          Text(
                            'No se puede activar la notificación de desconexión porque tu red WiFi está experimentando desconexiones frecuentes (3 o más por hora).\nPor favor, verifica tu conexión a internet antes de continuar.',
                            style: GoogleFonts.poppins(color: color0),
                            textAlign: TextAlign.start,
                          ),
                          [
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              child: Text(
                                'Entendido',
                                style: GoogleFonts.poppins(color: color0),
                              ),
                            ),
                          ],
                        );
                      } else {
                        setState(() {
                          showNotificationOptions = !showNotificationOptions;
                        });
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    foregroundColor: color0,
                    backgroundColor: color1,
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        discNotfActivated
                            ? 'Desactivar notificación\nde desconexión'
                            : 'Activar notificación\nde desconexión',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          color: color0,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              },

              // Tarjeta de opciones de notificación
              AnimatedSize(
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeInOut,
                child: showNotificationOptions
                    ? Container(
                        padding: const EdgeInsets.all(20),
                        margin: const EdgeInsets.only(top: 20),
                        decoration: BoxDecoration(
                          color: color1,
                          borderRadius: BorderRadius.circular(15),
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
                            RadioGroup<int>(
                              groupValue: selectedNotificationOption,
                              onChanged: (int? value) {
                                setState(() {
                                  selectedNotificationOption = value!;
                                });
                              },
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  RadioListTile<int>(
                                    value: 0,
                                    activeColor: color0,
                                    title: Text(
                                      'Instantáneo',
                                      style: GoogleFonts.poppins(color: color0),
                                    ),
                                  ),
                                  RadioListTile<int>(
                                    value: 10,
                                    activeColor: color0,
                                    title: Text(
                                      'Si permanece 10 minutos desconectado',
                                      style: GoogleFonts.poppins(color: color0),
                                    ),
                                  ),
                                  RadioListTile<int>(
                                    value: 60,
                                    activeColor: color0,
                                    title: Text(
                                      'Si permanece 1 hora desconectado',
                                      style: GoogleFonts.poppins(color: color0),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton(
                              onPressed: () async {
                                setState(() {
                                  discNotfActivated = true;
                                  showNotificationOptions = false;
                                });

                                configNotiDsc[widget.deviceName] =
                                    selectedNotificationOption;
                                await saveconfigNotiDsc(configNotiDsc);

                                showNotification(
                                  'Notificación Activada',
                                  'Has activado la notificación de desconexión con la opción seleccionada.',
                                  'noti',
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: color0,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 15, horizontal: 15),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                              child: Text(
                                'Aceptar',
                                style: GoogleFonts.poppins(
                                    color: color1, fontSize: 16),
                              ),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),

              const SizedBox(height: 10),
              if ((pc == '022000_IOT' ||
                      pc == '027000_IOT' ||
                      pc == '041220_IOT') &&
                  hasLED(pc, hardwareVersion)) ...[
                Container(
                  key: keys['managerScreen:led']!,
                  width: MediaQuery.of(context).size.width * 1.5,
                  padding:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                  decoration: BoxDecoration(
                    color: color1,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Modo del led:',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          textStyle: const TextStyle(
                            color: color0,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Transform.scale(
                        scale: 1.5,
                        child: Switch(
                          activeThumbColor: color1,
                          activeTrackColor: color0,
                          inactiveThumbColor: color1,
                          inactiveTrackColor: color0,
                          trackOutlineColor:
                              const WidgetStatePropertyAll(color1),
                          thumbIcon: WidgetStateProperty.resolveWith<Icon?>(
                            (Set<WidgetState> states) {
                              if (states.contains(WidgetState.selected)) {
                                return const Icon(HugeIcons.strokeRoundedMoon02,
                                    color: color0);
                              } else {
                                return const Icon(HugeIcons.strokeRoundedSun03,
                                    color: color0);
                              }
                            },
                          ),
                          value: nightMode,
                          onChanged: (value) {
                            setState(() {
                              nightMode = value;
                              //printLog.i('Estado: $nightMode');
                              int fun = nightMode ? 1 : 0;
                              String data = '$pc[9]($fun)';
                              //printLog.i(data);
                              bluetoothManager.toolsUuid.write(data.codeUnits);
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],

              SizedBox(
                key: keys['managerScreen:imagen']!,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    ImageManager.openImageOptions(context, widget.deviceName,
                        () {
                      setState(() {
                        // La UI se reconstruirá automáticamente para mostrar la nueva imagen
                      });
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    foregroundColor: color0,
                    backgroundColor: color1,
                    padding: const EdgeInsets.symmetric(
                      vertical: 11,
                      horizontal: 20,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Text(
                    'Cambiar imagen del dispositivo',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Control de bomba para dispositivos de riego
              if (globalDATA['$pc/$sn']?['riegoActive'] == true) ...{
                AnimatedContainer(
                  key: keys['managerScreen:bomba']!,
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeInOut,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: color1,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              showBombaControl = !showBombaControl;
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            foregroundColor: color0,
                            backgroundColor: color1,
                            padding: const EdgeInsets.symmetric(
                              vertical: 11,
                              horizontal: 20,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            'Control de bomba',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeInOut,
                        child: showBombaControl
                            ? Padding(
                                padding: const EdgeInsets.all(15.0),
                                child: Column(
                                  children: [
                                    Text(
                                      'Estado actual de la bomba: ${globalDATA['$pc/$sn']?['freeBomb'] ?? false ? 'Manual' : 'Automático'}',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.poppins(
                                        color: color0,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 15),
                                    const Text(
                                      'Introduzca el código para cambiar el uso de la bomba a manual o automático:',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: color0),
                                    ),
                                    const SizedBox(height: 10),
                                    TextField(
                                      controller: bombaController,
                                      obscureText: true,
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        hintText:
                                            'Ingrese código para cambiar el uso de la bomba',
                                        hintStyle: GoogleFonts.poppins(
                                          color: Colors.grey[600],
                                        ),
                                        filled: true,
                                        fillColor: Colors.white,
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(15),
                                          borderSide: BorderSide.none,
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                          horizontal: 20,
                                          vertical: 15,
                                        ),
                                      ),
                                      style: GoogleFonts.poppins(
                                        color: Colors.black,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 15),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: ElevatedButton(
                                            onPressed: () async {
                                              String codigo =
                                                  bombaController.text;
                                              // Aquí puedes cambiar el código por el que desees
                                              if (codigo == '5773') {
                                                // Código de ejemplo
                                                try {
                                                  bool currentStatus =
                                                      globalDATA['$pc/$sn']
                                                              ?['freeBomb'] ??
                                                          false;
                                                  bool newStatus =
                                                      !currentStatus;

                                                  // Actualizar en la base de datos
                                                  await putFreeBomb(
                                                      pc, sn, newStatus);

                                                  // Actualizar en globalDATA
                                                  globalDATA.putIfAbsent(
                                                          '$pc/$sn',
                                                          () =>
                                                              {})['freeBomb'] =
                                                      newStatus;

                                                  // Guardar los datos localmente

                                                  setState(() {});

                                                  showToast(
                                                      'Bomba ${newStatus ? 'manual' : 'automática'} activada correctamente');
                                                } catch (e) {
                                                  printLog.e(
                                                      'Error al cambiar el estado de la bomba: $e');
                                                  showToast(
                                                      'Error al cambiar el estado de la bomba');
                                                }
                                              } else {
                                                showToast('Código incorrecto');
                                                bombaController.clear();
                                              }
                                            },
                                            style: ElevatedButton.styleFrom(
                                              foregroundColor: color1,
                                              backgroundColor: color0,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 12),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(15),
                                              ),
                                            ),
                                            child: Text(
                                              globalDATA['$pc/$sn']
                                                          ?['freeBomb'] ??
                                                      false
                                                  ? 'Cambiar a automático'
                                                  : 'Cambiar a manual',
                                              style: GoogleFonts.poppins(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              },

              if (pc == '050217_IOT') ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      showAlertDialog(
                        context,
                        true,
                        Text(
                          'Beneficios',
                          style: GoogleFonts.poppins(color: color0),
                        ),
                        Text(
                          '- Encendio rapido y sencillo al alcance de tu mano\n- Configura tu temperatura ideal\n- Mayor eficiencia energética\n- Control de consumo inmediato\n- Mayor comodidad\n- Seguridad corte automático sobre temperatura superior a la establecida\n- Programación de encendido por dias o por franjas horarias\n- Mayor durabilidad',
                          style: GoogleFonts.poppins(color: color0),
                        ),
                        [
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            child: Text(
                              'Cerrar',
                              style: GoogleFonts.poppins(color: color0),
                            ),
                          ),
                        ],
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      foregroundColor: color0,
                      backgroundColor: color1,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Text(
                      'Beneficios de termotanque smart',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],

              Container(
                width: MediaQuery.of(context).size.width * 1.5,
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                decoration: BoxDecoration(
                  color: color1,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Versión de Hardware: $hv',
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
                  color: color1,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Versión de Software: $sv',
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
              GestureDetector(
                onTap: () => launchWebURL(linksOfProducts(widget.deviceName)),
                child: Container(
                  width: MediaQuery.of(context).size.width * 1.5,
                  padding:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                  decoration: BoxDecoration(
                    color: color1,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Visitar página web',
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
              ),
              if (specialUser) ...[
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: isWeatherLoading ? null : () => _showDeviceClima(),
                  child: Container(
                    width: MediaQuery.of(context).size.width * 1.5,
                    padding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 20),
                    decoration: BoxDecoration(
                      color: color1,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: isWeatherLoading
                        ? const Center(
                            child: SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: color0,
                                strokeWidth: 2,
                              ),
                            ),
                          )
                        : Text(
                            'Consultar clima del equipo',
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
                ),
              ],
              Padding(
                padding: EdgeInsets.only(bottom: bottomBarHeight + 120),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Método para mostrar QR con información del equipo
  void _showDeviceQR() {
    // Crear datos para el QR
    Map<String, dynamic> deviceData = {
      'deviceName': widget.deviceName,
      'productCode': DeviceManager.getProductCode(widget.deviceName),
      'serialNumber': DeviceManager.extractSerialNumber(widget.deviceName),
      'sharedBy': currentUserEmail,
      'timestamp': DateTime.now().toIso8601String(),
    };

    String qrData = jsonEncode(deviceData);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: color1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Compartir Equipo',
            style: GoogleFonts.poppins(
              color: color0,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          content: SizedBox(
            width: 300,
            height: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Comparte este código QR para que otros usuarios puedan agregar el equipo a sus dispositivos',
                    style: GoogleFonts.poppins(
                      color: color0,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 15),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: QrImageView(
                      data: qrData,
                      version: QrVersions.auto,
                      size: 200.0,
                      backgroundColor: Colors.white,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: Colors.black,
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.deviceName,
                    style: GoogleFonts.poppins(
                      color: color0,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cerrar',
                style: GoogleFonts.poppins(
                  color: color0,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
