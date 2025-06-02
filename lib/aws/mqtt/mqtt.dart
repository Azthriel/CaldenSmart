import 'dart:convert';
import 'dart:io';
import '/master.dart';
import '/aws/mqtt/mqtt_certificates.dart';
import '../../Global/stored_data.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:provider/provider.dart';
import 'package:caldensmart/logger.dart';

MqttServerClient? mqttAWSFlutterClient;

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

    // Configuración de las credenciales
    mqttAWSFlutterClient!.setProtocolV311();
    mqttAWSFlutterClient!.keepAlivePeriod = 30;
    try {
      await mqttAWSFlutterClient!.connect();
      printLog.i('Usuario conectado a mqtt');

      return true;
    } catch (e) {
      printLog.i('Error intentando conectar: $e');

      return false;
    }
  } catch (e, s) {
    printLog.i('Error setup mqtt $e $s');
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
    mqttAWSFlutterClient!
        .publishMessage(topic, MqttQos.atLeastOnce, builder.payload!, retain: true);
    printLog.i('Mensaje enviado');
  } catch (e, s) {
    printLog.i('Error sending message $e $s');
  }
}
//*-Envíar mensaje a los topics-*\\

//*-Subscribir y desuscribir a los topics-*\\
void subToTopicMQTT(String topic) {
  try {
    mqttAWSFlutterClient!.subscribe(topic, MqttQos.atLeastOnce);
    printLog.i('Subscrito correctamente a $topic');
  } catch (e) {
    printLog.i('Error al subscribir al topic $topic, $e');
  }
}

void unSubToTopicMQTT(String topic) {
  mqttAWSFlutterClient!.unsubscribe(topic);
  printLog.i('Me desuscribo de $topic');
  topicsToSub.remove(topic);
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
    String keyName = "${listNames[1]}/${listNames[2]}";
    printLog.i('Keyname: $keyName');

    final String messageString = utf8.decode(message);
    printLog.i('Mensaje: $messageString');
    try {
      final Map<String, dynamic> messageMap = json.decode(messageString) ?? {};

      printLog.i('Mensaje decodificado: $messageMap');

      bool specialDevice = (messageMap.keys.contains('index') &&
          !messageMap.keys.contains('cstate'));

      printLog.i('Special device: $specialDevice');

      if (specialDevice) {
        printLog.i('Mensaje domotica $messageMap');
        int index = messageMap["index"];
        globalDATA
            .putIfAbsent(keyName, () => {})
            .addAll({'io$index': json.encode(messageMap)});
        saveGlobalData(globalDATA);
        GlobalDataNotifier notifier = Provider.of<GlobalDataNotifier>(
            navigatorKey.currentContext!,
            listen: false);
        notifier.updateData(
          keyName,
          {'io$index': json.encode(messageMap)},
        );
      } else {
        globalDATA.putIfAbsent(keyName, () => {}).addAll(messageMap);
        saveGlobalData(globalDATA);
        GlobalDataNotifier notifier = Provider.of<GlobalDataNotifier>(
            navigatorKey.currentContext!,
            listen: false);
        // printLog.i('Notificando a $keyName');
        // printLog.i('Mensaje: $messageMap');
        notifier.updateData(keyName, messageMap);
      }

      // globalDATA.putIfAbsent(keyName, () => {}).addAll(messageMap);
      // saveGlobalData(globalDATA);
      // GlobalDataNotifier notifier = Provider.of<GlobalDataNotifier>(
      //     navigatorKey.currentContext!,
      //     listen: false);
      // notifier.updateData(keyName, messageMap);

      printLog.i('Received message: $messageMap from topic: $topic');
    } catch (e, s) {
      printLog.e('Error decoding message: $e');
      printLog.t('Error decoding message: $s');
    }
  });
}
//*-Recibe los mensajes que se envían a los topics-*\\
