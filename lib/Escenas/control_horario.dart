import 'dart:convert';

import 'package:caldensmart/aws/dynamo/dynamo.dart';
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
      final admin = deviceDATA['secondary_admin'] ?? [];
      return owner == '' ||
          owner == currentUserEmail ||
          admin.contains(currentUserEmail);
    }).toList();

    final eventosGrupoYCadena = eventosCreados.where((evento) {
      final eventoType = evento['evento'] as String;
      return eventoType == 'grupo' || eventoType == 'cadena';
    }).toList();

    if (validDevices.isEmpty && eventosGrupoYCadena.isEmpty) {
      return [
        Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'No hay dispositivos o eventos válidos para control horario.',
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

    List<Widget> widgets = [];

    if (eventosGrupoYCadena.isNotEmpty) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Text(
            'EVENTOS DISPONIBLES',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color0.withValues(alpha: 0.9),
              letterSpacing: 1,
            ),
          ),
        ),
      );

      for (final evento in eventosGrupoYCadena) {
        final eventoType = evento['evento'] as String;
        final eventoTitle = evento['title'] as String;
        final isSelected = selectedDevices.contains(eventoTitle);

        widgets.add(
          Container(
            margin: const EdgeInsets.only(bottom: 8.0),
            decoration: BoxDecoration(
              color: isSelected
                  ? color4.withValues(alpha: 0.1)
                  : color0.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(
                color: isSelected ? color4 : color0,
                width: 1.0,
              ),
            ),
            child: ListTile(
              leading: Icon(
                eventoType == 'grupo' ? Icons.group_work_outlined : Icons.link,
                color: eventoType == 'grupo' ? color4 : Colors.orange,
              ),
              title: Text(
                eventoTitle,
                style: GoogleFonts.poppins(color: color0),
              ),
              subtitle: Text(
                'Evento $eventoType',
                style: GoogleFonts.poppins(
                  color: color0.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              ),
              trailing: Checkbox(
                value: isSelected,
                activeColor: color4,
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      selectedDevices.add(eventoTitle);
                    } else {
                      selectedDevices.remove(eventoTitle);
                    }
                  });
                },
              ),
              onTap: () {
                setState(() {
                  if (isSelected) {
                    selectedDevices.remove(eventoTitle);
                  } else {
                    selectedDevices.add(eventoTitle);
                  }
                });
              },
            ),
          ),
        );
      }

      if (validDevices.isNotEmpty) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Text(
              'DISPOSITIVOS INDIVIDUALES',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color0.withValues(alpha: 0.9),
                letterSpacing: 1,
              ),
            ),
          ),
        );
      }
    }

    if (validDevices.isEmpty && eventosGrupoYCadena.isNotEmpty) {
      return widgets;
    }

    widgets.addAll(validDevices.map((equipo) {
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
              ? color4.withValues(alpha: 0.1)
              : color0.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(
            color: (selectedDevices.contains(equipo) || hasSelectedSalida)
                ? color4
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
                        activeColor: color4,
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
                  activeColor: color4,
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
                activeColor: color4,
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
    }).toList());

    return widgets;
  }

  Widget _buildTimeAndDaySelection() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: Text(
            'Selecciona los días del evento',
            style: GoogleFonts.poppins(color: color0, fontSize: 16),
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
              unSelectedDayTextColor: color1,
              selectedDayTextColor: color1,
              selectedDaysFillColor: color4,
              unselectedDaysFillColor: color0,
              border: false,
              width: MediaQuery.of(context).size.width * 0.9,
              boxDecoration: BoxDecoration(
                color: color0,
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
            style: GoogleFonts.poppins(color: color0, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
        const Divider(
          color: color4,
          thickness: 1,
          height: 24,
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: 120,
              maxHeight: 180,
            ),
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
            'Configura la acción para cada dispositivo/evento',
            style: GoogleFonts.poppins(color: color0, fontSize: 16),
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
              String displayName = device;
              String deviceType = 'Dispositivo';
              IconData iconData = Icons.devices_other;
              bool isCadena = false;

              final eventoEncontrado = eventosCreados.firstWhere(
                (evento) => evento['title'] == device,
                orElse: () => <String, dynamic>{},
              );

              if (eventoEncontrado.isNotEmpty) {
                final eventoType = eventoEncontrado['evento'] as String;
                displayName = device;
                deviceType = eventoType == 'grupo' ? 'Grupo' : 'Cadena';
                iconData = eventoType == 'grupo'
                    ? Icons.group_work_outlined
                    : Icons.link;
                isCadena = eventoType == 'cadena';
              } else {
                displayName = nicknamesMap[device] ?? device;
              }

              printLog.i('Device Type = $deviceType');

              return Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                color: color0,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(iconData, color: color1, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              displayName,
                              style: GoogleFonts.poppins(
                                color: color1,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (isCadena) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.blue.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.play_arrow,
                                color: Colors.blue,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Se ejecutará la secuencia completa',
                                  style: GoogleFonts.poppins(
                                    color: Colors.blue,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        Row(
                          children: [
                            Expanded(
                              child: ToggleButtons(
                                isSelected: [isOn == true, isOn == false],
                                onPressed: (i) => setState(() {
                                  deviceActions[device] = i == 0 ? true : false;
                                }),
                                borderRadius: BorderRadius.circular(12),
                                selectedColor: color0,
                                fillColor: isOn
                                    ? Colors.green.withValues(alpha: 0.8)
                                    : color3.withValues(alpha: 0.8),
                                color: color1,
                                borderColor: color1,
                                selectedBorderColor: isOn
                                    ? Colors.green.withValues(alpha: 0.8)
                                    : color3.withValues(alpha: 0.8),
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
      color: color1,
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
                      color: color0,
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
                          color: color0,
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
                      color: currentStep >= 1 ? color4 : color0),
                  _buildStepIndicator(1, 'Horario', currentStep >= 1),
                  Container(
                      width: 30,
                      height: 2,
                      color: currentStep >= 2 ? color4 : color0),
                  _buildStepIndicator(2, 'Acciones', currentStep >= 2),
                  Container(
                      width: 30,
                      height: 2,
                      color: currentStep >= 3 ? color4 : color0),
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
                            backgroundColor: color0,
                            foregroundColor: color1,
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
                          foregroundColor: color1,
                          disabledBackgroundColor:
                              color1.withValues(alpha: 0.5),
                          disabledForegroundColor: color0,
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
            color: isActive ? color4 : color0,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '${step + 1}',
              style: GoogleFonts.poppins(
                color: color1,
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
            color: color0,
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
                style: GoogleFonts.poppins(color: color0, fontSize: 16),
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
                style: GoogleFonts.poppins(color: color0, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: title,
              decoration: InputDecoration(
                hintText: 'Ej: Luces del jardín',
                hintStyle: GoogleFonts.poppins(color: color1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16.0),
                  borderSide: const BorderSide(color: color4),
                ),
                filled: true,
                fillColor: color0,
                errorText: title.text.contains(':')
                    ? 'No se permiten dos puntos (:)'
                    : null,
              ),
              style: GoogleFonts.poppins(color: color1),
              onChanged: (value) {
                setState(() {
                  // Actualizar el estado para mostrar/ocultar el error
                });
              },
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
        int requiredActions = selectedDevices.where((device) {
          final eventoEncontrado = eventosCreados.firstWhere(
            (evento) => evento['title'] == device,
            orElse: () => <String, dynamic>{},
          );
          // Excluir cadenas de los requerimientos
          return !(eventoEncontrado.isNotEmpty &&
              eventoEncontrado['evento'] == 'cadena');
        }).length;

        int configuredActions = deviceActions.entries.where((entry) {
          final eventoEncontrado = eventosCreados.firstWhere(
            (evento) => evento['title'] == entry.key,
            orElse: () => <String, dynamic>{},
          );
          // Excluir cadenas del conteo
          return !(eventoEncontrado.isNotEmpty &&
              eventoEncontrado['evento'] == 'cadena');
        }).length;

        return deviceActions.isNotEmpty && configuredActions >= requiredActions;
      case 3:
        return title.text.isNotEmpty && !title.text.contains(':');
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
            // Verificar si es una cadena buscando en eventosCreados
            final eventoEncontrado = eventosCreados.firstWhere(
              (evento) => evento['title'] == device,
              orElse: () => <String, dynamic>{},
            );

            if (eventoEncontrado.isNotEmpty &&
                eventoEncontrado['evento'] == 'cadena') {
              // Para cadenas, configurar automáticamente como 'ejecutar' (true)
              deviceActions[device] = true;
            } else {
              // Para dispositivos y grupos, valor por defecto false
              deviceActions[device] ??= false;
            }
          }
        }
      });
    } else {
      _confirmarHorario();
    }
  }

  void _confirmarHorario() {
    String horario =
        '${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}';

    // Convertir días de strings a números (0=Domingo, 1=Lunes, etc.)
    List<int> daysAsNumbers = selectedDays
        .map((day) {
          switch (day.toLowerCase()) {
            case 'domingo':
              return 0;
            case 'lunes':
              return 1;
            case 'martes':
              return 2;
            case 'miercoles' || 'miércoles':
              return 3;
            case 'jueves':
              return 4;
            case 'viernes':
              return 5;
            case 'sabado' || 'sábado':
              return 6;
            default:
              return -1; // Error
          }
        })
        .where((day) => day != -1)
        .toList();

    // Obtener información de timezone del dispositivo
    DateTime now = DateTime.now();
    int timezoneOffset = now.timeZoneOffset.inHours;
    String timezoneName = now.timeZoneName;

    Map<String, bool> finalDeviceActions = {};

    for (String item in selectedDevices) {
      // Verificar si es un evento (grupo o cadena)
      final eventoEncontrado = eventosCreados.firstWhere(
        (evento) => evento['title'] == item,
        orElse: () => <String, dynamic>{},
      );

      String finalKey;
      if (eventoEncontrado.isNotEmpty) {
        // Es un evento, agregar el tipo
        final eventoType = eventoEncontrado['evento'] as String;
        finalKey = '$item:$eventoType';
      } else {
        // Es un dispositivo individual, agregar el tipo 'dispositivo'
        finalKey = '$item:dispositivo';
      }
      
      finalDeviceActions[finalKey] = deviceActions[item] ?? false;
    }

    printLog.i("=== CONTROL HORARIO CREADO ===");
    printLog.i("Nombre: ${title.text}");
    printLog.i("Dispositivos/Eventos seleccionados: $selectedDevices");
    printLog.i("Días originales: $selectedDays");
    printLog.i("Días como números: $daysAsNumbers");
    printLog.i("Hora: $horario");
    printLog.i("Acciones (con tipo): $finalDeviceActions");
    printLog.i("Timezone offset: $timezoneOffset");
    printLog.i("Timezone name: $timezoneName");

    Map<String, dynamic> eventoData = {
      'evento': 'horario',
      'title': title.text,
      'selectedDays': List<String>.from(selectedDays),
      'selectedTime': horario,
      'deviceActions': Map<String, bool>.from(finalDeviceActions),
      'deviceGroup': List<String>.from(selectedDevices),
    };

    eventosCreados.add(eventoData);

    showToast("Control horario creado exitosamente");
    printLog.d("$eventosCreados", color: 'verde');

    putEventos(currentUserEmail, eventosCreados);

    if (selectedDevices.isNotEmpty) {
      putEventoControlPorHorarios(horario, currentUserEmail, title.text,
          finalDeviceActions, daysAsNumbers, timezoneOffset, timezoneName);
    }

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
