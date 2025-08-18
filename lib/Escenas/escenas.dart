// ignore_for_file: equal_elements_in_set

import 'package:caldensmart/Escenas/control_disparadores.dart';
import 'package:caldensmart/Escenas/control_cadena.dart';
// import 'package:caldensmart/Escenas/control_clima.dart';
import 'package:caldensmart/Escenas/control_grupo.dart';
import 'package:caldensmart/Escenas/control_horario.dart';
// import 'package:caldensmart/Escenas/control_horario.dart';
import 'package:caldensmart/aws/dynamo/dynamo.dart';
import 'package:caldensmart/logger.dart';
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
  late VoidCallback _titleListener;
  final GlobalKey _configCardKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // printLog(nicknamesMap);
    selectedWeatherCondition = weatherConditions.first;

    currentBuilder = buildMainOptions;
    _titleListener = () {
      if (mounted) setState(() {});
    };
    title.addListener(_titleListener);

    filterDevices = List.from(previusConnections);
    filterDevices.removeWhere((device) => device.contains('Detector'));
  }

  @override
  void dispose() {
    super.dispose();
    _scrollController.dispose();

    title.removeListener(_titleListener);

    delayController.dispose();
    selectWeekDaysKey.currentState?.dispose();
  }

  void resetConfig() {
    setState(() {
      showCard = false;
      showHorarioStep = false;
      showHorarioStep2 = false;
      showGrupoStep = false;
      showCascadaStep = false;
      showCascadaStep2 = false;
      showClimaStep = false;
      showClimaStep2 = false;

      showDelay = false;

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
    Map<String, bool>? devicesActions,
    String? condition,
    List<String> activadores,
    List<String> ejecutores,
    String? estadoAlerta,
    String? estadoTermometro, {
    List<Map<String, dynamic>>? pasosCadena,
    required VoidCallback onDelete,
  }) {
    printLog.i('aca estamos revisando $devicesActions', color: 'verde');
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

      if (evento == 'cadena') {
        // Manejar estructura de pasos para cadenas
        if (pasosCadena != null && pasosCadena.isNotEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color0.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: color0.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      HugeIcons.strokeRoundedSettings02,
                      size: 20,
                      color: color6,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'PASOS DE LA CADENA',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: color0.withValues(alpha: 0.9),
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Mostrar cada paso
                ...pasosCadena.asMap().entries.map((entry) {
                  final pasoIndex = entry.key;
                  final paso = entry.value;
                  final devices = paso['devices'] as List<dynamic>? ?? [];
                  if(paso['actions'].runtimeType == String) {
                    paso['actions'] = parseMapString(paso['actions']);
                  }
                  final actions =
                      paso['actions'] as Map<String, dynamic>? ?? {};
                  
                  final stepDelay =
                      paso['stepDelay'] as Duration? ?? Duration.zero;
                  final stepDelayUnit =
                      paso['stepDelayUnit'] as String? ?? 'seg';

                  String delayText = '';
                  if (stepDelay > Duration.zero) {
                    if (stepDelayUnit == 'min') {
                      delayText =
                          '${stepDelay.inMinutes} ${stepDelay.inMinutes == 1 ? 'minuto' : 'minutos'}';
                    } else {
                      delayText =
                          '${stepDelay.inSeconds} ${stepDelay.inSeconds == 1 ? 'segundo' : 'segundos'}';
                    }
                  } else {
                    delayText = 'Instantáneo';
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: color6.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: color6.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Cabecera del paso
                        Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: color6,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Center(
                                child: Text(
                                  '${pasoIndex + 1}',
                                  style: GoogleFonts.poppins(
                                    color: color1,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Paso ${pasoIndex + 1}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: color0,
                                    ),
                                  ),
                                  Text(
                                    delayText,
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: stepDelay > Duration.zero
                                          ? Colors.orange.shade700
                                          : Colors.green.shade700,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Dispositivos del paso
                        ...devices.map((device) {
                          if(actions[device].runtimeType == String) {
                            actions[device] = actions[device] == 'true';
                          }
                          final action = actions[device] ?? false;
                          String displayName = '';
                          if (device.contains('_')) {
                            final apodoSalida = nicknamesMap[device];
                            final parts = device.split('_');
                            displayName =
                                '${nicknamesMap[parts[0]] ?? parts[0]} salida ${apodoSalida ?? parts[1]}';
                          } else {
                            displayName = nicknamesMap[device] ?? device;
                          }

                          final actionIcon = action
                              ? HugeIcons.strokeRoundedPlug01
                              : HugeIcons.strokeRoundedPlugSocket;
                          final actionColor = action ? Colors.green : color6;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: actionColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
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
                                    color: actionColor.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Icon(
                                    actionIcon,
                                    size: 14,
                                    color: actionColor,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        displayName,
                                        style: GoogleFonts.poppins(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: color0,
                                        ),
                                      ),
                                      Text(
                                        'Se ${action ? "encenderá" : "apagará"}',
                                        style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          color: color0.withValues(alpha: 0.7),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  );
                }),
              ],
            ),
          );
        }

        // Fallback para estructura antigua
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color0.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color0.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    HugeIcons.strokeRoundedSettings02,
                    size: 20,
                    color: color6,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'PASOS DE LA CADENA',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: color0.withValues(alpha: 0.9),
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Aquí debemos obtener los pasos desde los datos del evento
              // Como no tenemos acceso directo, necesitamos pasar los pasos como parámetro
              // Por ahora, creamos una vista simplificada
              ...deviceGroup.asMap().entries.map((entry) {
                final index = entry.key;
                final equipo = entry.value;
                String displayName = '';
                if (equipo.contains('_')) {
                  final apodoSalida = nicknamesMap[equipo];
                  final parts = equipo.split('_');
                  displayName =
                      '${nicknamesMap[parts[0]] ?? parts[0]} salida ${apodoSalida ?? parts[1]}';
                } else {
                  displayName = nicknamesMap[equipo] ?? equipo;
                }

                final delay = devicesDelay?[equipo] ?? Duration.zero;
                final action = devicesActions?[equipo] ?? false;
                final actionIcon = action
                    ? HugeIcons.strokeRoundedPlug01
                    : HugeIcons.strokeRoundedPlugSocket;
                final actionColor = action ? Colors.green : color6;

                String actionText;
                if (delay > const Duration(seconds: 0)) {
                  actionText =
                      'Luego de ${delay.toString().substring(2, 7)} ${delay > const Duration(seconds: 59) ? 'minutos' : 'segundos'} se ${action ? "encenderá" : "apagará"}';
                } else {
                  actionText = 'Se ${action ? "encenderá" : "apagará"}';
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: actionColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: actionColor.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Número de posición
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: color6,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: GoogleFonts.poppins(
                              color: color1,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Icono de acción
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: actionColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          actionIcon,
                          size: 16,
                          color: actionColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Información del dispositivo
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: color0,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              actionText,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: color0.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      }

      if (evento == 'disparador') {
        final bool isTermometro =
            deviceGroup.isNotEmpty && deviceGroup.first.contains('Termometro');
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Activador section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color0.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: color0.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        HugeIcons.strokeRoundedPlayCircle,
                        size: 20,
                        color: color6,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'ACTIVADOR',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: color0.withValues(alpha: 0.9),
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (deviceGroup.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: color6.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: color6.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: color6.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  HugeIcons.strokeRoundedLink01,
                                  size: 16,
                                  color: color6,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  () {
                                    final activador = deviceGroup.first;
                                    if (activador.contains('_')) {
                                      final apodoActivador =
                                          nicknamesMap[activador];
                                      final parts = activador.split('_');
                                      return '${nicknamesMap[parts[0]] ?? parts[0]} entrada ${apodoActivador ?? parts[1]}';
                                    } else {
                                      return nicknamesMap[activador] ??
                                          activador;
                                    }
                                  }(),
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: color0,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Alertas section
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color0.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: color0.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        HugeIcons.strokeRoundedInformationCircle,
                        size: 20,
                        color: color6,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'CONDICIONES',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: color0.withValues(alpha: 0.9),
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Card(
                    color: Colors.transparent,
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: (estadoAlerta == "1"
                                ? Colors.orange
                                : Colors.blueGrey)
                            .withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            estadoAlerta == "1"
                                ? HugeIcons.strokeRoundedAlert02
                                : HugeIcons.strokeRoundedCheckmarkCircle02,
                            color: estadoAlerta == "1"
                                ? Colors.orange
                                : Colors.blueGrey,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  const TextSpan(
                                      text:
                                          "El evento se accionara cuando el activador esté en "),
                                  TextSpan(
                                    text: estadoAlerta == "1"
                                        ? "ALERTA"
                                        : "REPOSO",
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold,
                                      color: estadoAlerta == "1"
                                          ? Colors.orange
                                          : Colors.blueGrey,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const TextSpan(text: "."),
                                ],
                              ),
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: color0.withValues(alpha: 0.85),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (isTermometro && estadoTermometro != null)
                    Card(
                      color: Colors.transparent,
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color: (estadoTermometro == "1"
                                  ? Colors.red
                                  : Colors.lightBlue)
                              .withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.thermostat,
                              color: estadoTermometro == "1"
                                  ? Colors.red
                                  : Colors.lightBlue,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text.rich(
                                TextSpan(
                                  children: [
                                    const TextSpan(
                                        text: "Condición usada: Temperatura "),
                                    TextSpan(
                                      text: estadoTermometro == "1"
                                          ? "MÁXIMA"
                                          : "MÍNIMA",
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.bold,
                                        color: estadoTermometro == "1"
                                            ? Colors.red
                                            : Colors.lightBlue,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const TextSpan(text: " del termómetro."),
                                  ],
                                ),
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: color0.withValues(alpha: 0.85),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Ejecutores section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color0.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: color0.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        HugeIcons.strokeRoundedSettings02,
                        size: 20,
                        color: color6,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'EJECUTORES',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: color0.withValues(alpha: 0.9),
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...deviceGroup.skip(1).map((equipo) {
                    String displayName = '';
                    if (equipo.contains('_')) {
                      final apodoSalida = nicknamesMap[equipo];
                      final parts = equipo.split('_');
                      displayName =
                          '${nicknamesMap[parts[0]] ?? parts[0]} salida ${apodoSalida ?? parts[1]}';
                    } else {
                      displayName = nicknamesMap[equipo] ?? equipo;
                    }
                    final action =
                        devicesActions != null ? devicesActions[equipo] : null;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: (action == true ? Colors.green : color6)
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: (action == true ? Colors.green : color6)
                              .withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: (action == true ? Colors.green : color6)
                                  .withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              action == true
                                  ? HugeIcons.strokeRoundedPlug01
                                  : HugeIcons.strokeRoundedPlugSocket,
                              size: 16,
                              color: action == true ? Colors.green : color6,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayName,
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: color0,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Se ${action == true ? "encenderá" : "apagará"}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: color0.withValues(alpha: 0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        );
      }

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color0.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color0.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  HugeIcons.strokeRoundedSettings02,
                  size: 20,
                  color: color6,
                ),
                const SizedBox(width: 8),
                Text(
                  'DISPOSITIVOS',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color0.withValues(alpha: 0.9),
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...deviceGroup.asMap().entries.map((entry) {
              final index = entry.key;
              final equipo = entry.value;
              String displayName = '';
              if (equipo.contains('_')) {
                final apodoSalida = nicknamesMap[equipo];
                final parts = equipo.split('_');
                displayName =
                    '${nicknamesMap[parts[0]] ?? parts[0]} salida ${apodoSalida ?? parts[1]}';
              } else {
                displayName = nicknamesMap[equipo] ?? equipo;
              }

              String actionText = '';
              IconData actionIcon = HugeIcons.strokeRoundedSettings02;
              Color actionColor = color3;

              switch (evento) {
                case 'horario':
                  final delay = devicesDelay?[equipo] ?? Duration.zero;
                  final action = devicesActions?[equipo] ?? false;
                  actionIcon = action
                      ? HugeIcons.strokeRoundedPlug01
                      : HugeIcons.strokeRoundedPlugSocket;
                  actionColor = action ? Colors.green : color6;

                  if (delay > const Duration(seconds: 0)) {
                    actionText =
                        'Luego de ${delay.toString().substring(2, 7)} ${delay > const Duration(seconds: 59) ? 'minutos' : 'segundos'} se ${action ? "encenderá" : "apagará"}';
                  } else {
                    actionText = 'Se ${action ? "encenderá" : "apagará"}';
                  }
                  break;
                case 'grupo':
                  final action = devicesActions?[equipo];
                  if (action == true) {
                    // Encender - verde con enchufe común
                    actionText = 'Se encenderá';
                    actionIcon = HugeIcons.strokeRoundedPlug01;
                    actionColor = Colors.green;
                  } else if (action == false) {
                    // Apagar - color6 con enchufe desconectado
                    actionText = 'Se apagará';
                    actionIcon = HugeIcons.strokeRoundedPlugSocket;
                    actionColor = color6;
                  } else {
                    // Sin acción específica - color neutro
                    actionText = 'Parte del grupo';
                    actionIcon = HugeIcons.strokeRoundedEqualSign;
                    actionColor = color0;
                  }
                  break;
                case 'cadena':
                  final delay = devicesDelay?[equipo] ?? Duration.zero;
                  final action = devicesActions?[equipo] ?? false;
                  actionIcon = action
                      ? HugeIcons.strokeRoundedPlug01
                      : HugeIcons.strokeRoundedPlugSocket;
                  actionColor = action ? Colors.green : color6;

                  if (delay > const Duration(seconds: 0)) {
                    actionText =
                        'Posición ${index + 1} - Luego de ${delay.toString().substring(2, 7)} ${delay > const Duration(seconds: 59) ? 'minutos' : 'segundos'} se ${action ? "encenderá" : "apagará"}';
                  } else {
                    actionText =
                        'Posición ${index + 1} - Se ${action ? "encenderá" : "apagará"}';
                  }
                  break;
                case 'clima':
                  final action = devicesActions?[equipo] ?? false;
                  actionIcon = action
                      ? HugeIcons.strokeRoundedPlug01
                      : HugeIcons.strokeRoundedPlugSocket;
                  actionColor = action ? Colors.green : color6;
                  actionText =
                      'Se ${action ? "encenderá" : "apagará"} según condición climática';
                  break;
                default:
                  actionText = displayName;
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: actionColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: actionColor.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    // Número de orden para cadena
                    if (evento == 'cadena') ...[
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: actionColor.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: color0,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    // Icono de acción
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: actionColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        actionIcon,
                        size: 16,
                        color: actionColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Información del dispositivo
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: color0,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            actionText,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: color0.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      );
    }

    Widget buildCardContent({
      required String evento,
      required IconData icon,
      required String title,
      required String description,
      required List<String> devices,
      Color? iconColor,
    }) {
      return Container(
        decoration: BoxDecoration(
          color: color3,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color3.withValues(alpha: 0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: color0.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                border: Border.all(
                  color: color0.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: (iconColor ?? color0).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color:
                                  (iconColor ?? color0).withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child:
                              Icon(icon, size: 24, color: iconColor ?? color0),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: color0,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: (iconColor ?? color0)
                                      .withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  evento.toUpperCase(),
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: iconColor ?? color0,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: color5.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: color5.withValues(alpha: 0.4),
                        width: 1,
                      ),
                    ),
                    child: IconButton(
                      icon:
                          const Icon(HugeIcons.strokeRoundedDelete02, size: 20),
                      color: color5,
                      onPressed: onDelete,
                      tooltip: 'Eliminar evento',
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: color0.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: color0.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      description,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: color0.withValues(alpha: 0.9),
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  buildDeviceChips(deviceGroup),
                ],
              ),
            ),
          ],
        ),
      );
    }

    switch (evento) {
      case 'horario':
        final daysText = formatDays(selectedDays);
        final timeText = selectedTime ?? 'hora no especificada';
        final description =
            'Este evento accionara los dispositivos seleccionados los días $daysText en el horario $timeText';
        return Card(
          elevation: 0,
          color: Colors.transparent,
          child: buildCardContent(
            evento: evento,
            icon: HugeIcons.strokeRoundedClock01,
            title: title,
            description: description,
            devices: deviceGroup,
            iconColor: color6,
          ),
        );

      case 'grupo':
        const description = 'Este evento controla los dispositivos:';
        return Card(
          elevation: 0,
          color: Colors.transparent,
          child: buildCardContent(
            evento: evento,
            icon: HugeIcons.strokeRoundedComputerPhoneSync,
            title: title,
            description: description,
            devices: deviceGroup,
            iconColor: color6,
          ),
        );

      case 'cadena':
        const description =
            'Este evento ejecuta dispositivos organizados por pasos en secuencia:';
        return Card(
          elevation: 0,
          color: Colors.transparent,
          child: buildCardContent(
            evento: evento,
            icon: HugeIcons.strokeRoundedLink01,
            title: title,
            description: description,
            devices: deviceGroup,
            iconColor: color6,
          ),
        );
      case 'clima':
        final description =
            'Este evento accionara los dispositivos si se cumple la condición de $condition';
        return Card(
          elevation: 0,
          color: Colors.transparent,
          child: buildCardContent(
            evento: evento,
            icon: (() {
              switch (condition) {
                case 'Lluvia':
                  return HugeIcons.strokeRoundedCloudAngledRain;
                case 'Nublado':
                  return HugeIcons.strokeRoundedSunCloud02;
                case 'Viento':
                  return HugeIcons.strokeRoundedFastWind;
                default:
                  return HugeIcons.strokeRoundedCloud;
              }
            })(),
            title: title,
            description: description,
            devices: deviceGroup,
            iconColor: color6,
          ),
        );

      case 'disparador':
        const description =
            'Este evento se activa automáticamente cuando el activador cumple las condiciones y ejecuta los equipos configurados';
        return Card(
          elevation: 0,
          color: Colors.transparent,
          child: buildCardContent(
            evento: evento,
            icon: HugeIcons.strokeRoundedLink01,
            title: title,
            description: description,
            devices: deviceGroup,
            iconColor: color6,
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }
  //*- Crea el evento -*\\

  //*- Opción principal -*\\
  Widget buildMainOptions() {
    return Container(
      decoration: BoxDecoration(
        color: color3,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color3.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Header mejorado
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: color0.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: color0.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color6.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: color6.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      HugeIcons.strokeRoundedSettings02,
                      size: 24,
                      color: color6,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Selecciona un tipo de evento',
                      textAlign: TextAlign.left,
                      style: GoogleFonts.poppins(
                        color: color0,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Lista de opciones mejorada
            _buildOptionTile(
              icon: HugeIcons.strokeRoundedClock01,
              title: 'Control horario',
              subtitle: 'Programa eventos en días y horarios específicos',
              color: color0,
              onTap: () {
                // showToast("Próximamente");
                setState(() {
                  currentBuilder = () => ControlHorarioWidget(
                        onBackToMain: () =>
                            setState(() => currentBuilder = buildMainOptions),
                      );
                  deviceGroup.clear();
                });
                Future.delayed(const Duration(milliseconds: 350), () {
                  final context = _configCardKey.currentContext;
                  if (context != null && context.mounted) {
                    Scrollable.ensureVisible(
                      context,
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeInOut,
                      alignment: 0.1,
                    );
                  }
                });
              },
            ),
            const SizedBox(height: 16),
            _buildOptionTile(
              icon: HugeIcons.strokeRoundedLink01,
              title: 'Control por cadena',
              subtitle: 'Ejecuta dispositivos en secuencia con retrasos',
              color: color0,
              onTap: () {
                // showToast("Próximamente");
                setState(() {
                  currentBuilder = () => ControlCadenaWidget(
                        onBackToMain: () =>
                            setState(() => currentBuilder = buildMainOptions),
                      );
                  deviceGroup.clear();
                });
                Future.delayed(const Duration(milliseconds: 350), () {
                  final context = _configCardKey.currentContext;
                  if (context != null && context.mounted) {
                    Scrollable.ensureVisible(
                      context,
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeInOut,
                      alignment: 0.1,
                    );
                  }
                });
              },
            ),
            const SizedBox(height: 16),
            _buildOptionTile(
              icon: HugeIcons.strokeRoundedComputerPhoneSync,
              title: 'Control por grupos',
              subtitle: 'Controla múltiples dispositivos como una unidad',
              color: color0,
              onTap: () {
                setState(() {
                  currentBuilder = () => ControlPorGrupoWidget(
                        onBackToMain: () =>
                            setState(() => currentBuilder = buildMainOptions),
                      );
                  deviceGroup.clear();
                  selectedTime = null;
                });
                Future.delayed(const Duration(milliseconds: 350), () {
                  final context = _configCardKey.currentContext;
                  if (context != null && context.mounted) {
                    Scrollable.ensureVisible(
                      context,
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeInOut,
                      alignment: 0.1,
                    );
                  }
                });
              },
            ),
            const SizedBox(height: 16),
            _buildOptionTile(
              icon: HugeIcons.strokeRoundedFastWind,
              title: 'Control por clima',
              subtitle: 'Activa eventos según condiciones meteorológicas',
              color: color0,
              onTap: () {
                showToast("Próximamente");
                // setState(() {
                //   currentBuilder = () => ControlClimaWidget(
                //         onBackToMain: () =>
                //             setState(() => currentBuilder = buildMainOptions),
                //       );
                //   deviceGroup.clear();
                // });
                // Future.delayed(const Duration(milliseconds: 350), () {
                //   final context = _configCardKey.currentContext;
                //   if (context != null && context.mounted) {
                //     Scrollable.ensureVisible(
                //       context,
                //       duration: const Duration(milliseconds: 400),
                //       curve: Curves.easeInOut,
                //       alignment: 0.1,
                //     );
                //   }
                // });
              },
            ),
            const SizedBox(height: 16),
            _buildOptionTile(
              icon: HugeIcons.strokeRoundedPlayCircle,
              title: 'Control por disparadores',
              subtitle: 'Un dispositivo activa automáticamente otros',
              color: color0,
              onTap: () {
                setState(() {
                  currentBuilder = () => ControlDisparadorWidget(
                        onBackToMain: () =>
                            setState(() => currentBuilder = buildMainOptions),
                      );
                  deviceGroup.clear();
                });
                Future.delayed(const Duration(milliseconds: 350), () {
                  final context = _configCardKey.currentContext;
                  if (context != null && context.mounted) {
                    Scrollable.ensureVisible(
                      context,
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeInOut,
                      alignment: 0.1,
                    );
                  }
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color0.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color0.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: color.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    icon,
                    size: 24,
                    color: color,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          color: color0,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: GoogleFonts.poppins(
                          color: color0.withValues(alpha: 0.7),
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    HugeIcons.strokeRoundedArrowRight02,
                    size: 16,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  //*- Opción principal -*\\

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
            child: SingleChildScrollView(
              controller: _scrollController,
              child: Column(
                children: [
                  // Botón de configurar evento mejorado
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: showCard
                            ? [color5, color4]
                            : [color3, color3.withValues(alpha: 0.8)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: (showCard ? color5 : color3)
                              .withValues(alpha: 0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            showCard = !showCard;
                            if (!showCard) {
                              resetConfig();
                              currentBuilder = buildMainOptions;
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 16),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: color0.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  showCard
                                      ? HugeIcons.strokeRoundedCancel01
                                      : HugeIcons.strokeRoundedAdd01,
                                  color: color0,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                showCard
                                    ? 'Cancelar evento'
                                    : 'Configurar evento',
                                style: GoogleFonts.poppins(
                                  color: color0,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    switchInCurve: Curves.easeIn,
                    switchOutCurve: Curves.easeOut,
                    child: showCard
                        ? Container(
                            key: _configCardKey,
                            child: currentBuilder!(),
                          )
                        : const SizedBox.shrink(
                            key: ValueKey('noCard'),
                          ),
                  ),
                  const SizedBox(height: 16),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: eventosCreados.isNotEmpty
                        ? Column(
                            children:
                                eventosCreados.asMap().entries.map((entry) {
                              final index = entry.key;
                              final evento = entry.value;
                              return AnimatedContainer(
                                duration:
                                    Duration(milliseconds: 200 + (index * 50)),
                                curve: Curves.easeOutBack,
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 20),
                                  child: () {
                                    List<String> deviceGroup = [];

                                    final eventoType =
                                        evento['evento'] as String;

                                    if (eventoType == 'cadena' &&
                                        evento['pasos'] != null) {
                                      // Para eventos de cadena, extraer devices de todos los pasos
                                      final pasos = evento['pasos'] as List;
                                      for (final paso in pasos) {
                                        // Si paso es String, parsearlo para compatibilidad
                                        dynamic pasoProcessed = paso;
                                        if (paso is String) {
                                          try {
                                            pasoProcessed =
                                                parseMapString(paso);
                                          } catch (e) {
                                            printLog.e(
                                                'Error parseando paso en escenas: $e');
                                            continue; // Saltar este paso si hay error
                                          }
                                        }

                                        // Validar que el paso tenga la estructura correcta
                                        if (pasoProcessed is Map &&
                                            pasoProcessed['devices'] != null) {
                                          final devices =
                                              pasoProcessed['devices']
                                                      as List<dynamic>? ??
                                                  [];
                                          deviceGroup.addAll(
                                              devices.map((e) => e.toString()));
                                        }
                                      }
                                      // Eliminar duplicados
                                      deviceGroup =
                                          deviceGroup.toSet().toList();
                                    } else {
                                      // Para otros eventos, usar deviceGroup normal
                                      deviceGroup =
                                          (evento['deviceGroup'] as List?)
                                                  ?.whereType<String>()
                                                  .toList() ??
                                              <String>[];
                                    }
                                    final title = evento['title'] as String;

                                    final selectedDays =
                                        (evento['selectedDays'] as List?)
                                                ?.whereType<String>()
                                                .toList() ??
                                            <String>[];

                                    final selectedAction =
                                        evento['selectedAction'] ?? 0;
                                    final selectedTime =
                                        evento['selectedTime'] ?? '';

                                    final deviceDelays =
                                        evento['deviceDelays'] != null
                                            ? Map<String, Duration>.from(
                                                (evento['deviceDelays'] as Map)
                                                    .map(
                                                  (key, value) => MapEntry(
                                                    key.toString(),
                                                    value is int
                                                        ? Duration(
                                                            seconds: value)
                                                        : Duration.zero,
                                                  ),
                                                ),
                                              )
                                            : <String, Duration>{};

                                    final deviceActions =
                                        evento['deviceActions'] != null
                                            ? Map<String, bool>.from(
                                                (evento['deviceActions'] as Map)
                                                    .map(
                                                  (key, value) => MapEntry(
                                                    key.toString(),
                                                    value == true,
                                                  ),
                                                ),
                                              )
                                            : <String, bool>{};

                                    final condition = evento['condition'] ?? '';

                                    final activadores =
                                        (evento['activadores'] as List?)
                                                ?.whereType<String>()
                                                .toList() ??
                                            <String>[];

                                    final ejecutores =
                                        (evento['ejecutores'] as List?)
                                                ?.whereType<String>()
                                                .toList() ??
                                            <String>[];

                                    final estadoAlerta =
                                        evento['estadoAlerta']?.toString();
                                    final estadoTermometro =
                                        evento['estadoTermometro']?.toString();
                                    final pasosCadena = eventoType == 'cadena'
                                        ? (evento['pasos'] as List?)
                                            ?.map((paso) {
                                            // Si paso es String, parsearlo para compatibilidad
                                            if (paso is String) {
                                              try {
                                                return parseMapString(paso);
                                              } catch (e) {
                                                printLog.e(
                                                    'Error parseando paso en pasosCadena: $e');
                                                return <String, dynamic>{};
                                              }
                                            } else {
                                              return Map<String, dynamic>.from(
                                                  paso);
                                            }
                                          }).toList()
                                        : null;

                                    return buildEvent(
                                      deviceGroup,
                                      eventoType,
                                      title,
                                      selectedDays,
                                      selectedAction,
                                      selectedTime,
                                      deviceDelays,
                                      deviceActions,
                                      condition,
                                      activadores,
                                      ejecutores,
                                      estadoAlerta,
                                      estadoTermometro,
                                      pasosCadena: pasosCadena,
                                      onDelete: () {
                                        setState(() {
                                          eventosCreados.removeAt(index);
                                          putEventos(
                                              currentUserEmail, eventosCreados);
                                          if (eventoType == 'grupo') {
                                            deleteEventoControlPorGrupos(
                                                currentUserEmail, title);
                                            todosLosDispositivos.removeWhere(
                                                (entry) => entry.key == title);
                                          } else if (eventoType ==
                                              'disparador') {
                                            String activador =
                                                activadores.first;

                                            String sortKey =
                                                '$currentUserEmail:$title';

                                            // Eliminar solo de este tipo específico de alerta
                                            removeEjecutoresFromDisparador(
                                                activador, sortKey);
                                          } else if (eventoType == 'horario') {
                                            deleteEventoControlPorHorarios(
                                                selectedTime,
                                                currentUserEmail,
                                                title);
                                          } else if (eventoType == 'cadena') {
                                            deleteEventoControlPorCadena(
                                                currentUserEmail, title);
                                            todosLosDispositivos.removeWhere(
                                                (entry) => entry.key == title);
                                          }
                                        });
                                      },
                                    );
                                  }(),
                                ),
                              );
                            }).toList(),
                          )
                        : Container(
                            padding: const EdgeInsets.all(40),
                            decoration: BoxDecoration(
                              color: color3.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: color3.withValues(alpha: 0.3),
                                width: 2,
                                style: BorderStyle.solid,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  HugeIcons.strokeRoundedFileNotFound,
                                  size: 48,
                                  color: color3.withValues(alpha: 0.6),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No hay eventos creados',
                                  style: GoogleFonts.poppins(
                                    color: color3,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Toca "Configurar evento" para crear tu primer evento',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.poppins(
                                    color: color3.withValues(alpha: 0.7),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
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
