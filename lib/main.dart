import 'dart:io';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:caldensmart/Devices/domotica4i4o.dart';
import 'package:caldensmart/Devices/millenium.dart';
import 'package:caldensmart/Devices/modulo.dart';
import 'package:caldensmart/Devices/relay.dart';
import 'package:caldensmart/Global/profile.dart';
import 'package:upgrader/upgrader.dart';
import 'Devices/domotica.dart';
import 'Devices/detectores.dart';
import 'Devices/roller.dart';
import 'Global/escenas.dart';
import 'easterEgg/easter_egg.dart';
import 'Global/loading.dart';
import 'Global/menu.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'Devices/calefactores.dart';
import 'amplifyconfiguration.dart';
import 'aws/mqtt/mqtt.dart';
import 'firebase_options.dart';
import 'Global/permission.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'login/welcome.dart';
import 'master.dart';
import 'Global/stored_data.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  //! IOS O ANDROID !\\
  android = Platform.isAndroid;
  //! IOS O ANDROID !\\
  appVersionNumber = Upgrader().currentInstalledVersion ?? '4.0.4';

  try {
    if (Firebase.apps.isEmpty) {
      printLog("Skibidi toilet", "Cyan");
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    printLog("Firebase ya está inicializado: $e");
  }

  await Amplify.addPlugin(
    AmplifyAuthCognito(),
  );
  await Amplify.configure(amplifyconfig);

  appName = nameOfApp(app);

  await initNotifications();

  FirebaseMessaging.onBackgroundMessage(handleNotifications);

  FirebaseMessaging.onMessage.listen(handleNotifications);

  FlutterError.onError = (FlutterErrorDetails details) async {
    String errorReport = generateErrorReport(details);
    if (xDebugMode) {
      sendReportError(errorReport);
    }
  };

  printLog('Todo configurado, iniciando app');
  runApp(
    ChangeNotifierProvider(
      create: (context) => GlobalDataNotifier(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  MyAppState createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();

    loadValues();

    setupMqtt().then((value) {
      if (value) {
        for (var topic in topicsToSub) {
          printLog('Subscribiendo a $topic');
          subToTopicMQTT(topic);
        }
      }
    });
    listenToTopics();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      fbData = await fetchDocumentData();
      printLog(fbData, "rojo");
    });

    printLog('Empezamos');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      title: nameOfApp(app),
      theme: ThemeData(
        primaryColor: color5,
        primaryColorLight: color6,
        textSelectionTheme: const TextSelectionThemeData(
          selectionColor: color1,
          selectionHandleColor: color1,
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          surfaceTintColor: Colors.transparent,
          backgroundColor: Colors.transparent,
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: color5,
        ),
        useMaterial3: true,
      ),
      initialRoute: '/perm',
      routes: {
        '/perm': (context) => const PermissionHandler(),
        '/welcome': (context) => const WelcomePage(),
        '/loading': (context) => const LoadingPage(),
        '/menu': (context) => const MenuPage(),
        '/eg': (context) => const EasterEgg(),
        '/detector': (context) => const DetectorPage(),
        '/calefactor': (context) => const CalefactorPage(),
        '/domotica': (context) => const DomoticaPage(),
        '/profile': (context) => const ProfilePage(),
        '/escenas': (context) => const EscenasPage(),
        '/rele': (context) => const RelayPage(),
        '/roller': (context) => const RollerPage(),
        '/millenium': (context) => const MilleniumPage(),
        '/domotica4i4o': (context) => const Domotica4i4oPage(),
        '/modulo': (context) => const ModuloPage(),
      },
    );
  }
}
