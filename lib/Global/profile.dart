import 'package:flutter/material.dart';
import 'package:caldensmart/master.dart';
import 'package:hugeicons/hugeicons.dart';

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

  // Estado de los elementos desplegables
  bool isAccountOpen = false;
  bool isDevicesOpen = false;
  bool isDomoticaOpen = false;
  bool isDetectorOpen = false;
  bool isContactOpen = false;
  bool isSocialOpen = false;

  // Estado de los sonidos seleccionados en Domótica y Detector

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
        title: const Text(
          'Configuraciones del perfil',
          style: TextStyle(color: color0),
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
                  // Sección Cuenta conectada
                  ListTile(
                    leading:
                        const Icon(HugeIcons.strokeRoundedUser, color: color3),
                    title: const Text(
                      "Cuenta conectada",
                      style:
                          TextStyle(color: color3, fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text(
                      "Ver cuenta conectada",
                      style: TextStyle(color: color3),
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
                              style: const TextStyle(color: color0),
                            ),
                          ),
                          const Divider(color: Colors.transparent),
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
                    title: const Text(
                      "Dispositivos conectados",
                      style:
                          TextStyle(color: color3, fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text(
                      "Ver dispositivos conectados",
                      style: TextStyle(color: color3),
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
                                const Center(
                                  child: Text(
                                    "No hay dispositivos conectados",
                                    style: TextStyle(color: color3),
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
                                            style:
                                                const TextStyle(color: color0),
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
                    title: const Text(
                      "Domótica",
                      style:
                          TextStyle(color: color3, fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text(
                      "alarma para domótica",
                      style: TextStyle(color: color3),
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
                                const SizedBox(
                                    width:
                                        10), // Espacio entre el ícono y el texto
                                Text(
                                  alarmSounds[index],
                                  style: const TextStyle(color: color3),
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
                    title: const Text(
                      "Detector",
                      style:
                          TextStyle(color: color3, fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text(
                      "alarma para detectores",
                      style: TextStyle(color: color3),
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
                                const SizedBox(
                                    width:
                                        10), // Espacio entre el ícono y el texto
                                Text(
                                  alarmSounds[index],
                                  style: const TextStyle(color: color3),
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
                    title: const Text(
                      "Contáctanos",
                      style:
                          TextStyle(color: color3, fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text(
                      "Ver información de contacto",
                      style: TextStyle(color: color3),
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Contacto comercial
                          Container(
                            decoration: BoxDecoration(
                              color: color3,
                              borderRadius: BorderRadius.circular(8.0),
                              border: Border.all(color: color0),
                            ),
                            padding: const EdgeInsets.all(16.0),
                            margin: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Contacto comercial:',
                                  style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: color0),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    sendWhatsAppMessage(
                                      '5491162234181',
                                      '¡Hola! Tengo una duda comercial sobre los productos $appName: \n',
                                    );
                                  },
                                  child: const Row(
                                    children: [
                                      Icon(
                                        HugeIcons.strokeRoundedCall02,
                                        size: 20,
                                        color: color0,
                                      ),
                                      SizedBox(
                                        width: 10,
                                      ),
                                      Text(
                                        '+54 9 11 6223-4181',
                                        style: TextStyle(
                                            fontSize: 20, color: color0),
                                      ),
                                    ],
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    launchEmail(
                                      'ceat@ibsanitarios.com.ar',
                                      'Consulta comercial acerca de la línea $appName',
                                      '¡Hola! Tengo la siguiente duda sobre la línea IoT:\n',
                                    );
                                  },
                                  child: const Row(
                                    children: [
                                      Icon(
                                        HugeIcons.strokeRoundedMail01,
                                        size: 20,
                                        color: color0,
                                      ),
                                      SizedBox(
                                        width: 10,
                                      ),
                                      Expanded(
                                        child: SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          child: Text(
                                            'ceat@ibsanitarios.com.ar',
                                            style: TextStyle(
                                                fontSize: 20, color: color0),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Contacto técnico
                          Container(
                            decoration: BoxDecoration(
                              color: color3,
                              borderRadius: BorderRadius.circular(8.0),
                              border: Border.all(color: color0),
                            ),
                            padding: const EdgeInsets.all(16.0),
                            margin: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Consulta técnica:',
                                  style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: color0),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    launchEmail(
                                      'pablo@intelligentgas.com.ar',
                                      'Consulta ref. $appName',
                                      '¡Hola! Tengo una consulta referida al área de ingeniería sobre mis equipos.\n',
                                    );
                                  },
                                  child: const Row(
                                    children: [
                                      Icon(
                                        HugeIcons.strokeRoundedMail01,
                                        size: 20,
                                        color: color0,
                                      ),
                                      SizedBox(
                                        width: 10,
                                      ),
                                      Expanded(
                                        child: SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          child: Text(
                                            'pablo@intelligentgas.com.ar',
                                            style: TextStyle(
                                                fontSize: 20, color: color0),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Customer service
                          Container(
                            decoration: BoxDecoration(
                              color: color3,
                              borderRadius: BorderRadius.circular(8.0),
                              border: Border.all(color: color0),
                            ),
                            padding: const EdgeInsets.all(16.0),
                            margin: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Customer service:',
                                  style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: color0),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    sendWhatsAppMessage(
                                      '5491162232619',
                                      '¡Hola! Me comunico en relación a uno de mis equipos: \n',
                                    );
                                  },
                                  child: const Row(
                                    children: [
                                      Icon(
                                        HugeIcons.strokeRoundedCall02,
                                        size: 20,
                                        color: color0,
                                      ),
                                      SizedBox(
                                        width: 10,
                                      ),
                                      Text(
                                        '+54 9 11 6223-2619',
                                        style: TextStyle(
                                            fontSize: 20, color: color0),
                                      ),
                                    ],
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    launchEmail(
                                      'service@calefactorescalden.com.ar',
                                      'Consulta sobre línea Smart',
                                      '¡Hola! Me comunico en relación a uno de mis equipos: \n',
                                    );
                                  },
                                  child: const Row(
                                    children: [
                                      Icon(
                                        HugeIcons.strokeRoundedMail01,
                                        size: 20,
                                        color: color0,
                                      ),
                                      SizedBox(
                                        width: 10,
                                      ),
                                      Expanded(
                                        child: SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          child: Text(
                                            'service@calefactorescalden.com.ar',
                                            style: TextStyle(
                                                fontSize: 20, color: color0),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    crossFadeState: isContactOpen
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                  ),

                  const Divider(color: color3),
                  // Sección Nuestras redes
                  ListTile(
                    leading: const Icon(HugeIcons.strokeRoundedShare01,
                        color: color3),
                    title: const Text(
                      "Nuestras redes",
                      style:
                          TextStyle(color: color3, fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text(
                      "Ver nuestras redes sociales",
                      style: TextStyle(color: color3),
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
                            title: const Text(
                              'Instagram',
                              style: TextStyle(color: color3),
                            ),
                            onTap: () {
                              launchURL(
                                  'https://www.instagram.com/calefactores.calden/?hl=en');
                            },
                          ),
                          ListTile(
                            leading: const Icon(
                                HugeIcons.strokeRoundedFacebook01,
                                color: color3),
                            title: const Text(
                              'Facebook',
                              style: TextStyle(color: color3),
                            ),
                            onTap: () {
                              launchURL('https://www.facebook.com/tu_facebook');
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

            // Botón Cerrar sesión al final
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  backgroundColor: color3,
                  side: const BorderSide(color: color3),
                  padding: const EdgeInsets.symmetric(vertical: 15.0),
                ),
                onPressed: () {
                  // Acción para cerrar sesión
                },
                child: const Text(
                  "Cerrar sesión",
                  style: TextStyle(
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
