import 'package:flutter/material.dart';
import 'package:optivus2/widgets/liquid_glass_tabbar.dart';
import 'package:optivus2/views/tabs/home_tab.dart';
import 'package:optivus2/views/routine/routine_tab.dart' as rt;
import 'package:optivus2/providers/routine_provider.dart';
import 'package:optivus2/views/tabs/tracker_tab.dart';
import 'package:optivus2/views/tabs/coach_tab.dart';
import 'package:optivus2/views/tabs/goals_tab.dart';
import 'package:optivus2/views/tabs/profile_tab.dart';
import 'package:optivus2/views/habits/log_habit_sheet.dart';

// Per-tab gradient definitions
const List<List<Color>> _tabGradients = [
  [Color(0xFFFF6B6B), Color(0xFFFBE5E4)], // Home     – coral red
  [Color(0xFFA3FF91), Color(0xFFEFFEEC)], // Routine  – mint green
  [Color(0xFF78FDFF), Color(0xFFE8FEFE)], // Tracker  – cyan teal
  [Color(0xFFC084FC), Color(0xFFF5EEFF)], // Coach    – soft violet
  [Color(0xFFFF8CC2), Color(0xFFFCEDF3)], // Goals    – rose pink
  [Color(0xFFFFB830), Color(0xFFFFF6E0)], // Profile  – amber gold
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  RoutineFilter _routineFilter = RoutineFilter.all;

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
          child: switch (_currentIndex) {
            0 => HomeTab(
                  onSkinCareTapped: () {
                    setState(() {
                      _currentIndex = 1;
                      _routineFilter = RoutineFilter.skinCare;
                    });
                  },
                  onClassesTapped: () {
                    setState(() {
                      _currentIndex = 1;
                      _routineFilter = RoutineFilter.classes;
                    });
                  },
                  onEatingTapped: () {
                    setState(() {
                      _currentIndex = 1;
                      _routineFilter = RoutineFilter.eating;
                    });
                  },
                ),
            1 => rt.RoutineTab(initialFilter: _routineFilter),
            2 => const TrackerTab(),
            3 => const CoachTab(),
            4 => const GoalsTab(),
            _ => const ProfileTab(),
          },
        ),
      ),
      floatingActionButton: _currentIndex == 0 ? FloatingActionButton(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => const LogHabitSheet(),
          );
        },
        backgroundColor: const Color(0xFF0F111A),
        foregroundColor: Colors.white,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add_rounded, size: 32),
      ) : null,
      bottomNavigationBar: LiquidGlassTabBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
            if (index == 1) {
              _routineFilter = RoutineFilter.all; // Normal tab bar tap resets filter
            }
          });
        },
        activeColor: _tabGradients[_currentIndex][0],
      ),
    );
  }
}
