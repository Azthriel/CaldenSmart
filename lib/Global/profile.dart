import 'package:caldensmart/Global/stored_data.dart';
import 'package:flutter/material.dart';
import 'package:caldensmart/master.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:caldensmart/aws/mqtt/mqtt.dart';
import 'package:amplify_flutter/amplify_flutter.dart';

import '../aws/dynamo/dynamo.dart';
import '../aws/dynamo/dynamo_certificates.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  ProfilePageState createState() => ProfilePageState();
}

class ProfilePageState extends State<ProfilePage> {
  final List<String> alarmSounds = [
    "Sonido 1",
    "Sonido 2",
    "Sonido 3",
    "Sonido 4",
    "Sonido 5",
  ];

  bool isAccountOpen = false;
  bool isDevicesOpen = false;
  bool isDomoticaOpen = false;
  bool isDetectorOpen = false;
  bool isContactOpen = false;
  bool isSocialOpen = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: color3,
        leading: IconButton(
          icon: const Icon(HugeIcons.strokeRoundedArrowLeft02),
          color: color0,
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Text(
          'Configuraciones del perfil',
          style: GoogleFonts.poppins(
              color: color0, fontWeight: FontWeight.bold, fontSize: 20),
        ),
      ),
      body: Container(
        color: color1,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: ListView(
                children: [
                  ListTile(
                    leading:
                        const Icon(HugeIcons.strokeRoundedUser, color: color3),
                    title: Text(
                      "Cuenta",
                      style: GoogleFonts.poppins(
                        color: color3,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      "Ver cuenta conectada",
                      style: GoogleFonts.poppins(
                        color: color3,
                      ),
                    ),
                    onTap: () {
                      setState(() {
                        isAccountOpen = !isAccountOpen;
                      });
                    },
                    trailing: Icon(
                      isAccountOpen
                          ? HugeIcons.strokeRoundedArrowUp01
                          : HugeIcons.strokeRoundedArrowDown01,
                      color: color3,
                    ),
                  ),
                  AnimatedCrossFade(
                    duration: const Duration(milliseconds: 300),
                    firstChild: const SizedBox.shrink(),
                    secondChild: Padding(
                      padding: const EdgeInsets.only(left: 16.0),
                      child: Column(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: color3,
                              borderRadius: BorderRadius.circular(8.0),
                              border: Border.all(color: color0),
                            ),
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              currentUserEmail,
                              style: GoogleFonts.poppins(
                                color: color0,
                              ),
                            ),
                          ),
                          const Divider(color: Colors.transparent),
                          TextButton(
                            onPressed: () {
                              printLog('Hora: ${DateTime.now()}');
                              showAlertDialog(
                                context,
                                false,
                                const Text(
                                  '¿Está seguro que quiere eliminar la cuenta?',
                                ),
                                const Text(
                                  'Al presionar aceptar su cuenta será eliminada, está acción no puede revertirse',
                                ),
                                [
                                  TextButton(
                                    style: const ButtonStyle(
                                      foregroundColor: WidgetStatePropertyAll(
                                        color0,
                                      ),
                                    ),
                                    child: const Text('Cancelar'),
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                    },
                                  ),
                                  TextButton(
                                    style: const ButtonStyle(
                                      foregroundColor: WidgetStatePropertyAll(
                                        color0,
                                      ),
                                    ),
                                    child: const Text('Aceptar'),
                                    onPressed: () async {
                                      await Amplify.Auth.deleteUser();
                                      // launchWebURL(
                                      //     linksOfApp(app, 'Borrar Cuenta'));
                                      if (context.mounted) {
                                        Navigator.of(context).pop();
                                      }
                                    },
                                  ),
                                ],
                              );
                            },
                            child: Text(
                              'Borrar cuenta',
                              style: GoogleFonts.poppins(
                                color: color3,
                              ),
                            ),
                          )
                        ],
                      ),
                    ),
                    crossFadeState: isAccountOpen
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                  ),
                  const Divider(color: color3),
                  ListTile(
                    leading: const Icon(
                        HugeIcons.strokeRoundedComputerPhoneSync,
                        color: color3),
                    title: Text(
                      "Dispositivos",
                      style: GoogleFonts.poppins(
                        color: color3,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      "Ver dispositivos registrados",
                      style: GoogleFonts.poppins(
                        color: color3,
                      ),
                    ),
                    onTap: () {
                      setState(() {
                        isDevicesOpen = !isDevicesOpen;
                      });
                    },
                    trailing: Icon(
                      isDevicesOpen
                          ? HugeIcons.strokeRoundedArrowUp01
                          : HugeIcons.strokeRoundedArrowDown01,
                      color: color3,
                    ),
                  ),
                  AnimatedCrossFade(
                    duration: const Duration(milliseconds: 300),
                    firstChild: const SizedBox.shrink(),
                    secondChild: Padding(
                      padding: const EdgeInsets.only(left: 16.0),
                      child: Column(
                        children: previusConnections.isEmpty
                            ? [
                                Center(
                                  child: Text(
                                    "No hay dispositivos registrados",
                                    style: GoogleFonts.poppins(
                                      color: color3,
                                    ),
                                  ),
                                )
                              ]
                            : previusConnections
                                .map((device) => Center(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 8.0),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: color3,
                                            borderRadius:
                                                BorderRadius.circular(8.0),
                                            border: Border.all(color: color0),
                                          ),
                                          padding: const EdgeInsets.all(16.0),
                                          child: Text(
                                            device,
                                            style: GoogleFonts.poppins(
                                              color: color0,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ))
                                .toList(),
                      ),
                    ),
                    crossFadeState: isDevicesOpen
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                  ),
                  const Divider(color: color3),
                  ListTile(
                    leading: const Icon(HugeIcons.strokeRoundedHome11,
                        color: color3),
                    title: Text(
                      "Domotica",
                      style: GoogleFonts.poppins(
                        color: color3,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      "Alarma para domotica",
                      style: GoogleFonts.poppins(
                        color: color3,
                      ),
                    ),
                    onTap: () {
                      setState(() {
                        isDomoticaOpen = !isDomoticaOpen;
                      });
                    },
                    trailing: Icon(
                      isDomoticaOpen
                          ? HugeIcons.strokeRoundedArrowUp01
                          : HugeIcons.strokeRoundedArrowDown01,
                      color: color3,
                    ),
                  ),
                  AnimatedCrossFade(
                    duration: const Duration(milliseconds: 300),
                    firstChild: const SizedBox.shrink(),
                    secondChild: Padding(
                      padding: const EdgeInsets.only(left: 16.0),
                      child: Column(
                        children: List.generate(alarmSounds.length, (index) {
                          return RadioListTile<int>(
                            title: Row(
                              children: [
                                const Icon(HugeIcons.strokeRoundedVolumeHigh,
                                    color: color3),
                                const SizedBox(width: 10),
                                Text(
                                  alarmSounds[index],
                                  style: GoogleFonts.poppins(
                                    color: color3,
                                  ),
                                ),
                              ],
                            ),
                            activeColor: color3,
                            value: index,
                            groupValue: selectedSoundDomotica,
                            onChanged: (int? value) {
                              setState(() {
                                if (selectedSoundDomotica == value) {
                                  selectedSoundDomotica = null;
                                } else {
                                  selectedSoundDomotica = value;
                                  printLog('Elegí alarma${value! + 1}');
                                  soundOfNotification['020010_IOT'] =
                                      'alarm${value + 1}';
                                }
                              });
                            },
                          );
                        }),
                      ),
                    ),
                    crossFadeState: isDomoticaOpen
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                  ),
                  const Divider(color: color3),
                  ListTile(
                    leading: const Icon(HugeIcons.strokeRoundedHotspot,
                        color: color3),
                    title: Text(
                      "Detector",
                      style: GoogleFonts.poppins(
                        color: color3,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      "Alarma para detectores",
                      style: GoogleFonts.poppins(
                        color: color3,
                      ),
                    ),
                    onTap: () {
                      setState(() {
                        isDetectorOpen = !isDetectorOpen;
                      });
                    },
                    trailing: Icon(
                      isDetectorOpen
                          ? HugeIcons.strokeRoundedArrowUp01
                          : HugeIcons.strokeRoundedArrowDown01,
                      color: color3,
                    ),
                  ),
                  AnimatedCrossFade(
                    duration: const Duration(milliseconds: 300),
                    firstChild: const SizedBox.shrink(),
                    secondChild: Padding(
                      padding: const EdgeInsets.only(left: 16.0),
                      child: Column(
                        children: List.generate(alarmSounds.length, (index) {
                          return RadioListTile<int>(
                            title: Row(
                              children: [
                                const Icon(HugeIcons.strokeRoundedVolumeHigh,
                                    color: color3),
                                const SizedBox(width: 10),
                                Text(
                                  alarmSounds[index],
                                  style: GoogleFonts.poppins(
                                    color: color3,
                                  ),
                                ),
                              ],
                            ),
                            activeColor: color3,
                            value: index,
                            groupValue: selectedSoundDetector,
                            onChanged: (int? value) {
                              setState(() {
                                if (selectedSoundDetector == value) {
                                  selectedSoundDetector = null;
                                } else {
                                  selectedSoundDetector = value;
                                  printLog('Elegí alarma${value! + 1}');
                                  soundOfNotification['015773_IOT'] =
                                      'alarm${value + 1}';
                                }
                              });
                            },
                          );
                        }),
                      ),
                    ),
                    crossFadeState: isDetectorOpen
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                  ),
                  const Divider(color: color3),
                  ListTile(
                    leading: const Icon(HugeIcons.strokeRoundedContactBook,
                        color: color3),
                    title: Text(
                      "Contáctanos",
                      style: GoogleFonts.poppins(
                        color: color3,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      "Ver información de contacto",
                      style: GoogleFonts.poppins(
                        color: color3,
                      ),
                    ),
                    onTap: () {
                      setState(() {
                        isContactOpen = !isContactOpen;
                      });
                    },
                    trailing: Icon(
                      isContactOpen
                          ? HugeIcons.strokeRoundedArrowUp01
                          : HugeIcons.strokeRoundedArrowDown01,
                      color: color3,
                    ),
                  ),
                  AnimatedCrossFade(
                    duration: const Duration(milliseconds: 300),
                    firstChild: const SizedBox.shrink(),
                    secondChild: Padding(
                      padding: const EdgeInsets.only(left: 16.0),
                      child: contactInfo(app),
                    ),
                    crossFadeState: isContactOpen
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                  ),
                  const Divider(color: color3),
                  ListTile(
                    leading: const Icon(HugeIcons.strokeRoundedShare01,
                        color: color3),
                    title: Text(
                      "Nuestras redes",
                      style: GoogleFonts.poppins(
                        color: color3,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      "Ver nuestras redes sociales",
                      style: GoogleFonts.poppins(
                        color: color3,
                      ),
                    ),
                    onTap: () {
                      setState(() {
                        isSocialOpen = !isSocialOpen;
                      });
                    },
                    trailing: Icon(
                      isSocialOpen
                          ? HugeIcons.strokeRoundedArrowUp01
                          : HugeIcons.strokeRoundedArrowDown01,
                      color: color3,
                    ),
                  ),
                  AnimatedCrossFade(
                    duration: const Duration(milliseconds: 300),
                    firstChild: const SizedBox.shrink(),
                    secondChild: Padding(
                      padding: const EdgeInsets.only(left: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ListTile(
                            leading: const Icon(
                                HugeIcons.strokeRoundedInstagram,
                                color: color3),
                            title: Text(
                              'Instagram',
                              style: GoogleFonts.poppins(
                                color: color3,
                              ),
                            ),
                            onTap: () {
                              launchWebURL(linksOfApp(app, 'Instagram'));
                            },
                          ),
                          ListTile(
                            leading: const Icon(
                                HugeIcons.strokeRoundedFacebook01,
                                color: color3),
                            title: Text(
                              'Facebook',
                              style: GoogleFonts.poppins(
                                color: color3,
                              ),
                            ),
                            onTap: () {
                              launchWebURL(linksOfApp(app, 'Facebook'));
                            },
                          ),
                        ],
                      ),
                    ),
                    crossFadeState: isSocialOpen
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                  ),
                  const Divider(color: color3),
                ],
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  backgroundColor: color3,
                  side: const BorderSide(color: color3),
                  padding: const EdgeInsets.symmetric(vertical: 15.0),
                ),
                onPressed: () {
                  showToast('Cerrando sesión...');
                  previusConnections.clear();
                  saveDeviceList(previusConnections);
                  alexaDevices.clear();
                  saveAlexaDevices(alexaDevices);
                  putDevicesForAlexa(service, currentUserEmail, alexaDevices);
                  for (int i = 0; i < topicsToSub.length; i++) {
                    unSubToTopicMQTT(topicsToSub[i]);
                  }
                  topicsToSub.clear();
                  saveTopicList(topicsToSub);
                  backTimerDS?.cancel();
                  Amplify.Auth.signOut(
                    // options: const SignOutOptions(
                    //   globalSignOut: true,
                    // ),
                  );
                  // GoogleSignIn().signOut();
                  Navigator.pop(context);
                  asking();
                },
                child: Text(
                  "Cerrar sesión",
                  style: GoogleFonts.poppins(
                    color: color0,
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
