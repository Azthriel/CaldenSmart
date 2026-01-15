import 'dart:convert';
import 'dart:io';
import 'package:caldensmart/widget/widget_handler.dart';

import '/master.dart';
import '/aws/mqtt/mqtt_certificates.dart';
import '/aws/dynamo/dynamo.dart';
import '../../Global/stored_data.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' as riverpod;
import 'package:caldensmart/logger.dart';
import 'package:caldensmart/Escenas/models/evento_estado.dart';

MqttServerClient? mqttAWSFlutterClient;

// Provider para almacenar el estado de los eventos
final eventosEstadoProvider = riverpod.StateNotifierProvider<
    EventosEstadoNotifier, Map<String, EventoEstado>>((ref) {
  return EventosEstadoNotifier();
});

// Notifier para gestionar el estado de los eventos
class EventosEstadoNotifier
    extends riverpod.StateNotifier<Map<String, EventoEstado>> {
  EventosEstadoNotifier() : super({});

  void updateEstado(
      String tipoEvento, String nombreEvento, EventoEstado nuevoEstado) {
    final key = '$tipoEvento/$nombreEvento';
    state = {...state, key: nuevoEstado};
    printLog.i('Estado del evento $key actualizado: ${nuevoEstado.status}');
  }

  EventoEstado? getEstado(String tipoEvento, String nombreEvento) {
    final key = '$tipoEvento/$nombreEvento';
    return state[key];
  }

  void clearEstado(String tipoEvento, String nombreEvento) {
    final key = '$tipoEvento/$nombreEvento';
    state = Map.from(state)..remove(key);
  }
}

//*-Conexión y desconexión IoT Core-*\\
Future<bool> setupMqtt() async {
  try {
    printLog.i('Haciendo setup');
    String deviceId = 'FlutterDevice/${generateRandomNumbers(32)}';
    String broker = mqttBroker;

    mqttAWSFlutterClient = MqttServerClient(broker, deviceId);

    mqttAWSFlutterClient!.secure = true;
    mqttAWSFlutterClient!.port = 8883;
    mqttAWSFlutterClient!.securityContext = SecurityContext.defaultContext;

    mqttAWSFlutterClient!.securityContext
        .setTrustedCertificatesBytes(utf8.encode(caCert));
    mqttAWSFlutterClient!.securityContext
        .useCertificateChainBytes(utf8.encode(certChain));
    mqttAWSFlutterClient!.securityContext
        .usePrivateKeyBytes(utf8.encode(privateKey));

    mqttAWSFlutterClient!.logging(on: true);
    mqttAWSFlutterClient!.onDisconnected = mqttonDisconnected;

    mqttAWSFlutterClient!.setProtocolV311();
    mqttAWSFlutterClient!.keepAlivePeriod = 30;
    try {
      await mqttAWSFlutterClient!.connect();
      printLog.i('Usuario conectado a mqtt');

      return true;
    } catch (e) {
      printLog.e('Error intentando conectar: $e');

      return false;
    }
  } catch (e, s) {
    printLog.e('Error setup mqtt $e $s');
    return false;
  }
}

void mqttonDisconnected() {
  printLog.i('Desconectado de mqtt');
  reconnectMqtt();
}

void reconnectMqtt() async {
  await setupMqtt().then((value) {
    if (value) {
      for (var topic in topicsToSub) {
        printLog.i('Subscribiendo a $topic');
        subToTopicMQTT(topic);
      }
      listenToTopics();
    } else {
      reconnectMqtt();
    }
  });
}
//*-Conexión y desconexión IoT Core-*\\

//*-Envíar mensaje a los topics-*\\
void sendMessagemqtt(String topic, String message) {
  printLog.i('Voy a mandar $message');
  printLog.i('A el topic $topic');
  final MqttClientPayloadBuilder builder = MqttClientPayloadBuilder();
  builder.addString(message);

  printLog.i('${builder.payload} : ${utf8.decode(builder.payload!)}');

  try {
    mqttAWSFlutterClient!.publishMessage(
        topic, MqttQos.atLeastOnce, builder.payload!,
        retain: true);
    printLog.i('Mensaje enviado');
  } catch (e, s) {
    printLog.e('Error sending message $e $s');
  }
}
//*-Envíar mensaje a los topics-*\\

//*-Subscribir y desuscribir a los topics-*\\
void subToTopicMQTT(String topic) {
  try {
    mqttAWSFlutterClient!.subscribe(topic, MqttQos.atLeastOnce);
    printLog.i('Subscrito correctamente a $topic');
  } catch (e) {
    printLog.e('Error al subscribir al topic $topic, $e');
  }
}

void unSubToTopicMQTT(String topic) {
  mqttAWSFlutterClient!.unsubscribe(topic);
  printLog.i('Me desuscribo de $topic');
  topicsToSub.remove(topic);
}

//*-Funciones específicas para eventos-*\\
void subscribeToEventoStatus(
    String tipoEvento, String userEmail, String nombreEvento) {
  final topic = 'eventos/$tipoEvento/$userEmail/$nombreEvento/status';
  subToTopicMQTT(topic);
  if (!topicsToSub.contains(topic)) {
    topicsToSub.add(topic);
  }
  printLog.i('📡 Suscrito al evento $tipoEvento: $nombreEvento');
}

void unsubscribeFromEventoStatus(
    String tipoEvento, String userEmail, String nombreEvento) {
  final topic = 'eventos/$tipoEvento/$userEmail/$nombreEvento/status';
  unSubToTopicMQTT(topic);
  printLog.i('📡 Desuscrito del evento $tipoEvento: $nombreEvento');
}

// Suscribirse a todos los eventos del usuario al inicializar
void subscribeToAllUserEventos(
    String userEmail, List<Map<String, dynamic>> eventos) {
  for (var evento in eventos) {
    String? tipoEvento;
    String? nombreEvento = evento['title'];

    if (nombreEvento == null) continue;

    // Determinar el tipo de evento
    if (evento['evento'] == 'cadena') {
      tipoEvento = 'ControlPorCadena';
    } else if (evento['evento'] == 'riego') {
      tipoEvento = 'ControlPorRiego';
    } else if (evento['evento'] == 'grupo') {
      tipoEvento = 'ControlPorGrupos';
    }

    if (tipoEvento != null) {
      subscribeToEventoStatus(tipoEvento, userEmail, nombreEvento);
    }
  }
}
//*-Subscribir y desuscribir a los topics-*\\

//*-Recibe los mensajes que se envían a los topics-*\\
void listenToTopics() {
  mqttAWSFlutterClient!.updates!.listen((c) {
    printLog.i('LLego algo(mqtt)');
    final MqttPublishMessage recMess = c[0].payload as MqttPublishMessage;
    final String topic = c[0].topic;
    var listNames = topic.split('/');
    final List<int> message = recMess.payload.message;

    final String messageString = utf8.decode(message);
    printLog.i('Topic: $topic');
    printLog.i('Mensaje: $messageString');

    try {
      final Map<String, dynamic> messageMap = json.decode(messageString) ?? {};
      printLog.i('Mensaje decodificado: $messageMap');

      // 🎯 MANEJO DE MENSAJES DE EVENTOS (Control por Cadena, Riego, Grupos)
      if (topic.startsWith('eventos/')) {
        // Topic format: eventos/{tipoEvento}/{userEmail}/{nombreEvento}/status
        if (listNames.length >= 5 && listNames[4] == 'status') {
          final tipoEvento = listNames[
              1]; // ControlPorCadena, ControlPorRiego, ControlPorGrupos
          final userEmail = listNames[2];
          final nombreEvento = listNames[3];

          printLog.i('📡 Mensaje de estado de evento recibido:');
          printLog.i('   - Tipo: $tipoEvento');
          printLog.i('   - Usuario: $userEmail');
          printLog.i('   - Nombre: $nombreEvento');
          printLog.i('   - Estado: ${messageMap['status']}');

          // Solo procesar si es del usuario actual
          if (userEmail == currentUserEmail) {
            final eventoEstado = EventoEstado.fromJson(messageMap);

            // Actualizar el provider con el nuevo estado
            final container = riverpod.ProviderScope.containerOf(
                navigatorKey.currentContext!);
            container
                .read(eventosEstadoProvider.notifier)
                .updateEstado(tipoEvento, nombreEvento, eventoEstado);

            // Si el evento se completó, marcar como no ejecutando
            if (eventoEstado.isCompleted) {
              printLog.i('🎉 Evento "$nombreEvento" completado!');

              // Remover de la lista de ejecutando según el tipo
              if (tipoEvento == 'ControlPorCadena') {
                removeCadenaExecuting(nombreEvento, currentUserEmail);
                cadenaCompletedController.add(nombreEvento);
              } else if (tipoEvento == 'ControlPorRiego') {
                removeRiegoExecuting(nombreEvento, currentUserEmail);
                riegoCompletedController.add(nombreEvento);
              }
            }

            // Si el evento fue cancelado, también removerlo
            if (eventoEstado.isCancelled) {
              printLog.i('❌ Evento "$nombreEvento" cancelado');

              if (tipoEvento == 'ControlPorCadena') {
                removeCadenaExecuting(nombreEvento, currentUserEmail);
              } else if (tipoEvento == 'ControlPorRiego') {
                removeRiegoExecuting(nombreEvento, currentUserEmail);
              }
            }

            // Si hay error, remover y notificar
            if (eventoEstado.hasError) {
              printLog.e(
                  '⚠️ Error en evento "$nombreEvento": ${eventoEstado.error}');

              if (tipoEvento == 'ControlPorCadena') {
                removeCadenaExecuting(nombreEvento, currentUserEmail);
              } else if (tipoEvento == 'ControlPorRiego') {
                removeRiegoExecuting(nombreEvento, currentUserEmail);
              }
            }
          }
          return;
        }
      }

      String pc = listNames[1];
      String sn = listNames[2];

      // 🔧 MANEJO DE MENSAJES DE DISPOSITIVOS (lógica existente)
      String keyName = "$pc/$sn";
      printLog.i('Keyname: $keyName');

      bool specialDevice = (messageMap.keys.contains('index') &&
          !messageMap.keys.contains('cstate'));

      printLog.i('Special device: $specialDevice');

      if (specialDevice) {
        printLog.i('Mensaje domotica $messageMap');
        int index = messageMap["index"];
        final encoded = {'io$index': json.encode(messageMap)};
        globalDATA.putIfAbsent(keyName, () => {}).addAll(encoded);

        final container =
            riverpod.ProviderScope.containerOf(navigatorKey.currentContext!);
        container
            .read(globalDataProvider.notifier)
            .updateData(keyName, encoded);

        // Actualizar widgets para dispositivos con pin
        bool isOn = messageMap['w_status'] ?? false;
        bool isOnline = globalDATA[keyName]?['cstate'] ?? false;
        updateWidgetsForDevice(pc, sn, isOn, isOnline, pinIndex: index);
      } else {
        globalDATA.putIfAbsent(keyName, () => {}).addAll(messageMap);

        final container =
            riverpod.ProviderScope.containerOf(navigatorKey.currentContext!);
        container
            .read(globalDataProvider.notifier)
            .updateData(keyName, messageMap);

        // Actualizar widgets para dispositivos normales
        if (messageMap.containsKey('w_status') ||
            messageMap.containsKey('cstate')) {
          bool isOn = messageMap['w_status'] ??
              globalDATA[keyName]?['w_status'] ??
              false;
          bool isOnline =
              messageMap['cstate'] ?? globalDATA[keyName]?['cstate'] ?? true;
          updateWidgetsForDevice(pc, sn, isOn, isOnline);
        }
      }

      printLog.i('Received message: $messageMap from topic: $topic');
    } catch (e, s) {
      printLog.e('Error decoding message: $e');
      printLog.t('Error decoding message: $s');
    }
  });
}
//*-Recibe los mensajes que se envían a los topics-*\\

// 🆕 Cargar estados iniciales de eventos desde DynamoDB
Future<void> loadInitialEventosState(
    String userEmail, riverpod.WidgetRef ref) async {
  try {
    printLog.i('📥 Cargando estados iniciales de eventos desde DynamoDB...');

    // Consultar eventos de ControlPorCadena
    final eventosCadena = await queryEventosControlPorCadena(userEmail);

    for (var evento in eventosCadena) {
      final nombreEvento = evento['nombreEvento'];
      final estadoEjecucion = evento['estado_ejecucion'];

      if (estadoEjecucion != null) {
        final status = estadoEjecucion['status'];

        // Si el evento está en ejecución o pausado, restaurar su estado
        if (status == 'running' || status == 'paused') {
          final pasoActual = estadoEjecucion['paso_actual'] ?? 0;
          final totalPasos = estadoEjecucion['total_pasos'] ?? 0;
          final pasosCompletados = estadoEjecucion['pasos_completados'] ?? [];
          final pasosCompletadosCount = pasosCompletados.length;

          // Crear mensaje consistente con el formato de ejecución
          final mensaje =
              '$pasosCompletadosCount pasos completados de $totalPasos${status == 'paused' ? ' - Pausado' : ''}';

          final eventoEstado = EventoEstado(
            status: status,
            pasoActual: pasoActual,
            totalPasos: totalPasos,
            mensaje: mensaje,
            timestamp: DateTime.now().millisecondsSinceEpoch,
          );

          // Actualizar el provider
          ref.read(eventosEstadoProvider.notifier).updateEstado(
                'ControlPorCadena',
                nombreEvento,
                eventoEstado,
              );

          printLog.i(
              '✅ Estado restaurado [Cadena]: $nombreEvento - $status ($pasosCompletadosCount/$totalPasos pasos completados)');
        }
      }
    }

    // Consultar eventos de ControlDeRiego
    final eventosRiego = await queryEventosControlDeRiego(userEmail);

    for (var evento in eventosRiego) {
      final nombreEvento = evento['nombreEvento'];
      final estadoEjecucion = evento['estado_ejecucion'];

      if (estadoEjecucion != null) {
        final status = estadoEjecucion['status'];

        // Si el evento está en ejecución o pausado, restaurar su estado
        if (status == 'running' || status == 'paused') {
          final pasoActual = estadoEjecucion['paso_actual'] ?? 0;
          final totalPasos = estadoEjecucion['total_pasos'] ?? 0;
          final pasosCompletados = estadoEjecucion['pasos_completados'] ?? [];
          final pasosCompletadosCount = pasosCompletados.length;

          // Crear mensaje consistente con el formato de ejecución
          final mensaje =
              '$pasosCompletadosCount pasos completados de $totalPasos${status == 'paused' ? ' - Pausado' : ''}';

          final eventoEstado = EventoEstado(
            status: status,
            pasoActual: pasoActual,
            totalPasos: totalPasos,
            mensaje: mensaje,
            timestamp: DateTime.now().millisecondsSinceEpoch,
          );

          // Actualizar el provider
          ref.read(eventosEstadoProvider.notifier).updateEstado(
                'ControlPorRiego',
                nombreEvento,
                eventoEstado,
              );

          printLog.i(
              '✅ Estado restaurado [Riego]: $nombreEvento - $status ($pasosCompletadosCount/$totalPasos pasos completados)');
        }
      }
    }

    printLog.i('✅ Estados iniciales cargados correctamente');
  } catch (e) {
    printLog.e('❌ Error cargando estados iniciales: $e');
  }
}
