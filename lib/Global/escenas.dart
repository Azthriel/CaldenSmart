// ignore_for_file: equal_elements_in_set

import 'dart:convert';
import 'package:caldensmart/aws/dynamo/dynamo.dart';
import 'package:caldensmart/aws/dynamo/dynamo_certificates.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import '../master.dart';
import 'package:caldensmart/logger.dart';

class EscenasPage extends StatefulWidget {
  const EscenasPage({super.key});

  @override
  State<EscenasPage> createState() => EscenasPageState();
}

class EscenasPageState extends State<EscenasPage> {
  Widget Function()? currentBuilder;
  TimeOfDay? selectedTime;

  int? selectedAction;
  Duration? delay;
  String? selectedWeatherCondition;

  bool showCard = false;
  bool showHorarioStep = false;
  bool showHorarioStep2 = false;
  bool showGrupoStep = false;
  bool showCascadaStep = false;
  bool showCascadaStep2 = false;
  bool showClimaStep = false;
  bool showDelay = false;

  Map<String, bool> deviceActions = {};
  Map<String, String> deviceUnits = {};

  List<String> selectedDays = [];
  List<String> deviceGroup = [];
  List<String> filterDevices = [];
  Map<String, Duration> deviceDelays = {};
  TextEditingController title = TextEditingController();
  TextEditingController delayController = TextEditingController();

  final List<String> weatherConditions = ['Viento', 'Lluvia', 'Nublado'];

  final selectWeekDaysKey = GlobalKey<SelectWeekDaysState>();

  @override
  void initState() {
    super.initState();
    // printLog.i(nicknamesMap);
    selectedWeatherCondition = weatherConditions.first;

    currentBuilder = buildMainOptions;

    title.addListener(() {
      setState(() {});
    });

    filterDevices = List.from(previusConnections);
    filterDevices.removeWhere((device) => device.contains('Detector'));
  }

  @override
  void dispose() {
    super.dispose();
    title.dispose();
    delayController.dispose();
    selectWeekDaysKey.currentState?.dispose();
  }

  void resetConfig() {
    setState(() {
      showHorarioStep = false;
      showHorarioStep2 = false;
      showGrupoStep = false;
      showDelay = false;
      showCascadaStep = false;
      showCascadaStep2 = false;

      deviceGroup.clear();
      title.clear();
    });
  }

  String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}';
    } else {
      return '${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
  }

  //*- Crea el evento -*\\
  Widget buildEvent(
    List<String> deviceGroup,
    String evento,
    String title,
    List<String> selectedDays,
    int selectedAction,
    String? selectedTime,
    Map<String, Duration>? devicesDelay,
    Map<String, bool>? devicesActions, {
    required VoidCallback onDelete,
  }) {
    String formatDays(List<String> days) {
      if (days.isEmpty) return 'No hay días seleccionados';
      if (days.length == 1) return days.first;
      final primeros = days.sublist(0, days.length - 1);
      return '${primeros.join(', ')} y ${days.last}';
    }

    Widget buildDeviceChips(List<String> deviceGroup) {
      if (deviceGroup.isEmpty) {
        return Center(
          child: Text(
            'No hay equipos seleccionados.',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: color0.withValues(alpha: 0.7),
            ),
          ),
        );
      }
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: deviceGroup.map((equipo) {
          String displayName = '';
          if (equipo.contains('_')) {
            final apodoSalida = nicknamesMap[equipo];
            final parts = equipo.split('_');
            displayName =
                '${nicknamesMap[parts[0]] ?? parts[0]} salida ${apodoSalida ?? parts[1]}';
          } else {
            displayName = nicknamesMap[equipo] ?? equipo;
          }
          switch (evento) {
            case 'horario':
              if (devicesDelay![equipo]! > const Duration(seconds: 0)) {
                displayName =
                    '$displayName luego de ${devicesDelay[equipo]!.toString().substring(2, 7)} ${devicesDelay[equipo]! > const Duration(seconds: 59) ? 'minutos' : 'segundos'} se ${devicesActions![equipo]! ? "encenderá" : "apagará"}';
              } else {
                displayName =
                    '$displayName se ${devicesActions![equipo]! ? "encenderá" : "apagará"}';
              }
              break;
            case 'grupo':
              displayName = displayName;
              break;
            case 'cascada':
              if (devicesDelay![equipo]! > const Duration(seconds: 0)) {
                displayName =
                    '$displayName luego de ${devicesDelay[equipo]!.toString().substring(2, 7)} ${devicesDelay[equipo]! > const Duration(seconds: 59) ? 'minutos' : 'segundos'} se ${devicesActions![equipo]! ? "encenderá" : "apagará"}';
              } else {
                displayName =
                    '$displayName se ${devicesActions![equipo]! ? "encenderá" : "apagará"}';
              }
              break;
            case 'clima':
              displayName = displayName;

            default:
              displayName = displayName;
          }
          return SizedBox(
            height: MediaQuery.of(context).size.width * 0.14,
            width: MediaQuery.of(context).size.width * 0.8,
            child: Card(
              child: Align(
                alignment: Alignment.center,
                child: Text(
                  textAlign: TextAlign.center,
                  displayName,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: color3,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      );
    }

    Widget buildCardContent({
      required String evento,
      required IconData icon,
      required String title,
      required String description,
      required List<String> devices,
    }) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, size: 28, color: color0),
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
                tooltip: 'Eliminar evento',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            description,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontStyle: FontStyle.italic,
              color: color0.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 16),
          buildDeviceChips(deviceGroup),
        ],
      );
    }

    switch (evento) {
      case 'horario':
        final daysText = formatDays(selectedDays);
        final description =
            'Este evento accionara los dispositivos seleccionados los días $daysText en el horario $selectedTime ';
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
            child: buildCardContent(
              evento: evento,
              icon: HugeIcons.strokeRoundedClock01,
              title: title,
              description: description,
              devices: deviceGroup,
            ),
          ),
        );

      case 'grupo':
        const description = 'Este evento controla los dispositivos:';
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
            child: buildCardContent(
              evento: evento,
              icon: HugeIcons.strokeRoundedComputerPhoneSync,
              title: title,
              description: description,
              devices: deviceGroup,
            ),
          ),
        );

      case 'cascada':
        const description = 'Me parece que no me traje el parawasca';
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
            child: buildCardContent(
              evento: evento,
              icon: HugeIcons.strokeRoundedLink01,
              title: title,
              description: description,
              devices: deviceGroup,
            ),
          ),
        );

      case 'clima':
        const description = 'Me parece que no me traje el parawasca';
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
            child: buildCardContent(
              evento: evento,
              icon: HugeIcons.strokeRoundedFastWind,
              title: title,
              description: description,
              devices: deviceGroup,
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
              leading:
                  const Icon(HugeIcons.strokeRoundedClock01, color: color0),
              title: Text('Control horario',
                  style: GoogleFonts.poppins(color: color0)),
              onTap: () {
                setState(() {
                  currentBuilder = buildControlHorario;
                  deviceGroup.clear();
                  selectedDays.clear();
                });
              },
            ),
            ListTile(
              leading: const Icon(HugeIcons.strokeRoundedLink01, color: color0),
              title: Text('Control por cascada',
                  style: GoogleFonts.poppins(color: color0)),
              onTap: () {
                setState(() {
                  currentBuilder = buildControlCascada;
                  deviceGroup.clear();
                });
              },
            ),
            ListTile(
              leading: const Icon(HugeIcons.strokeRoundedComputerPhoneSync,
                  color: color0),
              title: Text('Control por grupos',
                  style: GoogleFonts.poppins(color: color0)),
              onTap: () {
                setState(() {
                  currentBuilder = buildControlPorGrupo;
                  deviceGroup.clear();
                  selectedTime = null;
                });
              },
            ),
            ListTile(
              leading:
                  const Icon(HugeIcons.strokeRoundedFastWind, color: color0),
              title: Text('Control por clima',
                  style: GoogleFonts.poppins(color: color0)),
              onTap: () {
                setState(() {
                  currentBuilder = buildControlClima;
                  deviceGroup.clear();
                });
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
                            onPressed: () {
                              setState(() {
                                showHorarioStep = false;
                                selectedTime = null;
                                selectedDays.clear();
                              });
                            },
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
                              () => currentBuilder = buildMainOptions,
                            ),
                          ),
                        ),
                      } else ...{
                        Positioned(
                          left: 0,
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back),
                            color: color1,
                            onPressed: () {
                              setState(() {
                                showHorarioStep2 = false;
                                selectedTime = null;
                                selectedDays.clear();
                              });
                            },
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
                      height: 200,
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
                                (equipo.contains("Domotica") ||
                                        equipo.contains("Modulo"))
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
                                        final info = rawData is String
                                            ? jsonDecode(rawData)
                                            : rawData;

                                        final pinType = int.tryParse(
                                                info['pinType'].toString()) ??
                                            -1;
                                        if (pinType != 0) {
                                          return const SizedBox.shrink();
                                        }
                                        const tipoOut = 'Salida';
                                        final salidaId =
                                            '${equipo}_${key.replaceAll("io", "")}';
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
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  },
                  const SizedBox(height: 10),
                  Center(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('Continuar'),
                      onPressed: (deviceGroup.isNotEmpty)
                          ? () {
                              setState(() {
                                showHorarioStep = true;

                                selectedDays.clear();
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
                    },
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check),
                      label: const Text('Continuar'),
                      onPressed:
                          (selectedDays.isNotEmpty && selectedTime != null)
                              ? () {
                                  setState(() {
                                    deviceActions.clear();
                                    deviceDelays.clear();
                                    deviceUnits.clear();
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
                  // TERCER PASO
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
                  const SizedBox(height: 20),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.center,
                        child: Text(
                          'Ajusta el tiempo de funcionamiento de los dispositivos y la acción',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            color: color1,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      // LISTA de equipos con configuración independiente
                      Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.8,
                            maxHeight: MediaQuery.of(context).size.width * 0.8,
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: deviceGroup.length,
                            itemBuilder: (context, index) {
                              final device = deviceGroup[index];
                              final isOn = deviceActions[device] ?? false;
                              final unit = deviceUnits[device] ?? 'seg';
                              final delay = deviceDelays[device] ??
                                  const Duration(seconds: 0);

                              return Card(
                                elevation: 4,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                margin: const EdgeInsets.symmetric(
                                    vertical: 8, horizontal: 12),
                                color: color1,
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                            flex: 2,
                                            child: TextField(
                                              keyboardType:
                                                  TextInputType.number,
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
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  borderSide: const BorderSide(
                                                      color: color6),
                                                ),
                                                contentPadding:
                                                    const EdgeInsets.symmetric(
                                                  vertical: 10,
                                                  horizontal: 12,
                                                ),
                                              ),
                                              controller: TextEditingController(
                                                text: unit == 'seg'
                                                    ? delay.inSeconds.toString()
                                                    : delay.inMinutes
                                                        .toString(),
                                              )..selection =
                                                    TextSelection.collapsed(
                                                  offset: (unit == 'seg'
                                                          ? delay.inSeconds
                                                          : delay.inMinutes)
                                                      .toString()
                                                      .length,
                                                ),
                                              onChanged: (value) {
                                                int val =
                                                    int.tryParse(value) ?? 0;
                                                if (val > 60) val = 60;
                                                setState(() {
                                                  if (deviceUnits[device] ==
                                                      'min') {
                                                    deviceDelays[device] =
                                                        Duration(minutes: val);
                                                  } else {
                                                    deviceDelays[device] =
                                                        Duration(seconds: val);
                                                  }
                                                  printLog.i(
                                                    'Device $device delay (${deviceUnits[device]}): '
                                                    '${deviceUnits[device] == 'min' ? deviceDelays[device]!.inMinutes : deviceDelays[device]!.inSeconds}',
                                                  );
                                                });
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            flex: 3,
                                            child: ToggleButtons(
                                              isSelected: [
                                                unit == 'seg',
                                                unit == 'min',
                                              ],
                                              onPressed: (i) => setState(() {
                                                final currentValue =
                                                    unit == 'seg'
                                                        ? delay.inSeconds
                                                        : delay.inMinutes;
                                                final newUnit =
                                                    i == 0 ? 'seg' : 'min';
                                                deviceUnits[device] = newUnit;
                                                deviceDelays[device] =
                                                    newUnit == 'seg'
                                                        ? Duration(
                                                            seconds:
                                                                currentValue)
                                                        : Duration(
                                                            minutes:
                                                                currentValue);
                                                printLog.i(
                                                  'Device $device unit -> $newUnit, value preserved: $currentValue',
                                                );
                                              }),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              selectedColor: color1,
                                              fillColor:
                                                  color4.withValues(alpha: 0.8),
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
                                                        fontWeight:
                                                            FontWeight.w500)),
                                                Text('min',
                                                    style: GoogleFonts.poppins(
                                                        fontWeight:
                                                            FontWeight.w500)),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 14),
                                      Row(
                                        children: [
                                          Expanded(
                                            flex: 1,
                                            child: ToggleButtons(
                                              isSelected: [
                                                isOn == true,
                                                isOn == false,
                                              ],
                                              onPressed: (i) => setState(() {
                                                deviceActions[device] =
                                                    i == 0 ? true : false;
                                              }),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              selectedColor: color1,
                                              fillColor: isOn
                                                  ? Colors.green
                                                      .withValues(alpha: 0.8)
                                                  : color5.withValues(
                                                      alpha: 0.8),
                                              color: color3,
                                              borderColor: color3,
                                              selectedBorderColor: isOn
                                                  ? Colors.green
                                                      .withValues(alpha: 0.8)
                                                  : color5.withValues(
                                                      alpha: 0.8),
                                              constraints: BoxConstraints(
                                                minHeight: 36,
                                                minWidth: MediaQuery.of(context)
                                                        .size
                                                        .width *
                                                    0.28,
                                              ),
                                              children: [
                                                Text('Enceder',
                                                    style: GoogleFonts.poppins(
                                                        fontWeight:
                                                            FontWeight.w500)),
                                                Text('Apagar',
                                                    style: GoogleFonts.poppins(
                                                        fontWeight:
                                                            FontWeight.w500)),
                                              ],
                                            ),
                                          ),
                                        ],
                                      )
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Center(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.check),
                          label: const Text('Confirmar'),
                          onPressed:
                              //TODO trabajo 2
                              title.text.isNotEmpty
                                  ? () {
                                      for (final device in deviceGroup) {
                                        deviceActions[device] ??= false;
                                        deviceDelays[device] ??=
                                            const Duration(seconds: 0);
                                      }

                                      eventosCreados.add({
                                        'evento': 'horario',
                                        'title': title.text,
                                        'selectedDays':
                                            List<String>.from(selectedDays),
                                        'selectedTime':
                                            '${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}',
                                        'deviceActions': Map<String, bool>.from(
                                            deviceActions),
                                        'deviceDelays':
                                            Map<String, Duration>.from(
                                                deviceDelays),
                                        'deviceGroup':
                                            List<String>.from(deviceGroup),
                                      });
                                      deviceGroup.clear();
                                      showCard = false;
                                      resetConfig();
                                      currentBuilder = buildMainOptions;
                                      showToast("Grupo confirmado");
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
                    ],
                  ),
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
            // PASO 1
            if (!showGrupoStep) ...[
              Align(
                alignment: Alignment.topCenter,
                child: Text(
                  'Selecciona al menos dos equipos',
                  style: GoogleFonts.poppins(color: color1, fontSize: 16),
                ),
              ),
              const SizedBox(height: 20),
              if (filterDevices.length >= 2 ||
                  filterDevices.any((equipo) => equipo.contains("Domotica")) ||
                  filterDevices.any((equipo) => equipo.contains("Modulo"))) ...[
                SizedBox(
                  height: 200,
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
                          .where((k) => k.startsWith('io'))
                          .toList()
                        ..sort((a, b) {
                          final numA = int.tryParse(a.substring(2)) ?? 0;
                          final numB = int.tryParse(b.substring(2)) ?? 0;
                          return numA.compareTo(numB);
                        });

                      final hasSelectedSalida = salidaKeys.any((key) {
                        final rawData = deviceDATA[key];
                        final data =
                            rawData is String ? jsonDecode(rawData) : rawData;
                        final pinType =
                            int.tryParse(data['pinType'].toString()) ?? -1;
                        if (pinType != 0) return false;
                        final salidaId =
                            '${equipo}_${key.replaceAll("io", "")}';
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
                            (equipo.contains("Domotica") ||
                                    equipo.contains("Modulo"))
                                ? ListTile(
                                    title: Text(displayName,
                                        style:
                                            GoogleFonts.poppins(color: color0)),
                                  )
                                : CheckboxListTile(
                                    title: Text(displayName,
                                        style:
                                            GoogleFonts.poppins(color: color0)),
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
                                        style:
                                            GoogleFonts.poppins(color: color0),
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
                                  final salidaIndex = key.replaceAll('io', '');
                                  final salidaId = '${equipo}_$salidaIndex';
                                  final isChecked =
                                      deviceGroup.contains(salidaId);

                                  printLog.i(nicknamesMap);
                                  return CheckboxListTile(
                                    title: Text(
                                      nicknamesMap[salidaId] ??
                                          'Salida $salidaIndex',
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
            // PASO 2
            else ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Text(
                      'Escribe el nombre del grupo',
                      style: GoogleFonts.poppins(
                        color: color1,
                        fontSize: 16,
                      ),
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
                          putEventos(
                            service,
                            currentUserEmail,
                            eventosCreados,
                          );
                          printLog.i("Equipos seleccionados: $deviceGroup");
                          printLog.i(eventosCreados);
                          groupsOfDevices.addAll(
                            {
                              title.text.trim(): deviceGroup,
                            },
                          );
                          todosLosDispositivos.add(
                            MapEntry(
                              title.text.trim(),
                              deviceGroup.toString(),
                            ),
                          );

                          printLog.i(groupsOfDevices);
                          putGroupsOfDevices(
                            service,
                            currentUserEmail,
                            groupsOfDevices,
                          );
                          deviceGroup.clear();
                          showCard = false;
                          resetConfig();
                          currentBuilder = buildMainOptions;
                          showToast("Grupo confirmado");
                        });
                        printLog.i(eventosCreados);
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

  //*- Control por cascada -*\\
  Widget buildControlCascada() {
    return LayoutBuilder(
      builder: (context, constraints) {
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
                      Column(
                        children: [
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              // BOTON de retroceso
                              if (!showCascadaStep) ...{
                                Positioned(
                                  left: 0,
                                  child: IconButton(
                                    icon: const Icon(Icons.arrow_back),
                                    color: color1,
                                    onPressed: () => setState(() =>
                                        currentBuilder = buildMainOptions),
                                  ),
                                ),
                              },
                              if (showCascadaStep2) ...{
                                Positioned(
                                  left: 0,
                                  child: IconButton(
                                    icon: const Icon(Icons.arrow_back),
                                    color: color1,
                                    onPressed: () => setState(() => [
                                          showCascadaStep = false,
                                          showCascadaStep2 = false
                                        ]),
                                  ),
                                ),
                              },
                              // TITULO de la card
                              Center(
                                child: Text(
                                  'Control por cascada',
                                  style: GoogleFonts.poppins(
                                    color: color1,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (!showCascadaStep) ...{
                            // SUBTITULO de la card
                            Positioned(
                              right: 0,
                              child: SizedBox(
                                width: MediaQuery.of(context).size.width * 0.8,
                                child: Text(
                                  'Selecciona al menos dos dispositivos en el orden que desees encenderlos',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.poppins(
                                    color: color1,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            // LISTA de dispositivos
                            if (filterDevices.length >= 2 ||
                                filterDevices.any(
                                    (equipo) => equipo.contains("Domotica")) ||
                                filterDevices.any(
                                    (equipo) => equipo.contains("Modulo"))) ...{
                              SizedBox(
                                height: 200,
                                child: ListView.builder(
                                  itemCount: filterDevices.length,
                                  itemBuilder: (context, index) {
                                    final equipo = filterDevices[index];
                                    final isSelected =
                                        deviceGroup.contains(equipo);
                                    final displayName =
                                        nicknamesMap[equipo] ?? equipo;

                                    Map<String,
                                        dynamic> deviceDATA = globalDATA[
                                            '${DeviceManager.getProductCode(equipo)}/${DeviceManager.extractSerialNumber(equipo)}'] ??
                                        {};
                                    final salidaKeys = deviceDATA.keys
                                        .where((key) => key.contains('io'))
                                        .toList();
                                    final hasSelectedSalida =
                                        salidaKeys.any((key) {
                                      final rawData = deviceDATA[key];
                                      final data = rawData is String
                                          ? jsonDecode(rawData)
                                          : rawData;
                                      final pinType = int.tryParse(
                                              data['pinType'].toString()) ??
                                          -1;
                                      if (pinType != 0) return false;
                                      final salidaId =
                                          '${displayName}_${key.replaceAll("io", "")}';
                                      return deviceGroup.contains(salidaId);
                                    });

                                    return Container(
                                      margin:
                                          const EdgeInsets.only(bottom: 8.0),
                                      decoration: BoxDecoration(
                                        color: (isSelected || hasSelectedSalida)
                                            ? color6.withValues(alpha: 0.1)
                                            : color0.withValues(alpha: 0.1),
                                        borderRadius:
                                            BorderRadius.circular(8.0),
                                        border: Border.all(
                                          color:
                                              (isSelected || hasSelectedSalida)
                                                  ? color6
                                                  : color0,
                                          width: 1.0,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          (equipo.contains("Domotica") ||
                                                  equipo.contains("Modulo"))
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
                                                                .startsWith(
                                                                    displayName));
                                                      }
                                                    });
                                                  },
                                                ),
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                left: 32.0, bottom: 8.0),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: List.generate(
                                                deviceDATA.keys
                                                    .where((key) =>
                                                        key.contains('io'))
                                                    .length,
                                                (i) {
                                                  final key = 'io$i';
                                                  if (!deviceDATA
                                                      .containsKey(key)) {
                                                    return ListTile(
                                                      title: Text(
                                                        'Error en el equipo',
                                                        style:
                                                            GoogleFonts.poppins(
                                                          color: color0,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                      subtitle: Text(
                                                        'Se solucionará automáticamente en poco tiempo...',
                                                        style:
                                                            GoogleFonts.poppins(
                                                          color: color0,
                                                          fontWeight:
                                                              FontWeight.normal,
                                                        ),
                                                      ),
                                                    );
                                                  }
                                                  final rawData =
                                                      deviceDATA[key];
                                                  final info = rawData is String
                                                      ? jsonDecode(rawData)
                                                      : rawData;

                                                  final pinType = int.tryParse(
                                                          info['pinType']
                                                              .toString()) ??
                                                      -1;
                                                  if (pinType != 0) {
                                                    return const SizedBox
                                                        .shrink();
                                                  }
                                                  const tipoOut = 'Salida';
                                                  final salidaId =
                                                      '${equipo}_${key.replaceAll("io", "")}';
                                                  final isChecked = deviceGroup
                                                      .contains(salidaId);

                                                  return CheckboxListTile(
                                                    title: Text(
                                                      nicknamesMap[salidaId] ??
                                                          '$tipoOut $i',
                                                      style:
                                                          GoogleFonts.poppins(
                                                        color: color0,
                                                      ),
                                                    ),
                                                    value: isChecked,
                                                    activeColor: color6,
                                                    onChanged: (bool? value) {
                                                      setState(() {
                                                        if (value == true) {
                                                          deviceGroup
                                                              .add(salidaId);
                                                        } else {
                                                          deviceGroup
                                                              .remove(salidaId);
                                                        }
                                                      });
                                                    },
                                                  );
                                                },
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            } else ...{
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
                            },
                            const SizedBox(height: 20),
                            // BOTON de continuar
                            ElevatedButton.icon(
                              icon: const Icon(Icons.check),
                              label: const Text('Continuar'),
                              onPressed: deviceGroup.length >= 2
                                  ? () => setState(() => [
                                        deviceActions.clear(),
                                        deviceDelays.clear(),
                                        deviceUnits.clear(),
                                        showCascadaStep = true,
                                        showCascadaStep2 = true,
                                      ])
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: color0,
                                foregroundColor: color3,
                                disabledForegroundColor: color2,
                                disabledBackgroundColor: color0,
                              ),
                            ),
                          },
                          // ASIGNAR tiempo, accion y  orden de los dispositivos
                          if (showCascadaStep2) ...{
                            const SizedBox(height: 20),
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
                            const SizedBox(height: 20),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 10),
                                Align(
                                  alignment: Alignment.center,
                                  child: Text(
                                    'Configura el tiempo entre los equipos y la acción',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.poppins(
                                      color: color1,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),

                                // LISTA de equipos con tamaño máximo y scroll
                                Center(
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth:
                                          MediaQuery.of(context).size.width *
                                              0.8,
                                      maxHeight:
                                          MediaQuery.of(context).size.width *
                                              0.8,
                                    ),
                                    child: ListView.builder(
                                      shrinkWrap: true,
                                      physics:
                                          const AlwaysScrollableScrollPhysics(),
                                      itemCount: deviceGroup.length,
                                      itemBuilder: (context, index) {
                                        final device = deviceGroup[index];
                                        final isOn =
                                            deviceActions[device] ?? false;
                                        final unit =
                                            deviceUnits[device] ?? 'seg';
                                        final delay = deviceDelays[device] ??
                                            const Duration(seconds: 0);

                                        return Card(
                                          elevation: 4,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(16),
                                          ),
                                          margin: const EdgeInsets.symmetric(
                                              vertical: 8, horizontal: 12),
                                          color: color1,
                                          child: Padding(
                                            padding: const EdgeInsets.all(16),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    const Icon(
                                                        Icons.devices_other,
                                                        color: color3,
                                                        size: 20),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(
                                                        nicknamesMap[device] ??
                                                            device,
                                                        style:
                                                            GoogleFonts.poppins(
                                                          color: color3,
                                                          fontSize: 15,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                        overflow: TextOverflow
                                                            .ellipsis,
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
                                                        keyboardType:
                                                            TextInputType
                                                                .number,
                                                        textAlign:
                                                            TextAlign.center,
                                                        decoration:
                                                            InputDecoration(
                                                          filled: true,
                                                          fillColor: color2,
                                                          hintText: '0',
                                                          hintStyle: GoogleFonts
                                                              .poppins(
                                                            color: color3
                                                                .withAlpha(150),
                                                            fontSize: 12,
                                                          ),
                                                          border:
                                                              OutlineInputBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        12),
                                                            borderSide:
                                                                const BorderSide(
                                                                    color:
                                                                        color6),
                                                          ),
                                                          contentPadding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                            vertical: 10,
                                                            horizontal: 12,
                                                          ),
                                                        ),
                                                        controller:
                                                            TextEditingController(
                                                          text: unit == 'seg'
                                                              ? delay.inSeconds
                                                                  .toString()
                                                              : delay.inMinutes
                                                                  .toString(),
                                                        )..selection =
                                                                  TextSelection
                                                                      .collapsed(
                                                                offset: (unit ==
                                                                            'seg'
                                                                        ? delay
                                                                            .inSeconds
                                                                        : delay
                                                                            .inMinutes)
                                                                    .toString()
                                                                    .length,
                                                              ),
                                                        onChanged: (value) {
                                                          int val =
                                                              int.tryParse(
                                                                      value) ??
                                                                  0;
                                                          if (val > 60) {
                                                            val = 60;
                                                          }
                                                          setState(() {
                                                            if (deviceUnits[
                                                                    device] ==
                                                                'min') {
                                                              deviceDelays[
                                                                      device] =
                                                                  Duration(
                                                                      minutes:
                                                                          val);
                                                            } else {
                                                              deviceDelays[
                                                                      device] =
                                                                  Duration(
                                                                      seconds:
                                                                          val);
                                                            }
                                                            printLog.i(
                                                              'Device $device delay (${deviceUnits[device]}): '
                                                              '${deviceUnits[device] == 'min' ? deviceDelays[device]!.inMinutes : deviceDelays[device]!.inSeconds}',
                                                            );
                                                          });
                                                        },
                                                      ),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      flex: 3,
                                                      child: ToggleButtons(
                                                        isSelected: [
                                                          unit == 'seg',
                                                          unit == 'min',
                                                        ],
                                                        onPressed: (i) =>
                                                            setState(() {
                                                          final currentValue =
                                                              unit == 'seg'
                                                                  ? delay
                                                                      .inSeconds
                                                                  : delay
                                                                      .inMinutes;
                                                          final newUnit = i == 0
                                                              ? 'seg'
                                                              : 'min';
                                                          deviceUnits[device] =
                                                              newUnit;
                                                          deviceDelays[
                                                              device] = newUnit ==
                                                                  'seg'
                                                              ? Duration(
                                                                  seconds:
                                                                      currentValue)
                                                              : Duration(
                                                                  minutes:
                                                                      currentValue);
                                                          printLog.i(
                                                            'Device $device unit -> $newUnit, value preserved: $currentValue',
                                                          );
                                                        }),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(12),
                                                        selectedColor: color1,
                                                        fillColor:
                                                            color4.withValues(
                                                                alpha: 0.8),
                                                        color: color3,
                                                        borderColor: color4,
                                                        selectedBorderColor:
                                                            color4,
                                                        constraints:
                                                            const BoxConstraints(
                                                          minHeight: 36,
                                                          minWidth: 60,
                                                        ),
                                                        children: [
                                                          Text('seg',
                                                              style: GoogleFonts.poppins(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w500)),
                                                          Text('min',
                                                              style: GoogleFonts.poppins(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w500)),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 14),
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      flex: 1,
                                                      child: ToggleButtons(
                                                        isSelected: [
                                                          isOn == true,
                                                          isOn == false,
                                                        ],
                                                        onPressed: (i) =>
                                                            setState(() {
                                                          deviceActions[
                                                                  device] =
                                                              i == 0
                                                                  ? true
                                                                  : false;
                                                        }),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(12),
                                                        selectedColor: color1,
                                                        fillColor: isOn
                                                            ? Colors.green
                                                                .withValues(
                                                                    alpha: 0.8)
                                                            : color5.withValues(
                                                                alpha: 0.8),
                                                        color: color3,
                                                        borderColor: color3,
                                                        selectedBorderColor: isOn
                                                            ? Colors.green
                                                                .withValues(
                                                                    alpha: 0.8)
                                                            : color5.withValues(
                                                                alpha: 0.8),
                                                        constraints:
                                                            BoxConstraints(
                                                          minHeight: 36,
                                                          minWidth: MediaQuery.of(
                                                                      context)
                                                                  .size
                                                                  .width *
                                                              0.28,
                                                        ),
                                                        children: [
                                                          Text('Enceder',
                                                              style: GoogleFonts.poppins(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w500)),
                                                          Text('Apagar',
                                                              style: GoogleFonts.poppins(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w500)),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                )
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Center(
                                  child: ElevatedButton.icon(
                                    icon: const Icon(Icons.check),
                                    label: const Text('Confirmar'),
                                    onPressed: title.text.isNotEmpty
                                        ? () {
                                            for (final device in deviceGroup) {
                                              deviceActions[device] ??= false;
                                              deviceDelays[device] ??=
                                                  const Duration(seconds: 0);
                                            }

                                            eventosCreados.add({
                                              'evento': 'cascada',
                                              'title': title.text,
                                              'deviceActions':
                                                  Map<String, bool>.from(
                                                      deviceActions),
                                              'deviceDelays':
                                                  Map<String, Duration>.from(
                                                      deviceDelays),
                                              'deviceGroup': List<String>.from(
                                                  deviceGroup),
                                            });
                                            deviceGroup.clear();
                                            showCard = false;
                                            resetConfig();
                                            currentBuilder = buildMainOptions;
                                            showToast("Grupo confirmado");
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
                              ],
                            ),
                          }
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  //*- Control por cascada -*\\

  //*- Control por clima -*\\
  Widget buildControlClima() {
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
                        showCascadaStep
                            ? showCascadaStep = false
                            : currentBuilder = buildMainOptions;
                      }),
                    ),
                  ),
                  Text(
                    'Control por clima',
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
            // PASO 1
            if (!showCascadaStep) ...[
              Align(
                alignment: Alignment.topCenter,
                child: Text(
                  'Selecciona la condición climática',
                  style: GoogleFonts.poppins(color: color1, fontSize: 16),
                ),
              ),
              const SizedBox(height: 15),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: color0),
                  color: color0.withValues(alpha: 0.1),
                  borderRadius: const BorderRadius.all(
                    Radius.circular(15),
                  ),
                ),
                width: MediaQuery.of(context).size.width * 0.6,
                child: DropdownButton<String>(
                  value: selectedWeatherCondition,
                  isExpanded: true,
                  icon: const Icon(
                    HugeIcons.strokeRoundedArrowDown01,
                    color: color0,
                  ),
                  elevation: 16,
                  alignment: Alignment.center,
                  selectedItemBuilder: (BuildContext context) {
                    return weatherConditions.map<Widget>((String item) {
                      return Center(
                        child: Text(
                          item,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: color0,
                            fontSize: 18,
                          ),
                        ),
                      );
                    }).toList();
                  },
                  style: const TextStyle(
                    color: color0,
                    fontSize: 18,
                  ),
                  underline: const SizedBox(),
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
                          style: const TextStyle(
                            fontSize: 18,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 15),
              Align(
                alignment: Alignment.topCenter,
                child: Text(
                  'Selecciona al menos un equipo',
                  style: GoogleFonts.poppins(color: color1, fontSize: 16),
                ),
              ),
              const SizedBox(height: 20),
              if (filterDevices.length >= 2 ||
                  filterDevices.any((equipo) => equipo.contains("Domotica")) ||
                  filterDevices.any((equipo) => equipo.contains("Modulo"))) ...[
                SizedBox(
                  height: 200,
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
                          .where((k) => k.startsWith('io'))
                          .toList()
                        ..sort((a, b) {
                          final numA = int.tryParse(a.substring(2)) ?? 0;
                          final numB = int.tryParse(b.substring(2)) ?? 0;
                          return numA.compareTo(numB);
                        });

                      final hasSelectedSalida = salidaKeys.any((key) {
                        final rawData = deviceDATA[key];
                        final data =
                            rawData is String ? jsonDecode(rawData) : rawData;
                        final pinType =
                            int.tryParse(data['pinType'].toString()) ?? -1;
                        if (pinType != 0) return false;
                        final salidaId =
                            '${equipo}_${key.replaceAll("io", "")}';
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
                            (equipo.contains("Domotica") ||
                                    equipo.contains("Modulo"))
                                ? ListTile(
                                    title: Text(displayName,
                                        style:
                                            GoogleFonts.poppins(color: color0)),
                                  )
                                : CheckboxListTile(
                                    title: Text(displayName,
                                        style:
                                            GoogleFonts.poppins(color: color0)),
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
                                        style:
                                            GoogleFonts.poppins(color: color0),
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
                                  final salidaIndex = key.replaceAll('io', '');
                                  final salidaId = '${equipo}_$salidaIndex';
                                  final isChecked =
                                      deviceGroup.contains(salidaId);

                                  printLog.i(nicknamesMap);
                                  return CheckboxListTile(
                                    title: Text(
                                      nicknamesMap[salidaId] ??
                                          'Salida $salidaIndex',
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
                  onPressed: deviceGroup.isNotEmpty
                      ? () => setState(() => showCascadaStep = true)
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
            // PASO 2
            else ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Text(
                      'Escribe el nombre del grupo',
                      style: GoogleFonts.poppins(
                        color: color1,
                        fontSize: 16,
                      ),
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
                            'evento': 'clima',
                            'title': title.text,
                            'deviceGroup': List<String>.from(deviceGroup),
                          });
                          printLog.i("Equipos seleccionados: $deviceGroup");

                          deviceGroup.clear();
                          showCard = false;
                          resetConfig();
                          currentBuilder = buildMainOptions;
                          showToast("Grupo confirmado");
                        });
                        printLog.i(eventosCreados);
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
  //*- Control por clima -*\\

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, A) {
        if (context.mounted) {
          Navigator.pushReplacementNamed(context, '/menu');
        }
      },
      child: Scaffold(
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
            onPressed: () => Navigator.pushReplacementNamed(context, '/menu'),
          ),
        ),
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          child: Container(
            color: color1,
            width: double.infinity,
            height: double.infinity,
            padding: const EdgeInsets.all(16),
            child: AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        showCard = !showCard;
                        if (!showCard) {
                          resetConfig();
                          currentBuilder = buildMainOptions;
                        }
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
                  const SizedBox(height: 16),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    switchInCurve: Curves.easeIn,
                    switchOutCurve: Curves.easeOut,
                    child: showCard
                        ? Container(
                            key: const ValueKey('configCard'),
                            child: currentBuilder!(),
                          )
                        : const SizedBox.shrink(
                            key: ValueKey('noCard'),
                          ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: eventosCreados.isNotEmpty
                          ? ListView.builder(
                              itemCount: eventosCreados.length,
                              itemBuilder: (context, index) {
                                final evento = eventosCreados[index];
                                return buildEvent(
                                  (evento['deviceGroup'] as List)
                                      .cast<String>(),
                                  evento['evento'] as String,
                                  evento['title'] as String,
                                  evento['selectedDays'] ?? [],
                                  evento['selectedAction'] ?? 0,
                                  evento['selectedTime'] ?? '',
                                  evento['deviceDelays'] ??
                                      <String, Duration>{},
                                  evento['deviceActions'] ?? <String, bool>{},
                                  onDelete: () {
                                    setState(() {
                                      eventosCreados.removeAt(index);
                                      putEventos(service, currentUserEmail,
                                          eventosCreados);
                                      if (evento['evento'] == 'grupo') {
                                        groupsOfDevices.remove(evento['title']);
                                        putGroupsOfDevices(service,
                                            currentUserEmail, groupsOfDevices);
                                        todosLosDispositivos.removeWhere(
                                            (entry) =>
                                                entry.key == evento['title'] ||
                                                entry.value ==
                                                    evento['deviceGroup']
                                                        .toString());
                                      }
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
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
