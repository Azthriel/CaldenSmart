import 'dart:convert';
import 'package:caldensmart/aws/dynamo/dynamo_certificates.dart';
import 'package:caldensmart/logger.dart';
import 'package:aws_dynamodb_api/dynamodb-2012-08-10.dart';
import 'package:caldensmart/aws/mqtt/mqtt.dart';
import '/master.dart';
import '../../Global/stored_data.dart';

//*-Lee todos los datos de un equipo-*\\
Future<void> queryItems(String pc, String sn) async {
  try {
    printLog.i('Buscare en el equipo: $pc/$sn');
    final response = await service.query(
      tableName: 'sime-domotica',
      keyConditionExpression: 'product_code = :pk AND device_id = :sk',
      expressionAttributeValues: {
        ':pk': AttributeValue(s: pc),
        ':sk': AttributeValue(s: sn),
      },
    );

    if (response.items != null) {
      printLog.i('Items encontrados');
      // printLog.i(response.items);
      for (var item in response.items!) {
        printLog.i("-----------Inicio de un item-----------");
        for (var key in item.keys) {
          var value = item[key];
          var displayValue = value?.s ??
              value?.n ??
              value?.boolValue.toString() ??
              value?.ss?.join('/') ??
              "Desconocido";
          if (value != null) {
            switch (key) {
              case 'alert':
                globalDATA
                    .putIfAbsent('$pc/$sn', () => {})
                    .addAll({key: value.boolValue ?? false});
                break;
              case 'cstate':
                globalDATA
                    .putIfAbsent('$pc/$sn', () => {})
                    .addAll({key: value.boolValue ?? false});
                break;
              case 'w_status':
                globalDATA
                    .putIfAbsent('$pc/$sn', () => {})
                    .addAll({key: value.boolValue ?? false});
                break;
              case 'f_status':
                globalDATA
                    .putIfAbsent('$pc/$sn', () => {})
                    .addAll({key: value.boolValue ?? false});
                break;
              case 'ppmco':
                globalDATA
                    .putIfAbsent('$pc/$sn', () => {})
                    .addAll({key: int.parse(value.n ?? '0')});
                break;
              case 'ppmch4':
                globalDATA
                    .putIfAbsent('$pc/$sn', () => {})
                    .addAll({key: int.parse(value.n ?? '0')});
                break;
              case 'distanceOn':
                globalDATA
                    .putIfAbsent('$pc/$sn', () => {})
                    .addAll({key: double.parse(value.n ?? '3000')});
                break;
              case 'distanceOff':
                globalDATA
                    .putIfAbsent('$pc/$sn', () => {})
                    .addAll({key: double.parse(value.n ?? '100')});
                break;
              case 'AT':
                globalDATA
                    .putIfAbsent('$pc/$sn', () => {})
                    .addAll({key: value.boolValue ?? false});
                break;
              case 'tenant':
                globalDATA
                    .putIfAbsent('$pc/$sn', () => {})
                    .addAll({key: value.s ?? ''});
                break;
              case 'owner':
                globalDATA
                    .putIfAbsent('$pc/$sn', () => {})
                    .addAll({key: value.s ?? ''});
                break;
              case 'secondary_admin':
                List<String> secAdm = value.ss ?? [];
                if (secAdm.contains('') && secAdm.length == 1) {
                  globalDATA.putIfAbsent('$pc/$sn', () => {}).addAll({key: []});
                } else {
                  globalDATA
                      .putIfAbsent('$pc/$sn', () => {})
                      .addAll({key: secAdm});
                }
                break;
              case 'isNC':
                globalDATA
                    .putIfAbsent('$pc/$sn', () => {})
                    .addAll({key: value.boolValue ?? false});
                break;
              case 'rollerSavedLength':
                globalDATA
                    .putIfAbsent('$pc/$sn', () => {})
                    .addAll({key: value.s ?? ''});
                break;
              case 'io0' || 'io1' || 'io2' || 'io3':
                Map<String, AttributeValue> mapa = value.m ?? {};
                Map<String, dynamic> valores = {};
                for (String llave in mapa.keys) {
                  AttributeValue valor = mapa[llave]!;
                  valores.addAll({llave: valor.boolValue ?? valor.n});
                }
                globalDATA
                    .putIfAbsent('$pc/$sn', () => {})
                    .addAll({key: jsonEncode(valores)});
                break;
              case 'hasSpark':
                globalDATA
                    .putIfAbsent('$pc/$sn', () => {})
                    .addAll({key: value.boolValue ?? false});
                break;
              case 'LabProcessFinished':
                globalDATA
                    .putIfAbsent('$pc/$sn', () => {})
                    .addAll({key: value.boolValue ?? false});
                break;
              case 'hasEntry':
                globalDATA
                    .putIfAbsent('$pc/$sn', () => {})
                    .addAll({key: value.boolValue ?? false});
                break;
              case 'HardwareVersion':
                globalDATA
                    .putIfAbsent('$pc/$sn', () => {})
                    .addAll({key: value.s ?? ''});
                break;
              case 'SoftwareVersion':
                globalDATA
                    .putIfAbsent('$pc/$sn', () => {})
                    .addAll({key: value.s ?? ''});
                break;
            }
          }
          printLog.i("$key: $displayValue");
          saveGlobalData(globalDATA);
        }
        printLog.i("-----------Fin de un item-----------");
      }
    } else {
      printLog.i('Dispositivo no encontrado');
    }
  } catch (e) {
    printLog.i('Error durante la consulta: $e');
  }
}
//*-Lee todos los datos de un equipo-*\\

//*-Guarda y lee Tokens en dynamo-*\\
Future<void> putTokens(String pc, String sn, List<String> data) async {
  if (data.isEmpty) {
    data.add('');
  }
  try {
    final response = await service.updateItem(tableName: 'sime-domotica', key: {
      'product_code': AttributeValue(s: pc),
      'device_id': AttributeValue(s: sn),
    }, attributeUpdates: {
      'tokens': AttributeValueUpdate(value: AttributeValue(ss: data)),
    });

    printLog.i('Item escrito perfectamente $response');
  } catch (e) {
    printLog.i('Error inserting item: $e');
  }
}

Future<List<String>> getTokens(String pc, String sn) async {
  try {
    final response = await service.getItem(
      tableName: 'sime-domotica',
      key: {
        'product_code': AttributeValue(s: pc),
        'device_id': AttributeValue(s: sn),
      },
    );
    if (response.item != null) {
      // Convertir AttributeValue a String
      var item = response.item!;
      List<String> tokens = item['tokens']?.ss ?? [];

      printLog.i('Se encontro el siguiente item: $tokens');

      if (tokens.contains('') && tokens.length == 1) {
        return [];
      } else {
        return tokens;
      }
    } else {
      printLog.i('Item no encontrado.');
      return [];
    }
  } catch (e) {
    printLog.i('Error al obtener el item: $e');
    return [];
  }
}
//*-Guarda y lee Tokens en dynamo-*\\

//*-Guarda el mail del owner de un equipo en dynamo-*\\
Future<void> putOwner(String pc, String sn, String data) async {
  try {
    final response = await service.updateItem(tableName: 'sime-domotica', key: {
      'product_code': AttributeValue(s: pc),
      'device_id': AttributeValue(s: sn),
    }, attributeUpdates: {
      'owner': AttributeValueUpdate(value: AttributeValue(s: data)),
    });

    printLog.i('Item escrito perfectamente $response');
  } catch (e) {
    printLog.i('Error inserting item: $e');
  }
}
//*-Guarda el mail del owner de un equipo en dynamo-*\\

//*-Guarda y lee los mails de los admins de un equipo en dynamo-*\\
Future<void> putSecondaryAdmins(String pc, String sn, List<String> data) async {
  if (data.isEmpty) {
    data.add('');
  }
  try {
    final response = await service.updateItem(tableName: 'sime-domotica', key: {
      'product_code': AttributeValue(s: pc),
      'device_id': AttributeValue(s: sn),
    }, attributeUpdates: {
      'secondary_admin': AttributeValueUpdate(value: AttributeValue(ss: data)),
    });

    printLog.i('Item escrito perfectamente $response');
  } catch (e) {
    printLog.i('Error inserting item: $e');
  }
}

Future<List<String>> getSecondaryAdmins(String pc, String sn) async {
  try {
    final response = await service.getItem(
      tableName: 'sime-domotica',
      key: {
        'product_code': AttributeValue(s: pc),
        'device_id': AttributeValue(s: sn),
      },
    );
    if (response.item != null) {
      // Convertir AttributeValue a String
      var item = response.item!;
      List<String> secAdm = item['secondary_admin']?.ss ?? [];

      printLog.i('Se encontro el siguiente item: $secAdm');

      if (secAdm.contains('') && secAdm.length == 1) {
        return [];
      } else {
        return secAdm;
      }
    } else {
      printLog.i('Item no encontrado.');
      return [];
    }
  } catch (e) {
    printLog.i('Error al obtener el item: $e');
    return [];
  }
}
//*-Guarda y lee los mails de los admins de un equipo en dynamo-*\\

//*-Lee las fechas de vencimiento de los beneficios que se hayan pagado en un equipo-*\\
Future<List<DateTime>> getDates(String pc, String sn) async {
  try {
    final response = await service.getItem(
      tableName: 'sime-domotica',
      key: {
        'product_code': AttributeValue(s: pc),
        'device_id': AttributeValue(s: sn),
      },
    );
    if (response.item != null) {
      var item = response.item!;
      List<DateTime> fechaExp = [];
      String? date = item['DateSecAdm']?.s;
      String? date2 = item['DateAT']?.s;
      printLog.i('Fecha encontrada');

      if (date != null && date != '') {
        var parts = date.split('/');
        fechaExp.add(
          DateTime(
            int.parse(parts[0]),
            int.parse(parts[1]),
            int.parse(parts[2]),
          ),
        );
      } else {
        fechaExp.add(DateTime.now());
      }

      if (date2 != null && date2 != '') {
        var parts = date2.split('/');
        fechaExp.add(
          DateTime(
            int.parse(parts[0]),
            int.parse(parts[1]),
            int.parse(parts[2]),
          ),
        );
      } else {
        fechaExp.add(DateTime.now());
      }

      return fechaExp;
    } else {
      printLog.i('Item no encontrado.');
      return [DateTime.now(), DateTime.now()];
    }
  } catch (e) {
    printLog.i('Error al obtener las fechas $e');
    return [DateTime.now(), DateTime.now()];
  }
}
//*-Lee las fechas de vencimiento de los beneficios que se hayan pagado en un equipo-*\\

//*-Escribe la distancia de encendido y apagado de el control por distancia de un equipo-*\\
Future<void> putDistanceOn(String pc, String sn, String data) async {
  try {
    final response = await service.updateItem(tableName: 'sime-domotica', key: {
      'product_code': AttributeValue(s: pc),
      'device_id': AttributeValue(s: sn),
    }, attributeUpdates: {
      'distanceOn': AttributeValueUpdate(value: AttributeValue(n: data)),
    });

    printLog.i('Item escrito perfectamente $response');
  } catch (e) {
    printLog.i('Error inserting item: $e');
  }
}

Future<void> putDistanceOff(String pc, String sn, String data) async {
  try {
    final response = await service.updateItem(tableName: 'sime-domotica', key: {
      'product_code': AttributeValue(s: pc),
      'device_id': AttributeValue(s: sn),
    }, attributeUpdates: {
      'distanceOff': AttributeValueUpdate(value: AttributeValue(n: data)),
    });

    printLog.i('Item escrito perfectamente $response');
  } catch (e) {
    printLog.i('Error inserting item: $e');
  }
}
//*-Escribe la distancia de encendido y apagado de el control por distancia de un equipo-*\\

//*-Guarda la data del alquiler temporario (airbnb) de un equipo-*\\
Future<void> saveATData(String pc, String sn, bool activate, String mail,
    String dOn, String dOff) async {
  try {
    final response = await service.updateItem(tableName: 'sime-domotica', key: {
      'product_code': AttributeValue(s: pc),
      'device_id': AttributeValue(s: sn),
    }, attributeUpdates: {
      'AT': AttributeValueUpdate(value: AttributeValue(boolValue: activate)),
      'tenant': AttributeValueUpdate(value: AttributeValue(s: mail)),
      'distanceOn': AttributeValueUpdate(value: AttributeValue(n: dOn)),
      'distanceOff': AttributeValueUpdate(value: AttributeValue(n: dOff)),
    });

    activatedAT = activate;
    printLog.i('Inquilino escrito perfectamente $response');
  } catch (e) {
    printLog.i('Error inserting item: $e');
  }
}
//*-Guarda la data del alquiler temporario (airbnb) de un equipo-*\\

//*-Guardar si un equipo es NA o NC-*\\
Future<void> saveNC(String pc, String sn, bool data) async {
  try {
    final response = await service.updateItem(tableName: 'sime-domotica', key: {
      'product_code': AttributeValue(s: pc),
      'device_id': AttributeValue(s: sn),
    }, attributeUpdates: {
      'isNC': AttributeValueUpdate(value: AttributeValue(boolValue: data)),
    });

    printLog.i('Item escrito perfectamente $response');
  } catch (e) {
    printLog.i('Error inserting item: $e');
  }
}
//*-Guardar si un equipo es NA o NC-*\\

///*-Guardar equipos en dynamo-*\\\
Future<void> putDevicesForAlexa(String email, List<String> data) async {
  if (data.isEmpty) {
    data.add('');
  }
  try {
    // Se actualiza el ítem, asignando 'devices' con la lista proporcionada (vacía o no).
    final response = await service.updateItem(
      tableName: 'Alexa-Devices',
      key: {
        'email': AttributeValue(s: email),
      },
      attributeUpdates: {
        'devices': AttributeValueUpdate(value: AttributeValue(ss: data)),
      },
    );
    printLog.i('Item actualizado correctamente: $response');
  } catch (e) {
    printLog.i('Error actualizando el ítem de Alexa: $e');
  }
}

Future<void> putPreviusConnections(String email, List<String> data) async {
  if (data.isEmpty) {
    data.add('');
  }
  try {
    // Se actualiza el ítem, asignando 'devices' con la lista proporcionada (vacía o no).
    final response = await service.updateItem(
      tableName: 'Alexa-Devices',
      key: {
        'email': AttributeValue(s: email),
      },
      attributeUpdates: {
        'previusConnections':
            AttributeValueUpdate(value: AttributeValue(ss: data)),
      },
    );
    printLog.i('Item actualizado correctamente: $response');
  } catch (e) {
    printLog.i('Error actualizando el ítem de Alexa: $e');
  }
}

///*-Guardar equipos en dynamo-*\\\

///*-Guardar y obtener Nicknames de los equipo-*\\\
Future<void> putNicknames(String email, Map<String, String> data) async {
  try {
    final response = await service.updateItem(tableName: 'Alexa-Devices', key: {
      'email': AttributeValue(s: email),
    }, attributeUpdates: {
      'nicknames': AttributeValueUpdate(
        value: AttributeValue(
          m: {
            for (final entry in data.entries)
              entry.key: AttributeValue(s: entry.value),
          },
        ),
      ),
    });

    printLog.i('Item escrito perfectamente $response');
  } catch (e) {
    printLog.i('Error guardando alexa item: $e');
  }
}

Future<void> getNicknames(String email) async {
  try {
    final response = await service.getItem(
      tableName: 'Alexa-Devices',
      key: {'email': AttributeValue(s: email)},
    );
    if (response.item != null) {
      // Convertir AttributeValue a String
      var item = response.item!;

      Map<String, AttributeValue> mapa = item['nicknames']?.m ?? {};
      mapa.forEach((key, value) {
        nicknamesMap.addAll({key: value.s ?? ''});
      });
      printLog.i('Nicknames encontrados: $nicknamesMap');
    } else {
      printLog.i('Item no encontrado. No está el mail en la database');
    }
  } catch (e) {
    printLog.i('Error al obtener el item: $e');
  }
}

///*-Guardar y obtener Nicknames de los equipo-*\\\

///*-Guardar el largo del Roller-*\\\
Future<void> putRollerLength(String pc, String sn, String data) async {
  try {
    final response = await service.updateItem(tableName: 'sime-domotica', key: {
      'product_code': AttributeValue(s: pc),
      'device_id': AttributeValue(s: sn),
    }, attributeUpdates: {
      'rollerSavedLength': AttributeValueUpdate(value: AttributeValue(s: data)),
    });

    printLog.i('Item escrito perfectamente $response');
  } catch (e) {
    printLog.i('Error inserting item: $e');
  }
}

///*-Guardar el largo del Roller-*\\\

///*-Leer las conexiones previas y los grupos-*\\\
///Está función lee los equipos y grupos de la base de datos de DynamoDB
///y los guarda en las variables previusConnections y groupsOfDevices respectivamente.
///También lee los dispositivos de Asistentes por voz y los guarda en la variable alexaDevices.
///A su vez, guarda los topics a los que se va a suscribir el cliente MQTT en la variable topicsToSub.
///Por último, guarda los nicknames de los dispositivos en la variable nicknamesMap.
Future<void> getDevices(String email) async {
  try {
    final response = await service.getItem(
      tableName: 'Alexa-Devices',
      key: {'email': AttributeValue(s: email)},
    );
    if (response.item != null) {
      // Convertir AttributeValue a String
      var item = response.item!;
      List<String> equipos = item['previusConnections']?.ss ?? [];
      if (equipos.contains('') && equipos.length == 1) {
        equipos = [];
      }

      previusConnections = equipos;

      for (String equipo in previusConnections) {
        topicsToSub.add(
            'devices_tx/${DeviceManager.getProductCode(equipo)}/${DeviceManager.extractSerialNumber(equipo)}');

        subToTopicMQTT(
            'devices_tx/${DeviceManager.getProductCode(equipo)}/${DeviceManager.extractSerialNumber(equipo)}');
      }

      printLog.i('Se encontro el siguiente item: $equipos');

      alexaDevices = item['devices']?.ss ?? [];
      if (alexaDevices.contains('') && alexaDevices.length == 1) {
        alexaDevices = [];
      }
      printLog.i('Equipos de asistentes por voz: $alexaDevices');

      await DeviceManager.init();

      for (String device in previusConnections) {
        await queryItems(DeviceManager.getProductCode(device),
            DeviceManager.extractSerialNumber(device));
      }
    } else {
      printLog.i('Item no encontrado. No está el mail en la database');
    }
  } catch (e) {
    printLog.i('Error al obtener el item: $e');
  }
}

Future<void> getGroups(String email) async {
  try {
    final response = await service.getItem(
      tableName: 'Alexa-Devices',
      key: {'email': AttributeValue(s: email)},
    );
    if (response.item != null) {
      // Convertir AttributeValue a String
      var item = response.item!;
      final raw = item['groups']?.m ?? <String, AttributeValue>{};
      final Map<String, List<String>> grupos = {
        for (final e in raw.entries)
          e.key: (e.value.ss ?? []).where((s) => s.isNotEmpty).toList()
      };

      if (grupos.isNotEmpty) {
        grupos.forEach((k, v) => printLog.i('$k: $v'));
        groupsOfDevices = grupos;
      } else {
        printLog.i('No se encontraron grupos.');
      }
    } else {
      printLog.i('Item no encontrado. No está el mail en la database');
    }
  } catch (e) {
    printLog.i('Error al obtener el item: $e');
  }
}
//*-Leer las conexiones previas y los grupos-*\\\

//*-Guardar los grupos de dispositivos-*\\
void putGroupsOfDevices(String email, Map<String, List<String>> data) async {
  try {
    final response = await service.updateItem(tableName: 'Alexa-Devices', key: {
      'email': AttributeValue(s: email),
    }, attributeUpdates: {
      'groups': AttributeValueUpdate(
        value: AttributeValue(
          m: {
            for (final entry in data.entries)
              entry.key: AttributeValue(ss: entry.value),
          },
        ),
      ),
    });

    printLog.i('Item escrito perfectamente $response');
  } catch (e) {
    printLog.i('Error guardando alexa item: $e');
  }
}
//*-Guardar los grupos de dispositivos-*\\

/// Guarda la lista [eventosCreados] (List<Map<String, dynamic>>) bajo la clave primaria [email]
void putEventos(
  String email,
  List<Map<String, dynamic>> eventosCreados,
) async {
  try {
    // Convertir cada Map a AttributeValue(M)
    final attributeList = eventosCreados.map((evento) {
      final m = <String, AttributeValue>{};
      evento.forEach((key, value) {
        if (value is String) {
          m[key] = AttributeValue(s: value);
        } else if (value is num) {
          m[key] = AttributeValue(n: value.toString());
        } else if (value is bool) {
          m[key] = AttributeValue(boolValue: value);
        } else if (value is List) {
          m[key] = AttributeValue(
              l: value.map((e) {
            if (e is String) return AttributeValue(s: e);
            if (e is num) return AttributeValue(n: e.toString());
            if (e is bool) return AttributeValue(boolValue: e);
            return AttributeValue(s: e.toString());
          }).toList());
        } else if (value is Map<String, dynamic>) {
          final nested = <String, AttributeValue>{};
          value.forEach((k, v) {
            if (v is String) {
              nested[k] = AttributeValue(s: v);
            } else if (v is num) {
              nested[k] = AttributeValue(n: v.toString());
            } else if (v is bool) {
              nested[k] = AttributeValue(boolValue: v);
            } else {
              nested[k] = AttributeValue(s: v.toString());
            }
          });
          m[key] = AttributeValue(m: nested);
        } else {
          m[key] = AttributeValue(s: value.toString());
        }
      });
      return AttributeValue(m: m);
    }).toList();

    // Actualizar el item en DynamoDB
    await service.updateItem(
      tableName: 'Alexa-Devices',
      key: {'email': AttributeValue(s: email)},
      attributeUpdates: {
        'events': AttributeValueUpdate(value: AttributeValue(l: attributeList)),
      },
    );
    printLog.i('Eventos guardados correctamente');
  } catch (e) {
    printLog.i('Error al guardar eventos: $e');
  }
}

/// Carga y convierte de vuelta a List<Map<String, dynamic>> desde DynamoDB
Future<List<Map<String, dynamic>>> getEventos(
  String email,
) async {
  try {
    final response = await service.getItem(
      tableName: 'Alexa-Devices',
      key: {'email': AttributeValue(s: email)},
    );

    final listAttr = response.item?['events']?.l;
    if (listAttr == null) return [];

    return listAttr.map((av) {
      final map = <String, dynamic>{};
      av.m?.forEach((key, val) {
        if (val.s != null) {
          map[key] = val.s;
        } else if (val.n != null) {
          map[key] = num.parse(val.n!);
        } else if (val.boolValue != null) {
          map[key] = val.boolValue;
        } else if (val.l != null) {
          map[key] =
              val.l!.map((e) => e.s ?? e.n ?? e.boolValue ?? e.m).toList();
        } else if (val.m != null) {
          final nested = <String, dynamic>{};
          val.m!.forEach((k, v) {
            if (v.s != null) {
              nested[k] = v.s;
            } else if (v.n != null) {
              nested[k] = num.parse(v.n!);
            } else if (v.boolValue != null) {
              nested[k] = v.boolValue;
            } else {
              nested[k] = null;
            }
          });
          map[key] = nested;
        } else {
          map[key] = null;
        }
      });
      return map;
    }).toList();
  } catch (e) {
    printLog.i('Error al cargar eventos: $e');
    return [];
  }
}

///Guarda la ubicación del equipo en la base de datos
Future<void> saveLocation(String pc, String sn, String data) async {
  try {
    final response = await service.updateItem(tableName: 'sime-domotica', key: {
      'product_code': AttributeValue(s: pc),
      'device_id': AttributeValue(s: sn),
    }, attributeUpdates: {
      'deviceLocation': AttributeValueUpdate(value: AttributeValue(s: data)),
    });

    printLog.i('Item escrito perfectamente $response');
  } catch (e) {
    printLog.i('Error inserting item: $e');
  }
}

///Guarda las versiones de Hardware y Software
Future<void> putVersions(String pc, String sn, String hard, String soft) async {
  try {
    final response = await service.updateItem(tableName: 'sime-domotica', key: {
      'product_code': AttributeValue(s: pc),
      'device_id': AttributeValue(s: sn),
    }, attributeUpdates: {
      'HardwareVersion': AttributeValueUpdate(value: AttributeValue(s: hard)),
      'SoftwareVersion': AttributeValueUpdate(value: AttributeValue(s: soft)),
    });

    printLog.i('Item escrito perfectamente $response');
  } catch (e) {
    printLog.i('Error inserting item: $e');
  }
}

//*-Obtener datos generales de la aplicación desde GENERALDATA-*\\
Future<Map<String, dynamic>> getGeneralData() async {
  try {
    printLog.i('Obteniendo datos generales de GENERALDATA...');
    final response = await service.getItem(
      tableName: 'GENERALDATA',
      key: {
        'App': AttributeValue(s: 'Caldén Smart'),
      },
    );

    if (response.item != null) {
      Map<String, dynamic> generalData = {};
      var item = response.item!;

      for (var key in item.keys) {
        if (key == 'App') continue; // Saltear la clave principal

        var value = item[key];
        if (value?.m != null) {
          // Es un mapa (Map)
          Map<String, dynamic> mapValue = {};
          for (var mapKey in value!.m!.keys) {
            var mapVal = value.m![mapKey];
            mapValue[mapKey] = mapVal?.s ??
                mapVal?.n ??
                mapVal?.boolValue ??
                mapVal?.ss ??
                mapVal?.toString();
          }
          generalData[key] = mapValue;
        } else if (value?.l != null) {
          // Es una lista (List)
          List<dynamic> listValue = [];
          for (var listItem in value!.l!) {
            listValue.add(listItem.s ??
                listItem.n ??
                listItem.boolValue ??
                listItem.toString());
          }
          generalData[key] = listValue;
        } else if (value?.ss != null) {
          // Es un conjunto de strings (StringSet)
          generalData[key] = value!.ss!;
        } else {
          // Es un valor simple
          generalData[key] =
              value?.s ?? value?.n ?? value?.boolValue ?? value?.toString();
        }
      }

      printLog.i('Datos generales obtenidos correctamente');
      return generalData;
    } else {
      printLog.i('No se encontraron datos generales en GENERALDATA');
      return {};
    }
  } catch (e) {
    printLog.i('Error al obtener datos generales de GENERALDATA: $e');
    return {};
  }
}
//*-Obtener datos generales de la aplicación desde GENERALDATA-*\\

//*- Guarda evento: Control por disparadores -*\\
/// Obtiene los ejecutores existentes de un evento disparador para un tipo específico de alerta
Future<Map<String, bool>> getEventoDisparador(String activador,
    {String? tipoAlerta}) async {
  try {
    final response = await service.getItem(
      tableName: 'Eventos_ControlDisparadores',
      key: {
        'deviceName': AttributeValue(s: activador),
      },
    );

    if (response.item != null) {
      var item = response.item!;

      // Si se especifica un tipo de alerta, buscar esa clave específica
      String claveEjecutores = tipoAlerta ?? 'ejecutores';
      Map<String, AttributeValue> ejecutoresMap =
          item[claveEjecutores]?.m ?? {};
      Map<String, bool> ejecutores = {};

      for (String key in ejecutoresMap.keys) {
        AttributeValue value = ejecutoresMap[key]!;
        ejecutores[key] = value.boolValue ?? false;
      }

      printLog.i(
          'Ejecutores existentes encontrados para $claveEjecutores: $ejecutores');
      return ejecutores;
    } else {
      printLog.i('No se encontraron ejecutores existentes para $activador');
      return {};
    }
  } catch (e) {
    printLog.i('Error al obtener ejecutores existentes: $e');
    return {};
  }
}

/// Guarda el estado de los ejecutores de un evento disparador
/// [activador] es el nombre del dispositivo que activa el disparador
/// [nuevosEjecutores] son los ejecutores a guardar con sus estados (true/false)
/// [tipoAlerta] especifica el tipo de alerta para construir la clave:
///   - Para alertas simples: 'ejecutoresAlert_true' o 'ejecutoresAlert_false'
///   - Para termómetros: 'ejecutoresMAX_true', 'ejecutoresMAX_false', 'ejecutoresMIN_true', 'ejecutoresMIN_false'
void putEventoDisparador(String activador, Map<String, bool> nuevosEjecutores,
    {String tipoAlerta = 'ejecutores'}) async {
  try {
    final response = await service
        .updateItem(tableName: 'Eventos_ControlDisparadores', key: {
      'deviceName': AttributeValue(s: activador),
    }, attributeUpdates: {
      tipoAlerta: AttributeValueUpdate(
        value: AttributeValue(
          m: {
            for (final entry in nuevosEjecutores.entries)
              entry.key: AttributeValue(boolValue: entry.value),
          },
        ),
      ),
    });

    printLog.i('Ejecutores guardados para $tipoAlerta: $response');
  } catch (e) {
    printLog.i('Error guardando ejecutores: $e');
  }
}

/// Elimina ejecutores específicos de un evento disparador
/// [activador] es el nombre del dispositivo activador
/// [ejecutoresAEliminar] lista de ejecutores a eliminar
/// [tipoAlerta] especifica qué tipo de alerta eliminar (opcional, si no se especifica elimina de todos los tipos)
void removeEjecutoresFromDisparador(
    String activador, List<String> ejecutoresAEliminar,
    {String? tipoAlerta}) async {
  try {
    if (tipoAlerta != null) {
      // Eliminar de un tipo específico de alerta
      Map<String, bool> ejecutoresExistentes =
          await getEventoDisparador(activador, tipoAlerta: tipoAlerta);

      if (ejecutoresExistentes.isEmpty) {
        printLog
            .i('No hay ejecutores existentes para $activador en $tipoAlerta');
        return;
      }

      // Remover los ejecutores especificados
      for (String ejecutor in ejecutoresAEliminar) {
        ejecutoresExistentes.remove(ejecutor);
      }

      if (ejecutoresExistentes.isEmpty) {
        // Eliminar la clave completa si no quedan ejecutores
        await service.updateItem(
          tableName: 'Eventos_ControlDisparadores',
          key: {'deviceName': AttributeValue(s: activador)},
          attributeUpdates: {
            tipoAlerta: AttributeValueUpdate(action: AttributeAction.delete),
          },
        );
        printLog.i('Eliminada clave $tipoAlerta para $activador');
      } else {
        // Actualizar con los ejecutores restantes
        putEventoDisparador(activador, ejecutoresExistentes,
            tipoAlerta: tipoAlerta);
      }
    } else {
      // Eliminar de todos los tipos de alerta posibles
      List<String> tiposAlerta = [
        'ejecutores', // Retrocompatibilidad
        'ejecutoresAlert_true',
        'ejecutoresAlert_false',
        'ejecutoresMAX_true',
        'ejecutoresMAX_false',
        'ejecutoresMIN_true',
        'ejecutoresMIN_false',
      ];

      for (String tipo in tiposAlerta) {
        removeEjecutoresFromDisparador(activador, ejecutoresAEliminar,
            tipoAlerta: tipo);
      }
    }
  } catch (e) {
    printLog.i('Error eliminando ejecutores: $e');
  }
}
//*- Guarda evento: Control por disparadores -*\\
