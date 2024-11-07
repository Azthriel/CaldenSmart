import 'package:caldensmart/Global/stored_data.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:day_night_time_picker/day_night_time_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../master.dart';

//TODO: hay que realizar muchicimas mejoras, cambiar los nombres a las variables, hacer mas global muchas funciones y widgets, reconozco que es una mierda, pero una que se puede mejorar

class EscenasPage extends StatefulWidget {
  const EscenasPage({super.key});

  @override
  State<EscenasPage> createState() => EscenasPageState();
}

class EscenasPageState extends State<EscenasPage> {
  //*-Variables generales-*\\
// Estas variables se usan para manejar el estado general de la aplicación y las escenas creadas.
  bool showCard =
      false; // Indica si se debe mostrar una tarjeta con la información actual.
  int sceneIdCounter =
      0; // Contador para asignar un ID único a cada nueva escena creada.
  List<Map<String, dynamic>> escenasCreadas =
      []; // Lista que guarda todas las escenas creadas con sus detalles.
  bool isDeviceSelection =
      false; // Variable que indica si se está en el estado de selección de dispositivos.
//*-Variables generales-*\\

//*-Variables para Control Horario (CH)-*\\
// Estas variables manejan los estados y acciones específicas del módulo de Control Horario (CH).
  bool showControlHorarioCH =
      false; // Controla la visualización del menú de Control Horario.
  bool showDeviceListCH =
      false; // Indica si se debe mostrar la lista de dispositivos disponibles en CH.
  bool showActionChoiceCH =
      false; // Controla la visualización de la lista de acciones seleccionables en CH.
  bool showIoSelectionCH =
      false; // Indica si se debe mostrar la selección de entradas/salidas.
  String? selectedDeviceCH; // Almacena el dispositivo seleccionado en CH.
  String? selectedActionCH; // Almacena la acción seleccionada en CH.
  TimeOfDay?
      selectedTimeCH; // Almacena la hora seleccionada para ejecutar la acción en CH.
  List<String> tipoScenaCH =
      []; // Guarda los tipos de escenas disponibles para CH.
  Map<String, bool> tipoScenaSeleccionCH =
      {}; // Mapea qué tipos de escenas han sido seleccionadas en CH.

  bool showDaySelectionCH = false;
  Map<String, bool> selectedDaysCH = {
    'Lunes': false,
    'Martes': false,
    'Miércoles': false,
    'Jueves': false,
    'Viernes': false,
    'Sábado': false,
    'Domingo': false,
  };

//*-Variables para Control Horario (CH)-*\\

//*-Variables para Activación en Cadena (AC)-*\\
// Estas variables manejan los estados y acciones específicas del módulo de Activación en Cadena (AC).
  bool showActivacionEnCadena =
      false; // Controla si el menú de Activación en Cadena se debe mostrar.
  bool showDeviceOptionsAC =
      false; // Indica si se deben mostrar las opciones del dispositivo en AC.
  bool showActionChoiceAC =
      false; // Controla la visualización de las acciones disponibles en AC.
  bool showOutputSelectionAC =
      false; // Indica si se debe mostrar la selección de salidas.
  bool showIntervalSelectionAC =
      false; // Controla la visualización de la selección de intervalos entre acciones.
  bool showDeviceSelectionAC =
      false; // Indica si se está en el estado de selección de dispositivos para AC.
  bool showDeviceOptionsSimultaneousAC =
      false; // Indica si se deben mostrar las opciones para controlar dispositivos simultáneamente en AC.
  bool showTriggerOutputSelectionAC =
      false; // Controla la visualización de la selección de la salida que activa la cadena.
  bool showOutputTriggerSelectionAC =
      false; // Indica si se debe mostrar la selección de las salidas que serán activadas por la cadena.

  Map<String, TextEditingController> intervalControllers =
      {}; // Almacena los controladores de texto para los intervalos de tiempo personalizados por salida.
  Map<String, double> intervalTimes =
      {}; // Guarda los tiempos de intervalos específicos para cada salida.

  List<String> orderedOutputsSelectionAC =
      []; // Mantiene el orden de las salidas seleccionadas en AC.
  double intervalTimeAC = 1; // Intervalo de tiempo general para AC.
  TextEditingController intervalControllerAC =
      TextEditingController(); // Controlador de texto para el intervalo de tiempo en AC.

  Map<String, bool> outputsSelectionAC =
      {}; // Mapea qué salidas han sido seleccionadas en AC.
  Map<String, bool> dispositivosSimultaneosSeleccion = {
    // Mapea qué dispositivos han sido seleccionados para controlar simultáneamente.
    'Gas': false,
    'Radiador': false,
    'Eléctrico': false,
  };

  String? selectedDeviceAC; // Almacena el dispositivo seleccionado en AC.
  String? selectedActionAC; // Almacena la acción seleccionada en AC.
  String?
      selectedOutputTriggerAC; // Almacena la salida seleccionada que activa la cadena.
  String?
      selectedTriggerOutputAC; // Almacena la salida seleccionada que será activada por la cadena.
//*-Variables para Activación en Cadena (AC)-*\\

//*-Variables para gestión de dispositivos para apagar en AC-*\\
// Estas variables gestionan qué dispositivos se apagarán y sus estados de selección.
  List<String> dispositivosParaApagar =
      []; // Lista de dispositivos que se apagarán en una escena de AC.
  Map<String, bool> dispositivosParaApagarSeleccion =
      {}; // Mapea qué dispositivos han sido seleccionados para apagar en AC.
//*-Variables para gestión de dispositivos para apagar en AC-*\\

//*-Variables para dispositivos a controlar simultáneamente en AC-*\\
// Estas variables manejan los dispositivos que se controlarán simultáneamente en AC.
  List<String> devicesToControlAC =
      []; // Lista de dispositivos a controlar simultáneamente en AC.
  Map<String, bool> devicesToControlSelectionAC =
      {}; // Mapea qué dispositivos han sido seleccionados para controlar simultáneamente en AC.
//*-Variables para dispositivos a controlar simultáneamente en AC-*\\

  //*-Clave global para AnimatedList-*\\
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  //*-Clave global para AnimatedList-*\\

  // FUNCIONES \\

  //*-Función para guardar eventos-*\\
  Future<void> guardarEscenas() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> escenasJson = escenasCreadas.map((escena) {
      Map<String, dynamic> escenaToSave = Map.from(escena);
      if (escenaToSave['time'] != null && escenaToSave['time'] is TimeOfDay) {
        escenaToSave['time'] =
            '${escenaToSave['time'].hour}:${escenaToSave['time'].minute}';
      }
      return json.encode(escenaToSave);
    }).toList();

    printLog('Guardando escenas: $escenasJson'); // Debugging
    await prefs.setStringList('escenasCreadas', escenasJson);
  }
//*-Funcion para guardar eventos-*\\

//*-Funcion para convertir a string-*\\
  List<String> convertToStringList(List<dynamic> list) {
    return list.map((item) => item.toString()).toList();
  }
//*-Funcion para convertir a string-*\\

//*-Funcion para cargar eventos-*\\
  Future<void> cargarEscenas() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? escenasJson = prefs.getStringList('escenasCreadas');

    printLog('THE GAME $escenasJson');
    if (escenasJson != null) {
      escenasJson = convertToStringList(escenasJson);

      escenasCreadas = [];

      List<Map<String, dynamic>> tempEscenas = [];
      for (var escenaJson in escenasJson) {
        Map<String, dynamic> escena = json.decode(escenaJson);

        if (escena.containsKey('devices') &&
            escena['devices'] is List<dynamic>) {
          escena['devices'] = convertToStringList(escena['devices']);
        }

        if (escena.containsKey('salidasSeleccionadas') &&
            escena['salidasSeleccionadas'] is List<dynamic>) {
          escena['salidasSeleccionadas'] =
              convertToStringList(escena['salidasSeleccionadas']);
        }

        if (escena.containsKey('time') && escena['time'] is String) {
          List<String> timeParts = escena['time'].split(':');
          if (timeParts.length == 2) {
            int hour = int.parse(timeParts[0]);
            int minute = int.parse(timeParts[1]);
            escena['time'] = TimeOfDay(hour: hour, minute: minute);
          }
        }

        tempEscenas.add(escena);
      }

      if (tempEscenas.isNotEmpty) {
        sceneIdCounter = tempEscenas
                .map((e) => e['id'] as int)
                .reduce((a, b) => a > b ? a : b) +
            1;
      }

      setState(() {
        escenasCreadas = tempEscenas;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (int i = 0; i < escenasCreadas.length; i++) {
          _listKey.currentState?.insertItem(i);
        }
      });
    }
  }
  //*-Función para cargar eventos-*\\

  //*-Función para reiniciar las variables-*\\
  void resetConfigurations() {
    showCard = false;
    isDeviceSelection = false;

    showControlHorarioCH = false;
    showDeviceListCH = false;
    showActionChoiceCH = false;
    showIoSelectionCH = false;
    selectedDeviceCH = null;
    selectedActionCH = null;
    selectedTimeCH = null;
    tipoScenaCH.clear();
    tipoScenaSeleccionCH.clear();

    showActivacionEnCadena = false;
    showDeviceOptionsAC = false;
    showActionChoiceAC = false;
    showOutputSelectionAC = false;
    showIntervalSelectionAC = false;
    showDeviceSelectionAC = false;
    showDeviceOptionsSimultaneousAC = false;
    showOutputTriggerSelectionAC = false;
    showTriggerOutputSelectionAC = false;

    selectedDeviceAC = null;
    selectedActionAC = null;
    selectedTriggerOutputAC = null;
    outputsSelectionAC.clear();
    orderedOutputsSelectionAC.clear();
    intervalControllers.clear();
    intervalTimes.clear();

    dispositivosSimultaneosSeleccion = {
      'Gas': false,
      'Radiador': false,
      'Eléctrico': false,
    };
    dispositivosParaApagarSeleccion.clear();
    devicesToControlSelectionAC.clear();
    devicesToControlAC.clear();

    intervalControllerAC.clear();
    intervalTimeAC = 1;

    showDaySelectionCH = false;
    selectedDaysCH = {
      'Lunes': false,
      'Martes': false,
      'Miércoles': false,
      'Jueves': false,
      'Viernes': false,
      'Sábado': false,
      'Domingo': false,
    };
  }
  //*-Función para reiniciar las variables-*\\

  @override
  void initState() {
    super.initState();
    cargarEscenas();
  }

  @override
  void dispose() {
    intervalControllerAC.dispose();
    super.dispose();
  }

  //*-Función para agregar una nueva escena-*\\
  void crearEscena(Map<String, dynamic> newScene) {
    if (mounted) {
      setState(() {
        newScene['id'] = sceneIdCounter++;

        if (newScene['devices'] != null &&
            !newScene['devices'].contains(selectedDeviceAC)) {
          newScene['devices'].insert(0, selectedDeviceAC);
        }

        escenasCreadas.insert(0, newScene);
        _listKey.currentState?.insertItem(0);
      });
      guardarEscenas().then((_) {
        resetConfigurations();
      });
    }
  }

  //*-Función para agregar una nueva escena-*\\

  //*-Función para formatear la lista de salidas o dispositivos-*\\
  String formatearSalidas(List<String> salidas) {
    if (salidas.length == 1) {
      return salidas.first;
    } else {
      return '${salidas.sublist(0, salidas.length - 1).join(', ')} y ${salidas.last}';
    }
  }

  //*-Función para formatear la lista de salidas o dispositivos-*\\

  //*-Función para abrir el selector de tiempo-*\\
  void selectTime(BuildContext context) {
    Navigator.of(context).push(
      showPicker(
        context: context,
        value: selectedTimeCH != null
            ? Time(hour: selectedTimeCH!.hour, minute: selectedTimeCH!.minute)
            : Time(hour: TimeOfDay.now().hour, minute: TimeOfDay.now().minute),
        onChange: (time) {
          setState(() {
            selectedTimeCH = TimeOfDay(hour: time.hour, minute: time.minute);
            showDaySelectionCH = true; // Mostrar la selección de días
          });
        },
        backgroundColor: color3,
        accentColor: color0,
        okStyle: GoogleFonts.poppins(
          color: color0,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        cancelStyle: GoogleFonts.poppins(
          color: color0,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
  //*-Función para abrir el selector de tiempo-*\\

//*-Widget para seleccion de dias-*\\
  Widget buildDaySelectionCH() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(
                HugeIcons.strokeRoundedArrowLeft02,
                color: color0,
              ),
              onPressed: () {
                setState(() {
                  showDaySelectionCH =
                      false; // Regresar a la selección de horario
                });
              },
            ),
            Text(
              'Volver a seleccionar horario',
              style: GoogleFonts.poppins(
                color: color0,
                fontSize: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Selecciona los días de la semana para la alarma:',
          style: GoogleFonts.poppins(
            color: color0,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 10),
        ...selectedDaysCH.keys.map((day) {
          return CheckboxListTile(
            title: Text(
              day,
              style: GoogleFonts.poppins(color: color0),
            ),
            value: selectedDaysCH[day],
            activeColor: color6,
            onChanged: (bool? value) {
              setState(() {
                selectedDaysCH[day] = value!;
              });
            },
          );
        }),
        const SizedBox(height: 20),
        Align(
          alignment: Alignment.bottomRight,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: color1,
              foregroundColor: color3,
            ),
            onPressed: () {
              if (selectedDaysCH.containsValue(true)) {
                // Crear la escena solo si al menos un día está seleccionado
                crearEscena({
                  'device': selectedDeviceCH,
                  'time': selectedTimeCH,
                  'action': selectedActionCH,
                  'days': selectedDaysCH.keys
                      .where((day) => selectedDaysCH[day]!)
                      .toList(),
                  'tipo': 'Control horario',
                  'salidasSeleccionadas': tipoScenaSeleccionCH.keys
                      .where((key) => tipoScenaSeleccionCH[key]!)
                      .toList(),
                });

                // Reiniciar la configuración
                resetConfigurations();
              } else {
                showToast('Por favor, selecciona al menos un día.');
              }
            },
            child: const Text('Guardar'),
          ),
        ),
      ],
    );
  }

  //*-Widgets para construir el contenido de la tarjeta emergente-*\\
  Widget buildCardContent() {
    String contentKey;

    if (showActivacionEnCadena) {
      if (showTriggerOutputSelectionAC) {
        contentKey = 'triggerOutputSelectionAC';
      } else if (showActionChoiceAC) {
        contentKey = 'actionSelectionAC';
      } else if (showOutputSelectionAC) {
        contentKey = 'outputSelectionAC';
      } else if (showIntervalSelectionAC) {
        contentKey = 'intervalSelectionAC';
      } else if (showDeviceSelectionAC) {
        contentKey = 'deviceSelectionAC';
      } else if (showDeviceOptionsAC) {
        contentKey = 'activacionEnCadenaDeviceOptions';
      } else {
        contentKey = 'activacionEnCadena';
      }
    } else if (showControlHorarioCH) {
      if (showDaySelectionCH) {
        contentKey = 'daySelectionCH';
      } else if (showActionChoiceCH) {
        contentKey = 'actionSelectionCH';
      } else if (showIoSelectionCH) {
        contentKey = 'ioSelectionCH';
      } else {
        contentKey = 'deviceSelectionCH';
      }
    } else {
      contentKey = 'mainOptions';
    }

    return Column(
      key: ValueKey(contentKey),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main options (initial screen)
        if (contentKey == 'mainOptions') buildMainOptions(),
        // Control Horario (CH) widgets
        if (contentKey == 'deviceSelectionCH') buildDeviceSelectionCH(),
        if (contentKey == 'ioSelectionCH') buildIoSelectionCH(),
        if (contentKey == 'actionSelectionCH') buildActionSelectionCH(),
        if (contentKey == 'daySelectionCH')
          buildDaySelectionCH(), // New widget for day selection
        // Activación en Cadena (AC) widgets
        if (contentKey == 'activacionEnCadena') buildActivacionEnCadena(),
        if (contentKey == 'activacionEnCadenaDeviceOptions')
          buildCardDetector(),
        if (contentKey == 'triggerOutputSelectionAC')
          buildTriggerOutputSelectionAC(),
        if (contentKey == 'actionSelectionAC') buildActionSelectionAC(),
        if (contentKey == 'outputSelectionAC') buildOutputSelectionAC(),
        if (contentKey == 'intervalSelectionAC') buildIntervalSelectionAC(),
        if (contentKey == 'deviceSelectionAC') buildSimultaneousDeviceAC(),
      ],
    );
  }

  //*-Widgets para construir el contenido de la tarjeta emergente-*\\

  //*-Función para obtener el título de la escena-*\\
  String getCardTitle(Map<String, dynamic> escena) {
    if (escena['tipo'] != null) {
      return escena['tipo'];
    } else {
      return 'Escena personalizada';
    }
  }
  //*-Función para obtener el título de la escena-*\\

  //*-Widgets para las opciones principales-*\\
  Widget buildMainOptions() {
    return Column(
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
            showToast("Próximamente");
            // setState(() {
            //   showControlHorarioCH = true;
            //   isDeviceSelection = true;
            // });
          },
        ),
        ListTile(
          leading: const Icon(Icons.devices, color: color0),
          title: Text('Mis dispositivos',
              style: GoogleFonts.poppins(color: color0)),
          onTap: () {
            showToast("Próximamente");
            // setState(() {
            //   showActivacionEnCadena = true;
            //   showCard = true;
            // });
          },
        ),
        // Opciones futuras con toast
        ListTile(
          leading: const Icon(Icons.lightbulb, color: color0),
          title: Text('Amanecer/Atardecer',
              style: GoogleFonts.poppins(color: color0)),
          onTap: () {
            showToast("Próximamente");
          },
        ),
        ListTile(
          leading: const Icon(Icons.air, color: color0),
          title: Text('Viento', style: GoogleFonts.poppins(color: color0)),
          onTap: () {
            showToast("Próximamente");
          },
        ),
        ListTile(
          leading: const Icon(Icons.cloud, color: color0),
          title: Text('Lluvia', style: GoogleFonts.poppins(color: color0)),
          onTap: () {
            showToast("Próximamente");
          },
        ),
      ],
    );
  }
  //*-Widgets para las opciones principales-*\\

  //*-Widgets para Control Horario (CH)-*\\

  //*-Construye la interfaz para seleccionar un dispositivo en Control Horario (CH)-*\\
  Widget buildDeviceSelectionCH() {
    final deviceList = previusConnections
        .where((device) => !device.toLowerCase().contains('detector'))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(
                HugeIcons.strokeRoundedArrowLeft02,
                color: color0,
              ),
              onPressed: () {
                setState(() {
                  showControlHorarioCH = false;
                  showDeviceListCH = false;
                  selectedDeviceCH = null;
                  selectedActionCH = null;
                  showActionChoiceCH = false;
                  showIoSelectionCH = false;
                  tipoScenaCH.clear();
                  tipoScenaSeleccionCH.clear();
                });
              },
            ),
            Text(
              'Volver a la lista',
              style: GoogleFonts.poppins(
                color: color0,
                fontSize: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Selecciona un equipo para gestionar su horario:',
          style: GoogleFonts.poppins(
            color: color0,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 10),
        ListTile(
          leading: const Icon(Icons.settings_remote, color: color0),
          title: Text(
            selectedDeviceCH == null
                ? 'Seleccionar equipo'
                : (nicknamesMap[selectedDeviceCH] ?? selectedDeviceCH!),
            style: GoogleFonts.poppins(color: color0),
          ),
          onTap: () {
            setState(() {
              showDeviceListCH = !showDeviceListCH;
            });
          },
          trailing: Icon(
            showDeviceListCH ? Icons.arrow_drop_up : Icons.arrow_drop_down,
            color: color0,
          ),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return FadeTransition(
              opacity: animation,
              child: SizeTransition(
                sizeFactor: animation,
                axisAlignment: -1.0,
                child: child,
              ),
            );
          },
          child: showDeviceListCH
              ? deviceList.isEmpty
                  ? Padding(
                      key: const ValueKey('noDevices'),
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        'No se encuentran dispositivos vinculados',
                        style: GoogleFonts.poppins(
                          color: color0,
                          fontSize: 16,
                        ),
                      ),
                    )
                  : Column(
                      key: const ValueKey('deviceList'),
                      children: deviceList.map((device) {
                        return ListTile(
                          title: Text(
                            nicknamesMap[device] ?? device,
                            style: GoogleFonts.poppins(
                              color: color0,
                            ),
                          ),
                          onTap: () {
                            setState(() {
                              selectedDeviceCH = device;
                              showDeviceListCH = false;
                              if (device.toLowerCase().contains('domotica')) {
                                showIoSelectionCH = true;

                                String equipo = command(device);
                                Map<String, dynamic> deviceDATA = globalDATA[
                                        '$equipo/${extractSerialNumber(device)}'] ??
                                    {};

                                String io =
                                    '${deviceDATA['io0']}/${deviceDATA['io1']}/${deviceDATA['io2']}/${deviceDATA['io3']}';
                                var partes = io.split('/');
                                tipoScenaCH = [];
                                tipoScenaSeleccionCH = {};
                                for (int i = 0; i < partes.length; i++) {
                                  var deviceParts = partes[i].split(':');
                                  if (deviceParts[0] == '0') {
                                    String tipo = 'Salida$i';
                                    tipoScenaCH.add(tipo);
                                    tipoScenaSeleccionCH[tipo] = false;
                                  }
                                }
                              } else {
                                showActionChoiceCH = true;
                              }
                            });
                          },
                          trailing: selectedDeviceCH == device
                              ? const Icon(Icons.check, color: color0)
                              : null,
                        );
                      }).toList(),
                    )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  //*-Construye la interfaz para seleccionar un dispositivo en Control Horario (CH)-*\\

  //*Widget para seleccionar las salidas de un domotica-*\\
  Widget buildIoSelectionCH() {
    return Column(
      key: const ValueKey('ioSelectionCH'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(
                HugeIcons.strokeRoundedArrowLeft02,
                color: color0,
              ),
              onPressed: () {
                setState(() {
                  showIoSelectionCH = false;
                  tipoScenaCH.clear();
                  tipoScenaSeleccionCH.clear();
                });
              },
            ),
            Text(
              'Volver a seleccionar',
              style: GoogleFonts.poppins(
                color: color0,
                fontSize: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Selecciona las salidas para accionar:',
          style: GoogleFonts.poppins(
            color: color0,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 10),
        ...tipoScenaCH.map((tipo) {
          return CheckboxListTile(
            title: Text(
              tipo,
              style: GoogleFonts.poppins(color: color0),
            ),
            value: tipoScenaSeleccionCH[tipo],
            activeColor: color6,
            onChanged: (bool? value) {
              setState(() {
                tipoScenaSeleccionCH[tipo] = value!;
              });
            },
          );
        }),
        const SizedBox(height: 20),
        Align(
          alignment: Alignment.bottomRight,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: color1,
              foregroundColor: color3,
            ),
            onPressed: () {
              if (tipoScenaSeleccionCH.containsValue(true)) {
                setState(() {
                  showIoSelectionCH = false;
                  showActionChoiceCH = true;
                });
              } else {
                showToast('Por favor, selecciona al menos una opción.');
              }
            },
            child: const Text('Continuar'),
          ),
        ),
      ],
    );
  }
  //*Widget para seleccionar las salidas de un domotica-*\\

  //*Widget para seleccionar la accion de prender o apagar-*\\
  Widget buildActionSelectionCH() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(
                HugeIcons.strokeRoundedArrowLeft02,
                color: color0,
              ),
              onPressed: () {
                setState(() {
                  // Verificar si ya se ha seleccionado una salida
                  if (tipoScenaSeleccionCH.containsValue(true)) {
                    // Si hay salidas seleccionadas, volver a la selección de salidas
                    showActionChoiceCH = false;
                    showIoSelectionCH = true;
                  } else {
                    // Si no, volver a la selección de dispositivo
                    showActionChoiceCH = false;
                    selectedActionCH = null;
                    showDeviceListCH = true;
                  }
                });
              },
            ),
            Text(
              'Volver a seleccionar salida',
              style: GoogleFonts.poppins(
                color: color0,
                fontSize: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Selecciona una acción:',
          style: GoogleFonts.poppins(
            color: color0,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 10),
        Column(
          children: [
            ListTile(
              title: Text('Apagar', style: GoogleFonts.poppins(color: color0)),
              leading: Radio<String>(
                value: 'apagará',
                groupValue: selectedActionCH,
                activeColor: color6,
                onChanged: (value) {
                  setState(() {
                    selectedActionCH = value;
                  });
                },
              ),
              onTap: () {
                setState(() {
                  selectedActionCH = 'apagará';
                });
              },
            ),
            ListTile(
              title:
                  Text('Encender', style: GoogleFonts.poppins(color: color0)),
              leading: Radio<String>(
                value: 'prenderá',
                groupValue: selectedActionCH,
                activeColor: color6,
                onChanged: (value) {
                  setState(() {
                    selectedActionCH = value;
                  });
                },
              ),
              onTap: () {
                setState(() {
                  selectedActionCH = 'prenderá';
                });
              },
            ),
          ],
        ),
        if (selectedActionCH != null)
          Align(
            alignment: Alignment.bottomRight,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: color1,
                foregroundColor: color3,
              ),
              onPressed: () {
                selectTime(context);
              },
              child: const Text('Continuar'),
            ),
          ),
      ],
    );
  }
  //*Widget para seleccionar la accion de prender o apagar-*\\

  //*-Widgets para Control Horario (CH)-*\\

  //*-Widgets para Activación en Cadena (AC)-*\\

  //*-Construye la interfaz para seleccionar un dispositivo en Activación en cadena (AC)-*\\
  Widget buildActivacionEnCadena() {
    final deviceList = previusConnections.where((device) {
      bool isDetector = device.toLowerCase().contains('detector');
      bool isInUse = escenasCreadas.any((escena) =>
          escena['device'] == device &&
          escena['tipo'] == 'Activación en cadena');
      return !(isDetector && isInUse);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(
                HugeIcons.strokeRoundedArrowLeft02,
                color: color0,
              ),
              onPressed: () {
                setState(() {
                  showActivacionEnCadena = false;
                  selectedDeviceAC = null;
                });
              },
            ),
            Text(
              'Volver a la lista',
              style: GoogleFonts.poppins(
                color: color0,
                fontSize: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Agrega dispositivos y configura su activación en cadena',
          style: GoogleFonts.poppins(
            color: color0,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 20),
        ListTile(
          leading: const Icon(Icons.settings_remote, color: color0),
          title: Text(
            selectedDeviceAC == null ? 'Seleccionar equipo' : selectedDeviceAC!,
            style: GoogleFonts.poppins(color: color0),
          ),
          onTap: () {
            setState(() {
              showDeviceListCH = !showDeviceListCH;
            });
          },
          trailing: Icon(
            showDeviceListCH ? Icons.arrow_drop_up : Icons.arrow_drop_down,
            color: color0,
          ),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return FadeTransition(
              opacity: animation,
              child: SizeTransition(
                sizeFactor: animation,
                axisAlignment: -1.0,
                child: child,
              ),
            );
          },
          child: showDeviceListCH
              ? deviceList.isEmpty
                  ? Padding(
                      key: const ValueKey('noDevices'),
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        'No se encuentran dispositivos vinculados',
                        style: GoogleFonts.poppins(
                          color: color0,
                          fontSize: 16,
                        ),
                      ),
                    )
                  : Column(
                      key: const ValueKey('deviceList'),
                      children: deviceList.map((device) {
                        return ListTile(
                          title: Text(
                            nicknamesMap[device] ?? device,
                            style: GoogleFonts.poppins(
                              color: color0,
                            ),
                          ),
                          onTap: () {
                            setState(() {
                              selectedDeviceAC = device;
                              showDeviceListCH = false;
                              isDeviceSelection = true;

                              if (device.toLowerCase().contains('detector')) {
                                // Si el dispositivo es un detector
                                dispositivosParaApagar = previusConnections
                                    .where((d) =>
                                        !d.toLowerCase().contains('detector'))
                                    .toList();

                                dispositivosParaApagarSeleccion = {
                                  for (var d in dispositivosParaApagar)
                                    d: false,
                                };

                                showDeviceOptionsAC = true;
                              } else if (device
                                  .toLowerCase()
                                  .contains('domotica')) {
                                // Si es un dispositivo domótico
                                showTriggerOutputSelectionAC =
                                    true; // Nuevo paso
                              } else if (device.toLowerCase().contains('gas') ||
                                  device.toLowerCase().contains('radiador') ||
                                  device.toLowerCase().contains('eléctrico')) {
                                // Si es gas, radiador o eléctrico
                                showActionChoiceAC = true;
                              } else {
                                // Manejar otros dispositivos si es necesario
                              }
                            });
                          },
                          trailing: selectedDeviceAC == device
                              ? const Icon(Icons.check, color: color0)
                              : null,
                        );
                      }).toList(),
                    )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
  //*-Construye la interfaz para seleccionar un dispositivo en Activación en cadena (AC)-*\\

  //*Widget para seleccionar la accion de prender o apagar-*\\
  Widget buildActionSelectionAC() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(
                HugeIcons.strokeRoundedArrowLeft02,
                color: color0,
              ),
              onPressed: () {
                setState(() {
                  if (selectedDeviceAC != null &&
                      (selectedDeviceAC!.toLowerCase().contains('gas') ||
                          selectedDeviceAC!
                              .toLowerCase()
                              .contains('radiador') ||
                          selectedDeviceAC!
                              .toLowerCase()
                              .contains('eléctrico'))) {
                    showActionChoiceAC = false;
                    showDeviceSelectionAC = false;
                    selectedDeviceAC = null;
                    showActivacionEnCadena = true;
                  } else {
                    showActionChoiceAC = false;
                    showTriggerOutputSelectionAC = true;
                  }
                });
              },
            ),
            Text(
              'Volver a seleccionar',
              style: GoogleFonts.poppins(
                color: color0,
                fontSize: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Selecciona una acción:',
          style: GoogleFonts.poppins(
            color: color0,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 10),
        Column(
          children: [
            ListTile(
              title: Text('Apagar', style: GoogleFonts.poppins(color: color0)),
              leading: Radio<String>(
                value: 'apagará',
                groupValue: selectedActionAC,
                activeColor: color6,
                onChanged: (value) {
                  setState(() {
                    selectedActionAC = value;
                  });
                },
              ),
              onTap: () {
                setState(() {
                  selectedActionAC = 'apagará';
                });
              },
            ),
            ListTile(
              title:
                  Text('Encender', style: GoogleFonts.poppins(color: color0)),
              leading: Radio<String>(
                value: 'prenderá',
                groupValue: selectedActionAC,
                activeColor: color6,
                onChanged: (value) {
                  setState(() {
                    selectedActionAC = value;
                  });
                },
              ),
              onTap: () {
                setState(() {
                  selectedActionAC = 'prenderá';
                });
              },
            ),
          ],
        ),
        if (selectedActionAC != null)
          Align(
            alignment: Alignment.bottomRight,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: color1,
                foregroundColor: color3,
              ),
              onPressed: () {
                setState(() {
                  showActionChoiceAC = false;
                  if (selectedDeviceAC != null &&
                      (selectedDeviceAC!.toLowerCase().contains('gas') ||
                          selectedDeviceAC!
                              .toLowerCase()
                              .contains('radiador') ||
                          selectedDeviceAC!
                              .toLowerCase()
                              .contains('eléctrico'))) {
                    showDeviceSelectionAC = true;
                    devicesToControlAC = previusConnections
                        .where((d) =>
                            d.toLowerCase().contains('gas') ||
                            d.toLowerCase().contains('radiador') ||
                            d.toLowerCase().contains('eléctrico'))
                        .toList();
                    devicesToControlSelectionAC = {
                      for (var d in devicesToControlAC) d: false,
                    };
                  } else {
                    showOutputSelectionAC = true;
                  }
                });
              },
              child: const Text('Continuar'),
            ),
          ),
      ],
    );
  }
  //*-Widget para seleccionar la accion de prender o apagar-*\\

  //*-Construye la interfaz para seleccionar dispositivos que serán controlados simultáneamente en Activación en Cadena (AC)-*\\
  Widget buildSimultaneousDeviceAC() {
    devicesToControlAC = previusConnections
        .where((d) =>
            (d.toLowerCase().contains('gas') ||
                d.toLowerCase().contains('radiador') ||
                d.toLowerCase().contains('eléctrico')) &&
            d != selectedDeviceAC)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(
                HugeIcons.strokeRoundedArrowLeft02,
                color: color0,
              ),
              onPressed: () {
                setState(() {
                  showDeviceSelectionAC = false;
                  devicesToControlSelectionAC.clear();
                  showActionChoiceAC = true;
                });
              },
            ),
            Text(
              'Volver a seleccionar acción',
              style: GoogleFonts.poppins(
                color: color0,
                fontSize: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Selecciona los equipos que deseas ${selectedActionAC ?? ''} en simultáneo:',
          style: GoogleFonts.poppins(
            color: color0,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 10),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return FadeTransition(
              opacity: animation,
              child: SizeTransition(
                sizeFactor: animation,
                axisAlignment: -1.0,
                child: child,
              ),
            );
          },
          child: devicesToControlAC.isEmpty
              ? Padding(
                  key: const ValueKey('noMoreDevices'),
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    'No se encontraron más dispositivos para accionar',
                    style: GoogleFonts.poppins(
                      color: color0,
                      fontSize: 16,
                    ),
                  ),
                )
              : Column(
                  key: const ValueKey('deviceList'),
                  children: devicesToControlAC.map((device) {
                    return CheckboxListTile(
                      title: Text(
                        nicknamesMap[device] ?? device,
                        style: GoogleFonts.poppins(color: color0),
                      ),
                      value: devicesToControlSelectionAC[device],
                      activeColor: color6,
                      onChanged: (bool? value) {
                        setState(() {
                          devicesToControlSelectionAC[device] = value!;
                        });
                      },
                    );
                  }).toList(),
                ),
        ),
        const SizedBox(height: 20),
        Align(
          alignment: Alignment.bottomRight,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: color1,
              foregroundColor: color3,
            ),
            onPressed: () {
              List<String> selectedDevices = devicesToControlSelectionAC.entries
                  .where((entry) => entry.value)
                  .map((entry) => entry.key)
                  .toList();

              if (selectedDevices.isNotEmpty) {
                crearEscena({
                  'device': selectedDeviceAC,
                  'time': null,
                  'action': selectedActionAC,
                  'devices': selectedDevices,
                  'tipo': 'Activación en cadena',
                });

                setState(() {
                  showCard = false;
                  selectedDeviceAC = null;
                  selectedActionAC = null;
                  devicesToControlSelectionAC.clear();
                  showDeviceSelectionAC = false;
                });
              } else {
                showToast('Por favor, selecciona al menos un dispositivo.');
              }
            },
            child: const Text('Guardar'),
          ),
        ),
      ],
    );
  }

  //*-Construye la interfaz para seleccionar dispositivos que serán controlados simultáneamente en Activación en Cadena (AC)-*\\

//*-Muestra la interfaz para seleccionar y ordenar las salidas de un dispositivo en AC-*\\
  Widget buildOutputSelectionAC() {
    return Column(
      key: const ValueKey('outputSelectionAC'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(
                HugeIcons.strokeRoundedArrowLeft02,
                color: color0,
              ),
              onPressed: () {
                setState(() {
                  outputsSelectionAC.updateAll((key, value) => false);
                  orderedOutputsSelectionAC.clear();

                  showOutputSelectionAC = false;
                  showActionChoiceAC = true;
                });
              },
            ),
            Text(
              'Selecciona las salidas:',
              style: GoogleFonts.poppins(
                color: color0,
                fontSize: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Selecciona el orden de las salidas:',
          style: GoogleFonts.poppins(
            color: color0,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 10),
        ...outputsSelectionAC.keys.map((outputName) {
          int order = orderedOutputsSelectionAC.indexOf(outputName) + 1;

          return CheckboxListTile(
            title: Row(
              children: [
                Text(
                  outputName,
                  style: GoogleFonts.poppins(color: color0),
                ),
                if (outputsSelectionAC[outputName] == true)
                  Text(
                    ' $order',
                    style: GoogleFonts.poppins(
                      color: color6,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
            value: outputsSelectionAC[outputName],
            activeColor: color6,
            onChanged: (bool? value) {
              setState(() {
                outputsSelectionAC[outputName] = value!;

                if (value) {
                  orderedOutputsSelectionAC.add(outputName);
                } else {
                  orderedOutputsSelectionAC.remove(outputName);
                }

                outputsSelectionAC[outputName] = value;
              });
            },
          );
        }),
        const SizedBox(height: 20),
        Align(
          alignment: Alignment.bottomRight,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: color1,
              foregroundColor: color3,
            ),
            onPressed: () {
              if (outputsSelectionAC.containsValue(true)) {
                setState(() {
                  showOutputSelectionAC = false;
                  showIntervalSelectionAC = true;
                });
              } else {
                showToast('Por favor, selecciona al menos una opción.');
              }
            },
            child: const Text('Continuar'),
          ),
        ),
      ],
    );
  }
//*-Muestra la interfaz para seleccionar y ordenar las salidas de un dispositivo en AC-*\\

//*-Construye la interfaz para configurar los intervalos de tiempo para las salidas seleccionadas en AC-*\\
  Widget buildIntervalSelectionAC() {
    List<String> intervalOrder = orderedOutputsSelectionAC
        .where((output) => outputsSelectionAC[output] == true)
        .toList();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(
                  HugeIcons.strokeRoundedArrowLeft02,
                  color: color0,
                ),
                onPressed: () {
                  setState(() {
                    showIntervalSelectionAC = false;
                    showOutputSelectionAC = true;
                    intervalControllers.clear();
                    intervalTimes.clear();
                  });
                },
              ),
              Text(
                'Volver a seleccionar salida',
                style: GoogleFonts.poppins(
                  color: color0,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Configura el intervalo para cada salida:',
            style: GoogleFonts.poppins(
              color: color0,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.4,
            ),
            child: ListView(
              shrinkWrap: true,
              children: intervalOrder.map((salida) {
                // Crear un controlador si no existe para la salida
                if (!intervalControllers.containsKey(salida)) {
                  intervalControllers[salida] = TextEditingController(
                      text: intervalTimes[salida]?.toString() ?? '1');
                  intervalTimes[salida] = intervalTimes[salida] ?? 1.0;
                }

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 3),
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  color: color1,
                  child: Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Intervalo para $salida:',
                          style: GoogleFonts.poppins(
                            color: color3,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline,
                                  color: color3),
                              onPressed: () {
                                setState(() {
                                  int currentValue =
                                      intervalTimes[salida]!.toInt();
                                  if (currentValue > 1) {
                                    intervalTimes[salida] = currentValue - 1;
                                    intervalControllers[salida]?.text =
                                        intervalTimes[salida]!
                                            .toInt()
                                            .toString();
                                  }
                                });
                              },
                            ),
                            Expanded(
                                child: TextField(
                              controller: intervalControllers[salida],
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                color: color0,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                              cursorColor: color0,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: color3,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                  horizontal: 10,
                                ),
                                suffixText: 'seg',
                                suffixStyle: GoogleFonts.poppins(
                                  color: color0,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              selectionControls:
                                  MaterialTextSelectionControls(),
                              onChanged: (value) {
                                String cleanedValue =
                                    value.replaceAll(RegExp(r'[^0-9]'), '');
                                int? parsedValue = int.tryParse(cleanedValue);

                                if (parsedValue != null && parsedValue > 3600) {
                                  parsedValue = 3600;
                                }

                                setState(() {
                                  if (parsedValue != null && parsedValue > 0) {
                                    intervalTimes[salida] =
                                        parsedValue.toDouble();
                                    intervalControllers[salida]?.text =
                                        "$parsedValue";
                                  }
                                });

                                intervalControllers[salida]?.selection =
                                    TextSelection.fromPosition(
                                  TextPosition(
                                      offset: intervalControllers[salida]!
                                          .text
                                          .length),
                                );
                              },
                              onSubmitted: (value) {
                                String cleanedValue =
                                    value.replaceAll(RegExp(r'[^0-9]'), '');
                                int? parsedValue = int.tryParse(cleanedValue);

                                setState(() {
                                  if (parsedValue == null || parsedValue <= 0) {
                                    intervalControllers[salida]?.text = "1";
                                    intervalTimes[salida] = 1.0;
                                  } else if (parsedValue > 3600) {
                                    intervalControllers[salida]?.text = "3600";
                                    intervalTimes[salida] = 3600.0;
                                  } else {
                                    intervalTimes[salida] =
                                        parsedValue.toDouble();
                                    intervalControllers[salida]?.text =
                                        "$parsedValue";
                                  }
                                });
                              },
                            )),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline,
                                  color: color3),
                              onPressed: () {
                                setState(() {
                                  int currentValue =
                                      intervalTimes[salida]!.toInt();
                                  if (currentValue < 3600) {
                                    intervalTimes[salida] = currentValue + 1;
                                    intervalControllers[salida]?.text =
                                        intervalTimes[salida]!
                                            .toInt()
                                            .toString();
                                  }
                                });
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Usa los botones o el cuadro para ajustar el intervalo.',
                          style: GoogleFonts.poppins(
                            color: color3,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.bottomRight,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: color1,
                foregroundColor: color3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              onPressed: () {
                bool allValid = true;

                intervalControllers.forEach((salida, controller) {
                  final input =
                      controller.text.trim().replaceAll(RegExp(r'[^0-9]'), '');
                  final parsedValue = int.tryParse(input);

                  if (input.isEmpty ||
                      parsedValue == null ||
                      parsedValue <= 0) {
                    allValid = false;
                  } else {
                    intervalTimes[salida] = parsedValue.toDouble();
                  }
                });

                if (allValid) {
                  List<String> selectedOutputs = outputsSelectionAC.entries
                      .where((entry) => entry.value)
                      .map((entry) => entry.key)
                      .toList();

                  crearEscena({
                    'device': selectedDeviceAC,
                    'time': null,
                    'action': selectedActionAC,
                    'outputs': selectedOutputs,
                    'intervals': Map<String, double>.from(intervalTimes),
                    'tipo': 'Activación en cadena',
                    'accionador': selectedTriggerOutputAC,
                  });

                  setState(() {
                    showCard = false;
                    selectedDeviceAC = null;
                    selectedActionAC = null;
                    outputsSelectionAC.clear();
                    intervalControllers.clear();
                    intervalTimes.clear();
                    showIntervalSelectionAC = false;
                  });
                } else {
                  showToast(
                      'Por favor, ingresa un número válido de segundos para todas las salidas.');
                }
              },
              icon: const Icon(Icons.save, color: color3),
              label: Text(
                'Guardar',
                style: GoogleFonts.poppins(
                  color: color3,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
//*-Construye la interfaz para configurar los intervalos de tiempo para las salidas seleccionadas en AC-*\\

//*-Construye la interfaz para seleccionar dispositivos que serán apagados al activarse un detector.-*\\
  //*-Construye la interfaz para seleccionar dispositivos que serán apagados al activarse un detector.-*\\
  Widget buildCardDetector() {
    // Filtrar dispositivos que no sean de tipo domotica
    final dispositivosFiltrados = dispositivosParaApagar
        .where((dispositivo) => !dispositivo.toLowerCase().contains('domotica'))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(
                HugeIcons.strokeRoundedArrowLeft02,
                color: color0,
              ),
              onPressed: () {
                setState(() {
                  showDeviceOptionsAC = false;
                  selectedDeviceAC = null;
                  isDeviceSelection = false;
                });
              },
            ),
            Text(
              'Volver a la lista',
              style: GoogleFonts.poppins(
                color: color0,
                fontSize: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Selecciona los dispositivos que quieras apagar cuando se active el detector:',
          style: GoogleFonts.poppins(
            color: color0,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 10),
        // Iterar sobre dispositivos filtrados
        ...dispositivosFiltrados.map((dispositivo) {
          return CheckboxListTile(
            title: Text(
              nicknamesMap[dispositivo] ?? dispositivo,
              style: GoogleFonts.poppins(color: color0),
            ),
            value: dispositivosParaApagarSeleccion[dispositivo],
            activeColor: color1,
            onChanged: (bool? value) {
              setState(() {
                dispositivosParaApagarSeleccion[dispositivo] = value!;
              });
            },
          );
        }),
        const SizedBox(height: 20),
        Align(
          alignment: Alignment.bottomRight,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: color1,
              foregroundColor: color3,
            ),
            onPressed: () {
              // Crear la escena
              List<String> dispositivosSeleccionados =
                  dispositivosParaApagarSeleccion.entries
                      .where((entry) => entry.value)
                      .map((entry) => entry.key)
                      .toList();

              printLog(
                  'Si suena $selectedDeviceAC se apaga: $dispositivosSeleccionados');

              detectorOff
                  .addAll({selectedDeviceAC!: dispositivosSeleccionados});
              saveDetectorOff(detectorOff);

              crearEscena({
                'device': selectedDeviceAC,
                'time': null,
                'action': 'apagará',
                'salidasSeleccionadas': dispositivosSeleccionados,
                'tipo': 'Activación en cadena',
              });

              setState(() {
                showCard = false;
                selectedDeviceAC = null;
                dispositivosParaApagarSeleccion.clear();
                showDeviceOptionsAC = false;
              });
            },
            child: const Text('Guardar'),
          ),
        ),
      ],
    );
  }
//*-Construye la interfaz para seleccionar dispositivos que serán apagados al activarse un detector.-*\\

//*-Construye la interfaz para seleccionar dispositivos que serán apagados al activarse un detector-*\\

//*-Muestra la interfaz para seleccionar la salida específica de un dispositivo que activará la cadena en AC-*\\
  Widget buildOutputTriggerSelectionAC() {
    String equipo = command(selectedDeviceAC!);
    Map<String, dynamic> deviceDATA =
        globalDATA['$equipo/${extractSerialNumber(selectedDeviceAC!)}'] ?? {};

    String io =
        '${deviceDATA['io0']}/${deviceDATA['io1']}/${deviceDATA['io2']}/${deviceDATA['io3']}';
    var partes = io.split('/');
    List<String> availableOutputs = [];

    for (int i = 0; i < partes.length; i++) {
      var deviceParts = partes[i].split(':');
      if (deviceParts[0] == '0') {
        String outputName = 'Salida$i';
        availableOutputs.add(outputName);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(
                HugeIcons.strokeRoundedArrowLeft02,
                color: color0,
              ),
              onPressed: () {
                setState(() {
                  showOutputTriggerSelectionAC = false;
                  showDeviceOptionsAC = true;
                  selectedOutputTriggerAC = null;
                });
              },
            ),
            Text(
              'Volver a seleccionar',
              style: GoogleFonts.poppins(
                color: color0,
                fontSize: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Selecciona la salida que activará la cadena:',
          style: GoogleFonts.poppins(
            color: color0,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 10),
        ...availableOutputs.map((output) {
          return RadioListTile<String>(
            title: Text(
              output,
              style: GoogleFonts.poppins(color: color0),
            ),
            value: output,
            groupValue: selectedOutputTriggerAC,
            activeColor: color6,
            onChanged: (value) {
              setState(() {
                selectedOutputTriggerAC = value;
              });
            },
          );
        }),
        const SizedBox(height: 20),
        Align(
          alignment: Alignment.bottomRight,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: color1,
              foregroundColor: color3,
            ),
            onPressed: () {
              if (selectedOutputTriggerAC != null) {
                setState(() {
                  showOutputTriggerSelectionAC = false;
                  showActionChoiceAC = true;
                });
              } else {
                showToast(
                    'Por favor, selecciona una salida para activar la cadena.');
              }
            },
            child: const Text('Continuar'),
          ),
        ),
      ],
    );
  }
//*-Muestra la interfaz para seleccionar la salida específica de un dispositivo que activará la cadena en AC-*\\

//*-Construye la interfaz para seleccionar la salida que actuará como accionador de la cadena en AC-*\\
  Widget buildTriggerOutputSelectionAC() {
    String equipo = command(selectedDeviceAC!);
    Map<String, dynamic> deviceDATA =
        globalDATA['$equipo/${extractSerialNumber(selectedDeviceAC!)}'] ?? {};

    String io =
        '${deviceDATA['io0']}/${deviceDATA['io1']}/${deviceDATA['io2']}/${deviceDATA['io3']}';
    var partes = io.split('/');
    List<String> availableOutputs = [];

    for (int i = 0; i < partes.length; i++) {
      var deviceParts = partes[i].split(':');
      if (deviceParts[0] == '0') {
        String outputName = 'Salida$i';
        availableOutputs.add(outputName);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(
                HugeIcons.strokeRoundedArrowLeft02,
                color: color0,
              ),
              onPressed: () {
                setState(() {
                  showTriggerOutputSelectionAC = false;
                  selectedDeviceAC = null;
                });
              },
            ),
            Text(
              'Volver a seleccionar',
              style: GoogleFonts.poppins(
                color: color0,
                fontSize: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Selecciona la salida que actuará como accionador de la cadena:',
          style: GoogleFonts.poppins(
            color: color0,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 10),
        ...availableOutputs.map((output) {
          return RadioListTile<String>(
            title: Text(
              output,
              style: GoogleFonts.poppins(color: color0),
            ),
            value: output,
            groupValue: selectedTriggerOutputAC,
            activeColor: color6,
            onChanged: (value) {
              setState(() {
                selectedTriggerOutputAC = value;
              });
            },
          );
        }),
        const SizedBox(height: 20),
        Align(
          alignment: Alignment.bottomRight,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: color1,
              foregroundColor: color3,
            ),
            onPressed: () {
              if (selectedTriggerOutputAC != null) {
                setState(() {
                  showTriggerOutputSelectionAC = false;
                  showActionChoiceAC = true;
                  outputsSelectionAC = {};
                  intervalTimes = {};
                  intervalControllers = {};

                  String equipo = command(selectedDeviceAC!);
                  Map<String, dynamic> deviceDATA = globalDATA[
                          '$equipo/${extractSerialNumber(selectedDeviceAC!)}'] ??
                      {};

                  String io =
                      '${deviceDATA['io0']}/${deviceDATA['io1']}/${deviceDATA['io2']}/${deviceDATA['io3']}';
                  var partes = io.split('/');
                  List<String> accionableOutputs = [];

                  for (int i = 0; i < partes.length; i++) {
                    var deviceParts = partes[i].split(':');
                    if (deviceParts[0] == '0') {
                      String outputName = 'Salida$i';
                      if (outputName != selectedTriggerOutputAC) {
                        accionableOutputs.add(outputName);
                        outputsSelectionAC[outputName] = false;
                      }
                    }
                  }
                });
              } else {
                showToast(
                    'Por favor, selecciona una salida para actuar como accionador.');
              }
            },
            child: const Text('Continuar'),
          ),
        ),
      ],
    );
  }
  //*-Construye la interfaz para seleccionar la salida que actuará como accionador de la cadena en AC-*\\

  //*-Widgets para Activación en Cadena (AC)-*\\

  //*-Construcción de la descripción de escena-*\\
  String buildSceneDescription(Map<String, dynamic>? escena) {
    if (escena == null) {
      return 'Escena no válida.';
    }

    String accion = escena['action'] == 'apagará' ? 'apague' : 'prenda';

    List<String>? salidasSeleccionadas =
        escena['salidasSeleccionadas']?.cast<String>();
    List<String>? outputs = escena['outputs']?.cast<String>();
    Map<String, double>? intervals =
        escena['intervals']?.cast<String, double>();
    List<String>? diasSeleccionados = escena['days']?.cast<String>();
    String dispositivo = nicknamesMap[escena['device']] ??
        escena['device'] ??
        'dispositivo desconocido';

    if (escena['tipo'] == 'Control horario') {
      String dias = diasSeleccionados != null && diasSeleccionados.isNotEmpty
          ? (diasSeleccionados.length > 1
              ? '${diasSeleccionados.sublist(0, diasSeleccionados.length - 1).join(', ')} y ${diasSeleccionados.last}'
              : diasSeleccionados.first)
          : 'los días seleccionados';

      if (escena['device']?.toLowerCase().contains('domotica') == true) {
        if (salidasSeleccionadas != null && salidasSeleccionadas.isNotEmpty) {
          String salidasFormateadas = formatearSalidas(salidasSeleccionadas);
          return 'Se ${escena['action']} $salidasFormateadas de $dispositivo los días $dias a la hora seleccionada.';
        }
      }
      return 'Se ${escena['action']} el dispositivo $dispositivo los días $dias a la hora seleccionada.';
    }

    if (escena['tipo'] == 'Activación en cadena' &&
        outputs != null &&
        intervals != null) {
      outputs = intervals.keys.toList();

      if (outputs.length == 1) {
        String salida = outputs.first;
        double segundos = intervals[salida] ?? 1.0;
        return 'Cuando se $accion $salida de $dispositivo, se ${escena['action'] ?? 'realiza una acción desconocida'} con un intervalo de ${segundos.round()} segundos.';
      } else {
        List<String> partes = [];
        for (int i = 0; i < outputs.length; i++) {
          String salida = outputs[i];
          double segundos = intervals[salida] ?? 1.0;
          if (i < outputs.length - 1) {
            partes.add(
                '$salida con un intervalo de ${segundos.round()} segundos');
          } else {
            partes.add(
                'y $salida con un intervalo de ${segundos.round()} segundos');
          }
        }
        String salidasFormateadas = partes.join(', ');
        return 'Cuando se $accion ${outputs.first} de $dispositivo, se ${escena['action'] ?? 'realiza una acción desconocida'} $salidasFormateadas.';
      }
    }

    if (escena['tipo'] == 'Activación en cadena' &&
        (escena['device']?.toLowerCase().contains('gas') == true ||
            escena['device']?.toLowerCase().contains('eléctrico') == true ||
            escena['device']?.toLowerCase().contains('radiador') == true) &&
        escena['devices'] != null &&
        escena['devices'].isNotEmpty) {
      String dispositivos = formatearSalidas(escena['devices']);
      return 'Se ${escena['action']} $dispositivos de manera simultánea.';
    }

    if (escena['action'] == 'apagará' &&
        escena['device']?.toLowerCase().contains('detector') == true) {
      if (salidasSeleccionadas != null && salidasSeleccionadas.isNotEmpty) {
        String salidasFormateadas = formatearSalidas(salidasSeleccionadas);
        return 'Cuando se active $dispositivo, se apagarán $salidasFormateadas.';
      }
    } else if (escena['action'] == 'prenderá') {
      if (salidasSeleccionadas != null && salidasSeleccionadas.isNotEmpty) {
        String salidasFormateadas = formatearSalidas(salidasSeleccionadas);
        return 'Se prenderán $salidasFormateadas de $dispositivo en el horario seleccionado.';
      } else if (outputs != null && outputs.isNotEmpty) {
        outputs = intervals?.keys.toList();

        String salidasConIntervalos = outputs!.map((output) {
          double segundos = intervals?[output] ?? 1.0;
          return '$output con un intervalo de ${segundos.round()} segundos';
        }).join(', ');
        return 'Se prenderán $salidasConIntervalos de $dispositivo en el horario seleccionado.';
      } else {
        return 'Se prenderá el dispositivo $dispositivo en el horario seleccionado.';
      }
    } else if (escena['action'] == 'apagará') {
      if (salidasSeleccionadas != null && salidasSeleccionadas.isNotEmpty) {
        String salidasFormateadas = formatearSalidas(salidasSeleccionadas);
        return 'Se apagarán las $salidasFormateadas de $dispositivo en el horario seleccionado.';
      } else if (outputs != null && outputs.isNotEmpty) {
        outputs = intervals?.keys.toList();

        String salidasConIntervalos = outputs!.map((output) {
          double segundos = intervals?[output] ?? 1.0;
          return '$output con un intervalo de ${segundos.round()} segundos';
        }).join(', ');
        return 'Se apagarán $salidasConIntervalos de $dispositivo en el horario seleccionado.';
      } else {
        return 'Se apagará el dispositivo $dispositivo en el horario seleccionado.';
      }
    }

    return 'Configuración de $dispositivo en el horario seleccionado.';
  }

//*-Construcción de la descripción de escena-*\\

  //*-Método para eliminar una escena con animación-*\\
  void _removeItem(int index) {
    final removedItem = escenasCreadas[index];
    if (removedItem['tipo'] == 'Activación en cadena') {
      detectorOff.removeWhere(
        (key, value) =>
            key == removedItem['device'] &&
            value == removedItem['salidasSeleccionadas'],
      );
      saveDetectorOff(detectorOff);
    }
    printLog('Añaaaa $detectorOff');
    escenasCreadas.removeAt(index);
    _listKey.currentState?.removeItem(
      index,
      (context, animation) => buildListItem(removedItem, index, animation),
      duration: const Duration(milliseconds: 600),
    );
    guardarEscenas(); // Guardar después de eliminar
  }

  //*-Método para eliminar una escena con animación-*\\

  //*-Widget para construir cada elemento de la lista con animación-*\\
  Widget buildListItem(
      Map<String, dynamic> escena, int index, Animation<double> animation) {
    return SizeTransition(
      sizeFactor: animation,
      axisAlignment: 0.0,
      child: buildCard(escena, index),
    );
  }

  //*-Widget para construir cada elemento de la lista con animación-*\\

  //*-Widget para construir la tarjeta de cada escena-*\\
  Widget buildCard(Map<String, dynamic> escena, int index) {
    return Card(
      color: color3,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      elevation: 5,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  escena['action'] != null
                      ? (escena['action'] == 'prenderá'
                          ? Icons.lightbulb
                          : Icons.power_off)
                      : Icons.devices,
                  color: color0,
                  size: 28,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    getCardTitle(escena),
                    style: GoogleFonts.poppins(
                      color: color0,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              buildSceneDescription(escena),
              style: GoogleFonts.poppins(
                color: color0,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (escena['time'] != null) ...[
                  const Icon(Icons.access_time, color: color0, size: 20),
                  const SizedBox(width: 4),
                  Text(
                    (escena['time'] as TimeOfDay).format(context),
                    style: GoogleFonts.poppins(
                      color: color0,
                      fontSize: 14,
                    ),
                  ),
                ],
                const Spacer(),
                // Condición para deshabilitar el botón de eliminar
                if (!showCard)
                  IconButton(
                    icon: const Icon(Icons.delete, color: color5),
                    onPressed: () {
                      _removeItem(index);
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  //*-Widget para construir la tarjeta de cada escena-*\\

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    const cardHeight = 350.0;
    final topCardPosition = screenHeight * 0.07;
    final topListPosition =
        showCard ? topCardPosition + cardHeight + 20.0 : 50.0;

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
                        showCard = !showCard;

                        if (!showCard) {
                          resetConfigurations();
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
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Text(
                            showCard ? 'Cancelar evento' : 'Configurar evento',
                            key: ValueKey(showCard),
                            style: GoogleFonts.poppins(
                              color: color3,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                top: topListPosition,
                left: 10,
                right: 10,
                bottom: 20,
                child: AnimatedList(
                  key: _listKey,
                  initialItemCount: escenasCreadas.length,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  itemBuilder: (context, index, animation) {
                    final escena = escenasCreadas[index];
                    return buildListItem(escena, index, animation);
                  },
                ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                top: showCard ? topCardPosition : -400.0,
                left: 20,
                right: 20,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: showCard ? 1 : 0,
                  child: Card(
                    color: color3,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: SingleChildScrollView(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder:
                              (Widget child, Animation<double> animation) {
                            final slideAnimation = Tween<Offset>(
                              begin: const Offset(1.0, 0.0),
                              end: Offset.zero,
                            ).animate(animation);

                            return SlideTransition(
                              position: slideAnimation,
                              child: child,
                            );
                          },
                          child: buildCardContent(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
