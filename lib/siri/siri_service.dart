import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:caldensmart/master.dart';
import 'package:caldensmart/logger.dart';

/// Publica en el App Group compartido la lista de equipos que Siri puede
/// controlar, para que la App Intents Extension resuelva "las luces" a un
/// productCode + serialNumber + index concretos.
///
/// La extension NO puede consultar DynamoDB ni levantar Amplify: es un proceso
/// aparte con poca memoria y ~10s de vida. Por eso la app le deja la lista
/// pre-armada.
///
/// Escribe por MethodChannel propio y NO por home_widget: asi Siri no depende
/// de la configuracion de los widgets de iOS (que hoy no existen).
///
/// Solo iOS. En Android no se usa.
class SiriService {
  static const _channel = MethodChannel('com.caldensmart.sime/siri');

  static Timer? _debounce;

  /// Version debounced de [syncDevices]. **Usar esta en la mayoria de los casos.**
  ///
  /// La lista depende de nicknamesMap Y de globalDATA, y globalDATA se llena
  /// de a poco por MQTT. En vez de adivinar el momento exacto en que esta todo
  /// cargado, se llama a esto cada vez que algo cambia: la ultima llamada
  /// dentro de la ventana es la que termina ejecutandose.
  ///
  /// Llamarlo 50 veces por segundo no cuesta nada: solo reinicia el timer.
  static void scheduleSync({Duration delay = const Duration(seconds: 2)}) {
    if (!Platform.isIOS) return;

    _debounce?.cancel();
    _debounce = Timer(delay, syncDevices);
  }

  /// Mismos codigos que MULTIPIN_CODES en el Lambda siri_command.
  /// Si agregas uno aca, agregalo tambien alla.
  static const Set<String> _multipinCodes = {
    '020010_IOT',
    '020020_IOT',
    '027313_IOT',
  };

  /// Tipos que Siri no puede prender/apagar:
  ///   015773_IOT detector, 023430_IOT termometro -> solo lectura
  ///   024011_IOT cortina    -> abre/cierra, no on/off (queda para otro intent)
  ///   027131_IOT riel       -> mismo criterio que shouldHaveWidget
  static const Set<String> _excludedCodes = {
    '015773_IOT',
    '023430_IOT',
    '024011_IOT',
    '027131_IOT',
  };

  /// Recorre los equipos del usuario y escribe la lista en el App Group.
  ///
  /// Version directa, sin debounce. Preferí [scheduleSync] salvo que necesites
  /// que la escritura ocurra ya (por ejemplo antes de abrir la hoja de Siri).
  static Future<void> syncDevices() async {
    if (!Platform.isIOS) return;

    try {
      final entries = <Map<String, dynamic>>[];

      // Respetamos el orden de la lista wifi del usuario: si dos equipos
      // tienen nombres parecidos, Siri prioriza el que el usuario ve primero.
      for (final deviceName in getOrderedDeviceList()) {
        final productCode = DeviceManager.getProductCode(deviceName);
        final serialNumber = DeviceManager.extractSerialNumber(deviceName);

        if (productCode.isEmpty || serialNumber.isEmpty) continue;
        if (_excludedCodes.contains(productCode)) continue;

        final deviceNickname = nicknamesMap[deviceName] ?? deviceName;
        final deviceData = globalDATA['$productCode/$serialNumber'];

        if (_multipinCodes.contains(productCode)) {
          entries.addAll(_buildPinEntries(
            deviceName: deviceName,
            deviceNickname: deviceNickname,
            productCode: productCode,
            serialNumber: serialNumber,
            deviceData: deviceData,
          ));
        } else {
          entries.add({
            'id': '$productCode#$serialNumber#0',
            'name': deviceNickname,
            'room': '',
            'productCode': productCode,
            'serialNumber': serialNumber,
            'index': 0,
          });
        }
      }

      await _channel.invokeMethod('saveDevices', {
        'devices': jsonEncode(entries),
      });
      printLog.i('[Siri] ${entries.length} equipos publicados al App Group');
    } on PlatformException catch (e) {
      printLog.e('[Siri] Error publicando equipos: ${e.message}');
    } catch (e, st) {
      printLog.e('[Siri] Error publicando equipos: $e');
      printLog.e(st.toString());
    }
  }

  /// Un entry por cada SALIDA del equipo multipin.
  ///
  /// Las entradas (pinType != 0) quedan afuera: no se comandan, solo se leen.
  /// El Lambda tambien las rechaza, pero mejor que Siri ni las ofrezca.
  static List<Map<String, dynamic>> _buildPinEntries({
    required String deviceName,
    required String deviceNickname,
    required String productCode,
    required String serialNumber,
    required Map<String, dynamic>? deviceData,
  }) {
    final result = <Map<String, dynamic>>[];
    if (deviceData == null) return result;

    // 027313_IOT con hasEntry == false se muestra en la app como un equipo
    // unico, sin el sufijo "salida N". Si usaramos el fallback generico, Siri
    // ofreceria "Salida 0", un nombre que el usuario nunca vio.
    final bool singleOutput = productCode == '027313_IOT' &&
        (deviceData['hasEntry'] ?? true) == false;

    var i = 0;
    while (true) {
      final ioData = deviceData['io$i'];
      if (ioData == null) break;

      Map<String, dynamic> ioMap = {};
      if (ioData is String) {
        ioMap = jsonDecode(ioData);
      } else if (ioData is Map) {
        ioMap = Map<String, dynamic>.from(ioData);
      }

      final pinType = ioMap['pinType']?.toString() ?? '0';
      if (pinType == '0') {
        // Misma convencion que el resto de la app: nickname del pin, y si no
        // tiene, el fallback que corresponda segun el tipo de equipo.
        final pinNickname = nicknamesMap['${deviceName}_$i'] ??
            (singleOutput ? deviceNickname : 'Salida $i');

        result.add({
          'id': '$productCode#$serialNumber#$i',
          'name': pinNickname,
          // El nickname del equipo va como contexto: si el usuario tiene
          // "Luces" en dos equipos, Siri puede desambiguar. Si el nombre del
          // pin ya es el del equipo, no lo repetimos.
          'room': pinNickname == deviceNickname ? '' : deviceNickname,
          'productCode': productCode,
          'serialNumber': serialNumber,
          'index': i,
        });
      }

      i++;
    }

    return result;
  }

  /// Vacia la lista.
  ///
  /// No hace falta llamarlo en el logout si ya llamas a
  /// SiriCredentials.clear(): ese metodo tambien vacia la lista, para que no
  /// queden equipos del usuario anterior si una de las dos llamadas falla.
  static Future<void> clearDevices() async {
    if (!Platform.isIOS) return;

    try {
      await _channel.invokeMethod('saveDevices', {'devices': '[]'});
      printLog.i('[Siri] Lista de equipos vaciada');
    } on PlatformException catch (e) {
      printLog.e('[Siri] Error vaciando equipos: ${e.message}');
    }
  }
}
