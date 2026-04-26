import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus2/core/liquid_ui/liquid_ui.dart';
import 'package:optivus2/providers/routine_provider.dart';

// Use same schedule item as OnboardingPage8, but local to this file to map to FixedBlock.
class SetupBlockItem {
  final String id;
  String title;
  double start; // 0 to 24 hours
  double duration;
  IconData? icon;
  Color? color;
  bool isAdd;
  bool isMini;
  bool hasTopTape;
  bool hasBottomTape;

  String get displayStartTime => _formatTime(start);
  String get displayEndTime => _formatTime(start + duration);

  SetupBlockItem({
    required this.id,
    required this.title,
    required this.start,
    this.duration = 1.0,
    this.icon,
    this.color,
    this.isAdd = false,
    this.isMini = false,
    this.hasTopTape = false,
    this.hasBottomTape = false,
  });

  static String _formatTime(double hour) {
    int h = hour.floor();
    int m = ((hour - h) * 60).round();
    String ampm = h >= 12 ? 'PM' : 'AM';
    int displayH = h % 12;
    if (displayH == 0) displayH = 12;
    String minStr = m.toString().padLeft(2, '0');
    return '$displayH:$minStr $ampm';
  }

  FixedBlock toFixedBlock() {
    int startMinute = (start * 60).round();
    int endMinute = ((start + duration) * 60).round();
    String colorHex = '#${(color ?? Colors.blue).toARGB32().toRadixString(16).substring(2).toUpperCase()}';
    // Mapping IconData to emoji heuristically for FixedBlock
    String emoji = '📅';
    if (icon == Icons.bed_rounded) emoji = '🛏️';
    if (icon == Icons.school_rounded) emoji = '🎓';
    if (icon == Icons.work_rounded) emoji = '💼';
    if (icon == Icons.fitness_center_rounded) emoji = '💪';
    
    return FixedBlock(
      id: id,
      title: title,
      emoji: emoji,
      startMinute: startMinute,
      endMinute: endMinute,
      colorHex: colorHex,
    );
  }

  factory SetupBlockItem.fromFixedBlock(FixedBlock b) {
    double startHr = b.startMinute / 60.0;
    double endHr = b.endMinute / 60.0;
    if (endHr <= startHr) endHr += 24.0;
    double dur = endHr - startHr;
    
    IconData ic = Icons.star_rounded;
    if (b.emoji == '🛏️') ic = Icons.bed_rounded;
    if (b.emoji == '🎓') ic = Icons.school_rounded;
    if (b.emoji == '💼') ic = Icons.work_rounded;
    if (b.emoji == '💪') ic = Icons.fitness_center_rounded;
    
    // Check for mini
    bool min = dur <= 1.0; 

    // Has tape if duration allows resizing visually
    bool tape = !min;

    return SetupBlockItem(
      id: b.id,
      title: b.title,
      start: startHr,
      duration: dur,
      icon: ic,
      color: Color(int.parse(b.colorHex.replaceAll('#', '0xFF'))),
      hasTopTape: tape,
      hasBottomTape: tape,
      isMini: min,
    );
  }
}

class FixedScheduleSetupScreen extends ConsumerStatefulWidget {
  final VoidCallback onComplete;
  const FixedScheduleSetupScreen({super.key, required this.onComplete});

  @override
  ConsumerState<FixedScheduleSetupScreen> createState() => _FixedScheduleSetupScreenState();
}

class _FixedScheduleSetupScreenState extends ConsumerState<FixedScheduleSetupScreen> {
  final double kHourHeight = 60.0;
  final double kLeftOffset = 64.0;

  final List<Color> _cycleColors = [
    const Color(0xFFF43F5E), // Rose
    const Color(0xFF14B8A6), // Teal
    const Color(0xFF8B5CF6), // Purple
    const Color(0xFF3B82F6), // Blue
    const Color(0xFFF59E0B), // Orange
    const Color(0xFF10B981), // Green
  ];
  int _colorIndex = 0;

  List<SetupBlockItem> items = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(routineProvider);
      
      setState(() {
        if (state.fixedBlocks.isNotEmpty) {
          items = state.fixedBlocks.map((b) => SetupBlockItem.fromFixedBlock(b)).toList();
        } else {
          // Default placeholders if totally empty (fallback, onboarding usually populates this)
          items = [
            SetupBlockItem(id: 'sleep', title: 'Sleep', start: 0, duration: 6.5, icon: Icons.bed_rounded, color: const Color(0xFF8B5CF6), hasTopTape: true, hasBottomTape: true),
            SetupBlockItem(id: 'add1', title: '', start: 7.5, isAdd: true),
            SetupBlockItem(id: 'classes', title: 'Classes', start: 9, duration: 3, icon: Icons.school_rounded, color: const Color(0xFF3B82F6), hasTopTape: true, hasBottomTape: true),
            SetupBlockItem(id: 'work', title: 'Work', start: 13, duration: 4, icon: Icons.work_rounded, color: const Color(0xFFF59E0B), hasTopTape: true, hasBottomTape: true),
          ];
        }
      });
    });
  }

  void _saveToProvider() {
    // Only save concrete blocks, filter out 'add' buttons
    final blocks = items.where((i) => !i.isAdd).map((i) => i.toFixedBlock()).toList();
    ref.read(routineProvider.notifier).setFixedBlocks(blocks);
  }

  void _onTopTapeDrag(int index, DragUpdateDetails details) {
    setState(() {
      double deltaHours = details.delta.dy / kHourHeight;
      if (items[index].duration - deltaHours < 0.25) {
        deltaHours = items[index].duration - 0.25; 
      }
      if (items[index].start + deltaHours < 0) {
        deltaHours = -items[index].start;
      }
      items[index].start += deltaHours;
      items[index].duration -= deltaHours;
    });
    _saveToProvider();
  }

  void _onBottomTapeDrag(int index, DragUpdateDetails details) {
    setState(() {
      double deltaHours = details.delta.dy / kHourHeight;
      if (items[index].duration + deltaHours < 0.25) {
        deltaHours = 0.25 - items[index].duration;
      }
      if (items[index].start + items[index].duration + deltaHours > 24) {
        deltaHours = 24 - (items[index].start + items[index].duration);
      }
      items[index].duration += deltaHours;
    });
    _saveToProvider();
  }

  Future<void> _showEditDialog(int index) async {
    final item = items[index];

    TextEditingController nameCtrl = TextEditingController(text: item.title);
    
    double tempStart = item.start;
    double tempDuration = item.isAdd ? 1.5 : item.duration;
    
    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final startH = tempStart.floor();
            final startM = ((tempStart - startH) * 60).round();
            final startTime = TimeOfDay(hour: startH, minute: startM);

            final endDouble = tempStart + tempDuration;
            int endH = endDouble.floor();
            int endM = ((endDouble - endH) * 60).round();
            if (endH >= 24) { endH = 23; endM = 59; }
            final endTime = TimeOfDay(hour: endH, minute: endM);

            return AlertDialog(
              backgroundColor: Colors.white.withValues(alpha: 0.95),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(item.isAdd ? 'Add New Block' : 'Edit Block Details', style: const TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Block Name (e.g. Work)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Start Time:'),
                      TextButton(
                        onPressed: () async {
                          final picked = await showTimePicker(
                            context: ctx,
                            initialTime: startTime,
                          );
                          if (picked != null) {
                            setDialogState(() {
                              double nStart = picked.hour + picked.minute / 60.0;
                              double currentEnd = tempStart + tempDuration;
                              tempStart = nStart;
                              if (currentEnd <= tempStart) currentEnd = tempStart + 0.5;
                              tempDuration = currentEnd - tempStart;
                            });
                          }
                        },
                        child: Text(startTime.format(ctx), style: const TextStyle(fontWeight: FontWeight.bold)),
                      )
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('End Time:'),
                      TextButton(
                        onPressed: () async {
                          final picked = await showTimePicker(
                            context: ctx,
                            initialTime: endTime,
                          );
                          if (picked != null) {
                            setDialogState(() {
                              double nEnd = picked.hour + picked.minute / 60.0;
                              if (nEnd <= tempStart) nEnd += 24.0;
                              if (nEnd > 24) nEnd = 24.0;
                              tempDuration = nEnd - tempStart;
                            });
                          }
                        },
                        child: Text(endTime.format(ctx), style: const TextStyle(fontWeight: FontWeight.bold)),
                      )
                    ],
                  ),
                ],
              ),
              actions: [
                if (!item.isAdd)
                  TextButton(
                    onPressed: () {
                      setState(() {
                         items.removeAt(index);
                      });
                      _saveToProvider();
                      Navigator.pop(ctx);
                    },
                    child: const Text('Delete', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
                  ),
                if (!item.isAdd) const Spacer(),
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      item.title = nameCtrl.text.isEmpty ? 'New Block' : nameCtrl.text;
                      item.start = tempStart;
                      item.duration = tempDuration;
                      if (item.isAdd) {
                        item.isAdd = false;
                        item.hasTopTape = true;
                        item.hasBottomTape = true;
                        item.icon = Icons.star_rounded;
                        item.color = _cycleColors[_colorIndex % _cycleColors.length];
                        _colorIndex++;
                        
                        items.insert(index + 1, SetupBlockItem(
                           id: 'add_${DateTime.now().millisecondsSinceEpoch}',
                           title: '',
                           start: item.start + item.duration + 0.5,
                           isAdd: true,
                        ));
                      }
                      
                      // auto mini if duration <= 1
                      item.isMini = item.duration <= 1.0;
                      item.hasTopTape = !item.isMini;
                      item.hasBottomTape = !item.isMini;
                    });
                    _saveToProvider();
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
    // Custom 3D liquid bubble
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
          if (text.isNotEmpty)
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

  Widget _buildColoredBlock(int index, SetupBlockItem item) {
    final top = item.start * kHourHeight;
    final height = item.duration * kHourHeight;

    String timeText = '${item.displayStartTime} - ${item.displayEndTime}';

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
                  border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 1.5),
                  boxShadow: [
                    BoxShadow(color: item.color!.withValues(alpha: 0.2), blurRadius: 16, offset: const Offset(0, 6)),
                    BoxShadow(color: Colors.white.withValues(alpha: 0.7), blurRadius: 8, offset: const Offset(-2, -2)),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                if (item.icon != null) ...[
                                  Icon(item.icon, color: item.color!.withValues(alpha: 0.9), size: 24),
                                  const SizedBox(width: 8),
                                ],
                                Expanded(child: Text(item.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)))),
                                const Icon(Icons.more_vert_rounded, color: Color(0xFF64748B), size: 20),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Container(
                              height: 32,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 1),
                              ),
                              child: Stack(
                                children: [
                                  Positioned(
                                    top: 0, left: 0, right: 0, height: 6,
                                    child: ClipRRect(
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter, end: Alignment.bottomCenter,
                                            colors: [Colors.black.withValues(alpha: 0.06), Colors.transparent],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Center(
                                    child: Text(timeText, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                                  ),
                                ],
                              ),
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

  Widget _buildMiniBlock(int index, SetupBlockItem item) {
    final top = item.start * kHourHeight + 4;
    final height = kHourHeight - 8;
    return Positioned(
      top: top, left: kLeftOffset, right: 0, height: height,
      child: GestureDetector(
        onTap: () => _showEditDialog(index),
        onLongPress: () => _showEditDialog(index),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(height / 2),
            border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 1.5),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2)),
              BoxShadow(color: Colors.white.withValues(alpha: 0.6), blurRadius: 4, offset: const Offset(-1, -1)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(height / 2),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(item.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
                    const Icon(Icons.more_vert_rounded, color: Color(0xFF94A3B8), size: 18),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddButton(int index, SetupBlockItem item) {
    final height = 36.0;
    final top = item.start * kHourHeight - height / 2;
    return Positioned(
      top: top, left: kLeftOffset, right: 0, height: height,
      child: GestureDetector(
        onTap: () => _showEditDialog(index),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(height / 2),
            border: Border.all(color: Colors.white.withValues(alpha: 0.7), width: 1.5),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 2)),
            ]
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(height / 2),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Stack(
                children: [
                  Positioned(
                    top: 0, left: 0, right: 0, height: 6,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter, end: Alignment.bottomCenter,
                          colors: [Colors.black.withValues(alpha: 0.05), Colors.transparent],
                        ),
                      ),
                    ),
                  ),
                  const Center(
                    child: Icon(Icons.add_rounded, color: Color(0xFF8B5CF6), size: 28),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    const headerColors = [
      Color(0xFFE8B6DF), // Pink/Purple
      Color(0xFFA58DE8), // Indigo
      Color(0xFF8B5CF6), // Purple
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LiquidBg(
        child: Stack(
          children: [
            SafeArea(
              child: Column(
                children: [
                  // App Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        LiquidIconBtn(
                          icon: Icons.arrow_back_ios_new_rounded,
                          size: 44,
                          onTap: () => Navigator.pop(context),
                        ),
                        const Text(
                          'FIXED SCHEDULE',
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
                            _saveToProvider();
                            widget.onComplete();
                            Navigator.pop(context);
                          },
                        ), 
                      ],
                    ),
                  ),

                  // Glass Header (No day selector because Fixed Schedule is typically everyday)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      width: double.infinity,
                      height: 48,
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
                                  'Set Your Fixed Schedule',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.2),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Main 24H Timeline Scroll
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
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              padding: EdgeInsets.only(top: 24, bottom: bottomPadding + 80),
                              child: SizedBox(
                                height: 24 * kHourHeight,
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    // Ruler Lines
                                    ...List.generate(24, (i) {
                                      String label = i == 0 ? "12 AM" : (i < 12 ? "$i AM" : (i == 12 ? "12 PM" : "${i - 12} PM"));
                                      return Positioned(
                                        top: i * kHourHeight - 10, left: 16, width: 44,
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                                            const SizedBox(width: 8),
                                            Container(width: 4, height: 1.5, color: const Color(0xFFCBD5E1)),
                                          ],
                                        ),
                                      );
                                    }),

                                    // Glass Ruler Pillar
                                    Positioned(
                                      top: 0, bottom: 0, left: 60, width: 10,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.35),
                                          borderRadius: BorderRadius.circular(5),
                                          border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 1.2),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(5),
                                          child: BackdropFilter(
                                            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                                            child: Stack(
                                              children: List.generate(24, (i) {
                                                return Positioned(
                                                  top: i * kHourHeight - 0.75, left: 0, right: 0,
                                                  child: Center(child: Container(width: 4, height: 1.5, color: Colors.white.withValues(alpha: 0.8))),
                                                );
                                              }),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    
                                    // Block Items
                                    ...items.asMap().entries.map((entry) {
                                      int idx = entry.key;
                                      SetupBlockItem item = entry.value;
                                      if (item.isAdd) {
                                        return _buildAddButton(idx, item);
                                      } else if (item.isMini) {
                                        return _buildMiniBlock(idx, item);
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
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
