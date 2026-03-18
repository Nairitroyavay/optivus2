import 'dart:ui';
import 'package:flutter/material.dart';
import '../onboarding_screen.dart';

class ScheduleItem {
  final String id;
  String title;
  double start;
  double duration;
  IconData? icon;
  Color? color;
  bool hasTopTape;
  bool hasBottomTape;
  bool isMini;
  bool isAdd;

  ScheduleItem({
    required this.id,
    required this.title,
    required this.start,
    this.duration = 0,
    this.icon,
    this.color,
    this.hasTopTape = false,
    this.hasBottomTape = false,
    this.isMini = false,
    this.isAdd = false,
  });
}

class OnboardingPage8 extends StatefulWidget {
  const OnboardingPage8({super.key});

  @override
  State<OnboardingPage8> createState() => _OnboardingPage8State();
}

class _OnboardingPage8State extends State<OnboardingPage8> {
  final double kHourHeight = 44.0;
  final double kLeftOffset = 64.0;

  late List<ScheduleItem> items;

  final List<Color> _cycleColors = [
    const Color(0xFFF43F5E), // Rose
    const Color(0xFF14B8A6), // Teal
    const Color(0xFF8B5CF6), // Purple
    const Color(0xFF3B82F6), // Blue
  ];
  int _colorIndex = 0;

  @override
  void initState() {
    super.initState();
    items = [
      ScheduleItem(id: 'sleep', title: 'Sleep', start: 0, duration: 6.5, icon: Icons.bed_rounded, color: const Color(0xFF8B5CF6), hasTopTape: true, hasBottomTape: true),
      ScheduleItem(id: 'add1', title: '', start: 7.75, isAdd: true),
      ScheduleItem(id: 'classes', title: 'Classes', start: 9, duration: 3, icon: Icons.school_rounded, color: const Color(0xFF3B82F6), hasTopTape: true, hasBottomTape: true),
      ScheduleItem(id: 'add2', title: '', start: 12.5, isAdd: true),
      ScheduleItem(id: 'work', title: 'Work', start: 13, duration: 4, icon: Icons.work_rounded, color: const Color(0xFFF59E0B), hasTopTape: true, hasBottomTape: true),
      ScheduleItem(id: 'gym', title: 'Gym', start: 17.5, duration: 1.5, icon: Icons.fitness_center_rounded, color: const Color(0xFF10B981), hasTopTape: true, hasBottomTape: true),
      ScheduleItem(id: 'dinner', title: 'Dinner', start: 19.5, duration: 1.0, isMini: true),
      ScheduleItem(id: 'leisure', title: 'Leisure', start: 20.75, duration: 1.0, isMini: true),
      ScheduleItem(id: 'end', title: 'End of Day', start: 22.0, duration: 1.0, isMini: true),
    ];
  }

  String _formatTime(double hour) {
    int h = hour.floor();
    int m = ((hour - h) * 60).round();
    String ampm = h >= 12 ? 'PM' : 'AM';
    int displayH = h % 12;
    if (displayH == 0) displayH = 12;
    String minStr = m.toString().padLeft(2, '0');
    return '$displayH:$minStr $ampm';
  }

  void _onTopTapeDrag(int index, DragUpdateDetails details) {
    setState(() {
      double deltaHours = details.delta.dy / kHourHeight;
      if (items[index].duration - deltaHours < 0.25) {
        deltaHours = items[index].duration - 0.25; // absolute minimum 15 mins
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
      if (items[index].duration + deltaHours < 0.25) {
        deltaHours = 0.25 - items[index].duration;
      }
      if (items[index].start + items[index].duration + deltaHours > 24) {
        deltaHours = 24 - (items[index].start + items[index].duration);
      }
      items[index].duration += deltaHours;
    });
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
              title: Text(item.isAdd ? 'Add New Task' : 'Edit Task Details', style: const TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Task Name',
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
                            helpText: 'Select Start Time',
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
                            helpText: 'Select End Time',
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
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      item.title = nameCtrl.text.isEmpty ? 'New Task' : nameCtrl.text;
                      item.start = tempStart;
                      item.duration = tempDuration;
                      if (item.isAdd) {
                        item.isAdd = false;
                        item.hasTopTape = true;
                        item.hasBottomTape = true;
                        item.icon = Icons.star_rounded;
                        item.color = _cycleColors[_colorIndex % _cycleColors.length];
                        _colorIndex++;
                      }
                    });
                    Navigator.pop(ctx);
                  }, 
                  child: Text(item.isAdd ? 'Create Task' : 'Save Fixed Time')
                ),
              ]
            );
          }
        );
      }
    );
  }

  Widget _buildTopPill() {
    return Container(
      height: 52,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
          BoxShadow(color: Colors.white.withValues(alpha: 0.8), blurRadius: 8, offset: const Offset(-2, -2)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        const Color(0xFF60A5FA).withValues(alpha: 0.3),
                        const Color(0xFF34D399).withValues(alpha: 0.2),
                        const Color(0xFFFBBF24).withValues(alpha: 0.25),
                        const Color(0xFFA78BFA).withValues(alpha: 0.3),
                      ],
                    ),
                  ),
                ),
              ),
              Center(
                child: RichText(
                  text: const TextSpan(
                    children: [
                      TextSpan(text: 'Set Your ', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700, fontSize: 22, letterSpacing: -0.5)),
                      TextSpan(text: 'Fixed Schedule', style: TextStyle(color: Color(0xFFA78BFA), fontWeight: FontWeight.w700, fontSize: 22, letterSpacing: -0.5)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDroplet(double size, {Color color = Colors.white}) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.4),
        border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 1.2),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4, offset: const Offset(1, 2)),
          BoxShadow(color: Colors.white.withValues(alpha: 0.8), blurRadius: 4, offset: const Offset(-1, -1)),
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

  Widget _buildColoredBlock(int index, ScheduleItem item) {
    final top = item.start * kHourHeight;
    final height = item.duration * kHourHeight;
    final bool isSmall = item.duration <= 2.0;

    String timeText = '';
    if (item.id == 'sleep') {
      timeText = 'Start: ${_formatTime(item.start)} | End: ${_formatTime(item.start + item.duration)}';
    } else {
      timeText = '${_formatTime(item.start)} - ${_formatTime(item.start + item.duration)}';
    }

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
                  // Using SingleChildScrollView prevents layout overflow when resized too small!
                  child: SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: isSmall ? 6 : 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Icon(item.icon, color: item.color!.withValues(alpha: 0.9), size: isSmall ? 20 : 24),
                                const SizedBox(width: 10),
                                Expanded(child: Text(item.title, style: TextStyle(fontSize: isSmall ? 16 : 18, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B)))),
                                const Icon(Icons.more_vert_rounded, color: Color(0xFF64748B), size: 20),
                              ],
                            ),
                            if (timeText.isNotEmpty) ...[
                              if (isSmall) const SizedBox(height: 2) else const SizedBox(height: 12),
                              Container(
                                height: isSmall ? 22 : 32,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.35),
                                  borderRadius: BorderRadius.circular(isSmall ? 11 : 16),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 1),
                                ),
                                child: Stack(
                                  children: [
                                    Positioned(
                                      top: 0, left: 0, right: 0, height: 6,
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.vertical(top: Radius.circular(isSmall ? 11 : 16)),
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
                                      child: Text(timeText, style: TextStyle(fontSize: isSmall ? 11 : 13, fontWeight: FontWeight.w600, color: const Color(0xFF334155))),
                                    ),
                                  ],
                                ),
                              ),
                            ],
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

  Widget _buildMiniBlock(int index, ScheduleItem item) {
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

  Widget _buildAddButton(int index, ScheduleItem item) {
    final height = 36.0;
    // Add buttons dynamically span 1 hour for layout visually
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
                    child: Icon(Icons.add_rounded, color: Color(0xFF60A5FA), size: 28),
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
    final topPadding = MediaQuery.of(context).padding.top + kIndicatorOverlayH;
    final bottomPadding = MediaQuery.of(context).padding.bottom + kButtonOverlayH;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, topPadding + 16, 20, bottomPadding + 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildTopPill(),
            const SizedBox(height: 24),
            SizedBox(
              height: 24 * kHourHeight,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Axis lines + text
                  ...List.generate(24, (i) {
                    String label = i == 0 ? "12 AM" : (i < 12 ? "$i AM" : (i == 12 ? "12 PM" : "${i - 12} PM"));
                    return Positioned(
                      top: i * kHourHeight - 10, left: 0, width: 44,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                          const SizedBox(width: 6),
                          Container(width: 4, height: 1.5, color: const Color(0xFFCBD5E1)),
                        ],
                      ),
                    );
                  }),
                  
                  // Glass Ruler
                  Positioned(
                    top: 0, bottom: 0, left: 48, width: 10,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 1.2),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(2, 2)),
                          BoxShadow(color: Colors.white.withValues(alpha: 0.7), blurRadius: 4, offset: const Offset(-2, -2)),
                        ],
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
                  
                  // Render Blocks
                  ...items.asMap().entries.map((entry) {
                    int idx = entry.key;
                    ScheduleItem item = entry.value;
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
          ],
        ),
      ),
    );
  }
}
