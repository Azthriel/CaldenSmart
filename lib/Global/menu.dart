import 'package:hugeicons/hugeicons.dart';

import '/Global/scan.dart';
import '/Global/wifi.dart';
import 'package:flutter/material.dart';

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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: color1,
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        children: const [
          ScanPage(),
          WifiPage(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (counter < 10) {
            counter++;
          } else {
            navigatorKey.currentState?.pushNamed('/eg');
          }
        },
        backgroundColor: color3,
        elevation: 5,
        shape: const CircleBorder(),
        child: Image.asset(
          'assets/dragon.png',
          fit: BoxFit.contain,
          height: 40,
          width: 40,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 10.0,
        color: color3,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            const Spacer(),
            IconButton(
              iconSize: 40.0,
              icon: Container(
                height: 60.0,
                width: 60.0,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _selectedIndex == 0 ? color5 : Colors.transparent,
                ),
                child: Center(
                  child: Icon(
                    HugeIcons.strokeRoundedBluetoothSearch,
                    size: _selectedIndex == 0 ? 35.0 : 30.0,
                    color: color0,
                  ),
                ),
              ),
              onPressed: () => _onItemTapped(0),
            ),
            const Spacer(flex: 6),
            IconButton(
              iconSize: 40.0,
              icon: Container(
                height: 60.0,
                width: 60.0,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _selectedIndex == 1 ? color5 : Colors.transparent,
                ),
                child: Center(
                  child: Icon(
                    HugeIcons.strokeRoundedWifi02,
                    size: _selectedIndex == 1 ? 35.0 : 30.0,
                    color: color0,
                  ),
                ),
              ),
              onPressed: () => _onItemTapped(1),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
