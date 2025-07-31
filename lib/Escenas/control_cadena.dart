// ignore_for_file: equal_elements_in_set

import 'dart:convert';

import 'package:caldensmart/logger.dart';
import 'package:caldensmart/master.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ControlCadenaWidget extends StatefulWidget {
  final VoidCallback? onBackToMain;
  const ControlCadenaWidget({super.key, this.onBackToMain});

  @override
  ControlCadenaWidgetState createState() => ControlCadenaWidgetState();
}

class ControlCadenaWidgetState extends State<ControlCadenaWidget> {
  int currentStep = 0;
  TextEditingController title = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() {
    deviceGroup.clear();
    deviceActions.clear();
    deviceDelays.clear();
    deviceUnits.clear();
    currentStep = 0;
  }

  bool _isValidForCascada(String equipo) {
    final displayName = nicknamesMap[equipo] ?? equipo;
    if (displayName.isEmpty) return false;

    // Excluir detectores, Termometros y patitos
    if (equipo.contains('Detector') ||
        equipo.contains('Termometro') ||
        equipo.contains('Patito')) {
      return false;
    }

    // Para Domotica, Modulo y Rele, verificar que tengan salidas
    if (equipo.contains('Domotica') ||
        equipo.contains('Modulo') ||
        equipo.contains('Rele')) {
      final deviceKey =
          '${DeviceManager.getProductCode(equipo)}/${DeviceManager.extractSerialNumber(equipo)}';
      final deviceDATA = globalDATA[deviceKey] ?? {};

      // Si no tiene pines IO, es válido
      final hasPinsIO = deviceDATA.keys.any((k) => k.startsWith('io'));
      if (!hasPinsIO) return true;

      // Verificar que tenga al menos una salida (pinType = 0)
      final hasSalidas =
          deviceDATA.keys.where((k) => k.startsWith('io')).any((key) {
        final rawData = deviceDATA[key];
        final data = rawData is String ? jsonDecode(rawData) : rawData;
        final pinType = int.tryParse(data['pinType'].toString()) ?? -1;
        return pinType == 0;
      });

      return hasSalidas;
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color3,
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header con título y navegación
            Container(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                children: [
                  Opacity(
                    opacity: currentStep == 0 ? 1.0 : 0.0,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back),
                      color: color1,
                      onPressed: currentStep == 0
                          ? () {
                              if (widget.onBackToMain != null) {
                                widget.onBackToMain!();
                              }
                            }
                          : null,
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        'Control por cadena',
                        style: GoogleFonts.poppins(
                          color: color1,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            const SizedBox(height: 6),

            // Indicador de pasos
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildStepIndicator(0, 'Dispositivos', currentStep >= 0),
                  Container(
                      width: 30,
                      height: 2,
                      color: currentStep >= 1 ? color6 : color0),
                  _buildStepIndicator(1, 'Configuración', currentStep >= 1),
                  Container(
                      width: 30,
                      height: 2,
                      color: currentStep >= 2 ? color6 : color0),
                  _buildStepIndicator(2, 'Nombre', currentStep >= 2),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Contenido del paso actual
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.5,
                minHeight: 0,
              ),
              child: _buildCurrentStepContent(),
            ),
            const SizedBox(height: 8),

            // Botones de navegación
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  if (currentStep > 0)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ElevatedButton(
                          onPressed: () => setState(() => currentStep--),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: color0,
                            foregroundColor: color3,
                            padding: const EdgeInsets.symmetric(vertical: 12.0),
                          ),
                          child: const Text('Anterior'),
                        ),
                      ),
                    ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(left: currentStep > 0 ? 8.0 : 0),
                      child: ElevatedButton.icon(
                        icon: Icon(currentStep == 2
                            ? Icons.check
                            : Icons.arrow_forward),
                        label:
                            Text(currentStep == 2 ? 'Confirmar' : 'Continuar'),
                        onPressed:
                            _canContinue() ? () => _handleContinue() : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: color0,
                          foregroundColor: color3,
                          disabledForegroundColor: color3.withValues(alpha: 0.5),
                          disabledBackgroundColor: color0,
                          padding: const EdgeInsets.symmetric(vertical: 12.0),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator(int step, String label, bool isActive) {
    return Column(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: isActive ? color6 : color0,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '${step + 1}',
              style: GoogleFonts.poppins(
                color: color3,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.poppins(
            color: color1,
            fontSize: 9,
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentStepContent() {
    switch (currentStep) {
      case 0:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Text(
                'Selecciona los dispositivos en el orden que desees accionarlos',
                style: GoogleFonts.poppins(color: color1, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: _buildDeviceList(),
              ),
            ),
          ],
        );
      case 1:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Text(
                'Configura el tiempo entre los equipos y la acción',
                style: GoogleFonts.poppins(color: color1, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: deviceGroup.length,
                itemBuilder: (context, index) {
                  final device = deviceGroup[index];
                  final isOn = deviceActions[device] ?? false;
                  final unit = deviceUnits[device] ?? 'seg';
                  final delay =
                      deviceDelays[device] ?? const Duration(seconds: 0);

                  return Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    margin:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    color: color1,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.devices_other,
                                  color: color3, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  nicknamesMap[device] ?? device,
                                  style: GoogleFonts.poppins(
                                    color: color3,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: TextField(
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: color2,
                                    hintText: '0',
                                    hintStyle: GoogleFonts.poppins(
                                      color: color3.withAlpha(150),
                                      fontSize: 12,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide:
                                          const BorderSide(color: color6),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                      horizontal: 8,
                                    ),
                                  ),
                                  controller: TextEditingController(
                                    text: unit == 'seg'
                                        ? delay.inSeconds.toString()
                                        : delay.inMinutes.toString(),
                                  )..selection = TextSelection.collapsed(
                                      offset: (unit == 'seg'
                                              ? delay.inSeconds
                                              : delay.inMinutes)
                                          .toString()
                                          .length,
                                    ),
                                  onChanged: (value) {
                                    int val = int.tryParse(value) ?? 0;
                                    if (val > 60) val = 60;
                                    setState(() {
                                      if (deviceUnits[device] == 'min') {
                                        deviceDelays[device] =
                                            Duration(minutes: val);
                                      } else {
                                        deviceDelays[device] =
                                            Duration(seconds: val);
                                      }
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 4,
                                child: ToggleButtons(
                                  isSelected: [unit == 'seg', unit == 'min'],
                                  onPressed: (i) => setState(() {
                                    final currentValue = unit == 'seg'
                                        ? delay.inSeconds
                                        : delay.inMinutes;
                                    final newUnit = i == 0 ? 'seg' : 'min';
                                    deviceUnits[device] = newUnit;
                                    deviceDelays[device] = newUnit == 'seg'
                                        ? Duration(seconds: currentValue)
                                        : Duration(minutes: currentValue);
                                  }),
                                  borderRadius: BorderRadius.circular(12),
                                  selectedColor: color1,
                                  fillColor: color4.withValues(alpha: 0.8),
                                  color: color3,
                                  borderColor: color4,
                                  selectedBorderColor: color4,
                                  constraints: const BoxConstraints(
                                    minHeight: 32,
                                    minWidth: 40,
                                  ),
                                  children: [
                                    Text('seg',
                                        style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w500,
                                            fontSize: 11)),
                                    Text('min',
                                        style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w500,
                                            fontSize: 11)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: ToggleButtons(
                              isSelected: [isOn == true, isOn == false],
                              onPressed: (i) => setState(() {
                                deviceActions[device] = i == 0 ? true : false;
                              }),
                              borderRadius: BorderRadius.circular(12),
                              selectedColor: color1,
                              fillColor: isOn
                                  ? Colors.green.withValues(alpha: 0.8)
                                  : color5.withValues(alpha: 0.8),
                              color: color3,
                              borderColor: color3,
                              selectedBorderColor: isOn
                                  ? Colors.green.withValues(alpha: 0.8)
                                  : color5.withValues(alpha: 0.8),
                              constraints: BoxConstraints(
                                minHeight: 36,
                                minWidth:
                                    MediaQuery.of(context).size.width * 0.25,
                              ),
                              children: [
                                Text('Encender',
                                    style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 12)),
                                Text('Apagar',
                                    style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      case 2:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Text(
                'Escribe el nombre de la cascada',
                style: GoogleFonts.poppins(color: color1, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: title,
              decoration: InputDecoration(
                hintText: 'Ej: Cascada de luces',
                hintStyle: GoogleFonts.poppins(color: color3),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16.0),
                  borderSide: const BorderSide(color: color6),
                ),
                filled: true,
                fillColor: color1,
              ),
              style: GoogleFonts.poppins(color: color3),
            ),
            const SizedBox(height: 16),
          ],
        );
      default:
        return const SizedBox();
    }
  }

  List<Widget> _buildDeviceList() {
    // Filtrar equipos válidos
    final validDevices = filterDevices.where((equipo) {
      if (!_isValidForCascada(equipo)) return false;
      final deviceKey =
          '${DeviceManager.getProductCode(equipo)}/${DeviceManager.extractSerialNumber(equipo)}';
      final deviceDATA = globalDATA[deviceKey] ?? {};
      final owner = deviceDATA['owner'] ?? '';
      return owner == '' || owner == currentUserEmail;
    }).toList();

    if (validDevices.length < 2) {
      return [
        Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Se necesitan al menos 2 equipos válidos para crear una cascada.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: Colors.red,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ];
    }

    return validDevices.map((equipo) {
      final displayName = nicknamesMap[equipo] ?? equipo;
      final deviceKey =
          '${DeviceManager.getProductCode(equipo)}/${DeviceManager.extractSerialNumber(equipo)}';
      final deviceDATA = globalDATA[deviceKey] ?? {};

      final salidaKeys =
          deviceDATA.keys.where((k) => k.startsWith('io')).toList()
            ..sort((a, b) {
              final numA = int.tryParse(a.substring(2)) ?? 0;
              final numB = int.tryParse(b.substring(2)) ?? 0;
              return numA.compareTo(numB);
            });

      final hasSelectedSalida = salidaKeys.any((key) {
        final rawData = deviceDATA[key];
        final data = rawData is String ? jsonDecode(rawData) : rawData;
        final pinType = int.tryParse(data['pinType'].toString()) ?? -1;
        if (pinType != 0) return false;
        final salidaId = '${equipo}_${key.replaceAll("io", "")}';
        return deviceGroup.contains(salidaId);
      });

      final isEquipoSelected =
          deviceGroup.contains(equipo) || hasSelectedSalida;

      return Container(
        margin: const EdgeInsets.only(bottom: 8.0),
        decoration: BoxDecoration(
          color: isEquipoSelected
              ? color6.withValues(alpha: 0.1)
              : color0.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(
            color: isEquipoSelected ? color6 : color0,
            width: 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (equipo.contains('Domotica') ||
                equipo.contains('Modulo') ||
                equipo.contains('Rele')) ...[
              if (deviceDATA.keys.any((k) => k.startsWith('io'))) ...[
                ListTile(
                  title: Text(displayName,
                      style: GoogleFonts.poppins(color: color0)),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 32.0, bottom: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: salidaKeys.map((key) {
                      if (!deviceDATA.containsKey(key)) {
                        return ListTile(
                          title: Text(
                            'Error en el equipo',
                            style: GoogleFonts.poppins(
                              color: color0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            'Se solucionará automáticamente en poco tiempo...',
                            style: GoogleFonts.poppins(color: color0),
                          ),
                        );
                      }
                      final raw = deviceDATA[key];
                      final data = raw is String ? jsonDecode(raw) : raw;
                      final pinType =
                          int.tryParse(data['pinType'].toString()) ?? -1;

                      // Solo mostrar salidas (pinType = 0)
                      if (pinType != 0) return const SizedBox.shrink();

                      final salidaIndex = key.replaceAll('io', '');
                      final salidaId = '${equipo}_$salidaIndex';
                      final isChecked = deviceGroup.contains(salidaId);

                      return CheckboxListTile(
                        title: Text(
                          nicknamesMap[salidaId] ?? 'Salida $salidaIndex',
                          style: GoogleFonts.poppins(color: color0),
                        ),
                        value: isChecked,
                        activeColor: color6,
                        onChanged: (value) {
                          setState(() {
                            if (value == true) {
                              deviceGroup.add(salidaId);
                            } else {
                              deviceGroup.remove(salidaId);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
              ] else ...[
                CheckboxListTile(
                  title: Text(displayName,
                      style: GoogleFonts.poppins(color: color0)),
                  value: deviceGroup.contains(equipo),
                  activeColor: color6,
                  onChanged: (value) {
                    setState(() {
                      if (value == true) {
                        deviceGroup.add(equipo);
                      } else {
                        deviceGroup.remove(equipo);
                      }
                    });
                  },
                ),
              ],
            ] else ...[
              CheckboxListTile(
                title: Text(displayName,
                    style: GoogleFonts.poppins(color: color0)),
                value: deviceGroup.contains(equipo),
                activeColor: color6,
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      deviceGroup.add(equipo);
                    } else {
                      deviceGroup.remove(equipo);
                    }
                  });
                },
              ),
            ],
          ],
        ),
      );
    }).toList();
  }

  bool _canContinue() {
    switch (currentStep) {
      case 0:
        return deviceGroup.length >= 2;
      case 1:
        return deviceGroup.every((device) =>
            deviceActions.containsKey(device) &&
            deviceDelays.containsKey(device));
      case 2:
        return title.text.isNotEmpty;
      default:
        return false;
    }
  }

  void _handleContinue() {
    if (currentStep < 2) {
      setState(() {
        currentStep++;
        // Inicializar valores por defecto para nuevos dispositivos en el paso 1
        if (currentStep == 1) {
          for (final device in deviceGroup) {
            deviceActions[device] ??= false;
            deviceDelays[device] ??= const Duration(seconds: 0);
            deviceUnits[device] ??= 'seg';
          }
        }
      });
    } else {
      _confirmarCascada();
    }
  }

  void _confirmarCascada() {
    printLog.i("=== CONTROL POR CASCADA CREADO ===");
    printLog.i("Nombre: ${title.text}");
    printLog.i("Equipos seleccionados: $deviceGroup");
    printLog.i("Acciones: $deviceActions");
    printLog.i("Delays: $deviceDelays");

    eventosCreados.add({
      'evento': 'cadena',
      'title': title.text,
      'deviceActions': Map<String, bool>.from(deviceActions),
      'deviceDelays': Map<String, Duration>.from(deviceDelays),
      'deviceGroup': List<String>.from(deviceGroup),
    });

    _initializeData();
    title.clear();
    showToast("Cascada confirmada");

    if (widget.onBackToMain != null) {
      widget.onBackToMain!();
    }

    printLog.i(eventosCreados);
  }

  @override
  void dispose() {
    title.dispose();
    super.dispose();
  }
}
