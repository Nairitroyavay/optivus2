// lib/Routine Screen/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'liquid_kit.dart';
import 'routine_tab_v2.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  int _idx = 0;
  late final AnimationController _bgCtrl;
  late final Animation<Color?> _bgAnim;

  static const _gradients = [
    [Color(0xFFFF6B6B), Color(0xFFFCF8EE)],
    [Color(0xFFA3FF91), Color(0xFFFCF8EE)],
    [Color(0xFF78FDFF), Color(0xFFFCF8EE)],
    [Color(0xFFC084FC), Color(0xFFFCF8EE)],
    [Color(0xFFFF8CC2), Color(0xFFFCF8EE)],
    [Color(0xFFFFB830), Color(0xFFFCF8EE)],
  ];

  @override
  void initState() {
    super.initState();
    _bgCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 400));
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent));
  }

  @override void dispose() { _bgCtrl.dispose(); super.dispose(); }

  Widget _tabBody() {
    switch (_idx) {
      case 0: return const Center(child: Text('Home'));  // wire your HomeTab here
      case 1: return const RoutineTab();
      default: return Center(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_tabEmoji(_idx), style: const TextStyle(fontSize: 52)),
          const SizedBox(height: 16),
          Text(_tabLabel(_idx),
              style: const TextStyle(fontSize: 22,
                  fontWeight: FontWeight.w900, color: kInk)),
          const SizedBox(height: 8),
          Text('Coming soon', style: TextStyle(fontSize: 15, color: kSub)),
        ],
      ));
    }
  }

  static String _tabEmoji(int i) => ['🏠','🗓️','📊','🤖','🎯','👤'][i];
  static String _tabLabel(int i) =>
      ['Home','Routine','Tracker','Coach','Goals','Profile'][i];

  @override
  Widget build(BuildContext context) {
    final topColor  = _gradients[_idx][0];
    final botColor  = _gradients[_idx][1];

    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [topColor, botColor],
            stops: const [0.0, 0.65],
          ),
        ),
        child: _tabBody(),
      ),
      bottomNavigationBar: LiquidTabBar(
        currentIndex: _idx,
        onTap: (i) => setState(() => _idx = i),
      ),
    );
  }
}
