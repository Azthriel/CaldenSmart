import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../aws/dynamo/dynamo.dart';
import '../master.dart';
import 'stored_data.dart';
import 'package:caldensmart/logger.dart';

class ManagerScreen extends StatefulWidget {
  const ManagerScreen({super.key});

  @override
  ManagerScreenState createState() => ManagerScreenState();
}

class ManagerScreenState extends State<ManagerScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController tenantController = TextEditingController();

  var parts = utf8.decode(ioValues).split('/');
  bool showSecondaryAdminFields = false;
  bool showSecondaryAdminList = false;
  bool showSmartResident = false;
  bool dOnOk = false;
  bool dOffOk = false;
  bool showNotificationOptions = false;
  int selectedNotificationOption = 0;

  Future<void> addSecondaryAdmin(String email) async {
    if (!isValidEmail(email)) {
      showToast('Por favor, introduce un correo electrónico válido.');
      return;
    }

    if (adminDevices.contains(email)) {
      showToast('Este administrador ya está añadido.');
      return;
    }

    try {
      List<String> updatedAdmins = List.from(adminDevices)..add(email);

      await putSecondaryAdmins(
          
          DeviceManager.getProductCode(deviceName),
          DeviceManager.extractSerialNumber(deviceName),
          updatedAdmins);

      setState(() {
        adminDevices = updatedAdmins;
        emailController.clear();
      });

      showToast('Administrador añadido correctamente.');
    } catch (e) {
      printLog.e('Error al añadir administrador secundario: $e');
      showToast('Error al añadir el administrador. Inténtalo de nuevo.');
    }
  }

  Future<void> removeSecondaryAdmin(String email) async {
    try {
      List<String> updatedAdmins = List.from(adminDevices)..remove(email);

      await putSecondaryAdmins(
          
          DeviceManager.getProductCode(deviceName),
          DeviceManager.extractSerialNumber(deviceName),
          updatedAdmins);

      setState(() {
        adminDevices.remove(email);
      });

      showToast('Administrador eliminado correctamente.');
    } catch (e) {
      printLog.i('Error al eliminar administrador secundario: $e');
      showToast('Error al eliminar el administrador. Inténtalo de nuevo.');
    }
  }

  bool isValidEmail(String email) {
    final RegExp emailRegex = RegExp(
      r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@"
      r"[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)*$",
    );
    return emailRegex.hasMatch(email);
  }

  Future<int?> showPinSelectionDialog(BuildContext context) async {
    int? selectedPin;
    return showDialog<int>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              backgroundColor: color3,
              title: Text(
                'Selecciona un pin',
                style: GoogleFonts.poppins(
                  color: color0,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SingleChildScrollView(
                child: ListBody(
                  children: List.generate(parts.length, (index) {
                    var equipo = parts[index].split(':');
                    printLog.i(equipo);
                    return equipo[0] == '0'
                        ? RadioListTile<int>(
                            title: Text(
                              nicknamesMap['${deviceName}_$index'] ??
                                  'Salida $index',
                              style: GoogleFonts.poppins(
                                color: color0,
                                fontSize: 16,
                              ),
                            ),
                            value: index,
                            groupValue: selectedPin,
                            activeColor: color6,
                            onChanged: (int? value) {
                              setState(() {
                                selectedPin = value;
                              });
                            },
                          )
                        : const SizedBox.shrink();
                  }),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: Text(
                    'Aceptar',
                    style: GoogleFonts.poppins(color: color6),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop(selectedPin);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 30.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              key: keys['managerScreen:titulo']!,
              'Gestión del equipo',
              style: GoogleFonts.poppins(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            //! Opción - Reclamar propiedad del equipo o dejar de ser propietario
            if (!tenant && (owner == currentUserEmail || owner == '')) ...{
              InkWell(
                key: keys['managerScreen:reclamar']!,
                onTap: () async {
                  if (owner == currentUserEmail) {
                    showAlertDialog(
                      context,
                      false,
                      const Text(
                        '¿Dejar de ser administrador del equipo?',
                      ),
                      const Text(
                        'Esto hará que otras personas puedan conectarse al dispositivo y modificar sus parámetros',
                      ),
                      <Widget>[
                        TextButton(
                          child: const Text('Cancelar'),
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                        ),
                        TextButton(
                          child: const Text('Aceptar'),
                          onPressed: () {
                            try {
                              putOwner(
                                
                                DeviceManager.getProductCode(deviceName),
                                DeviceManager.extractSerialNumber(deviceName),
                                '',
                              );
                              Navigator.of(context).pop();

                              saveATData(
                                
                                DeviceManager.getProductCode(deviceName),
                                DeviceManager.extractSerialNumber(deviceName),
                                false,
                                '',
                                '3000',
                                '100',
                              );

                              setState(() {
                                owner = '';
                                deviceOwner = false;
                              });
                            } catch (e, s) {
                              printLog.i('Error al borrar owner $e Trace: $s');
                              showToast('Error al borrar el administrador.');
                            }
                          },
                        ),
                      ],
                    );
                  } else if (owner == '') {
                    try {
                      putOwner(
                        
                        DeviceManager.getProductCode(deviceName),
                        DeviceManager.extractSerialNumber(deviceName),
                        currentUserEmail,
                      );
                      setState(() {
                        owner = currentUserEmail;
                        deviceOwner = true;
                      });
                      showToast('Ahora eres el propietario del equipo');
                    } catch (e, s) {
                      printLog.i('Error al agregar owner $e Trace: $s');
                      showToast('Error al agregar el administrador.');
                    }
                  } else {
                    showToast('El equipo ya esta reclamado');
                  }
                },
                borderRadius: BorderRadius.circular(15),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 600),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: color6,
                    shape: BoxShape.rectangle,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 10,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Text(
                    owner == currentUserEmail
                        ? 'Dejar de ser dueño del equipo'
                        : 'Reclamar propiedad del equipo',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            },
            const SizedBox(height: 20),
            //! Opciones adicionales con animación
            AnimatedSize(
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeInOut,
              child: AnimatedOpacity(
                opacity: owner == currentUserEmail ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 600),
                child: owner == currentUserEmail
                    ? Column(
                        children: [
                          //! Opciones adicionales existentes (isOwner)
                          if (owner == currentUserEmail) ...[
                            //! Opción 2 - Añadir administradores secundarios
                            InkWell(
                              key: keys['managerScreen:agregarAdmin']!,
                              onTap: () {
                                setState(() {
                                  showSecondaryAdminFields =
                                      !showSecondaryAdminFields;
                                });
                              },
                              borderRadius: BorderRadius.circular(15),
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 0),
                                padding: const EdgeInsets.all(15),
                                decoration: BoxDecoration(
                                  color: color3,
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Añadir administradores\nsecundarios',
                                      style: GoogleFonts.poppins(
                                        fontSize: 15,
                                        color: color0,
                                      ),
                                    ),
                                    Icon(
                                      showSecondaryAdminFields
                                          ? Icons.arrow_drop_up
                                          : Icons.arrow_drop_down,
                                      color: color0,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            AnimatedSize(
                              duration: const Duration(milliseconds: 600),
                              curve: Curves.easeInOut,
                              child: showSecondaryAdminFields
                                  ? Column(
                                      children: [
                                        AnimatedOpacity(
                                          opacity: showSecondaryAdminFields
                                              ? 1.0
                                              : 0.0,
                                          duration:
                                              const Duration(milliseconds: 600),
                                          child: TextField(
                                            controller: emailController,
                                            cursorColor: color3,
                                            style: GoogleFonts.poppins(
                                              color: color3,
                                            ),
                                            decoration: InputDecoration(
                                              labelText: 'Correo electrónico',
                                              labelStyle: GoogleFonts.poppins(
                                                fontSize: 16,
                                                color: color3,
                                              ),
                                              filled: true,
                                              fillColor: Colors.transparent,
                                              focusedBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(15),
                                                borderSide: const BorderSide(
                                                  color: color3,
                                                  width: 2,
                                                ),
                                              ),
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(15),
                                                borderSide: const BorderSide(
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        InkWell(
                                          onTap: () {
                                            if (emailController
                                                .text.isNotEmpty) {
                                              if (adminDevices.length < 3) {
                                                addSecondaryAdmin(
                                                    emailController.text);
                                              } else {
                                                printLog.i('¿Pago? $payAdmSec');
                                                if (payAdmSec) {
                                                  if (adminDevices.length < 6) {
                                                    addSecondaryAdmin(
                                                        emailController.text);
                                                  } else {
                                                    showToast(
                                                        'No puedes añadir más de 6 administradores secundarios');
                                                  }
                                                } else {
                                                  showAlertDialog(
                                                    context,
                                                    true,
                                                    Text(
                                                      'Actualmente no tienes habilitado este beneficio',
                                                      style:
                                                          GoogleFonts.poppins(
                                                              color: color0),
                                                    ),
                                                    Text(
                                                      'En caso de requerirlo puedes solicitarlo vía mail',
                                                      style:
                                                          GoogleFonts.poppins(
                                                              color: color0),
                                                    ),
                                                    [
                                                      TextButton(
                                                        style: TextButton
                                                            .styleFrom(
                                                          foregroundColor:
                                                              const Color(
                                                                  0xFFFFFFFF),
                                                        ),
                                                        onPressed: () async {
                                                          String cuerpo =
                                                              '¡Hola! Me comunico porque busco habilitar la opción de "Administradores secundarios extras" en mi equipo $deviceName\nCódigo de Producto: ${DeviceManager.getProductCode(deviceName)}\nNúmero de Serie: ${DeviceManager.extractSerialNumber(deviceName)}\nDueño actual del equipo: $owner';
                                                          final Uri
                                                              emailLaunchUri =
                                                              Uri(
                                                            scheme: 'mailto',
                                                            path:
                                                                'cobranzas@ibsanitarios.com.ar',
                                                            query:
                                                                encodeQueryParameters(<String,
                                                                    String>{
                                                              'subject':
                                                                  'Habilitación Administradores secundarios extras',
                                                              'body': cuerpo,
                                                              'CC':
                                                                  'pablo@intelligentgas.com.ar'
                                                            }),
                                                          );
                                                          if (await canLaunchUrl(
                                                              emailLaunchUri)) {
                                                            await launchUrl(
                                                                emailLaunchUri);
                                                          } else {
                                                            showToast(
                                                                'No se pudo enviar el correo electrónico');
                                                          }
                                                          navigatorKey
                                                              .currentState
                                                              ?.pop();
                                                        },
                                                        child: const Text(
                                                            'Solicitar'),
                                                      ),
                                                    ],
                                                  );
                                                }
                                              }
                                            } else {
                                              showToast(
                                                  'Por favor, introduce un correo electrónico.');
                                            }
                                          },
                                          borderRadius:
                                              BorderRadius.circular(15),
                                          child: Container(
                                            padding: const EdgeInsets.all(15),
                                            decoration: BoxDecoration(
                                              color: color3,
                                              borderRadius:
                                                  BorderRadius.circular(15),
                                            ),
                                            child: Center(
                                              child: Text(
                                                'Añadir administrador',
                                                style: GoogleFonts.poppins(
                                                  color: color0,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                  : const SizedBox(),
                            ),
                            const SizedBox(height: 10),
                            //! Opción 3 - Ver administradores secundarios
                            InkWell(
                              key: keys['managerScreen:verAdmin']!,
                              onTap: () {
                                setState(() {
                                  showSecondaryAdminList =
                                      !showSecondaryAdminList;
                                });
                              },
                              borderRadius: BorderRadius.circular(15),
                              child: Container(
                                padding: const EdgeInsets.all(15),
                                decoration: BoxDecoration(
                                  color: color3,
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Ver administradores\nsecundarios',
                                      style: GoogleFonts.poppins(
                                        fontSize: 15,
                                        color: color0,
                                      ),
                                    ),
                                    Icon(
                                      showSecondaryAdminList
                                          ? Icons.arrow_drop_up
                                          : Icons.arrow_drop_down,
                                      color: color0,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            AnimatedSize(
                              duration: const Duration(milliseconds: 600),
                              curve: Curves.easeInOut,
                              child: showSecondaryAdminList
                                  ? adminDevices.isEmpty
                                      ? Text(
                                          'No hay administradores secundarios.',
                                          style: GoogleFonts.poppins(
                                            fontSize: 16,
                                            color: color3,
                                          ),
                                        )
                                      : Column(
                                          children: adminDevices.map((email) {
                                            return AnimatedContainer(
                                              duration: const Duration(
                                                  milliseconds: 300),
                                              curve: Curves.easeInOut,
                                              margin:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 5),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 10,
                                                      horizontal: 15),
                                              decoration: BoxDecoration(
                                                color: color3,
                                                borderRadius:
                                                    BorderRadius.circular(15),
                                                border: Border.all(
                                                  color: color0,
                                                  width: 2,
                                                ),
                                                boxShadow: const [
                                                  BoxShadow(
                                                    color: Colors.black12,
                                                    blurRadius: 4,
                                                    offset: Offset(2, 2),
                                                  ),
                                                ],
                                              ),
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      email,
                                                      style:
                                                          GoogleFonts.poppins(
                                                        fontSize: 16,
                                                        color: color0,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(
                                                        Icons.delete,
                                                        color: color5),
                                                    onPressed: () {
                                                      removeSecondaryAdmin(
                                                          email);
                                                    },
                                                  ),
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                        )
                                  : const SizedBox(),
                            ),
                            const SizedBox(height: 10),
                            //! Opción 4 - Alquiler temporario
                            InkWell(
                              key: keys['managerScreen:alquiler']!,
                              onTap: () {
                                if (activatedAT) {
                                  setState(() {
                                    showSmartResident = !showSmartResident;
                                  });
                                } else {
                                  if (!payAT) {
                                    showAlertDialog(
                                      context,
                                      true,
                                      Text(
                                        'Actualmente no tienes habilitado este beneficio',
                                        style:
                                            GoogleFonts.poppins(color: color0),
                                      ),
                                      Text(
                                        'En caso de requerirlo puedes solicitarlo vía mail',
                                        style:
                                            GoogleFonts.poppins(color: color0),
                                      ),
                                      [
                                        TextButton(
                                          style: TextButton.styleFrom(
                                            foregroundColor:
                                                const Color(0xFFFFFFFF),
                                          ),
                                          onPressed: () async {
                                            String cuerpo =
                                                '¡Hola! Me comunico porque busco habilitar la opción de "Alquiler temporario" en mi equipo $deviceName\nCódigo de Producto: ${DeviceManager.getProductCode(deviceName)}\nNúmero de Serie: ${DeviceManager.extractSerialNumber(deviceName)}\nDueño actual del equipo: $owner';
                                            final Uri emailLaunchUri = Uri(
                                              scheme: 'mailto',
                                              path:
                                                  'cobranzas@ibsanitarios.com.ar',
                                              query:
                                                  encodeQueryParameters(<String,
                                                      String>{
                                                'subject':
                                                    'Habilitación Alquiler temporario',
                                                'body': cuerpo,
                                                'CC':
                                                    'pablo@intelligentgas.com.ar'
                                              }),
                                            );
                                            if (await canLaunchUrl(
                                                emailLaunchUri)) {
                                              await launchUrl(emailLaunchUri);
                                            } else {
                                              showToast(
                                                  'No se pudo enviar el correo electrónico');
                                            }
                                            navigatorKey.currentState?.pop();
                                          },
                                          child: const Text('Solicitar'),
                                        ),
                                      ],
                                    );
                                  } else {
                                    setState(() {
                                      showSmartResident = !showSmartResident;
                                    });
                                  }
                                }
                              },
                              borderRadius: BorderRadius.circular(15),
                              child: Container(
                                padding: const EdgeInsets.all(15),
                                decoration: BoxDecoration(
                                  color: color3,
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Alquiler temporario',
                                      style: GoogleFonts.poppins(
                                          fontSize: 15, color: color0),
                                    ),
                                    Icon(
                                      showSmartResident
                                          ? Icons.arrow_drop_up
                                          : Icons.arrow_drop_down,
                                      color: color0,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            AnimatedSize(
                              duration: const Duration(milliseconds: 600),
                              curve: Curves.easeInOut,
                              child: showSmartResident && payAT
                                  ? Column(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(20),
                                          margin:
                                              const EdgeInsets.only(top: 20),
                                          decoration: BoxDecoration(
                                            color: color3,
                                            borderRadius:
                                                BorderRadius.circular(15),
                                            boxShadow: const [
                                              BoxShadow(
                                                color: Colors.black26,
                                                blurRadius: 5,
                                                offset: Offset(0, 3),
                                              ),
                                            ],
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Configura los parámetros del alquiler',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: color0,
                                                ),
                                              ),
                                              const SizedBox(height: 20),
                                              TextField(
                                                controller: tenantController,
                                                keyboardType:
                                                    TextInputType.emailAddress,
                                                style: GoogleFonts.poppins(
                                                    color: color0),
                                                decoration: InputDecoration(
                                                  labelText:
                                                      "Email del inquilino",
                                                  labelStyle:
                                                      GoogleFonts.poppins(
                                                          color: color0),
                                                  enabledBorder:
                                                      OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            15),
                                                    borderSide:
                                                        const BorderSide(
                                                            color: color0),
                                                  ),
                                                  focusedBorder:
                                                      OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            15),
                                                    borderSide:
                                                        const BorderSide(
                                                            color: color0),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 20),
                                              // Mostrar el email actual solo si existe
                                              if (activatedAT)
                                                Container(
                                                  padding:
                                                      const EdgeInsets.all(15),
                                                  decoration: BoxDecoration(
                                                    color: color3,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            15),
                                                    border: Border.all(
                                                        color: color0,
                                                        width: 2),
                                                    boxShadow: const [
                                                      BoxShadow(
                                                        color: Colors.black12,
                                                        blurRadius: 4,
                                                        offset: Offset(2, 2),
                                                      ),
                                                    ],
                                                  ),
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        'Inquilino actual:',
                                                        style:
                                                            GoogleFonts.poppins(
                                                          fontSize: 16,
                                                          color: color0,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 5),
                                                      Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .spaceBetween,
                                                        children: [
                                                          Expanded(
                                                            child: Text(
                                                              globalDATA[
                                                                      '${DeviceManager.getProductCode(deviceName)}/${DeviceManager.extractSerialNumber(deviceName)}']
                                                                  ?['tenant'],
                                                              style: GoogleFonts
                                                                  .poppins(
                                                                fontSize: 14,
                                                                color: color0,
                                                              ),
                                                            ),
                                                          ),
                                                          IconButton(
                                                            icon: const Icon(
                                                              Icons.delete,
                                                              color: Colors
                                                                  .redAccent,
                                                            ),
                                                            onPressed:
                                                                () async {
                                                              await saveATData(
                                                                
                                                                DeviceManager
                                                                    .getProductCode(
                                                                        deviceName),
                                                                DeviceManager
                                                                    .extractSerialNumber(
                                                                        deviceName),
                                                                false,
                                                                '',
                                                                '3000',
                                                                '100',
                                                              );

                                                              setState(() {
                                                                tenantController
                                                                    .clear();
                                                                globalDATA[
                                                                        '${DeviceManager.getProductCode(deviceName)}/${DeviceManager.extractSerialNumber(deviceName)}']
                                                                    ?[
                                                                    'tenant'] = '';
                                                                activatedAT =
                                                                    false;
                                                                dOnOk = false;
                                                                dOffOk = false;
                                                              });
                                                              showToast(
                                                                  "Inquilino eliminado correctamente.");
                                                            },
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),

                                              const SizedBox(height: 10),

                                              // Distancia de apagado y encendido sliders
                                              if (DeviceManager.getProductCode(deviceName) != '020010_IOT' &&
                                                  DeviceManager.getProductCode(
                                                          deviceName) !=
                                                      '050217_IOT' &&
                                                  DeviceManager.getProductCode(
                                                          deviceName) !=
                                                      '020010_IOT') ...{
                                                Text(
                                                  'Distancia de apagado (${distOffValue.round()} metros)',
                                                  style: GoogleFonts.poppins(
                                                      color: color0),
                                                ),
                                                Slider(
                                                  value: distOffValue,
                                                  min: 100,
                                                  max: 300,
                                                  divisions: 200,
                                                  activeColor: color0,
                                                  inactiveColor: color0
                                                      .withValues(alpha: 0.3),
                                                  onChanged: (double value) {
                                                    setState(() {
                                                      distOffValue = value;
                                                      dOffOk = true;
                                                    });
                                                  },
                                                ),
                                                const SizedBox(height: 10),
                                                Text(
                                                  'Distancia de encendido (${distOnValue.round()} metros)',
                                                  style: GoogleFonts.poppins(
                                                    color: color0,
                                                  ),
                                                ),
                                                Slider(
                                                  value: distOnValue,
                                                  min: 3000,
                                                  max: 5000,
                                                  divisions: 200,
                                                  activeColor: color0,
                                                  inactiveColor: color0
                                                      .withValues(alpha: 0.3),
                                                  onChanged: (double value) {
                                                    setState(() {
                                                      distOnValue = value;
                                                      dOnOk = true;
                                                    });
                                                  },
                                                ),
                                                const SizedBox(height: 20),
                                              },
                                              // Botones de Activar y Cancelar
                                              Center(
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    TextButton(
                                                      onPressed: () {
                                                        if (tenantController
                                                            .text.isNotEmpty) {
                                                          saveATData(
                                                            
                                                            DeviceManager
                                                                .getProductCode(
                                                                    deviceName),
                                                            DeviceManager
                                                                .extractSerialNumber(
                                                                    deviceName),
                                                            true,
                                                            tenantController
                                                                .text
                                                                .trim(),
                                                            distOnValue
                                                                .round()
                                                                .toString(),
                                                            distOffValue
                                                                .round()
                                                                .toString(),
                                                          );

                                                          setState(() {
                                                            activatedAT = true;
                                                            globalDATA['${DeviceManager.getProductCode(deviceName)}/${DeviceManager.extractSerialNumber(deviceName)}']
                                                                    ?[
                                                                    'tenant'] =
                                                                tenantController
                                                                    .text
                                                                    .trim();
                                                          });
                                                          showToast(
                                                              'Configuración guardada para el inquilino.');
                                                        } else {
                                                          showToast(
                                                              'Por favor, completa todos los campos');
                                                        }
                                                      },
                                                      style:
                                                          TextButton.styleFrom(
                                                        backgroundColor: color0,
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal: 30,
                                                                vertical: 15),
                                                        shape:
                                                            RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(15),
                                                        ),
                                                      ),
                                                      child: Text(
                                                        'Activar',
                                                        style:
                                                            GoogleFonts.poppins(
                                                                color: color3,
                                                                fontSize: 16),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 20),
                                                    TextButton(
                                                      onPressed: () {
                                                        setState(() {
                                                          showSmartResident =
                                                              false;
                                                        });
                                                      },
                                                      style:
                                                          TextButton.styleFrom(
                                                        backgroundColor: color0,
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal: 30,
                                                                vertical: 15),
                                                        shape:
                                                            RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(15),
                                                        ),
                                                      ),
                                                      child: Text(
                                                        'Cancelar',
                                                        style:
                                                            GoogleFonts.poppins(
                                                                color: color3,
                                                                fontSize: 16),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    )
                                  : const SizedBox(),
                            ),
                            const SizedBox(height: 10),
                          ],
                        ],
                      )
                    : const SizedBox(),
              ),
            ),
            const SizedBox(height: 30),
            if (!tenant &&
                DeviceManager.getProductCode(deviceName) != '027131_IOT' &&
                DeviceManager.getProductCode(deviceName) != '024011_IOT') ...[
              SizedBox(
                key: keys['managerScreen:accesoRapido']!,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (DeviceManager
                                .getProductCode(deviceName) ==
                            '020010_IOT' ||
                        DeviceManager.getProductCode(deviceName) ==
                            '020020_IOT' ||
                        (DeviceManager.getProductCode(deviceName) ==
                                '027313_IOT' &&
                            Versioner.isPosterior(
                                hardwareVersion, '241220A'))) {
                      if (!quickAccesActivated) {
                        int? selectedPin =
                            await showPinSelectionDialog(context);

                        if (selectedPin != null) {
                          pinQuickAccess
                              .addAll({deviceName: selectedPin.toString()});
                          quickAccess.add(deviceName);
                          await savequickAccess(quickAccess);
                          await savepinQuickAccess(pinQuickAccess);
                          setState(() {
                            quickAccesActivated = true;
                          });
                        }
                      } else {
                        quickAccess.remove(deviceName);
                        pinQuickAccess.remove(deviceName);
                        await savequickAccess(quickAccess);
                        await savepinQuickAccess(pinQuickAccess);
                        setState(() {
                          quickAccesActivated = false;
                        });
                      }
                    } else {
                      if (!quickAccesActivated) {
                        quickAccess.add(deviceName);
                        await savequickAccess(quickAccess);
                        setState(() {
                          quickAccesActivated = true;
                        });
                      } else {
                        quickAccess.remove(deviceName);
                        await savequickAccess(quickAccess);
                        setState(() {
                          quickAccesActivated = false;
                        });
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    foregroundColor: color0,
                    backgroundColor: color3,
                    padding: const EdgeInsets.symmetric(
                        vertical: 11, horizontal: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Text(
                    quickAccesActivated
                        ? 'Desactivar acceso rápido'
                        : 'Activar acceso rápido',
                    style: GoogleFonts.poppins(
                      color: color0,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],

            //! activar notificación de desconexión
            // if (owner == '' || owner == currentUserEmail || secondaryAdmin) ...{
            //   ElevatedButton(
            //     key: keys['managerScreen:desconexionNotificacion']!,
            //     onPressed: () async {
            //       if (discNotfActivated) {
            //         showAlertDialog(
            //           context,
            //           true,
            //           Text(
            //             'Confirmar Desactivación',
            //             style: GoogleFonts.poppins(color: color0),
            //           ),
            //           Text(
            //             '¿Estás seguro de que deseas desactivar la notificación de desconexión?',
            //             style: GoogleFonts.poppins(color: color0),
            //           ),
            //           [
            //             TextButton(
            //               onPressed: () {
            //                 Navigator.of(context).pop();
            //               },
            //               child: Text(
            //                 'Cancelar',
            //                 style: GoogleFonts.poppins(color: color0),
            //               ),
            //             ),
            //             TextButton(
            //               onPressed: () async {
            //                 // Actualizar el estado para desactivar la notificación
            //                 setState(() {
            //                   discNotfActivated = false;
            //                   showNotificationOptions = false;
            //                 });

            //                 // Eliminar la configuración de notificación para el dispositivo actual
            //                 configNotiDsc
            //                     .removeWhere((key, value) => key == deviceName);
            //                 await saveconfigNotiDsc(configNotiDsc);

            //                 if (context.mounted) {
            //                   Navigator.of(context).pop();
            //                 }
            //               },
            //               child: Text(
            //                 'Aceptar',
            //                 style: GoogleFonts.poppins(color: color0),
            //               ),
            //             ),
            //           ],
            //         );
            //       } else {
            //         setState(() {
            //           showNotificationOptions = !showNotificationOptions;
            //         });
            //       }
            //     },
            //     style: ElevatedButton.styleFrom(
            //       foregroundColor: color0,
            //       backgroundColor: color3,
            //       padding:
            //           const EdgeInsets.symmetric(vertical: 12, horizontal: 18),
            //       shape: RoundedRectangleBorder(
            //         borderRadius: BorderRadius.circular(20),
            //       ),
            //     ),
            //     child: Row(
            //       mainAxisAlignment: MainAxisAlignment.center,
            //       children: [
            //         Text(
            //           discNotfActivated
            //               ? 'Desactivar notificación\nde desconexión'
            //               : 'Activar notificación\nde desconexión',
            //           style: GoogleFonts.poppins(
            //             fontSize: 18,
            //             color: color0,
            //             fontWeight: FontWeight.bold,
            //           ),
            //           textAlign: TextAlign.center,
            //         ),
            //       ],
            //     ),
            //   ),
            // },

            // Tarjeta de opciones de notificación
            AnimatedSize(
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeInOut,
              child: showNotificationOptions
                  ? Container(
                      padding: const EdgeInsets.all(20),
                      margin: const EdgeInsets.only(top: 20),
                      decoration: BoxDecoration(
                        color: color3,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Selecciona cuándo deseas recibir una notificación en caso de que el equipo se desconecte:',
                            style: GoogleFonts.poppins(
                                color: color0, fontSize: 16),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          RadioListTile<int>(
                            value: 0,
                            groupValue: selectedNotificationOption,
                            onChanged: (int? value) {
                              setState(() {
                                selectedNotificationOption = value!;
                              });
                            },
                            activeColor: color1,
                            title: Text(
                              'Instantáneo',
                              style: GoogleFonts.poppins(color: color0),
                            ),
                          ),
                          RadioListTile<int>(
                            value: 10,
                            groupValue: selectedNotificationOption,
                            onChanged: (int? value) {
                              setState(() {
                                selectedNotificationOption = value!;
                              });
                            },
                            activeColor: color1,
                            title: Text(
                              'Si permanece 10 minutos desconectado',
                              style: GoogleFonts.poppins(color: color0),
                            ),
                          ),
                          RadioListTile<int>(
                            value: 60,
                            groupValue: selectedNotificationOption,
                            onChanged: (int? value) {
                              setState(() {
                                selectedNotificationOption = value!;
                              });
                            },
                            activeColor: color1,
                            title: Text(
                              'Si permanece 1 hora desconectado',
                              style: GoogleFonts.poppins(color: color0),
                            ),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: () async {
                              setState(() {
                                discNotfActivated = true;
                                showNotificationOptions = false;
                              });

                              configNotiDsc[deviceName] =
                                  selectedNotificationOption;
                              await saveconfigNotiDsc(configNotiDsc);

                              showNotification(
                                'Notificación Activada',
                                'Has activado la notificación de desconexión con la opción seleccionada.',
                                'noti',
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: color0,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 15, horizontal: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                            child: Text(
                              'Aceptar',
                              style: GoogleFonts.poppins(
                                  color: color3, fontSize: 16),
                            ),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),

            const SizedBox(height: 10),
            if ((DeviceManager.getProductCode(deviceName) == '022000_IOT' ||
                    DeviceManager.getProductCode(deviceName) == '027000_IOT' ||
                    DeviceManager.getProductCode(deviceName) == '041220_IOT') &&
                hasLED(DeviceManager.getProductCode(deviceName),
                    hardwareVersion)) ...[
              Container(
                key: keys['managerScreen:led']!,
                width: MediaQuery.of(context).size.width * 1.5,
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                decoration: BoxDecoration(
                  color: color3,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Modo del led:',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        textStyle: const TextStyle(
                          color: color0,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Transform.scale(
                      scale: 1.5,
                      child: Switch(
                        activeColor: color3,
                        activeTrackColor: color0,
                        inactiveThumbColor: color3,
                        inactiveTrackColor: color0,
                        trackOutlineColor: const WidgetStatePropertyAll(color3),
                        thumbIcon: WidgetStateProperty.resolveWith<Icon?>(
                          (Set<WidgetState> states) {
                            if (states.contains(WidgetState.selected)) {
                              return const Icon(Icons.nights_stay,
                                  color: color0);
                            } else {
                              return const Icon(Icons.wb_sunny, color: color0);
                            }
                          },
                        ),
                        value: nightMode,
                        onChanged: (value) {
                          setState(() {
                            nightMode = value;
                            printLog.i('Estado: $nightMode');
                            int fun = nightMode ? 1 : 0;
                            String data =
                                '${DeviceManager.getProductCode(deviceName)}[9]($fun)';
                            printLog.i(data);
                            myDevice.toolsUuid.write(data.codeUnits);
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],

            SizedBox(
              key: keys['managerScreen:imagen']!,
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  ImageManager.openImageOptions(context, deviceName, () {
                    setState(() {
                      // La UI se reconstruirá automáticamente para mostrar la nueva imagen
                    });
                  });
                },
                style: ElevatedButton.styleFrom(
                  foregroundColor: color0,
                  backgroundColor: color3,
                  padding: const EdgeInsets.symmetric(
                    vertical: 11,
                    horizontal: 20,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Text(
                  'Cambiar imagen del dispositivo',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(height: 10),

            if (DeviceManager.getProductCode(deviceName) == '050217_IOT') ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    showAlertDialog(
                      context,
                      true,
                      Text(
                        'Beneficios',
                        style: GoogleFonts.poppins(color: color0),
                      ),
                      Text(
                        '- Encendio rapido y sencillo al alcance de tu mano\n- Configura tu temperatura ideal\n- Mayor eficiencia energética\n- Control de consumo inmediato\n- Mayor comodidad\n- Seguridad corte automático sobre temperatura superior a la establecida\n- Programación de encendido por dias o por franjas horarias\n- Mayor durabilidad',
                        style: GoogleFonts.poppins(color: color0),
                      ),
                      [
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: Text(
                            'Cerrar',
                            style: GoogleFonts.poppins(color: color0),
                          ),
                        ),
                      ],
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    foregroundColor: color0,
                    backgroundColor: color3,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: Text(
                    'Beneficios de termotanque smart',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],

            Container(
              width: MediaQuery.of(context).size.width * 1.5,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
              decoration: BoxDecoration(
                color: color3,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Versión de Hardware: $hardwareVersion',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  textStyle: const TextStyle(
                    color: color0,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: MediaQuery.of(context).size.width * 1.5,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
              decoration: BoxDecoration(
                color: color3,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Versión de Software: $softwareVersion',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  textStyle: const TextStyle(
                    color: color0,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(bottom: bottomBarHeight + 30),
            ),
          ],
        ),
      ),
    );
  }
}
