import 'dart:convert';

import 'package:caldensmart/logger.dart';
import 'package:caldensmart/master.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ControlHorarioWidget extends StatefulWidget {
  final VoidCallback? onBackToMain;
  const ControlHorarioWidget({super.key, this.onBackToMain});

  @override
  ControlHorarioWidgetState createState() => ControlHorarioWidgetState();
}

class ControlHorarioWidgetState extends State<ControlHorarioWidget> {
  int currentStep = 0;
  List<String> selectedDevices = [];
  List<String> selectedDays = [];
  TimeOfDay? selectedTime;
  Map<String, bool> deviceActions = {};
  Map<String, Duration> deviceDelays = {};
  Map<String, String> deviceUnits = {};
  TextEditingController title = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() {
    selectedDevices.clear();
    selectedDays.clear();
    selectedTime = null;
    deviceActions.clear();
    deviceDelays.clear();
    deviceUnits.clear();
    currentStep = 0;
  }

  bool _isValidForHorario(String equipo) {
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

  List<Widget> _buildDeviceSelection() {
    // Filtrar equipos válidos
    final validDevices = filterDevices.where((equipo) {
      if (!_isValidForHorario(equipo)) return false;
      final deviceKey =
          '${DeviceManager.getProductCode(equipo)}/${DeviceManager.extractSerialNumber(equipo)}';
      final deviceDATA = globalDATA[deviceKey] ?? {};
      final owner = deviceDATA['owner'] ?? '';
      return owner == '' || owner == currentUserEmail;
    }).toList();

    if (validDevices.isEmpty) {
      return [
        Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'No hay dispositivos válidos para control horario.',
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
        return selectedDevices.contains(salidaId);
      });

      return Container(
        margin: const EdgeInsets.only(bottom: 8.0),
        decoration: BoxDecoration(
          color: (selectedDevices.contains(equipo) || hasSelectedSalida)
              ? color6.withValues(alpha: 0.1)
              : color0.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(
            color: (selectedDevices.contains(equipo) || hasSelectedSalida)
                ? color6
                : color0,
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
                      final rawData = deviceDATA[key];
                      final data =
                          rawData is String ? jsonDecode(rawData) : rawData;
                      final pinType =
                          int.tryParse(data['pinType'].toString()) ?? -1;

                      // Solo mostrar salidas (pinType = 0)
                      if (pinType != 0) return const SizedBox.shrink();

                      final salidaIndex = key.replaceAll('io', '');
                      final salidaId = '${equipo}_$salidaIndex';
                      final isChecked = selectedDevices.contains(salidaId);

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
                              selectedDevices.add(salidaId);
                            } else {
                              selectedDevices.remove(salidaId);
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
                  value: selectedDevices.contains(equipo),
                  activeColor: color6,
                  onChanged: (value) {
                    setState(() {
                      if (value == true) {
                        selectedDevices.add(equipo);
                      } else {
                        selectedDevices.remove(equipo);
                      }
                    });
                  },
                ),
              ],
            ] else ...[
              CheckboxListTile(
                title: Text(displayName,
                    style: GoogleFonts.poppins(color: color0)),
                value: selectedDevices.contains(equipo),
                activeColor: color6,
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      selectedDevices.add(equipo);
                    } else {
                      selectedDevices.remove(equipo);
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

  Widget _buildTimeAndDaySelection() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: Text(
            'Selecciona los días del evento',
            style: GoogleFonts.poppins(color: color1, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.9,
            child: SelectWeekDays(
              key: selectWeekDaysKey,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              days: [
                DayInWeek("L", dayKey: "Lunes"),
                DayInWeek("M", dayKey: "Martes"),
                DayInWeek("X", dayKey: "Miércoles"),
                DayInWeek("J", dayKey: "Jueves"),
                DayInWeek("V", dayKey: "Viernes"),
                DayInWeek("S", dayKey: "Sábado"),
                DayInWeek("D", dayKey: "Domingo"),
              ],
              unSelectedDayTextColor: color3,
              selectedDayTextColor: color3,
              selectedDaysFillColor: color6,
              unselectedDaysFillColor: color0,
              border: false,
              width: MediaQuery.of(context).size.width * 0.9,
              boxDecoration: BoxDecoration(
                color: color1,
                borderRadius: BorderRadius.circular(20.0),
              ),
              onSelect: (values) {
                setState(() {
                  selectedDays = values;
                });
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            'Selecciona la hora del evento',
            style: GoogleFonts.poppins(color: color1, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 8),
        Flexible(
          child: SizedBox(
            height: 150,
            child: TimeSelector(
              onTimeChanged: (TimeOfDay time) {
                setState(() {
                  selectedTime = time;
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionsSelection() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: Text(
            'Configura la acción para cada dispositivo',
            style: GoogleFonts.poppins(color: color1, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 12),
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: selectedDevices.length,
            itemBuilder: (context, index) {
              final device = selectedDevices[index];
              final isOn = deviceActions[device] ?? false;
              final unit = deviceUnits[device] ?? 'seg';
              final delay = deviceDelays[device] ?? const Duration(seconds: 0);
              final displayName = nicknamesMap[device] ?? device;

              return Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
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
                              displayName,
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
                            flex: 2,
                            child: TextField(
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: color2,
                                hintText: '0',
                                hintStyle: GoogleFonts.poppins(
                                  color: color3.withValues(alpha: 0.6),
                                  fontSize: 12,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: color6),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                  horizontal: 12,
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
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 3,
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
                                minHeight: 36,
                                minWidth: 60,
                              ),
                              children: [
                                Text('seg',
                                    style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w500)),
                                Text('min',
                                    style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
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
                              constraints: const BoxConstraints(
                                minHeight: 36,
                                minWidth: 100,
                              ),
                              children: [
                                Text('Encender',
                                    style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w500)),
                                Text('Apagar',
                                    style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                        ],
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
                        'Control por Horario',
                        style: GoogleFonts.poppins(
                          color: color1,
                          fontSize: 20,
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
                  _buildStepIndicator(1, 'Horario', currentStep >= 1),
                  Container(
                      width: 30,
                      height: 2,
                      color: currentStep >= 2 ? color6 : color0),
                  _buildStepIndicator(2, 'Acciones', currentStep >= 2),
                  Container(
                      width: 30,
                      height: 2,
                      color: currentStep >= 3 ? color6 : color0),
                  _buildStepIndicator(3, 'Nombre', currentStep >= 3),
                ],
              ),
            ),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.5,
                minHeight: 0,
              ),
              child: _buildCurrentStepContent(),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  if (currentStep > 0)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Atrás'),
                          onPressed: () {
                            setState(() {
                              currentStep--;
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: color1,
                            foregroundColor: color3,
                            elevation: 2,
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(left: currentStep > 0 ? 8.0 : 0),
                      child: ElevatedButton.icon(
                        icon: Icon(currentStep < 3
                            ? Icons.arrow_forward
                            : Icons.check),
                        label:
                            Text(currentStep < 3 ? 'Continuar' : 'Confirmar'),
                        onPressed: _canContinue() ? _handleContinue : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: color0,
                          foregroundColor: color3,
                          disabledBackgroundColor: color3.withValues(alpha: 0.5),
                          disabledForegroundColor: color1,
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
                'Selecciona los dispositivos',
                style: GoogleFonts.poppins(color: color1, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: _buildDeviceSelection(),
              ),
            ),
          ],
        );
      case 1:
        return _buildTimeAndDaySelection();
      case 2:
        return _buildActionsSelection();
      case 3:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Text(
                'Nombre del control horario',
                style: GoogleFonts.poppins(color: color1, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: title,
              decoration: InputDecoration(
                hintText: 'Ej: Luces del jardín',
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

  bool _canContinue() {
    switch (currentStep) {
      case 0:
        return selectedDevices.isNotEmpty;
      case 1:
        return selectedDays.isNotEmpty && selectedTime != null;
      case 2:
        return deviceActions.isNotEmpty &&
            deviceActions.length == selectedDevices.length;
      case 3:
        return title.text.isNotEmpty;
      default:
        return false;
    }
  }

  void _handleContinue() {
    if (currentStep < 3) {
      setState(() {
        currentStep++;
        if (currentStep == 2) {
          for (String device in selectedDevices) {
            deviceActions[device] ??= false;
            deviceDelays[device] ??= const Duration(seconds: 0);
            deviceUnits[device] ??= 'seg';
          }
        }
      });
    } else {
      _confirmarHorario();
    }
  }

  void _confirmarHorario() {
    printLog.i("=== CONTROL HORARIO CREADO ===");
    printLog.i("Nombre: ${title.text}");
    printLog.i("Dispositivos: $selectedDevices");
    printLog.i("Días: $selectedDays");
    printLog.i("Hora: ${selectedTime!.hour}:${selectedTime!.minute}");
    printLog.i("Acciones: $deviceActions");
    printLog.i("Delays: $deviceDelays");

    eventosCreados.add({
      'evento': 'horario',
      'title': title.text,
      'selectedDays': List<String>.from(selectedDays),
      'selectedTime':
          '${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}',
      'deviceActions': Map<String, bool>.from(deviceActions),
      'deviceDelays': Map<String, Duration>.from(deviceDelays),
      'deviceGroup': List<String>.from(selectedDevices),
    });

    showToast("Control horario creado exitosamente");
    printLog.i("$eventosCreados", color: 'verde');

    setState(() {
      _initializeData();
      title.clear();
    });

    if (widget.onBackToMain != null) {
      widget.onBackToMain!();
    }
  }

  @override
  void dispose() {
    title.dispose();
    super.dispose();
  }
}
