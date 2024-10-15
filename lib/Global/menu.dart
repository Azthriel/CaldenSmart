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

  void _onPageChanged(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _onItemTapped(int index) {
    _pageController.animateToPage(index,
        duration: const Duration(milliseconds: 300), curve: Curves.ease);
    setState(() {
      _selectedIndex = index;
    });
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
                        color: _selectedIndex == 0
                            ? const Color(0xFFE77272)
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
                            ? const Color(0xFFE77272)
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
              'assets/dragon.png',
              fit: BoxFit.contain,
              height: 40,
              width: 40,
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}