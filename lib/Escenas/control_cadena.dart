// ignore_for_file: equal_elements_in_set

import 'dart:convert';

import 'package:caldensmart/aws/dynamo/dynamo.dart';
import 'package:caldensmart/aws/mqtt/mqtt.dart';
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
  int currentStepIndex = 0;
  TextEditingController title = TextEditingController();

  List<Map<String, dynamic>> pasosCadena = [];

  List<String> tempDeviceGroup = [];
  Map<String, bool> tempDeviceActions = {};
  Duration tempStepDelay = Duration.zero;
  String tempStepDelayUnit = 'seg';

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
    pasosCadena.clear();
    tempDeviceGroup.clear();
    tempDeviceActions.clear();
    tempStepDelay = Duration.zero;
    tempStepDelayUnit = 'seg';
    currentStep = 0;
    currentStepIndex = 0;
  }

  bool _isValidForCascada(String equipo) {
    final displayName = nicknamesMap[equipo] ?? equipo;
    if (displayName.isEmpty) return false;

    if (equipo.contains('Detector') ||
        equipo.contains('Termometro') ||
        equipo.contains('Patito')) {
      return false;
    }

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
                        'Control por cadena',
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
                  _buildStepIndicator(0, 'Dispositivos', currentStep >= 0),
                  Container(
                      width: 30,
                      height: 2,
                      color: currentStep >= 1 ? color4 : color0),
                  _buildStepIndicator(1, 'Configuración', currentStep >= 1),
                  Container(
                      width: 30,
                      height: 2,
                      color: currentStep >= 2 ? color4 : color0),
                  _buildStepIndicator(2, 'Gestión de Pasos', currentStep >= 2),
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
                maxHeight: MediaQuery.of(context).size.height * 0.7,
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
                  if (currentStep > 0 && currentStep != 2)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ElevatedButton(
                          onPressed: () => setState(() {
                            currentStep--;
                          }),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: color0,
                            foregroundColor: color1,
                            padding: const EdgeInsets.symmetric(vertical: 12.0),
                          ),
                          child: const Text('Anterior'),
                        ),
                      ),
                    ),
                  if (currentStep == 2)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text('Agregar Paso'),
                          onPressed: _addNewStep,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: color4,
                            foregroundColor: color0,
                            padding: const EdgeInsets.symmetric(vertical: 12.0),
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(left: currentStep > 0 ? 8.0 : 0),
                      child: ElevatedButton.icon(
                        icon: Icon(_getContinueIcon()),
                        label: Text(_getContinueText()),
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
                'Selecciona los dispositivos para el Paso ${currentStepIndex + 1}',
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
      case 1:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Text(
                'Configura las acciones y delay del Paso ${currentStepIndex + 1}',
                style: GoogleFonts.poppins(color: color0, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            Card(
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
                        const Icon(Icons.schedule, color: color1, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Delay antes de ejecutar este paso',
                            style: GoogleFonts.poppins(
                              color: color1,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
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
                              fillColor: color0,
                              hintText: '0',
                              hintStyle: GoogleFonts.poppins(
                                color: color1.withAlpha(150),
                                fontSize: 12,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: color4),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 8,
                                horizontal: 8,
                              ),
                            ),
                            controller: TextEditingController(
                              text: tempStepDelayUnit == 'seg'
                                  ? tempStepDelay.inSeconds.toString()
                                  : tempStepDelay.inMinutes.toString(),
                            )..selection = TextSelection.collapsed(
                                offset: (tempStepDelayUnit == 'seg'
                                        ? tempStepDelay.inSeconds
                                        : tempStepDelay.inMinutes)
                                    .toString()
                                    .length,
                              ),
                            onChanged: (value) {
                              int val = int.tryParse(value) ?? 0;
                              if (val > 60) val = 60;
                              setState(() {
                                if (tempStepDelayUnit == 'min') {
                                  tempStepDelay = Duration(minutes: val);
                                } else {
                                  tempStepDelay = Duration(seconds: val);
                                }
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 4,
                          child: ToggleButtons(
                            isSelected: [
                              tempStepDelayUnit == 'seg',
                              tempStepDelayUnit == 'min'
                            ],
                            onPressed: (i) => setState(() {
                              final currentValue = tempStepDelayUnit == 'seg'
                                  ? tempStepDelay.inSeconds
                                  : tempStepDelay.inMinutes;
                              final newUnit = i == 0 ? 'seg' : 'min';
                              tempStepDelayUnit = newUnit;
                              tempStepDelay = newUnit == 'seg'
                                  ? Duration(seconds: currentValue)
                                  : Duration(minutes: currentValue);
                            }),
                            borderRadius: BorderRadius.circular(12),
                            selectedColor: color0,
                            fillColor: color2.withValues(alpha: 0.8),
                            color: color1,
                            borderColor: color2,
                            selectedBorderColor: color2,
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
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: tempDeviceGroup.length,
                itemBuilder: (context, index) {
                  final device = tempDeviceGroup[index];
                  final isOn = tempDeviceActions[device] ?? false;

                  return Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    margin:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    color: color0,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.devices_other,
                                  color: color1, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  nicknamesMap[device] ?? device,
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
                          SizedBox(
                            width: double.infinity,
                            child: ToggleButtons(
                              isSelected: [isOn == true, isOn == false],
                              onPressed: (i) => setState(() {
                                tempDeviceActions[device] =
                                    i == 0 ? true : false;
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
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      case 2:
        return _buildStepManagementView();
      case 3:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Text(
                'Escribe el nombre de la cascada',
                style: GoogleFonts.poppins(color: color0, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: title,
              decoration: InputDecoration(
                hintText: 'Ej: Cascada de luces',
                hintStyle: GoogleFonts.poppins(color: color1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16.0),
                  borderSide: const BorderSide(color: color4),
                ),
                filled: true,
                fillColor: color0,
              ),
              style: GoogleFonts.poppins(color: color1),
            ),
            const SizedBox(height: 16),
          ],
        );
      default:
        return const SizedBox();
    }
  }

  Widget _buildStepManagementView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: Text(
            'Gestión de Pasos de la Cadena',
            style: GoogleFonts.poppins(
                color: color0, fontSize: 16, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 16),

        // Lista de pasos existentes
        if (pasosCadena.isNotEmpty) ...[
          Text(
            'Pasos configurados:',
            style: GoogleFonts.poppins(
                color: color0, fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 250),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: pasosCadena.length,
                itemBuilder: (context, index) {
                  final paso = pasosCadena[index];
                  final devices = paso['devices'] as List<dynamic>;
                  final actions = paso['actions'] as Map<String, dynamic>;
                  final stepDelay =
                      paso['stepDelay'] as Duration? ?? Duration.zero;
                  final stepDelayUnit =
                      paso['stepDelayUnit'] as String? ?? 'seg';

                  // Debug printLog.i para ver qué valores tenemos
                  printLog.i('=== DEBUG DELAY ===');
                  printLog.i('stepDelay: $stepDelay');
                  printLog.i('stepDelay.inSeconds: ${stepDelay.inSeconds}');
                  printLog.i('stepDelay.inMinutes: ${stepDelay.inMinutes}');
                  printLog.i('stepDelayUnit: $stepDelayUnit');
                  printLog.i(
                      'stepDelay > Duration.zero: ${stepDelay > Duration.zero}');

                  String delayText = 'Instantáneo';
                  String delaySubtext = '';

                  if (stepDelay.inSeconds > 0) {
                    int totalSeconds = stepDelay.inSeconds;
                    int minutes = (totalSeconds / 60).floor();
                    int remainingSeconds = totalSeconds % 60;

                    if (stepDelayUnit == 'min') {
                      delayText =
                          '$minutes ${minutes == 1 ? 'minuto' : 'minutos'}';
                      // No mostrar segundos entre paréntesis para minutos
                    } else {
                      delayText =
                          '$totalSeconds ${totalSeconds == 1 ? 'segundo' : 'segundos'}';
                      if (minutes > 0) {
                        delaySubtext =
                            '($minutes ${minutes == 1 ? 'minuto' : 'minutos'} $remainingSeconds ${remainingSeconds == 1 ? 'segundo' : 'segundos'})';
                      }
                    }
                  }

                  return Card(
                    margin:
                        const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    color: color0,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            color0,
                            color0.withValues(alpha: 0.95),
                          ],
                        ),
                        border: Border.all(
                          color: color4.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        color4,
                                        color4.withValues(alpha: 0.8)
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: color4.withValues(alpha: 0.3),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.play_arrow,
                                        color: color0,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Paso ${index + 1}',
                                        style: GoogleFonts.poppins(
                                          color: color0,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const Spacer(),

                                // Botones de acción en la esquina superior derecha
                                Container(
                                  decoration: BoxDecoration(
                                    color: color4,
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(
                                        color: color4.withValues(alpha: 0.3),
                                        blurRadius: 2,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                  child: InkWell(
                                    onTap: () => _editStep(index),
                                    borderRadius: BorderRadius.circular(8),
                                    child: const Padding(
                                      padding: EdgeInsets.all(6),
                                      child: Icon(
                                        Icons.edit,
                                        size: 16,
                                        color: color0,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            Colors.red.withValues(alpha: 0.3),
                                        blurRadius: 2,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                  child: InkWell(
                                    onTap: () => _removeStep(index),
                                    borderRadius: BorderRadius.circular(8),
                                    child: const Padding(
                                      padding: EdgeInsets.all(6),
                                      child: Icon(
                                        Icons.delete,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: stepDelay.inSeconds > 0
                                    ? LinearGradient(
                                        colors: [
                                          Colors.orange.withValues(alpha: 0.15),
                                          Colors.orange.withValues(alpha: 0.05),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      )
                                    : LinearGradient(
                                        colors: [
                                          Colors.green.withValues(alpha: 0.15),
                                          Colors.green.withValues(alpha: 0.05),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: stepDelay.inSeconds > 0
                                      ? Colors.orange.withValues(alpha: 0.3)
                                      : Colors.green.withValues(alpha: 0.3),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: stepDelay.inSeconds > 0
                                          ? Colors.orange.withValues(alpha: 0.2)
                                          : Colors.green.withValues(alpha: 0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      stepDelay.inSeconds > 0
                                          ? Icons.timer_outlined
                                          : Icons.flash_on,
                                      size: 20,
                                      color: stepDelay.inSeconds > 0
                                          ? Colors.orange.shade700
                                          : Colors.green.shade700,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          stepDelay.inSeconds > 0
                                              ? (index == 0
                                                  ? 'Tras accionar la secuencia, luego de $delayText se ejecutará este paso'
                                                  : 'Tras finalizar el paso anterior, luego de $delayText se ejecutará este paso')
                                              : (index == 0
                                                  ? 'Se ejecuta inmediatamente al accionar la secuencia'
                                                  : 'Se ejecuta inmediatamente tras finalizar el paso anterior'),
                                          style: GoogleFonts.poppins(
                                            color: stepDelay.inSeconds > 0
                                                ? Colors.orange.shade800
                                                : Colors.green.shade800,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            height: 1.3,
                                          ),
                                        ),
                                        if (delaySubtext.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            delaySubtext,
                                            style: GoogleFonts.poppins(
                                              color: Colors.orange.shade600,
                                              fontSize: 10,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              height: 1,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    color0.withValues(alpha: 0.1),
                                    color0.withValues(alpha: 0.3),
                                    color0.withValues(alpha: 0.1),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Dispositivos (${devices.length}):',
                              style: GoogleFonts.poppins(
                                color: color0,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: devices.map((device) {
                                String displayName = '';
                                if (device.contains('_')) {
                                  final apodoSalida = nicknamesMap[device];
                                  final parts = device.split('_');
                                  final deviceName =
                                      nicknamesMap[parts[0]] ?? parts[0];
                                  final salidaName =
                                      apodoSalida ?? 'Salida ${parts[1]}';
                                  displayName = '$deviceName\n$salidaName';
                                } else {
                                  displayName = nicknamesMap[device] ?? device;
                                }

                                final action = actions[device] ?? false;
                                final actionColor =
                                    action ? Colors.green : Colors.red;

                                return Container(
                                  width: double.infinity,
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        actionColor.withValues(alpha: 0.15),
                                        actionColor.withValues(alpha: 0.08),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: actionColor.withValues(alpha: 0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: actionColor.withValues(
                                              alpha: 0.2),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          action
                                              ? Icons.power_settings_new
                                              : Icons.power_off,
                                          size: 16,
                                          color: actionColor,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              displayName,
                                              style: GoogleFonts.poppins(
                                                color: color1,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                                height: 1.2,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                color: actionColor.withValues(
                                                    alpha: 0.2),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                action ? 'ENCENDER' : 'APAGAR',
                                                style: GoogleFonts.poppins(
                                                  color: actionColor,
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        if (pasosCadena.isEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Agrega al menos un paso para continuar',
            style: GoogleFonts.poppins(color: Colors.orange, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  void _addNewStep() {
    setState(() {
      currentStepIndex = pasosCadena.length;
      _clearTemporaryData();
      currentStep = 0;
    });
  }

  void _editStep(int index) {
    setState(() {
      currentStepIndex = index;
      final paso = pasosCadena[index];
      tempDeviceGroup = List<String>.from(paso['devices']);
      tempDeviceActions = Map<String, bool>.from(paso['actions']);
      tempStepDelay = paso['stepDelay'] as Duration? ?? Duration.zero;
      tempStepDelayUnit = paso['stepDelayUnit'] as String? ?? 'seg';
      currentStep = 0;
    });
  }

  void _removeStep(int index) {
    setState(() {
      pasosCadena.removeAt(index);
      for (int i = index; i < pasosCadena.length; i++) {
        // Los pasos se mantienen en orden automáticamente
      }
    });
  }

  void _clearTemporaryData() {
    tempDeviceGroup.clear();
    tempDeviceActions.clear();
    tempStepDelay = Duration.zero;
    tempStepDelayUnit = 'seg';
  }

  void _saveCurrentStep() {
    // Debug printLog.i para verificar qué se está guardando
    printLog.i('=== GUARDANDO PASO ===');
    printLog.i('tempStepDelay: $tempStepDelay');
    printLog.i('tempStepDelay.inSeconds: ${tempStepDelay.inSeconds}');
    printLog.i('tempStepDelayUnit: $tempStepDelayUnit');
    printLog.i('tempDeviceGroup: $tempDeviceGroup');
    printLog.i('tempDeviceActions: $tempDeviceActions');

    final stepData = {
      'devices': List<String>.from(tempDeviceGroup),
      'actions': Map<String, bool>.from(tempDeviceActions),
      'stepDelay': tempStepDelay,
      'stepDelayUnit': tempStepDelayUnit,
    };

    printLog.i('stepData guardado: $stepData');

    setState(() {
      if (currentStepIndex < pasosCadena.length) {
        pasosCadena[currentStepIndex] = stepData;
      } else {
        pasosCadena.add(stepData);
      }

      printLog.i('pasosCadena después de guardar: $pasosCadena');
      currentStep = 2;
    });
  }

  List<Widget> _buildDeviceList() {
    final validDevices = filterDevices.where((equipo) {
      if (!_isValidForCascada(equipo)) return false;
      final deviceKey =
          '${DeviceManager.getProductCode(equipo)}/${DeviceManager.extractSerialNumber(equipo)}';
      final deviceDATA = globalDATA[deviceKey] ?? {};
      final owner = deviceDATA['owner'] ?? '';
      final admin = deviceDATA['secondary_admin'] ?? [];
      final isnotRiego = deviceDATA['riegoActive'] != true;
      return (owner == '' ||
              owner == currentUserEmail ||
              admin.contains(currentUserEmail)) &&
          isnotRiego;
    }).toList();

    if (validDevices.isEmpty) {
      return [
        Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Se necesitan al menos 1 equipo válido para crear una cascada.',
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
        return tempDeviceGroup.contains(salidaId);
      });

      final isEquipoSelected =
          tempDeviceGroup.contains(equipo) || hasSelectedSalida;

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

                      if (pinType != 0) return const SizedBox.shrink();

                      final salidaIndex = key.replaceAll('io', '');
                      final salidaId = '${equipo}_$salidaIndex';
                      final isChecked = tempDeviceGroup.contains(salidaId);

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
                              tempDeviceGroup.add(salidaId);
                            } else {
                              tempDeviceGroup.remove(salidaId);
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
                  value: tempDeviceGroup.contains(equipo),
                  activeColor: color4,
                  onChanged: (value) {
                    setState(() {
                      if (value == true) {
                        tempDeviceGroup.add(equipo);
                      } else {
                        tempDeviceGroup.remove(equipo);
                      }
                    });
                  },
                ),
              ],
            ] else ...[
              CheckboxListTile(
                title: Text(displayName,
                    style: GoogleFonts.poppins(color: color0)),
                value: tempDeviceGroup.contains(equipo),
                activeColor: color4,
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      tempDeviceGroup.add(equipo);
                    } else {
                      tempDeviceGroup.remove(equipo);
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
        return tempDeviceGroup.isNotEmpty;
      case 1:
        return tempDeviceGroup
            .every((device) => tempDeviceActions.containsKey(device));
      case 2:
        return pasosCadena.isNotEmpty;
      case 3:
        return title.text.isNotEmpty;
      default:
        return false;
    }
  }

  void _handleContinue() {
    if (currentStep == 0) {
      setState(() {
        currentStep++;
        // Inicializar valores por defecto para nuevos dispositivos en el paso 1
        for (final device in tempDeviceGroup) {
          tempDeviceActions[device] ??= false;
        }
      });
    } else if (currentStep == 1) {
      _saveCurrentStep();
    } else if (currentStep == 2) {
      setState(() => currentStep = 3);
    } else {
      _confirmarCascada();
    }
  }

  void _confirmarCascada() async {
    printLog.i("=== CONTROL POR CASCADA CREADO ===");
    printLog.i("Nombre: ${title.text}");
    printLog.i("Número de pasos: ${pasosCadena.length}");

    final List<String> allDevices = [];
    List<Map<String, dynamic>> stepsToDynamo = [];
    for (int i = 0; i < pasosCadena.length; i++) {
      final paso = pasosCadena[i];
      printLog.d(paso);
      printLog.i("Paso ${i + 1}:");
      printLog.i("  Equipos: ${paso['devices']}");
      printLog.i("  Acciones: ${paso['actions']}");
      printLog.i("  Delay del paso: ${paso['stepDelay']}");
      allDevices.addAll(paso['devices'] as List<String>);
      final Duration stepDelay = paso['stepDelay'] as Duration;
      stepsToDynamo.add({
        'paso_index': i,
        'ejecutores': paso['actions'],
        'delay': paso['stepDelayUnit'] == 'seg'
            ? stepDelay.inSeconds
            : stepDelay.inMinutes * 60,
      });
    }

    printLog.i("A dynamo se envia: $stepsToDynamo");

    // Crear el evento y agregarlo a eventosCreados
    final cadenaEvent = {
      'evento': 'cadena',
      'title': title.text.trim(),
      'deviceGroup': allDevices,
      'pasos': pasosCadena
          .map((paso) => {
                'devices': List<String>.from(paso['devices']),
                'actions': Map<String, bool>.from(paso['actions']),
                'stepDelay': paso['stepDelay'] as Duration,
                'stepDelayUnit': paso['stepDelayUnit'] as String,
              })
          .toList(),
    };

    eventosCreados.add(cadenaEvent);

    todosLosDispositivos.add(MapEntry(
      cadenaEvent['title'] as String? ?? 'Cadena',
      (cadenaEvent['deviceGroup'] as List<dynamic>).join(','),
    ));

    // Guardar en DynamoDB
    putEventoControlPorCadena(
        currentUserEmail, title.text.trim(), stepsToDynamo);
    putEventos(currentUserEmail, eventosCreados);

    // Suscribirse al topic MQTT del nuevo evento
    subscribeToEventoStatus(
        'ControlPorCadena', currentUserEmail, title.text.trim());

    _initializeData();
    title.clear();
    showToast("Cascada confirmada");

    if (widget.onBackToMain != null) {
      widget.onBackToMain!();
    }

    Navigator.pop(context, true);

    printLog.i(eventosCreados);
  }

  IconData _getContinueIcon() {
    switch (currentStep) {
      case 0:
        return Icons.arrow_forward;
      case 1:
        return Icons.arrow_forward;
      case 2:
        return Icons.arrow_forward;
      case 3:
        return Icons.check;
      default:
        return Icons.arrow_forward;
    }
  }

  String _getContinueText() {
    switch (currentStep) {
      case 0:
        return 'Continuar';
      case 1:
        return 'Continuar';
      case 2:
        return 'Continuar';
      case 3:
        return 'Confirmar';
      default:
        return 'Continuar';
    }
  }

  @override
  void dispose() {
    title.dispose();
    super.dispose();
  }
}
