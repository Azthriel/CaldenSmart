import 'dart:convert';
import '../master.dart';
import 'package:shared_preferences/shared_preferences.dart';

// MASTERLOAD \\
//*-Cargo toda la data-*\\
Future<void> loadValues() async {
  globalDATA = await loadGlobalData();
  notificationMap = await loadNotificationMap();
  deviceImages = await loadDeviceImages();
  soundOfNotification = await loadSounds();
  configNotiDsc = await loadconfigNotiDsc();
  quickAccess = await loadquickAccess();
  pinQuickAccess = await loadpinQuickAccess();
  lastPage = await loadLastPage();
  tutorial = await loadTutorial();
}
//*-Cargo toda la data-*\\
// MASTERLOAD \\

//*-GlobalDATA-*\\
Future<void> saveGlobalData(
    Map<String, Map<String, dynamic>> globalData) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  Map<String, String> stringMap = globalData.map((key, value) {
    return MapEntry(key, json.encode(value));
  });
  await prefs.setString('CSglobalData', json.encode(stringMap));
}

Future<Map<String, Map<String, dynamic>>> loadGlobalData() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  String? jsonString = prefs.getString('CSglobalData');
  if (jsonString == null) {
    return {};
  }
  Map<String, dynamic> stringMap =
      json.decode(jsonString) as Map<String, dynamic>;
  Map<String, Map<String, dynamic>> globalData = stringMap.map((key, value) {
    return MapEntry(key, json.decode(value) as Map<String, dynamic>);
  });
  return globalData;
}
//*-GlobalDATA-*\\

//*-Dómotica con notis encendida-*\\
Future<void> saveNotificationMap(Map<String, List<bool>> map) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  String jsonString = json.encode(map);
  await prefs.setString('CSNotificationMap', jsonString);
}

Future<Map<String, List<bool>>> loadNotificationMap() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  String? jsonString = prefs.getString('CSNotificationMap');
  Map<String, List<bool>> map = jsonString != null
      ? Map.from(json.decode(jsonString)).map((key, value) {
          List<bool> boolList = List<bool>.from(value);
          return MapEntry(key, boolList);
        })
      : {};

  return map;
}
//*-Dómotica con notis encendida-*\\

//*-Dispositivos que tienen el acceso rápido habilitado-*\\
Future<void> savequickAccess(List<String> lista) async {
  final prefs = await SharedPreferences.getInstance();
  String devicesList = json.encode(lista);
  await prefs.setString('CSquickAccess', devicesList);
}

Future<List<String>> loadquickAccess() async {
  final prefs = await SharedPreferences.getInstance();
  String? devicesList = prefs.getString('CSquickAccess');
  if (devicesList != null) {
    List<dynamic> decodedList = json.decode(devicesList);
    return decodedList.cast<String>();
  }
  return [];
}

Future<void> savepinQuickAccess(Map<String, String> data) async {
  final prefs = await SharedPreferences.getInstance();
  String taskMapString = json.encode(data);
  await prefs.setString('CSpinQuickAccess', taskMapString);
}

Future<Map<String, String>> loadpinQuickAccess() async {
  final prefs = await SharedPreferences.getInstance();
  String? dataString = prefs.getString('CSpinQuickAccess');
  if (dataString != null) {
    return Map<String, String>.from(json.decode(dataString));
  }
  return {};
}
//*-Dispositivos que tienen el acceso rápido habilitado-*\\

//*-Tokens de los celulares-*\\
Future<void> saveToken(String token) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('CStoken', token);
}

Future<String> loadToken() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('CStoken') ?? '';
}
//*-Tokens de los celulares-*\\

//*-Sonido notificaciones*-\\
Future<void> saveSounds(Map<String, String> sounds) async {
  final prefs = await SharedPreferences.getInstance();
  String tokenString = json.encode(sounds);
  await prefs.setString('CSsounds', tokenString);
}

Future<Map<String, String>> loadSounds() async {
  final prefs = await SharedPreferences.getInstance();
  String? soundsString = prefs.getString('CSsounds');
  if (soundsString != null) {
    return Map<String, String>.from(json.decode(soundsString));
  }
  return {};
}
//*-Sonido notificaciones*-\\

//*-Fecha reinicio gasto-*\\
Future<void> guardarFecha(String device) async {
  DateTime now = DateTime.now();
  SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.setInt('CSyear$device', now.year);
  await prefs.setInt('CSmonth$device', now.month);
  await prefs.setInt('CSday$device', now.day);
}

Future<DateTime?> cargarFechaGuardada(String device) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  int? year = prefs.getInt('CSyear$device');
  int? month = prefs.getInt('CSmonth$device');
  int? day = prefs.getInt('CSday$device');
  if (year != null && month != null && day != null) {
    return DateTime(year, month, day);
  } else {
    return null;
  }
}
//*-Fecha reinicio gasto-*\\

//*-Imagenes Scan-*\\
Future<Map<String, String>> loadDeviceImages() async {
  final prefs = await SharedPreferences.getInstance();
  final jsonString = prefs.getString('CSdeviceImages');
  if (jsonString != null) {
    return Map<String, String>.from(jsonDecode(jsonString));
  } else {
    return {};
  }
}

Future<void> saveDeviceImage(String deviceId, String imagePath) async {
  final prefs = await SharedPreferences.getInstance();

  deviceImages[deviceId] = imagePath;

  final jsonString = jsonEncode(deviceImages);
  await prefs.setString('CSdeviceImages', jsonString);
}

Future<void> removeDeviceImage(String deviceId) async {
  final prefs = await SharedPreferences.getInstance();
  deviceImages.remove(deviceId);
  final jsonString = jsonEncode(deviceImages);
  await prefs.setString('CSdeviceImages', jsonString);
}
//*-Imagenes Scan-*\\

//*-Notificación Desconexión-*\\
Future<void> saveconfigNotiDsc(Map<String, int> data) async {
  final prefs = await SharedPreferences.getInstance();
  String taskMapString = json.encode(data);
  await prefs.setString('CSconfigNotiDsc', taskMapString);
}

Future<Map<String, int>> loadconfigNotiDsc() async {
  final prefs = await SharedPreferences.getInstance();
  String? dataString = prefs.getString('CSconfigNotiDsc');
  if (dataString != null) {
    return Map<String, int>.from(json.decode(dataString));
  }
  return {};
}
//*-Notificación Desconexión-*\\

//*- Guardar y cargar última página-*\\
Future<void> saveLastPage(int index) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt('CSlastPageIndex', index);
}

Future<int?> loadLastPage() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  return prefs.getInt('CSlastPageIndex') ?? 0;
}
//*- Guardar y cargar última página-*\\

//*- Guardar si el tutorial esta activado -*\\
Future<void> saveTutorial(bool tutorial) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('CSTutorial', tutorial);
}

Future<bool> loadTutorial() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  return prefs.getBool('CSTutorial') ?? true;
}
//*- Guardar si el tutorial esta activado -*\\

//*- Guardar email -*\\
Future<void> saveEmail(String email) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.setString('CSEmail', email);
}

Future<String> loadEmail() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  return prefs.getString('CSEmail') ?? '';
}
//*- Guardar email -*\\

//*- Guardar top score del Easter Egg -*\\
Future<void> saveEasterEggTopScore(int topScore) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.setInt('CSEasterEggTopScore', topScore);
}

Future<int> loadEasterEggTopScore() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  return prefs.getInt('CSEasterEggTopScore') ?? 0;
}
//*- Guardar top score del Easter Egg -*\\

//*- Guardar lista de equipos wifi -*\\
Future<void> saveWifiOrderDevices(
    List<Map<String, String>> devices, String email) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  String jsonList = jsonEncode(devices);
  await prefs.setString('CSwifiOrderDevices_$email', jsonList);
}

Future<List<Map<String, String>>> loadWifiOrderDevices(String email) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  String? jsonList = prefs.getString('CSwifiOrderDevices_$email');
  if (jsonList == null) return [];
  List<dynamic> decoded = jsonDecode(jsonList);
  return decoded
      .map<Map<String, String>>((e) => Map<String, String>.from(e))
      .toList();
}
//*- Guardar lista de equipos wifi -*\\
