import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:caldensmart/master.dart';
import 'package:caldensmart/Global/stored_data.dart';
import 'package:caldensmart/aws/mqtt/mqtt.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import '../aws/dynamo/dynamo.dart';
import 'package:caldensmart/logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caldensmart/secret.dart';

class WifiPage extends ConsumerStatefulWidget {
  const WifiPage({super.key});

  @override
  ConsumerState<WifiPage> createState() => WifiPageState();
}

class WifiPageState extends ConsumerState<WifiPage> {
  bool charging = false;
  static bool _hasInitialized = false;
  final Map<String, bool> _expandedStates = {};
  final Set<String> _processingGroups = {};

  @override
  void initState() {
    super.initState();
    if (!_hasInitialized) {
      _hasInitialized = true;
      initAsync();
    } else {
      setState(() {
        todosLosDispositivos;

        printLog.i('Lista de dispositivos: $todosLosDispositivos');
      });
    }
  }

  void initAsync() async {
    setState(() {
      charging = true;
    });

    currentUserEmail = await getUserMail();

    todosLosDispositivos.clear();
    await getDevices(currentUserEmail);
    await getNicknames(currentUserEmail);
    await getGroups(currentUserEmail);
    eventosCreados = await getEventos(currentUserEmail);

    // Agregar individuales
    for (String device in previusConnections) {
      todosLosDispositivos.add(MapEntry('individual', device));
    }

    // Agregar los grupos
    groupsOfDevices.forEach((key, value) {
      printLog.i('Grupo: $key');
      printLog.i('Dispositivos: $value');
      todosLosDispositivos.add(MapEntry(key, value.toString()));
    });

    printLog.i('Lista de dispositivos: $todosLosDispositivos');
    charging = false;
    if (mounted) {
      setState(() {});
    }
  }

  //*-Prender y apagar los equipos-*\\
  void toggleState(String deviceName, bool newState) async {
    String deviceSerialNumber = DeviceManager.extractSerialNumber(deviceName);
    String productCode = DeviceManager.getProductCode(deviceName);
    globalDATA[
            '${DeviceManager.getProductCode(deviceName)}/$deviceSerialNumber']![
        'w_status'] = newState;
    saveGlobalData(globalDATA);
    String topic = 'devices_rx/$productCode/$deviceSerialNumber';
    String topic2 = 'devices_tx/$productCode/$deviceSerialNumber';
    String message = jsonEncode({"w_status": newState});
    sendMessagemqtt(topic, message);
    sendMessagemqtt(topic2, message);
  }
  //*-Prender y apagar los equipos-*\\

  //*-Borrar equipo de la lista-*\\
  void _confirmDelete(String deviceName, String equipo) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: color3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
            side: const BorderSide(color: color6, width: 2.0),
          ),
          title: Text(
            'Confirmación',
            style: GoogleFonts.poppins(color: color0),
          ),
          content: Text(
            '¿Seguro que quieres eliminar el dispositivo de la lista?',
            style: GoogleFonts.poppins(color: color0),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(
                'Cancelar',
                style: GoogleFonts.poppins(color: color0),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text(
                'Aceptar',
                style: GoogleFonts.poppins(color: color0),
              ),
              onPressed: () async {
                previusConnections.remove(deviceName);
                alexaDevices.removeWhere((d) => d.contains(deviceName));
                todosLosDispositivos.removeWhere((e) => e.value == deviceName);
                setState(() {});

                await putPreviusConnections(
                    currentUserEmail, previusConnections);
                await putDevicesForAlexa(currentUserEmail, previusConnections);

                final topic =
                    'devices_tx/$equipo/${DeviceManager.extractSerialNumber(deviceName)}';
                unSubToTopicMQTT(topic);

                topicsToSub.remove(topic);

                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }
  //*-Borrar equipo de la lista-*\\

  //*-Determina si el grupo está online-*\\
  bool isGroupOnline(String devicesInGroup) {
    // 1. Convertir el string a lista
    List<String> deviceList = devicesInGroup
        .replaceAll('[', '')
        .replaceAll(']', '')
        .split(',')
        .map((e) => e.trim())
        .toList();

    for (String deviceName in deviceList) {
      String equipo = DeviceManager.getProductCode(deviceName);
      String serial = DeviceManager.extractSerialNumber(deviceName);

      Map<String, dynamic> deviceDATA = globalDATA['$equipo/$serial'] ?? {};

      bool online = deviceDATA['cstate'] ?? false;

      if (!online) {
        return false;
      }
    }

    return true;
  }
//*-Determina si el grupo está online-*\\

  //*-Determina si el grupo está on-*\\
  bool isGroupOn(String devicesInGroup) {
    // 1. Convertir el string a lista
    List<String> deviceList = devicesInGroup
        .replaceAll('[', '')
        .replaceAll(']', '')
        .split(',')
        .map((e) => e.trim())
        .toList();

    for (String deviceName in deviceList) {
      if (deviceName.contains('_')) {
        final list = deviceName.split('_');
        String equipo = DeviceManager.getProductCode(list[0]);
        String serial = DeviceManager.extractSerialNumber(list[0]);

        Map<String, dynamic> deviceDATA =
            jsonDecode(globalDATA['$equipo/$serial']!['io${list[1]}']) ?? {};

        bool turnOn = deviceDATA['w_status'] ?? false;

        if (!turnOn) {
          return false;
        }
      } else {
        String equipo = DeviceManager.getProductCode(deviceName);
        String serial = DeviceManager.extractSerialNumber(deviceName);

        Map<String, dynamic> deviceDATA = globalDATA['$equipo/$serial'] ?? {};

        bool turnOn = deviceDATA['w_status'] ?? false;

        if (!turnOn) {
          return false;
        }
      }
    }

    return true;
  }
  //*-Determina si el grupo está on-*\\

  //*-Determina si puedo controlar el grupo-*\\
  bool canControlGroup(String devicesInGroup) {
    // 1. Convertir el string a lista
    List<String> deviceList = devicesInGroup
        .replaceAll('[', '')
        .replaceAll(']', '')
        .split(',')
        .map((e) => e.trim())
        .toList();

    for (String deviceName in deviceList) {
      String equipo = DeviceManager.getProductCode(deviceName);
      String serial = DeviceManager.extractSerialNumber(deviceName);

      Map<String, dynamic> deviceDATA = globalDATA['$equipo/$serial'] ?? {};

      List<dynamic> admins = deviceDATA['secondary_admin'] ?? [];

      bool owner = deviceDATA['owner'] == currentUserEmail ||
          admins.contains(deviceName) ||
          deviceDATA['owner'] == '' ||
          deviceDATA['owner'] == null;

      if (!owner) {
        return false;
      }
    }

    return true;
  }
  //*-Determina si puedo controlar el grupo-*\\

  //*-Controlar el grupo-*\\
  void controlGroup(String email, bool state, String grupo) async {
    // Verificar si el grupo ya está siendo procesado
    if (_processingGroups.contains(grupo)) {
      showToast(
          '⏳ El grupo "$grupo" ya se está procesando, aguarde un momento...');
      return;
    }

    // Agregar el grupo al Set de procesamiento
    _processingGroups.add(grupo);

    String url = controlGruposAPI;
    Uri uri = Uri.parse(url);

    String bd = jsonEncode(
      {
        'email': email,
        'on': state,
        'grupo': grupo,
        'app': app,
      },
    );

    printLog.i('Body: $bd');

    try {
      var response = await http.post(uri, body: bd);

      printLog.i('Response status: ${response.statusCode}');
      printLog.i('Response body: ${response.body}');

      if (response.statusCode == 200) {
        // Respuesta exitosa - todos los dispositivos se controlaron
        final responseData = jsonDecode(response.body);

        printLog.i('Grupo controlado exitosamente');
        showToast(
            '¡Perfecto! Todos los equipos del grupo se ${state ? 'encendieron' : 'apagaron'} correctamente 🎉');

        // Log adicional con detalles
        if (responseData['exitosos'] != null &&
            responseData['total_dispositivos'] != null) {
          printLog.i(
              'Dispositivos procesados: ${responseData['exitosos']}/${responseData['total_dispositivos']}');
        }
      } else if (response.statusCode == 207) {
        // Multi-Status - algunos dispositivos fallaron
        final responseData = jsonDecode(response.body);

        printLog.i('Algunos dispositivos no pudieron ser controlados');

        final exitosos = responseData['exitosos'] ?? 0;
        final fallidos = responseData['fallidos'] ?? 0;
        final dispositivosOffline = responseData['dispositivos_offline'] ?? [];

        // Mostrar mensaje detallado al usuario
        String message = '⚠️ Acción parcialmente completada:\n\n';
        message +=
            '✅ $exitosos equipos se ${state ? 'encendieron' : 'apagaron'} correctamente\n';

        if (fallidos > 0) {
          message += '❌ $fallidos equipos no disponibles en este momento';
          if (dispositivosOffline.isNotEmpty) {
            // Mostrar nombres de dispositivos offline (máximo 3 para no saturar)
            final deviceNames = dispositivosOffline.take(3).map((device) {
              return nicknamesMap[device] ?? device;
            }).join(', ');
            message += '\n\n📱 Equipos sin conexión: $deviceNames';
            if (dispositivosOffline.length > 3) {
              message += ' y ${dispositivosOffline.length - 3} más...';
            }
          }
        }

        showToast(message);
      } else if (response.statusCode == 400) {
        // Error de validación
        final responseData = jsonDecode(response.body);
        final errorMessage = responseData['error'] ?? 'Error de validación';

        printLog.e('Error de validación: $errorMessage');
        showToast(
            '🚫 Ups, algo no está bien configurado. Por favor intenta nuevamente');
      } else if (response.statusCode == 404) {
        // Grupo no encontrado
        printLog.e('Grupo no encontrado');
        showToast(
            '🔍 No encontramos el grupo "$grupo". Verifica que tengas permisos para controlarlo');
      } else {
        // Otros errores del servidor
        printLog.e('Error del servidor: ${response.statusCode}');
        showToast(
            '⚡ Hubo un problema en nuestros servidores. Por favor intenta en unos momentos');
      }
    } catch (e) {
      // Error de conexión o parsing
      printLog.e('Error de conexión al controlar el grupo: $e');
      showToast(
          '📶 Sin conexión a internet. Verifica tu red y vuelve a intentar');
    } finally {
      // Remover el grupo del Set de procesamiento
      _processingGroups.remove(grupo);
    }
  }
  //*-Controlar el grupo-*\\

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Mis equipos registrados',
          style: GoogleFonts.poppins(color: color0),
        ),
        backgroundColor: color3,
        actions: [
          charging
              ? const SizedBox.shrink()
              : IconButton(
                  icon: const Icon(HugeIcons.strokeRoundedSettings02,
                      color: color0),
                  onPressed: () =>
                      Navigator.pushReplacementNamed(context, '/escenas'),
                ),
        ],
      ),
      body: Container(
        padding: const EdgeInsets.only(bottom: 100.0),
        color: color1,
        child: charging
            ? Center(
                child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/branch/dragon.gif',
                          width: 150,
                          height: 150,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Se están cargando los equipos, aguarde un momento por favor...',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: color3,
                          ),
                        ),
                      ],
                    )),
              )
            : todosLosDispositivos.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        'Aún no se ha conectado a ningún equipo',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: color3,
                        ),
                      ),
                    ),
                  )
                : ReorderableListView.builder(
                    itemCount: todosLosDispositivos.length,
                    onReorder: (int oldIndex, int newIndex) {
                      setState(() {
                        if (newIndex > oldIndex) {
                          newIndex -= 1;
                        }
                        final MapEntry<String, String> item =
                            todosLosDispositivos.removeAt(oldIndex);
                        todosLosDispositivos.insert(newIndex, item);
                      });
                    },
                    itemBuilder: (BuildContext context, int index) {
                      final String grupo = todosLosDispositivos[index].key;
                      final String deviceName =
                          todosLosDispositivos[index].value;

                      final bool esGrupo = grupo != 'individual';
                      final topicData = ref.watch(
                        globalDataProvider.select(
                          (map) =>
                              map['${DeviceManager.getProductCode(deviceName)}/'
                                  '${DeviceManager.extractSerialNumber(deviceName)}'] ??
                              {},
                        ),
                      );

                      if (!esGrupo) {
                        String productCode =
                            DeviceManager.getProductCode(deviceName);
                        String serialNumber =
                            DeviceManager.extractSerialNumber(deviceName);

                        globalDATA
                            .putIfAbsent('$productCode/$serialNumber', () => {})
                            .addAll(topicData);
                        saveGlobalData(globalDATA);
                        Map<String, dynamic> deviceDATA =
                            globalDATA['$productCode/$serialNumber'] ?? {};
                        // printLog.i(deviceDATA, 'cyan');

                        // printLog.i(
                        //     "Las keys del equipo ${deviceDATA.keys}", 'rojo');

                        bool online = deviceDATA['cstate'] ?? false;

                        List<dynamic> admins =
                            deviceDATA['secondary_admin'] ?? [];

                        bool owner = deviceDATA['owner'] == currentUserEmail ||
                            admins.contains(currentUserEmail) ||
                            deviceDATA['owner'] == '' ||
                            deviceDATA['owner'] == null;

                        try {
                          switch (productCode) {
                            case '015773_IOT':
                              int ppmCO = deviceDATA['ppmco'] ?? 0;
                              int ppmCH4 = deviceDATA['ppmch4'] ?? 0;
                              bool alert = deviceDATA['alert'] == 1;
                              return Card(
                                key: ValueKey(deviceName),
                                color: color3,
                                margin: const EdgeInsets.symmetric(
                                    vertical: 5, horizontal: 10),
                                elevation: 2,
                                child: Theme(
                                  data: Theme.of(context).copyWith(
                                      dividerColor: Colors.transparent),
                                  child: ExpansionTile(
                                    tilePadding: const EdgeInsets.symmetric(
                                        horizontal: 16.0),
                                    iconColor: color6,
                                    collapsedIconColor: color6,
                                    title: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            SizedBox(
                                              width: MediaQuery.of(context)
                                                      .size
                                                      .width *
                                                  0.7,
                                              child: Text(
                                                nicknamesMap[deviceName] ??
                                                    deviceName,
                                                style: GoogleFonts.poppins(
                                                  color: color0,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                              ),
                                            ),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.start,
                                              spacing: 10,
                                              children: [
                                                Text(
                                                  online
                                                      ? '● CONECTADO'
                                                      : '● DESCONECTADO',
                                                  style: GoogleFonts.poppins(
                                                    color: online
                                                        ? Colors.green
                                                        : color5,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                                Icon(
                                                  online
                                                      ? Icons.cloud
                                                      : Icons.cloud_off,
                                                  color: online
                                                      ? Colors.green
                                                      : color5,
                                                  size: 15,
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    children: <Widget>[
                                      ListTile(
                                        title: online
                                            ? Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'PPM CO: $ppmCO',
                                                    style: GoogleFonts.poppins(
                                                      color: color0,
                                                      fontSize: 15,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                  Text(
                                                    'CH4 LIE: ${(ppmCH4 / 500).round()}%',
                                                    style: GoogleFonts.poppins(
                                                      color: color0,
                                                      fontSize: 15,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                  Row(
                                                    children: [
                                                      Text(
                                                        alert
                                                            ? 'PELIGRO'
                                                            : 'AIRE PURO',
                                                        style:
                                                            GoogleFonts.poppins(
                                                          color: color0,
                                                          fontSize: 15,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 5),
                                                      alert
                                                          ? const Icon(
                                                              HugeIcons
                                                                  .strokeRoundedAlert02,
                                                              color: color6,
                                                            )
                                                          : const Icon(
                                                              HugeIcons
                                                                  .strokeRoundedLeaf01,
                                                              color:
                                                                  Colors.green,
                                                            ),
                                                    ],
                                                  ),
                                                ],
                                              )
                                            : Text(
                                                'El equipo debe estar\nconectado para su uso',
                                                style: GoogleFonts.poppins(
                                                  color: color5,
                                                  fontSize: 15,
                                                ),
                                              ),
                                      ),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: Padding(
                                          padding: const EdgeInsets.only(
                                              right: 16.0, bottom: 8.0),
                                          child: IconButton(
                                            icon: const Icon(
                                              HugeIcons.strokeRoundedDelete02,
                                              color: color0,
                                              size: 20,
                                            ),
                                            onPressed: () {
                                              _confirmDelete(
                                                  deviceName, productCode);
                                            },
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            case '022000_IOT':
                              bool estado = deviceDATA['w_status'] ?? false;
                              bool heaterOn = deviceDATA['f_status'] ?? false;

                              return Card(
                                key: ValueKey(deviceName),
                                color: color3,
                                margin: const EdgeInsets.symmetric(
                                    vertical: 5, horizontal: 10),
                                elevation: 2,
                                child: Theme(
                                  data: Theme.of(context).copyWith(
                                      dividerColor: Colors.transparent),
                                  child: ExpansionTile(
                                    tilePadding: const EdgeInsets.symmetric(
                                        horizontal: 16.0),
                                    iconColor: color6,
                                    collapsedIconColor: color6,
                                    title: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            SizedBox(
                                              width: MediaQuery.of(context)
                                                      .size
                                                      .width *
                                                  0.7,
                                              child: Text(
                                                nicknamesMap[deviceName] ??
                                                    deviceName,
                                                style: GoogleFonts.poppins(
                                                  color: color0,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                              ),
                                            ),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.start,
                                              spacing: 10,
                                              children: [
                                                Text(
                                                  online
                                                      ? '● CONECTADO'
                                                      : '● DESCONECTADO',
                                                  style: GoogleFonts.poppins(
                                                    color: online
                                                        ? Colors.green
                                                        : color5,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                                Icon(
                                                  online
                                                      ? Icons.cloud
                                                      : Icons.cloud_off,
                                                  color: online
                                                      ? Colors.green
                                                      : color5,
                                                  size: 15,
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    children: <Widget>[
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16.0, vertical: 5.0),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            online
                                                ? Row(
                                                    children: [
                                                      estado
                                                          ? Row(
                                                              children: [
                                                                if (heaterOn) ...[
                                                                  Text(
                                                                    'Calentando',
                                                                    style: GoogleFonts
                                                                        .poppins(
                                                                      color: Colors
                                                                              .amber[
                                                                          800],
                                                                      fontSize:
                                                                          15,
                                                                    ),
                                                                  ),
                                                                  Icon(
                                                                    HugeIcons
                                                                        .strokeRoundedFlash,
                                                                    size: 15,
                                                                    color: Colors
                                                                            .amber[
                                                                        800],
                                                                  ),
                                                                ] else ...[
                                                                  Text(
                                                                    'Encendido',
                                                                    style: GoogleFonts
                                                                        .poppins(
                                                                      color: Colors
                                                                          .green,
                                                                      fontSize:
                                                                          15,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ],
                                                            )
                                                          : Text(
                                                              'Apagado',
                                                              style: GoogleFonts
                                                                  .poppins(
                                                                      color:
                                                                          color6,
                                                                      fontSize:
                                                                          15),
                                                            ),
                                                      const SizedBox(width: 5),
                                                      owner
                                                          ? Switch(
                                                              activeColor:
                                                                  const Color(
                                                                      0xFF9C9D98),
                                                              activeTrackColor:
                                                                  const Color(
                                                                      0xFFB2B5AE),
                                                              inactiveThumbColor:
                                                                  const Color(
                                                                      0xFFB2B5AE),
                                                              inactiveTrackColor:
                                                                  const Color(
                                                                      0xFF9C9D98),
                                                              value: estado,
                                                              onChanged:
                                                                  (newValue) {
                                                                toggleState(
                                                                    deviceName,
                                                                    newValue);
                                                                setState(() {
                                                                  estado =
                                                                      newValue;
                                                                });
                                                              },
                                                            )
                                                          : const SizedBox(
                                                              height: 0,
                                                              width: 0),
                                                    ],
                                                  )
                                                : Text(
                                                    'El equipo debe estar\nconectado para su uso',
                                                    style: GoogleFonts.poppins(
                                                      color: color5,
                                                      fontSize: 15,
                                                    ),
                                                  ),
                                          ],
                                        ),
                                      ),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: Padding(
                                          padding: const EdgeInsets.only(
                                              right: 16.0, bottom: 8.0),
                                          child: IconButton(
                                            icon: const Icon(
                                              HugeIcons.strokeRoundedDelete02,
                                              color: color0,
                                              size: 20,
                                            ),
                                            onPressed: () {
                                              _confirmDelete(
                                                  deviceName, productCode);
                                            },
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            case '027000_IOT':
                              bool estado = deviceDATA['w_status'] ?? false;
                              bool heaterOn = deviceDATA['f_status'] ?? false;
                              return Card(
                                key: ValueKey(deviceName),
                                color: color3,
                                margin: const EdgeInsets.symmetric(
                                    vertical: 5, horizontal: 10),
                                elevation: 2,
                                child: Theme(
                                  data: Theme.of(context).copyWith(
                                      dividerColor: Colors.transparent),
                                  child: ExpansionTile(
                                    tilePadding: const EdgeInsets.symmetric(
                                        horizontal: 16.0),
                                    iconColor: color6,
                                    collapsedIconColor: color6,
                                    title: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            SizedBox(
                                              width: MediaQuery.of(context)
                                                      .size
                                                      .width *
                                                  0.7,
                                              child: Text(
                                                nicknamesMap[deviceName] ??
                                                    deviceName,
                                                style: GoogleFonts.poppins(
                                                  color: color0,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                              ),
                                            ),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.start,
                                              spacing: 10,
                                              children: [
                                                Text(
                                                  online
                                                      ? '● CONECTADO'
                                                      : '● DESCONECTADO',
                                                  style: GoogleFonts.poppins(
                                                    color: online
                                                        ? Colors.green
                                                        : color5,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                                Icon(
                                                  online
                                                      ? Icons.cloud
                                                      : Icons.cloud_off,
                                                  color: online
                                                      ? Colors.green
                                                      : color5,
                                                  size: 15,
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    children: <Widget>[
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16.0, vertical: 5.0),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: online
                                                  ? Row(
                                                      children: [
                                                        estado
                                                            ? Row(
                                                                children: [
                                                                  if (heaterOn) ...[
                                                                    Text(
                                                                      'Calentando',
                                                                      style: GoogleFonts
                                                                          .poppins(
                                                                        color: Colors
                                                                                .amber[
                                                                            800],
                                                                        fontSize:
                                                                            15,
                                                                      ),
                                                                    ),
                                                                    Icon(
                                                                      HugeIcons
                                                                          .strokeRoundedFire,
                                                                      size: 15,
                                                                      color: Colors
                                                                              .amber[
                                                                          800],
                                                                    ),
                                                                  ] else ...[
                                                                    Text(
                                                                      'Encendido',
                                                                      style: GoogleFonts
                                                                          .poppins(
                                                                        color: Colors
                                                                            .green,
                                                                        fontSize:
                                                                            15,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ],
                                                              )
                                                            : Text(
                                                                'Apagado',
                                                                style: GoogleFonts
                                                                    .poppins(
                                                                  color: color6,
                                                                  fontSize: 15,
                                                                ),
                                                              ),
                                                        const SizedBox(width: 5),
                                                        Switch(
                                                            activeColor:
                                                                const Color(
                                                                    0xFF9C9D98),
                                                            activeTrackColor:
                                                                const Color(
                                                                    0xFFB2B5AE),
                                                            inactiveThumbColor:
                                                                const Color(
                                                                    0xFFB2B5AE),
                                                            inactiveTrackColor:
                                                                const Color(
                                                                    0xFF9C9D98),
                                                            value: estado,
                                                            onChanged: online
                                                                ? (newValue) {
                                                                    toggleState(
                                                                        deviceName,
                                                                        newValue);
                                                                    setState(() {
                                                                      estado =
                                                                          newValue;
                                                                      if (!newValue) {
                                                                        heaterOn =
                                                                            false;
                                                                      }
                                                                    });
                                                                  }
                                                                : null),
                                                      ],
                                                    )
                                                  : Text(
                                                      'El equipo debe estar\nconectado para su uso',
                                                      style: GoogleFonts.poppins(
                                                        color: color5,
                                                        fontSize: 15,
                                                      ),
                                                    ),
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                HugeIcons.strokeRoundedDelete02,
                                                color: color0,
                                                size: 20,
                                              ),
                                              onPressed: () {
                                                _confirmDelete(
                                                    deviceName, productCode);
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            case '020010_IOT':
                              return Card(
                                key: ValueKey(deviceName),
                                color: color3,
                                margin: const EdgeInsets.symmetric(
                                  vertical: 5,
                                  horizontal: 10,
                                ),
                                elevation: 2,
                                child: Theme(
                                  data: Theme.of(context).copyWith(
                                      dividerColor: Colors.transparent),
                                  child: ExpansionTile(
                                    tilePadding: const EdgeInsets.symmetric(
                                      horizontal: 16.0,
                                    ),
                                    iconColor: color6,
                                    collapsedIconColor: color6,
                                    title: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            SizedBox(
                                              width: MediaQuery.of(context)
                                                      .size
                                                      .width *
                                                  0.7,
                                              child: Text(
                                                nicknamesMap[deviceName] ??
                                                    deviceName,
                                                style: GoogleFonts.poppins(
                                                  color: color0,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                              ),
                                            ),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.start,
                                              spacing: 10,
                                              children: [
                                                Text(
                                                  online
                                                      ? '● CONECTADO'
                                                      : '● DESCONECTADO',
                                                  style: GoogleFonts.poppins(
                                                    color: online
                                                        ? Colors.green
                                                        : color5,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                                Icon(
                                                  online
                                                      ? Icons.cloud
                                                      : Icons.cloud_off,
                                                  color: online
                                                      ? Colors.green
                                                      : color5,
                                                  size: 15,
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    children: <Widget>[
                                      online
                                          ? Column(
                                              children: [
                                                ...(deviceDATA.keys
                                                        .where((key) =>
                                                            key.startsWith(
                                                                'io') &&
                                                            RegExp(r'^io\d+$')
                                                                .hasMatch(key))
                                                        .where((ioKey) =>
                                                            deviceDATA[ioKey] !=
                                                            null)
                                                        .toList()
                                                      ..sort((a, b) {
                                                        int indexA = int.parse(
                                                            a.substring(2));
                                                        int indexB = int.parse(
                                                            b.substring(2));
                                                        return indexA
                                                            .compareTo(indexB);
                                                      }))
                                                    .map((ioKey) {
                                                  // Extraer el índice del ioKey (ejemplo: "io0" -> 0)
                                                  int i = int.parse(
                                                      ioKey.substring(2));
                                                  Map<String, dynamic> equipo =
                                                      jsonDecode(
                                                          deviceDATA[ioKey]);
                                                  printLog.i(
                                                    'Voy a realizar el cambio: $equipo',
                                                  );
                                                  String tipoWifi =
                                                      equipo['pinType']
                                                                  .toString() ==
                                                              '0'
                                                          ? 'Salida'
                                                          : 'Entrada';
                                                  bool estadoWifi =
                                                      equipo['w_status'];
                                                  String comunWifi =
                                                      (equipo['r_state'] ?? '0')
                                                          .toString();
                                                  bool entradaWifi =
                                                      tipoWifi == 'Entrada';
                                                  return ListTile(
                                                    title: Row(
                                                      children: [
                                                        Text(
                                                          nicknamesMap[
                                                                  '${deviceName}_$i'] ??
                                                              '$tipoWifi $i',
                                                          style: GoogleFonts
                                                              .poppins(
                                                            color: color0,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            width: 5),
                                                      ],
                                                    ),
                                                    subtitle: Align(
                                                      alignment:
                                                          AlignmentDirectional
                                                              .centerStart,
                                                      child: Column(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .start,
                                                        children: [
                                                          entradaWifi
                                                              ? estadoWifi
                                                                  ? comunWifi ==
                                                                          '1'
                                                                      ? Text(
                                                                          'Cerrado',
                                                                          style:
                                                                              GoogleFonts.poppins(
                                                                            color:
                                                                                Colors.green,
                                                                            fontSize:
                                                                                15,
                                                                            fontWeight:
                                                                                FontWeight.bold,
                                                                          ),
                                                                        )
                                                                      : Text(
                                                                          'Abierto',
                                                                          style:
                                                                              GoogleFonts.poppins(
                                                                            color:
                                                                                color6,
                                                                            fontSize:
                                                                                15,
                                                                            fontWeight:
                                                                                FontWeight.bold,
                                                                          ),
                                                                        )
                                                                  : comunWifi ==
                                                                          '1'
                                                                      ? Text(
                                                                          'Abierto',
                                                                          style:
                                                                              GoogleFonts.poppins(
                                                                            color:
                                                                                color6,
                                                                            fontSize:
                                                                                15,
                                                                            fontWeight:
                                                                                FontWeight.bold,
                                                                          ),
                                                                        )
                                                                      : Text(
                                                                          'Cerrado',
                                                                          style:
                                                                              GoogleFonts.poppins(
                                                                            color:
                                                                                Colors.green,
                                                                            fontSize:
                                                                                15,
                                                                            fontWeight:
                                                                                FontWeight.bold,
                                                                          ),
                                                                        )
                                                              : estadoWifi
                                                                  ? Text(
                                                                      'Encendido',
                                                                      style: GoogleFonts
                                                                          .poppins(
                                                                        color: Colors
                                                                            .green,
                                                                        fontSize:
                                                                            15,
                                                                        fontWeight:
                                                                            FontWeight.bold,
                                                                      ),
                                                                    )
                                                                  : Text(
                                                                      'Apagado',
                                                                      style: GoogleFonts
                                                                          .poppins(
                                                                        color:
                                                                            color6,
                                                                        fontSize:
                                                                            15,
                                                                        fontWeight:
                                                                            FontWeight.bold,
                                                                      ),
                                                                    ),
                                                        ],
                                                      ),
                                                    ),
                                                    trailing: owner
                                                        ? entradaWifi
                                                            ? estadoWifi
                                                                ? comunWifi ==
                                                                        '1'
                                                                    ? const Icon(
                                                                        Icons
                                                                            .new_releases,
                                                                        color:
                                                                            Color(
                                                                          0xff9b9b9b,
                                                                        ),
                                                                      )
                                                                    : const Icon(
                                                                        Icons
                                                                            .new_releases,
                                                                        color:
                                                                            color6,
                                                                      )
                                                                : comunWifi ==
                                                                        '1'
                                                                    ? const Icon(
                                                                        Icons
                                                                            .new_releases,
                                                                        color:
                                                                            color6,
                                                                      )
                                                                    : const Icon(
                                                                        Icons
                                                                            .new_releases,
                                                                        color:
                                                                            Color(
                                                                          0xff9b9b9b,
                                                                        ),
                                                                      )
                                                            : Switch(
                                                                activeColor:
                                                                    const Color(
                                                                  0xFF9C9D98,
                                                                ),
                                                                activeTrackColor:
                                                                    const Color(
                                                                  0xFFB2B5AE,
                                                                ),
                                                                inactiveThumbColor:
                                                                    const Color(
                                                                  0xFFB2B5AE,
                                                                ),
                                                                inactiveTrackColor:
                                                                    const Color(
                                                                  0xFF9C9D98,
                                                                ),
                                                                value:
                                                                    estadoWifi,
                                                                onChanged:
                                                                    (value) {
                                                                  String topic =
                                                                      'devices_rx/$productCode/$serialNumber';
                                                                  String
                                                                      topic2 =
                                                                      'devices_tx/$productCode/$serialNumber';
                                                                  String
                                                                      message =
                                                                      jsonEncode({
                                                                    'pinType':
                                                                        tipoWifi ==
                                                                                'Salida'
                                                                            ? 0
                                                                            : 1,
                                                                    'index': i,
                                                                    'w_status':
                                                                        value,
                                                                    'r_state':
                                                                        comunWifi,
                                                                  });
                                                                  sendMessagemqtt(
                                                                      topic,
                                                                      message);
                                                                  sendMessagemqtt(
                                                                      topic2,
                                                                      message);
                                                                  setState(() {
                                                                    estadoWifi =
                                                                        value;
                                                                  });
                                                                  globalDATA
                                                                      .putIfAbsent(
                                                                          '$productCode/$serialNumber',
                                                                          () =>
                                                                              {})
                                                                      .addAll({
                                                                    'io$i':
                                                                        message
                                                                  });
                                                                  saveGlobalData(
                                                                      globalDATA);
                                                                },
                                                              )
                                                        : null,
                                                  );
                                                }),
                                              ],
                                            )
                                          : const SizedBox(height: 0),
                                      Stack(
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                left: 20.0),
                                            child: !online
                                                ? Text(
                                                    'El equipo debe estar\nconectado para su uso',
                                                    style: GoogleFonts.poppins(
                                                      color: color5,
                                                      fontSize: 15,
                                                    ),
                                                  )
                                                : const SizedBox(height: 0),
                                          ),
                                          Align(
                                            alignment: Alignment.centerRight,
                                            child: Padding(
                                              padding: const EdgeInsets.only(
                                                  right: 16.0, bottom: 8.0),
                                              child: IconButton(
                                                icon: const Icon(
                                                  HugeIcons
                                                      .strokeRoundedDelete02,
                                                  color: color0,
                                                  size: 20,
                                                ),
                                                onPressed: () {
                                                  _confirmDelete(
                                                      deviceName, productCode);
                                                },
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            case '027313_IOT':
                              bool estado = deviceDATA['w_status'] ?? false;
                              bool hasEntry = deviceDATA['hasEntry'] ?? false;
                              String hardv =
                                  deviceDATA['HardwareVersion'] ?? '000000A';
                              // bool isNC = deviceDATA['isNC'] ?? false;

                              return Card(
                                key: ValueKey(deviceName),
                                color: color3,
                                margin: const EdgeInsets.symmetric(
                                  vertical: 5,
                                  horizontal: 10,
                                ),
                                elevation: 2,
                                child: Theme(
                                  data: Theme.of(context).copyWith(
                                      dividerColor: Colors.transparent),
                                  child: ExpansionTile(
                                    tilePadding: const EdgeInsets.symmetric(
                                      horizontal: 16.0,
                                    ),
                                    iconColor: color6,
                                    collapsedIconColor: color6,
                                    title: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            SizedBox(
                                              width: MediaQuery.of(context)
                                                      .size
                                                      .width *
                                                  0.7,
                                              child: Text(
                                                nicknamesMap[deviceName] ??
                                                    deviceName,
                                                style: GoogleFonts.poppins(
                                                  color: color0,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                              ),
                                            ),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.start,
                                              spacing: 10,
                                              children: [
                                                Text(
                                                  online
                                                      ? '● CONECTADO'
                                                      : '● DESCONECTADO',
                                                  style: GoogleFonts.poppins(
                                                    color: online
                                                        ? Colors.green
                                                        : color5,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                                Icon(
                                                  online
                                                      ? Icons.cloud
                                                      : Icons.cloud_off,
                                                  color: online
                                                      ? Colors.green
                                                      : color5,
                                                  size: 15,
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    children: <Widget>[
                                      if (Versioner.isPrevious(
                                          hardv, '241220A')) ...{
                                        Stack(
                                          children: [
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 16.0,
                                                      vertical: 5.0),
                                              child: online
                                                  ? Row(
                                                      children: [
                                                        estado
                                                            ? Text(
                                                                'ENCENDIDO',
                                                                style:
                                                                    GoogleFonts
                                                                        .poppins(
                                                                  color: Colors
                                                                      .green,
                                                                  fontSize: 15,
                                                                ),
                                                              )
                                                            : Text(
                                                                'APAGADO',
                                                                style:
                                                                    GoogleFonts
                                                                        .poppins(
                                                                  color: color6,
                                                                  fontSize: 15,
                                                                ),
                                                              ),
                                                        const SizedBox(
                                                            width: 5),
                                                        owner
                                                            ? Switch(
                                                                activeColor:
                                                                    const Color(
                                                                        0xFF9C9D98),
                                                                activeTrackColor:
                                                                    const Color(
                                                                        0xFFB2B5AE),
                                                                inactiveThumbColor:
                                                                    const Color(
                                                                        0xFFB2B5AE),
                                                                inactiveTrackColor:
                                                                    const Color(
                                                                        0xFF9C9D98),
                                                                value: estado,
                                                                onChanged:
                                                                    (newValue) {
                                                                  toggleState(
                                                                      deviceName,
                                                                      newValue);
                                                                  setState(() {
                                                                    estado =
                                                                        newValue;
                                                                  });
                                                                },
                                                              )
                                                            : const SizedBox(
                                                                height: 0,
                                                                width: 0),
                                                      ],
                                                    )
                                                  : Text(
                                                      'El equipo debe estar\nconectado para su uso',
                                                      style:
                                                          GoogleFonts.poppins(
                                                        color: color5,
                                                        fontSize: 15,
                                                      ),
                                                    ),
                                            ),
                                            Align(
                                              alignment: Alignment.centerRight,
                                              child: Padding(
                                                padding: const EdgeInsets.only(
                                                    right: 16.0, bottom: 8.0),
                                                child: IconButton(
                                                  icon: const Icon(
                                                    HugeIcons
                                                        .strokeRoundedDelete02,
                                                    color: color0,
                                                    size: 20,
                                                  ),
                                                  onPressed: () {
                                                    _confirmDelete(deviceName,
                                                        productCode);
                                                  },
                                                ),
                                              ),
                                            ),
                                          ],
                                        )
                                      } else ...{
                                        online
                                            ? Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  // POSICIÓN 0: Salida con switch
                                                  if (deviceDATA['io0'] ==
                                                      null) ...[
                                                    const SizedBox
                                                        .shrink() // No mostrar nada si no hay datos
                                                  ] else ...[
                                                    if (deviceDATA['io0'] ==
                                                        null) ...[
                                                      const SizedBox
                                                          .shrink() // No mostrar nada si no hay datos
                                                    ] else ...[
                                                      if (hasEntry) ...[
                                                        ListTile(
                                                          title: Text(
                                                            nicknamesMap[
                                                                    '${deviceName}_0'] ??
                                                                'Salida 0',
                                                            style: GoogleFonts
                                                                .poppins(
                                                              color: color0,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                          ),
                                                          trailing: owner
                                                              ? Switch(
                                                                  activeColor:
                                                                      const Color(
                                                                          0xFF9C9D98),
                                                                  activeTrackColor:
                                                                      const Color(
                                                                          0xFFB2B5AE),
                                                                  inactiveThumbColor:
                                                                      const Color(
                                                                          0xFFB2B5AE),
                                                                  inactiveTrackColor:
                                                                      const Color(
                                                                          0xFF9C9D98),
                                                                  value: (jsonDecode(
                                                                              deviceDATA['io0'])[
                                                                          'w_status'] ??
                                                                      false),
                                                                  onChanged:
                                                                      (value) {
                                                                    final deviceSerialNumber =
                                                                        DeviceManager.extractSerialNumber(
                                                                            deviceName);
                                                                    final productCode =
                                                                        DeviceManager.getProductCode(
                                                                            deviceName);
                                                                    final topicRx =
                                                                        'devices_rx/$productCode/$deviceSerialNumber';
                                                                    final topicTx =
                                                                        'devices_tx/$productCode/$deviceSerialNumber';
                                                                    final Map<
                                                                            String,
                                                                            dynamic>
                                                                        io0Map =
                                                                        jsonDecode(
                                                                            deviceDATA['io0']);
                                                                    final rState =
                                                                        (io0Map['r_state'] ??
                                                                                '0')
                                                                            .toString();
                                                                    final message =
                                                                        jsonEncode({
                                                                      'pinType':
                                                                          0,
                                                                      'index':
                                                                          0,
                                                                      'w_status':
                                                                          value,
                                                                      'r_state':
                                                                          rState,
                                                                    });
                                                                    sendMessagemqtt(
                                                                        topicRx,
                                                                        message);
                                                                    sendMessagemqtt(
                                                                        topicTx,
                                                                        message);
                                                                    setState(
                                                                        () {});
                                                                    globalDATA
                                                                        .putIfAbsent(
                                                                            '$productCode/$deviceSerialNumber',
                                                                            () =>
                                                                                {})
                                                                        .addAll({
                                                                      'io0':
                                                                          message
                                                                    });
                                                                    saveGlobalData(
                                                                        globalDATA);
                                                                  },
                                                                )
                                                              : null,
                                                        ),
                                                      ] else ...[
                                                        Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                            horizontal: 16.0,
                                                            vertical: 5.0,
                                                          ),
                                                          child: Row(
                                                            mainAxisAlignment:
                                                                MainAxisAlignment
                                                                    .spaceBetween,
                                                            children: [
                                                              online
                                                                  ? Row(
                                                                      children: [
                                                                        (jsonDecode(deviceDATA['io0'])['w_status'] ??
                                                                                false)
                                                                            ? Text(
                                                                                'ENCENDIDO',
                                                                                style: GoogleFonts.poppins(
                                                                                  color: Colors.green,
                                                                                  fontSize: 15,
                                                                                ),
                                                                              )
                                                                            : Text(
                                                                                'APAGADO',
                                                                                style: GoogleFonts.poppins(
                                                                                  color: color6,
                                                                                  fontSize: 15,
                                                                                ),
                                                                              ),
                                                                        const SizedBox(
                                                                            width:
                                                                                5),
                                                                        owner
                                                                            ? Switch(
                                                                                activeColor: const Color(0xFF9C9D98),
                                                                                activeTrackColor: const Color(0xFFB2B5AE),
                                                                                inactiveThumbColor: const Color(0xFFB2B5AE),
                                                                                inactiveTrackColor: const Color(0xFF9C9D98),
                                                                                value: (jsonDecode(deviceDATA['io0'])['w_status'] ?? false),
                                                                                onChanged: (value) {
                                                                                  final topicRx = 'devices_rx/$productCode/$serialNumber';
                                                                                  final topicTx = 'devices_tx/$productCode/$serialNumber';
                                                                                  final Map<String, dynamic> io0Map = jsonDecode(deviceDATA['io0']);
                                                                                  final rState = (io0Map['r_state'] ?? '0').toString();
                                                                                  final message = jsonEncode({
                                                                                    'pinType': 0,
                                                                                    'index': 0,
                                                                                    'w_status': value,
                                                                                    'r_state': rState,
                                                                                  });
                                                                                  sendMessagemqtt(topicRx, message);
                                                                                  sendMessagemqtt(topicTx, message);
                                                                                  setState(() {});
                                                                                  globalDATA.putIfAbsent('$productCode/$serialNumber', () => {}).addAll({
                                                                                    'io0': message
                                                                                  });
                                                                                  saveGlobalData(globalDATA);
                                                                                },
                                                                              )
                                                                            : const SizedBox(
                                                                                height: 0,
                                                                                width: 0),
                                                                      ],
                                                                    )
                                                                  : Text(
                                                                      'El equipo debe estar\nconectado para su uso',
                                                                      style: GoogleFonts
                                                                          .poppins(
                                                                        color:
                                                                            color5,
                                                                        fontSize:
                                                                            15,
                                                                      ),
                                                                    ),
                                                            ],
                                                          ),
                                                        )
                                                      ],
                                                    ],
                                                  ],
                                                  // POSICIÓN 1: Entrada, solo si hasEntry == true
                                                  if (hasEntry) ...[
                                                    if (deviceDATA['io1'] ==
                                                        null) ...[
                                                      const SizedBox
                                                          .shrink() // No mostrar nada si no hay datos
                                                    ] else ...[
                                                      ListTile(
                                                        title: Text(
                                                          nicknamesMap[
                                                                  '${deviceName}_1'] ??
                                                              'Entrada 1',
                                                          style: GoogleFonts
                                                              .poppins(
                                                            color: color0,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                        trailing: Icon(
                                                          Icons.new_releases,
                                                          color: (() {
                                                            final io1 =
                                                                jsonDecode(
                                                                    deviceDATA[
                                                                        'io1']);
                                                            final bool wStatus =
                                                                io1['w_status'] ??
                                                                    false;
                                                            final String
                                                                rState =
                                                                (io1['r_state'] ??
                                                                        '0')
                                                                    .toString();
                                                            final bool
                                                                mismatch =
                                                                (rState == '0' &&
                                                                        wStatus) ||
                                                                    (rState ==
                                                                            '1' &&
                                                                        !wStatus);
                                                            return mismatch
                                                                ? color6
                                                                : const Color(
                                                                    0xFF9C9D98);
                                                          })(),
                                                        ),
                                                      ),
                                                    ]
                                                  ]
                                                ],
                                              )
                                            : Text(
                                                'El equipo debe estar\nconectado para su uso',
                                                style: GoogleFonts.poppins(
                                                  color: color5,
                                                  fontSize: 15,
                                                ),
                                              ),
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: IconButton(
                                            icon: const Icon(
                                              HugeIcons.strokeRoundedDelete02,
                                              color: color0,
                                              size: 20,
                                            ),
                                            onPressed: () {
                                              _confirmDelete(
                                                  deviceName, productCode);
                                            },
                                          ),
                                        ),
                                      }
                                    ],
                                  ),
                                ),
                              );

                            case '050217_IOT':
                              bool estado = deviceDATA['w_status'] ?? false;
                              bool heaterOn = deviceDATA['f_status'] ?? false;

                              return Card(
                                key: ValueKey(deviceName),
                                color: color3,
                                margin: const EdgeInsets.symmetric(
                                    vertical: 5, horizontal: 10),
                                elevation: 2,
                                child: Theme(
                                  data: Theme.of(context).copyWith(
                                      dividerColor: Colors.transparent),
                                  child: ExpansionTile(
                                    tilePadding: const EdgeInsets.symmetric(
                                        horizontal: 16.0),
                                    iconColor: color6,
                                    collapsedIconColor: color6,
                                    title: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            SizedBox(
                                              width: MediaQuery.of(context)
                                                      .size
                                                      .width *
                                                  0.7,
                                              child: Text(
                                                nicknamesMap[deviceName] ??
                                                    deviceName,
                                                style: GoogleFonts.poppins(
                                                  color: color0,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                              ),
                                            ),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.start,
                                              spacing: 10,
                                              children: [
                                                Text(
                                                  online
                                                      ? '● CONECTADO'
                                                      : '● DESCONECTADO',
                                                  style: GoogleFonts.poppins(
                                                    color: online
                                                        ? Colors.green
                                                        : color5,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                                Icon(
                                                  online
                                                      ? Icons.cloud
                                                      : Icons.cloud_off,
                                                  color: online
                                                      ? Colors.green
                                                      : color5,
                                                  size: 15,
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    children: <Widget>[
                                      Stack(
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 16.0,
                                                vertical: 5.0),
                                            child: online
                                                ? Row(
                                                    children: [
                                                      estado
                                                          ? Row(
                                                              children: [
                                                                if (heaterOn) ...[
                                                                  Text(
                                                                    'Calentando',
                                                                    style: GoogleFonts
                                                                        .poppins(
                                                                      color: Colors
                                                                              .amber[
                                                                          800],
                                                                      fontSize:
                                                                          15,
                                                                    ),
                                                                  ),
                                                                  Icon(
                                                                    Icons
                                                                        .water_drop,
                                                                    size: 15,
                                                                    color: Colors
                                                                            .amber[
                                                                        800],
                                                                  ),
                                                                ] else ...[
                                                                  Text(
                                                                    'Encendido',
                                                                    style: GoogleFonts
                                                                        .poppins(
                                                                      color: Colors
                                                                          .green,
                                                                      fontSize:
                                                                          15,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ],
                                                            )
                                                          : Text(
                                                              'Apagado',
                                                              style: GoogleFonts
                                                                  .poppins(
                                                                      color:
                                                                          color6,
                                                                      fontSize:
                                                                          15),
                                                            ),
                                                      const SizedBox(width: 5),
                                                      owner
                                                          ? Switch(
                                                              activeColor:
                                                                  const Color(
                                                                      0xFF9C9D98),
                                                              activeTrackColor:
                                                                  const Color(
                                                                      0xFFB2B5AE),
                                                              inactiveThumbColor:
                                                                  const Color(
                                                                      0xFFB2B5AE),
                                                              inactiveTrackColor:
                                                                  const Color(
                                                                      0xFF9C9D98),
                                                              value: estado,
                                                              onChanged:
                                                                  (newValue) {
                                                                toggleState(
                                                                    deviceName,
                                                                    newValue);
                                                                setState(() {
                                                                  estado =
                                                                      newValue;
                                                                });
                                                              },
                                                            )
                                                          : const SizedBox(
                                                              height: 0,
                                                              width: 0),
                                                    ],
                                                  )
                                                : Text(
                                                    'El equipo debe estar\nconectado para su uso',
                                                    style: GoogleFonts.poppins(
                                                      color: color5,
                                                      fontSize: 15,
                                                    ),
                                                  ),
                                          ),
                                          Align(
                                            alignment: Alignment.centerRight,
                                            child: Padding(
                                              padding: const EdgeInsets.only(
                                                  right: 16.0, bottom: 8.0),
                                              child: IconButton(
                                                icon: const Icon(
                                                  HugeIcons
                                                      .strokeRoundedDelete02,
                                                  color: color0,
                                                  size: 20,
                                                ),
                                                onPressed: () {
                                                  _confirmDelete(
                                                      deviceName, productCode);
                                                },
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );

                            case '020020_IOT':
                              return Card(
                                key: ValueKey(deviceName),
                                color: color3,
                                margin: const EdgeInsets.symmetric(
                                    vertical: 5, horizontal: 10),
                                elevation: 2,
                                child: Theme(
                                  data: Theme.of(context).copyWith(
                                      dividerColor: Colors.transparent),
                                  child: ExpansionTile(
                                    tilePadding: const EdgeInsets.symmetric(
                                        horizontal: 16.0),
                                    iconColor: color6,
                                    collapsedIconColor: color6,
                                    title: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            SizedBox(
                                              width: MediaQuery.of(context)
                                                      .size
                                                      .width *
                                                  0.7,
                                              child: Text(
                                                nicknamesMap[deviceName] ??
                                                    deviceName,
                                                style: GoogleFonts.poppins(
                                                  color: color0,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                              ),
                                            ),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.start,
                                              spacing: 10,
                                              children: [
                                                Text(
                                                  online
                                                      ? '● CONECTADO'
                                                      : '● DESCONECTADO',
                                                  style: GoogleFonts.poppins(
                                                    color: online
                                                        ? Colors.green
                                                        : color5,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                                Icon(
                                                  online
                                                      ? Icons.cloud
                                                      : Icons.cloud_off,
                                                  color: online
                                                      ? Colors.green
                                                      : color5,
                                                  size: 15,
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    children: <Widget>[
                                      online
                                          ? Column(
                                              children: (deviceDATA.keys
                                                      .where((key) =>
                                                          key.startsWith(
                                                              'io') &&
                                                          RegExp(r'^io\d+$')
                                                              .hasMatch(key))
                                                      .where((ioKey) =>
                                                          deviceDATA[ioKey] !=
                                                          null)
                                                      .toList()
                                                    ..sort((a, b) {
                                                      int indexA = int.parse(
                                                          a.substring(2));
                                                      int indexB = int.parse(
                                                          b.substring(2));
                                                      return indexA
                                                          .compareTo(indexB);
                                                    }))
                                                  .map((ioKey) {
                                                // Extraer el índice del ioKey (ejemplo: "io0" -> 0)
                                                int i = int.parse(
                                                    ioKey.substring(2));
                                                Map<String, dynamic> equipo =
                                                    jsonDecode(
                                                        deviceDATA[ioKey]);
                                                printLog.i(
                                                  'Voy a realizar el cambio: $equipo',
                                                );
                                                String tipoWifi =
                                                    equipo['pinType']
                                                                .toString() ==
                                                            '0'
                                                        ? 'Salida'
                                                        : 'Entrada';
                                                bool estadoWifi =
                                                    equipo['w_status'];
                                                String comunWifi =
                                                    (equipo['r_state'] ?? '0')
                                                        .toString();
                                                bool entradaWifi =
                                                    tipoWifi == 'Entrada';
                                                return ListTile(
                                                  title: Row(
                                                    children: [
                                                      Text(
                                                        nicknamesMap[
                                                                '${deviceName}_$i'] ??
                                                            '$tipoWifi $i',
                                                        style:
                                                            GoogleFonts.poppins(
                                                          color: color0,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 5),
                                                    ],
                                                  ),
                                                  subtitle: Align(
                                                    alignment:
                                                        AlignmentDirectional
                                                            .centerStart,
                                                    child: Column(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .start,
                                                      children: [
                                                        entradaWifi
                                                            ? estadoWifi
                                                                ? comunWifi ==
                                                                        '1'
                                                                    ? Text(
                                                                        'Cerrado',
                                                                        style: GoogleFonts
                                                                            .poppins(
                                                                          color:
                                                                              Colors.green,
                                                                          fontSize:
                                                                              15,
                                                                          fontWeight:
                                                                              FontWeight.bold,
                                                                        ),
                                                                      )
                                                                    : Text(
                                                                        'Abierto',
                                                                        style: GoogleFonts
                                                                            .poppins(
                                                                          color:
                                                                              color6,
                                                                          fontSize:
                                                                              15,
                                                                          fontWeight:
                                                                              FontWeight.bold,
                                                                        ),
                                                                      )
                                                                : comunWifi ==
                                                                        '1'
                                                                    ? Text(
                                                                        'Abierto',
                                                                        style: GoogleFonts
                                                                            .poppins(
                                                                          color:
                                                                              color6,
                                                                          fontSize:
                                                                              15,
                                                                          fontWeight:
                                                                              FontWeight.bold,
                                                                        ),
                                                                      )
                                                                    : Text(
                                                                        'Cerrado',
                                                                        style: GoogleFonts
                                                                            .poppins(
                                                                          color:
                                                                              Colors.green,
                                                                          fontSize:
                                                                              15,
                                                                          fontWeight:
                                                                              FontWeight.bold,
                                                                        ),
                                                                      )
                                                            : estadoWifi
                                                                ? Text(
                                                                    'Encendido',
                                                                    style: GoogleFonts
                                                                        .poppins(
                                                                      color: Colors
                                                                          .green,
                                                                      fontSize:
                                                                          15,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                    ),
                                                                  )
                                                                : Text(
                                                                    'Apagado',
                                                                    style: GoogleFonts
                                                                        .poppins(
                                                                      color:
                                                                          color6,
                                                                      fontSize:
                                                                          15,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                    ),
                                                                  ),
                                                      ],
                                                    ),
                                                  ),
                                                  trailing: owner
                                                      ? entradaWifi
                                                          ? estadoWifi
                                                              ? comunWifi == '1'
                                                                  ? const Icon(
                                                                      Icons
                                                                          .new_releases,
                                                                      color: Color(
                                                                          0xff9b9b9b),
                                                                    )
                                                                  : const Icon(
                                                                      Icons
                                                                          .new_releases,
                                                                      color:
                                                                          color6,
                                                                    )
                                                              : comunWifi == '1'
                                                                  ? const Icon(
                                                                      Icons
                                                                          .new_releases,
                                                                      color:
                                                                          color6,
                                                                    )
                                                                  : const Icon(
                                                                      Icons
                                                                          .new_releases,
                                                                      color: Color(
                                                                          0xff9b9b9b),
                                                                    )
                                                          : Switch(
                                                              activeColor:
                                                                  const Color(
                                                                      0xFF9C9D98),
                                                              activeTrackColor:
                                                                  const Color(
                                                                      0xFFB2B5AE),
                                                              inactiveThumbColor:
                                                                  const Color(
                                                                      0xFFB2B5AE),
                                                              inactiveTrackColor:
                                                                  const Color(
                                                                      0xFF9C9D98),
                                                              value: estadoWifi,
                                                              onChanged:
                                                                  (value) {
                                                                String topic =
                                                                    'devices_rx/$productCode/$serialNumber';
                                                                String topic2 =
                                                                    'devices_tx/$productCode/$serialNumber';
                                                                String message =
                                                                    jsonEncode({
                                                                  'pinType':
                                                                      tipoWifi ==
                                                                              'Salida'
                                                                          ? 0
                                                                          : 1,
                                                                  'index': i,
                                                                  'w_status':
                                                                      value,
                                                                  'r_state':
                                                                      comunWifi,
                                                                });
                                                                sendMessagemqtt(
                                                                    topic,
                                                                    message);
                                                                sendMessagemqtt(
                                                                    topic2,
                                                                    message);
                                                                setState(() {
                                                                  estadoWifi =
                                                                      value;
                                                                });
                                                                globalDATA
                                                                    .putIfAbsent(
                                                                        '$productCode/$serialNumber',
                                                                        () =>
                                                                            {})
                                                                    .addAll({
                                                                  'io$i':
                                                                      message
                                                                });
                                                                saveGlobalData(
                                                                    globalDATA);
                                                              },
                                                            )
                                                      : null,
                                                );
                                              }).toList(),
                                            )
                                          : const SizedBox(height: 0),
                                      Stack(
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                left: 20.0),
                                            child: !online
                                                ? Text(
                                                    'El equipo debe estar\nconectado para su uso',
                                                    style: GoogleFonts.poppins(
                                                      color: color5,
                                                      fontSize: 15,
                                                    ),
                                                  )
                                                : const SizedBox(height: 0),
                                          ),
                                          Align(
                                            alignment: Alignment.centerRight,
                                            child: Padding(
                                              padding: const EdgeInsets.only(
                                                  right: 16.0, bottom: 8.0),
                                              child: IconButton(
                                                icon: const Icon(
                                                  HugeIcons
                                                      .strokeRoundedDelete02,
                                                  color: color0,
                                                  size: 20,
                                                ),
                                                onPressed: () {
                                                  _confirmDelete(
                                                      deviceName, productCode);
                                                },
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );

                            case '041220_IOT':
                              bool estado = deviceDATA['w_status'] ?? false;
                              bool heaterOn = deviceDATA['f_status'] ?? false;

                              return Card(
                                key: ValueKey(deviceName),
                                color: color3,
                                margin: const EdgeInsets.symmetric(
                                    vertical: 5, horizontal: 10),
                                elevation: 2,
                                child: Theme(
                                  data: Theme.of(context).copyWith(
                                      dividerColor: Colors.transparent),
                                  child: ExpansionTile(
                                    tilePadding: const EdgeInsets.symmetric(
                                        horizontal: 16.0),
                                    iconColor: color6,
                                    collapsedIconColor: color6,
                                    title: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            SizedBox(
                                              width: MediaQuery.of(context)
                                                      .size
                                                      .width *
                                                  0.7,
                                              child: Text(
                                                nicknamesMap[deviceName] ??
                                                    deviceName,
                                                style: GoogleFonts.poppins(
                                                  color: color0,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                              ),
                                            ),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.start,
                                              spacing: 10,
                                              children: [
                                                Text(
                                                  online
                                                      ? '● CONECTADO'
                                                      : '● DESCONECTADO',
                                                  style: GoogleFonts.poppins(
                                                    color: online
                                                        ? Colors.green
                                                        : color5,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                                Icon(
                                                  online
                                                      ? Icons.cloud
                                                      : Icons.cloud_off,
                                                  color: online
                                                      ? Colors.green
                                                      : color5,
                                                  size: 15,
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    children: <Widget>[
                                      Stack(
                                        children: [
                                          Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 16.0,
                                                      vertical: 5.0),
                                              child: online
                                                  ? Row(
                                                      children: [
                                                        estado
                                                            ? Row(
                                                                children: [
                                                                  if (heaterOn) ...[
                                                                    Text(
                                                                      'Calentando',
                                                                      style: GoogleFonts
                                                                          .poppins(
                                                                        color: Colors
                                                                            .amber[800],
                                                                        fontSize:
                                                                            15,
                                                                      ),
                                                                    ),
                                                                    Icon(
                                                                      HugeIcons
                                                                          .strokeRoundedFlash,
                                                                      size: 15,
                                                                      color: Colors
                                                                              .amber[
                                                                          800],
                                                                    ),
                                                                  ] else ...[
                                                                    Text(
                                                                      'Encendido',
                                                                      style: GoogleFonts
                                                                          .poppins(
                                                                        color: Colors
                                                                            .green,
                                                                        fontSize:
                                                                            15,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ],
                                                              )
                                                            : Text(
                                                                'Apagado',
                                                                style: GoogleFonts
                                                                    .poppins(
                                                                        color:
                                                                            color6,
                                                                        fontSize:
                                                                            15),
                                                              ),
                                                        const SizedBox(
                                                            width: 5),
                                                        owner
                                                            ? Switch(
                                                                activeColor:
                                                                    const Color(
                                                                        0xFF9C9D98),
                                                                activeTrackColor:
                                                                    const Color(
                                                                        0xFFB2B5AE),
                                                                inactiveThumbColor:
                                                                    const Color(
                                                                        0xFFB2B5AE),
                                                                inactiveTrackColor:
                                                                    const Color(
                                                                        0xFF9C9D98),
                                                                value: estado,
                                                                onChanged:
                                                                    (newValue) {
                                                                  toggleState(
                                                                      deviceName,
                                                                      newValue);
                                                                  setState(() {
                                                                    estado =
                                                                        newValue;
                                                                  });
                                                                },
                                                              )
                                                            : const SizedBox(
                                                                height: 0,
                                                                width: 0),
                                                      ],
                                                    )
                                                  : Text(
                                                      'El equipo debe estar\nconectado para su uso',
                                                      style:
                                                          GoogleFonts.poppins(
                                                        color: color5,
                                                        fontSize: 15,
                                                      ),
                                                    )),
                                          Align(
                                            alignment: Alignment.centerRight,
                                            child: Padding(
                                              padding: const EdgeInsets.only(
                                                  right: 16.0, bottom: 8.0),
                                              child: IconButton(
                                                icon: const Icon(
                                                  HugeIcons
                                                      .strokeRoundedDelete02,
                                                  color: color0,
                                                  size: 20,
                                                ),
                                                onPressed: () {
                                                  _confirmDelete(
                                                      deviceName, productCode);
                                                },
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );

                            case '028000_IOT':
                              bool estado = deviceDATA['w_status'] ?? false;
                              bool heaterOn = deviceDATA['f_status'] ?? false;

                              return Card(
                                key: ValueKey(deviceName),
                                color: color3,
                                margin: const EdgeInsets.symmetric(
                                    vertical: 5, horizontal: 10),
                                elevation: 2,
                                child: Theme(
                                  data: Theme.of(context).copyWith(
                                      dividerColor: Colors.transparent),
                                  child: ExpansionTile(
                                    tilePadding: const EdgeInsets.symmetric(
                                        horizontal: 16.0),
                                    iconColor: color6,
                                    collapsedIconColor: color6,
                                    title: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            SizedBox(
                                              width: MediaQuery.of(context)
                                                      .size
                                                      .width *
                                                  0.7,
                                              child: Text(
                                                nicknamesMap[deviceName] ??
                                                    deviceName,
                                                style: GoogleFonts.poppins(
                                                  color: color0,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                              ),
                                            ),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.start,
                                              spacing: 10,
                                              children: [
                                                Text(
                                                  online
                                                      ? '● CONECTADO'
                                                      : '● DESCONECTADO',
                                                  style: GoogleFonts.poppins(
                                                    color: online
                                                        ? Colors.green
                                                        : color5,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                                Icon(
                                                  online
                                                      ? Icons.cloud
                                                      : Icons.cloud_off,
                                                  color: online
                                                      ? Colors.green
                                                      : color5,
                                                  size: 15,
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    children: <Widget>[
                                      Stack(
                                        children: [
                                          Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 16.0,
                                                      vertical: 5.0),
                                              child: online
                                                  ? Row(
                                                      children: [
                                                        estado
                                                            ? Row(
                                                                children: [
                                                                  if (heaterOn) ...[
                                                                    Text(
                                                                      'Enfriando',
                                                                      style: GoogleFonts
                                                                          .poppins(
                                                                        color: Colors
                                                                            .lightBlueAccent
                                                                            .shade400,
                                                                        fontSize:
                                                                            15,
                                                                      ),
                                                                    ),
                                                                    Icon(
                                                                      HugeIcons
                                                                          .strokeRoundedSnow,
                                                                      size: 15,
                                                                      color: Colors
                                                                          .lightBlueAccent
                                                                          .shade400,
                                                                    ),
                                                                  ] else ...[
                                                                    Text(
                                                                      'Encendido',
                                                                      style: GoogleFonts
                                                                          .poppins(
                                                                        color: Colors
                                                                            .green,
                                                                        fontSize:
                                                                            15,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ],
                                                              )
                                                            : Text(
                                                                'Apagado',
                                                                style: GoogleFonts
                                                                    .poppins(
                                                                        color:
                                                                            color6,
                                                                        fontSize:
                                                                            15),
                                                              ),
                                                        const SizedBox(
                                                            width: 5),
                                                        owner
                                                            ? Switch(
                                                                activeColor:
                                                                    const Color(
                                                                        0xFF9C9D98),
                                                                activeTrackColor:
                                                                    const Color(
                                                                        0xFFB2B5AE),
                                                                inactiveThumbColor:
                                                                    const Color(
                                                                        0xFFB2B5AE),
                                                                inactiveTrackColor:
                                                                    const Color(
                                                                        0xFF9C9D98),
                                                                value: estado,
                                                                onChanged:
                                                                    (newValue) {
                                                                  toggleState(
                                                                      deviceName,
                                                                      newValue);
                                                                  setState(() {
                                                                    estado =
                                                                        newValue;
                                                                  });
                                                                },
                                                              )
                                                            : const SizedBox(
                                                                height: 0,
                                                                width: 0),
                                                      ],
                                                    )
                                                  : Text(
                                                      'El equipo debe estar\nconectado para su uso',
                                                      style:
                                                          GoogleFonts.poppins(
                                                        color: color5,
                                                        fontSize: 15,
                                                      ),
                                                    )),
                                          Align(
                                            alignment: Alignment.centerRight,
                                            child: Padding(
                                              padding: const EdgeInsets.only(
                                                  right: 16.0, bottom: 8.0),
                                              child: IconButton(
                                                icon: const Icon(
                                                  HugeIcons
                                                      .strokeRoundedDelete02,
                                                  color: color0,
                                                  size: 20,
                                                ),
                                                onPressed: () {
                                                  _confirmDelete(
                                                      deviceName, productCode);
                                                },
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );

                            case '023430_IOT':
                              String temp = deviceDATA['actualTemp'].toString();
                              bool alertMaxFlag =
                                  deviceDATA['alert_maxflag'] ?? false;
                              bool alertMinFlag =
                                  deviceDATA['alert_minflag'] ?? false;
                              return Card(
                                key: ValueKey(deviceName),
                                color: color3,
                                margin: const EdgeInsets.symmetric(
                                    vertical: 5, horizontal: 10),
                                elevation: 2,
                                child: Theme(
                                  data: Theme.of(context).copyWith(
                                      dividerColor: Colors.transparent),
                                  child: ExpansionTile(
                                    tilePadding: const EdgeInsets.symmetric(
                                        horizontal: 16.0),
                                    iconColor: color6,
                                    collapsedIconColor: color6,
                                    title: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            SizedBox(
                                              width: MediaQuery.of(context)
                                                      .size
                                                      .width *
                                                  0.7,
                                              child: Text(
                                                nicknamesMap[deviceName] ??
                                                    deviceName,
                                                style: GoogleFonts.poppins(
                                                  color: color0,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                              ),
                                            ),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.start,
                                              spacing: 10,
                                              children: [
                                                Text(
                                                  online
                                                      ? '● CONECTADO'
                                                      : '● DESCONECTADO',
                                                  style: GoogleFonts.poppins(
                                                    color: online
                                                        ? Colors.green
                                                        : color5,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                                Icon(
                                                  online
                                                      ? Icons.cloud
                                                      : Icons.cloud_off,
                                                  color: online
                                                      ? Colors.green
                                                      : color5,
                                                  size: 15,
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    children: <Widget>[
                                      ListTile(
                                        title: online
                                            ? Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Temperatura: $temp °C',
                                                    style: GoogleFonts.poppins(
                                                      color: color0,
                                                      fontSize: 15,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                  Row(
                                                    children: [
                                                      Text(
                                                        'Alerta máxima:',
                                                        style:
                                                            GoogleFonts.poppins(
                                                          color: color0,
                                                          fontSize: 15,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 5),
                                                      alertMaxFlag
                                                          ? const Icon(
                                                              HugeIcons
                                                                  .strokeRoundedAlert02,
                                                              color: color6,
                                                            )
                                                          : const Icon(
                                                              HugeIcons
                                                                  .strokeRoundedTemperature,
                                                              color:
                                                                  Colors.green,
                                                            ),
                                                    ],
                                                  ),
                                                  Row(
                                                    children: [
                                                      Text(
                                                        'Alerta mínima:',
                                                        style:
                                                            GoogleFonts.poppins(
                                                          color: color0,
                                                          fontSize: 15,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 5),
                                                      alertMinFlag
                                                          ? const Icon(
                                                              HugeIcons
                                                                  .strokeRoundedAlert02,
                                                              color: color6,
                                                            )
                                                          : const Icon(
                                                              HugeIcons
                                                                  .strokeRoundedTemperature,
                                                              color:
                                                                  Colors.green,
                                                            ),
                                                    ],
                                                  ),
                                                ],
                                              )
                                            : Text(
                                                'El equipo debe estar\nconectado para su uso',
                                                style: GoogleFonts.poppins(
                                                  color: color5,
                                                  fontSize: 15,
                                                ),
                                              ),
                                      ),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: Padding(
                                          padding: const EdgeInsets.only(
                                              right: 16.0, bottom: 8.0),
                                          child: IconButton(
                                            icon: const Icon(
                                              HugeIcons.strokeRoundedDelete02,
                                              color: color0,
                                              size: 20,
                                            ),
                                            onPressed: () {
                                              _confirmDelete(
                                                  deviceName, productCode);
                                            },
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            default:
                              return Container(
                                key: ValueKey(deviceName),
                              );
                          }
                        } catch (e) {
                          printLog
                              .e('Error al procesar el equipo $deviceName: $e');
                          return Card(
                            key: ValueKey('${deviceName}_error'),
                            color: color3,
                            margin: const EdgeInsets.symmetric(
                                vertical: 5, horizontal: 10),
                            elevation: 2,
                            child: Theme(
                                data: Theme.of(context)
                                    .copyWith(dividerColor: Colors.transparent),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ListTile(
                                      title: Text(
                                        nicknamesMap[deviceName] ?? deviceName,
                                        style: GoogleFonts.poppins(
                                          color: color0,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      subtitle: Text(
                                        'Por favor, verifica la conexión y actualice su equipo.',
                                        style: GoogleFonts.poppins(
                                          color: color1,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                  ],
                                )),
                          );
                        }
                      } else {
                        String devicesInGroup = deviceName;
                        List<String> deviceList = devicesInGroup
                            .replaceAll('[', '')
                            .replaceAll(']', '')
                            .split(',');
                        List<String> nicksList = [];
                        for (String equipo in deviceList) {
                          String displayName = '';
                          if (equipo.contains('_')) {
                            final parts = equipo.split('_');
                            displayName = nicknamesMap[equipo.trim()] ??
                                '${parts[0]} salida ${parts[1]}';
                          } else {
                            displayName =
                                nicknamesMap[equipo.trim()] ?? equipo.trim();
                          }

                          nicksList.add(displayName);
                        }

                        for (String device in deviceList) {
                          String equipo = DeviceManager.getProductCode(device);
                          String serial = DeviceManager.extractSerialNumber(
                            device,
                          );

                          final deviceSpecificData = ref.watch(
                            globalDataProvider.select(
                              (map) => map['$equipo/$serial'] ?? {},
                            ),
                          );

                          globalDATA
                              .putIfAbsent('$equipo/$serial', () => {})
                              .addAll(deviceSpecificData);
                        }

                        bool online = isGroupOnline(devicesInGroup);
                        bool estado = isGroupOn(devicesInGroup);
                        bool owner = canControlGroup(devicesInGroup);

                        return Card(
                          key: ValueKey(deviceName),
                          color: color3,
                          margin: const EdgeInsets.symmetric(
                            vertical: 5,
                            horizontal: 10,
                          ),
                          elevation: 2,
                          child: Theme(
                            data: Theme.of(
                              context,
                            ).copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              tilePadding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                              ),
                              iconColor: color6,
                              collapsedIconColor: color6,
                              onExpansionChanged: (bool expanded) {
                                setState(() {
                                  _expandedStates[deviceName] = expanded;
                                });
                              },
                              title: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          grupo[0].toUpperCase() +
                                              grupo.substring(1),
                                          style: GoogleFonts.poppins(
                                            color: color0,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          nicksList
                                              .toString()
                                              .replaceAll('[', '')
                                              .replaceAll(']', ''),
                                          style: GoogleFonts.poppins(
                                            color: color1,
                                            fontSize: 15,
                                          ),
                                          overflow:
                                              _expandedStates[deviceName] ==
                                                      true
                                                  ? TextOverflow.visible
                                                  : TextOverflow.ellipsis,
                                          maxLines:
                                              _expandedStates[deviceName] ==
                                                      true
                                                  ? null
                                                  : 1,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              children: <Widget>[
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16.0,
                                    vertical: 5.0,
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      online
                                          ? estado
                                              ? Text(
                                                  'Encendido',
                                                  style: GoogleFonts.poppins(
                                                    color: Colors.green,
                                                    fontSize: 15,
                                                  ),
                                                )
                                              : Text(
                                                  'Apagado',
                                                  style: GoogleFonts.poppins(
                                                    color: color6,
                                                    fontSize: 15,
                                                  ),
                                                )
                                          : Text(
                                              'Todos los equipos deben estar\nconectados para su uso',
                                              style: GoogleFonts.poppins(
                                                color: color6,
                                                fontSize: 15,
                                              ),
                                            ),
                                      owner && online
                                          ? Switch(
                                              activeColor:
                                                  const Color(0xFF9C9D98),
                                              activeTrackColor: const Color(
                                                0xFFB2B5AE,
                                              ),
                                              inactiveThumbColor: const Color(
                                                0xFFB2B5AE,
                                              ),
                                              inactiveTrackColor: const Color(
                                                0xFF9C9D98,
                                              ),
                                              value: estado,
                                              onChanged: (newValue) {
                                                controlGroup(
                                                  currentUserEmail,
                                                  newValue,
                                                  grupo,
                                                );
                                              },
                                            )
                                          : const SizedBox(height: 0, width: 0),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                    },
                    proxyDecorator:
                        (Widget child, int index, Animation<double> animation) {
                      return Material(
                        color: Colors.transparent,
                        child: child,
                      );
                    },
                  ),
      ),
    );
  }
}
