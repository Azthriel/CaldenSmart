import 'package:caldensmart/Global/stored_data.dart';
import 'package:caldensmart/Global/watchers.dart';
import 'package:caldensmart/aws/dynamo/dynamo.dart';
import 'package:flutter/material.dart';
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
  final PageController _pageController = PageController();
  int _selectedIndex = 0;
  int counter = 0;

  @override
  void initState() {
    super.initState();
    _selectedIndex = lastPage ?? 0;

    BluetoothWatcher().start();

    LocationWatcher().start();

    _initAsync();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pageController.jumpToPage(_selectedIndex);
      if (mounted) {
        checkForUpdate(context);
      }
    });

    if (mounted) {
      fToast.init(navigatorKey.currentState!.context);
    }
  }

  Future<void> _initAsync() async {
    currentUserEmail = await getUserMail();
    if (currentUserEmail != '') {
      await getDevices( currentUserEmail);
      await getNicknames( currentUserEmail);
      await getGroups( currentUserEmail);
      eventosCreados = await getEventos( currentUserEmail);
    }
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
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
    _pageController.animateToPage(
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
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      extendBody: true,
      resizeToAvoidBottomInset: false,
      body: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30.0),
          topRight: Radius.circular(30.0),
        ),
        child: PageView(
          controller: _pageController,
          onPageChanged: _onPageChanged,
          children: const [
            ScanPage(),
            WifiPage(),
          ],
        ),
      ),
      bottomNavigationBar: GestureDetector(
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
                        color: _selectedIndex == 0 ? color6 : Colors.grey,
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
                        color: _selectedIndex == 1 ? color6 : Colors.grey,
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
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}
