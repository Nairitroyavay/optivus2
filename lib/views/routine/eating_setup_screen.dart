import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus2/core/liquid_ui/liquid_ui.dart';
import 'package:optivus2/core/constants/event_names.dart';
import 'package:optivus2/core/providers.dart';
import 'package:optivus2/providers/onboarding_provider.dart';
import 'package:optivus2/providers/routine_provider.dart';
import 'package:optivus2/services/image_upload_service.dart';
import 'package:image_picker/image_picker.dart';

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
  bool reminderEnabled;
  String? suggestionId;
  int? weekday;

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
    this.reminderEnabled = false,
    this.suggestionId,
    this.weekday,
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
  Map<String, dynamic>? _pendingImportMetadata;
  final ImageUploadService _imageUploadService = ImageUploadService();
  bool _isImportingPhoto = false;
  String? _importError;
  bool _sensitiveMode = false;

  @override
  void initState() {
    super.initState();
    // Start with an empty grid — one Add placeholder per day.
    // No pre-seeded sample meals so fresh users don't accidentally
    // persist fake data on first Save.
    weeklyRoutines = {
      for (int i = 0; i < 7; i++)
        i: [
          EatingRoutineBlock(
            id: 'add_initial_$i',
            mealName: '',
            start: 2.0, // default position: 8 AM
            isAdd: true,
          ),
        ],
    };
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Read the sensitive-context flag synchronously (cached by StreamProvider).
    final container = ProviderScope.containerOf(context, listen: false);
    _sensitiveMode =
        container.read(eatingDisorderFlagProvider).valueOrNull ?? false;
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
    final isSensitive =
        ref.read(eatingDisorderFlagProvider).valueOrNull ?? false;

    TextEditingController nameCtrl = TextEditingController(text: item.mealName);
    TextEditingController foodCtrl = TextEditingController(text: item.foodName);
    TextEditingController emojiCtrl = TextEditingController(text: item.emoji);
    TextEditingController startTimeCtrl =
        TextEditingController(text: item.displayStartTime);
    TextEditingController endTimeCtrl =
        TextEditingController(text: item.displayEndTime);
    bool tempReminder = item.reminderEnabled;
    String? dialogError;

    await showDialog(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(builder: (context, setDialogState) {
            return AlertDialog(
                backgroundColor: Colors.white.withValues(alpha: 0.95),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24)),
                title: Text(item.isAdd ? 'Add Meal' : 'Edit Meal Details',
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, color: Color(0xFF0F111A))),
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
                                style: const TextStyle(
                                    fontSize: 24, fontWeight: FontWeight.w700),
                                textAlign: TextAlign.center,
                                decoration: InputDecoration(
                                  labelText: 'Icon',
                                  filled: true,
                                  fillColor: const Color(0xFFF1F5F9),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: nameCtrl,
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w700),
                                decoration: InputDecoration(
                                  labelText: 'Meal Name (e.g. Lunch)',
                                  filled: true,
                                  fillColor: const Color(0xFFF1F5F9),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: foodCtrl,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600),
                          decoration: InputDecoration(
                            labelText: isSensitive
                                ? 'Notes (optional — how did this meal feel?)'
                                : 'Food Detail (e.g. Grilled Chicken Salad)',
                            hintText: isSensitive
                                ? 'e.g. felt calm, felt rushed…'
                                : 'e.g. Rice, Dal, Salad',
                            filled: true,
                            fillColor: const Color(0xFFF1F5F9),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: startTimeCtrl,
                                style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w600),
                                decoration: InputDecoration(
                                  labelText: 'Start (e.g. 1:00 PM)',
                                  filled: true,
                                  fillColor: const Color(0xFFF1F5F9),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: endTimeCtrl,
                                style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w600),
                                decoration: InputDecoration(
                                  labelText: 'End (e.g. 2:00 PM)',
                                  filled: true,
                                  fillColor: const Color(0xFFF1F5F9),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Reminder'),
                          value: tempReminder,
                          onChanged: (value) {
                            setDialogState(() => tempReminder = value);
                          },
                        ),
                        if (dialogError != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            dialogError!,
                            style: const TextStyle(
                              color: Color(0xFFEF4444),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
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
                      child: const Text('Delete',
                          style: TextStyle(
                              color: Color(0xFFEF4444),
                              fontWeight: FontWeight.bold)),
                    ),
                  if (!item.isAdd) const Spacer(),
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel')),
                  ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F111A),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        // Validate inputs before saving.
                        final nameText = nameCtrl.text.trim();
                        if (nameText.isEmpty) {
                          setDialogState(() => dialogError = 'Meal name cannot be empty.');
                          return;
                        }
                        final parsedStart =
                            _parseHoursFrom6AM(startTimeCtrl.text);
                        var parsedEnd =
                            _parseHoursFrom6AM(endTimeCtrl.text);
                        if (parsedEnd <= parsedStart) parsedEnd += 24;
                        if (parsedEnd - parsedStart < 0.1) {
                          setDialogState(() => dialogError = 'End time must be after start time.');
                          return;
                        }
                        setState(() {
                          item.mealName = nameText;
                          item.foodName = foodCtrl.text.trim();
                          item.emoji =
                              emojiCtrl.text.trim().isEmpty ? '🍽️' : emojiCtrl.text.trim();
                          item.reminderEnabled = tempReminder;
                          item.start = parsedStart;
                          item.duration = (parsedEnd - parsedStart).clamp(0.5, 12.0).toDouble();

                          if (item.isAdd) {
                            item.isAdd = false;
                            item.hasTopTape = true;
                            item.hasBottomTape = true;
                            item.color =
                                _cycleColors[_colorIndex % _cycleColors.length];
                            _colorIndex++;
                            // Insert an Add button below this block
                            items.insert(
                                index + 1,
                                EatingRoutineBlock(
                                  id: 'add_${DateTime.now().millisecondsSinceEpoch}',
                                  mealName: '',
                                  start: item.start + item.duration + 0.5,
                                  isAdd: true,
                                ));
                          }
                        });
                        Navigator.pop(ctx);
                      },
                      child: const Text('Save')),
                ]);
          });
        });
  }

  // ── Local mess-menu text parser (hostel fallback when Worker is off) ────────
  //
  // Splits raw text into meal blocks for the current selected day.
  // Recognises common patterns: "Breakfast: ...", "Lunch - ...", plain lines.
  // No network call needed — works offline.
  List<EatingRoutineBlock> _parseMessMenuTextLocally(String text) {
    final lines = text
        .split(RegExp(r'[\n;]'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final mealDefaults = <String, (double, double)>{
      'breakfast': (2.0, 3.0),  // 8–9 AM
      'morning': (2.0, 3.0),
      'lunch': (7.0, 8.0),      // 1–2 PM
      'afternoon': (7.0, 8.0),
      'snack': (10.0, 10.5),    // 4–4:30 PM
      'tea': (10.0, 10.5),
      'dinner': (14.0, 15.0),   // 8–9 PM
      'supper': (14.0, 15.0),
      'night': (14.0, 15.0),
    };

    final blocks = <EatingRoutineBlock>[];
    double lastEnd = 2.0;
    int idx = 0;

    for (final line in lines) {
      final lower = line.toLowerCase();
      final separator = RegExp(r'[:–\-]');
      final sepMatch = separator.firstMatch(line);

      String mealName;
      String foodDetail;
      double start;
      double duration;

      if (sepMatch != null) {
        mealName = line.substring(0, sepMatch.start).trim();
        foodDetail = line.substring(sepMatch.end).trim();
      } else {
        mealName = line;
        foodDetail = '';
      }

      // Look up default times by meal keyword.
      double? foundStart;
      double? foundEnd;
      for (final entry in mealDefaults.entries) {
        if (lower.contains(entry.key)) {
          foundStart = entry.value.$1;
          foundEnd = entry.value.$2;
          break;
        }
      }

      if (foundStart != null && foundEnd != null) {
        start = foundStart;
        duration = foundEnd - foundStart;
      } else {
        // Assign sequentially if no keyword matched.
        start = lastEnd.clamp(0.0, 22.0).toDouble();
        duration = 1.0;
      }
      lastEnd = start + duration + 0.5;

      blocks.add(EatingRoutineBlock(
        id: 'local_parsed_${_day}_${idx}_${DateTime.now().microsecondsSinceEpoch}',
        mealName: mealName.isEmpty ? 'Meal' : mealName,
        foodName: foodDetail,
        start: start,
        duration: duration,
        emoji: '🍽️',
        color: _cycleColors[(_colorIndex + idx) % _cycleColors.length],
        hasTopTape: true,
        hasBottomTape: true,
      ));
      idx++;
    }
    return blocks;
  }

  // ── Sensitive-context banner widget ──────────────────────────────────────────
  Widget _buildSensitiveBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Container(
        width: double.infinity,
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF60D4A0).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: const Color(0xFF60D4A0).withValues(alpha: 0.6)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.health_and_safety_rounded,
                size: 18, color: Color(0xFF22C55E)),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Mindful Eating mode is active. '  
                'Focus on meal timing and how you feel — '  
                'not specific foods or portions.',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDroplet(double size,
      {Color color = Colors.white, String text = '', bool isActive = false}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutBack,
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive
            ? color.withValues(alpha: 0.15)
            : Colors.white.withValues(alpha: 0.25),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.9), width: 1.2),
        boxShadow: [
          BoxShadow(
              color: isActive
                  ? color.withValues(alpha: 0.2)
                  : const Color(0x0F000000),
              blurRadius: 8,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            right: size * 0.15,
            bottom: size * 0.05,
            width: size * 0.7,
            height: size * 0.45,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(size),
                boxShadow: [
                  BoxShadow(
                      color: Colors.white.withValues(alpha: 0.4), blurRadius: 6)
                ],
              ),
            ),
          ),
          Positioned(
            top: size * 0.08,
            left: size * 0.18,
            width: size * 0.35,
            height: size * 0.15,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(size),
                boxShadow: [
                  BoxShadow(
                      color: Colors.white.withValues(alpha: 0.6), blurRadius: 4)
                ],
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
              width: 56,
              height: 16,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.95), width: 1.5),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 3)),
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
      top: top,
      left: kLeftOffset,
      right: 0,
      height: height,
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
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      item.color!.withValues(alpha: 0.3),
                      item.color!.withValues(alpha: 0.05)
                    ],
                  ),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.9), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                        color: item.color!.withValues(alpha: 0.15),
                        blurRadius: 16,
                        offset: const Offset(0, 6)),
                    BoxShadow(
                        color: Colors.white.withValues(alpha: 0.9),
                        blurRadius: 12,
                        offset: const Offset(-4, -4)),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Text(item.emoji,
                                    style: const TextStyle(fontSize: 24)),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: Text(item.mealName,
                                        style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w900,
                                            color: Color(0xFF0F111A)))),
                                const Icon(Icons.more_vert_rounded,
                                    color: Color(0xFF64748B), size: 18),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color:
                                            Colors.white.withValues(alpha: 0.8),
                                        width: 1),
                                  ),
                                  child: Text(
                                      '${item.displayStartTime} - ${item.displayEndTime}',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF334155))),
                                ),
                                if (item.foodName.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.white.withValues(alpha: 0.45),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                          color: Colors.white
                                              .withValues(alpha: 0.8),
                                          width: 1),
                                    ),
                                    child: Text(item.foodName,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF1E293B))),
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
                  top: -8,
                  left: 0,
                  right: 0,
                  child: Center(
                      child: _buildTapeWithDrops(
                          onDrag: (d) => _onTopTapeDrag(index, d)))),
            if (item.hasBottomTape)
              Positioned(
                  bottom: -8,
                  left: 0,
                  right: 0,
                  child: Center(
                      child: _buildTapeWithDrops(
                          onDrag: (d) => _onBottomTapeDrag(index, d)))),
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton(int index, EatingRoutineBlock item) {
    final height = 40.0;
    final top = item.start * kHourHeight - height / 2;
    return Positioned(
      top: top,
      left: kLeftOffset,
      right: 0,
      height: height,
      child: GestureDetector(
        onTap: () => _showEditDialog(index),
        child: Align(
          alignment: Alignment.center,
          child: Container(
            width: 60,
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(height / 2),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.8), width: 1.5),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 3))
                ]),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(height / 2),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: 8,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.05),
                              Colors.transparent
                            ],
                          ),
                        ),
                      ),
                    ),
                    const Center(
                        child: Icon(Icons.add_rounded,
                            color: Color(0xFF94A3B8), size: 28)),
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

  Future<void> _save(WidgetRef ref) async {
    final notifier = ref.read(routineProvider.notifier);
    // Re-read the sensitive flag at save time (may have changed since screen opened).
    final isSensitive =
        ref.read(eatingDisorderFlagProvider).valueOrNull ?? false;
    final templates = <Map<String, dynamic>>[];
    String format24h(double hoursFrom6AM) {
      final totalMinutes = ((hoursFrom6AM + 6) * 60).round();
      final h = (totalMinutes ~/ 60) % 24;
      final m = totalMinutes % 60;
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
    }

    for (int d = 0; d < 7; d++) {
      final itemsForDay = weeklyRoutines[d] ?? [];
      final meals = <MealItem>[];
      for (final item in itemsForDay) {
        if (!item.isAdd) {
          templates.add({
            'templateId': 'eating_${d + 1}_${item.id}',
            'title': item.mealName.trim(),
            'routineType': 'eating',
            'startTime': format24h(item.start),
            'endTime': format24h(item.start + item.duration),
            'repeatRule': 'mess_menu_weekday:${d + 1}',
            'mealType': item.mealName.trim(),
            // notes: for sensitive users store the user's own text (not AI-generated)
            // but mark the template so the Worker never overwrites with calorie content.
            'notes': item.foodName.trim(),
            'emoji': item.emoji,
            'reminderEnabled': item.reminderEnabled,
            'isActive': true,
            // Safety gate: Worker and adaptive logic must respect this flag.
            if (isSensitive) 'sensitiveMode': true,
            'createdAt': DateTime.now().toIso8601String(),
            'updatedAt': DateTime.now().toIso8601String(),
          });
          meals.add(MealItem(
            emoji: item.emoji,
            name: item.foodName.trim().isNotEmpty
                ? item.foodName.trim()
                : item.mealName.trim(),
            time: item.displayStartTime,
          ));
        }
      }
      notifier.setMealPlan(d, DayMealPlan(meals: meals));
    }
    await notifier.setRoutineTemplates(
      'eating',
      templates,
      importMetadata: _pendingImportMetadata,
    );
    widget.onComplete();
  }

  Future<void> _showImportOptions() async {
    if (_isImportingPhoto) return;
    final flags = ref.read(appFeatureFlagsProvider);
    if (!flags.routineImportWorkerReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('AI import is coming soon. Please add meals manually.'),
        ),
      );
      return;
    }
    final source = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: const Text('Mess Photo from Camera'),
              onTap: () => Navigator.of(ctx).pop('camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Mess Photo from Gallery'),
              onTap: () => Navigator.of(ctx).pop('gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.text_snippet_rounded),
              title: const Text('Paste Mess Menu Text'),
              onTap: () => Navigator.of(ctx).pop('text'),
            ),
            ListTile(
              leading: const Icon(Icons.auto_awesome),
              title: const Text('Generate Adaptive Meal Plan (Coming Soon)'),
              onTap: () => Navigator.of(ctx).pop('adaptive'),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    if (source == 'camera') {
      await _pickUploadAndImportMessPhoto(ImageSource.camera);
    } else if (source == 'gallery') {
      await _pickUploadAndImportMessPhoto(ImageSource.gallery);
    } else if (source == 'text') {
      await _showTextInputDialog();
    } else if (source == 'adaptive') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adaptive eating plan is coming soon.')),
      );
    }
  }

  Future<void> _showTextInputDialog() async {
    final controller = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Paste Mess Menu'),
        content: TextField(
          controller: controller,
          maxLines: 8,
          decoration: const InputDecoration(
            hintText: 'Paste your weekly mess menu here...',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Import'),
          ),
        ],
      ),
    );
    if (submitted == true && controller.text.trim().isNotEmpty) {
      await _importMessMenuText(controller.text.trim());
    }
  }

  Future<void> _importMessMenuText(String text) async {
    setState(() {
      _isImportingPhoto = true;
      _importError = null;
    });
    try {
      final flags = ref.read(appFeatureFlagsProvider);
      final eatFlag = ref.read(eatingDisorderFlagProvider).valueOrNull ?? false;

      if (!flags.routineImportWorkerReady) {
        // ── Local fallback: parse text without Worker (hostel/mess offline mode)
        final blocks = _parseMessMenuTextLocally(text);
        if (blocks.isEmpty) {
          setState(() {
            _importError =
                'Could not parse any meals from the text. Try using the format:\n'
                '"Breakfast: Idli, Sambar\nLunch: Dal, Rice"';
          });
          return;
        }
        setState(() {
          // Replace current day with parsed blocks + trailing Add button.
          weeklyRoutines[_day] = _withAddButtons(blocks, _day);
          _colorIndex += blocks.length;
          _pendingImportMetadata = {
            'mode': 'eating_mess_text_local',
            'parsedMeals': blocks.length,
            if (eatFlag) 'sensitiveMode': true,
          };
        });
        return;
      }

      // Worker is ready — call remote endpoint.
      final generated = await ref.read(routineRepositoryProvider).previewRoutineImport(
        routineType: 'eating',
        mode: 'eating_mess_text',
        sourceText: text,
        sensitiveContext: eatFlag,
      );
      if (!mounted) return;
      await _processImportedTemplates(generated, null, {'mode': 'eating_mess_text'});
    } catch (e) {
      debugPrint('[EatingSetup] mess text import failed: $e');
      if (mounted) {
        setState(() {
          _importError = 'Mess menu text import failed. Check the text and endpoint configuration.';
        });
      }
    } finally {
      if (mounted) setState(() => _isImportingPhoto = false);
    }
  }

  void _showImageImportComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Mess photo import is coming soon. Add meals manually.'),
      ),
    );
  }

  Future<void> _pickUploadAndImportMessPhoto(ImageSource source) async {
    setState(() {
      _isImportingPhoto = true;
      _importError = null;
    });

    Map<String, dynamic>? imageMetadata;
    try {
      final uploaded = await _imageUploadService.pickCompressAndUpload(
        source: source,
        routineType: 'eating',
      );
      if (!mounted || uploaded == null) return;

      final storagePath = uploaded['path']?.toString() ?? '';
      imageMetadata = {
        ...uploaded,
        'storagePath': storagePath,
        'source': 'eating_mess_photo',
        'routineType': 'eating',
        'uploadedAt': DateTime.now().toIso8601String(),
      };

      final eatFlag = ref.read(eatingDisorderFlagProvider).valueOrNull ?? false;
      final generated = await ref.read(routineRepositoryProvider).previewRoutineImport(
        routineType: 'eating',
        mode: 'eating_mess_photo',
        sensitiveContext: eatFlag,
        imageMetadata: {
          ...imageMetadata,
          'storagePath': storagePath,
        },
      );
      if (!mounted) return;

      await _processImportedTemplates(
        generated,
        imageMetadata,
        {
          'mode': 'eating_mess_photo',
          'storagePath': storagePath,
          'imageMetadata': imageMetadata,
        },
      );
    } catch (e) {
      debugPrint('[EatingSetup] mess photo import failed: $e');
      await _deleteUploadedImageQuietly(imageMetadata);
      if (mounted) {
        setState(() {
          _importError =
              'Mess photo import failed. Check the image and endpoint configuration.';
        });
      }
    } finally {
      if (mounted) setState(() => _isImportingPhoto = false);
    }
  }

  Future<void> _processImportedTemplates(
    List<Map<String, dynamic>> generated,
    Map<String, dynamic>? imageMetadata,
    Map<String, dynamic> metadataBase,
  ) async {
    final grid = _weeklyBlocksFromTemplates(generated);
    final totalMeals = grid.values.fold<int>(
      0,
      (sum, dayBlocks) => sum + dayBlocks.length,
    );
    if (totalMeals == 0) {
      if (imageMetadata != null) await _deleteUploadedImageQuietly(imageMetadata);
      if (!mounted) return;
      setState(() {
        _importError =
            'No mess menu meals were detected. Try a clearer menu input.';
      });
      return;
    }

    final suggestionIds = generated
        .map((template) => template['_suggestionId']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    final accepted = await _showMessMenuReview(grid, {
      ...metadataBase,
      if (suggestionIds.isNotEmpty) 'suggestionIds': suggestionIds,
      'createdAt': DateTime.now().toIso8601String(),
    });
    if (accepted != true && imageMetadata != null) {
      await _deleteUploadedImageQuietly(imageMetadata);
    }
  }

  Future<void> _deleteUploadedImageQuietly(
    Map<String, dynamic>? imageMetadata,
  ) async {
    try {
      await _imageUploadService.deleteUploadedMetadata(imageMetadata);
    } catch (e) {
      debugPrint('[EatingSetup] upload cleanup failed: $e');
    }
  }

  EatingRoutineBlock _mealBlockFromTemplate(Map<String, dynamic> template) {
    final start =
        _parseHoursFrom6AM(template['startTime']?.toString() ?? '8:00 AM');
    var end = _parseHoursFrom6AM(template['endTime']?.toString() ?? '8:30 AM');
    if (end <= start) end += 24;
    final mealTime = template['mealTime']?.toString().trim().isNotEmpty == true
        ? template['mealTime'].toString().trim()
        : template['mealType']?.toString().trim().isNotEmpty == true
            ? template['mealType'].toString().trim()
            : template['title']?.toString().trim().isNotEmpty == true
                ? template['title'].toString().trim()
                : 'Meal';
    return EatingRoutineBlock(
      id: template['templateId']?.toString() ??
          'generated_${DateTime.now().microsecondsSinceEpoch}',
      mealName: mealTime,
      foodName: _menuItemsText(template),
      start: start,
      duration: (end > start ? end - start : 0.5).clamp(0.5, 3.0).toDouble(),
      emoji: template['emoji']?.toString() ?? '🍽️',
      color: const Color(0xFFFF9560),
      hasTopTape: true,
      hasBottomTape: true,
      reminderEnabled: template['reminderEnabled'] == true,
      suggestionId: template['_suggestionId']?.toString(),
      weekday: _weekdayFromTemplate(template),
    );
  }

  String _menuItemsText(Map<String, dynamic> template) {
    final items = template['items'];
    if (items is List) {
      final text = items
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .join(', ');
      if (text.isNotEmpty) return text;
    }
    final notes = template['notes']?.toString().trim() ?? '';
    if (notes.isNotEmpty) return notes;
    final mealName = template['mealName']?.toString().trim() ?? '';
    if (mealName.isNotEmpty) return mealName;
    return template['title']?.toString().trim() ?? '';
  }

  Map<int, List<EatingRoutineBlock>> _weeklyBlocksFromTemplates(
    List<Map<String, dynamic>> templates,
  ) {
    final grid = <int, List<EatingRoutineBlock>>{
      for (var day = 0; day < 7; day++) day: <EatingRoutineBlock>[],
    };
    for (var i = 0; i < templates.length; i++) {
      final template = templates[i];
      final weekday = _weekdayFromTemplate(template);
      final block = _mealBlockFromTemplate(template);
      block.color = _cycleColors[(_colorIndex + i) % _cycleColors.length];
      grid[weekday - 1]!.add(block);
    }
    for (final blocks in grid.values) {
      blocks.sort((a, b) => a.start.compareTo(b.start));
    }
    return grid;
  }

  int _weekdayFromTemplate(Map<String, dynamic> template) {
    final direct = _weekdayFromValue(template['weekday']);
    if (direct != null) return direct;
    final repeatRule = template['repeatRule']?.toString() ?? '';
    final match = RegExp(r'mess_menu_weekday:(\d)').firstMatch(repeatRule);
    if (match != null) return _clampWeekday(int.parse(match.group(1)!));
    return _day + 1;
  }

  int? _weekdayFromValue(Object? value) {
    if (value is int) return _clampWeekday(value);
    if (value is num) return _clampWeekday(value.round());
    final text = value?.toString().trim().toLowerCase() ?? '';
    if (text.isEmpty) return null;
    final numeric = int.tryParse(text);
    if (numeric != null) return _clampWeekday(numeric);
    const aliases = {
      'mon': 1,
      'monday': 1,
      'tue': 2,
      'tues': 2,
      'tuesday': 2,
      'wed': 3,
      'wednesday': 3,
      'thu': 4,
      'thur': 4,
      'thurs': 4,
      'thursday': 4,
      'fri': 5,
      'friday': 5,
      'sat': 6,
      'saturday': 6,
      'sun': 7,
      'sunday': 7,
    };
    return aliases[text];
  }

  int _clampWeekday(int value) => value.clamp(1, 7).toInt();

  String _weekdayLabel(int weekday) {
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return labels[_clampWeekday(weekday) - 1];
  }

  String _format24h(double hoursFrom6AM) {
    final totalMinutes = ((hoursFrom6AM + 6) * 60).round();
    final h = (totalMinutes ~/ 60) % 24;
    final m = totalMinutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  Future<bool> _showMessMenuReview(
    Map<int, List<EatingRoutineBlock>> grid,
    Map<String, dynamic> importMetadata,
  ) async {
    return await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          builder: (ctx) {
            final review = grid.values
                .expand((blocks) => blocks)
                .where((block) => !block.isAdd)
                .toList();
            var isAccepting = false;
            return StatefulBuilder(builder: (context, setSheetState) {
              return Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  20,
                  20,
                  MediaQuery.of(ctx).viewInsets.bottom + 20,
                ),
                child: SizedBox(
                  height: MediaQuery.of(ctx).size.height * 0.78,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('Review mess menu',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView.separated(
                          itemCount: review.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final item = review[index];
                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                    color: const Color(0xFFE2E8F0), width: 1),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: DropdownButtonFormField<int>(
                                          initialValue: _clampWeekday(
                                              item.weekday ?? _day + 1),
                                          decoration: const InputDecoration(
                                            labelText: 'Day',
                                            border: OutlineInputBorder(),
                                          ),
                                          items: List.generate(
                                            7,
                                            (dayIndex) => DropdownMenuItem(
                                              value: dayIndex + 1,
                                              child: Text(
                                                  _weekdayLabel(dayIndex + 1)),
                                            ),
                                          ),
                                          onChanged: (value) {
                                            if (value != null) {
                                              item.weekday = value;
                                            }
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        flex: 2,
                                        child: TextFormField(
                                          initialValue: item.mealName,
                                          decoration: const InputDecoration(
                                            labelText: 'Meal',
                                            border: OutlineInputBorder(),
                                          ),
                                          onChanged: (value) {
                                            final next = value.trim();
                                            if (next.isNotEmpty) {
                                              item.mealName = next;
                                            }
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    initialValue: item.foodName,
                                    decoration: const InputDecoration(
                                      labelText: 'Items',
                                      border: OutlineInputBorder(),
                                    ),
                                    onChanged: (value) =>
                                        item.foodName = value.trim(),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          initialValue: _format24h(item.start),
                                          decoration: const InputDecoration(
                                            labelText: 'Start',
                                            border: OutlineInputBorder(),
                                          ),
                                          onChanged: (value) {
                                            final parsed =
                                                _parseHoursFrom6AM(value);
                                            final currentEnd =
                                                item.start + item.duration;
                                            item.start = parsed;
                                            item.duration =
                                                (currentEnd - parsed)
                                                    .clamp(0.5, 3.0)
                                                    .toDouble();
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: TextFormField(
                                          initialValue: _format24h(
                                              item.start + item.duration),
                                          decoration: const InputDecoration(
                                            labelText: 'End',
                                            border: OutlineInputBorder(),
                                          ),
                                          onChanged: (value) {
                                            var parsed =
                                                _parseHoursFrom6AM(value);
                                            if (parsed <= item.start) {
                                              parsed += 24;
                                            }
                                            item.duration =
                                                (parsed - item.start)
                                                    .clamp(0.5, 3.0)
                                                    .toDouble();
                                          },
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Remove',
                                        onPressed: () => setSheetState(
                                            () => review.removeAt(index)),
                                        icon: const Icon(Icons
                                            .remove_circle_outline_rounded),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      Row(
                        children: [
                          const Spacer(),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(ctx, false);
                              _showImportOptions();
                            },
                            child: const Text('Regenerate'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: isAccepting
                                ? null
                                : () async {
                                    setSheetState(() => isAccepting = true);
                                    final accepted = review
                                        .where((item) =>
                                            item.mealName.trim().isNotEmpty)
                                        .toList();
                                    await _markSuggestionsAccepted(accepted);
                                    if (!mounted) return;
                                    setState(() {
                                      _applyReviewedMessMenu(accepted);
                                      _pendingImportMetadata = importMetadata;
                                      _colorIndex += accepted.length;
                                    });
                                    if (!ctx.mounted) return;
                                    Navigator.pop(ctx, true);
                                  },
                            child: Text(
                                isAccepting ? 'Accepting...' : 'Accept all'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            });
          },
        ) ??
        false;
  }

  void _applyReviewedMessMenu(List<EatingRoutineBlock> accepted) {
    final next = <int, List<EatingRoutineBlock>>{
      for (var day = 0; day < 7; day++) day: <EatingRoutineBlock>[],
    };
    for (final item in accepted) {
      final day = _clampWeekday(item.weekday ?? _day + 1) - 1;
      item.isAdd = false;
      item.hasTopTape = true;
      item.hasBottomTape = true;
      item.color ??= _cycleColors[_colorIndex % _cycleColors.length];
      next[day]!.add(item);
    }
    for (var day = 0; day < 7; day++) {
      next[day]!.sort((a, b) => a.start.compareTo(b.start));
      weeklyRoutines[day] = _withAddButtons(next[day]!, day);
    }
  }

  List<EatingRoutineBlock> _withAddButtons(
    List<EatingRoutineBlock> blocks,
    int day,
  ) {
    final result = <EatingRoutineBlock>[];
    for (var index = 0; index < blocks.length; index++) {
      final block = blocks[index];
      result.add(block);
      result.add(EatingRoutineBlock(
        id: 'add_${day}_${index}_${DateTime.now().microsecondsSinceEpoch}',
        mealName: '',
        start: (block.start + block.duration + 0.5).clamp(0.0, 23.5).toDouble(),
        isAdd: true,
      ));
    }
    if (result.isEmpty) {
      result.add(EatingRoutineBlock(
        id: 'add_${day}_${DateTime.now().microsecondsSinceEpoch}',
        mealName: '',
        start: 2.0,
        isAdd: true,
      ));
    }
    return result;
  }

  Future<void> _markSuggestionsAccepted(
    List<EatingRoutineBlock> blocks,
  ) async {
    final ids = blocks
        .map((block) => block.suggestionId ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
    for (final suggestionId in ids) {
      await ref.read(firestoreServiceProvider).saveSuggestion(
        suggestionId,
        {
          'status': 'accepted',
          'acceptedAt': DateTime.now().toIso8601String(),
        },
      );
      await ref.read(eventServiceProvider).emit(
        eventName: EventNames.suggestionAccepted,
        source: 'eating_setup',
        payload: {'suggestionId': suggestionId},
      );
    }
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isImportingPhoto ? null : _showImportOptions,
        icon: const Icon(Icons.auto_awesome_rounded),
        label: Text(
            ref.watch(appFeatureFlagsProvider).hostelMessImageImportReady
                ? 'AI / Menu'
                : 'Coming soon'),
      ),
      body: LiquidBg(
        child: Stack(children: [
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
                        onTap: () async {
                          await _save(ref);
                          if (!context.mounted) return;
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
                    const days = [
                      "MON",
                      "TUE",
                      "WED",
                      "THU",
                      "FRI",
                      "SAT",
                      "SUN"
                    ];
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
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.9),
                          width: 1.5),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 4,
                            offset: const Offset(0, 2))
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Row(
                              children: headerColors
                                  .map((color) => Expanded(
                                          child: Container(
                                        decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                          begin: Alignment.centerLeft,
                                          end: Alignment.centerRight,
                                          colors: [
                                            color.withValues(alpha: 0.1),
                                            color.withValues(alpha: 0.35),
                                            color.withValues(alpha: 0.1)
                                          ],
                                        )),
                                      )))
                                  .toList(),
                            ),
                          ),
                          BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                            child: const Center(
                              child: Text(
                                'Set Your Daily Eating Routine',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF64748B),
                                    letterSpacing: 0.2),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Safety banner for sensitive users
                if (_sensitiveMode) _buildSensitiveBanner(),
                if (_isImportingPhoto || _importError != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.9)),
                      ),
                      child: Row(
                        children: [
                          if (_isImportingPhoto)
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else
                            const Icon(Icons.error_outline_rounded,
                                size: 18, color: Color(0xFFEF4444)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _isImportingPhoto
                                  ? 'Reading mess menu photo...'
                                  : _importError!,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_isImportingPhoto || _importError != null)
                  const SizedBox(height: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.4),
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(32)),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.8),
                            width: 1.5),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 12,
                              offset: const Offset(0, -4)),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(32)),
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
                                    Text('Your Fixed Meals.',
                                        style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF1E293B),
                                            letterSpacing: -0.5)),
                                    SizedBox(height: 6),
                                    Text(
                                        'Maintain a healthy metabolism with regular eating times.',
                                        style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF475569))),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: ShaderMask(
                                  shaderCallback: (Rect bounds) {
                                    return const LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        Colors.white,
                                        Colors.white,
                                        Colors.transparent
                                      ],
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
                                            top: 0,
                                            bottom: 0,
                                            left: 48,
                                            width: 8,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: Colors.white
                                                    .withValues(alpha: 0.35),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                                border: Border.all(
                                                    color: Colors.white
                                                        .withValues(alpha: 0.9),
                                                    width: 1.2),
                                                boxShadow: [
                                                  BoxShadow(
                                                      color: Colors.black
                                                          .withValues(
                                                              alpha: 0.04),
                                                      blurRadius: 4,
                                                      offset:
                                                          const Offset(2, 2))
                                                ],
                                              ),
                                            ),
                                          ),
                                          ...List.generate(24, (i) {
                                            final hour = (i + 6) % 24;
                                            final ampm =
                                                hour < 12 ? 'AM' : 'PM';
                                            final displayHour = hour == 0
                                                ? 12
                                                : (hour > 12
                                                    ? hour - 12
                                                    : hour);
                                            final label = "$displayHour $ampm";
                                            return Positioned(
                                              top: i * kHourHeight - 10,
                                              left: 0,
                                              width: 44,
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.end,
                                                children: [
                                                  Text(label,
                                                      style: const TextStyle(
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color: Color(
                                                              0xFF64748B))),
                                                  const SizedBox(width: 6),
                                                  Container(
                                                      width: 4,
                                                      height: 1.5,
                                                      color: const Color(
                                                          0xFFCBD5E1)),
                                                ],
                                              ),
                                            );
                                          }),
                                          ...items.asMap().entries.map((entry) {
                                            int idx = entry.key;
                                            EatingRoutineBlock item =
                                                entry.value;
                                            if (item.isAdd) {
                                              return _buildAddButton(idx, item);
                                            } else {
                                              return _buildColoredBlock(
                                                  idx, item);
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
        ]),
      ),
    );
  }
}
