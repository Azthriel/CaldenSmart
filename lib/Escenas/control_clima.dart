import 'dart:convert';

import 'package:caldensmart/logger.dart';
import 'package:caldensmart/master.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';

class ControlClimaWidget extends StatefulWidget {
  final VoidCallback? onBackToMain;
  const ControlClimaWidget({super.key, this.onBackToMain});

  @override
  ControlClimaWidgetState createState() => ControlClimaWidgetState();
}

class ControlClimaWidgetState extends State<ControlClimaWidget> {
  int currentStep = 0;
  TextEditingController title = TextEditingController();
  List<String> deviceGroup = [];
  Map<String, bool> deviceActions = {};
  String selectedWeatherCondition = '';

  final List<String> weatherConditions = [
    'Lluvia',
    'Sol',
    'Viento fuerte',
    'Nieve',
    'Granizo',
    'Neblina',
    'Calor extremo',
    'Frío extremo',
  ];

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() {
    deviceGroup.clear();
    deviceActions.clear();
    currentStep = 0;
    selectedWeatherCondition = weatherConditions.first;
  }

  bool _isValidForClima(String equipo) {
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
      color: color1,
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
                        'Control por clima',
                        style: GoogleFonts.poppins(
                          color: color0,
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
                  _buildStepIndicator(0, 'Condición', currentStep >= 0),
                  Container(
                      width: 30,
                      height: 2,
                      color: currentStep >= 1 ? color4 : color0),
                  _buildStepIndicator(1, 'Dispositivos', currentStep >= 1),
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
                            foregroundColor: color1,
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
                        icon: Icon(currentStep == 3
                            ? Icons.check
                            : Icons.arrow_forward),
                        label:
                            Text(currentStep == 3 ? 'Confirmar' : 'Continuar'),
                        onPressed:
                            _canContinue() ? () => _handleContinue() : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: color0,
                          foregroundColor: color1,
                          disabledForegroundColor:
                              color1.withValues(alpha: 0.5),
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
        return _buildWeatherConditionStep();
      case 1:
        return _buildDeviceSelectionStep();
      case 2:
        return _buildActionConfigurationStep();
      case 3:
        return _buildNameInputStep();
      default:
        return const SizedBox();
    }
  }

  Widget _buildWeatherConditionStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: Text(
            'Selecciona la condición climática',
            style: GoogleFonts.poppins(color: color0, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 20),
        Theme(
          data: Theme.of(context).copyWith(
            canvasColor: Colors.white,
          ),
          child: DropdownButtonHideUnderline(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.6,
              decoration: BoxDecoration(
                color: color0.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: color0, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: DropdownButton<String>(
                  value: selectedWeatherCondition,
                  isExpanded: true,
                  icon: const Icon(
                    HugeIcons.strokeRoundedArrowDown01,
                    color: color0,
                  ),
                  dropdownColor: color1,
                  borderRadius: BorderRadius.circular(15),
                  elevation: 4,
                  style: GoogleFonts.poppins(
                    color: color0,
                    fontSize: 18,
                  ),
                  onChanged: (String? value) {
                    setState(() {
                      selectedWeatherCondition = value!;
                    });
                  },
                  items: weatherConditions
                      .map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Center(
                        child: Text(
                          value,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(color: color0),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildDeviceSelectionStep() {
    final validDevices = filterDevices.where((equipo) {
      if (!_isValidForClima(equipo)) return false;
      final deviceKey =
          '${DeviceManager.getProductCode(equipo)}/${DeviceManager.extractSerialNumber(equipo)}';
      final deviceDATA = globalDATA[deviceKey] ?? {};
      final owner = deviceDATA['owner'] ?? '';
      return owner == '' || owner == currentUserEmail;
    }).toList();

    final eventosGrupoYCadena = eventosCreados.where((evento) {
      final eventoType = evento['evento'] as String;
      return eventoType == 'grupo' || eventoType == 'cadena';
    }).toList();

    if (validDevices.isEmpty && eventosGrupoYCadena.isEmpty) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Text(
              'Selecciona al menos un dispositivo o evento',
              style: GoogleFonts.poppins(color: color0, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'No hay dispositivos o eventos válidos disponibles.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: Colors.red,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: Text(
            'Selecciona al menos un dispositivo',
            style: GoogleFonts.poppins(color: color0, fontSize: 16),
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
  }

  List<Widget> _buildDeviceList() {
    // Filtrar equipos válidos
    final validDevices = filterDevices.where((equipo) {
      if (!_isValidForClima(equipo)) return false;
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
              'No hay dispositivos o eventos válidos disponibles.',
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
        final isSelected = deviceGroup.contains(eventoTitle);

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
                      deviceGroup.add(eventoTitle);
                    } else {
                      deviceGroup.remove(eventoTitle);
                    }
                  });
                },
              ),
              onTap: () {
                setState(() {
                  if (isSelected) {
                    deviceGroup.remove(eventoTitle);
                  } else {
                    deviceGroup.add(eventoTitle);
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
        return deviceGroup.contains(salidaId);
      });

      final isEquipoSelected =
          deviceGroup.contains(equipo) || hasSelectedSalida;

      return Container(
        margin: const EdgeInsets.only(bottom: 8.0),
        decoration: BoxDecoration(
          color: isEquipoSelected
              ? color4.withValues(alpha: 0.1)
              : color0.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(
            color: isEquipoSelected ? color4 : color0,
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
                        activeColor: color4,
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
                  activeColor: color4,
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
                activeColor: color4,
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
    }));

    return widgets;
  }

  Widget _buildActionConfigurationStep() {
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
        const SizedBox(height: 16),
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: deviceGroup.length,
            itemBuilder: (context, index) {
              final device = deviceGroup[index];
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

              final finalDisplayName =
                  displayName.isEmpty ? device : displayName;

              return Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
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
                              finalDisplayName,
                              style: GoogleFonts.poppins(
                                color: color1,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (deviceType != 'Dispositivo') ...{
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: deviceType == 'Grupo'
                                    ? color4.withValues(alpha: 0.2)
                                    : Colors.orange.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                deviceType,
                                style: GoogleFonts.poppins(
                                  color: deviceType == 'Grupo'
                                      ? color4
                                      : Colors.orange,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          },
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (isCadena) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.orange, width: 1),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.play_arrow,
                                  color: Colors.orange, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Se ejecutará automáticamente',
                                style: GoogleFonts.poppins(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        SizedBox(
                          width: double.infinity,
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

  Widget _buildNameInputStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: Text(
            'Escribe el nombre del control climático',
            style: GoogleFonts.poppins(color: color0, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: title,
          decoration: InputDecoration(
            hintText: 'Ej: Control lluvia',
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
            setState(() {});
          },
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  bool _canContinue() {
    switch (currentStep) {
      case 0:
        return selectedWeatherCondition.isNotEmpty;
      case 1:
        return deviceGroup.isNotEmpty;
      case 2:
        int requiredActions = deviceGroup.where((device) {
          final eventoEncontrado = eventosCreados.firstWhere(
            (evento) => evento['title'] == device,
            orElse: () => <String, dynamic>{},
          );
          return !(eventoEncontrado.isNotEmpty &&
              eventoEncontrado['evento'] == 'cadena');
        }).length;

        int configuredActions = deviceActions.entries.where((entry) {
          final eventoEncontrado = eventosCreados.firstWhere(
            (evento) => evento['title'] == entry.key,
            orElse: () => <String, dynamic>{},
          );
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
        // Inicializar valores por defecto para nuevos dispositivos en el paso 2
        if (currentStep == 2) {
          for (String device in deviceGroup) {
            final eventoEncontrado = eventosCreados.firstWhere(
              (evento) => evento['title'] == device,
              orElse: () => <String, dynamic>{},
            );

            if (eventoEncontrado.isNotEmpty &&
                eventoEncontrado['evento'] == 'cadena') {
              deviceActions[device] = true;
            } else {
              deviceActions[device] ??= false;
            }
          }
        }
      });
    } else {
      _confirmarClima();
    }
  }

  void _confirmarClima() {
    printLog.d("=== CONTROL POR CLIMA CREADO ===");
    printLog.d("Nombre: ${title.text}");
    printLog.d("Condición: $selectedWeatherCondition");
    printLog.d("Dispositivos/Eventos seleccionados: $deviceGroup");
    printLog.d("Acciones: $deviceActions");

    Map<String, dynamic> eventoData = {
      'evento': 'clima',
      'title': title.text,
      'condition': selectedWeatherCondition,
      'deviceGroup': List<String>.from(deviceGroup),
      'deviceActions': Map<String, bool>.from(deviceActions),
    };

    eventosCreados.add(eventoData);
    //putEventos(currentUserEmail, eventosCreados);

    showToast("Control climático creado exitosamente");
    printLog.d("$eventosCreados", color: 'verde');

    setState(() {
      _initializeData();
      title.clear();
    });

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
