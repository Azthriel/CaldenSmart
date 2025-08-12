import 'package:caldensmart/Global/stored_data.dart';
import 'package:caldensmart/Global/watchers.dart';
import 'package:caldensmart/aws/dynamo/dynamo.dart';
import 'package:caldensmart/logger.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '/Global/scan.dart';
import '/Global/wifi.dart';
import 'package:hugeicons/hugeicons.dart';
import '../master.dart';

class MenuPage extends StatefulWidget {
  const MenuPage({super.key});

  @override
  State<MenuPage> createState() => MenuPageState();
}

class MenuPageState extends State<MenuPage> {
  PageController? _pageController;
  int _selectedIndex = 0;
  int counter = 0;
  late Future<int> _initialPageFuture;

  @override
  void initState() {
    super.initState();
    _initialPageFuture = getInitialPageIndex();
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
    printLog.i('Bluetooth state: $bleState, index: $index', color: 'verde');
    return 1;
  }

  Future<void> _initAsync() async {
    currentUserEmail = await getUserMail();
    _setupTokenManagement();
    if (currentUserEmail != '') {
      await getNicknames(currentUserEmail);
    }
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _pageController?.dispose();
    counter = 0;
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
        if (_pageController == null) {
          _selectedIndex = snapshot.data!;
          _pageController = PageController(initialPage: _selectedIndex);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              checkForUpdate(context);
              fToast.init(navigatorKey.currentState?.context ?? context);
            }
          });
          LocationWatcher().start();
          _initAsync();
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
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {},
              child: SizedBox(
                height: 60.0,
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(30.0),
                    topRight: Radius.circular(30.0),
                  ),
                  child: BottomAppBar(
                    color: color3,
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
                              color: _selectedIndex == 0 ? color5 : Colors.grey,
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
                              color: _selectedIndex == 1 ? color5 : Colors.grey,
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
            ),
          ),
          floatingActionButton: Padding(
            padding: const EdgeInsets.only(bottom: 15.0),
            child: FloatingActionButton(
              onPressed: () {
                if (counter < 10) {
                  counter++;
                } else {
                  navigatorKey.currentState?.pushNamed('/eg');
                }
              },
              backgroundColor: color3,
              elevation: 0,
              shape: const CircleBorder(),
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
