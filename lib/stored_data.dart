import 'dart:convert';
import '/aws/dynamo/dynamo_certificates.dart';
import '/aws/dynamo/dynamo.dart';
import 'master.dart';
import 'package:shared_preferences/shared_preferences.dart';

// MASTERLOAD \\
//*-Cargo toda la data-*\\
void loadValues() async {
  globalDATA = await loadGlobalData();
  previusConnections = await loadDeviceList();
  topicsToSub = await loadTopicList();
  nicknamesMap = await loadNicknamesMap();
  tokensOfDevices = await loadToken();
  subNicknamesMap = await loadSubNicknamesMap();
  notificationMap = await loadNotificationMap();
  deviceImages = await loadDeviceImages();
  soundOfNotification = await loadSounds();
  detectorOff = await loadDetectorOff();
  devicesToTrack = await loadDeviceListToTrack();
  msgFlag = await loadmsgFlag();

  for (String device in previusConnections) {
    await queryItems(service, command(device), extractSerialNumber(device));
  }
}
//*-Cargo toda la data-*\\
// MASTERLOAD \\

//*-Dispositivos conectados-*\\
Future<void> saveDeviceList(List<String> listaDispositivos) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.setStringList('connectedDevices', listaDispositivos);
}

Future<List<String>> loadDeviceList() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  return prefs.getStringList('connectedDevices') ?? [];
}
//*-Dispositivos conectados-*\\

//*-Topics mqtt-*\\
Future<void> saveTopicList(List<String> listatopics) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.setStringList('Topics', listatopics);
}

Future<List<String>> loadTopicList() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  return prefs.getStringList('Topics') ?? [];
}
//*-Topics mqtt-*\\

//*-Nicknames-*\\
Future<void> saveNicknamesMap(Map<String, String> nicknamesMap) async {
  final prefs = await SharedPreferences.getInstance();
  String nicknamesString = json.encode(nicknamesMap);
  await prefs.setString('nicknamesMap', nicknamesString);
}

Future<Map<String, String>> loadNicknamesMap() async {
  final prefs = await SharedPreferences.getInstance();
  String? nicknamesString = prefs.getString('nicknamesMap');
  if (nicknamesString != null) {
    return Map<String, String>.from(json.decode(nicknamesString));
  }
  return {}; // Devuelve un mapa vacío si no hay nada almacenado
}
//*-Nicknames-*\\

//*-SubNicknames-*\\
Future<void> saveSubNicknamesMap(Map<String, String> nicknamesMap) async {
  final prefs = await SharedPreferences.getInstance();
  String nicknamesString = json.encode(nicknamesMap);
  await prefs.setString('subNicknamesMap', nicknamesString);
}

Future<Map<String, String>> loadSubNicknamesMap() async {
  final prefs = await SharedPreferences.getInstance();
  String? nicknamesString = prefs.getString('subNicknamesMap');
  if (nicknamesString != null) {
    return Map<String, String>.from(json.decode(nicknamesString));
  }
  return {}; // Devuelve un mapa vacío si no hay nada almacenado
}
//*-SubNicknames-*\\

//*-GlobalDATA-*\\
Future<void> saveGlobalData(
    Map<String, Map<String, dynamic>> globalData) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  Map<String, String> stringMap = globalData.map((key, value) {
    return MapEntry(key, json.encode(value));
  });
  await prefs.setString('globalData', json.encode(stringMap));
}

Future<Map<String, Map<String, dynamic>>> loadGlobalData() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  String? jsonString = prefs.getString('globalData');
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

//*-Position-*\\
Future<void> savePositionLatitude(Map<String, double> latitudeMap) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  String latitude = json.encode(latitudeMap);
  await prefs.setString('latitude', latitude);
}

Future<Map<String, double>> loadLatitude() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  String? latitude = prefs.getString('latitude');
  if (latitude != null) {
    return Map<String, double>.from(json.decode(latitude));
  }
  return {};
}

Future<void> savePositionLongitud(Map<String, double> longitudMap) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  String longitud = json.encode(longitudMap);
  await prefs.setString('longitud', longitud);
}

Future<Map<String, double>> loadLongitud() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  String? longitud = prefs.getString('longitud');
  if (longitud != null) {
    return Map<String, double>.from(json.decode(longitud));
  }
  return {};
}
//*-Position-*\\

//*-Control de distancia habilitado-*\\
Future<void> saveControlValue(Map<String, bool> taskMap) async {
  final prefs = await SharedPreferences.getInstance();
  String taskMapString = json.encode(taskMap);
  await prefs.setString('taskMap', taskMapString);
}

Future<Map<String, bool>> loadControlValue() async {
  final prefs = await SharedPreferences.getInstance();
  String? taskMapString = prefs.getString('taskMap');
  if (taskMapString != null) {
    return Map<String, bool>.from(json.decode(taskMapString));
  }
  return {}; // Devuelve un mapa vacío si no hay nada almacenado
}
//*-Control de distancia habilitado-*\\

//*-Dispositivos con control por distancia habilitado-*\\
Future<void> saveDevicesForDistanceControl(List<String> devices) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  prefs.setStringList('DevicesForDistanceControl', devices);
}

Future<List<String>> loadDevicesForDistanceControl() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  return prefs.getStringList('DevicesForDistanceControl') ?? [];
}
//*-Dispositivos con control por distancia habilitado-*\\

//*-Dómotica con notis encendida-*\\
Future<void> saveNotificationMap(Map<String, List<bool>> map) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  String jsonString = json.encode(map);
  await prefs.setString('NotificationMap', jsonString);
}

Future<Map<String, List<bool>>> loadNotificationMap() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  String? jsonString = prefs.getString('NotificationMap');
  Map<String, List<bool>> map = jsonString != null
      ? Map.from(json.decode(jsonString)).map((key, value) {
          List<bool> boolList = List<bool>.from(value);
          return MapEntry(key, boolList);
        })
      : {};

  return map;
}
//*-Dómotica con notis encendida-*\\

//*-Dispositivos de los que sos dueño-*\\
Future<void> saveOwnedDevices(List<String> lista) async {
  final prefs = await SharedPreferences.getInstance();
  String devicesList = json.encode(lista);
  await prefs.setString('OwnedDevices', devicesList);
}

Future<List<String>> loadOwnedDevices() async {
  final prefs = await SharedPreferences.getInstance();
  String? devicesList = prefs.getString('OwnedDevices');
  if (devicesList != null) {
    List<dynamic> decodedList = json.decode(devicesList);
    return decodedList.cast<String>();
  }
  return []; // Devuelve una lista vacía si no hay nada almacenado
}
//*-Dispositivos de los que sos dueño-*\\

//*-Tokens de los celulares-*\\
Future<void> saveToken(Map<String, String> token) async {
  final prefs = await SharedPreferences.getInstance();
  String tokenString = json.encode(token);
  await prefs.setString('tokens', tokenString);
}

Future<Map<String, String>> loadToken() async {
  final prefs = await SharedPreferences.getInstance();
  String? tokenString = prefs.getString('tokens');
  if (tokenString != null) {
    return Map<String, String>.from(json.decode(tokenString));
  }
  return {}; // Devuelve un mapa vacío si no hay nada almacenado
}
//*-Tokens de los celulares-*\\

//*-Sonido notificaciones*-\\
Future<void> saveSounds(Map<String, String> sounds) async {
  final prefs = await SharedPreferences.getInstance();
  String tokenString = json.encode(sounds);
  await prefs.setString('sounds', tokenString);
}

Future<Map<String, String>> loadSounds() async {
  final prefs = await SharedPreferences.getInstance();
  String? soundsString = prefs.getString('sounds');
  if (soundsString != null) {
    return Map<String, String>.from(json.decode(soundsString));
  }
  return {}; // Devuelve un mapa vacío si no hay nada almacenado
}
//*-Sonido notificaciones*-\\

//*-Fecha reinicio gasto-*\\
Future<void> guardarFecha(String device) async {
  DateTime now = DateTime.now();
  SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.setInt('year$device', now.year);
  await prefs.setInt('month$device', now.month);
  await prefs.setInt('day$device', now.day);
}

Future<DateTime?> cargarFechaGuardada(String device) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  int? year = prefs.getInt('year$device');
  int? month = prefs.getInt('month$device');
  int? day = prefs.getInt('day$device');
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
  final jsonString = prefs.getString('deviceImages');
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
  await prefs.setString('deviceImages', jsonString);
}

Future<void> removeDeviceImage(String deviceId) async {
  final prefs = await SharedPreferences.getInstance();
  deviceImages.remove(deviceId);
  final jsonString = jsonEncode(deviceImages);
  await prefs.setString('deviceImages', jsonString);
}
//*-Imagenes Scan-*\\

//*-Equipos que detectores apagan-*\\
Future<void> saveDetectorOff(Map<String, List<String>> lista) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String jsonString = jsonEncode(lista);
  await prefs.setString('detectorOff', jsonString);
}

Future<Map<String, List<String>>> loadDetectorOff() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? jsonString = prefs.getString('detectorOff');
  if (jsonString != null) {
    Map<String, dynamic> jsonMap = jsonDecode(jsonString);
    return jsonMap.map((key, value) => MapEntry(key, List<String>.from(value)));
  } else {
    return {};
  }
}
//*-Equipos que detectores apagan-*\\

//*-Omnipresencia-*\\
Future<void> saveDeviceListToTrack(List<String> listaDispositivos) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.setStringList('devicesToTrack', listaDispositivos);
}

Future<List<String>> loadDeviceListToTrack() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  return prefs.getStringList('devicesToTrack') ?? [];
}

Future<void> savePinToTrack(List<String> listaPines, String device) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.setStringList('pinsToTrack$device', listaPines);
}

Future<List<String>> loadPinToTrack(String device) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  return prefs.getStringList('pinsToTrack$device') ?? [];
}

Future<void> saveMsgFlag(Map<String, bool> msgFlag) async {
  final prefs = await SharedPreferences.getInstance();
  String taskMapString = json.encode(msgFlag);
  await prefs.setString('msgFlag', taskMapString);
}

Future<Map<String, bool>> loadmsgFlag() async {
  final prefs = await SharedPreferences.getInstance();
  String? msgFlagString = prefs.getString('msgFlag');
  if (msgFlagString != null) {
    return Map<String, bool>.from(json.decode(msgFlagString));
  }
  return {}; // Devuelve un mapa vacío si no hay nada almacenado
}

//*-Omnipresencia-*\\