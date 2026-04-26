import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus2/core/liquid_ui/liquid_ui.dart';
import 'package:optivus2/providers/routine_provider.dart';

String _formatTimeFromStart(double hoursFrom6AM) {
  int totalMinutes = ((hoursFrom6AM + 6) * 60).round();
  int h = (totalMinutes ~/ 60) % 24;
  int m = totalMinutes % 60;
  String ampm = h < 12 ? 'AM' : 'PM';
  int displayH = h == 0 ? 12 : (h > 12 ? h - 12 : h);
  String displayM = m.toString().padLeft(2, '0');
  return "$displayH:$displayM $ampm";
}

class EatingRoutineBlock {
  final String id;
  String mealName;
  String foodName;
  double start; // For vertical position (hours from 6 AM)
  double duration;
  IconData? icon;
  String emoji;
  Color? color;

  bool isAdd;
  bool hasTopTape;
  bool hasBottomTape;

  String get displayStartTime => _formatTimeFromStart(start);
  String get displayEndTime => _formatTimeFromStart(start + duration);

  EatingRoutineBlock({
    required this.id,
    required this.mealName,
    this.foodName = '',
    required this.start,
    this.duration = 1.0,
    this.icon,
    this.emoji = '🍽️',
    this.color,
    this.isAdd = false,
    this.hasTopTape = false,
    this.hasBottomTape = false,
  });
}

class EatingSetupScreen extends ConsumerStatefulWidget {
  final VoidCallback onComplete;
  const EatingSetupScreen({super.key, required this.onComplete});

  @override
  ConsumerState<EatingSetupScreen> createState() => _EatingSetupScreenState();
}

class _EatingSetupScreenState extends ConsumerState<EatingSetupScreen> {
  int _day = 0; // 0 for Mon, 6 for Sun
  late Map<int, List<EatingRoutineBlock>> weeklyRoutines;

  final double kHourHeight = 84.0;
  final double kLeftOffset = 64.0;

  final List<Color> _cycleColors = [
    const Color(0xFFFFB830), // Yellow
    const Color(0xFF60D4A0), // Green
    const Color(0xFFFF9560), // Orange
    const Color(0xFF9B8FFF), // Purple
    const Color(0xFFF43F5E), // Rose
  ];
  int _colorIndex = 0;

  @override
  void initState() {
    super.initState();
    weeklyRoutines = {};
    for (int i = 0; i < 7; i++) {
      weeklyRoutines[i] = [
        EatingRoutineBlock(
          id: 'breakfast_$i',
          mealName: 'Breakfast',
          foodName: 'Oatmeal & Berries',
          start: 2.0, // 8:00 AM (6 AM + 2 hrs)
          duration: 1.0,
          emoji: '🥣',
          color: const Color(0xFFFFB830),
          hasTopTape: true,
          hasBottomTape: true,
        ),
        EatingRoutineBlock(
          id: 'add1_$i',
          mealName: '',
          start: 5.0, // 11:00 AM
          isAdd: true,
        ),
        EatingRoutineBlock(
          id: 'lunch_$i',
          mealName: 'Lunch',
          foodName: 'Grilled Chicken Salad',
          start: 7.0, // 1:00 PM
          duration: 1.0,
          emoji: '🥗',
          color: const Color(0xFF60D4A0),
          hasTopTape: true,
          hasBottomTape: true,
        ),
        EatingRoutineBlock(
          id: 'add2_$i',
          mealName: '',
          start: 9.5, // 3:30 PM
          isAdd: true,
        ),
        EatingRoutineBlock(
          id: 'snack_$i',
          mealName: 'Snack',
          foodName: 'Green Apple & Walnuts',
          start: 11.0, // 5:00 PM
          duration: 0.5,
          emoji: '🍎',
          color: const Color(0xFFFF9560),
          hasTopTape: true,
          hasBottomTape: true,
        ),
        EatingRoutineBlock(
          id: 'add3_$i',
          mealName: '',
          start: 13.0, // 7:00 PM
          isAdd: true,
        ),
        EatingRoutineBlock(
          id: 'dinner_$i',
          mealName: 'Dinner',
          foodName: 'Salmon with Asparagus',
          start: 14.5, // 8:30 PM
          duration: 1.0,
          emoji: '🍣',
          color: const Color(0xFF9B8FFF),
          hasTopTape: true,
          hasBottomTape: true,
        ),
      ];
    }
  }

  List<EatingRoutineBlock> get items => weeklyRoutines[_day]!;

  void _onTopTapeDrag(int index, DragUpdateDetails details) {
    setState(() {
      double deltaHours = details.delta.dy / kHourHeight;
      if (items[index].duration - deltaHours < 0.6) {
        deltaHours = items[index].duration - 0.6; // minimum height
      }
      if (items[index].start + deltaHours < 0) {
        deltaHours = -items[index].start;
      }
      items[index].start += deltaHours;
      items[index].duration -= deltaHours;
    });
  }

  void _onBottomTapeDrag(int index, DragUpdateDetails details) {
    setState(() {
      double deltaHours = details.delta.dy / kHourHeight;
      if (items[index].duration + deltaHours < 0.6) {
        deltaHours = 0.6 - items[index].duration;
      }
      if (items[index].start + items[index].duration + deltaHours > 24) {
        deltaHours = 24 - (items[index].start + items[index].duration);
      }
      items[index].duration += deltaHours;
    });
  }

  double _parseHoursFrom6AM(String timeStr) {
    try {
      timeStr = timeStr.trim().toUpperCase();
      bool isPM = timeStr.contains('PM');
      String cleaned = timeStr.replaceAll('AM', '').replaceAll('PM', '').trim();
      List<String> parts = cleaned.split(':');
      if (parts.isEmpty) return 0.0;
      int h = int.parse(parts[0]);
      int m = parts.length > 1 ? int.parse(parts[1]) : 0;
      
      if (isPM && h != 12) h += 12;
      if (!isPM && h == 12) h = 0;
      
      double hoursFromMidnight = h + (m / 60.0);
      double from6AM = hoursFromMidnight - 6;
      if (from6AM < 0) from6AM += 24; 
      return from6AM;
    } catch (e) {
      return 0.0;
    }
  }

  Future<void> _showEditDialog(int index) async {
    final item = items[index];

    TextEditingController nameCtrl = TextEditingController(text: item.mealName);
    TextEditingController foodCtrl = TextEditingController(text: item.foodName);
    TextEditingController emojiCtrl = TextEditingController(text: item.emoji);
    TextEditingController startTimeCtrl = TextEditingController(text: item.displayStartTime);
    TextEditingController endTimeCtrl = TextEditingController(text: item.displayEndTime);

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white.withValues(alpha: 0.95),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Text(item.isAdd ? 'Add Meal' : 'Edit Meal Details', style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF0F111A))),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          SizedBox(
                            width: 60,
                            child: TextField(
                              controller: emojiCtrl,
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                              textAlign: TextAlign.center,
                              decoration: InputDecoration(
                                labelText: 'Icon',
                                filled: true,
                                fillColor: const Color(0xFFF1F5F9),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: nameCtrl,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                              decoration: InputDecoration(
                                labelText: 'Meal Name (e.g. Lunch)',
                                filled: true,
                                fillColor: const Color(0xFFF1F5F9),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: foodCtrl,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          labelText: 'Food Detail (e.g. Grilled Chicken Salad)',
                          filled: true,
                          fillColor: const Color(0xFFF1F5F9),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: startTimeCtrl,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                              decoration: InputDecoration(
                                labelText: 'Start (e.g. 1:00 PM)',
                                filled: true,
                                fillColor: const Color(0xFFF1F5F9),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: endTimeCtrl,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                              decoration: InputDecoration(
                                labelText: 'End (e.g. 2:00 PM)',
                                filled: true,
                                fillColor: const Color(0xFFF1F5F9),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                if (!item.isAdd)
                  TextButton(
                    onPressed: () {
                      setState(() {
                         items.removeAt(index);
                      });
                      Navigator.pop(ctx);
                    },
                    child: const Text('Delete', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
                  ),
                if (!item.isAdd) const Spacer(),
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F111A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    setState(() {
                      item.mealName = nameCtrl.text.isEmpty ? 'New Meal' : nameCtrl.text;
                      item.foodName = foodCtrl.text;
                      item.emoji = emojiCtrl.text.isEmpty ? '🍽️' : emojiCtrl.text;
                      
                      double parsedStart = _parseHoursFrom6AM(startTimeCtrl.text);
                      double parsedEnd = _parseHoursFrom6AM(endTimeCtrl.text);
                      if (parsedEnd <= parsedStart && parsedEnd != 0.0) parsedEnd += 24;
                      item.start = parsedStart;
                      item.duration = parsedEnd - parsedStart > 0.5 ? parsedEnd - parsedStart : 0.5;

                      if (item.isAdd) {
                        item.isAdd = false;
                        item.hasTopTape = true;
                        item.hasBottomTape = true;
                        item.duration = 1.0; 
                        item.color = _cycleColors[_colorIndex % _cycleColors.length];
                        _colorIndex++;
                        // Insert an Add button below this block
                        items.insert(index + 1, EatingRoutineBlock(
                           id: 'add_${DateTime.now().millisecondsSinceEpoch}',
                           mealName: '',
                           start: item.start + item.duration + 0.5,
                           isAdd: true,
                        ));
                      }
                    });
                    Navigator.pop(ctx);
                  }, 
                  child: const Text('Save')
                ),
              ]
            );
          }
        );
      }
    );
  }

  Widget _buildDroplet(double size, {Color color = Colors.white, String text = '', bool isActive = false}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutBack,
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive ? color.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.25),
        border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: isActive ? color.withValues(alpha: 0.2) : const Color(0x0F000000), 
            blurRadius: 8, 
            offset: const Offset(0, 4)
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            right: size * 0.15, bottom: size * 0.05,
            width: size * 0.7, height: size * 0.45,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(size),
                boxShadow: [BoxShadow(color: Colors.white.withValues(alpha: 0.4), blurRadius: 6)],
              ),
            ),
          ),
          Positioned(
            top: size * 0.08, left: size * 0.18,
            width: size * 0.35, height: size * 0.15,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(size),
                boxShadow: [BoxShadow(color: Colors.white.withValues(alpha: 0.6), blurRadius: 4)],
              ),
            ),
          ),
          Material(
            type: MaterialType.transparency,
            child: Text(
              text,
              style: TextStyle(
                fontSize: isActive ? 12 : 11,
                fontWeight: FontWeight.w900,
                color: isActive ? color : const Color(0xFF64748B),
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTapeWithDrops({GestureDragUpdateCallback? onDrag}) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeUpDown,
      child: GestureDetector(
        onVerticalDragUpdate: onDrag,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Container(
              width: 56, height: 16,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withValues(alpha: 0.95), width: 1.5),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4, offset: const Offset(0, 3)),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(),
                ),
              ),
            ),
            Positioned(right: -6, bottom: -4, child: _buildDroplet(14)),
            Positioned(right: 4, top: -2, child: _buildDroplet(8)),
            Positioned(left: 8, top: -5, child: _buildDroplet(10)),
            Positioned(left: -4, bottom: 2, child: _buildDroplet(6)),
          ],
        ),
      ),
    );
  }

  Widget _buildColoredBlock(int index, EatingRoutineBlock item) {
    final top = item.start * kHourHeight;
    final height = item.duration * kHourHeight;

    return Positioned(
      top: top, left: kLeftOffset, right: 0, height: height,
      child: GestureDetector(
        onTap: () => _showEditDialog(index),
        onLongPress: () => _showEditDialog(index),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [item.color!.withValues(alpha: 0.3), item.color!.withValues(alpha: 0.05)],
                  ),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 1.5),
                  boxShadow: [
                    BoxShadow(color: item.color!.withValues(alpha: 0.15), blurRadius: 16, offset: const Offset(0, 6)),
                    BoxShadow(color: Colors.white.withValues(alpha: 0.9), blurRadius: 12, offset: const Offset(-4, -4)),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Text(item.emoji, style: const TextStyle(fontSize: 24)),
                                const SizedBox(width: 8),
                                Expanded(child: Text(item.mealName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F111A)))),
                                const Icon(Icons.more_vert_rounded, color: Color(0xFF64748B), size: 18),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 1),
                                  ),
                                  child: Text('${item.displayStartTime} - ${item.displayEndTime}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
                                ),
                                if (item.foodName.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.45),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 1),
                                    ),
                                    child: Text(item.foodName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (item.hasTopTape) 
              Positioned(
                top: -8, left: 0, right: 0, 
                child: Center(child: _buildTapeWithDrops(onDrag: (d) => _onTopTapeDrag(index, d)))
              ),
            if (item.hasBottomTape) 
              Positioned(
                bottom: -8, left: 0, right: 0, 
                child: Center(child: _buildTapeWithDrops(onDrag: (d) => _onBottomTapeDrag(index, d)))
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton(int index, EatingRoutineBlock item) {
    final height = 40.0;
    final top = item.start * kHourHeight - height / 2;
    return Positioned(
      top: top, left: kLeftOffset, right: 0, height: height,
      child: GestureDetector(
        onTap: () => _showEditDialog(index),
        child: Align(
          alignment: Alignment.center,
          child: Container(
            width: 60,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(height / 2),
              border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 1.5),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 3))]
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(height / 2),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      top: 0, left: 0, right: 0, height: 8,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter, end: Alignment.bottomCenter,
                            colors: [Colors.black.withValues(alpha: 0.05), Colors.transparent],
                          ),
                        ),
                      ),
                    ),
                    const Center(child: Icon(Icons.add_rounded, color: Color(0xFF94A3B8), size: 28)),
                    Positioned(left: -4, top: 4, child: _buildDroplet(8)),
                    Positioned(right: -2, bottom: -2, child: _buildDroplet(12)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _save(WidgetRef ref) {
    final notifier = ref.read(routineProvider.notifier);
    for (int d = 0; d < 7; d++) {
      final itemsForDay = weeklyRoutines[d] ?? [];
      final meals = <MealItem>[];
      for (final item in itemsForDay) {
        if (!item.isAdd) {
          meals.add(MealItem(
            emoji: item.emoji,
            name: item.foodName.isNotEmpty ? item.foodName : item.mealName,
            time: item.displayStartTime,
          ));
        }
      }
      notifier.setMealPlan(d, DayMealPlan(meals: meals));
    }
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    const headerColors = [
      Color(0xFFFFD480),
      Color(0xFFFFA64D),
      Color(0xFFFF8080),
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LiquidBg(
        child: Stack(
          children: [
            SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        LiquidIconBtn(
                          icon: Icons.arrow_back_ios_new_rounded,
                          size: 44,
                          onTap: () => Navigator.pop(context),
                        ),
                        const Text(
                          'EATING SETUP',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: kSub,
                            letterSpacing: 1.5,
                          ),
                        ),
                        LiquidIconBtn(
                          icon: Icons.check_rounded,
                          size: 44,
                          onTap: () {
                            _save(ref);
                            Navigator.pop(context);
                          },
                        ), 
                      ],
                    ),
                  ),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(7, (i) {
                    final isSel = i == _day;
                    const days = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"];
                    return GestureDetector(
                      onTap: () => setState(() => _day = i),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2.0),
                        child: _buildDroplet(
                          isSel ? 44 : 36, 
                          color: const Color(0xFFFF9560),
                          text: days[i],
                          isActive: isSel,
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 20),
                
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    width: double.infinity,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 1.5),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 2))],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Row(
                              children: headerColors.map((color) => Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.centerLeft, end: Alignment.centerRight,
                                      colors: [color.withValues(alpha: 0.1), color.withValues(alpha: 0.35), color.withValues(alpha: 0.1)],
                                    )
                                  ),
                                )
                              )).toList(),
                            ),
                          ),
                          BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                            child: const Center(
                              child: Text(
                                'Set Your Daily Eating Routine',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.2),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.4),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 1.5),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 12, offset: const Offset(0, -4)),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.fromLTRB(24, 28, 24, 16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Your Fixed Meals.', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF1E293B), letterSpacing: -0.5)),
                                    SizedBox(height: 6),
                                    Text('Maintain a healthy metabolism with regular eating times.', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                                  ],
                                ),
                              ),
                              
                              Expanded(
                                child: ShaderMask(
                                  shaderCallback: (Rect bounds) {
                                    return const LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [Colors.transparent, Colors.white, Colors.white, Colors.transparent],
                                      stops: [0.0, 0.05, 0.9, 1.0],
                                    ).createShader(bounds);
                                  },
                                  blendMode: BlendMode.dstIn,
                                  child: SingleChildScrollView(
                                    physics: const BouncingScrollPhysics(),
                                    padding: const EdgeInsets.only(bottom: 120),
                                    child: SizedBox(
                                      height: 24 * kHourHeight,
                                      child: Stack(
                                        clipBehavior: Clip.none,
                                      children: [
                                        Positioned(
                                          top: 0, bottom: 0, left: 48, width: 8,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: Colors.white.withValues(alpha: 0.35),
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 1.2),
                                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(2, 2))],
                                            ),
                                          ),
                                        ),
                                        
                                        ...List.generate(24, (i) {
                                          final hour = (i + 6) % 24;
                                          final ampm = hour < 12 ? 'AM' : 'PM';
                                          final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
                                          final label = "$displayHour $ampm";
                                          return Positioned(
                                            top: i * kHourHeight - 10, left: 0, width: 44,
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.end,
                                              children: [
                                                Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                                                const SizedBox(width: 6),
                                                Container(width: 4, height: 1.5, color: const Color(0xFFCBD5E1)),
                                              ],
                                            ),
                                          );
                                        }),
                                        
                                        ...items.asMap().entries.map((entry) {
                                          int idx = entry.key;
                                          EatingRoutineBlock item = entry.value;
                                          if (item.isAdd) {
                                            return _buildAddButton(idx, item);
                                          } else {
                                            return _buildColoredBlock(idx, item);
                                          }
                                        }),
                                      ],
                                    ),
                                  ),
                                ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          ]
        ),
      ),
    );
  }
}
