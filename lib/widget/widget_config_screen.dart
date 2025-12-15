import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:caldensmart/master.dart';
import 'package:caldensmart/logger.dart';
import 'package:caldensmart/aws/dynamo/dynamo.dart';
import 'package:hugeicons/hugeicons.dart';
import 'dart:convert';
import 'widget_models.dart';
import 'widget_service.dart';
import 'widget_channel.dart';

/// Pantalla de configuración del widget
/// Se abre cuando el usuario agrega un widget a la pantalla de inicio
class WidgetConfigScreen extends StatefulWidget {
  final int? widgetId;

  const WidgetConfigScreen({super.key, this.widgetId});

  @override
  State<WidgetConfigScreen> createState() => _WidgetConfigScreenState();
}

class _WidgetConfigScreenState extends State<WidgetConfigScreen> {
  int? widgetId;
  String? selectedDevice;
  int? selectedIoIndex;
  bool isLoading = true;
  bool isLoadingData = true;

  @override
  void initState() {
    super.initState();
    widgetId = widget.widgetId;

    // Cargar datos iniciales primero
    _loadInitialData();
  }

  /// Cargar datos necesarios para la configuración del widget
  Future<void> _loadInitialData() async {
    try {
      printLog.i('Iniciando carga de datos para configuración de widget');

      // Obtener el email del usuario
      currentUserEmail = await getUserMail();

      if (currentUserEmail.isEmpty) {
        printLog.e('Usuario no logueado, no se puede configurar widget');
        if (mounted) {
          showToast('Debes iniciar sesión para crear widgets');
          Navigator.of(context).pop();
        }
        return;
      }

      printLog.i('Usuario logueado: $currentUserEmail');

      // Cargar dispositivos y nicknames
      await getDevices(currentUserEmail);
      await getNicknames(currentUserEmail);

      printLog.i('Datos cargados - Dispositivos: ${previusConnections.length}');

      if (mounted) {
        setState(() {
          isLoadingData = false;
        });
      }

      // Después de cargar los datos, obtener el widget ID
      _loadWidgetId();
    } catch (e) {
      printLog.e('Error cargando datos para widget: $e');
      if (mounted) {
        showToast('Error al cargar datos');
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _loadWidgetId() async {
    // Intentar obtener el widgetId de diferentes fuentes
    if (widgetId == null) {
      // Intentar obtener de los argumentos de la ruta
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is int) {
        setState(() {
          widgetId = args;
          isLoading = false;
        });
        printLog.i('Widget ID recibido por argumentos: $args');
      } else {
        // Si no viene por parámetro ni argumentos, intentar del intent
        await _loadWidgetIdFromIntent();
      }
    } else {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _loadWidgetIdFromIntent() async {
    try {
      // En Android, el widget ID viene como extra en el intent
      final id = await WidgetChannel.getWidgetId();

      if (mounted) {
        setState(() {
          widgetId = id;
          isLoading = false;
        });
      }

      if (id != null) {
        printLog.i('Widget ID recibido: $id');
      }
    } catch (e) {
      printLog.e('Error obteniendo widget ID: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _saveConfiguration() async {
    if (widgetId == null || selectedDevice == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Por favor selecciona un dispositivo')),
        );
      }
      return;
    }

    try {
      String productCode = DeviceManager.getProductCode(selectedDevice!);
      String serialNumber = DeviceManager.extractSerialNumber(selectedDevice!);

      // Obtener nickname correcto dependiendo si es un IO específico o dispositivo completo
      String nickname;
      WidgetType type;

      if (selectedIoIndex != null) {
        // Para IOs, buscar nickname con formato deviceName_ioIndex
        nickname = nicknamesMap['${selectedDevice!}_$selectedIoIndex'] ??
            '${nicknamesMap[selectedDevice!] ?? selectedDevice!} - IO $selectedIoIndex';

        // Determinar tipo según si es entrada o salida
        final deviceData = globalDATA['$productCode/$serialNumber'];
        if (deviceData != null) {
          var ioData = deviceData['io$selectedIoIndex'];
          if (ioData != null) {
            Map<String, dynamic> ioParsed;
            if (ioData is String) {
              ioParsed = jsonDecode(ioData);
            } else {
              ioParsed = ioData as Map<String, dynamic>;
            }

            String pinType = ioParsed['pinType']?.toString() ?? '0';
            bool isInput = pinType != '0';
            type = isInput ? WidgetType.display : WidgetType.control;
          } else {
            type = WidgetType.control;
          }
        } else {
          type = WidgetType.control;
        }
      } else {
        // Para dispositivos normales
        nickname = nicknamesMap[selectedDevice!] ?? selectedDevice!;
        type = getWidgetType(productCode);
      }

      // Crear configuración del widget
      final widgetData = WidgetData(
        widgetId: widgetId!,
        deviceName: selectedDevice!,
        productCode: productCode,
        serialNumber: serialNumber,
        nickname: nickname,
        type: type,
        ioIndex: selectedIoIndex,
      );

      // Guardar configuración
      printLog.i('Guardando configuración del widget...');
      await WidgetService.saveWidgetConfig(widgetData);
      printLog.i('Configuración guardada exitosamente');

      // Obtener estado actual del dispositivo
      printLog.i(
          'Extrayendo estado del dispositivo: $productCode/$serialNumber, ioIndex: $selectedIoIndex');
      final deviceState = WidgetService.extractDeviceState(
        productCode,
        serialNumber,
        selectedIoIndex,
      );
      printLog.i(
          'Estado extraído: online=${deviceState.online}, status=${deviceState.status}');

      // Actualizar el widget
      printLog.i('Actualizando widget con los datos...');
      await WidgetService.updateWidget(widgetData, deviceState);
      printLog.i('Widget actualizado');

      printLog.i('Widget configurado correctamente');

      // Finalizar la configuración correctamente en Android
      // El finish() nativo cerrará la actividad automáticamente
      await WidgetChannel.finishWidgetConfiguration(widgetId!);
    } catch (e) {
      printLog.e('Error guardando configuración: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al configurar el widget')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Mostrar carga mientras se cargan los datos iniciales
    if (isLoadingData) {
      return Scaffold(
        backgroundColor: color0,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/branch/dragon.gif',
                  width: 150,
                  height: 150,
                ),
                const SizedBox(height: 20),
                Text(
                  'Se están cargando los datos de la app, aguarde un momento por favor...',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color1,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Mostrar carga mientras se obtiene el widget ID
    if (isLoading) {
      return const Scaffold(
        backgroundColor: color0,
        body: Center(
          child: CircularProgressIndicator(color: color4),
        ),
      );
    }

    if (widgetId == null) {
      return Scaffold(
        backgroundColor: color0,
        appBar: AppBar(
          backgroundColor: color1,
          title: Text(
            'Error',
            style: GoogleFonts.poppins(color: color0),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(HugeIcons.strokeRoundedInformationCircle,
                    size: 64, color: color4),
                const SizedBox(height: 20),
                Text(
                  'No se pudo configurar el widget',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    color: color1,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  'Por favor intenta nuevamente',
                  style: GoogleFonts.poppins(fontSize: 14, color: color1),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: color0,
      appBar: AppBar(
        backgroundColor: color1,
        title: Text(
          'Configurar Widget',
          style: GoogleFonts.poppins(color: color0),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Título
                  Text(
                    'Selecciona un dispositivo',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: color1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Elige el equipo que deseas controlar desde el widget',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: color1.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Lista de dispositivos
                  _buildDeviceList(),
                ],
              ),
            ),
          ),

          // Botón para guardar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: color1,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: selectedDevice != null ? _saveConfiguration : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: color4,
                disabledBackgroundColor: color4.withValues(alpha: 0.5),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Guardar Configuración',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceList() {
    if (previusConnections.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            children: [
              Icon(HugeIcons.strokeRoundedLaptopPhoneSync,
                  size: 64, color: color1.withValues(alpha: 0.3)),
              const SizedBox(height: 20),
              Text(
                'No hay dispositivos conectados',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: color1,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Conecta tus dispositivos primero desde la app',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: color1.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Filtrar dispositivos que NO deben tener widget (Riel y Roll)
    List<String> availableDevices = previusConnections.where((deviceName) {
      String productCode = DeviceManager.getProductCode(deviceName);
      return shouldHaveWidget(productCode);
    }).toList();

    // Expandir dispositivos multi-output en entradas separadas
    List<Map<String, dynamic>> deviceEntries = [];

    for (String deviceName in availableDevices) {
      String productCode = DeviceManager.getProductCode(deviceName);
      String serialNumber = DeviceManager.extractSerialNumber(deviceName);
      final deviceData = globalDATA['$productCode/$serialNumber'];

      // Verificar permisos de owner/admin antes de agregar el dispositivo
      if (deviceData != null) {
        String? owner = deviceData['owner'] as String?;
        List<dynamic>? admins = deviceData['secondary_admin'] as List<dynamic>?;
        List<String> adminEmails = admins?.cast<String>() ?? [];

        bool isOwner = owner == currentUserEmail;
        bool isAdmin = adminEmails.contains(currentUserEmail);
        bool hasOwner = owner != null && owner.isNotEmpty;

        // Solo permitir si es owner, admin, o el equipo no tiene owner asignado
        if (!isOwner && !isAdmin && hasOwner) {
          printLog.i(
              'Dispositivo $deviceName omitido: usuario no es owner ni admin');
          continue; // Saltar este dispositivo
        }
      }

      bool hasMultipleOutputs = _hasMultipleOutputs(productCode);

      // Para relés, verificar si realmente tiene io
      if (productCode == '027313_IOT' && deviceData != null) {
        int ioCount = _getOutputCount(productCode, deviceData);
        hasMultipleOutputs = ioCount > 0;
      }

      if (hasMultipleOutputs && deviceData != null) {
        // Crear una entrada para cada io (salida o entrada)
        int ioCount = _getOutputCount(productCode, deviceData);
        for (int i = 0; i < ioCount; i++) {
          // Verificar si es entrada o salida
          String ioKey = 'io$i';
          var ioData = deviceData[ioKey];

          if (ioData != null) {
            Map<String, dynamic> ioParsed;
            if (ioData is String) {
              ioParsed = jsonDecode(ioData);
            } else {
              ioParsed = ioData as Map<String, dynamic>;
            }

            // Parsear pinType - puede venir como String o int
            var pinTypeRaw = ioParsed['pinType'];
            String pinType = pinTypeRaw?.toString() ?? '0';

            printLog.d(
                'Device: $deviceName, IO: $i, pinTypeRaw: $pinTypeRaw (${pinTypeRaw.runtimeType}), pinType: $pinType');

            bool isOutput = pinType == '0';
            String ioType = isOutput ? 'Salida' : 'Entrada';

            // Obtener nickname personalizado o usar nombre por defecto
            String? customName = nicknamesMap['${deviceName}_$i'];
            String displayName = customName ??
                '${nicknamesMap[deviceName] ?? deviceName} - $ioType ${i + 1}';

            printLog.d(
                'IO $i configurado como: $ioType (pinType=$pinType, isOutput=$isOutput)');

            deviceEntries.add({
              'deviceName': deviceName,
              'ioIndex': i,
              'displayName': displayName,
              'isInput': !isOutput,
            });
          }
        }
      } else {
        // Dispositivo normal sin múltiples salidas
        deviceEntries.add({
          'deviceName': deviceName,
          'ioIndex': null,
          'displayName': nicknamesMap[deviceName] ?? deviceName,
        });
      }
    }

    if (deviceEntries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            children: [
              Icon(HugeIcons.strokeRoundedUnavailable,
                  size: 64, color: color1.withValues(alpha: 0.3)),
              const SizedBox(height: 20),
              Text(
                'No hay dispositivos disponibles',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: color1,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Los dispositivos deben ser compatibles y tener permisos de administrador',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: color1.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: deviceEntries.length,
      itemBuilder: (context, index) {
        final entry = deviceEntries[index];
        String deviceName = entry['deviceName'];
        int? ioIndex = entry['ioIndex'];
        String displayName = entry['displayName'];
        bool? isInput = entry['isInput'];

        String productCode = DeviceManager.getProductCode(deviceName);
        String serialNumber = DeviceManager.extractSerialNumber(deviceName);

        // Determinar tipo de widget: si es entrada específica, es display; si es salida o dispositivo completo, usar getWidgetType
        WidgetType type;
        if (isInput != null) {
          // Es un IO específico (entrada o salida)
          type = isInput ? WidgetType.display : WidgetType.control;
        } else {
          // Es un dispositivo completo, usar la función normal
          type = getWidgetType(productCode);
        }

        final deviceData = globalDATA['$productCode/$serialNumber'];
        bool online = deviceData?['cstate'] ?? false;

        bool isSelected =
            selectedDevice == deviceName && selectedIoIndex == ioIndex;

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          color: isSelected ? color4.withValues(alpha: 0.2) : color1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isSelected ? color4 : Colors.transparent,
              width: 2,
            ),
          ),
          child: ListTile(
            onTap: () {
              setState(() {
                selectedDevice = deviceName;
                selectedIoIndex = ioIndex;
              });
            },
            leading: Icon(
              _getDeviceIcon(type),
              color: online ? Colors.green : color3,
              size: 32,
            ),
            title: Text(
              displayName,
              style: GoogleFonts.poppins(
                color: color0,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  deviceName,
                  style: GoogleFonts.poppins(
                    color: color0.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    online
                        ? ImageIcon(
                            const AssetImage(CaldenIcons.cloud),
                            color: online ? Colors.green : color3,
                            size: 25,
                          )
                        : ImageIcon(
                            const AssetImage(CaldenIcons.cloudOff),
                            size: 14,
                            color: online ? Colors.green : color3,
                          ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        online ? 'Conectado' : 'Desconectado',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: online ? Colors.green : color3,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            trailing: _getWidgetTypeBadge(type),
          ),
        );
      },
    );
  }

  bool _hasMultipleOutputs(String productCode) {
    // Productos con múltiples salidas (io0, io1, etc.)
    switch (productCode) {
      case '020010_IOT': // Domotica
      case '020020_IOT': // Módulo
      case '027313_IOT': // Relé (algunos casos)
        return true;
      default:
        return false;
    }
  }

  int _getOutputCount(String productCode, Map<String, dynamic> deviceData) {
    // Contar las salidas disponibles
    int count = 0;
    for (int i = 0; i < 10; i++) {
      if (deviceData.containsKey('io$i')) {
        count++;
      }
    }

    // Si no tiene io, el relé se maneja como dispositivo normal
    if (count == 0 && productCode == '027313_IOT') {
      return 0; // Indicar que no tiene múltiples salidas
    }

    return count > 0
        ? count
        : 2; // Por defecto 2 salidas si no se puede determinar
  }

  IconData _getDeviceIcon(WidgetType type) {
    switch (type) {
      case WidgetType.display:
        return HugeIcons.strokeRoundedCellularNetwork;
      case WidgetType.control:
        return HugeIcons.strokeRoundedPlugSocket;
    }
  }

  Widget _getWidgetTypeBadge(WidgetType type) {
    Color badgeColor;
    String label;
    IconData icon;

    switch (type) {
      case WidgetType.display:
        badgeColor = Colors.blue;
        label = 'Visualización';
        icon = HugeIcons.strokeRoundedView;
        break;
      case WidgetType.control:
        badgeColor = Colors.orange;
        label = 'Control';
        icon = HugeIcons.strokeRoundedTap07;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: badgeColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: badgeColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: badgeColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
