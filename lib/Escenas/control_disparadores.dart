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
                        activeColor: color6,
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
                  activeColor: color6,
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

    return widgets;
  }

  List<Widget> _buildEjecutoresSelection() {
    List<Widget> widgets = [];

    for (String equipo in previusConnections) {
      if (!_isEjecutor(equipo)) continue;

      final displayName = nicknamesMap[equipo] ?? equipo;
      final deviceKey =
          '${DeviceManager.getProductCode(equipo)}/${DeviceManager.extractSerialNumber(equipo)}';
      final deviceDATA = globalDATA[deviceKey] ?? {};

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
                          activeColor: color6,
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
                    activeColor: color6,
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
                  activeColor: color6,
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

    return widgets;
  }

  Widget _buildAccionesSelection() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: Text(
            'Configura la acción para cada ejecutor',
            style: GoogleFonts.poppins(color: color1, fontSize: 16),
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
              final displayName = nicknamesMap[device] ?? device;
              final finalDisplayName =
                  displayName.isEmpty ? device : displayName;

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
                              finalDisplayName,
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
                      const SizedBox(height: 12),
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
                        'Control por disparadores',
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
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildStepIndicator(0, 'Activadores', currentStep >= 0),
                  Container(
                      width: 30,
                      height: 2,
                      color: currentStep >= 1 ? color6 : color0),
                  _buildStepIndicator(1, 'Alerta', currentStep >= 1),
                  Container(
                      width: 30,
                      height: 2,
                      color: currentStep >= 2 ? color6 : color0),
                  _buildStepIndicator(2, 'Ejecutores', currentStep >= 2),
                  Container(
                      width: 30,
                      height: 2,
                      color: currentStep >= 3 ? color6 : color0),
                  _buildStepIndicator(3, 'Acciones', currentStep >= 3),
                  Container(
                      width: 30,
                      height: 2,
                      color: currentStep >= 4 ? color6 : color0),
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
                        icon: Icon(currentStep == 4
                            ? Icons.check
                            : Icons.arrow_forward),
                        label:
                            Text(currentStep == 4 ? 'Confirmar' : 'Continuar'),
                        onPressed:
                            _canContinue() ? () => _handleContinue() : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: color0,
                          foregroundColor: color3,
                          disabledForegroundColor: color2,
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
                'Selecciona el equipo activador',
                style: GoogleFonts.poppins(color: color1, fontSize: 16),
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
                style: GoogleFonts.poppins(color: color1, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: ToggleButtons(
                isSelected: [estadoAlerta == "1", estadoAlerta == "0"],
                onPressed: (index) {
                  setState(() {
                    //TODO Estado de alerta
                    estadoAlerta = index == 0 ? "1" : "0";
                  });
                },
                borderRadius: BorderRadius.circular(12),
                selectedColor: color3,
                fillColor: color6.withValues(alpha: 0.8),
                color: color1,
                borderColor: color6,
                selectedBorderColor: color6,
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
                color: color2,
                thickness: 1.0,
                height: 24,
              ),
              Center(
                child: Text(
                  'Elige con que alerta ejecutarse',
                  style: GoogleFonts.poppins(color: color1, fontSize: 16),
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
                      //TODO Estado de termometro
                      estadoTermometro = index == 0 ? "1" : "0";
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  selectedColor: color3,
                  fillColor: color6.withValues(alpha: 0.8),
                  color: color1,
                  borderColor: color6,
                  selectedBorderColor: color6,
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
                style: GoogleFonts.poppins(color: color1, fontSize: 16),
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
                style: GoogleFonts.poppins(color: color1, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: title,
              decoration: InputDecoration(
                hintText: 'Ej: Cadena de seguridad',
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
        return deviceActions.isNotEmpty &&
            deviceActions.length == ejecutores.length;
      case 4:
        return title.text.isNotEmpty;
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
            deviceActions[device] ??= false;
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
    deviceGroup.addAll(activadores);
    deviceGroup.addAll(ejecutores);

    eventosCreados.add({
      'evento': 'disparador',
      'title': title.text,
      'activadores': List<String>.from(activadores),
      'ejecutores': List<String>.from(ejecutores),
      'deviceGroup': List<String>.from(deviceGroup),
      'deviceActions': Map<String, bool>.from(deviceActions),
      'estadoAlerta': estadoAlerta,
      'estadoTermometro': estadoTermometro,
    });

    putEventos(currentUserEmail, eventosCreados);

    Map<String, bool> ejecutoresMap = {};

    for (String device in ejecutores) {
      ejecutoresMap[device] = deviceActions[device] ?? false;
    }

    // Determinar el tipo de alerta basado en el activador y los estados
    String tipoAlerta;
    String activador = activadores.first;
    bool isTermometro = activador.contains('Termometro');

    if (isTermometro) {
      // Para termómetros, usar estado de temperatura (MAX/MIN) y estado de alerta
      if (estadoTermometro == "1") {
        tipoAlerta =
            estadoAlerta == "1" ? 'ejecutoresMAX_true' : 'ejecutoresMAX_false';
      } else {
        tipoAlerta =
            estadoAlerta == "1" ? 'ejecutoresMIN_true' : 'ejecutoresMIN_false';
      }
    } else {
      // Para otros dispositivos, usar solo estado de alerta
      tipoAlerta = estadoAlerta == "1"
          ? 'ejecutoresAlert_true'
          : 'ejecutoresAlert_false';
    }

    putEventoDisparador(activadores.first, ejecutoresMap,
        tipoAlerta: tipoAlerta);

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
