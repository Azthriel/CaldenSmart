import 'dart:convert';

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
  String? selectedAction;
  bool showHorarioStep = false;
  bool showGrupoStep = false;

  List<String> selectedDays = [];
  List<String> deviceGroup = [];
  List<String> filterDevices = [];

  TextEditingController title = TextEditingController();

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

  //- Crea el evento -\\
  Widget buildEvent(List<String> deviceGroup, String evento, String title,
      {required VoidCallback onDelete}) {
    switch (evento) {
      case 'horario':
        return Card(
          color: color3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Este evento se ejecutará en horarios específicos.',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: color0,
                  ),
                ),
                const SizedBox(height: 16),
                _buildDeviceList(deviceGroup),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: onDelete,
                  ),
                ),
              ],
            ),
          ),
        );

      case 'grupo':
        return Card(
          color: color3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Este evento controla un grupo de dispositivos.',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: color0,
                  ),
                ),
                const SizedBox(height: 16),
                _buildDeviceList(deviceGroup),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: onDelete,
                  ),
                ),
              ],
            ),
          ),
        );

      default:
        return Card(
          color: color3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Evento Desconocido',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Este evento no tiene una configuración específica.',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: color0,
                  ),
                ),
                const SizedBox(height: 16),
                _buildDeviceList(deviceGroup),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: onDelete,
                  ),
                ),
              ],
            ),
          ),
        );
    }
  }

  Widget _buildDeviceList(List<String> deviceGroup) {
    if (deviceGroup.isEmpty) {
      return Text(
        'No hay equipos seleccionados.',
        style: GoogleFonts.poppins(
          fontSize: 14,
          color: color0,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: deviceGroup.map((equipo) {
        final displayName = nicknamesMap[equipo] ?? equipo;
        return Text(
          '• $displayName',
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: color0,
          ),
        );
      }).toList(),
    );
  }
  //- Crea el evento -\\

  //- Opción principal -\\
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
              leading: const Icon(Icons.devices_other, color: color0),
              title: Text(
                'Control por cascada',
                style: GoogleFonts.poppins(color: color0),
              ),
              onTap: () {
                showToast("Próximamente");
              },
            ),
            ListTile(
              leading: const Icon(Icons.devices, color: color0),
              title: Text(
                'Control por grupos',
                style: GoogleFonts.poppins(color: color0),
              ),
              onTap: () {
                setState(() {
                  currentBuilder = buildControlPorGrupo;
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.air, color: color0),
              title: Text(
                'Control por clima',
                style: GoogleFonts.poppins(color: color0),
              ),
              onTap: () {
                showToast("Próximamente");
              },
            ),
          ],
        ),
      ),
    );
  }
  //- Opción principal -\\

  //- Control horario -\\
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
                if (showHorarioStep)
                  Align(
                    alignment: Alignment.topLeft,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back),
                      color: color1,
                      onPressed: () {
                        setState(() {
                          showHorarioStep = false;
                        });
                      },
                    ),
                  ),
                Align(
                  alignment: Alignment.topCenter,
                  child: Text(
                    'Control horario',
                    style: GoogleFonts.poppins(
                      color: color1,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                if (!showHorarioStep) ...[
                  // PRIMER PASO
                  Text(
                    'Selecciona los equipos',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      color: color1,
                      fontSize: width * 0.04,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 200,
                    child: ListView.builder(
                      itemCount: filterDevices.length,
                      itemBuilder: (context, index) {
                        final equipo = filterDevices[index];
                        final isSelected = deviceGroup.contains(equipo);
                        final displayName = nicknamesMap[equipo] ?? equipo;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8.0),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? color6.withValues(alpha: 0.1)
                                : color0.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8.0),
                            border: Border.all(
                              color: isSelected ? color6 : color0,
                              width: 1.0,
                            ),
                          ),
                          child: CheckboxListTile(
                            title: Text(
                              displayName,
                              style: GoogleFonts.poppins(color: color0),
                            ),
                            value: isSelected,
                            activeColor: color6,
                            onChanged: (bool? value) {
                              setState(() {
                                if (value == true) {
                                  deviceGroup.add(equipo);
                                } else {
                                  deviceGroup.remove(equipo);
                                }
                              });
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.topCenter,
                    child: Text(
                      'Selecciona la acción del evento',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
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
                              selectedAction == 'on' ? color6 : color0,
                          foregroundColor: color3,
                        ),
                        onPressed: () {
                          setState(() {
                            selectedAction = 'on';
                          });
                        },
                      ),
                      const SizedBox(width: 20),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.power_off),
                        label: const Text('Apagar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              selectedAction == 'off' ? color6 : color0,
                          foregroundColor: color3,
                        ),
                        onPressed: () {
                          setState(() {
                            selectedAction = 'off';
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
                ] else ...[
                  // SEGUNDO PASO
                  Align(
                    alignment: Alignment.topCenter,
                    child: Text(
                      'Selecciona los días del evento',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        color: color1,
                        fontSize: width * 0.04,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: SelectWeekDays(
                      key: customWidgetKey,
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
                        fontWeight: FontWeight.bold,
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
                      printLog(
                          "Hora seleccionada: ${selectedTime?.format(context)}");
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
                                  showToast("Horario confirmado");
                                  printLog("Días seleccionados: $selectedDays",
                                      'violeta');
                                  printLog(
                                      "Hora seleccionada: ${selectedTime!.format(context)}",
                                      'violeta');
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
              ],
            ),
          ),
        );
      },
    );
  }
  //- Control horario -\\

  //- Control por grupo -\\
  Widget buildControlPorGrupo() {
    return Card(
      color: color3,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: Text(
                'Control por grupo',
                style: GoogleFonts.poppins(
                  color: color1,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (!showGrupoStep) ...[
              Align(
                alignment: Alignment.topCenter,
                child: Text(
                  'Selecciona al menos dos equipos',
                  style: GoogleFonts.poppins(
                    color: color1,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (filterDevices.length >= 2) ...{
                SizedBox(
                  height: 300,
                  child: ListView.builder(
                    itemCount: filterDevices.length,
                    itemBuilder: (context, index) {
                      final equipo = filterDevices[index];
                      final isSelected = deviceGroup.contains(equipo);
                      final displayName = nicknamesMap[equipo] ?? equipo;
                      Map<String, dynamic> deviceDATA = globalDATA[
                              '${DeviceManager.getProductCode(equipo)}/${DeviceManager.extractSerialNumber(equipo)}'] ??
                          {};
                      printLog('$equipo LOS TENEMOS SEÑOR', 'verde');
                      printLog('onichan $deviceDATA', 'rojo');

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8.0),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? color6.withValues(alpha: 0.1)
                              : color0.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8.0),
                          border: Border.all(
                            color: isSelected ? color6 : color0,
                            width: 1.0,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CheckboxListTile(
                              title: Text(
                                displayName,
                                style: GoogleFonts.poppins(color: color0),
                              ),
                              value: isSelected,
                              activeColor: color6,
                              onChanged: (bool? value) {
                                setState(() {
                                  if (value == true) {
                                    deviceGroup.add(equipo);
                                  } else {
                                    deviceGroup.removeWhere((salidaId) =>
                                        salidaId.startsWith(displayName));
                                  }
                                });
                              },
                            ),
                            if (isSelected &&
                                (displayName.contains("Domotica") ||
                                    displayName.contains("Modulo"))) ...{
                              Padding(
                                padding: const EdgeInsets.only(
                                    left: 32.0, bottom: 8.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                              equipo['pinType'].toString()) ??
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
                                            fontWeight: FontWeight.bold,
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
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  icon: const Icon(Icons.check),
                  label: const Text('Continuar'),
                  onPressed: (deviceGroup.length >= 2)
                      ? () {
                          setState(() {
                            showGrupoStep = true;
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
            ] else ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
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
                onPressed: (title.text.isNotEmpty)
                    ? () {
                        setState(() {
                          eventosCreados.add({
                            'evento': 'grupo',
                            'title': title.text,
                            'deviceGroup': List<String>.from(deviceGroup),
                          });
                          putEventos(service, currentUserEmail, eventosCreados);
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
                          title.clear();
                          currentBuilder = buildMainOptions;
                          showCard = false;
                        });
                        showGrupoStep = false;
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
            ]
          ],
        ),
      ),
    );
  }
  //- Control por grupo -\\

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
                          showHorarioStep = false;
                          showGrupoStep = false;
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
