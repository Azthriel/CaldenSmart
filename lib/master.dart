import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wifi_scan/wifi_scan.dart';
import 'aws/dynamo/dynamo.dart';
import 'aws/dynamo/dynamo_certificates.dart';
import 'aws/mqtt/mqtt.dart';
import 'Global/stored_data.dart';

//! VARIABLES !\\

//*-Base de datos interna app-*\\
Map<String, Map<String, dynamic>> globalDATA = {};
//*-Base de datos interna app-*\\

//*-Colores-*\\
const Color color0 = Color(0xFFE5DACE);
const Color color1 = Color(0xFFCFC8BD);
const Color color2 = Color(0xFFBAB6AE);
const Color color3 = Color(0xFF302b36);
const Color color4 = Color(0xFF91262B);
const Color color5 = Color(0xFFE53030);
const Color color6 = Color(0xFFE77272);
//*-Colores-*\\

//*-Datos de la app-*\\
late bool android;
late String appName;
//*-Datos de la app-*\\

//*-Estado de app-*\\
const bool xProfileMode = bool.fromEnvironment('dart.vm.profile');
const bool xReleaseMode = bool.fromEnvironment('dart.vm.product');
const bool xDebugMode = !xProfileMode && !xReleaseMode;
//*-Estado de app-*\\

//*-Key de la app (uso de navegación y contextos)-*\\
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
//*-Key de la app (uso de navegación y contextos)-*\\

//*-Datos del dispositivo al que te conectaste-*\\
String deviceName = '';
String deviceType = '';
String softwareVersion = '';
String hardwareVersion = '';
String owner = '';
bool deviceOwner = false;
int lastUser = 0;
bool userConnected = false;
String myDeviceid = '';
bool connectionFlag = false;
bool turnOn = false;
double distOnValue = 0.0;
double distOffValue = 0.0;
//*-Datos del dispositivo al que te conectaste-*\\

//*-Relacionado al wifi-*\\
List<WiFiAccessPoint> _wifiNetworksList = [];
String? _currentlySelectedSSID;
Map<String, String?> _wifiPasswordsMap = {};
FocusNode wifiPassNode = FocusNode();
bool _scanInProgress = false;
int? _expandedIndex;
bool wifiError = false;
String errorMessage = '';
String errorSintax = '';
String nameOfWifi = '';
bool isWifiConnected = false;
bool wifilogoConnected = false;
bool atemp = false;
String textState = '';
bool werror = false;
IconData wifiIcon = Icons.wifi_off;
MaterialColor statusColor = Colors.grey;
//*-Relacionado al wifi-*\\

//*-Relacionado al ble-*\\
MyDevice myDevice = MyDevice();
List<int> infoValues = [];
List<int> toolsValues = [];
List<int> ioValues = [];
List<int> varsValues = [];
bool bluetoothOn = true;
//*-Relacionado al ble-*\\

//*-Topics mqtt-*\\
List<String> topicsToSub = [];
//*-Topics mqtt-*\\

//*-Equipos registrados-*\\
List<String> previusConnections = [];
List<String> adminDevices = [];
List<String> alexaDevices = [];
//*-Equipos registrados-*\\

//*-Nicknames-*\\
late String nickname;
Map<String, String> nicknamesMap = {};
Map<String, String> subNicknamesMap = {};
//*-Nicknames-*\\

//*-Notifications-*\\
Map<String, String> tokensOfDevices = {};
Map<String, List<bool>> notificationMap = {};
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();
Map<String, String> soundOfNotification = {};
int? selectedSoundDomotica;
int? selectedSoundDetector;
//*-Notifications-*\\

//*-Relacionado al Alquiler temporario (Airbnb)-*\\
bool payAT = false;
bool activatedAT = false;
int vencimientoAT = 0;
bool tenant = false;
//*-Relacionado al Alquiler temporario (Airbnb)-*\\

//*-Relacionado al Administrador secundario-*\\
bool payAdmSec = false;
bool secondaryAdmin = false;
int vencimientoAdmSec = 0;
//*-Relacionado al Administrador secundario-*\\

//*-Monitoreo Localizacion y Bluetooth*-\\
Timer? locationTimer;
Timer? bluetoothTimer;
bool bleFlag = false;
//*-Monitoreo Localizacion y Bluetooth*-\\

//*-Cognito user flow-*\\
String currentUserEmail = '';
//*-Cognito user flow-*\\

//*-Background functions-*\\
Timer? backTimerDS;
Timer? backTimerCH;
//*-Background functions-*\\

//*-Imagenes Scan-*\\
Map<String, String> deviceImages = {};
//*-Imagenes Scan-*\\

//*-CurvedNavigationBar-*\\
typedef LetIndexPage = bool Function(int value);
//*-CurvedNavigationBar-*\\

//*-AnimSearchBar*-\\
int toggle = 0;
String textFieldValue = '';
//*-AnimSearchBar*-\\

//*-Escenas-*\\
List<String> registeredScenes = [];
List<Map<String, dynamic>> timeScenes = [];
Map<String, List<String>> detectorOff = {};
//*-Escenas-*\\

//*-Omnipresencia-*\\
List<String> devicesToTrack = [];
Map<String, DateTime> lastSeenDevices = {};
Map<String, bool> msgFlag = {};
Timer? bleScanTimer;
//*-Omnipresencia-*\\

//*-Notificación Desconexión-*\\
bool discNotfActivated = false;
Map<String, int> configNotiDsc = {};
//*-Notificación Desconexión-*\\

//*-Control por distancia-*\\
Map<String, bool> isTaskScheduled = {};
//*-Control por distancia-*\\

//*- Roller -*\\
bool distanceControlActive = false;
int actualPosition = 0;
bool rollerMoving = false;
int workingPosition = 0;
String rollerlength = '';
String rollerPolarity = '';
String contrapulseTime = '';
bool awsInit = false;
String rollerRPM = '';
String rollerMicroStep = '';
String rollerIMAX = '';
String rollerIRMSRUN = '';
String rollerIRMSHOLD = '';
bool rollerFreewheeling = false;
String rollerTPWMTHRS = '';
String rollerTCOOLTHRS = '';
String rollerSGTHRS = '';
//*- Roller -*\\

//*-Acceso rápido BLE-*\\
List<String> quickAccess = [];
bool quickAccesActivated = false;
bool quickAction = false;
Map<String, String> pinQuickAccess = {};
//*-Acceso rápido BLE-*\\

// !------------------------------VERSION NUMBER---------------------------------------
//ACORDATE: Cambia el número de versión en el pubspec.yaml antes de publicar
String appVersionNumber = '24111900';
//ACORDATE: 0 = Caldén Smart
int app = 0;
// !------------------------------VERSION NUMBER---------------------------------------

// // -------------------------------------------------------------------------------------------------------------\\ \\

//! FUNCIONES !\\

///*-Permite hacer prints seguros, solo en modo debug-*\\\
///Colores permitidos para [color] son:
///rojo, verde, amarillo, azul, magenta y cyan.
///
///Si no colocas ningún color se pondra por defecto...
void printLog(var text, [String? color]) {
  if (color != null) {
    switch (color.toLowerCase()) {
      case 'rojo':
        color = '\x1B[31m';
        break;
      case 'verde':
        color = '\x1B[32m';
        break;
      case 'amarillo':
        color = '\x1B[33m';
        break;
      case 'azul':
        color = '\x1B[34m';
        break;
      case 'magenta':
        color = '\x1B[35m';
        break;
      case 'cyan':
        color = '\x1B[36m';
        break;
      case 'reset':
        color = '\x1B[0m';
        break;
      default:
        color = '\x1B[0m';
        break;
    }
  } else {
    color = '\x1B[0m';
  }
  if (xDebugMode) {
    if (Platform.isAndroid) {
      // ignore: avoid_print
      print('${color}PrintData: $text\x1B[0m');
    } else {
      // ignore: avoid_print
      print("PrintData: $text");
    }
  }
}
//*-Permite hacer prints seguros, solo en modo debug-*\\

//*-Tipo de Aplicación y parametros-*\\
String nameOfApp(int type) {
  switch (type) {
    case 0:
      return 'Caldén Smart';
    default:
      return 'Caldén Smart';
  }
}

Widget contactInfo(int type) {
  switch (type) {
    case 0:
      return Column(
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
                Text(
                  'Contacto comercial:',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color0,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    sendWhatsAppMessage(
                      '5491162234181',
                      '¡Hola! Tengo una duda comercial sobre los productos $appName: \n',
                    );
                  },
                  child: Row(
                    children: [
                      const Icon(
                        HugeIcons.strokeRoundedWhatsapp,
                        size: 20,
                        color: color0,
                      ),
                      const SizedBox(
                        width: 10,
                      ),
                      Text(
                        '+54 9 11 6223-4181',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          color: color0,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    launchEmail(
                      'comercial@caldensmart.com',
                      'Consulta comercial acerca de la línea $appName',
                      '¡Hola! Tengo la siguiente duda sobre la línea IoT:\n',
                    );
                  },
                  child: Row(
                    children: [
                      const Icon(
                        HugeIcons.strokeRoundedMail01,
                        size: 20,
                        color: color0,
                      ),
                      const SizedBox(
                        width: 10,
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Text(
                            'comercial@caldensmart.com',
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              color: color0,
                            ),
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
                Text(
                  'Consulta técnica:',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color0,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    launchEmail(
                      'serviciotecnico@caldensmart.com',
                      'Consulta ref. $appName',
                      '¡Hola! Tengo una consulta referida al área de ingeniería sobre mis equipos.\n',
                    );
                  },
                  child: Row(
                    children: [
                      const Icon(
                        HugeIcons.strokeRoundedMail01,
                        size: 20,
                        color: color0,
                      ),
                      const SizedBox(
                        width: 10,
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Text(
                            'serviciotecnico@caldensmart.com',
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              color: color0,
                            ),
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
                Text(
                  'Customer service:',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color0,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    sendWhatsAppMessage(
                      '5491162232619',
                      '¡Hola! Me comunico en relación a uno de mis equipos: \n',
                    );
                  },
                  child: Row(
                    children: [
                      const Icon(
                        HugeIcons.strokeRoundedWhatsapp,
                        size: 20,
                        color: color0,
                      ),
                      const SizedBox(
                        width: 10,
                      ),
                      Text(
                        '+54 9 11 6223-2619',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          color: color0,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    launchEmail(
                      'service@caldensmart.com',
                      'Consulta sobre línea Smart',
                      '¡Hola! Me comunico en relación a uno de mis equipos: \n',
                    );
                  },
                  child: Row(
                    children: [
                      const Icon(
                        HugeIcons.strokeRoundedMail01,
                        size: 20,
                        color: color0,
                      ),
                      const SizedBox(
                        width: 10,
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Text(
                            'service@caldensmart.com',
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              color: color0,
                            ),
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
      );
    default:
      return Column(
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
                Text(
                  'Contacto comercial:',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color0,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    sendWhatsAppMessage(
                      '5491162234181',
                      '¡Hola! Tengo una duda comercial sobre los productos $appName: \n',
                    );
                  },
                  child: Row(
                    children: [
                      const Icon(
                        HugeIcons.strokeRoundedWhatsapp,
                        size: 20,
                        color: color0,
                      ),
                      const SizedBox(
                        width: 10,
                      ),
                      Text(
                        '+54 9 11 6223-4181',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          color: color0,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    launchEmail(
                      'comercial@caldensmart.com',
                      'Consulta comercial acerca de la línea $appName',
                      '¡Hola! Tengo la siguiente duda sobre la línea IoT:\n',
                    );
                  },
                  child: Row(
                    children: [
                      const Icon(
                        HugeIcons.strokeRoundedMail01,
                        size: 20,
                        color: color0,
                      ),
                      const SizedBox(
                        width: 10,
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Text(
                            'comercial@caldensmart.com',
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              color: color0,
                            ),
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
                Text(
                  'Consulta técnica:',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color0,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    launchEmail(
                      'serviciotecnico@caldensmart.com',
                      'Consulta ref. $appName',
                      '¡Hola! Tengo una consulta referida al área de ingeniería sobre mis equipos.\n',
                    );
                  },
                  child: Row(
                    children: [
                      const Icon(
                        HugeIcons.strokeRoundedMail01,
                        size: 20,
                        color: color0,
                      ),
                      const SizedBox(
                        width: 10,
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Text(
                            'serviciotecnico@caldensmart.com',
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              color: color0,
                            ),
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
                Text(
                  'Customer service:',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color0,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    sendWhatsAppMessage(
                      '5491162232619',
                      '¡Hola! Me comunico en relación a uno de mis equipos: \n',
                    );
                  },
                  child: Row(
                    children: [
                      const Icon(
                        HugeIcons.strokeRoundedWhatsapp,
                        size: 20,
                        color: color0,
                      ),
                      const SizedBox(
                        width: 10,
                      ),
                      Text(
                        '+54 9 11 6223-2619',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          color: color0,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    launchEmail(
                      'service@caldensmart.com',
                      'Consulta sobre línea Smart',
                      '¡Hola! Me comunico en relación a uno de mis equipos: \n',
                    );
                  },
                  child: Row(
                    children: [
                      const Icon(
                        HugeIcons.strokeRoundedMail01,
                        size: 20,
                        color: color0,
                      ),
                      const SizedBox(
                        width: 10,
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Text(
                            'service@caldensmart.com',
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              color: color0,
                            ),
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
      );
  }
}

String linksOfApp(int type, String link) {
  switch (link) {
    case 'Privacidad':
      switch (type) {
        case 0:
          return 'https://caldensmart.com/ayuda/privacidad/';
        default:
          return 'https://caldensmart.com/ayuda/privacidad/';
      }
    case 'TerminosDeUso':
      switch (type) {
        case 0:
          return 'https://caldensmart.com/ayuda/terminos-de-uso/';
        default:
          return 'https://caldensmart.com/ayuda/terminos-de-uso/';
      }
    case 'Borrar Cuenta':
      switch (type) {
        default:
          return 'https://caldensmart.com/ayuda/eliminar-cuenta/';
      }
    case 'Instagram':
      switch (type) {
        case 0:
          return 'https://www.instagram.com/caldensmart/';
        default:
          return 'https://www.instagram.com/gonzaa_trillo/';
      }
    case 'Facebook':
      switch (type) {
        case 0:
          return 'https://www.facebook.com/CalefactoresCalden';
        default:
          return 'https://www.facebook.com/CalefactoresCalden';
      }
    case 'Web':
      switch (type) {
        case 0:
          return 'https://caldensmart.com';
        default:
          return 'https://caldensmart.com';
      }
    default:
      switch (type) {
        case 0:
          return 'https://caldensmart.com';
        default:
          return 'https://caldensmart.com';
      }
  }
}
//*-Tipo de Aplicación y parametros-*\\

//*-Funciones diversas-*\\
void showToast(String message) {
  printLog('Toast: $message');
  Fluttertoast.showToast(
    msg: message,
    toastLength: Toast.LENGTH_SHORT,
    gravity: ToastGravity.BOTTOM,
    timeInSecForIosWeb: 1,
    backgroundColor: color3,
    textColor: color0,
    fontSize: 16.0,
  );
}

String generateRandomNumbers(int length) {
  Random random = Random();
  String result = '';

  for (int i = 0; i < length; i++) {
    result += random.nextInt(10).toString();
  }

  return result;
}

Future<void> sendWhatsAppMessage(String phoneNumber, String message) async {
  var whatsappUrl =
      "whatsapp://send?phone=$phoneNumber&text=${Uri.encodeFull(message)}";
  Uri uri = Uri.parse(whatsappUrl);

  if (await canLaunchUrl(uri)) {
    await launchUrl(uri);
  } else {
    showToast('No se pudo abrir WhatsApp');
  }
}

void launchEmail(String mail, String asunto, String cuerpo) async {
  final Uri emailLaunchUri = Uri(
    scheme: 'mailto',
    path: mail,
    query: encodeQueryParameters(
        <String, String>{'subject': asunto, 'body': cuerpo}),
  );

  if (await canLaunchUrl(emailLaunchUri)) {
    await launchUrl(emailLaunchUri);
  } else {
    showToast('No se pudo abrir el correo electrónico');
  }
}

String encodeQueryParameters(Map<String, String> params) {
  return params.entries
      .map((e) =>
          '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
      .join('&');
}

void launchWebURL(String url) async {
  var uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri);
  } else {
    printLog('No se pudo abrir $url');
  }
}
//*-Funciones diversas-*\\

//*-Gestión de errores en app-*\\
String generateErrorReport(FlutterErrorDetails details) {
  String error =
      'Error: ${details.exception}\nStacktrace: ${details.stack}\nContexto: ${details.context}';
  return error;
}

void sendReportError(String cuerpo) async {
  printLog(cuerpo);
  String encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map((e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }

  String recipients = 'ingenieria@caldensmart.com';
  String subject = 'Reporte de error $deviceName';

  try {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: recipients,
      query: encodeQueryParameters(
        <String, String>{'subject': subject, 'body': cuerpo},
      ),
    );

    if (await canLaunchUrl(emailLaunchUri)) {
      await launchUrl(emailLaunchUri);
    }
    printLog('Correo enviado');
  } catch (error) {
    printLog('Error al enviar el correo: $error');
  }
}
//*-Gestión de errores en app-*\\

//*-Wifi, menú y scanner-*\\
Future<void> sendWifitoBle(String ssid, String pass) async {
  MyDevice myDevice = MyDevice();
  String value = '$ssid#$pass';
  String deviceCommand = DeviceManager.getProductCode(deviceName);
  printLog(deviceCommand);
  String dataToSend = '$deviceCommand[1]($value)';
  printLog(dataToSend);
  try {
    await myDevice.toolsUuid.write(dataToSend.codeUnits);
    printLog('Se mando el wifi ANASHE');
  } catch (e) {
    printLog('Error al conectarse a Wifi $e');
  }
  ssid != 'DSC' ? atemp = true : null;
}

Future<List<WiFiAccessPoint>> _fetchWiFiNetworks() async {
  if (_scanInProgress) return _wifiNetworksList;

  _scanInProgress = true;

  try {
    if (await Permission.locationWhenInUse.request().isGranted) {
      final canScan =
          await WiFiScan.instance.canStartScan(askPermissions: true);
      if (canScan == CanStartScan.yes) {
        final results = await WiFiScan.instance.startScan();
        if (results == true) {
          final networks = await WiFiScan.instance.getScannedResults();

          if (networks.isNotEmpty) {
            final uniqueResults = <String, WiFiAccessPoint>{};
            for (var network in networks) {
              if (network.ssid.isNotEmpty) {
                uniqueResults[network.ssid] = network;
              }
            }

            _wifiNetworksList = uniqueResults.values.toList()
              ..sort((a, b) => b.level.compareTo(a.level));
          }
        }
      } else {
        printLog('No se puede iniciar el escaneo.');
      }
    } else {
      printLog('Permiso de ubicación denegado.');
    }
  } catch (e) {
    printLog('Error durante el escaneo de WiFi: $e');
  } finally {
    _scanInProgress = false;
  }

  return _wifiNetworksList;
}

void wifiText(BuildContext context) {
  bool isAddingNetwork = false;
  String manualSSID = '';
  String manualPassword = '';

  showDialog(
    barrierDismissible: true,
    context: context,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          // Función para construir la vista principal
          Widget buildMainView() {
            if (!_scanInProgress && _wifiNetworksList.isEmpty && android) {
              _fetchWiFiNetworks().then((wifiNetworks) {
                setState(() {
                  _wifiNetworksList = wifiNetworks;
                });
              });
            }

            return AlertDialog(
              backgroundColor: const Color(0xff1f1d20),
              title: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    const Text.rich(
                      TextSpan(
                        text: 'Estado de conexión: ',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFFFFFFFF),
                        ),
                      ),
                    ),
                    Text.rich(
                      TextSpan(
                        text: isWifiConnected ? 'Conectado' : 'Desconectado',
                        style: TextStyle(
                          color: isWifiConnected ? Colors.green : Colors.red,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  ],
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (werror) ...[
                      Text.rich(
                        TextSpan(
                          text: 'Error: $errorMessage',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFFFFFFFF),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text.rich(
                        TextSpan(
                          text: 'Sintax: $errorSintax',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFFFFFFFF),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: [
                        const Text.rich(
                          TextSpan(
                            text: 'Red actual: ',
                            style: TextStyle(
                                fontSize: 20,
                                color: Color(0xFFFFFFFF),
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        Text(
                          nameOfWifi,
                          style: const TextStyle(
                            fontSize: 20,
                            color: Color(0xFFFFFFFF),
                          ),
                        ),
                      ]),
                    ),
                    if (isWifiConnected) ...[
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: () {
                          sendWifitoBle('DSC', 'DSC');
                          Navigator.of(context).pop();
                        },
                        style: const ButtonStyle(
                          foregroundColor: WidgetStatePropertyAll(
                            Color(0xFFFFFFFF),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Icon(Icons.signal_wifi_off),
                            Text('Desconectar Red Actual')
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    if (android) ...[
                      _wifiNetworksList.isEmpty && _scanInProgress
                          ? const Center(
                              child: CircularProgressIndicator(
                                  color: Colors.white))
                          : SizedBox(
                              width: double.maxFinite,
                              height: 200.0,
                              child: ListView.builder(
                                itemCount: _wifiNetworksList.length,
                                itemBuilder: (context, index) {
                                  final network = _wifiNetworksList[index];
                                  int nivel = network.level;
                                  // printLog('${network.ssid}: $nivel dBm ');
                                  return nivel >= -80
                                      ? SizedBox(
                                          child: ExpansionTile(
                                            initiallyExpanded:
                                                _expandedIndex == index,
                                            onExpansionChanged: (bool open) {
                                              if (open) {
                                                wifiPassNode.requestFocus();
                                                setState(() {
                                                  _expandedIndex = index;
                                                });
                                              } else {
                                                setState(() {
                                                  _expandedIndex = null;
                                                });
                                              }
                                            },
                                            leading: Icon(
                                              nivel >= -30
                                                  ? Icons.signal_wifi_4_bar
                                                  : // Excelente
                                                  nivel >= -67
                                                      ? Icons.signal_wifi_4_bar
                                                      : // Muy buena
                                                      nivel >= -70
                                                          ? Icons
                                                              .network_wifi_3_bar
                                                          : // Okay
                                                          nivel >= -80
                                                              ? Icons
                                                                  .network_wifi_2_bar
                                                              : // No buena
                                                              Icons
                                                                  .signal_wifi_off, // Inusable
                                              color: Colors.white,
                                            ),
                                            title: Text(
                                              network.ssid,
                                              style: const TextStyle(
                                                  color: Colors.white),
                                            ),
                                            backgroundColor:
                                                const Color(0xff1f1d20),
                                            collapsedBackgroundColor:
                                                const Color(0xff1f1d20),
                                            textColor: Colors.white,
                                            iconColor: Colors.white,
                                            children: [
                                              Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 16.0,
                                                        vertical: 8.0),
                                                child: Row(
                                                  children: [
                                                    const Icon(
                                                      Icons.lock,
                                                      color: Colors.white,
                                                      size: 20,
                                                    ),
                                                    const SizedBox(width: 8.0),
                                                    Expanded(
                                                      child: TextField(
                                                        focusNode: wifiPassNode,
                                                        style: const TextStyle(
                                                          color:
                                                              Color(0xFFFFFFFF),
                                                        ),
                                                        decoration:
                                                            const InputDecoration(
                                                          hintText:
                                                              'Escribir contraseña',
                                                          hintStyle: TextStyle(
                                                            color: Colors.grey,
                                                          ),
                                                          enabledBorder:
                                                              UnderlineInputBorder(
                                                            borderSide:
                                                                BorderSide(
                                                                    color: Colors
                                                                        .white),
                                                          ),
                                                          focusedBorder:
                                                              UnderlineInputBorder(
                                                            borderSide:
                                                                BorderSide(
                                                                    color: Colors
                                                                        .blue),
                                                          ),
                                                          border:
                                                              UnderlineInputBorder(
                                                            borderSide:
                                                                BorderSide(
                                                                    color: Colors
                                                                        .white),
                                                          ),
                                                        ),
                                                        obscureText: true,
                                                        onChanged: (value) {
                                                          setState(() {
                                                            _currentlySelectedSSID =
                                                                network.ssid;
                                                            _wifiPasswordsMap[
                                                                    network
                                                                        .ssid] =
                                                                value;
                                                          });
                                                        },
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      : const SizedBox.shrink();
                                },
                              ),
                            ),
                    ] else ...[
                      SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Campo para SSID
                            Row(
                              children: [
                                const Icon(
                                  Icons.wifi,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 8.0),
                                Expanded(
                                  child: TextField(
                                    cursorColor: Colors.white,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: const InputDecoration(
                                      hintText: 'Agregar WiFi',
                                      hintStyle: TextStyle(color: Colors.grey),
                                      enabledBorder: UnderlineInputBorder(
                                        borderSide:
                                            BorderSide(color: Colors.white),
                                      ),
                                      focusedBorder: UnderlineInputBorder(
                                        borderSide:
                                            BorderSide(color: Colors.white),
                                      ),
                                    ),
                                    onChanged: (value) {
                                      manualSSID = value;
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                const Icon(
                                  Icons.lock,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 8.0),
                                Expanded(
                                  child: TextField(
                                    cursorColor: Colors.white,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: const InputDecoration(
                                      hintText: 'Contraseña',
                                      hintStyle: TextStyle(color: Colors.grey),
                                      enabledBorder: UnderlineInputBorder(
                                        borderSide:
                                            BorderSide(color: Colors.white),
                                      ),
                                      focusedBorder: UnderlineInputBorder(
                                        borderSide:
                                            BorderSide(color: Colors.white),
                                      ),
                                    ),
                                    obscureText: true,
                                    onChanged: (value) {
                                      manualPassword = value;
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ]
                  ],
                ),
              ),
              actions: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.qr_code,
                        color: Color(0xFFFFFFFF),
                      ),
                      iconSize: 30,
                      onPressed: () async {
                        PermissionStatus permissionStatusC =
                            await Permission.camera.request();
                        if (!permissionStatusC.isGranted) {
                          await Permission.camera.request();
                        }
                        permissionStatusC = await Permission.camera.status;
                        if (permissionStatusC.isGranted) {
                          openQRScanner(navigatorKey.currentContext ?? context);
                        }
                      },
                    ),
                    android
                        ? TextButton(
                            style: const ButtonStyle(),
                            child: const Text(
                              'Agregar Red',
                              style: TextStyle(
                                color: Color(0xFFFFFFFF),
                              ),
                            ),
                            onPressed: () {
                              setState(() {
                                isAddingNetwork = true;
                              });
                            },
                          )
                        : const SizedBox.shrink(),
                    TextButton(
                      style: const ButtonStyle(),
                      child: const Text(
                        'Conectar',
                        style: TextStyle(
                          color: Color(0xFFFFFFFF),
                        ),
                      ),
                      onPressed: () {
                        if (_currentlySelectedSSID != null &&
                            _wifiPasswordsMap[_currentlySelectedSSID] != null) {
                          printLog(
                              '$_currentlySelectedSSID#${_wifiPasswordsMap[_currentlySelectedSSID]}');
                          sendWifitoBle(_currentlySelectedSSID!,
                              _wifiPasswordsMap[_currentlySelectedSSID]!);
                          Navigator.of(context).pop();
                        }
                      },
                    ),
                  ],
                ),
              ],
            );
          }

          Widget buildAddNetworkView() {
            return AlertDialog(
              backgroundColor: const Color(0xff1f1d20),
              title: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Color(0xFFFFFFFF),
                    ),
                    onPressed: () {
                      setState(() {
                        isAddingNetwork = false;
                      });
                    },
                  ),
                  const Text(
                    'Agregar red\nmanualmente',
                    style: TextStyle(
                      color: Color(0xFFFFFFFF),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Campo para SSID
                    Row(
                      children: [
                        const Icon(
                          Icons.wifi,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 8.0),
                        Expanded(
                          child: TextField(
                            cursorColor: Colors.white,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              hintText: 'Agregar WiFi',
                              hintStyle: TextStyle(color: Colors.grey),
                              enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: Colors.white),
                              ),
                              focusedBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: Colors.white),
                              ),
                            ),
                            onChanged: (value) {
                              manualSSID = value;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Icon(
                          Icons.lock,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 8.0),
                        Expanded(
                          child: TextField(
                            cursorColor: Colors.white,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              hintText: 'Contraseña',
                              hintStyle: TextStyle(color: Colors.grey),
                              enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: Colors.white),
                              ),
                              focusedBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: Colors.white),
                              ),
                            ),
                            obscureText: true,
                            onChanged: (value) {
                              manualPassword = value;
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    if (manualSSID.isNotEmpty && manualPassword.isNotEmpty) {
                      printLog('$manualSSID#$manualPassword');

                      sendWifitoBle(manualSSID, manualPassword);
                      Navigator.of(context).pop();
                    } else {}
                  },
                  style: ButtonStyle(
                    backgroundColor:
                        WidgetStateProperty.all<Color>(const Color(0xff1f1d20)),
                  ),
                  child: const Text(
                    'Agregar',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          }

          return isAddingNetwork
              ? buildAddNetworkView()
              : buildMainView(); // Mostrar la vista correspondiente
        },
      );
    },
  ).then((_) {
    _scanInProgress = false;
    _expandedIndex = null;
  });
}

String getWifiErrorSintax(int errorCode) {
  switch (errorCode) {
    case 1:
      return "WIFI_REASON_UNSPECIFIED";
    case 2:
      return "WIFI_REASON_AUTH_EXPIRE";
    case 3:
      return "WIFI_REASON_AUTH_LEAVE";
    case 4:
      return "WIFI_REASON_ASSOC_EXPIRE";
    case 5:
      return "WIFI_REASON_ASSOC_TOOMANY";
    case 6:
      return "WIFI_REASON_NOT_AUTHED";
    case 7:
      return "WIFI_REASON_NOT_ASSOCED";
    case 8:
      return "WIFI_REASON_ASSOC_LEAVE";
    case 9:
      return "WIFI_REASON_ASSOC_NOT_AUTHED";
    case 10:
      return "WIFI_REASON_DISASSOC_PWRCAP_BAD";
    case 11:
      return "WIFI_REASON_DISASSOC_SUPCHAN_BAD";
    case 12:
      return "WIFI_REASON_BSS_TRANSITION_DISASSOC";
    case 13:
      return "WIFI_REASON_IE_INVALID";
    case 14:
      return "WIFI_REASON_MIC_FAILURE";
    case 15:
      return "WIFI_REASON_4WAY_HANDSHAKE_TIMEOUT";
    case 16:
      return "WIFI_REASON_GROUP_KEY_UPDATE_TIMEOUT";
    case 17:
      return "WIFI_REASON_IE_IN_4WAY_DIFFERS";
    case 18:
      return "WIFI_REASON_GROUP_CIPHER_INVALID";
    case 19:
      return "WIFI_REASON_PAIRWISE_CIPHER_INVALID";
    case 20:
      return "WIFI_REASON_AKMP_INVALID";
    case 21:
      return "WIFI_REASON_UNSUPP_RSN_IE_VERSION";
    case 22:
      return "WIFI_REASON_INVALID_RSN_IE_CAP";
    case 23:
      return "WIFI_REASON_802_1X_AUTH_FAILED";
    case 24:
      return "WIFI_REASON_CIPHER_SUITE_REJECTED";
    case 25:
      return "WIFI_REASON_TDLS_PEER_UNREACHABLE";
    case 26:
      return "WIFI_REASON_TDLS_UNSPECIFIED";
    case 27:
      return "WIFI_REASON_SSP_REQUESTED_DISASSOC";
    case 28:
      return "WIFI_REASON_NO_SSP_ROAMING_AGREEMENT";
    case 29:
      return "WIFI_REASON_BAD_CIPHER_OR_AKM";
    case 30:
      return "WIFI_REASON_NOT_AUTHORIZED_THIS_LOCATION";
    case 31:
      return "WIFI_REASON_SERVICE_CHANGE_PERCLUDES_TS";
    case 32:
      return "WIFI_REASON_UNSPECIFIED_QOS";
    case 33:
      return "WIFI_REASON_NOT_ENOUGH_BANDWIDTH";
    case 34:
      return "WIFI_REASON_MISSING_ACKS";
    case 35:
      return "WIFI_REASON_EXCEEDED_TXOP";
    case 36:
      return "WIFI_REASON_STA_LEAVING";
    case 37:
      return "WIFI_REASON_END_BA";
    case 38:
      return "WIFI_REASON_UNKNOWN_BA";
    case 39:
      return "WIFI_REASON_TIMEOUT";
    case 46:
      return "WIFI_REASON_PEER_INITIATED";
    case 47:
      return "WIFI_REASON_AP_INITIATED";
    case 48:
      return "WIFI_REASON_INVALID_FT_ACTION_FRAME_COUNT";
    case 49:
      return "WIFI_REASON_INVALID_PMKID";
    case 50:
      return "WIFI_REASON_INVALID_MDE";
    case 51:
      return "WIFI_REASON_INVALID_FTE";
    case 67:
      return "WIFI_REASON_TRANSMISSION_LINK_ESTABLISH_FAILED";
    case 68:
      return "WIFI_REASON_ALTERATIVE_CHANNEL_OCCUPIED";
    case 200:
      return "WIFI_REASON_BEACON_TIMEOUT";
    case 201:
      return "WIFI_REASON_NO_AP_FOUND";
    case 202:
      return "WIFI_REASON_AUTH_FAIL";
    case 203:
      return "WIFI_REASON_ASSOC_FAIL";
    case 204:
      return "WIFI_REASON_HANDSHAKE_TIMEOUT";
    case 205:
      return "WIFI_REASON_CONNECTION_FAIL";
    case 206:
      return "WIFI_REASON_AP_TSF_RESET";
    case 207:
      return "WIFI_REASON_ROAMING";
    default:
      return "Error Desconocido";
  }
}
//*-Wifi, menú y scanner-*\\

//*-Qr scanner-*\\
Future<void> openQRScanner(BuildContext context) async {
  try {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      var qrResult = await navigatorKey.currentState
          ?.push(MaterialPageRoute(builder: (context) => const QRScanPage()));
      if (qrResult != null) {
        var wifiData = parseWifiQR(qrResult);
        sendWifitoBle(wifiData['SSID']!, wifiData['password']!);
      }
    });
  } catch (e) {
    printLog("Error during navigation: $e");
  }
}

Map<String, String> parseWifiQR(String qrContent) {
  printLog(qrContent);
  final ssidMatch = RegExp(r'S:([^;]+)').firstMatch(qrContent);
  final passwordMatch = RegExp(r'P:([^;]+)').firstMatch(qrContent);

  final ssid = ssidMatch?.group(1) ?? '';
  final password = passwordMatch?.group(1) ?? '';
  return {"SSID": ssid, "password": password};
}
//*-Qr scanner-*\\

//*-Notificaciones-*\\
Future<void> initNotifications() async {
  AndroidNotificationChannel channel = AndroidNotificationChannel(
    'caldenSmart',
    'Eventos',
    description: 'Notificaciones de eventos en $appName',
    importance: Importance.high,
    enableLights: true,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  if (Platform.isIOS || Platform.isAndroid) {
    await flutterLocalNotificationsPlugin.initialize(
      const InitializationSettings(
        iOS: DarwinInitializationSettings(),
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
  }

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>()
      ?.requestPermissions(alert: true, badge: true, sound: true);

  printLog('Notificaciones iniciadas');
}

@pragma('vm:entry-point')
Future<void> handleNotifications(RemoteMessage message) async {
  android = Platform.isAndroid;
  try {
    printLog('Llegó esta notif: ${message.data}', 'rojo');
    String product = message.data['pc']!;
    String number = message.data['sn']!;
    String device = DeviceManager.recoverDeviceName(product, number);
    String sound = soundOfNotification[product] ?? 'alarm2';
    String caso = message.data['case']!;

    printLog('El caso que llego es $caso');

    if (caso == 'Alarm') {
      if (product == '015773_IOT') {
        final now = DateTime.now();
        String displayTitle = '¡ALERTA EN ${nicknamesMap[device] ?? device}!';
        String displayMessage =
            'El detector disparó una alarma.\nA las ${now.hour > 10 ? now.hour : '0${now.hour}'}:${now.minute > 10 ? now.minute : '0${now.minute}'} del ${now.day}/${now.month}/${now.year}';
        showNotification(displayTitle.toUpperCase(), displayMessage, sound);
        printLog('Esta el cortito ${detectorOff.keys.contains(device)}');
        if (detectorOff.keys.contains(device)) {
          List<String> equipos = detectorOff[device] ?? [];

          for (String equipo in equipos) {
            printLog('Apago $equipo');
            String deviceSerialNumber =
                DeviceManager.extractSerialNumber(equipo);
            String productCode = DeviceManager.getProductCode(equipo);
            String topic = 'devices_rx/$productCode/$deviceSerialNumber';
            String topic2 = 'devices_tx/$productCode/$deviceSerialNumber';
            String message = jsonEncode({"w_status": false});
            sendMessagemqtt(topic, message);
            sendMessagemqtt(topic2, message);
          }
        }
      } else if (product == '020010_IOT') {
        final now = DateTime.now();
        String entry = subNicknamesMap['$device/-/${message.data['entry']!}'] ??
            'Entrada${message.data['entry']!}';
        String displayTitle = '¡ALERTA EN ${nicknamesMap[device] ?? device}!';
        String displayMessage =
            'La $entry disparó una alarma.\nA las ${now.hour > 10 ? now.hour : '0${now.hour}'}:${now.minute > 10 ? now.minute : '0${now.minute}'} del ${now.day}/${now.month}/${now.year}';
        if (notificationMap['$product/$number']![
            int.parse(message.data['entry']!)]) {
          printLog(
              'En la lista: ${notificationMap['$product/$number']!} en la posición ${message.data['entry']!} hay un true');
          showNotification(displayTitle.toUpperCase(), displayMessage, sound);
        }
      }
    } else if (caso == 'Disconnect') {
      // if (product == '015773_IOT') {
      //   final now = DateTime.now();
      //   String displayTitle =
      //       '¡El equipo ${nicknamesMap[device] ?? device} se desconecto!';
      //   String displayMessage =
      //       'Se detecto una desconexión a las ${now.hour > 10 ? now.hour : '0${now.hour}'}:${now.minute > 10 ? now.minute : '0${now.minute}'} del ${now.day}/${now.month}/${now.year}';
      //   showNotification(displayTitle, displayMessage, 'noti');
      // }

      configNotiDsc = await loadconfigNotiDsc();
      if (configNotiDsc.keys.toList().contains(device)) {
        final now = DateTime.now();
        int espera = configNotiDsc[device] ?? 0;
        printLog('La espera son $espera minutos', "cyan");
        printLog('Empezo la espera ${DateTime.now()}', "cyan");
        await Future.delayed(
          Duration(minutes: espera),
        );
        printLog('Termino la espera ${DateTime.now()}', "cyan");
        await queryItems(service, product, number);
        bool cstate = globalDATA['$product/$number']?['cstate'] ?? false;
        printLog('El cstate después de la espera es $cstate');
        if (!cstate) {
          String displayTitle =
              '¡El equipo ${nicknamesMap[device] ?? device} se desconecto!';
          String displayMessage =
              'Se detecto una desconexión a las ${now.hour > 10 ? now.hour : '0${now.hour}'}:${now.minute > 10 ? now.minute : '0${now.minute}'} del ${now.day}/${now.month}/${now.year}';
          showNotification(displayTitle, displayMessage, 'noti');
        }
      }
    }
  } catch (e, s) {
    printLog("Error: $e");
    printLog("Trace: $s");
  }
}

void showNotification(String title, String body, String sonido) async {
  printLog('Titulo: $title');
  printLog('Body: $body');
  printLog('Sonido: $sonido');
  try {
    int notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await flutterLocalNotificationsPlugin.show(
      notificationId,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'CaldénSmart_$sonido',
          'Eventos',
          icon: '@mipmap/ic_launcher',
          sound: RawResourceAndroidNotificationSound(sonido.toLowerCase()),
          enableVibration: true,
          importance: Importance.max,
        ),
        iOS: DarwinNotificationDetails(
          sound: '$sonido.wav',
          presentSound: true,
        ),
      ),
    );
    // printLog("Notificacion enviada anacardamente nasharda");
  } catch (e, s) {
    printLog('Error enviando notif: $e');
    printLog(s);
  }
}

void setupToken(String pc, String sn, String device) async {
  try {
    // Si es IOS recibo el APNS primero
    if (!android) {
      final apnsToken = await FirebaseMessaging.instance.getAPNSToken();
      printLog("Token APNS: $apnsToken");
      if (apnsToken == null) {
        printLog("Error al obtener el APNS");
        showToast("Error al obtener token");
        return;
      }
    }

    // Obtener token actual
    String? token = await FirebaseMessaging.instance.getToken();
    printLog("Token actual de Firebase: $token", 'Magenta');
    // Obtén los tokens existentes
    List<String> tokens = await getTokens(service, pc, sn);
    printLog('Tokens: $tokens');
    if (token != null) {
      // Remueve el token previo del dispositivo si existe
      if (tokensOfDevices[device] != null &&
          tokens.contains(tokensOfDevices[device])) {
        tokens.remove(tokensOfDevices[device]);
      }
      // Agrega el token actual a la lista
      tokens.add(token);
      // Actualiza los tokens en tu backend
      await putTokens(service, pc, sn, tokens);
      // Actualiza el diccionario local con el nuevo token
      tokensOfDevices[device] = token;
      saveToken(tokensOfDevices);
      printLog('Token agregado exitosamente');
    }
    // Escucha cuando el token cambie
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      printLog('Token actualizado: $newToken', 'Magenta');
      // Obtén los tokens actualizados
      List<String> tokens = await getTokens(service, pc, sn);
      // Elimina el token anterior, si existe
      if (tokensOfDevices[device] != null &&
          tokens.contains(tokensOfDevices[device])) {
        tokens.remove(tokensOfDevices[device]);
      }
      // Agrega el nuevo token
      tokens.add(newToken);
      // Actualiza el backend con los nuevos tokens
      await putTokens(service, pc, sn, tokens);
      // Guarda el nuevo token localmente
      tokensOfDevices[device] = newToken;
      saveToken(tokensOfDevices);
      printLog('Token actualizado exitosamente');
    });
  } catch (e, s) {
    printLog('Error setupear token $e');
    printLog('Tracke anashardopolis $s');
  }
}
//*-Notificaciones-*\\

//*-Monitoreo Localizacion y Bluetooth*-\\
void startLocationMonitoring() {
  locationTimer = Timer.periodic(
      const Duration(seconds: 10), (Timer t) => locationStatus());
}

void locationStatus() async {
  await NativeService.isLocationServiceEnabled();
}

void startBluetoothMonitoring() {
  bluetoothTimer = Timer.periodic(
      const Duration(seconds: 10), (Timer t) => bluetoothStatus());
}

void bluetoothStatus() async {
  await NativeService.isBluetoothServiceEnabled();
}
//*-Monitoreo Localizacion y Bluetooth*-\\

//*-Admin secundarios y alquiler temporario-*\\
Future<void> analizePayment(
  String pc,
  String sn,
) async {
  List<DateTime> expDates = await getDates(service, pc, sn);

  vencimientoAdmSec = expDates[0].difference(DateTime.now()).inDays;

  payAdmSec = vencimientoAdmSec > 0;

  printLog('--------------Administradores secundarios--------------');
  printLog(expDates[0].toIso8601String());
  printLog('Se vence en $vencimientoAdmSec dias');
  printLog('¿Esta pago? ${payAdmSec ? 'Si' : 'No'}');
  printLog('--------------Administradores secundarios--------------');

  vencimientoAT = expDates[1].difference(DateTime.now()).inDays;

  payAT = vencimientoAT > 0;

  printLog('--------------Alquiler Temporario--------------');
  printLog(expDates[1].toIso8601String());
  printLog('Se vence en $vencimientoAT dias');
  printLog('¿Esta pago? ${payAT ? 'Si' : 'No'}');
  printLog('--------------Alquiler Temporario--------------');
}

void showPaymentTest(bool adm, int vencimiento, BuildContext context) {
  try {
    showAlertDialog(
      context,
      false,
      const Text(
        '¡Estas por perder tu beneficio!',
      ),
      Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Text(
            'Faltan $vencimiento días para que te quedes sin la opción:',
            style: const TextStyle(fontWeight: FontWeight.normal),
          ),
          adm
              ? const Text(
                  'Administradores secundarios extra',
                  style: TextStyle(fontWeight: FontWeight.bold),
                )
              : const Text(
                  'Habilitar alquiler temporario',
                  style: TextStyle(fontWeight: FontWeight.bold),
                )
        ],
      ),
      <Widget>[
        TextButton(
          child: const Text('Ignorar'),
          onPressed: () {
            navigatorKey.currentState?.pop();
          },
        ),
        TextButton(
          child: const Text('Solicitar extensión'),
          onPressed: () async {
            String cuerpo = adm
                ? '¡Hola! Me comunico porque busco extender mi beneficio de "Administradores secundarios extra" en mi equipo $deviceName\nCódigo de Producto: ${DeviceManager.getProductCode(deviceName)}\nNúmero de Serie: ${DeviceManager.extractSerialNumber(deviceName)}\nDueño actual del equipo: $owner\nVencimiento en: $vencimiento dias'
                : '¡Hola! Me comunico porque busco extender mi beneficio "Habilitar alquiler temporario" en mi equipo $deviceName\nCódigo de Producto: ${DeviceManager.getProductCode(deviceName)}\nNúmero de Serie: ${DeviceManager.extractSerialNumber(deviceName)}\nDueño actual del equipo: $owner\nVencimiento en: $vencimiento dias';
            final Uri emailLaunchUri = Uri(
              scheme: 'mailto',
              path: 'cobranzas@caldensmart.com',
              query: encodeQueryParameters(<String, String>{
                'subject': 'Extensión de beneficio',
                'body': cuerpo,
                'CC': 'serviciotecnico@caldensmart.com'
              }),
            );
            if (await canLaunchUrl(emailLaunchUri)) {
              await launchUrl(emailLaunchUri);
            } else {
              showToast('No se pudo enviar el correo electrónico');
            }
            navigatorKey.currentState?.pop();
          },
        ),
      ],
    );
  } catch (e, s) {
    printLog(e);
    printLog(s);
  }
}
//*-Admin secundarios y alquiler temporario-*\\

//*-Cognito user flow-*\\
void asking() async {
  bool alreadyLog = await isUserSignedIn();

  if (!alreadyLog) {
    printLog('Usuario no está logueado');
    navigatorKey.currentState?.pushReplacementNamed('/welcome');
  } else {
    printLog('Usuario logueado');
    navigatorKey.currentState?.pushReplacementNamed('/menu');
  }
}

Future<bool> isUserSignedIn() async {
  final result = await Amplify.Auth.fetchAuthSession();
  return result.isSignedIn;
}

Future<String> getUserMail() async {
  try {
    final attributes = await Amplify.Auth.fetchUserAttributes();
    for (final attribute in attributes) {
      if (attribute.userAttributeKey.key == 'email') {
        return attribute.value; // Retorna el correo electrónico del usuario
      }
    }
  } on AuthException catch (e) {
    printLog('Error fetching user attributes: ${e.message}');
  }
  return ''; // Retorna nulo si no se encuentra el correo electrónico
}

void getMail() async {
  currentUserEmail = await getUserMail();
}
//*-Cognito user flow-*\\

//*-Background functions-*\\
Future<void> initializeService() async {
  try {
    final backService = FlutterBackgroundService();

    await backService.configure(
      iosConfiguration: IosConfiguration(
        onBackground: onIosStart,
        autoStart: true,
        onForeground: onIosStart,
      ),
      androidConfiguration: AndroidConfiguration(
        notificationChannelId: 'caldenSmart',
        foregroundServiceNotificationId: 888,
        initialNotificationTitle: 'Eventos $appName',
        initialNotificationContent:
            'Utilizamos este servicio para ejecutar tareas en la app\nTal como el control por distancia, entre otras...',
        onStart: onStart,
        autoStart: true,
        isForegroundMode: true,
        foregroundServiceTypes: [
          AndroidForegroundType.location,
          AndroidForegroundType.dataSync
        ],
      ),
    );

    initNotifications();

    await backService.isRunning() ? null : await backService.startService();

    printLog('Se inició piola');
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasInitService', true);
  } catch (e, s) {
    printLog('Error al inicializar servicio $e');
    printLog('$s');
  }
}

@pragma('vm:entry-point')
Future<bool> onIosStart(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  await setupMqtt();

  flutterLocalNotificationsPlugin.show(
    888,
    'Servicio inicializado con exito',
    'Gracias por elegir Caldén Smart',
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'caldenSmart',
        'Eventos',
        icon: '@mipmap/ic_launcher',
        sound: RawResourceAndroidNotificationSound('noti'),
        enableVibration: true,
        importance: Importance.max,
      ),
      iOS: DarwinNotificationDetails(),
    ),
  );

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  service.on('distanceControl').listen((event) {
    showNotification('Se inició el control por distancia',
        'Recuerde tener la ubicación del telefono encendida', 'noti');
    backTimerDS = Timer.periodic(const Duration(minutes: 2), (timer) async {
      await backFunctionDS();
    });
  });

  service.on('escenas/controlHorario').listen(
    (event) {
      showNotification('Se inició el control horario',
          'Se configuro un control por horario', 'noti');
      backTimerCH = Timer.periodic(
        const Duration(minutes: 1),
        (timer) async {
          //TODO: Agregar control horario
        },
      );
    },
  );

  service.on('presenceControl').listen(
    (event) {
      printLog('Se llamo el cosito coson');
      showNotification(
          'Se inició el trackeo',
          'Recuerde tener la ubicación y bluetooth del telefono encendida',
          'noti');

      FlutterBluePlus.startScan(
        withKeywords: [
          'Electrico',
          'Gas',
          'Detector',
          'Radiador',
          'Domotica',
          'Rele',
        ],
        androidUsesFineLocation: true,
        continuousUpdates: true,
        removeIfGone: const Duration(seconds: 30),
      );

      FlutterBluePlus.scanResults.listen(
        (results) => backFunctionTrack(results),
      );
    },
  );

  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  await setupMqtt();

  flutterLocalNotificationsPlugin.show(
    888,
    'Servicio inicializado con exito',
    'Gracias por elegir Caldén Smart',
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'caldenSmart',
        'Eventos',
        icon: '@mipmap/ic_launcher',
        sound: RawResourceAndroidNotificationSound('noti'),
        enableVibration: true,
        importance: Importance.max,
      ),
      iOS: DarwinNotificationDetails(
        sound: 'noti.wav',
        presentSound: true,
      ),
    ),
  );

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  service.on('distanceControl').listen((event) {
    showNotification('Se inició el control por distancia',
        'Recuerde tener la ubicación del telefono encendida', 'noti');
    backTimerDS = Timer.periodic(const Duration(minutes: 2), (timer) async {
      await backFunctionDS();
    });
  });

  service.on('escenas/controlHorario').listen(
    (event) {
      showNotification('Se inició el control horario',
          'Se configuro un control por horario', 'noti');
      backTimerCH = Timer.periodic(
        const Duration(minutes: 1),
        (timer) async {
          //TODO: Agregar control horario
        },
      );
    },
  );

  service.on('presenceControl').listen(
    (event) {
      printLog('Se llamo el cosito coson');
      showNotification(
          'Se inició el trackeo',
          'Recuerde tener la ubicación y bluetooth del telefono encendida',
          'noti');

      // NativeService.enableWakelock();
      bleScanTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
        printLog("Voy a hacer un escaneo zarpado asi re kawai xd", "Verde");
        FlutterBluePlus.startScan(
          withKeywords: [
            'Electrico',
            'Gas',
            'Detector',
            'Radiador',
            'Domotica',
            'Rele',
            'Roll'
          ],
          androidUsesFineLocation: true,
          continuousUpdates: false, // Realizar un escaneo puntual y detener
        );

        // Detener el escaneo después de un tiempo fijo
        Future.delayed(const Duration(seconds: 30), () {
          printLog("Paro el escaneo anashajavaibe", "Verde");
          FlutterBluePlus.stopScan();
        });
      });

      // FlutterBluePlus.startScan(
      //   withKeywords: [
      //     'Electrico',
      //     'Gas',
      //     'Detector',
      //     'Radiador',
      //     'Domotica',
      //     'Rele',
      //   ],
      //   androidUsesFineLocation: true,
      //   continuousUpdates: true,
      //   removeIfGone: const Duration(seconds: 30),
      // );

      FlutterBluePlus.scanResults.listen(
        (results) => backFunctionTrack(results),
      );
    },
  );

  service.on('CancelpresenceControl').listen((event) {
    printLog("Pincho el trackeo AÑA", "rojo");
    bleScanTimer?.cancel();
    FlutterBluePlus.stopScan();
  });
}

Future<bool> backFunctionDS() async {
  printLog('Entre a hacer locuritas. ${DateTime.now()}');
  // showNotification('Entre a la función', '${DateTime.now()}');
  try {
    List<String> devicesStored = await loadDevicesForDistanceControl();
    globalDATA = await loadGlobalData();
    Map<String, double> latitudes = await loadLatitude();
    Map<String, double> longitudes = await loadLongitud();

    for (int index = 0; index < devicesStored.length; index++) {
      String name = devicesStored[index];
      String productCode = DeviceManager.getProductCode(name);
      String sn = DeviceManager.extractSerialNumber(name);

      await queryItems(service, productCode, sn);

      double latitude = latitudes[name]!;
      double longitude = longitudes[name]!;

      double distanceOff =
          globalDATA['$productCode/$sn']?['distanceOff'] ?? 100.0;
      double distanceOn =
          globalDATA['$productCode/$sn']?['distanceOn'] ?? 3000.0;

      Position storedLocation = Position(
        latitude: latitude,
        longitude: longitude,
        timestamp: DateTime.now(),
        accuracy: 0.0,
        altitude: 0.0,
        heading: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
        floor: 0,
        isMocked: false,
        altitudeAccuracy: 0.0,
        headingAccuracy: 0.0,
      );

      printLog('Ubicación guardada $storedLocation');

      // showNotification('Ubicación guardada', '$storedLocation');

      Position currentPosition1 = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      printLog('$currentPosition1');

      double distance1 = Geolocator.distanceBetween(
        currentPosition1.latitude,
        currentPosition1.longitude,
        storedLocation.latitude,
        storedLocation.longitude,
      );
      printLog('Distancia 1 : $distance1 metros');

      // showNotification('Distancia 1', '$distance1 metros');

      if (distance1 > 100.0) {
        printLog('Esperando 30 segundos ${DateTime.now()}');

        // showNotification('Esperando 30 segundos', '${DateTime.now()}');

        await Future.delayed(const Duration(seconds: 30));

        Position currentPosition2 = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high);
        printLog('$currentPosition2');

        double distance2 = Geolocator.distanceBetween(
          currentPosition2.latitude,
          currentPosition2.longitude,
          storedLocation.latitude,
          storedLocation.longitude,
        );
        printLog('Distancia 2 : $distance2 metros');

        // showNotification('Distancia 2', '$distance2 metros');

        if (distance2 <= distanceOn && distance1 > distance2) {
          printLog('Usuario cerca, encendiendo');

          showNotification('Encendimos el calefactor',
              'Te acercaste a menos de $distanceOn metros', 'noti');

          globalDATA
              .putIfAbsent('$productCode/$sn', () => {})
              .addAll({"w_status": true});
          saveGlobalData(globalDATA);
          String topic = 'devices_rx/$productCode/$sn';
          String topic2 = 'devices_tx/$productCode/$sn';
          String message = jsonEncode({"w_status": true});
          sendMessagemqtt(topic, message);
          sendMessagemqtt(topic2, message);
          //Ta cerca prendo
        } else if (distance2 >= distanceOff && distance1 < distance2) {
          printLog('Usuario lejos, apagando');

          showNotification('Apagamos el calefactor',
              'Te alejaste a más de $distanceOff metros', 'noti');

          globalDATA
              .putIfAbsent('$productCode/$sn', () => {})
              .addAll({"w_status": false});
          saveGlobalData(globalDATA);
          String topic = 'devices_rx/$productCode/$sn';
          String topic2 = 'devices_tx/$productCode/$sn';
          String message = jsonEncode({"w_status": false});
          sendMessagemqtt(topic, message);
          sendMessagemqtt(topic2, message);
          //Estas re lejos apago el calefactor
        } else {
          printLog('Ningun caso');

          // showNotification('No se cumplio ningún caso', 'No hicimos nada');
        }
      } else {
        printLog('Esta en home');
      }
    }

    return Future.value(true);
  } catch (e, s) {
    printLog('Error en segundo plano $e');
    printLog(s);

    // showNotification('Error en segundo plano $e', '$e');

    return Future.value(false);
  }
}

Future<void> backFunctionTrack(List<ScanResult> results) async {
  List<BluetoothDevice> equipos = [];
  for (ScanResult device in results) {
    equipos.add(device.device);
  }
  // Lista de nombres de plataformas de dispositivos encontrados en el escaneo.
  List<String> foundDeviceNames =
      equipos.map((device) => device.platformName.toLowerCase()).toList();

  printLog("Los anashe equipos son: $foundDeviceNames", "Cyan");
  List<String> devicesTrack = await loadDeviceListToTrack();
  Map<String, Map<String, dynamic>> globalDATA = await loadGlobalData();
  Map<String, bool> flags = await loadmsgFlag();
  // printLog('Vamos a buscar en la lista: $devicesTrack');
  for (String trackedDevice in devicesTrack) {
    if (foundDeviceNames.contains(trackedDevice.toLowerCase())) {
      bool flag = flags[trackedDevice] ?? false;
      // printLog('Flag: $flag');
      if (!flag) {
        printLog(
            'Dispositivo $trackedDevice encontrado en el escaneo.', "verde");
        if (DeviceManager.getProductCode(trackedDevice) == '020010_IOT') {
          List<String> pinToTrack = await loadPinToTrack(trackedDevice);
          printLog('Encontre $pinToTrack');
          for (String pin in pinToTrack) {
            printLog('Voy a mandar al pin $pin');
            globalDATA
                .putIfAbsent(
                    '${DeviceManager.getProductCode(trackedDevice)}/${DeviceManager.extractSerialNumber(trackedDevice)}',
                    () => {})
                .addAll({'io$pin': '0:1:0'});
            saveGlobalData(globalDATA);
            try {
              String topic =
                  'devices_rx/${DeviceManager.getProductCode(trackedDevice)}/${DeviceManager.extractSerialNumber(trackedDevice)}';
              String topic2 =
                  'devices_tx/${DeviceManager.getProductCode(trackedDevice)}/${DeviceManager.extractSerialNumber(trackedDevice)}';
              String message = jsonEncode({'io$pin': '0:1:0'});
              sendMessagemqtt(topic, message);
              sendMessagemqtt(topic2, message);
            } catch (e, s) {
              printLog('Error al enviar valor $e $s');
            }
          }
        } else {
          globalDATA
              .putIfAbsent(
                  '${DeviceManager.getProductCode(trackedDevice)}/${DeviceManager.extractSerialNumber(trackedDevice)}',
                  () => {})
              .addAll({'w_status': true});
          saveGlobalData(globalDATA);
          try {
            String topic =
                'devices_rx/${DeviceManager.getProductCode(trackedDevice)}/${DeviceManager.extractSerialNumber(trackedDevice)}';
            String topic2 =
                'devices_tx/${DeviceManager.getProductCode(trackedDevice)}/${DeviceManager.extractSerialNumber(trackedDevice)}';
            String message = jsonEncode({'w_status': true});
            sendMessagemqtt(topic, message);
            sendMessagemqtt(topic2, message);
          } catch (e, s) {
            printLog('Error al enviar valor $e $s');
          }
        }
      }
      flags[trackedDevice] = true;
      await saveMsgFlag(flags);
    } else {
      bool flag = flags[trackedDevice] ?? false;
      if (flag) {
        printLog(
            'Dispositivo $trackedDevice NO encontrado en el escaneo.', "verde");
        if (DeviceManager.getProductCode(trackedDevice) == '020010_IOT') {
          List<String> pinToTrack = await loadPinToTrack(trackedDevice);
          printLog('Encontre $pinToTrack');
          for (String pin in pinToTrack) {
            printLog('Es el pin io$pin');
            globalDATA
                .putIfAbsent(
                    '${DeviceManager.getProductCode(trackedDevice)}/${DeviceManager.extractSerialNumber(trackedDevice)}',
                    () => {})
                .addAll({'io$pin': '0:0:0'});
            saveGlobalData(globalDATA);
            try {
              String topic =
                  'devices_rx/${DeviceManager.getProductCode(trackedDevice)}/${DeviceManager.extractSerialNumber(trackedDevice)}';
              String topic2 =
                  'devices_tx/${DeviceManager.getProductCode(trackedDevice)}/${DeviceManager.extractSerialNumber(trackedDevice)}';
              String message = jsonEncode({'io$pin': '0:0:0'});
              sendMessagemqtt(topic, message);
              sendMessagemqtt(topic2, message);
            } catch (e, s) {
              printLog('Error al enviar valor $e $s');
            }
          }
        } else {
          globalDATA
              .putIfAbsent(
                  '${DeviceManager.getProductCode(trackedDevice)}/${DeviceManager.extractSerialNumber(trackedDevice)}',
                  () => {})
              .addAll({'w_status': false});
          saveGlobalData(globalDATA);
          try {
            String topic =
                'devices_rx/${DeviceManager.getProductCode(trackedDevice)}/${DeviceManager.extractSerialNumber(trackedDevice)}';
            String topic2 =
                'devices_tx/${DeviceManager.getProductCode(trackedDevice)}/${DeviceManager.extractSerialNumber(trackedDevice)}';
            String message = jsonEncode({'w_status': false});
            sendMessagemqtt(topic, message);
            sendMessagemqtt(topic2, message);
          } catch (e, s) {
            printLog('Error al enviar valor $e $s');
          }
        }
      }
      flags[trackedDevice] = false;
      await saveMsgFlag(flags);
    }
  }
}
//*-Background functions-*\\

//*-show dialog generico-*\\
void showAlertDialog(BuildContext context, bool dismissible, Widget? title,
    Widget? content, List<Widget>? actions) {
  showGeneralDialog(
    context: context,
    barrierDismissible: dismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withOpacity(0.5),
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (BuildContext context, Animation<double> animation,
        Animation<double> secondaryAnimation) {
      double screenWidth = MediaQuery.of(context).size.width;
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter changeState) {
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: 300.0,
                maxWidth: screenWidth - 20,
              ),
              child: IntrinsicWidth(
                child: Container(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        spreadRadius: 1,
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Card(
                    color: color3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30.0),
                    ),
                    elevation: 24,
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.topCenter,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 70, 20, 20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Center(
                                child: DefaultTextStyle(
                                  style: GoogleFonts.poppins(
                                    color: color0,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  child: title ?? const SizedBox.shrink(),
                                ),
                              ),
                              const SizedBox(height: 20),
                              Center(
                                child: DefaultTextStyle(
                                  style: GoogleFonts.poppins(
                                    color: color0,
                                    fontSize: 16,
                                  ),
                                  child: content ?? const SizedBox.shrink(),
                                ),
                              ),
                              const SizedBox(height: 30),
                              if (actions != null)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: actions.map(
                                    (widget) {
                                      if (widget is TextButton) {
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 5.0),
                                          child: TextButton(
                                            style: TextButton.styleFrom(
                                              foregroundColor: color0,
                                              backgroundColor: color3,
                                            ),
                                            onPressed: widget.onPressed,
                                            child: widget.child!,
                                          ),
                                        );
                                      } else {
                                        return widget;
                                      }
                                    },
                                  ).toList(),
                                ),
                            ],
                          ),
                        ),
                        Positioned(
                          top: -50,
                          child: Material(
                            elevation: 10,
                            shape: const CircleBorder(),
                            shadowColor: Colors.black.withOpacity(0.4),
                            child: CircleAvatar(
                              radius: 50,
                              backgroundColor: color3,
                              child: Image.asset(
                                'assets/dragon.png',
                                width: 60,
                                height: 60,
                              ),
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
        },
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: Curves.easeInOut,
        ),
        child: ScaleTransition(
          scale: CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOut,
          ),
          child: child,
        ),
      );
    },
  );
}
//*-show dialog generico-*\\

//*-Acceso rápido BLE-*\\
Future<void> controlDeviceBLE(String name, bool newState) async {
  printLog("Voy a ${newState ? 'Encender' : 'Apagar'} el equipo $name", "Rojo");
  if (DeviceManager.getProductCode(name) == '020010_IOT') {
    String fun = '${pinQuickAccess[name]!}#${newState ? '1' : '0'}';
    myDevice.ioUuid.write(fun.codeUnits);
    String topic =
        'devices_rx/${DeviceManager.getProductCode(deviceName)}/${DeviceManager.extractSerialNumber(deviceName)}';
    String topic2 =
        'devices_tx/${DeviceManager.getProductCode(deviceName)}/${DeviceManager.extractSerialNumber(deviceName)}';
    String message = jsonEncode({
      'index': int.parse(pinQuickAccess[name]!),
      'w_status': newState,
    });
    sendMessagemqtt(topic, message);
    sendMessagemqtt(topic2, message);

    globalDATA
        .putIfAbsent(
            '${DeviceManager.getProductCode(deviceName)}/${DeviceManager.extractSerialNumber(deviceName)}',
            () => {})
        .addAll({'io${pinQuickAccess[name]!}': message});

    saveGlobalData(globalDATA);
  } else {
    int fun = newState ? 1 : 0;
    String data = '${DeviceManager.getProductCode(name)}[11]($fun)';
    myDevice.toolsUuid.write(data.codeUnits);
    globalDATA[
            '${DeviceManager.getProductCode(name)}/${DeviceManager.extractSerialNumber(name)}']![
        'w_status'] = newState;
    saveGlobalData(globalDATA);
    try {
      String topic =
          'devices_rx/${DeviceManager.getProductCode(name)}/${DeviceManager.extractSerialNumber(name)}';
      String topic2 =
          'devices_tx/${DeviceManager.getProductCode(name)}/${DeviceManager.extractSerialNumber(name)}';
      String message = jsonEncode({'w_status': newState});
      sendMessagemqtt(topic, message);
      sendMessagemqtt(topic2, message);
    } catch (e, s) {
      printLog('Error al enviar valor en cdBLE $e $s');
    }
  }
}
//*-Acceso rápido BLE-*\\

// // -------------------------------------------------------------------------------------------------------------\\ \\

//! CLASES !\\

//*-BLE, configuraciones del equipo-*\\
class MyDevice {
  static final MyDevice _singleton = MyDevice._internal();

  factory MyDevice() {
    return _singleton;
  }

  MyDevice._internal();

  late BluetoothDevice device;
  late BluetoothCharacteristic infoUuid;

  late BluetoothCharacteristic toolsUuid;
  late BluetoothCharacteristic otaUuid;
  late BluetoothCharacteristic varsUuid;
  late BluetoothCharacteristic workUuid;
  late BluetoothCharacteristic lightUuid;
  late BluetoothCharacteristic ioUuid;

  Future<bool> setup(BluetoothDevice connectedDevice) async {
    try {
      device = connectedDevice;

      List<BluetoothService> services =
          await device.discoverServices(timeout: 3);
      // printLog('Los servicios: $services');

      BluetoothService infoService = services.firstWhere(
          (s) => s.uuid == Guid('6a3253b4-48bc-4e97-bacd-325a1d142038'));
      infoUuid = infoService.characteristics.firstWhere((c) =>
          c.uuid ==
          Guid(
              'fc5c01f9-18de-4a75-848b-d99a198da9be')); //ProductType:SerialNumber:SoftVer:HardVer:Owner
      toolsUuid = infoService.characteristics.firstWhere((c) =>
          c.uuid ==
          Guid(
              '89925840-3d11-4676-bf9b-62961456b570')); //WifiStatus:WifiSSID/WifiError:BleStatus(users)

      infoValues = await infoUuid.read();
      String str = utf8.decode(infoValues);
      var partes = str.split(':');
      var fun = partes[0].split('_');
      deviceType = fun[0];
      softwareVersion = partes[2];
      hardwareVersion = partes[3];
      printLog('Device: $deviceType');
      printLog(
          'Product code: ${DeviceManager.getProductCode(device.platformName)}');
      printLog(
          'Serial number: ${DeviceManager.extractSerialNumber(device.platformName)}');
      globalDATA.putIfAbsent(
          '${DeviceManager.getProductCode(device.platformName)}/${DeviceManager.extractSerialNumber(device.platformName)}',
          () => {});
      saveGlobalData(globalDATA);

      switch (deviceType) {
        case '022000':
          BluetoothService espService = services.firstWhere(
              (s) => s.uuid == Guid('6f2fa024-d122-4fa3-a288-8eca1af30502'));

          varsUuid = espService.characteristics.firstWhere((c) =>
              c.uuid ==
              Guid(
                  '52a2f121-a8e3-468c-a5de-45dca9a2a207')); //WorkingTemp:WorkingStatus:EnergyTimer:HeaterOn:NightMode
          break;
        case '027000':
          BluetoothService espService = services.firstWhere(
              (s) => s.uuid == Guid('6f2fa024-d122-4fa3-a288-8eca1af30502'));

          varsUuid = espService.characteristics.firstWhere((c) =>
              c.uuid ==
              Guid(
                  '52a2f121-a8e3-468c-a5de-45dca9a2a207')); //WorkingTemp:WorkingStatus:EnergyTimer:HeaterOn:NightMode
          break;
        case '041220':
          BluetoothService espService = services.firstWhere(
              (s) => s.uuid == Guid('6f2fa024-d122-4fa3-a288-8eca1af30502'));

          varsUuid = espService.characteristics.firstWhere((c) =>
              c.uuid ==
              Guid(
                  '52a2f121-a8e3-468c-a5de-45dca9a2a207')); //WorkingTemp:WorkingStatus:EnergyTimer:HeaterOn:NightMode
          break;
        case '015773':
          BluetoothService service = services.firstWhere(
              (s) => s.uuid == Guid('dd249079-0ce8-4d11-8aa9-53de4040aec6'));

          workUuid = service.characteristics.firstWhere((c) =>
              c.uuid ==
              Guid(
                  '6869fe94-c4a2-422a-ac41-b2a7a82803e9')); //Array de datos (ppm,etc)
          lightUuid = service.characteristics.firstWhere((c) =>
              c.uuid == Guid('12d3c6a1-f86e-4d5b-89b5-22dc3f5c831f')); //No leo

          break;
        case '020010':
          BluetoothService service = services.firstWhere(
              (s) => s.uuid == Guid('6f2fa024-d122-4fa3-a288-8eca1af30502'));
          ioUuid = service.characteristics.firstWhere(
              (c) => c.uuid == Guid('03b1c5d9-534a-4980-aed3-f59615205216'));
          break;
        case '027313':
          BluetoothService espService = services.firstWhere(
              (s) => s.uuid == Guid('6f2fa024-d122-4fa3-a288-8eca1af30502'));

          varsUuid = espService.characteristics.firstWhere((c) =>
              c.uuid ==
              Guid(
                  '52a2f121-a8e3-468c-a5de-45dca9a2a207')); //DistanceControl:W_Status:EnergyTimer:AwsINIT
          break;
        case '024011':
          BluetoothService espService = services.firstWhere(
              (s) => s.uuid == Guid('6f2fa024-d122-4fa3-a288-8eca1af30502'));

          varsUuid = espService.characteristics.firstWhere((c) =>
              c.uuid ==
              Guid(
                  '52a2f121-a8e3-468c-a5de-45dca9a2a207')); //DstCtrl:LargoRoller:InversionGiro:VelocidadMotor:PosicionActual:PosicionTrabajo:RollerMoving:AWSinit
          otaUuid = espService.characteristics.firstWhere((c) =>
              c.uuid ==
              Guid(
                  'ae995fcd-2c7a-4675-84f8-332caf784e9f')); //Ota comandos (Solo notify)
          break;
        case '030710':
          break;
      }

      return Future.value(true);
    } catch (e, stackTrace) {
      printLog('Lcdtmbe $e $stackTrace');

      return Future.value(false);
    }
  }
}
//*-BLE, configuraciones del equipo-*\\

//*-Metodos, interacción con código Nativo-*\\
class NativeService {
  static const platform = MethodChannel('com.caldensmart.sime/native');

  static Future<bool> isLocationServiceEnabled() async {
    try {
      final bool isEnabled =
          await platform.invokeMethod("isLocationServiceEnabled");
      return isEnabled;
    } on PlatformException catch (e) {
      printLog('Error verificando ubicación: $e');
      return false;
    }
  }

  static Future<void> isBluetoothServiceEnabled() async {
    try {
      final bool isBluetoothOn = await platform.invokeMethod('isBluetoothOn');

      if (!isBluetoothOn && !bleFlag) {
        bleFlag = true;
        final bool turnedOn = await platform.invokeMethod('turnOnBluetooth');

        if (turnedOn) {
          bleFlag = false;
        } else {
          printLog("El usuario rechazó encender Bluetooth");
        }
      }
    } on PlatformException catch (e) {
      android
          ? printLog("Error al verificar o encender Bluetooth: ${e.message}")
          : null;

      bleFlag = false;
    }
  }

  static Future<void> openLocationOptions() async {
    try {
      await platform.invokeMethod("openLocationSettings");
    } on PlatformException catch (e) {
      printLog('Error abriendo la configuración de ubicación: $e');
    }
  }

  // static Future<void> enableWakelock() async {
  //   try {
  //     await platform.invokeMethod("enableWakeLock");
  //   } on PlatformException catch (e) {
  //     printLog('Error al habilitar el wakelock: $e');
  //   }
  // }

  // static Future<void> disableWakelock() async {
  //   try {
  //     await platform.invokeMethod("disableWakelock");
  //   } on PlatformException catch (e) {
  //     printLog('Error al deshabilitar el wakelock: $e');
  //   }
  // }
}
//*-Metodos, interacción con código Nativo-*\\

//*-Provider, actualización de data en un widget-*\\
class GlobalDataNotifier extends ChangeNotifier {
  final Map<String, Map<String, dynamic>> _data = {};

  // Obtener datos por topic específico
  Map<String, dynamic> getData(String topic) {
    return _data[topic] ?? {};
  }

  // Actualizar datos para un topic específico y notificar a los oyentes
  void updateData(String topic, Map<String, dynamic> newData) {
    if (_data[topic] != newData) {
      _data[topic] = newData;
      notifyListeners(); // Esto notifica a todos los oyentes que algo cambió
    }
  }
}
//*-Provider, actualización de data en un widget-*\\

//*-QR Scan, lee datos de qr wifi-*\\
class QRScanPage extends StatefulWidget {
  const QRScanPage({super.key});
  @override
  QRScanPageState createState() => QRScanPageState();
}

class QRScanPageState extends State<QRScanPage>
    with SingleTickerProviderStateMixin {
  Barcode? result;
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  MobileScannerController controller = MobileScannerController();
  AnimationController? animationController;
  bool flashOn = false;
  late Animation<double> animation;

  @override
  void initState() {
    super.initState();

    animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    animation = Tween<double>(begin: 10, end: 350).animate(animationController!)
      ..addListener(() {
        setState(() {});
      });

    animationController!.repeat(reverse: true);
  }

  @override
  void dispose() {
    controller.dispose();
    animationController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        MobileScanner(
          controller: controller,
          onDetect: (
            barcode,
          ) {
            setState(() {
              result = barcode.barcodes.first;
            });
            if (result != null) {
              Navigator.pop(context, result!.rawValue);
            }
          },
        ),
        // Arriba
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 250,
          child: Container(
              color: Colors.black54,
              child: const Center(
                child: Text(
                  'Escanea el QR',
                  style: TextStyle(
                    color: Color(0xFFB2B5AE),
                  ),
                ),
              )),
        ),
        // Abajo
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 250,
          child: Container(
            color: Colors.black54,
          ),
        ),
        // Izquierda
        Positioned(
          top: 250,
          bottom: 250,
          left: 0,
          width: 50,
          child: Container(
            color: Colors.black54,
          ),
        ),
        // Derecha
        Positioned(
          top: 250,
          bottom: 250,
          right: 0,
          width: 50,
          child: Container(
            color: Colors.black54,
          ),
        ),
        // Área transparente con bordes redondeados
        Positioned(
          top: 250,
          left: 50,
          right: 50,
          bottom: 250,
          child: Stack(
            children: [
              Positioned(
                top: animation.value,
                left: 0,
                right: 0,
                child: Container(
                  height: 4,
                  color: const Color(0xFF1E242B),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 3,
                  color: const Color(0xFFB2B5AE),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 3,
                  color: const Color(0xFFB2B5AE),
                ),
              ),
              Positioned(
                top: 0,
                bottom: 0,
                left: 0,
                child: Container(
                  width: 3,
                  color: const Color(0xFFB2B5AE),
                ),
              ),
              Positioned(
                top: 0,
                bottom: 0,
                right: 0,
                child: Container(
                  width: 3,
                  color: const Color(0xFFB2B5AE),
                ),
              ),
            ],
          ),
        ),
        // Botón de Flash
        Positioned(
          bottom: 20,
          right: 20,
          child: IconButton(
            icon: Icon(
                controller.torchEnabled ? Icons.flash_on : Icons.flash_off),
            onPressed: () => controller.toggleTorch(),
          ),
        ),
      ]),
    );
  }
}
//*-QR Scan, lee datos de qr wifi-*\\

//*-CurvedNativationAppBar*-\\
class CurvedNavigationBar extends StatefulWidget {
  final List<Widget> items;
  final int index;
  final Color color;
  final Color? buttonBackgroundColor;
  final Color backgroundColor;
  final ValueChanged<int>? onTap;
  final LetIndexPage letIndexChange;
  final Curve animationCurve;
  final Duration animationDuration;
  final double height;
  final double? maxWidth;

  CurvedNavigationBar({
    super.key,
    required this.items,
    this.index = 0,
    this.color = Colors.white,
    this.buttonBackgroundColor,
    this.backgroundColor = Colors.blueAccent,
    this.onTap,
    LetIndexPage? letIndexChange,
    this.animationCurve = Curves.easeOut,
    this.animationDuration = const Duration(milliseconds: 600),
    this.height = 75.0,
    this.maxWidth,
  })  : letIndexChange = letIndexChange ?? ((_) => true),
        assert(items.isNotEmpty),
        assert(0 <= index && index < items.length),
        assert(0 <= height && height <= 75.0),
        assert(maxWidth == null || 0 <= maxWidth);

  @override
  CurvedNavigationBarState createState() => CurvedNavigationBarState();
}

class CurvedNavigationBarState extends State<CurvedNavigationBar>
    with SingleTickerProviderStateMixin {
  late double _startingPos;
  late int _endingIndex;
  late double _pos;
  double _buttonHide = 0;
  late Widget _icon;
  late AnimationController _animationController;
  late int _length;

  @override
  void initState() {
    super.initState();
    _icon = widget.items[widget.index];
    _length = widget.items.length;
    _pos = widget.index / _length;
    _startingPos = widget.index / _length;
    _endingIndex = widget.index;
    _animationController = AnimationController(vsync: this, value: _pos);
    _animationController.addListener(() {
      setState(() {
        _pos = _animationController.value;
        final endingPos = _endingIndex / widget.items.length;
        final middle = (endingPos + _startingPos) / 2;
        if ((endingPos - _pos).abs() < (_startingPos - _pos).abs()) {
          _icon = widget.items[_endingIndex];
        }
        _buttonHide =
            (1 - ((middle - _pos) / (_startingPos - middle)).abs()).abs();
      });
    });
  }

  @override
  void didUpdateWidget(CurvedNavigationBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      final newPosition = widget.index / _length;
      _startingPos = _pos;
      _endingIndex = widget.index;
      _animationController.animateTo(newPosition,
          duration: widget.animationDuration, curve: widget.animationCurve);
    }
    if (!_animationController.isAnimating) {
      _icon = widget.items[_endingIndex];
    }
  }

  @override
  void dispose() {
    super.dispose();
    _animationController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textDirection = Directionality.of(context);
    return SizedBox(
      height: widget.height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = min(
              constraints.maxWidth, widget.maxWidth ?? constraints.maxWidth);
          return Align(
            alignment: textDirection == TextDirection.ltr
                ? Alignment.bottomLeft
                : Alignment.bottomRight,
            child: Container(
              color: widget.backgroundColor,
              width: maxWidth,
              child: ClipRect(
                clipper: NavCustomClipper(
                  deviceHeight: MediaQuery.sizeOf(context).height,
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.bottomCenter,
                  children: <Widget>[
                    Positioned(
                      bottom: -40 - (75.0 - widget.height),
                      left: textDirection == TextDirection.rtl
                          ? null
                          : _pos * maxWidth,
                      right: textDirection == TextDirection.rtl
                          ? _pos * maxWidth
                          : null,
                      width: maxWidth / _length,
                      child: Center(
                        child: Transform.translate(
                          offset: Offset(
                            0,
                            -(1 - _buttonHide) * 80,
                          ),
                          child: Material(
                            color: widget.buttonBackgroundColor ?? widget.color,
                            type: MaterialType.circle,
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: _icon,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0 - (75.0 - widget.height),
                      child: CustomPaint(
                        painter: NavCustomPainter(
                            _pos, _length, widget.color, textDirection),
                        child: Container(
                          height: 75.0,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0 - (75.0 - widget.height),
                      child: SizedBox(
                          height: 100.0,
                          child: Row(
                              children: widget.items.map((item) {
                            return NavButton(
                              onTap: _buttonTap,
                              position: _pos,
                              length: _length,
                              index: widget.items.indexOf(item),
                              child: Center(child: item),
                            );
                          }).toList())),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void setPage(int index) {
    _buttonTap(index);
  }

  void _buttonTap(int index) {
    if (!widget.letIndexChange(index) || _animationController.isAnimating) {
      return;
    }
    if (widget.onTap != null) {
      widget.onTap!(index);
    }
    final newPosition = index / _length;
    setState(() {
      _startingPos = _pos;
      _endingIndex = index;
      _animationController.animateTo(newPosition,
          duration: widget.animationDuration, curve: widget.animationCurve);
    });
  }
}

class NavCustomPainter extends CustomPainter {
  late double loc;
  late double s;
  Color color;
  TextDirection textDirection;

  NavCustomPainter(
      double startingLoc, int itemsLength, this.color, this.textDirection) {
    final span = 1.0 / itemsLength;
    s = 0.2;
    double l = startingLoc + (span - s) / 2;
    loc = textDirection == TextDirection.rtl ? 0.8 - l : l;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo((loc - 0.1) * size.width, 0)
      ..cubicTo(
        (loc + s * 0.20) * size.width,
        size.height * 0.05,
        loc * size.width,
        size.height * 0.60,
        (loc + s * 0.50) * size.width,
        size.height * 0.60,
      )
      ..cubicTo(
        (loc + s) * size.width,
        size.height * 0.60,
        (loc + s - s * 0.20) * size.width,
        size.height * 0.05,
        (loc + s + 0.1) * size.width,
        0,
      )
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return this != oldDelegate;
  }
}

class NavButton extends StatelessWidget {
  final double position;
  final int length;
  final int index;
  final ValueChanged<int> onTap;
  final Widget child;

  const NavButton({
    super.key,
    required this.onTap,
    required this.position,
    required this.length,
    required this.index,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final desiredPosition = 1.0 / length * index;
    final difference = (position - desiredPosition).abs();
    final verticalAlignment = 1 - length * difference;
    final opacity = length * difference;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          onTap(index);
        },
        child: SizedBox(
          height: 75.0,
          child: Transform.translate(
            offset: Offset(
                0, difference < 1.0 / length ? verticalAlignment * 40 : 0),
            child: Opacity(
                opacity: difference < 1.0 / length * 0.99 ? opacity : 1.0,
                child: child),
          ),
        ),
      ),
    );
  }
}

class NavCustomClipper extends CustomClipper<Rect> {
  final double deviceHeight;

  NavCustomClipper({required this.deviceHeight});

  @override
  Rect getClip(Size size) {
    //Clip only the bottom of the widget
    return Rect.fromLTWH(
      0,
      -deviceHeight + size.height,
      size.width,
      deviceHeight,
    );
  }

  @override
  bool shouldReclip(NavCustomClipper oldClipper) {
    return oldClipper.deviceHeight != deviceHeight;
  }
}
//*-CurvedNativationAppBar*-\\

//*-AnimSearchBar*-\\
class AnimSearchBar extends StatefulWidget {
  final double width;
  final TextEditingController textController;
  final Icon? suffixIcon;
  final Icon? prefixIcon;
  final String helpText;
  final int animationDurationInMilli;
  final dynamic onSuffixTap;
  final bool rtl;
  final bool autoFocus;
  final TextStyle? style;
  final bool closeSearchOnSuffixTap;
  final Color? color;
  final Color? textFieldColor;
  final Color? searchIconColor;
  final Color? textFieldIconColor;
  final List<TextInputFormatter>? inputFormatters;
  final bool boxShadow;
  final Function(String) onSubmitted;

  const AnimSearchBar({
    super.key,

    /// The width cannot be null
    required this.width,

    /// The textController cannot be null
    required this.textController,
    this.suffixIcon,
    this.prefixIcon,
    this.helpText = "Search...",

    /// choose your custom color
    this.color = Colors.white,

    /// choose your custom color for the search when it is expanded
    this.textFieldColor = Colors.white,

    /// choose your custom color for the search when it is expanded
    this.searchIconColor = Colors.black,

    /// choose your custom color for the search when it is expanded
    this.textFieldIconColor = Colors.black,

    /// The onSuffixTap cannot be null
    required this.onSuffixTap,
    this.animationDurationInMilli = 375,

    /// The onSubmitted cannot be null
    required this.onSubmitted,

    /// make the search bar to open from right to left
    this.rtl = false,

    /// make the keyboard to show automatically when the searchbar is expanded
    this.autoFocus = false,

    /// TextStyle of the contents inside the searchbar
    this.style,

    /// close the search on suffix tap
    this.closeSearchOnSuffixTap = false,

    /// enable/disable the box shadow decoration
    this.boxShadow = true,

    /// can add list of inputformatters to control the input
    this.inputFormatters,
    required Null Function() onTap,
  });

  @override
  AnimSearchBarState createState() => AnimSearchBarState();
}

class AnimSearchBarState extends State<AnimSearchBar>
    with SingleTickerProviderStateMixin {
  ///initializing the AnimationController
  late AnimationController _con;
  FocusNode focusNode = FocusNode();

  @override
  void initState() {
    super.initState();

    ///Initializing the animationController which is responsible for the expanding and shrinking of the search bar
    _con = AnimationController(
      vsync: this,

      /// animationDurationInMilli is optional, the default value is 375
      duration: Duration(milliseconds: widget.animationDurationInMilli),
    );
  }

  @override
  void dispose() {
    super.dispose();
    _con.dispose();
  }

  unfocusKeyboard() {
    final FocusScopeNode currentScope = FocusScope.of(context);
    if (!currentScope.hasPrimaryFocus && currentScope.hasFocus) {
      FocusManager.instance.primaryFocus?.unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100.0,

      ///if the rtl is true, search bar will be from right to left
      alignment:
          widget.rtl ? Alignment.centerRight : const Alignment(-1.0, 0.0),

      ///Using Animated container to expand and shrink the widget
      child: AnimatedContainer(
        duration: Duration(milliseconds: widget.animationDurationInMilli),
        height: 48.0,
        width: (toggle == 0) ? 48.0 : widget.width,
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          /// can add custom  color or the color will be white
          color: toggle == 1 ? widget.textFieldColor : widget.color,
          borderRadius: BorderRadius.circular(30.0),

          /// show boxShadow unless false was passed
          boxShadow: !widget.boxShadow
              ? null
              : [
                  const BoxShadow(
                    color: Colors.black26,
                    spreadRadius: -10.0,
                    blurRadius: 10.0,
                    offset: Offset(0.0, 10.0),
                  ),
                ],
        ),
        child: Stack(
          children: [
            ///Using Animated Positioned widget to expand and shrink the widget
            AnimatedPositioned(
              duration: Duration(milliseconds: widget.animationDurationInMilli),
              top: 6.0,
              right: 7.0,
              curve: Curves.easeOut,
              child: AnimatedOpacity(
                opacity: (toggle == 0) ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    /// can add custom color or the color will be white
                    color: widget.color,
                    borderRadius: BorderRadius.circular(30.0),
                  ),
                  child: AnimatedBuilder(
                    builder: (context, widget) {
                      ///Using Transform.rotate to rotate the suffix icon when it gets expanded
                      return Transform.rotate(
                        angle: _con.value * 2.0 * pi,
                        child: widget,
                      );
                    },
                    animation: _con,
                    child: GestureDetector(
                      onTap: () {
                        try {
                          ///trying to execute the onSuffixTap function
                          widget.onSuffixTap();

                          // * if field empty then the user trying to close bar
                          if (textFieldValue == '') {
                            unfocusKeyboard();
                            setState(() {
                              toggle = 0;
                            });

                            ///reverse == close
                            _con.reverse();
                          }

                          // * why not clear textfield here?
                          widget.textController.clear();
                          textFieldValue = '';

                          ///closeSearchOnSuffixTap will execute if it's true
                          if (widget.closeSearchOnSuffixTap) {
                            unfocusKeyboard();
                            setState(() {
                              toggle = 0;
                            });
                          }
                        } catch (e) {
                          ///print the error if the try block fails
                          printLog(e);
                        }
                      },

                      ///suffixIcon is of type Icon
                      child: widget.suffixIcon ??
                          Icon(
                            Icons.close,
                            size: 20.0,
                            color: widget.textFieldIconColor,
                          ),
                    ),
                  ),
                ),
              ),
            ),
            AnimatedPositioned(
              duration: Duration(milliseconds: widget.animationDurationInMilli),
              left: (toggle == 0) ? 20.0 : 40.0,
              curve: Curves.easeOut,
              top: 11.0,

              ///Using Animated opacity to change the opacity of th textField while expanding
              child: AnimatedOpacity(
                opacity: (toggle == 0) ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  padding: const EdgeInsets.only(left: 10),
                  alignment: Alignment.topCenter,
                  width: widget.width / 1.7,
                  child: TextField(
                    ///Text Controller. you can manipulate the text inside this textField by calling this controller.
                    controller: widget.textController,
                    inputFormatters: widget.inputFormatters,
                    focusNode: focusNode,
                    cursorRadius: const Radius.circular(10.0),
                    cursorWidth: 2.0,
                    onChanged: (value) {
                      textFieldValue = value;
                    },
                    onSubmitted: (value) => {
                      widget.onSubmitted(value),
                      unfocusKeyboard(),
                      setState(() {
                        toggle = 0;
                      }),
                      widget.textController.clear(),
                    },
                    onEditingComplete: () {
                      /// on editing complete the keyboard will be closed and the search bar will be closed
                      unfocusKeyboard();
                      setState(() {
                        toggle = 0;
                      });
                    },

                    ///style is of type TextStyle, the default is just a color black
                    style: widget.style ?? const TextStyle(color: Colors.black),
                    cursorColor: Colors.black,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.only(bottom: 5),
                      isDense: true,
                      floatingLabelBehavior: FloatingLabelBehavior.never,
                      labelText: widget.helpText,
                      labelStyle: const TextStyle(
                        color: Color(0xff5B5B5B),
                        fontSize: 17.0,
                        fontWeight: FontWeight.w500,
                      ),
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20.0),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            ///Using material widget here to get the ripple effect on the prefix icon
            Material(
              /// can add custom color or the color will be white
              /// toggle button color based on toggle state
              color: toggle == 0 ? widget.color : widget.textFieldColor,
              borderRadius: BorderRadius.circular(30.0),
              child: IconButton(
                splashRadius: 19.0,

                ///if toggle is 1, which means it's open. so show the back icon, which will close it.
                ///if the toggle is 0, which means it's closed, so tapping on it will expand the widget.
                ///prefixIcon is of type Icon
                icon: widget.prefixIcon != null
                    ? toggle == 1
                        ? Icon(
                            Icons.arrow_back_ios,
                            color: widget.textFieldIconColor,
                          )
                        : widget.prefixIcon!
                    : Icon(
                        toggle == 1 ? Icons.arrow_back_ios : Icons.search,
                        // search icon color when closed
                        color: toggle == 0
                            ? widget.searchIconColor
                            : widget.textFieldIconColor,
                        size: 20.0,
                      ),
                onPressed: () {
                  setState(
                    () {
                      ///if the search bar is closed
                      if (toggle == 0) {
                        toggle = 1;
                        setState(() {
                          ///if the autoFocus is true, the keyboard will pop open, automatically
                          if (widget.autoFocus) {
                            FocusScope.of(context).requestFocus(focusNode);
                          }
                        });

                        ///forward == expand
                        _con.forward();
                      } else {
                        ///if the search bar is expanded
                        toggle = 0;

                        ///if the autoFocus is true, the keyboard will close, automatically
                        setState(() {
                          if (widget.autoFocus) unfocusKeyboard();
                        });

                        ///reverse == close
                        _con.reverse();
                      }
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
//*-AnimSearchBar*-\\

//*-pantalla para usuario no autorizo a entrar al equipo-*\\
class AccessDeniedScreen extends StatelessWidget {
  const AccessDeniedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, A) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            return AlertDialog(
              backgroundColor: const Color(0xFF252223),
              content: Row(
                children: [
                  Image.asset('assets/dragon.gif', width: 100, height: 100),
                  Container(
                    margin: const EdgeInsets.only(left: 15),
                    child: const Text(
                      "Desconectando...",
                      style: TextStyle(color: Color(0xFFFFFFFF)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
        Future.delayed(const Duration(seconds: 2), () async {
          await myDevice.device.disconnect();
          if (context.mounted) {
            Navigator.pop(context);
            Navigator.pushReplacementNamed(context, '/menu');
          }
        });
        return;
      },
      child: Scaffold(
        backgroundColor: color1,
        body: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: color3),
                  onPressed: () {
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) {
                        return AlertDialog(
                          backgroundColor: const Color(0xFF252223),
                          content: Row(
                            children: [
                              Image.asset('assets/dragon.gif',
                                  width: 100, height: 100),
                              Container(
                                margin: const EdgeInsets.only(left: 15),
                                child: const Text(
                                  "Desconectando...",
                                  style: TextStyle(color: Color(0xFFFFFFFF)),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                    Future.delayed(const Duration(seconds: 2), () async {
                      await myDevice.device.disconnect();
                      if (context.mounted) {
                        Navigator.pop(context);
                        Navigator.pushReplacementNamed(context, '/menu');
                      }
                    });
                    return;
                  },
                ),
              ),
              const Spacer(),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.dangerous,
                    size: 80,
                    color: color3,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No eres dueño de este equipo',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      color: color3,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: color3,
                    ),
                    children: [
                      const TextSpan(text: 'Si crees que es un error,\n'),
                      TextSpan(
                        text: 'contáctanos por correo',
                        style: const TextStyle(
                          decoration: TextDecoration.underline,
                          color: color3,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () {
                            String adminActual = globalDATA[
                                        '${DeviceManager.getProductCode(deviceName)}/${DeviceManager.extractSerialNumber(deviceName)}']
                                    ?['owner'] ??
                                'Desconocido';
                            String message =
                                'Hola, te hablo en relación a mi equipo $deviceName.\nEste mismo me dice que no soy dueño.\nDatos del equipo:\nCódigo de producto: ${DeviceManager.getProductCode(deviceName)}\nNúmero de serie: ${DeviceManager.extractSerialNumber(deviceName)}\nDueño actual: $adminActual\n';

                            launchEmail(
                              'service@caldensmart.com',
                              'Consulta sobre línea Smart',
                              message,
                            );
                          },
                      ),
                      const TextSpan(text: ' o '),
                      TextSpan(
                        text: 'WhatsApp',
                        style: const TextStyle(
                          decoration: TextDecoration.underline,
                          color: color3,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () {
                            String phoneNumber = '5491162232619';

                            String adminActual = globalDATA[
                                        '${DeviceManager.getProductCode(deviceName)}/${DeviceManager.extractSerialNumber(deviceName)}']
                                    ?['owner'] ??
                                'Desconocido';

                            String message =
                                'Hola, te hablo en relación a mi equipo $deviceName.\nEste mismo me dice que no soy dueño.\n*Datos del equipo:*\nCódigo de producto: ${DeviceManager.getProductCode(deviceName)}\nNúmero de serie: ${DeviceManager.extractSerialNumber(deviceName)}\nDueño actual: $adminActual\n';

                            sendWhatsAppMessage(phoneNumber, message);
                          },
                      ),
                    ],
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
//*-pantalla para usuario no autorizo a entrar al equipo-*\\

//*-si el equipo ya tiene un usuario conectado -*\\
class DeviceInUseScreen extends StatelessWidget {
  const DeviceInUseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, A) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            return AlertDialog(
              backgroundColor: const Color(0xFF252223),
              content: Row(
                children: [
                  Image.asset('assets/dragon.gif', width: 100, height: 100),
                  Container(
                    margin: const EdgeInsets.only(left: 15),
                    child: const Text(
                      "Desconectando...",
                      style: TextStyle(color: Color(0xFFFFFFFF)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
        Future.delayed(const Duration(seconds: 2), () async {
          await myDevice.device.disconnect();
          if (context.mounted) {
            Navigator.pop(context);
            Navigator.pushReplacementNamed(context, '/menu');
          }
        });
        return;
      },
      child: Scaffold(
        backgroundColor: color1,
        body: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: color3),
                  onPressed: () {
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) {
                        return AlertDialog(
                          backgroundColor: const Color(0xFF252223),
                          content: Row(
                            children: [
                              Image.asset('assets/dragon.gif',
                                  width: 100, height: 100),
                              Container(
                                margin: const EdgeInsets.only(left: 15),
                                child: const Text(
                                  "Desconectando...",
                                  style: TextStyle(color: Color(0xFFFFFFFF)),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                    Future.delayed(const Duration(seconds: 2), () async {
                      await myDevice.device.disconnect();
                      if (context.mounted) {
                        Navigator.pop(context);
                        Navigator.pushReplacementNamed(context, '/menu');
                      }
                    });
                    return;
                  },
                ),
              ),
              const Spacer(),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.dangerous,
                    size: 80,
                    color: color3,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Actualmente hay un usuario\nusando el equipo...',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      color: color3,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                  Text(
                    'Espere a que\nse desconecte\npara poder usarlo',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      color: color3,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                  Image.asset(
                    'assets/dragon.gif',
                    width: 150,
                    height: 150,
                  ),
                ],
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
//*-si el equipo ya tiene un usuario conectado -*\\

//*- imagenes de los equipos -*\\
class ImageManager {
  /// Función para abrir el menú de opciones de imagen
  /// [onImageChanged] es un callback que se ejecuta después de cambiar la imagen
  static void openImageOptions(
      BuildContext context, String deviceName, VoidCallback onImageChanged) {
    showModalBottomSheet(
      context: context,
      backgroundColor: color3,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (BuildContext bc) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library, color: color0),
                title: const Text(
                  'Elegir de la galería',
                  style: TextStyle(color: color0),
                ),
                onTap: () async {
                  Navigator.of(context).pop();
                  await pickFromGallery(deviceName);
                  onImageChanged();
                },
              ),
              const Divider(color: color0),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: color0),
                title: const Text(
                  'Tomar una foto',
                  style: TextStyle(color: color0),
                ),
                onTap: () async {
                  Navigator.of(context).pop();
                  await takePhoto(deviceName);
                  onImageChanged();
                },
              ),
              const Divider(color: color0),
              ListTile(
                leading: const Icon(Icons.restore, color: color0),
                title: const Text(
                  'Restablecer imagen',
                  style: TextStyle(color: color0),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  removeDeviceImage(deviceName);
                  onImageChanged();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// Función para elegir una imagen de la galería
  static Future<void> pickFromGallery(String deviceName) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      final String savedPath = await _saveImageLocally(image);
      deviceImages[deviceName] = savedPath;
      await saveDeviceImage(deviceName, deviceImages[deviceName]!);
    }
  }

  /// Función para tomar una foto
  static Future<void> takePhoto(String deviceName) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera);

    if (image != null) {
      final String savedPath = await _saveImageLocally(image);
      deviceImages[deviceName] = savedPath;
      await saveDeviceImage(deviceName, deviceImages[deviceName]!);
    }
  }

  /// Función privada para guardar la imagen localmente
  static Future<String> _saveImageLocally(XFile image) async {
    final Directory appDir = await getApplicationDocumentsDirectory();
    final String path = appDir.path;
    final String fileName =
        '${DateTime.now().millisecondsSinceEpoch}_${image.name}';
    final File localImage = await File(image.path).copy('$path/$fileName');
    return localImage.path;
  }

  /// Función para obtener la ruta de la imagen (personalizada o predeterminada)
  static String getImagePath(String deviceName) {
    return deviceImages[deviceName] ?? rutaDeImagen(deviceName);
  }

  /// Ruta de imágenes predeterminadas
  static String rutaDeImagen(String device) {
    if (device.contains('Electrico')) {
      return 'assets/devices/022000.jpg';
    } else if (device.contains('Gas')) {
      return 'assets/devices/027000.webp';
    } else if (device.contains('Detector')) {
      return 'assets/devices/015773.jpeg';
    } else if (device.contains('Radiador')) {
      return 'assets/devices/041220.jpg';
    } else if (device.contains('Domotica')) {
      return 'assets/devices/020010.jpg';
    } else {
      return 'assets/Logo.png';
    }
  }
}
//*- imagenes de los equipos -*\\

//*- icono en el boton de la slide -*\\
class IconThumbSlider extends SliderComponentShape {
  final IconData iconData;
  final double thumbRadius;

  const IconThumbSlider({required this.iconData, required this.thumbRadius});

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    return Size.fromRadius(thumbRadius);
  }

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final Canvas canvas = context.canvas;

    // Draw the thumb as a circle
    final paint = Paint()
      ..color = sliderTheme.thumbColor!
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, thumbRadius, paint);

    // Draw the icon on the thumb
    TextSpan span = TextSpan(
      style: TextStyle(
        fontSize: thumbRadius,
        fontFamily: iconData.fontFamily,
        color: sliderTheme.valueIndicatorColor,
      ),
      text: String.fromCharCode(iconData.codePoint),
    );
    TextPainter tp = TextPainter(
        text: span,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr);
    tp.layout();
    Offset iconOffset = Offset(
      center.dx - (tp.width / 2),
      center.dy - (tp.height / 2),
    );
    tp.paint(canvas, iconOffset);
  }
}
//*- icono en el boton de la slide -*\\

//*- Funciones relacionadas a los equipos*-\\
class DeviceManager {
  final List<String> productos = [
    '015773_IOT',
    '020010_IOT',
    '022000_IOT',
    '024011_IOT',
    '027000_IOT',
    '027313_IOT',
  ];

  ///Extrae el número de serie desde el deviceName
  static String extractSerialNumber(String productName) {
    RegExp regExp = RegExp(r'(\d{8})');

    Match? match = regExp.firstMatch(productName);

    return match?.group(0) ?? '';
  }

  ///Conseguir el código de producto en base al deviceName
  static String getProductCode(String device) {
    switch (true) {
      case true when device.contains('Electrico'):
        return '022000_IOT';
      case true when device.contains('Gas'):
        return '027000_IOT';
      case true when device.contains('Detector'):
        return '015773_IOT';
      case true when device.contains('Domotica'):
        return '020010_IOT';
      case true when device.contains('Rele'):
        return '027313_IOT';
      case true when device.contains('Roll'):
        return '024011_IOT';
      default:
        return '';
    }
  }

  ///Recupera el deviceName en base al productCode y al SerialNumber
  static String recoverDeviceName(String pc, String sn) {
    String code = '';
    switch (pc) {
      case '015773_IOT':
        code = 'Detector';
        break;
      case '022000_IOT':
        code = 'Electrico';
        break;
      case '027000_IOT':
        code = 'Gas';
        break;
      case '020010_IOT':
        code = 'Domotica';
        break;
      case '027313_IOT':
        code = 'Rele';
        break;
      case '024011_IOT':
        code = 'Roll';
        break;
    }

    return '$code$sn';
  }

  static String getComercialName(String name) {
    switch (true) {
      case true when name.contains('Electrico'):
        return 'Calefactor Eléctrico';
      case true when name.contains('Gas'):
        return 'Calefactor a Gas';
      case true when name.contains('Detector'):
        return 'Detector de Gas & CO';
      case true when name.contains('Domotica'):
        return 'Domótica 4 IO';
      case true when name.contains('Rele'):
        return 'Tecla Smart';
      case true when name.contains('Roll'):
        return 'Cortina Roll';
      default:
        return '';
    }
  }
}
//*- Funciones relacionadas a los equipos*-\\