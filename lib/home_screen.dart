import 'package:flutter/material.dart';
import 'widgets/liquid_glass_tabbar.dart';
import 'tabs/home_tab.dart';

// Per-tab gradient definitions
const List<List<Color>> _tabGradients = [
  [Color(0xFFFF6B6B), Color(0xFFFBE5E4)], // Home     – coral red
  [Color(0xFFA3FF91), Color(0xFFEFFEEC)], // Routine  – mint green
  [Color(0xFF78FDFF), Color(0xFFE8FEFE)], // Tracker  – cyan teal
  [Color(0xFFC084FC), Color(0xFFF5EEFF)], // Coach    – soft violet
  [Color(0xFFFF8CC2), Color(0xFFFCEDF3)], // Goals    – rose pink
  [Color(0xFFFFB830), Color(0xFFFFF6E0)], // Profile  – amber gold
];

const List<String> _tabLabels = [
  'Home', 'Routine', 'Tracker', 'Coach', 'Goals', 'Profile',
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final colors = _tabGradients[_currentIndex];

    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: colors,
            stops: const [0.0, 0.7],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: _currentIndex == 0
              ? const HomeTab()
              : Center(
                  child: Text(
                    '${_tabLabels[_currentIndex]} Screen',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
        ),
      ),
      bottomNavigationBar: LiquidGlassTabBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        activeColor: _tabGradients[_currentIndex][0],
      ),
    );
  }
}
