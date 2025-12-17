import 'package:caldensmart/Global/stored_data.dart';
import 'package:caldensmart/Global/watchers.dart';
import 'package:caldensmart/aws/dynamo/dynamo.dart';
import 'package:caldensmart/logger.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:hugeicons/hugeicons.dart';
import '/Global/scan.dart';
import '/Global/wifi.dart';
import 'package:google_fonts/google_fonts.dart';
import '../master.dart';

class MenuPage extends StatefulWidget {
  const MenuPage({super.key});

  @override
  State<MenuPage> createState() => MenuPageState();
}

class MenuPageState extends State<MenuPage> {
  PageController? _pageController;
  int _selectedIndex = 0;
  late Future<int> _initialPageFuture;
  bool _isLoading = true;
  static bool hasInitialized = false;

  @override
  void initState() {
    super.initState();
    _initialPageFuture = getInitialPageIndex();
    if (!hasInitialized) {
      hasInitialized = true;
      _loadInitialData();
    } else {
      // Si ya se inicializó anteriormente, no mostrar pantalla de carga
      printLog.i('Datos ya inicializados, evitando recarga', color: 'azul');
      _isLoading = false;
    }
  }

  void _setupTokenManagement() async {
    if (currentUserEmail.isNotEmpty) {
      printLog.i('Iniciando gestión de tokens ');
      await TokenManager.setupUserTokens();
    }

    // Listener para cambios de token

    _setupTokenRefreshListener();
  }

  void _setupTokenRefreshListener() {
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      printLog.i('Token de Firebase actualizado: $newToken');
      try {
        // El usuario ya está logueado cuando llega al MenuPage
        if (currentUserEmail.isNotEmpty) {
          String userEmail = currentUserEmail;

          // Obtener tokens actuales del usuario
          List<String> userTokens = await getTokensFromAlexaDevices(userEmail);

          // Añadir nuevo token si no existe
          if (!userTokens.contains(newToken)) {
            userTokens.add(newToken);
            await putTokensInAlexaDevices(userEmail, userTokens);
            printLog.i('Nuevo token actualizado en alexa-devices');
          }
        }
      } catch (e) {
        printLog.e('Error actualizando token: $e');
      }
    });
  }

  Future<int> getInitialPageIndex() async {
    final bleState = await FlutterBluePlus.adapterState.first;
    int index = bleState == BluetoothAdapterState.on ? 0 : 1;
    // printLog.i('Bluetooth state: $bleState, index: $index', color: 'verde');
    return index;
  }

  // Nueva función para cargar datos iniciales críticos
  Future<void> _loadInitialData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Verificar conexión a internet antes de intentar cargar datos
      bool hasInternet = await checkInternetConnection();

      while (!hasInternet) {
        if (!mounted) return;

        // Mostrar diálogo de sin internet y esperar respuesta
        bool retry = await showNoInternetDialog(context);

        if (retry) {
          hasInternet = true;
        } else {
          // El usuario presionó reintentar pero sigue sin internet
          hasInternet = await checkInternetConnection();
        }
      }

      currentUserEmail = await getUserMail();

      _setupTokenManagement();

      if (currentUserEmail.isNotEmpty) {
        await getDevices(currentUserEmail);
        eventosCreados = await getEventos(currentUserEmail);
        nicknamesMap = await getNicknames(currentUserEmail);
        savedOrder = await loadWifiOrderDevices(currentUserEmail);

        printLog.i(
            'Datos iniciales cargados - Dispositivos: ${previusConnections.length}');
        printLog.i('Eventos cargados: ${eventosCreados.length}');
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      printLog.e('Error cargando datos iniciales: $e');

      // Si hay error de conexión, mostrar el diálogo
      if (mounted) {
        bool hasInternet = await checkInternetConnection();
        if (!hasInternet && mounted) {
          bool retry = await showNoInternetDialog(context);
          if (retry) {
            // Reintentar la carga
            await _loadInitialData();
            return;
          }
        }
      }

      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _selectedIndex = index;
      lastPage = _selectedIndex;
    });
    saveLastPage(index);
  }

  void _onItemTapped(int index) {
    _pageController?.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.ease,
    );
    setState(() {
      _selectedIndex = index;
      lastPage = _selectedIndex;
    });
    saveLastPage(index);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: _initialPageFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Mostrar pantalla de carga hasta que los datos críticos estén listos
        if (_isLoading) {
          return Scaffold(
            backgroundColor: color0,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/branch/dragon.gif',
                      width: 150,
                      height: 150,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Se están cargando los datos de la app, aguarde un momento por favor...',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: color1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (_pageController == null) {
          _selectedIndex = snapshot.data!;
          _pageController = PageController(initialPage: _selectedIndex);
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (mounted) {
              checkForUpdate(context);
              fToast.init(navigatorKey.currentState?.context ?? context);
            }
          });
          LocationWatcher().start();
        }
        return Scaffold(
          backgroundColor: Colors.transparent,
          extendBody: true,
          resizeToAvoidBottomInset: false,
          body: Stack(
            children: [
              PageView(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                children: const [
                  ScanPage(),
                  WifiPage(),
                ],
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: MediaQuery.of(context).padding.bottom,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: SizedBox(
              height: 60.0,
              child: Stack(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {},
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(30.0),
                        topRight: Radius.circular(30.0),
                      ),
                      child: BottomAppBar(
                        color: color1,
                        shape: const CircularNotchedRectangle(),
                        notchMargin: 6.0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            const Spacer(flex: 1),
                            Padding(
                              padding: const EdgeInsets.only(top: 1.0),
                              child: IconButton(
                                iconSize: _selectedIndex == 0 ? 35.0 : 30.0,
                                icon: Icon(
                                  HugeIcons.strokeRoundedBluetoothSearch,
                                  color: _selectedIndex == 0
                                      ? color3
                                      : Colors.grey,
                                ),
                                onPressed: () => _onItemTapped(0),
                              ),
                            ),
                            const Spacer(flex: 6),
                            Padding(
                              padding: const EdgeInsets.only(top: 1.0),
                              child: IconButton(
                                iconSize: _selectedIndex == 1 ? 35.0 : 30.0,
                                icon: Icon(
                                  HugeIcons.strokeRoundedWifi02,
                                  color: _selectedIndex == 1
                                      ? color3
                                      : Colors.grey,
                                ),
                                onPressed: () => _onItemTapped(1),
                              ),
                            ),
                            const Spacer(flex: 1),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: PaintBottomAppBar(
                          borderColor: Colors.red,
                          width: 1.0,
                          radius: 30.0,
                          notchMargin: 6.0,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          floatingActionButton: Padding(
            padding: const EdgeInsets.only(bottom: 15.0),
            child: FloatingActionButton(
              onPressed: () {
                launchWebURL('https://caldensmart.com');
              },
              backgroundColor: color1,
              elevation: 0,
              shape: const CircleBorder(
                side: BorderSide(
                  color: color2,
                  width: 1.0,
                ),
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/DragonForeground.png',
                  fit: BoxFit.contain,
                  height: 140,
                  width: 140,
                ),
              ),
            ),
          ),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerDocked,
        );
      },
    );
  }
}
