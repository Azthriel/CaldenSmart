import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:caldensmart/master.dart';
import 'package:caldensmart/Global/stored_data.dart';
import 'package:caldensmart/aws/mqtt/mqtt.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import '../aws/dynamo/dynamo.dart';
import '../aws/dynamo/dynamo_certificates.dart';
import 'package:caldensmart/logger.dart';

class WifiPage extends StatefulWidget {
  const WifiPage({super.key});

  @override
  State<WifiPage> createState() => WifiPageState();
}

class WifiPageState extends State<WifiPage> {
  bool charging = false;
  static bool _hasInitialized = false;

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
    await getDevices(service, currentUserEmail);
    await getGroups(service, currentUserEmail);
    eventosCreados = await getEventos(service, currentUserEmail);

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
              onPressed: () {
                setState(() {
                  previusConnections.remove(deviceName);
                  putPreviusConnections(
                      service, currentUserEmail, previusConnections);
                  for (String device in alexaDevices) {
                    device.contains(deviceName)
                        ? alexaDevices.remove(device)
                        : null;
                  }
                  putDevicesForAlexa(
                      service, currentUserEmail, previusConnections);
                  todosLosDispositivos.removeAt(todosLosDispositivos
                      .indexWhere((element) => element.value == deviceName));
                  String topic =
                      'devices_tx/$equipo/${DeviceManager.extractSerialNumber(deviceName)}';
                  unSubToTopicMQTT(topic);
                  topicsToSub.remove(topic);
                });
                Navigator.of(context).pop();
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
    String url = urlEscenas;
    Uri uri = Uri.parse(url);

    String bd = jsonEncode(
      {
        'caso': 'Grupos',
        'email': email,
        'on': state,
        'grupo': grupo,
      },
    );

    printLog.i('Body: $bd');

    var response = await http.post(uri, body: bd);

    if (response.statusCode == 200) {
      printLog.i('Grupo controlado');
      showToast('Grupo ${state ? 'encendido' : 'apagado'} correctamente');
    } else {
      printLog.e('Error al controlar el grupo');
      printLog.e(response.body);
      showToast('Error al controlar el grupo');
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
                      return Consumer<GlobalDataNotifier>(
                        key: Key(deviceName + grupo),
                        builder: (context, notifier, child) {
                          if (!esGrupo) {
                            String equipo =
                                DeviceManager.getProductCode(deviceName);
                            String serial =
                                DeviceManager.extractSerialNumber(deviceName);
                            Map<String, dynamic> topicData =
                                notifier.getData('$equipo/$serial');
                            // printLog.i('Llego un cambio en ${'$equipo/$serial'}',
                            //     'Magenta');
                            // printLog.i('Y fue el siguiente: $topicData', 'magenta');
                            globalDATA
                                .putIfAbsent('$equipo/$serial', () => {})
                                .addAll(topicData);
                            saveGlobalData(globalDATA);
                            Map<String, dynamic> deviceDATA =
                                globalDATA['$equipo/$serial'] ?? {};
                            // printLog.i(deviceDATA, 'cyan');

                            // printLog.i(
                            //     "Las keys del equipo ${deviceDATA.keys}", 'rojo');

                            bool online = deviceDATA['cstate'] ?? false;

                            List<dynamic> admins =
                                deviceDATA['secondary_admin'] ?? [];

                            bool owner =
                                deviceDATA['owner'] == currentUserEmail ||
                                    admins.contains(deviceName) ||
                                    deviceDATA['owner'] == '' ||
                                    deviceDATA['owner'] == null;

                            try {
                              switch (equipo) {
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
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
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
                                                      style:
                                                          GoogleFonts.poppins(
                                                        color: online
                                                            ? Colors.green
                                                            : color6,
                                                        fontSize: 15,
                                                      ),
                                                    ),
                                                    Icon(
                                                      online
                                                          ? Icons.cloud
                                                          : Icons.cloud_off,
                                                      color: online
                                                          ? Colors.green
                                                          : color6,
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
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        'PPM CO: $ppmCO',
                                                        style:
                                                            GoogleFonts.poppins(
                                                          color: color0,
                                                          fontSize: 15,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                      Text(
                                                        'CH4 LIE: ${(ppmCH4 / 500).round()}%',
                                                        style:
                                                            GoogleFonts.poppins(
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
                                                            style: GoogleFonts
                                                                .poppins(
                                                              color: color0,
                                                              fontSize: 15,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                              width: 5),
                                                          alert
                                                              ? const Icon(
                                                                  HugeIcons
                                                                      .strokeRoundedAlert02,
                                                                  color: color6,
                                                                )
                                                              : const Icon(
                                                                  HugeIcons
                                                                      .strokeRoundedLeaf01,
                                                                  color: Colors
                                                                      .green,
                                                                ),
                                                        ],
                                                      ),
                                                    ],
                                                  )
                                                : Text(
                                                    'El equipo debe estar\nconectado para su uso',
                                                    style: GoogleFonts.poppins(
                                                      color: color6,
                                                      fontSize: 15,
                                                    ),
                                                  ),
                                            trailing: IconButton(
                                              icon: const Icon(
                                                HugeIcons.strokeRoundedDelete02,
                                                color: color0,
                                                size: 20,
                                              ),
                                              onPressed: () {
                                                _confirmDelete(
                                                    deviceName, equipo);
                                              },
                                            ),
                                          )
                                        ],
                                      ),
                                    ),
                                  );
                                case '022000_IOT':
                                  bool estado = deviceDATA['w_status'] ?? false;
                                  bool heaterOn =
                                      deviceDATA['f_status'] ?? false;

                                  return Card(
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
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
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
                                                      style:
                                                          GoogleFonts.poppins(
                                                        color: online
                                                            ? Colors.green
                                                            : color6,
                                                        fontSize: 15,
                                                      ),
                                                    ),
                                                    Icon(
                                                      online
                                                          ? Icons.cloud
                                                          : Icons.cloud_off,
                                                      color: online
                                                          ? Colors.green
                                                          : color6,
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
                                                horizontal: 16.0,
                                                vertical: 5.0),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
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
                                                                          color:
                                                                              Colors.amber[800],
                                                                          fontSize:
                                                                              15,
                                                                        ),
                                                                      ),
                                                                      Icon(
                                                                        HugeIcons
                                                                            .strokeRoundedFlash,
                                                                        size:
                                                                            15,
                                                                        color: Colors
                                                                            .amber[800],
                                                                      ),
                                                                    ] else ...[
                                                                      Text(
                                                                        'Encendido',
                                                                        style: GoogleFonts
                                                                            .poppins(
                                                                          color:
                                                                              Colors.green,
                                                                          fontSize:
                                                                              15,
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ],
                                                                )
                                                              : Text(
                                                                  'Apagado',
                                                                  style: GoogleFonts.poppins(
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
                                                                    setState(
                                                                        () {
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
                                                          color: color6,
                                                          fontSize: 15,
                                                        ),
                                                      ),
                                                IconButton(
                                                  icon: const Icon(
                                                    HugeIcons
                                                        .strokeRoundedDelete02,
                                                    color: color0,
                                                    size: 20,
                                                  ),
                                                  onPressed: () {
                                                    _confirmDelete(
                                                        deviceName, equipo);
                                                  },
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                case '027000_IOT':
                                  bool estado = deviceDATA['w_status'] ?? false;
                                  bool heaterOn =
                                      deviceDATA['f_status'] ?? false;
                                  return Card(
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
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
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
                                                      style:
                                                          GoogleFonts.poppins(
                                                        color: online
                                                            ? Colors.green
                                                            : color6,
                                                        fontSize: 15,
                                                      ),
                                                    ),
                                                    Icon(
                                                      online
                                                          ? Icons.cloud
                                                          : Icons.cloud_off,
                                                      color: online
                                                          ? Colors.green
                                                          : color6,
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
                                                horizontal: 16.0,
                                                vertical: 5.0),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
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
                                                                          color:
                                                                              Colors.amber[800],
                                                                          fontSize:
                                                                              15,
                                                                        ),
                                                                      ),
                                                                      Icon(
                                                                        HugeIcons
                                                                            .strokeRoundedFire,
                                                                        size:
                                                                            15,
                                                                        color: Colors
                                                                            .amber[800],
                                                                      ),
                                                                    ] else ...[
                                                                      Text(
                                                                        'Encendido',
                                                                        style: GoogleFonts
                                                                            .poppins(
                                                                          color:
                                                                              Colors.green,
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
                                                                        15,
                                                                  ),
                                                                ),
                                                          const SizedBox(
                                                              width: 5),
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
                                                                      setState(
                                                                          () {
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
                                                        style:
                                                            GoogleFonts.poppins(
                                                          color: color6,
                                                          fontSize: 15,
                                                        ),
                                                      ),
                                                IconButton(
                                                  icon: const Icon(
                                                    HugeIcons
                                                        .strokeRoundedDelete02,
                                                    color: color0,
                                                    size: 20,
                                                  ),
                                                  onPressed: () {
                                                    _confirmDelete(
                                                        deviceName, equipo);
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
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
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
                                                      style:
                                                          GoogleFonts.poppins(
                                                        color: online
                                                            ? Colors.green
                                                            : color6,
                                                        fontSize: 15,
                                                      ),
                                                    ),
                                                    Icon(
                                                      online
                                                          ? Icons.cloud
                                                          : Icons.cloud_off,
                                                      color: online
                                                          ? Colors.green
                                                          : color6,
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
                                                  children: List.generate(
                                                    deviceDATA.keys
                                                        .where((key) =>
                                                            key.contains('io'))
                                                        .length,
                                                    (i) {
                                                      if (deviceDATA['io$i'] ==
                                                          null) {
                                                        return ListTile(
                                                          title: Text(
                                                            'Error en el equipo',
                                                            style: GoogleFonts
                                                                .poppins(
                                                              color: color0,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                          ),
                                                          subtitle: Text(
                                                            'Se solucionara automaticamente en poco tiempo...',
                                                            style: GoogleFonts
                                                                .poppins(
                                                              color: color0,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .normal,
                                                            ),
                                                          ),
                                                        );
                                                      } else {
                                                        Map<String, dynamic>
                                                            equipo = jsonDecode(
                                                                deviceDATA[
                                                                    'io$i']);
                                                        printLog.i(
                                                          'Voy a realizar el cambio: $equipo',
                                                        );
                                                        String tipoWifi = equipo[
                                                                        'pinType']
                                                                    .toString() ==
                                                                '0'
                                                            ? 'Salida'
                                                            : 'Entrada';
                                                        bool estadoWifi =
                                                            equipo['w_status'];
                                                        String comunWifi =
                                                            (equipo['r_state'] ??
                                                                    '0')
                                                                .toString();
                                                        bool entradaWifi =
                                                            tipoWifi ==
                                                                'Entrada';
                                                        return ListTile(
                                                          title: Row(
                                                            children: [
                                                              Text(
                                                                nicknamesMap[
                                                                        '${deviceName}_$i'] ??
                                                                    '$tipoWifi $i',
                                                                style:
                                                                    GoogleFonts
                                                                        .poppins(
                                                                  color: color0,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
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
                                                                                style: GoogleFonts.poppins(
                                                                                  color: Colors.green,
                                                                                  fontSize: 15,
                                                                                  fontWeight: FontWeight.bold,
                                                                                ),
                                                                              )
                                                                            : Text(
                                                                                'Abierto',
                                                                                style: GoogleFonts.poppins(
                                                                                  color: color6,
                                                                                  fontSize: 15,
                                                                                  fontWeight: FontWeight.bold,
                                                                                ),
                                                                              )
                                                                        : comunWifi ==
                                                                                '1'
                                                                            ? Text(
                                                                                'Abierto',
                                                                                style: GoogleFonts.poppins(
                                                                                  color: color6,
                                                                                  fontSize: 15,
                                                                                  fontWeight: FontWeight.bold,
                                                                                ),
                                                                              )
                                                                            : Text(
                                                                                'Cerrado',
                                                                                style: GoogleFonts.poppins(
                                                                                  color: Colors.green,
                                                                                  fontSize: 15,
                                                                                  fontWeight: FontWeight.bold,
                                                                                ),
                                                                              )
                                                                    : estadoWifi
                                                                        ? Text(
                                                                            'Encendido',
                                                                            style:
                                                                                GoogleFonts.poppins(
                                                                              color: Colors.green,
                                                                              fontSize: 15,
                                                                              fontWeight: FontWeight.bold,
                                                                            ),
                                                                          )
                                                                        : Text(
                                                                            'Apagado',
                                                                            style:
                                                                                GoogleFonts.poppins(
                                                                              color: color6,
                                                                              fontSize: 15,
                                                                              fontWeight: FontWeight.bold,
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
                                                                              Icons.new_releases,
                                                                              color: Color(
                                                                                0xff9b9b9b,
                                                                              ),
                                                                            )
                                                                          : const Icon(
                                                                              Icons.new_releases,
                                                                              color: color6,
                                                                            )
                                                                      : comunWifi ==
                                                                              '1'
                                                                          ? const Icon(
                                                                              Icons.new_releases,
                                                                              color: color6,
                                                                            )
                                                                          : const Icon(
                                                                              Icons.new_releases,
                                                                              color: Color(
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
                                                                        String
                                                                            deviceSerialNumber =
                                                                            DeviceManager.extractSerialNumber(deviceName);
                                                                        String
                                                                            topic =
                                                                            'devices_rx/${DeviceManager.getProductCode(deviceName)}/$deviceSerialNumber';
                                                                        String
                                                                            topic2 =
                                                                            'devices_tx/${DeviceManager.getProductCode(deviceName)}/$deviceSerialNumber';
                                                                        String
                                                                            message =
                                                                            jsonEncode({
                                                                          'pinType': tipoWifi == 'Salida'
                                                                              ? 0
                                                                              : 1,
                                                                          'index':
                                                                              i,
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
                                                                        setState(
                                                                            () {
                                                                          estadoWifi =
                                                                              value;
                                                                        });
                                                                        globalDATA
                                                                            .putIfAbsent(
                                                                                '${DeviceManager.getProductCode(deviceName)}/$deviceSerialNumber',
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
                                                      }
                                                    },
                                                  ),
                                                )
                                              : const SizedBox(height: 0),
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                left: 20.0),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: <Widget>[
                                                !online
                                                    ? Text(
                                                        'El equipo debe estar\nconectado para su uso',
                                                        style:
                                                            GoogleFonts.poppins(
                                                          color: color6,
                                                          fontSize: 15,
                                                        ),
                                                      )
                                                    : const SizedBox(height: 0),
                                                IconButton(
                                                  icon: const Icon(
                                                    HugeIcons
                                                        .strokeRoundedDelete02,
                                                    color: color0,
                                                    size: 20,
                                                  ),
                                                  onPressed: () {
                                                    _confirmDelete(
                                                        deviceName, equipo);
                                                  },
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                case '027313_IOT':
                                  bool estado = deviceDATA['w_status'] ?? false;
                                  // bool isNC = deviceDATA['isNC'] ?? false;

                                  return Card(
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
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
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
                                                      style:
                                                          GoogleFonts.poppins(
                                                        color: online
                                                            ? Colors.green
                                                            : color6,
                                                        fontSize: 15,
                                                      ),
                                                    ),
                                                    Icon(
                                                      online
                                                          ? Icons.cloud
                                                          : Icons.cloud_off,
                                                      color: online
                                                          ? Colors.green
                                                          : color6,
                                                      size: 15,
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        children: <Widget>[
                                          if (!deviceDATA.keys
                                              .contains('io')) ...{
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 16.0,
                                                      vertical: 5.0),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  online
                                                      ? Row(
                                                          children: [
                                                            estado
                                                                ? Text(
                                                                    'ENCENDIDO',
                                                                    style: GoogleFonts
                                                                        .poppins(
                                                                      color: Colors
                                                                          .green,
                                                                      fontSize:
                                                                          15,
                                                                    ),
                                                                  )
                                                                : Text(
                                                                    'APAGADO',
                                                                    style: GoogleFonts
                                                                        .poppins(
                                                                      color:
                                                                          color6,
                                                                      fontSize:
                                                                          15,
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
                                                                    value:
                                                                        estado,
                                                                    onChanged:
                                                                        (newValue) {
                                                                      toggleState(
                                                                          deviceName,
                                                                          newValue);
                                                                      setState(
                                                                          () {
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
                                                          style: GoogleFonts
                                                              .poppins(
                                                            color: color6,
                                                            fontSize: 15,
                                                          ),
                                                        ),
                                                  IconButton(
                                                    icon: const Icon(
                                                      HugeIcons
                                                          .strokeRoundedDelete02,
                                                      color: color0,
                                                      size: 20,
                                                    ),
                                                    onPressed: () {
                                                      _confirmDelete(
                                                          deviceName, equipo);
                                                    },
                                                  ),
                                                ],
                                              ),
                                            )
                                          } else ...{
                                            online
                                                ? Column(
                                                    children: List.generate(
                                                      2,
                                                      (i) {
                                                        if (deviceDATA[
                                                                'io$i'] ==
                                                            null) {
                                                          return ListTile(
                                                            title: Text(
                                                              'Error en el equipo',
                                                              style: GoogleFonts
                                                                  .poppins(
                                                                color: color0,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                            ),
                                                            subtitle: Text(
                                                              'Se solucionara automaticamente en poco tiempo...',
                                                              style: GoogleFonts
                                                                  .poppins(
                                                                color: color0,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .normal,
                                                              ),
                                                            ),
                                                          );
                                                        } else {
                                                          Map<String, dynamic>
                                                              equipo =
                                                              jsonDecode(
                                                                  deviceDATA[
                                                                      'io$i']);
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
                                                              equipo[
                                                                  'w_status'];
                                                          String comunWifi =
                                                              (equipo['r_state'] ??
                                                                      '0')
                                                                  .toString();
                                                          bool entradaWifi =
                                                              tipoWifi ==
                                                                  'Entrada';
                                                          return ListTile(
                                                            title: Row(
                                                              children: [
                                                                Text(
                                                                  nicknamesMap[
                                                                          '${deviceName}_$i'] ??
                                                                      '$tipoWifi $i',
                                                                  style: GoogleFonts
                                                                      .poppins(
                                                                    color:
                                                                        color0,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
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
                                                                          ? comunWifi == '1'
                                                                              ? Text(
                                                                                  'Cerrado',
                                                                                  style: GoogleFonts.poppins(
                                                                                    color: Colors.green,
                                                                                    fontSize: 15,
                                                                                    fontWeight: FontWeight.bold,
                                                                                  ),
                                                                                )
                                                                              : Text(
                                                                                  'Abierto',
                                                                                  style: GoogleFonts.poppins(
                                                                                    color: color6,
                                                                                    fontSize: 15,
                                                                                    fontWeight: FontWeight.bold,
                                                                                  ),
                                                                                )
                                                                          : comunWifi == '1'
                                                                              ? Text(
                                                                                  'Abierto',
                                                                                  style: GoogleFonts.poppins(
                                                                                    color: color6,
                                                                                    fontSize: 15,
                                                                                    fontWeight: FontWeight.bold,
                                                                                  ),
                                                                                )
                                                                              : Text(
                                                                                  'Cerrado',
                                                                                  style: GoogleFonts.poppins(
                                                                                    color: Colors.green,
                                                                                    fontSize: 15,
                                                                                    fontWeight: FontWeight.bold,
                                                                                  ),
                                                                                )
                                                                      : estadoWifi
                                                                          ? Text(
                                                                              'Encendido',
                                                                              style: GoogleFonts.poppins(
                                                                                color: Colors.green,
                                                                                fontSize: 15,
                                                                                fontWeight: FontWeight.bold,
                                                                              ),
                                                                            )
                                                                          : Text(
                                                                              'Apagado',
                                                                              style: GoogleFonts.poppins(
                                                                                color: color6,
                                                                                fontSize: 15,
                                                                                fontWeight: FontWeight.bold,
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
                                                                                Icons.new_releases,
                                                                                color: Color(0xff9b9b9b),
                                                                              )
                                                                            : const Icon(
                                                                                Icons.new_releases,
                                                                                color: color6,
                                                                              )
                                                                        : comunWifi ==
                                                                                '1'
                                                                            ? const Icon(
                                                                                Icons.new_releases,
                                                                                color: color6,
                                                                              )
                                                                            : const Icon(
                                                                                Icons.new_releases,
                                                                                color: Color(0xff9b9b9b),
                                                                              )
                                                                    : Switch(
                                                                        activeColor:
                                                                            const Color(0xFF9C9D98),
                                                                        activeTrackColor:
                                                                            const Color(0xFFB2B5AE),
                                                                        inactiveThumbColor:
                                                                            const Color(0xFFB2B5AE),
                                                                        inactiveTrackColor:
                                                                            const Color(0xFF9C9D98),
                                                                        value:
                                                                            estadoWifi,
                                                                        onChanged:
                                                                            (value) {
                                                                          String
                                                                              deviceSerialNumber =
                                                                              DeviceManager.extractSerialNumber(deviceName);
                                                                          String
                                                                              topic =
                                                                              'devices_rx/${DeviceManager.getProductCode(deviceName)}/$deviceSerialNumber';
                                                                          String
                                                                              topic2 =
                                                                              'devices_tx/${DeviceManager.getProductCode(deviceName)}/$deviceSerialNumber';
                                                                          String
                                                                              message =
                                                                              jsonEncode({
                                                                            'pinType': tipoWifi == 'Salida'
                                                                                ? 0
                                                                                : 1,
                                                                            'index':
                                                                                i,
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
                                                                          setState(
                                                                              () {
                                                                            estadoWifi =
                                                                                value;
                                                                          });
                                                                          globalDATA.putIfAbsent('${DeviceManager.getProductCode(deviceName)}/$deviceSerialNumber', () => {}).addAll({
                                                                            'io$i':
                                                                                message
                                                                          });
                                                                          saveGlobalData(
                                                                              globalDATA);
                                                                        },
                                                                      )
                                                                : null,
                                                          );
                                                        }
                                                      },
                                                    ),
                                                  )
                                                : Text(
                                                    'El equipo debe estar\nconectado para su uso',
                                                    style: GoogleFonts.poppins(
                                                      color: color6,
                                                      fontSize: 15,
                                                    ),
                                                  ),
                                            Align(
                                              alignment: Alignment.centerRight,
                                              child: IconButton(
                                                icon: const Icon(
                                                  HugeIcons
                                                      .strokeRoundedDelete02,
                                                  color: color0,
                                                  size: 20,
                                                ),
                                                onPressed: () {
                                                  _confirmDelete(
                                                      deviceName, equipo);
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
                                  bool heaterOn =
                                      deviceDATA['f_status'] ?? false;

                                  return Card(
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
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
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
                                                      style:
                                                          GoogleFonts.poppins(
                                                        color: online
                                                            ? Colors.green
                                                            : color6,
                                                        fontSize: 15,
                                                      ),
                                                    ),
                                                    Icon(
                                                      online
                                                          ? Icons.cloud
                                                          : Icons.cloud_off,
                                                      color: online
                                                          ? Colors.green
                                                          : color6,
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
                                                horizontal: 16.0,
                                                vertical: 5.0),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
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
                                                                          color:
                                                                              Colors.amber[800],
                                                                          fontSize:
                                                                              15,
                                                                        ),
                                                                      ),
                                                                      Icon(
                                                                        Icons
                                                                            .water_drop,
                                                                        size:
                                                                            15,
                                                                        color: Colors
                                                                            .amber[800],
                                                                      ),
                                                                    ] else ...[
                                                                      Text(
                                                                        'Encendido',
                                                                        style: GoogleFonts
                                                                            .poppins(
                                                                          color:
                                                                              Colors.green,
                                                                          fontSize:
                                                                              15,
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ],
                                                                )
                                                              : Text(
                                                                  'Apagado',
                                                                  style: GoogleFonts.poppins(
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
                                                                    setState(
                                                                        () {
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
                                                          color: color6,
                                                          fontSize: 15,
                                                        ),
                                                      ),
                                                IconButton(
                                                  icon: const Icon(
                                                    HugeIcons
                                                        .strokeRoundedDelete02,
                                                    color: color0,
                                                    size: 20,
                                                  ),
                                                  onPressed: () {
                                                    _confirmDelete(
                                                        deviceName, equipo);
                                                  },
                                                ),
                                              ],
                                            ),
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
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
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
                                                      style:
                                                          GoogleFonts.poppins(
                                                        color: online
                                                            ? Colors.green
                                                            : color6,
                                                        fontSize: 15,
                                                      ),
                                                    ),
                                                    Icon(
                                                      online
                                                          ? Icons.cloud
                                                          : Icons.cloud_off,
                                                      color: online
                                                          ? Colors.green
                                                          : color6,
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
                                                  children: List.generate(
                                                    4,
                                                    (i) {
                                                      if (deviceDATA['io$i'] ==
                                                          null) {
                                                        return ListTile(
                                                          title: Text(
                                                            'Error en el equipo',
                                                            style: GoogleFonts
                                                                .poppins(
                                                              color: color0,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                          ),
                                                          subtitle: Text(
                                                            'Se solucionara automaticamente en poco tiempo...',
                                                            style: GoogleFonts
                                                                .poppins(
                                                              color: color0,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .normal,
                                                            ),
                                                          ),
                                                        );
                                                      } else {
                                                        Map<String, dynamic>
                                                            equipo = jsonDecode(
                                                                deviceDATA[
                                                                    'io$i']);
                                                        printLog.i(
                                                          'Voy a realizar el cambio: $equipo',
                                                        );
                                                        String tipoWifi = equipo[
                                                                        'pinType']
                                                                    .toString() ==
                                                                '0'
                                                            ? 'Salida'
                                                            : 'Entrada';
                                                        bool estadoWifi =
                                                            equipo['w_status'];
                                                        String comunWifi =
                                                            (equipo['r_state'] ??
                                                                    '0')
                                                                .toString();
                                                        bool entradaWifi =
                                                            tipoWifi ==
                                                                'Entrada';
                                                        return ListTile(
                                                          title: Row(
                                                            children: [
                                                              Text(
                                                                nicknamesMap[
                                                                        '${deviceName}_$i'] ??
                                                                    '$tipoWifi $i',
                                                                style:
                                                                    GoogleFonts
                                                                        .poppins(
                                                                  color: color0,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
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
                                                                                style: GoogleFonts.poppins(
                                                                                  color: Colors.green,
                                                                                  fontSize: 15,
                                                                                  fontWeight: FontWeight.bold,
                                                                                ),
                                                                              )
                                                                            : Text(
                                                                                'Abierto',
                                                                                style: GoogleFonts.poppins(
                                                                                  color: color6,
                                                                                  fontSize: 15,
                                                                                  fontWeight: FontWeight.bold,
                                                                                ),
                                                                              )
                                                                        : comunWifi ==
                                                                                '1'
                                                                            ? Text(
                                                                                'Abierto',
                                                                                style: GoogleFonts.poppins(
                                                                                  color: color6,
                                                                                  fontSize: 15,
                                                                                  fontWeight: FontWeight.bold,
                                                                                ),
                                                                              )
                                                                            : Text(
                                                                                'Cerrado',
                                                                                style: GoogleFonts.poppins(
                                                                                  color: Colors.green,
                                                                                  fontSize: 15,
                                                                                  fontWeight: FontWeight.bold,
                                                                                ),
                                                                              )
                                                                    : estadoWifi
                                                                        ? Text(
                                                                            'Encendido',
                                                                            style:
                                                                                GoogleFonts.poppins(
                                                                              color: Colors.green,
                                                                              fontSize: 15,
                                                                              fontWeight: FontWeight.bold,
                                                                            ),
                                                                          )
                                                                        : Text(
                                                                            'Apagado',
                                                                            style:
                                                                                GoogleFonts.poppins(
                                                                              color: color6,
                                                                              fontSize: 15,
                                                                              fontWeight: FontWeight.bold,
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
                                                                              Icons.new_releases,
                                                                              color: Color(0xff9b9b9b),
                                                                            )
                                                                          : const Icon(
                                                                              Icons.new_releases,
                                                                              color: color6,
                                                                            )
                                                                      : comunWifi ==
                                                                              '1'
                                                                          ? const Icon(
                                                                              Icons.new_releases,
                                                                              color: color6,
                                                                            )
                                                                          : const Icon(
                                                                              Icons.new_releases,
                                                                              color: Color(0xff9b9b9b),
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
                                                                      value:
                                                                          estadoWifi,
                                                                      onChanged:
                                                                          (value) {
                                                                        String
                                                                            deviceSerialNumber =
                                                                            DeviceManager.extractSerialNumber(deviceName);
                                                                        String
                                                                            topic =
                                                                            'devices_rx/${DeviceManager.getProductCode(deviceName)}/$deviceSerialNumber';
                                                                        String
                                                                            topic2 =
                                                                            'devices_tx/${DeviceManager.getProductCode(deviceName)}/$deviceSerialNumber';
                                                                        String
                                                                            message =
                                                                            jsonEncode({
                                                                          'pinType': tipoWifi == 'Salida'
                                                                              ? 0
                                                                              : 1,
                                                                          'index':
                                                                              i,
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
                                                                        setState(
                                                                            () {
                                                                          estadoWifi =
                                                                              value;
                                                                        });
                                                                        globalDATA
                                                                            .putIfAbsent(
                                                                                '${DeviceManager.getProductCode(deviceName)}/$deviceSerialNumber',
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
                                                      }
                                                    },
                                                  ),
                                                )
                                              : const SizedBox(height: 0),
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                left: 20.0),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: <Widget>[
                                                !online
                                                    ? Text(
                                                        'El equipo debe estar\nconectado para su uso',
                                                        style:
                                                            GoogleFonts.poppins(
                                                          color: color6,
                                                          fontSize: 15,
                                                        ),
                                                      )
                                                    : const SizedBox(height: 0),
                                                IconButton(
                                                  icon: const Icon(
                                                    HugeIcons
                                                        .strokeRoundedDelete02,
                                                    color: color0,
                                                    size: 20,
                                                  ),
                                                  onPressed: () {
                                                    _confirmDelete(
                                                        deviceName, equipo);
                                                  },
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );

                                case '041220_IOT':
                                  bool estado = deviceDATA['w_status'] ?? false;
                                  bool heaterOn =
                                      deviceDATA['f_status'] ?? false;

                                  return Card(
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
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
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
                                                      style:
                                                          GoogleFonts.poppins(
                                                        color: online
                                                            ? Colors.green
                                                            : color6,
                                                        fontSize: 15,
                                                      ),
                                                    ),
                                                    Icon(
                                                      online
                                                          ? Icons.cloud
                                                          : Icons.cloud_off,
                                                      color: online
                                                          ? Colors.green
                                                          : color6,
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
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 16.0,
                                                      vertical: 5.0),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
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
                                                                          style:
                                                                              GoogleFonts.poppins(
                                                                            color:
                                                                                Colors.amber[800],
                                                                            fontSize:
                                                                                15,
                                                                          ),
                                                                        ),
                                                                        Icon(
                                                                          HugeIcons
                                                                              .strokeRoundedFlash,
                                                                          size:
                                                                              15,
                                                                          color:
                                                                              Colors.amber[800],
                                                                        ),
                                                                      ] else ...[
                                                                        Text(
                                                                          'Encendido',
                                                                          style:
                                                                              GoogleFonts.poppins(
                                                                            color:
                                                                                Colors.green,
                                                                            fontSize:
                                                                                15,
                                                                          ),
                                                                        ),
                                                                      ],
                                                                    ],
                                                                  )
                                                                : Text(
                                                                    'Apagado',
                                                                    style: GoogleFonts.poppins(
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
                                                                    value:
                                                                        estado,
                                                                    onChanged:
                                                                        (newValue) {
                                                                      toggleState(
                                                                          deviceName,
                                                                          newValue);
                                                                      setState(
                                                                          () {
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
                                                          style: GoogleFonts
                                                              .poppins(
                                                            color: color6,
                                                            fontSize: 15,
                                                          ),
                                                        ),
                                                  IconButton(
                                                    icon: const Icon(
                                                      HugeIcons
                                                          .strokeRoundedDelete02,
                                                      color: color0,
                                                      size: 20,
                                                    ),
                                                    onPressed: () {
                                                      _confirmDelete(
                                                          deviceName, equipo);
                                                    },
                                                  ),
                                                ],
                                              )),
                                        ],
                                      ),
                                    ),
                                  );

                                case '028000_IOT':
                                  bool estado = deviceDATA['w_status'] ?? false;
                                  bool heaterOn =
                                      deviceDATA['f_status'] ?? false;

                                  return Card(
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
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
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
                                                      style:
                                                          GoogleFonts.poppins(
                                                        color: online
                                                            ? Colors.green
                                                            : color6,
                                                        fontSize: 15,
                                                      ),
                                                    ),
                                                    Icon(
                                                      online
                                                          ? Icons.cloud
                                                          : Icons.cloud_off,
                                                      color: online
                                                          ? Colors.green
                                                          : color6,
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
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 16.0,
                                                      vertical: 5.0),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  online
                                                      ? Row(
                                                          children: [
                                                            estado
                                                                ? Row(
                                                                    children: [
                                                                      if (heaterOn) ...[
                                                                        Text(
                                                                          'Enfriando',
                                                                          style:
                                                                              GoogleFonts.poppins(
                                                                            color:
                                                                                Colors.lightBlueAccent.shade400,
                                                                            fontSize:
                                                                                15,
                                                                          ),
                                                                        ),
                                                                        Icon(
                                                                          HugeIcons
                                                                              .strokeRoundedSnow,
                                                                          size:
                                                                              15,
                                                                          color: Colors
                                                                              .lightBlueAccent
                                                                              .shade400,
                                                                        ),
                                                                      ] else ...[
                                                                        Text(
                                                                          'Encendido',
                                                                          style:
                                                                              GoogleFonts.poppins(
                                                                            color:
                                                                                Colors.green,
                                                                            fontSize:
                                                                                15,
                                                                          ),
                                                                        ),
                                                                      ],
                                                                    ],
                                                                  )
                                                                : Text(
                                                                    'Apagado',
                                                                    style: GoogleFonts.poppins(
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
                                                                    value:
                                                                        estado,
                                                                    onChanged:
                                                                        (newValue) {
                                                                      toggleState(
                                                                          deviceName,
                                                                          newValue);
                                                                      setState(
                                                                          () {
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
                                                          style: GoogleFonts
                                                              .poppins(
                                                            color: color6,
                                                            fontSize: 15,
                                                          ),
                                                        ),
                                                  IconButton(
                                                    icon: const Icon(
                                                      HugeIcons
                                                          .strokeRoundedDelete02,
                                                      color: color0,
                                                      size: 20,
                                                    ),
                                                    onPressed: () {
                                                      _confirmDelete(
                                                          deviceName, equipo);
                                                    },
                                                  ),
                                                ],
                                              )),
                                        ],
                                      ),
                                    ),
                                  );

                                default:
                                  return Container();
                              }
                            } catch (e) {
                              return Card(
                                color: color3,
                                margin: const EdgeInsets.symmetric(
                                    vertical: 5, horizontal: 10),
                                elevation: 2,
                                child: Theme(
                                    data: Theme.of(context).copyWith(
                                        dividerColor: Colors.transparent),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        ListTile(
                                          title: Text(
                                            nicknamesMap[deviceName] ??
                                                deviceName,
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
                                displayName = nicknamesMap[equipo.trim()] ??
                                    equipo.trim();
                              }

                              nicksList.add(displayName);
                            }

                            for (String device in deviceList) {
                              String equipo =
                                  DeviceManager.getProductCode(device);
                              String serial =
                                  DeviceManager.extractSerialNumber(device);
                              Map<String, dynamic> topicData =
                                  notifier.getData('$equipo/$serial');
                              globalDATA
                                  .putIfAbsent('$equipo/$serial', () => {})
                                  .addAll(topicData);
                            }

                            bool online = isGroupOnline(devicesInGroup);
                            bool estado = isGroupOn(devicesInGroup);
                            bool owner = canControlGroup(devicesInGroup);
                            return Card(
                              color: color3,
                              margin: const EdgeInsets.symmetric(
                                vertical: 5,
                                horizontal: 10,
                              ),
                              elevation: 2,
                              child: Theme(
                                data: Theme.of(context)
                                    .copyWith(dividerColor: Colors.transparent),
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
                                          Text(
                                            grupo[0].toUpperCase() +
                                                grupo.substring(1),
                                            style: GoogleFonts.poppins(
                                              color: color0,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          SizedBox(
                                            width: MediaQuery.of(context)
                                                    .size
                                                    .width *
                                                0.75,
                                            child: Text(
                                              nicksList
                                                  .toString()
                                                  .replaceAll('[', '')
                                                  .replaceAll(']', ''),
                                              style: GoogleFonts.poppins(
                                                color: color1,
                                                fontSize: 15,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                            ),
                                          ),
                                        ],
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
                                                      style:
                                                          GoogleFonts.poppins(
                                                        color: Colors.green,
                                                        fontSize: 15,
                                                      ),
                                                    )
                                                  : Text(
                                                      'Apagado',
                                                      style:
                                                          GoogleFonts.poppins(
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
                                                  activeTrackColor:
                                                      const Color(0xFFB2B5AE),
                                                  inactiveThumbColor:
                                                      const Color(0xFFB2B5AE),
                                                  inactiveTrackColor:
                                                      const Color(0xFF9C9D98),
                                                  value: estado,
                                                  onChanged: (newValue) {
                                                    controlGroup(
                                                      currentUserEmail,
                                                      newValue,
                                                      grupo,
                                                    );
                                                  },
                                                )
                                              : const SizedBox(
                                                  height: 0,
                                                  width: 0,
                                                )
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }
                        },
                      );
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
