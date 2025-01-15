import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:caldensmart/master.dart';
import 'package:caldensmart/Global/stored_data.dart';
import 'package:caldensmart/aws/mqtt/mqtt.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import '../aws/dynamo/dynamo.dart';
import '../aws/dynamo/dynamo_certificates.dart';

class WifiPage extends StatefulWidget {
  const WifiPage({super.key});

  @override
  State<WifiPage> createState() => WifiPageState();
}

class WifiPageState extends State<WifiPage> {
  @override
  void initState() {
    super.initState();
    for (String device in previusConnections) {
      // printLog('Voy a cargar los datos de $device');
      queryItems(service, DeviceManager.getProductCode(device),
          DeviceManager.extractSerialNumber(device));
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
                  saveDeviceList(previusConnections);
                  putDevicesForAlexa(
                      service, currentUserEmail, previusConnections);
                  String topic =
                      'devices_tx/$equipo/${DeviceManager.extractSerialNumber(deviceName)}';
                  unSubToTopicMQTT(topic);
                  topicsToSub.remove(topic);
                  saveTopicList(topicsToSub);
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
          IconButton(
            icon: const Icon(HugeIcons.strokeRoundedSettings02, color: color0),
            onPressed: () => Navigator.pushNamed(context, '/escenas'),
          ),
        ],
      ),
      body: Container(
        padding: const EdgeInsets.only(bottom: 100.0),
        color: color1,
        child: previusConnections.isEmpty
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
                itemCount: previusConnections.length,
                onReorder: (int oldIndex, int newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) {
                      newIndex -= 1;
                    }
                    final String item = previusConnections.removeAt(oldIndex);
                    previusConnections.insert(newIndex, item);
                    saveDeviceList(previusConnections);
                  });
                },
                itemBuilder: (BuildContext context, int index) {
                  String deviceName = previusConnections[index];
                  return Consumer<GlobalDataNotifier>(
                    key: Key(deviceName),
                    builder: (context, notifier, child) {
                      String equipo = DeviceManager.getProductCode(deviceName);
                      Map<String, dynamic> topicData = notifier.getData(
                          '$equipo/${DeviceManager.extractSerialNumber(deviceName)}');
                      printLog(
                          'Llego un cambio en ${'$equipo/${DeviceManager.extractSerialNumber(deviceName)}'}',
                          'Magenta');
                      printLog('Y fue el siguiente: $topicData', 'magenta');
                      globalDATA
                          .putIfAbsent(
                              '$equipo/${DeviceManager.extractSerialNumber(deviceName)}',
                              () => {})
                          .addAll(topicData);
                      saveGlobalData(globalDATA);
                      Map<String, dynamic> deviceDATA = globalDATA[
                              '$equipo/${DeviceManager.extractSerialNumber(deviceName)}'] ??
                          {};
                      // printLog(deviceDATA, 'cyan');

                      // printLog(
                      //     "Las keys del equipo ${deviceDATA.keys}", 'rojo');

                      bool online = deviceDATA['cstate'] ?? false;

                      List<dynamic> admins =
                          deviceDATA['secondary_admin'] ?? [];

                      bool owner = deviceDATA['owner'] == currentUserEmail ||
                          admins.contains(deviceName) ||
                          deviceDATA['owner'] == '' ||
                          deviceDATA['owner'] == null;

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
                                          nicknamesMap[deviceName] ??
                                              deviceName,
                                          style: GoogleFonts.poppins(
                                            color: color0,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          online
                                              ? '● CONECTADO'
                                              : '● DESCONECTADO',
                                          style: GoogleFonts.poppins(
                                            color:
                                                online ? Colors.green : color6,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                children: <Widget>[
                                  ListTile(
                                    title: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'PPM CO: $ppmCO',
                                          style: GoogleFonts.poppins(
                                            color: color0,
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          'CH4 LIE: ${(ppmCH4 / 500).round()}%',
                                          style: GoogleFonts.poppins(
                                            color: color0,
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            Text(
                                              alert ? 'PELIGRO' : 'AIRE PURO',
                                              style: GoogleFonts.poppins(
                                                color: color0,
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
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
                                                    color: Colors.green,
                                                  ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(
                                        HugeIcons.strokeRoundedDelete02,
                                        color: color0,
                                        size: 20,
                                      ),
                                      onPressed: () {
                                        _confirmDelete(deviceName, equipo);
                                      },
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
                            color: color3,
                            margin: const EdgeInsets.symmetric(
                                vertical: 5, horizontal: 10),
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
                                          nicknamesMap[deviceName] ??
                                              deviceName,
                                          style: GoogleFonts.poppins(
                                            color: color0,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          online
                                              ? '● CONECTADO'
                                              : '● DESCONECTADO',
                                          style: GoogleFonts.poppins(
                                            color:
                                                online ? Colors.green : color6,
                                            fontSize: 12,
                                          ),
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
                                        Row(
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
                                                            fontSize: 15,
                                                          ),
                                                        ),
                                                        Icon(
                                                          HugeIcons
                                                              .strokeRoundedFlash,
                                                          size: 15,
                                                          color:
                                                              Colors.amber[800],
                                                        ),
                                                      ] else ...[
                                                        Text(
                                                          'Encendido',
                                                          style: GoogleFonts
                                                              .poppins(
                                                            color: Colors.green,
                                                            fontSize: 15,
                                                          ),
                                                        ),
                                                      ],
                                                    ],
                                                  )
                                                : Text(
                                                    'Apagado',
                                                    style: GoogleFonts.poppins(
                                                        color: color6,
                                                        fontSize: 15),
                                                  ),
                                            const SizedBox(width: 5),
                                            owner
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
                                                      toggleState(
                                                          deviceName, newValue);
                                                      setState(() {
                                                        estado = newValue;
                                                      });
                                                    },
                                                  )
                                                : const SizedBox(
                                                    height: 0, width: 0),
                                          ],
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            HugeIcons.strokeRoundedDelete02,
                                            color: color0,
                                            size: 20,
                                          ),
                                          onPressed: () {
                                            _confirmDelete(deviceName, equipo);
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
                          bool heaterOn = deviceDATA['f_status'] ?? false;
                          return Card(
                            color: color3,
                            margin: const EdgeInsets.symmetric(
                                vertical: 5, horizontal: 10),
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
                                          nicknamesMap[deviceName] ??
                                              deviceName,
                                          style: GoogleFonts.poppins(
                                            color: color0,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          online
                                              ? '● CONECTADO'
                                              : '● DESCONECTADO',
                                          style: GoogleFonts.poppins(
                                            color:
                                                online ? Colors.green : color6,
                                            fontSize: 12,
                                          ),
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
                                        Row(
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
                                                            fontSize: 15,
                                                          ),
                                                        ),
                                                        Icon(
                                                          HugeIcons
                                                              .strokeRoundedFire,
                                                          size: 15,
                                                          color:
                                                              Colors.amber[800],
                                                        ),
                                                      ] else ...[
                                                        Text(
                                                          'Encendido',
                                                          style: GoogleFonts
                                                              .poppins(
                                                            color: Colors.green,
                                                            fontSize: 15,
                                                          ),
                                                        ),
                                                      ],
                                                    ],
                                                  )
                                                : Text(
                                                    'Apagado',
                                                    style: GoogleFonts.poppins(
                                                      color: color6,
                                                      fontSize: 15,
                                                    ),
                                                  ),
                                            const SizedBox(width: 5),
                                            Switch(
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
                                                toggleState(
                                                    deviceName, newValue);
                                                setState(() {
                                                  estado = newValue;
                                                  if (!newValue) {
                                                    heaterOn = false;
                                                  }
                                                });
                                              },
                                            ),
                                          ],
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            HugeIcons.strokeRoundedDelete02,
                                            color: color0,
                                            size: 20,
                                          ),
                                          onPressed: () {
                                            _confirmDelete(deviceName, equipo);
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
                              data: Theme.of(context)
                                  .copyWith(dividerColor: Colors.transparent),
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
                                        Text(
                                          nicknamesMap[deviceName] ??
                                              deviceName,
                                          style: GoogleFonts.poppins(
                                            color: color0,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          online
                                              ? '● CONECTADO'
                                              : '● DESCONECTADO',
                                          style: GoogleFonts.poppins(
                                            color:
                                                online ? Colors.green : color6,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                children: <Widget>[
                                  Column(
                                    children: List.generate(
                                      deviceDATA.keys
                                          .where((key) => key.contains('io'))
                                          .length,
                                      (i) {
                                        if (deviceDATA['io$i'] == null) {
                                          return ListTile(
                                            title: Text(
                                              'Error en el equipo',
                                              style: GoogleFonts.poppins(
                                                color: color0,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            subtitle: Text(
                                              'Se solucionara automaticamente en poco tiempo...',
                                              style: GoogleFonts.poppins(
                                                color: color0,
                                                fontWeight: FontWeight.normal,
                                              ),
                                            ),
                                          );
                                        } else {
                                          Map<String, dynamic> equipo =
                                              jsonDecode(deviceDATA['io$i']);
                                          printLog(
                                              'Voy a realizar el cambio: $equipo',
                                              'amarillo');
                                          String tipoWifi =
                                              equipo['pinType'].toString() ==
                                                      '0'
                                                  ? 'Salida'
                                                  : 'Entrada';
                                          bool estadoWifi = equipo['w_status'];
                                          String comunWifi =
                                              (equipo['r_state'] ?? '0')
                                                  .toString();
                                          bool entradaWifi =
                                              tipoWifi == 'Entrada';
                                          return ListTile(
                                            title: Row(
                                              children: [
                                                Text(
                                                  subNicknamesMap[
                                                          '$deviceName/-/$i'] ??
                                                      '$tipoWifi $i',
                                                  style: GoogleFonts.poppins(
                                                    color: color0,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                const SizedBox(width: 5),
                                              ],
                                            ),
                                            subtitle: Align(
                                              alignment: AlignmentDirectional
                                                  .centerStart,
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.start,
                                                children: [
                                                  entradaWifi
                                                      ? estadoWifi
                                                          ? comunWifi == '1'
                                                              ? Text(
                                                                  'Cerrado',
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
                                                                  'Abierto',
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
                                                                )
                                                          : comunWifi == '1'
                                                              ? Text(
                                                                  'Abierto',
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
                                                                )
                                                              : Text(
                                                                  'Cerrado',
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
                                                      : estadoWifi
                                                          ? Text(
                                                              'Encendido',
                                                              style: GoogleFonts
                                                                  .poppins(
                                                                color: Colors
                                                                    .green,
                                                                fontSize: 15,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                            )
                                                          : Text(
                                                              'Apagado',
                                                              style: GoogleFonts
                                                                  .poppins(
                                                                color: color6,
                                                                fontSize: 15,
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
                                                                  0xff9b9b9b,
                                                                ),
                                                              )
                                                            : const Icon(
                                                                Icons
                                                                    .new_releases,
                                                                color: color6,
                                                              )
                                                        : comunWifi == '1'
                                                            ? const Icon(
                                                                Icons
                                                                    .new_releases,
                                                                color: color6,
                                                              )
                                                            : const Icon(
                                                                Icons
                                                                    .new_releases,
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
                                                        value: estadoWifi,
                                                        onChanged: (value) {
                                                          String
                                                              deviceSerialNumber =
                                                              DeviceManager
                                                                  .extractSerialNumber(
                                                                      deviceName);
                                                          String topic =
                                                              'devices_rx/${DeviceManager.getProductCode(deviceName)}/$deviceSerialNumber';
                                                          String topic2 =
                                                              'devices_tx/${DeviceManager.getProductCode(deviceName)}/$deviceSerialNumber';
                                                          String message =
                                                              jsonEncode({
                                                            'pinType':
                                                                tipoWifi ==
                                                                        'Salida'
                                                                    ? 0
                                                                    : 1,
                                                            'index': i,
                                                            'w_status': value,
                                                            'r_state':
                                                                comunWifi,
                                                          });
                                                          sendMessagemqtt(
                                                              topic, message);
                                                          sendMessagemqtt(
                                                              topic2, message);
                                                          setState(() {
                                                            estadoWifi = value;
                                                          });
                                                          globalDATA
                                                              .putIfAbsent(
                                                                  '${DeviceManager.getProductCode(deviceName)}/$deviceSerialNumber',
                                                                  () => {})
                                                              .addAll({
                                                            'io$i': message
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
                                        _confirmDelete(deviceName, equipo);
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        case '027313_IOT':
                          bool estado = deviceDATA['w_status'] ?? false;
                          bool isNC = deviceDATA['isNC'] ?? false;

                          return Card(
                            color: color3,
                            margin: const EdgeInsets.symmetric(
                                vertical: 5, horizontal: 10),
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
                                          nicknamesMap[deviceName] ??
                                              deviceName,
                                          style: GoogleFonts.poppins(
                                            color: color0,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          online
                                              ? '● CONECTADO'
                                              : '● DESCONECTADO',
                                          style: GoogleFonts.poppins(
                                            color:
                                                online ? Colors.green : color6,
                                            fontSize: 12,
                                          ),
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
                                        Row(
                                          children: [
                                            isNC
                                                ? estado
                                                    ? Text(
                                                        labelEncendido[
                                                                deviceName] ??
                                                            'ABIERTO',
                                                        style:
                                                            GoogleFonts.poppins(
                                                          color: Colors.green,
                                                          fontSize: 15,
                                                        ),
                                                      )
                                                    : Text(
                                                        labelApagado[
                                                                deviceName] ??
                                                            'CERRADO',
                                                        style:
                                                            GoogleFonts.poppins(
                                                          color: color6,
                                                          fontSize: 15,
                                                        ),
                                                      )
                                                : estado
                                                    ? Text(
                                                        labelEncendido[
                                                                deviceName] ??
                                                            'CERRADO',
                                                        style:
                                                            GoogleFonts.poppins(
                                                          color: Colors.green,
                                                          fontSize: 15,
                                                        ),
                                                      )
                                                    : Text(
                                                        labelApagado[
                                                                deviceName] ??
                                                            'ABIERTO',
                                                        style:
                                                            GoogleFonts.poppins(
                                                          color: color6,
                                                          fontSize: 15,
                                                        ),
                                                      ),
                                            const SizedBox(width: 5),
                                            owner
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
                                                      toggleState(
                                                          deviceName, newValue);
                                                      setState(() {
                                                        estado = newValue;
                                                      });
                                                    },
                                                  )
                                                : const SizedBox(
                                                    height: 0, width: 0),
                                          ],
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            HugeIcons.strokeRoundedDelete02,
                                            color: color0,
                                            size: 20,
                                          ),
                                          onPressed: () {
                                            _confirmDelete(deviceName, equipo);
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );

                        case '050217_IOT':
                          bool estado = deviceDATA['w_status'] ?? false;
                          bool heaterOn = deviceDATA['f_status'] ?? false;

                          return Card(
                            color: color3,
                            margin: const EdgeInsets.symmetric(
                                vertical: 5, horizontal: 10),
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
                                          nicknamesMap[deviceName] ??
                                              deviceName,
                                          style: GoogleFonts.poppins(
                                            color: color0,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          online
                                              ? '● CONECTADO'
                                              : '● DESCONECTADO',
                                          style: GoogleFonts.poppins(
                                            color:
                                                online ? Colors.green : color6,
                                            fontSize: 12,
                                          ),
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
                                        Row(
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
                                                            fontSize: 15,
                                                          ),
                                                        ),
                                                        Icon(
                                                          Icons.water_drop,
                                                          size: 15,
                                                          color:
                                                              Colors.amber[800],
                                                        ),
                                                      ] else ...[
                                                        Text(
                                                          'Encendido',
                                                          style: GoogleFonts
                                                              .poppins(
                                                            color: Colors.green,
                                                            fontSize: 15,
                                                          ),
                                                        ),
                                                      ],
                                                    ],
                                                  )
                                                : Text(
                                                    'Apagado',
                                                    style: GoogleFonts.poppins(
                                                        color: color6,
                                                        fontSize: 15),
                                                  ),
                                            const SizedBox(width: 5),
                                            owner
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
                                                      toggleState(
                                                          deviceName, newValue);
                                                      setState(() {
                                                        estado = newValue;
                                                      });
                                                    },
                                                  )
                                                : const SizedBox(
                                                    height: 0, width: 0),
                                          ],
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            HugeIcons.strokeRoundedDelete02,
                                            color: color0,
                                            size: 20,
                                          ),
                                          onPressed: () {
                                            _confirmDelete(deviceName, equipo);
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
                                          nicknamesMap[deviceName] ??
                                              deviceName,
                                          style: GoogleFonts.poppins(
                                            color: color0,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          online
                                              ? '● CONECTADO'
                                              : '● DESCONECTADO',
                                          style: GoogleFonts.poppins(
                                            color:
                                                online ? Colors.green : color6,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                children: <Widget>[
                                  Column(
                                    children: List.generate(
                                      4,
                                      (i) {
                                        if (deviceDATA['io$i'] == null) {
                                          return ListTile(
                                            title: Text(
                                              'Error en el equipo',
                                              style: GoogleFonts.poppins(
                                                color: color0,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            subtitle: Text(
                                              'Se solucionara automaticamente en poco tiempo...',
                                              style: GoogleFonts.poppins(
                                                color: color0,
                                                fontWeight: FontWeight.normal,
                                              ),
                                            ),
                                          );
                                        } else {
                                          Map<String, dynamic> equipo =
                                              jsonDecode(deviceDATA['io$i']);
                                          printLog(
                                              'Voy a realizar el cambio: $equipo',
                                              'amarillo');
                                          String tipoWifi =
                                              equipo['pinType'].toString() ==
                                                      '0'
                                                  ? 'Salida'
                                                  : 'Entrada';
                                          bool estadoWifi = equipo['w_status'];
                                          String comunWifi =
                                              (equipo['r_state'] ?? '0')
                                                  .toString();
                                          bool entradaWifi =
                                              tipoWifi == 'Entrada';
                                          return ListTile(
                                            title: Row(
                                              children: [
                                                Text(
                                                  subNicknamesMap[
                                                          '$deviceName/-/$i'] ??
                                                      '$tipoWifi $i',
                                                  style: GoogleFonts.poppins(
                                                    color: color0,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                const SizedBox(width: 5),
                                              ],
                                            ),
                                            subtitle: Align(
                                              alignment: AlignmentDirectional
                                                  .centerStart,
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.start,
                                                children: [
                                                  entradaWifi
                                                      ? estadoWifi
                                                          ? comunWifi == '1'
                                                              ? Text(
                                                                  'Cerrado',
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
                                                                  'Abierto',
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
                                                                )
                                                          : comunWifi == '1'
                                                              ? Text(
                                                                  'Abierto',
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
                                                                )
                                                              : Text(
                                                                  'Cerrado',
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
                                                      : estadoWifi
                                                          ? Text(
                                                              'Encendido',
                                                              style: GoogleFonts
                                                                  .poppins(
                                                                color: Colors
                                                                    .green,
                                                                fontSize: 15,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                            )
                                                          : Text(
                                                              'Apagado',
                                                              style: GoogleFonts
                                                                  .poppins(
                                                                color: color6,
                                                                fontSize: 15,
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
                                                                color: color6,
                                                              )
                                                        : comunWifi == '1'
                                                            ? const Icon(
                                                                Icons
                                                                    .new_releases,
                                                                color: color6,
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
                                                        onChanged: (value) {
                                                          String
                                                              deviceSerialNumber =
                                                              DeviceManager
                                                                  .extractSerialNumber(
                                                                      deviceName);
                                                          String topic =
                                                              'devices_rx/${DeviceManager.getProductCode(deviceName)}/$deviceSerialNumber';
                                                          String topic2 =
                                                              'devices_tx/${DeviceManager.getProductCode(deviceName)}/$deviceSerialNumber';
                                                          String message =
                                                              jsonEncode({
                                                            'pinType':
                                                                tipoWifi ==
                                                                        'Salida'
                                                                    ? 0
                                                                    : 1,
                                                            'index': i,
                                                            'w_status': value,
                                                            'r_state':
                                                                comunWifi,
                                                          });
                                                          sendMessagemqtt(
                                                              topic, message);
                                                          sendMessagemqtt(
                                                              topic2, message);
                                                          setState(() {
                                                            estadoWifi = value;
                                                          });
                                                          globalDATA
                                                              .putIfAbsent(
                                                                  '${DeviceManager.getProductCode(deviceName)}/$deviceSerialNumber',
                                                                  () => {})
                                                              .addAll({
                                                            'io$i': message
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
                                        _confirmDelete(deviceName, equipo);
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );

                        case '041220_IOT':
                          bool estado = deviceDATA['w_status'] ?? false;
                          bool heaterOn = deviceDATA['f_status'] ?? false;

                          return Card(
                            color: color3,
                            margin: const EdgeInsets.symmetric(
                                vertical: 5, horizontal: 10),
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
                                          nicknamesMap[deviceName] ??
                                              deviceName,
                                          style: GoogleFonts.poppins(
                                            color: color0,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          online
                                              ? '● CONECTADO'
                                              : '● DESCONECTADO',
                                          style: GoogleFonts.poppins(
                                            color:
                                                online ? Colors.green : color6,
                                            fontSize: 12,
                                          ),
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
                                        Row(
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
                                                            fontSize: 15,
                                                          ),
                                                        ),
                                                        Icon(
                                                          HugeIcons
                                                              .strokeRoundedFlash,
                                                          size: 15,
                                                          color:
                                                              Colors.amber[800],
                                                        ),
                                                      ] else ...[
                                                        Text(
                                                          'Encendido',
                                                          style: GoogleFonts
                                                              .poppins(
                                                            color: Colors.green,
                                                            fontSize: 15,
                                                          ),
                                                        ),
                                                      ],
                                                    ],
                                                  )
                                                : Text(
                                                    'Apagado',
                                                    style: GoogleFonts.poppins(
                                                        color: color6,
                                                        fontSize: 15),
                                                  ),
                                            const SizedBox(width: 5),
                                            owner
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
                                                      toggleState(
                                                          deviceName, newValue);
                                                      setState(() {
                                                        estado = newValue;
                                                      });
                                                    },
                                                  )
                                                : const SizedBox(
                                                    height: 0, width: 0),
                                          ],
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            HugeIcons.strokeRoundedDelete02,
                                            color: color0,
                                            size: 20,
                                          ),
                                          onPressed: () {
                                            _confirmDelete(deviceName, equipo);
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );

                        case '028000_IOT':
                          bool estado = deviceDATA['w_status'] ?? false;
                          bool heaterOn = deviceDATA['f_status'] ?? false;

                          return Card(
                            color: color3,
                            margin: const EdgeInsets.symmetric(
                                vertical: 5, horizontal: 10),
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
                                          nicknamesMap[deviceName] ??
                                              deviceName,
                                          style: GoogleFonts.poppins(
                                            color: color0,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          online
                                              ? '● CONECTADO'
                                              : '● DESCONECTADO',
                                          style: GoogleFonts.poppins(
                                            color:
                                                online ? Colors.green : color6,
                                            fontSize: 12,
                                          ),
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
                                        Row(
                                          children: [
                                            estado
                                                ? Row(
                                                    children: [
                                                      if (heaterOn) ...[
                                                        Text(
                                                          'Enfriando',
                                                          style: GoogleFonts
                                                              .poppins(
                                                            color: Colors.lightBlueAccent.shade400,
                                                            fontSize: 15,
                                                          ),
                                                        ),
                                                        Icon(
                                                          HugeIcons.strokeRoundedSnow,
                                                          size: 15,
                                                          color:
                                                              Colors.lightBlueAccent.shade400,
                                                        ),
                                                      ] else ...[
                                                        Text(
                                                          'Encendido',
                                                          style: GoogleFonts
                                                              .poppins(
                                                            color: Colors.green,
                                                            fontSize: 15,
                                                          ),
                                                        ),
                                                      ],
                                                    ],
                                                  )
                                                : Text(
                                                    'Apagado',
                                                    style: GoogleFonts.poppins(
                                                        color: color6,
                                                        fontSize: 15),
                                                  ),
                                            const SizedBox(width: 5),
                                            owner
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
                                                      toggleState(
                                                          deviceName, newValue);
                                                      setState(() {
                                                        estado = newValue;
                                                      });
                                                    },
                                                  )
                                                : const SizedBox(
                                                    height: 0, width: 0),
                                          ],
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            HugeIcons.strokeRoundedDelete02,
                                            color: color0,
                                            size: 20,
                                          ),
                                          onPressed: () {
                                            _confirmDelete(deviceName, equipo);
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );

                        default:
                          return Container();
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
