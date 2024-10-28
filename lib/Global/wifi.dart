import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:caldensmart/master.dart';
import 'package:caldensmart/stored_data.dart';
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
      queryItems(service, command(device), extractSerialNumber(device));
    }
  }

  //*-Prender y apagar los equipos-*\\
  void toggleState(String deviceName, bool newState) async {
    String deviceSerialNumber = extractSerialNumber(deviceName);
    String productCode = command(deviceName);
    globalDATA['${command(deviceName)}/$deviceSerialNumber']!['w_status'] =
        newState;
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
                  putDevicesForAlexa(service, currentUserEmail, previusConnections);
                  String topic =
                      'devices_tx/$equipo/${extractSerialNumber(deviceName)}';
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
                      String equipo = command(deviceName);
                      Map<String, dynamic> topicData = notifier.getData(
                          '$equipo/${extractSerialNumber(deviceName)}');
                      globalDATA
                          .putIfAbsent(
                              '$equipo/${extractSerialNumber(deviceName)}',
                              () => {})
                          .addAll(topicData);
                      saveGlobalData(globalDATA);
                      Map<String, dynamic> deviceDATA = globalDATA[
                          '$equipo/${extractSerialNumber(deviceName)}']!;
                      printLog(deviceDATA);

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
                        case '020010_IOT':
                          String io =
                              '${deviceDATA['io0']}/${deviceDATA['io1']}/${deviceDATA['io2']}/${deviceDATA['io3']}';
                          printLog('IO: $io');
                          var partes = io.split('/');
                          List<String> tipoWifi = [];
                          List<bool> estadoWifi = [];
                          List<String> comunWifi = [];
                          for (int i = 0; i < partes.length; i++) {
                            var deviceParts = partes[i].split(':');
                            tipoWifi.add(
                                deviceParts[0] == '0' ? 'Salida' : 'Entrada');
                            estadoWifi.add(deviceParts[1] == '1');
                            comunWifi.add(deviceParts[2]);
                          }

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
                                    children: List.generate(partes.length, (i) {
                                      bool entradaWifi =
                                          tipoWifi[i] == 'Entrada';
                                      return ListTile(
                                        title: Row(
                                          children: [
                                            Text(
                                              subNicknamesMap[
                                                      '$deviceName/-/$i'] ??
                                                  '${tipoWifi[i]} $i',
                                              style: GoogleFonts.poppins(
                                                color: color0,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(width: 5),
                                          ],
                                        ),
                                        subtitle: Align(
                                          alignment:
                                              AlignmentDirectional.centerStart,
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.start,
                                            children: [
                                              entradaWifi
                                                  ? estadoWifi[i]
                                                      ? comunWifi[i] == '1'
                                                          ? Text(
                                                              'Cerrado',
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
                                                              'Abierto',
                                                              style: GoogleFonts
                                                                  .poppins(
                                                                color: color6,
                                                                fontSize: 15,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                            )
                                                      : comunWifi[i] == '1'
                                                          ? Text(
                                                              'Abierto',
                                                              style: GoogleFonts
                                                                  .poppins(
                                                                color: color6,
                                                                fontSize: 15,
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
                                                                fontSize: 15,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                            )
                                                  : estadoWifi[i]
                                                      ? Text(
                                                          'Encendido',
                                                          style: GoogleFonts
                                                              .poppins(
                                                            color: Colors.green,
                                                            fontSize: 15,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        )
                                                      : Text(
                                                          'Apagado',
                                                          style: GoogleFonts
                                                              .poppins(
                                                            color: color6,
                                                            fontSize: 15,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                            ],
                                          ),
                                        ),
                                        trailing: owner
                                            ? entradaWifi
                                                ? estadoWifi[i]
                                                    ? comunWifi[i] == '1'
                                                        ? const Icon(
                                                            Icons.new_releases,
                                                            color: Color(
                                                                0xff9b9b9b),
                                                          )
                                                        : const Icon(
                                                            Icons.new_releases,
                                                            color: color6,
                                                          )
                                                    : comunWifi[i] == '1'
                                                        ? const Icon(
                                                            Icons.new_releases,
                                                            color: color6,
                                                          )
                                                        : const Icon(
                                                            Icons.new_releases,
                                                            color: Color(
                                                                0xff9b9b9b),
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
                                                    value: estadoWifi[i],
                                                    onChanged: (value) {
                                                      // String fun2 =
                                                      //     '${tipoWifi[i] == 'Entrada' ? '1' : '0'}:${value ? '1' : '0'}:${comunWifi[i]}';

                                                      String topic =
                                                          'devices_rx/$equipo/${extractSerialNumber(deviceName)}';
                                                      String topic2 =
                                                          'devices_tx/$equipo/${extractSerialNumber(deviceName)}';
                                                      String message =
                                                          jsonEncode({
                                                        'type': tipoWifi[i] ==
                                                                'Entrada'
                                                            ? '1'
                                                            : '0',
                                                        'w_status': value,
                                                        'r_status':
                                                            comunWifi[i],
                                                        'index': i
                                                      });
                                                      sendMessagemqtt(
                                                          topic, message);
                                                      sendMessagemqtt(
                                                          topic2, message);
                                                      estadoWifi[i] = value;
                                                      for (int j = 0;
                                                          j < estadoWifi.length;
                                                          j++) {
                                                        String device =
                                                            '${tipoWifi[j] == 'Salida' ? '0' : '1'}:${estadoWifi[j] == true ? '1' : '0'}:${comunWifi[j]}';
                                                        globalDATA[
                                                                '$equipo/${extractSerialNumber(deviceName)}']![
                                                            'io$j'] = device;
                                                      }
                                                      saveGlobalData(
                                                          globalDATA);
                                                    },
                                                  )
                                            : null,
                                      );
                                    }),
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
                                                        'ABIERTO',
                                                        style:
                                                            GoogleFonts.poppins(
                                                          color: Colors.green,
                                                          fontSize: 15,
                                                        ),
                                                      )
                                                    : Text(
                                                        'CERRADO',
                                                        style:
                                                            GoogleFonts.poppins(
                                                                color: color6,
                                                                fontSize: 15),
                                                      )
                                                : estado
                                                    ? Text(
                                                        'CERRADO',
                                                        style:
                                                            GoogleFonts.poppins(
                                                          color: Colors.green,
                                                          fontSize: 15,
                                                        ),
                                                      )
                                                    : Text(
                                                        'ABIERTO',
                                                        style:
                                                            GoogleFonts.poppins(
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
