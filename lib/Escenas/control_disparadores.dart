import 'dart:convert';

import 'package:caldensmart/aws/dynamo/dynamo.dart';
import 'package:caldensmart/logger.dart';
import 'package:caldensmart/master.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ControlDisparadorWidget extends StatefulWidget {
  final VoidCallback? onBackToMain;
  const ControlDisparadorWidget({super.key, this.onBackToMain});

  @override
  ControlDisparadorWidgetState createState() => ControlDisparadorWidgetState();
}

class ControlDisparadorWidgetState extends State<ControlDisparadorWidget> {
  int currentStep = 0;
  List<String> activadores = [];
  List<String> ejecutores = [];
  Map<String, bool> deviceActions = {};
  TextEditingController title = TextEditingController();
  String estadoAlerta = "1";
  String estadoTermometro = "1";

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() {
    activadores.clear();
    ejecutores.clear();
    deviceActions.clear();
    currentStep = 0;
  }

  bool _isActivador(String equipo) {
    final displayName = nicknamesMap[equipo] ?? equipo;
    if (displayName.isEmpty) return false;

    if (equipo.contains('Detector') ||
        equipo.contains('Termometro') ||
        equipo.contains('Patito')) {
      return true;
    }

    if (equipo.contains('Domotica') ||
        equipo.contains('Modulo') ||
        equipo.contains('Rele')) {
      final deviceKey =
          '${DeviceManager.getProductCode(equipo)}/${DeviceManager.extractSerialNumber(equipo)}';
      final deviceDATA = globalDATA[deviceKey] ?? {};

      final hasEntradas =
          deviceDATA.keys.where((k) => k.startsWith('io')).any((key) {
        final rawData = deviceDATA[key];
        final data = rawData is String ? jsonDecode(rawData) : rawData;
        final pinType = int.tryParse(data['pinType'].toString()) ?? -1;
        return pinType != 0;
      });

      return hasEntradas;
    }

    return false;
  }

  bool _isEjecutor(String equipo) {
    final displayName = nicknamesMap[equipo] ?? equipo;
    if (displayName.isEmpty) return false;

    if (equipo.contains('Domotica') ||
        equipo.contains('Modulo') ||
        equipo.contains('Rele')) {
      final deviceKey =
          '${DeviceManager.getProductCode(equipo)}/${DeviceManager.extractSerialNumber(equipo)}';
      final deviceDATA = globalDATA[deviceKey] ?? {};

      final hasPinsIO = deviceDATA.keys.any((k) => k.startsWith('io'));
      if (!hasPinsIO) return true;

      final hasSalidas =
          deviceDATA.keys.where((k) => k.startsWith('io')).any((key) {
        final rawData = deviceDATA[key];
        final data = rawData is String ? jsonDecode(rawData) : rawData;
        final pinType = int.tryParse(data['pinType'].toString()) ?? -1;
        return pinType == 0;
      });

      return hasSalidas;
    }

    if (equipo.contains('Detector') ||
        equipo.contains('Termometro') ||
        equipo.contains('Patito')) {
      return false;
    }

    return true;
  }

  List<Widget> _buildActivadoresSelection() {
    List<Widget> widgets = [];

    for (String equipo in previusConnections) {
      if (!_isActivador(equipo)) continue;

      final displayName = nicknamesMap[equipo] ?? equipo;
      final deviceKey =
          '${DeviceManager.getProductCode(equipo)}/${DeviceManager.extractSerialNumber(equipo)}';
      final deviceDATA = globalDATA[deviceKey] ?? {};
      final owner = deviceDATA['owner'] ?? '';
      final admin = deviceDATA['secondary_admin'] ?? [];

      if (owner != '' &&
          owner != currentUserEmail &&
          !admin.contains(currentUserEmail)) {
        continue;
      }
      // Verificar si este equipo tiene entradas seleccionadas
      final hasSelectedEntrada =
          deviceDATA.keys.where((k) => k.startsWith('io')).any((key) {
        final rawData = deviceDATA[key];
        final data = rawData is String ? jsonDecode(rawData) : rawData;
        final pinType = int.tryParse(data['pinType'].toString()) ?? -1;
        if (pinType == 0) return false; // Solo entradas (pinType != 0)
        final entradaIndex = key.replaceAll('io', '');
        final entradaId = '${equipo}_$entradaIndex';
        return activadores.contains(entradaId);
      });

      final isEquipoSelected =
          activadores.contains(equipo) || hasSelectedEntrada;

      widgets.add(
        Container(
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
                ListTile(
                  title: Text(displayName,
                      style: GoogleFonts.poppins(color: color0)),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 32.0, bottom: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: deviceDATA.keys
                        .where((k) => k.startsWith('io'))
                        .map((key) {
                      final rawData = deviceDATA[key];
                      final data =
                          rawData is String ? jsonDecode(rawData) : rawData;
                      final pinType =
                          int.tryParse(data['pinType'].toString()) ?? -1;

                      if (pinType == 0) return const SizedBox.shrink();

                      final entradaIndex = key.replaceAll('io', '');
                      final entradaId = '${equipo}_$entradaIndex';

                      return RadioListTile<String>(
                        title: Text(
                          nicknamesMap[entradaId] ?? 'Entrada $entradaIndex',
                          style: GoogleFonts.poppins(color: color0),
                        ),
                        value: entradaId,
                        groupValue:
                            activadores.isNotEmpty ? activadores.first : null,
                        activeColor: color4,
                        onChanged: (value) {
                          setState(() {
                            activadores.clear();
                            if (value != null) {
                              activadores.add(value);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
              ] else ...[
                RadioListTile<String>(
                  title: Text(displayName.isEmpty ? equipo : displayName,
                      style: GoogleFonts.poppins(color: color0)),
                  value: equipo,
                  groupValue: activadores.isNotEmpty ? activadores.first : null,
                  activeColor: color4,
                  onChanged: (value) {
                    setState(() {
                      activadores.clear();
                      if (value != null) {
                        activadores.add(value);
                      }
                    });
                  },
                ),
              ],
            ],
          ),
        ),
      );
    }

    if (widgets.isEmpty) {
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

    return widgets;
  }

  List<Widget> _buildEjecutoresSelection() {
    final validDevices = previusConnections.where((equipo) {
      if (!_isEjecutor(equipo)) return false;
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
      return [
        Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'No hay dispositivos o eventos válidos para control por disparadores.',
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
        final isSelected = ejecutores.contains(eventoTitle);

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
                      ejecutores.add(eventoTitle);
                    } else {
                      ejecutores.remove(eventoTitle);
                    }
                  });
                },
              ),
              onTap: () {
                setState(() {
                  if (isSelected) {
                    ejecutores.remove(eventoTitle);
                  } else {
                    ejecutores.add(eventoTitle);
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

    for (String equipo in validDevices) {
      if (!_isEjecutor(equipo)) continue;

      final displayName = nicknamesMap[equipo] ?? equipo;
      final deviceKey =
          '${DeviceManager.getProductCode(equipo)}/${DeviceManager.extractSerialNumber(equipo)}';
      final deviceDATA = globalDATA[deviceKey] ?? {};
      final owner = deviceDATA['owner'] ?? '';
      final admin = deviceDATA['secondary_admin'] ?? [];

      if (owner != '' &&
          owner != currentUserEmail &&
          !admin.contains(currentUserEmail)) {
        continue;
      }

      // Verificar si este equipo tiene salidas seleccionadas
      final hasSelectedSalida =
          deviceDATA.keys.where((k) => k.startsWith('io')).any((key) {
        final rawData = deviceDATA[key];
        final data = rawData is String ? jsonDecode(rawData) : rawData;
        final pinType = int.tryParse(data['pinType'].toString()) ?? -1;
        if (pinType != 0) return false; // Solo salidas (pinType = 0)
        final salidaIndex = key.replaceAll('io', '');
        final salidaId = '${equipo}_$salidaIndex';
        return ejecutores.contains(salidaId);
      });

      final isEquipoSelected = ejecutores.contains(equipo) || hasSelectedSalida;

      widgets.add(
        Container(
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
                      children: deviceDATA.keys
                          .where((k) => k.startsWith('io'))
                          .map((key) {
                        final rawData = deviceDATA[key];
                        final data =
                            rawData is String ? jsonDecode(rawData) : rawData;
                        final pinType =
                            int.tryParse(data['pinType'].toString()) ?? -1;

                        if (pinType != 0) return const SizedBox.shrink();

                        final salidaIndex = key.replaceAll('io', '');
                        final salidaId = '${equipo}_$salidaIndex';
                        final isChecked = ejecutores.contains(salidaId);

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
                                ejecutores.add(salidaId);
                              } else {
                                ejecutores.remove(salidaId);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ] else ...[
                  CheckboxListTile(
                    title: Text(displayName.isEmpty ? equipo : displayName,
                        style: GoogleFonts.poppins(color: color0)),
                    value: ejecutores.contains(equipo),
                    activeColor: color4,
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          ejecutores.add(equipo);
                        } else {
                          ejecutores.remove(equipo);
                        }
                      });
                    },
                  ),
                ],
              ] else ...[
                CheckboxListTile(
                  title: Text(displayName.isEmpty ? equipo : displayName,
                      style: GoogleFonts.poppins(color: color0)),
                  value: ejecutores.contains(equipo),
                  activeColor: color4,
                  onChanged: (value) {
                    setState(() {
                      if (value == true) {
                        ejecutores.add(equipo);
                      } else {
                        ejecutores.remove(equipo);
                      }
                    });
                  },
                ),
              ],
            ],
          ),
        ),
      );
    }

    if (widgets.isEmpty) {
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

    return widgets;
  }

  Widget _buildAccionesSelection() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: Text(
            'Configura la acción para cada ejecutor/evento',
            style: GoogleFonts.poppins(color: color0, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 12),
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: ejecutores.length,
            itemBuilder: (context, index) {
              final device = ejecutores[index];
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
                      const SizedBox(height: 12),
                      if (isCadena) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.orange.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.play_arrow,
                                color: Colors.orange,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Se ejecutará la secuencia completa',
                                  style: GoogleFonts.poppins(
                                    color: Colors.orange,
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
                                  printLog.i('$deviceActions', color: 'verde');
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
                                  minWidth: 80,
                                ),
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12),
                                    child: Text('Encender',
                                        style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w500)),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12),
                                    child: Text('Apagar',
                                        style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w500)),
                                  ),
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
                        'Control por disparadores',
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
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildStepIndicator(0, 'Activadores', currentStep >= 0),
                  Container(
                      width: 30,
                      height: 2,
                      color: currentStep >= 1 ? color4 : color0),
                  _buildStepIndicator(1, 'Alerta', currentStep >= 1),
                  Container(
                      width: 30,
                      height: 2,
                      color: currentStep >= 2 ? color4 : color0),
                  _buildStepIndicator(2, 'Ejecutores', currentStep >= 2),
                  Container(
                      width: 30,
                      height: 2,
                      color: currentStep >= 3 ? color4 : color0),
                  _buildStepIndicator(3, 'Acciones', currentStep >= 3),
                  Container(
                      width: 30,
                      height: 2,
                      color: currentStep >= 4 ? color4 : color0),
                  _buildStepIndicator(4, 'Nombre', currentStep >= 4),
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
                        child: ElevatedButton(
                          onPressed: () => setState(() => currentStep--),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: color0,
                            foregroundColor: color1,
                            disabledForegroundColor:
                                color1.withValues(alpha: 0.5),
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
                        icon: Icon(currentStep == 4
                            ? Icons.check
                            : Icons.arrow_forward),
                        label:
                            Text(currentStep == 4 ? 'Confirmar' : 'Continuar'),
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
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Text(
                'Selecciona el equipo activador',
                style: GoogleFonts.poppins(color: color0, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: _buildActivadoresSelection(),
              ),
            ),
          ],
        );
      case 1:
        final bool isTermometro = activadores.isNotEmpty &&
            (activadores.first.contains('Termometro'));
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Center(
              child: Text(
                'Elige en que estado debe estar el activador para accionar los ejecutores',
                style: GoogleFonts.poppins(color: color0, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: ToggleButtons(
                isSelected: [estadoAlerta == "1", estadoAlerta == "0"],
                onPressed: (index) {
                  setState(() {
                    estadoAlerta = index == 0 ? "1" : "0";
                  });
                },
                borderRadius: BorderRadius.circular(12),
                selectedColor: color1,
                fillColor: color4.withValues(alpha: 0.8),
                color: color0,
                borderColor: color4,
                selectedBorderColor: color4,
                constraints: const BoxConstraints(
                  minHeight: 40,
                  minWidth: 120,
                ),
                children: [
                  Text(
                    'Estado de\n alerta',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    'Estado de\n reposo',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (isTermometro) ...{
              const Divider(
                color: color0,
                thickness: 1.0,
                height: 24,
              ),
              Center(
                child: Text(
                  'Elige con que alerta ejecutarse',
                  style: GoogleFonts.poppins(color: color0, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: ToggleButtons(
                  isSelected: [
                    estadoTermometro == "1",
                    estadoTermometro == "0"
                  ],
                  onPressed: (index) {
                    setState(() {
                      estadoTermometro = index == 0 ? "1" : "0";
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  selectedColor: color1,
                  fillColor: color4.withValues(alpha: 0.8),
                  color: color0,
                  borderColor: color4,
                  selectedBorderColor: color4,
                  constraints: const BoxConstraints(
                    minHeight: 40,
                    minWidth: 120,
                  ),
                  children: [
                    Text(
                      'Alerta Máxima',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                    ),
                    Text(
                      'Alerta Mínima',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 15),
            },
          ],
        );
      case 2:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Text(
                'Selecciona los equipos ejecutores',
                style: GoogleFonts.poppins(color: color0, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: _buildEjecutoresSelection(),
              ),
            ),
          ],
        );
      case 3:
        return _buildAccionesSelection();
      case 4:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Text(
                'Nombre del grupo en cadena',
                style: GoogleFonts.poppins(color: color0, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: title,
              decoration: InputDecoration(
                hintText: 'Ej: Cadena de seguridad',
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
      default:
        return const SizedBox();
    }
  }

  bool _canContinue() {
    switch (currentStep) {
      case 0:
        return activadores.length == 1;
      case 1:
        final bool isTermometro = activadores.isNotEmpty &&
            (activadores.first.contains('Termometro'));
        final bool estadoSeleccionado =
            estadoAlerta == "1" || estadoAlerta == "0";
        if (isTermometro) {
          return estadoSeleccionado &&
              (estadoTermometro == "1" || estadoTermometro == "0");
        }
        return estadoSeleccionado;
      case 2:
        return ejecutores.isNotEmpty;
      case 3:
        int requiredActions = ejecutores.where((device) {
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
      case 4:
        return title.text.isNotEmpty && !title.text.contains(':');
      default:
        return false;
    }
  }

  void _handleContinue() {
    if (currentStep < 4) {
      setState(() {
        currentStep++;
        if (currentStep == 3) {
          for (String device in ejecutores) {
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
      _confirmarDisparador();
    }
  }

  void _confirmarDisparador() async {
    printLog.i("=== CONTROL POR DISPARADOR CREADO ===");
    printLog.i("Nombre: ${title.text}");
    printLog.i("Activadores: $activadores");
    printLog.i("Ejecutores: $ejecutores");
    printLog.i("Acciones: $deviceActions");

    List<String> deviceGroup = [];
    Map<String, bool> finalDeviceActions = {};

    deviceGroup.addAll(activadores);

    deviceGroup.addAll(ejecutores);

    for (String item in ejecutores) {
      finalDeviceActions[item] = deviceActions[item] ?? false;
    }

    printLog.i("DeviceGroup completo: $deviceGroup");
    printLog.i("Acciones finales: $finalDeviceActions");

    Map<String, dynamic> eventoData = {
      'evento': 'disparador',
      'title': title.text,
      'activadores': List<String>.from(activadores),
      'ejecutores': List<String>.from(ejecutores),
      'deviceGroup': List<String>.from(deviceGroup),
      'deviceActions': Map<String, bool>.from(finalDeviceActions),
      'estadoAlerta': estadoAlerta,
      'estadoTermometro': estadoTermometro,
    };

    eventosCreados.add(eventoData);
    putEventos(currentUserEmail, eventosCreados);

    if (ejecutores.isNotEmpty) {
      Map<String, bool> ejecutoresMap = {};
      for (String item in ejecutores) {
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
        ejecutoresMap[finalKey] = finalDeviceActions[item] ?? false;
      }

      String tipoAlerta;
      String activador = activadores.first;
      bool isTermometro = activador.contains('Termometro');

      if (isTermometro) {
        if (estadoTermometro == "1") {
          tipoAlerta = estadoAlerta == "1"
              ? 'ejecutoresMAX_true'
              : 'ejecutoresMAX_false';
        } else {
          tipoAlerta = estadoAlerta == "1"
              ? 'ejecutoresMIN_true'
              : 'ejecutoresMIN_false';
        }
      } else {
        tipoAlerta = estadoAlerta == "1"
            ? 'ejecutoresAlert_true'
            : 'ejecutoresAlert_false';
      }

      putEventoControlPorDisparadores(
        activadores.first,
        currentUserEmail,
        title.text,
        ejecutoresMap,
        tipoAlerta: tipoAlerta,
      );
    }

    showToast("Evento creado exitosamente");
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
