import 'dart:convert';
import 'dart:math';
import 'package:caldensmart/aws/dynamo/dynamo.dart';
import 'package:caldensmart/aws/dynamo/dynamo_certificates.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import '../master.dart';

class EscenasPage extends StatefulWidget {
  const EscenasPage({super.key});

  @override
  State<EscenasPage> createState() => EscenasPageState();
}

class EscenasPageState extends State<EscenasPage> {
  // VARIABLES \\
  bool showCard = false;
  Widget Function()? currentBuilder;
  TimeOfDay? selectedTime;
  int? selectedAction;
  bool showHorarioStep = false;
  bool showHorarioStep2 = false;
  bool showGrupoStep = false;

  List<String> selectedDays = [];
  List<String> deviceGroup = [];
  List<String> filterDevices = [];

  TextEditingController title = TextEditingController();
  final selectWeekDaysKey = GlobalKey<SelectWeekDaysState>();

  final customWidgetKey = GlobalKey<SelectWeekDaysState>();

  @override
  void initState() {
    super.initState();
    printLog(nicknamesMap);
    currentBuilder = buildMainOptions;

    filterDevices = List.from(previusConnections);
    filterDevices.removeWhere((device) => device.contains('Detector'));
  }

  @override
  void dispose() {
    super.dispose();
    title.dispose();
  }

  void resetConfig() {
    setState(() {
      showHorarioStep = false;
      showHorarioStep2 = false;

      deviceGroup.clear();

      title.clear();
      showGrupoStep = false;
    });
  }

  //*- Crea el evento -*\\
  Widget buildEvent(List<String> deviceGroup, String evento, String title,
      List<String> selectedDays, int selectedAction, selectedTime,
      {required VoidCallback onDelete}) {
    switch (evento) {
      case 'horario':
        final daysText = () {
          if (selectedDays.length == 1) return selectedDays.first;
          final primeros = selectedDays.sublist(0, selectedDays.length - 1);
          return '${primeros.join(', ')} y ${selectedDays.last}';
        }();
        return Card(
          elevation: 8,
          shadowColor: Colors.black26,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: color3,
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.calendar_today,
                            size: 28, color: color0),
                        const SizedBox(width: 8),
                        Text(
                          title,
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: color0,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 24),
                      color: Colors.redAccent,
                      onPressed: onDelete,
                      tooltip: 'Eliminar grupo',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Este evento ${selectedAction == 1 ? "encenderá" : "apagará"} los dispositivos seleccionados los dias $daysText en el horario $selectedTime',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    color: color0.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 16),
                if (deviceGroup.isEmpty) ...[
                  Center(
                    child: Text(
                      'No hay equipos seleccionados.',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: color0.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ] else ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: deviceGroup.map((equipo) {
                      final displayName = nicknamesMap[equipo] ?? equipo;
                      return Chip(
                        label: Text(
                          displayName,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: color3,
                          ),
                        ),
                        backgroundColor: color0.withValues(alpha: 0.15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        );

      case 'grupo':
        return Card(
          elevation: 8,
          shadowColor: Colors.black26,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: color3,
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.devices, size: 28, color: color0),
                        const SizedBox(width: 8),
                        Text(
                          title,
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: color0,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 24),
                      color: Colors.redAccent,
                      onPressed: onDelete,
                      tooltip: 'Eliminar grupo',
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                Text(
                  'Este evento controla los dispositivos:',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    color: color0.withValues(alpha: 0.85),
                  ),
                ),

                const SizedBox(height: 16),

                // Lista de dispositivos como chips
                if (deviceGroup.isEmpty) ...[
                  Center(
                    child: Text(
                      'No hay equipos seleccionados.',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: color0.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ] else ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: deviceGroup.map((equipo) {
                      String displayName = '';
                      if (equipo.contains('_')) {
                        final parts = equipo.split('_');
                        displayName = nicknamesMap[parts[0]] ??
                            '${parts[0]} salida ${parts[1]}';
                      } else {
                        displayName = nicknamesMap[equipo] ?? equipo;
                      }

                      return Chip(
                        label: Text(
                          displayName,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: color3,
                          ),
                        ),
                        backgroundColor: color0.withValues(alpha: 0.15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }
  //*- Crea el evento -*\\

  //*- Opción principal -*\\
  Widget buildMainOptions() {
    return Card(
      color: color3,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              'Selecciona un evento de entrada',
              style: GoogleFonts.poppins(
                color: color0,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 10),
            ListTile(
              leading: const Icon(Icons.schedule, color: color0),
              title: Text('Control horario',
                  style: GoogleFonts.poppins(color: color0)),
              onTap: () {
                setState(() {
                  currentBuilder = buildControlHorario;
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.devices, color: color0),
              title: Text('Control por cascada',
                  style: GoogleFonts.poppins(color: color0)),
              onTap: () {
                showToast("Próximamente");
              },
            ),
            ListTile(
              leading: const Icon(Icons.lightbulb, color: color0),
              title: Text('Control por grupos',
                  style: GoogleFonts.poppins(color: color0)),
              onTap: () {
                setState(() {
                  currentBuilder = buildControlPorGrupo;
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.air, color: color0),
              title: Text('Control por clima',
                  style: GoogleFonts.poppins(color: color0)),
              onTap: () {
                showToast("Próximamente");
              },
            ),
          ],
        ),
      ),
    );
  }
  //*- Opción principal -*\\

  //*- Control horario -*\\
  Widget buildControlHorario() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        return Card(
          color: color3,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (showHorarioStep == true &&
                          showHorarioStep2 == false) ...{
                        Positioned(
                          left: 0,
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back),
                            color: color1,
                            onPressed: () =>
                                setState(() => showHorarioStep = false),
                          ),
                        ),
                      } else if (showHorarioStep == false &&
                          showHorarioStep2 == false) ...{
                        Positioned(
                          left: 0,
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back),
                            color: color1,
                            onPressed: () => setState(
                                () => currentBuilder = buildMainOptions),
                          ),
                        ),
                      } else ...{
                        Positioned(
                          left: 0,
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back),
                            color: color1,
                            onPressed: () =>
                                setState(() => showHorarioStep2 = false),
                          ),
                        ),
                      },
                      Text(
                        'Control por Horario',
                        style: GoogleFonts.poppins(
                          color: color1,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                if (showHorarioStep == false && showHorarioStep2 == false) ...[
                  Align(
                    alignment: Alignment.topCenter,
                    child: Text(
                      'Selecciona al menos un equipo',
                      style: GoogleFonts.poppins(
                        color: color1,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (filterDevices.isNotEmpty) ...{
                    SizedBox(
                      height:
                          min((72 * filterDevices.length).toDouble(), 300.0),
                      child: ListView.builder(
                        itemCount: filterDevices.length,
                        itemBuilder: (context, index) {
                          final equipo = filterDevices[index];
                          final isSelected = deviceGroup.contains(equipo);
                          final displayName = nicknamesMap[equipo] ?? equipo;

                          Map<String, dynamic> deviceDATA = globalDATA[
                                  '${DeviceManager.getProductCode(equipo)}/${DeviceManager.extractSerialNumber(equipo)}'] ??
                              {};
                          final salidaKeys = deviceDATA.keys
                              .where((key) => key.contains('io'))
                              .toList();
                          final hasSelectedSalida = salidaKeys.any((key) {
                            final rawData = deviceDATA[key];
                            final data = rawData is String
                                ? jsonDecode(rawData)
                                : rawData;
                            final pinType =
                                int.tryParse(data['pinType'].toString()) ?? -1;
                            if (pinType != 0) return false;
                            final salidaId =
                                '${displayName}_${key.replaceAll("io", "")}';
                            return deviceGroup.contains(salidaId);
                          });

                          printLog('$equipo LOS TENEMOS SEÑOR', 'verde');
                          printLog('onichan $deviceDATA', 'rojo');

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8.0),
                            decoration: BoxDecoration(
                              color: (isSelected || hasSelectedSalida)
                                  ? color6.withValues(alpha: 0.1)
                                  : color0.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8.0),
                              border: Border.all(
                                color: (isSelected || hasSelectedSalida)
                                    ? color6
                                    : color0,
                                width: 1.0,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                (displayName.contains("Domotica") ||
                                        displayName.contains("Modulo"))
                                    ? ListTile(
                                        title: Text(
                                          displayName,
                                          style: GoogleFonts.poppins(
                                            color: color0,
                                          ),
                                        ),
                                      )
                                    : CheckboxListTile(
                                        title: Text(
                                          displayName,
                                          style: GoogleFonts.poppins(
                                              color: color0),
                                        ),
                                        value: isSelected,
                                        activeColor: color6,
                                        onChanged: (bool? value) {
                                          setState(() {
                                            if (value == true) {
                                              deviceGroup.add(equipo);
                                            } else {
                                              deviceGroup.removeWhere(
                                                  (salidaId) => salidaId
                                                      .startsWith(displayName));
                                            }
                                          });
                                        },
                                      ),
                                if ((displayName.contains("Domotica") ||
                                    displayName.contains("Modulo"))) ...{
                                  Padding(
                                    padding: const EdgeInsets.only(
                                        left: 32.0, bottom: 8.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: List.generate(
                                        deviceDATA.keys
                                            .where((key) => key.contains('io'))
                                            .length,
                                        (i) {
                                          final key = 'io$i';
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
                                                style: GoogleFonts.poppins(
                                                  color: color0,
                                                  fontWeight: FontWeight.normal,
                                                ),
                                              ),
                                            );
                                          }

                                          final rawData = deviceDATA[key];
                                          final equipo = rawData is String
                                              ? jsonDecode(rawData)
                                              : rawData;

                                          final pinType = int.tryParse(
                                                  equipo['pinType']
                                                      .toString()) ??
                                              -1;
                                          if (pinType != 0) {
                                            return const SizedBox.shrink();
                                          }

                                          const tipoOut = 'Salida';
                                          final salidaId = '${displayName}_$i';
                                          final isChecked =
                                              deviceGroup.contains(salidaId);

                                          return CheckboxListTile(
                                            title: Text(
                                              nicknamesMap[salidaId] ??
                                                  '$tipoOut $i',
                                              style: GoogleFonts.poppins(
                                                color: color0,
                                              ),
                                            ),
                                            value: isChecked,
                                            activeColor: color6,
                                            onChanged: (bool? value) {
                                              setState(() {
                                                if (value == true) {
                                                  deviceGroup.add(salidaId);
                                                } else {
                                                  deviceGroup.remove(salidaId);
                                                }
                                              });
                                            },
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                },
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  },
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.topCenter,
                    child: Text(
                      'Selecciona la acción del evento',
                      style: GoogleFonts.poppins(
                        color: color1,
                        fontSize: width * 0.04,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.power_settings_new),
                        label: const Text('Encender'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              selectedAction == 1 ? color6 : color0,
                          foregroundColor: color3,
                        ),
                        onPressed: () {
                          setState(() {
                            selectedAction = 1;
                          });
                        },
                      ),
                      const SizedBox(width: 20),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.power_off),
                        label: const Text('Apagar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              selectedAction == 0 ? color6 : color0,
                          foregroundColor: color3,
                        ),
                        onPressed: () {
                          setState(() {
                            selectedAction = 0;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('Continuar'),
                      onPressed:
                          (deviceGroup.isNotEmpty && selectedAction != null)
                              ? () {
                                  setState(() {
                                    showHorarioStep = true;
                                  });
                                }
                              : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color0,
                        foregroundColor: color3,
                        disabledForegroundColor: color2,
                        disabledBackgroundColor: color0,
                      ),
                    ),
                  ),
                ] else if (showHorarioStep == true &&
                    showHorarioStep2 == false) ...[
                  // SEGUNDO PASO
                  Align(
                    alignment: Alignment.topCenter,
                    child: Text(
                      'Selecciona los días del evento',
                      style: GoogleFonts.poppins(
                        color: color1,
                        fontSize: width * 0.04,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: SelectWeekDays(
                      key: selectWeekDaysKey,
                      fontSize: width * 0.035,
                      fontWeight: FontWeight.w500,
                      days: [
                        DayInWeek("Lu", dayKey: "Lunes"),
                        DayInWeek("Ma", dayKey: "Martes"),
                        DayInWeek("Mi", dayKey: "Miércoles"),
                        DayInWeek("Ju", dayKey: "Jueves"),
                        DayInWeek("Vi", dayKey: "Viernes"),
                        DayInWeek("Sa", dayKey: "Sábado"),
                        DayInWeek("Do", dayKey: "Domingo"),
                      ],
                      unSelectedDayTextColor: color3,
                      selectedDayTextColor: color3,
                      selectedDaysFillColor: color6,
                      unselectedDaysFillColor: color0,
                      border: false,
                      width: width * 0.85,
                      boxDecoration: BoxDecoration(
                        color: color1,
                        borderRadius: BorderRadius.circular(20.0),
                      ),
                      onSelect: (values) {
                        setState(() {
                          selectedDays = values;
                        });
                        printLog("Días seleccionados: $selectedDays");
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.topCenter,
                    child: Text(
                      'Selecciona la hora del evento',
                      style: GoogleFonts.poppins(
                        color: color1,
                        fontSize: width * 0.04,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TimeSelector(
                    onTimeChanged: (TimeOfDay time) {
                      setState(() {
                        selectedTime = time;
                      });
                      printLog("Hora seleccionada: $selectedTime");
                    },
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check),
                      label: const Text('Confirmar'),
                      onPressed:
                          (selectedDays.isNotEmpty && selectedTime != null)
                              ? () {
                                  setState(() {
                                    showHorarioStep2 = true;
                                  });
                                }
                              : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color0,
                        foregroundColor: color3,
                        disabledForegroundColor: color2,
                        disabledBackgroundColor: color0,
                      ),
                    ),
                  ),
                ] else ...[
                  //TERCER PASO
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Align(
                        alignment: Alignment.topCenter,
                        child: Text(
                          'Selecciona cuanto tiempo durará ${selectedAction == 1 ? "encendido" : "apagado"} el evento',
                          style: GoogleFonts.poppins(
                            color: color1,
                            fontSize: width * 0.04,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Center(
                        child: Text(
                          'Escribe el nombre del grupo',
                          style: GoogleFonts.poppins(
                            color: color1,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: title,
                        decoration: InputDecoration(
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
                    ],
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check),
                      label: const Text('Confirmar'),
                      onPressed: (selectedDays.isNotEmpty &&
                              selectedTime != null)
                          ? () {
                              eventosCreados.add({
                                'evento': 'horario',
                                'title': title.text,
                                'deviceGroup': List<String>.from(deviceGroup),
                                'selectedDays': selectedDays,
                                'selectedTime':
                                    '${selectedTime!.hour}:${selectedTime!.minute.toString().padLeft(2, '0')}hs',
                                'selectedAction': selectedAction,
                              });
                              printLog("SEXO: $eventosCreados", 'verde');
                              deviceGroup.clear();
                              setState(() {
                                showCard = false;
                                resetConfig();
                                currentBuilder = buildMainOptions;
                              });
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color0,
                        foregroundColor: color3,
                        disabledForegroundColor: color2,
                        disabledBackgroundColor: color0,
                      ),
                    ),
                  )
                ],
              ],
            ),
          ),
        );
      },
    );
  }
  //*- Control horario -*\\

  //*- Control por grupo -*\\
  Widget buildControlPorGrupo() {
    return Card(
      color: color3,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    left: 0,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back),
                      color: color1,
                      onPressed: () => setState(() {
                        showGrupoStep
                            ? showGrupoStep = false
                            : currentBuilder = buildMainOptions;
                      }),
                    ),
                  ),
                  Text(
                    'Control por grupo',
                    style: GoogleFonts.poppins(
                      color: color1,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // PRIMERA ETAPA: selección de dispositivos
            if (!showGrupoStep) ...[
              Align(
                alignment: Alignment.topCenter,
                child: Text(
                  'Selecciona al menos dos equipo',
                  style: GoogleFonts.poppins(color: color1, fontSize: 16),
                ),
              ),
              const SizedBox(height: 20),
              if (filterDevices.length >= 2) ...[
                SizedBox(
                  height: 300,
                  child: ListView.builder(
                    itemCount: filterDevices.length,
                    itemBuilder: (context, index) {
                      final equipo = filterDevices[index];
                      final isSelected = deviceGroup.contains(equipo);
                      final displayName = nicknamesMap[equipo] ?? equipo;

                      final deviceKey =
                          '${DeviceManager.getProductCode(equipo)}/${DeviceManager.extractSerialNumber(equipo)}';
                      final deviceDATA = globalDATA[deviceKey] ?? {};

                      final salidaKeys = deviceDATA.keys
                          .where((k) => k.contains('io'))
                          .toList();

                      final hasSelectedSalida = salidaKeys.any((key) {
                        final rawData = deviceDATA[key];
                        final data =
                            rawData is String ? jsonDecode(rawData) : rawData;
                        final pinType =
                            int.tryParse(data['pinType'].toString()) ?? -1;
                        if (pinType != 0) return false;
                        final salidaId =
                            '${displayName}_${key.replaceAll("io", "")}';
                        return deviceGroup.contains(salidaId);
                      });

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8.0),
                        decoration: BoxDecoration(
                          color: (isSelected || hasSelectedSalida)
                              ? color6.withValues(alpha: 0.1)
                              : color0.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8.0),
                          border: Border.all(
                            color: (isSelected || hasSelectedSalida)
                                ? color6
                                : color0,
                            width: 1.0,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            equipo.contains("Domotica") ||
                                    equipo.contains("Modulo")
                                ? ListTile(
                                    title: Text(
                                      displayName,
                                      style: GoogleFonts.poppins(color: color0),
                                    ),
                                  )
                                : CheckboxListTile(
                                    title: Text(
                                      displayName,
                                      style: GoogleFonts.poppins(color: color0),
                                    ),
                                    value: isSelected,
                                    activeColor: color6,
                                    onChanged: (value) {
                                      setState(() {
                                        if (value == true) {
                                          deviceGroup.add(equipo);
                                        } else {
                                          deviceGroup.removeWhere((id) =>
                                              id.startsWith(displayName));
                                        }
                                      });
                                    },
                                  ),
                            if (equipo.contains("Domotica") ||
                                equipo.contains("Modulo")) ...{
                              Padding(
                                padding: const EdgeInsets.only(
                                    left: 32.0, bottom: 8.0),
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
                                          style: GoogleFonts.poppins(
                                              color: color0),
                                        ),
                                      );
                                    }

                                    final raw = deviceDATA[key];
                                    final data =
                                        raw is String ? jsonDecode(raw) : raw;

                                    final pinType = int.tryParse(
                                            data['pinType'].toString()) ??
                                        -1;
                                    if (pinType != 0) {
                                      return const SizedBox.shrink();
                                    }

                                    final salidaIndex =
                                        key.replaceAll('io', '');
                                    final salidaId =
                                        '${displayName}_$salidaIndex';
                                    final isChecked =
                                        deviceGroup.contains(salidaId);

                                    return CheckboxListTile(
                                      title: Text(
                                        nicknamesMap[salidaId] ??
                                            'Salida $salidaIndex',
                                        style:
                                            GoogleFonts.poppins(color: color0),
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
                            },
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  icon: const Icon(Icons.check),
                  label: const Text('Continuar'),
                  onPressed: deviceGroup.length >= 2
                      ? () => setState(() => showGrupoStep = true)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color0,
                    foregroundColor: color3,
                    disabledForegroundColor: color2,
                    disabledBackgroundColor: color0,
                  ),
                ),
              ] else
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      'Se necesitan al menos 2 equipos para formar un grupo.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        color: Colors.red,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ]

            // SEGUNDA ETAPA: nombre del grupo
            else ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Escribe el nombre del grupo',
                    style: GoogleFonts.poppins(
                      color: color1,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: title,
                    decoration: InputDecoration(
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
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.check),
                label: const Text('Confirmar'),
                onPressed: title.text.isNotEmpty
                    ? () {
                        setState(() {
                          eventosCreados.add({
                            'evento': 'grupo',
                            'title': title.text,
                            'deviceGroup': List<String>.from(deviceGroup),
                          });
                          printLog(
                              "Equipos seleccionados: $deviceGroup", 'verde');
                          printLog(eventosCreados);
                          groupsOfDevices
                              .addAll({title.text.trim(): deviceGroup});
                          todosLosDispositivos.add(MapEntry(
                              title.text.trim(), deviceGroup.toString()));

                          printLog(groupsOfDevices, 'magenta');
                          putGroupsOfDevices(
                              service, currentUserEmail, groupsOfDevices);
                          deviceGroup.clear();
                          showCard = false;
                          resetConfig();
                          currentBuilder = buildMainOptions;
                          showToast("Grupo confirmado");
                        });
                        printLog(eventosCreados);
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: color0,
                  foregroundColor: color3,
                  disabledForegroundColor: color2,
                  disabledBackgroundColor: color0,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  //*- Control por grupo -*\\

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final topCardPosition = screenHeight * 0.07;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Programación de eventos',
          style: GoogleFonts.poppins(
            color: color0,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: color3,
        leading: IconButton(
          icon: const Icon(HugeIcons.strokeRoundedArrowLeft02, color: color0),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Container(
          color: color1,
          width: double.infinity,
          height: double.infinity,
          child: Stack(
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        if (showCard) {
                          currentBuilder = buildMainOptions;
                          resetConfig();
                        }
                        showCard = !showCard;
                      });
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          showCard
                              ? HugeIcons.strokeRoundedCancel01
                              : HugeIcons.strokeRoundedAdd01,
                          color: color3,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          showCard ? 'Cancelar evento' : 'Configurar evento',
                          style: GoogleFonts.poppins(
                            color: color3,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 90,
                left: 20,
                right: 20,
                bottom: 0,
                child: eventosCreados.isNotEmpty
                    ? ListView.builder(
                        itemCount: eventosCreados.length,
                        itemBuilder: (context, index) {
                          final evento = eventosCreados[index];
                          return buildEvent(
                            (evento['deviceGroup'] as List).cast<String>(),
                            evento['evento'] as String,
                            evento['title'] as String,
                            evento['selectedDays'] ?? [],
                            evento['selectedAction'] ?? 0,
                            evento['selectedTime'] ?? 0,
                            onDelete: () {
                              setState(() {
                                eventosCreados.removeAt(index);
                              });
                            },
                          );
                        },
                      )
                    : Center(
                        child: Text(
                          'No hay eventos creados',
                          style: GoogleFonts.poppins(
                              color: color3, fontWeight: FontWeight.bold),
                        ),
                      ),
              ),
              Positioned(
                top: showCard ? topCardPosition : -400.0,
                left: 20,
                right: 20,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: showCard ? 1 : 0,
                  child: currentBuilder != null
                      ? currentBuilder!()
                      : const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
