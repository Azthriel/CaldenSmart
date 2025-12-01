import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:caldensmart/Devices/heladera.dart';
import 'package:caldensmart/Devices/modulo.dart';
import 'package:caldensmart/Devices/relay.dart';
import 'package:caldensmart/Devices/rele1i1o.dart';
import 'package:caldensmart/Devices/riego.dart';
import 'package:caldensmart/Devices/termometro.dart';
import 'package:caldensmart/Devices/termotanques.dart';
import 'package:caldensmart/Escenas/escenas.dart';
import 'package:caldensmart/Global/profile.dart';
// import 'package:caldensmart/widget/select_device.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:upgrader/upgrader.dart';
import 'Devices/domotica.dart';
import 'Devices/detectores.dart';
import 'Devices/roller.dart';
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
import 'login/welcome.dart';
import 'master.dart';
import 'Global/stored_data.dart';
import 'package:caldensmart/logger.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    printLog.i("Iniciando Firebase");
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    printLog.i("Firebase inicializado");
  } catch (e) {
    printLog.e("Error al configurar Firebase: $e");
  }

  try {
    printLog.i("Añadiendo plugin de Amplify");
    await Amplify.addPlugin(
      AmplifyAuthCognito(),
    );
    printLog.i("Configurando Amplify");
    await Amplify.configure(amplifyconfig);
    printLog.i("Amplify configurado");
  } catch (e) {
    printLog.e("Error al configurar Amplify: $e");
  }

  //! IOS O ANDROID !\\
  android = Platform.isAndroid;
  //! IOS O ANDROID !\\

  final upgrader = Upgrader(
    debugLogging: false,
  );

  await upgrader.initialize();

  appVersionNumber = upgrader.currentInstalledVersion ?? '4.0.4';

  appName = nameOfApp(app);

  await initNotifications();

  DeviceManager.init();

  FirebaseMessaging.onBackgroundMessage(handleNotifications);

  FirebaseMessaging.onMessage.listen(handleNotifications);

  FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);

  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterError;

  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  printLog.i('Todo configurado, iniciando app');

  runApp(
    const ProviderScope(
      child: MyApp(),
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

    initAsync();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      fToast = FToast();
      fToast.init(context);
    });

    printLog.i('Empezamos');
  }

  @override
  void dispose() {
    cancelGlobalConnectionListener();
    super.dispose();
  }

  void initAsync() async {
    await loadValues();
    printLog.i('Valores cargados');
    await setupMqtt();
    listenToTopics();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      builder: FToastBuilder(),
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      title: nameOfApp(app),
      theme: ThemeData(
        textTheme: GoogleFonts.poppinsTextTheme(),
        primaryColor: color3,
        primaryColorLight: color4,
        textSelectionTheme: const TextSelectionThemeData(
          selectionColor: color0,
          selectionHandleColor: color0,
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          surfaceTintColor: Colors.transparent,
          backgroundColor: Colors.transparent,
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: color3,
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
        '/modulo': (context) => const ModuloPage(),
        '/heladera': (context) => const HeladeraPage(),
        '/rele1i1o': (context) => const Rele1i1oPage(),
        '/qr': (context) => const QRScanPage(),
        '/termometro': (context) => const TermometroPage(),
        '/riego': (context) => const RiegoPage(),
        '/termotanque': (context) => const TermotanquePage(),
        // '/widget_config_selection': (context) => const SelectDeviceScreen(),
      },
    );
  }
}
