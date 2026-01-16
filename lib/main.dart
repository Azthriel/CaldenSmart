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
import 'package:caldensmart/widget/select_device.dart';
import 'package:caldensmart/widget/widget_handler.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:home_widget/home_widget.dart';
import 'package:permission_handler/permission_handler.dart';
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
import 'package:hugeicons/hugeicons.dart';

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

  HomeWidget.registerInteractivityCallback(backgroundCallback);

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
  bool _isInitialized = false;
  bool _hasInternet = true;
  bool _isCheckingInternet = true;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      fToast = FToast();
      fToast.init(context);
      _initializeApp();
    });

    printLog.i('Empezamos');
  }

  @override
  void dispose() {
    cancelGlobalConnectionListener();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    // Verificar conexión a internet
    setState(() {
      _isCheckingInternet = true;
    });

    bool hasInternet = await checkInternetConnection();

    if (!hasInternet) {
      setState(() {
        _hasInternet = false;
        _isCheckingInternet = false;
      });
      return;
    }

    // Si hay internet, cargar datos
    setState(() {
      _hasInternet = true;
      _isCheckingInternet = false;
    });

    // Reinicializar servicios que requieren internet
    try {
      // Reinicializar Firebase (por si falló en el arranque sin internet)
      if (!Firebase.apps.isNotEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        printLog.i('Firebase reinicializado');
      }

      // Reinicializar notificaciones
      await initNotifications();
      printLog.i('Notificaciones reinicializadas');

      // Reinicializar DeviceManager (carga dbData de DynamoDB)
      await DeviceManager.init();
      printLog.i('DeviceManager reinicializado');

      // Verificar actualizaciones de la app
      final upgrader = Upgrader(debugLogging: false);
      await upgrader.initialize();
      appVersionNumber = upgrader.currentInstalledVersion ?? appVersionNumber;
      printLog.i('Upgrader reinicializado');
    } catch (e) {
      printLog.e('Error reinicializando servicios: $e');
    }

    await loadValues();
    printLog.i('Valores cargados');
    await setupMqtt();
    listenToTopics();

    setState(() {
      _isInitialized = true;
    });
  }

  Future<void> _retryConnection() async {
    setState(() {
      _isCheckingInternet = true;
    });

    bool hasInternet = await checkInternetConnection();

    if (hasInternet) {
      setState(() {
        _hasInternet = true;
      });
      await _initializeApp();
    } else {
      setState(() {
        _isCheckingInternet = false;
        _hasInternet = false;
      });
    }
  }

  /// Construye la pantalla de sin internet
  Widget _buildNoInternetScreen() {
    return Scaffold(
      backgroundColor: color1,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(30.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icono de sin internet
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: color4.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    HugeIcons.strokeRoundedWifiOff02,
                    size: 80,
                    color: color3,
                  ),
                ),
                const SizedBox(height: 30),
                // Título
                Text(
                  'Sin conexión a Internet',
                  style: GoogleFonts.poppins(
                    color: color0,
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                // Descripción
                Text(
                  'Para usar la aplicación necesitas estar conectado a Internet.\n\nPor favor, activa los datos móviles o conéctate a una red WiFi.',
                  style: GoogleFonts.poppins(
                    color: color0.withValues(alpha: 0.8),
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                // Botón de reintentar
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      foregroundColor: color1,
                      backgroundColor: color0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 30,
                        vertical: 15,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    icon: const Icon(HugeIcons.strokeRoundedReload, size: 22),
                    label: Text(
                      'Reintentar',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onPressed: _retryConnection,
                  ),
                ),
                const SizedBox(height: 15),
                // Botón de configuración
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: color0,
                  ),
                  icon: const Icon(HugeIcons.strokeRoundedSettings02, size: 20),
                  label: Text(
                    'Abrir ajustes',
                    style: GoogleFonts.poppins(fontSize: 14),
                  ),
                  onPressed: () async {
                    await openAppSettings();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Si no hay internet, mostrar pantalla de sin conexión
    if (!_hasInternet && !_isCheckingInternet) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          textTheme: GoogleFonts.poppinsTextTheme(),
          colorScheme: ColorScheme.fromSeed(seedColor: color3),
          useMaterial3: true,
        ),
        home: _buildNoInternetScreen(),
      );
    }

    // Si está verificando o cargando, mostrar splash
    if (_isCheckingInternet || !_isInitialized) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          textTheme: GoogleFonts.poppinsTextTheme(),
          colorScheme: ColorScheme.fromSeed(seedColor: color3),
          useMaterial3: true,
        ),
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/branch/dragon.png',
                  width: 100,
                  height: 100,
                ),
              ],
            ),
          ),
        ),
      );
    }

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
        '/widget_config_selection': (context) => const SelectDeviceScreen(),
      },
    );
  }
}
