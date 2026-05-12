import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:optivus2/core/constants/event_names.dart';
import 'package:optivus2/core/liquid_ui/liquid_ui.dart';
import 'package:optivus2/core/providers.dart';
import 'package:optivus2/providers/routine_provider.dart';
import 'package:optivus2/services/image_upload_service.dart';
import 'package:optivus2/views/routine/widgets/routine_review_screen.dart';

class SkinCareStep {
  String name;
  SkinCareStep(this.name);
}

String _formatTimeFromStart(double hoursFrom6AM) {
  int totalMinutes = ((hoursFrom6AM + 6) * 60).round();
  int h = (totalMinutes ~/ 60) % 24;
  int m = totalMinutes % 60;
  String ampm = h < 12 ? 'AM' : 'PM';
  int displayH = h == 0 ? 12 : (h > 12 ? h - 12 : h);
  String displayM = m.toString().padLeft(2, '0');
  return "$displayH:$displayM $ampm";
}

class SkinCareRoutineBlock {
  final String id;
  String title;
  double start; // For vertical position (hours from 6 AM)
  double duration; // For vertical size (hours length)
  IconData? icon;
  Color? color;
  List<SkinCareStep> steps;

  bool isAdd;
  bool isMini;
  bool hasTopTape;
  bool hasBottomTape;
  bool reminderEnabled;

  String get displayStartTime => _formatTimeFromStart(start);
  String get displayEndTime => _formatTimeFromStart(start + duration);

  SkinCareRoutineBlock({
    required this.id,
    required this.title,
    required this.start,
    this.duration = 1.5,
    this.icon,
    this.color,
    this.steps = const [],
    this.isAdd = false,
    this.isMini = false,
    this.hasTopTape = false,
    this.hasBottomTape = false,
    this.reminderEnabled = false,
  });
}

class SkinCareSetupScreen extends ConsumerStatefulWidget {
  final VoidCallback onComplete;
  const SkinCareSetupScreen({super.key, required this.onComplete});

  @override
  ConsumerState<SkinCareSetupScreen> createState() =>
      _SkinCareSetupScreenState();
}

class _SkinCareSetupScreenState extends ConsumerState<SkinCareSetupScreen> {
  int _day = 0; // 0 for Mon, 6 for Sun
  late Map<int, List<SkinCareRoutineBlock>> weeklyRoutines;

  final double kHourHeight = 84.0;
  final double kLeftOffset = 64.0;

  final List<Color> _cycleColors = [
    const Color(0xFFF59E0B), // Orange/Gold
    const Color(0xFF3B82F6), // Blue
    const Color(0xFF10B981), // Green
    const Color(0xFF8B5CF6), // Purple
    const Color(0xFFF43F5E), // Rose
  ];
  int _colorIndex = 0;
  Map<String, dynamic>? _pendingImportMetadata;
  final ImageUploadService _imageUploadService = ImageUploadService();
  String _setupMode = 'Manual';
  final TextEditingController _textImportCtrl = TextEditingController();
  Map<String, dynamic>? _photoImportMetadata;
  bool _isUploadingPhoto = false;
  bool _isGenerating = false;
  bool _isSaving = false;
  String? _generationError;

  @override
  @override
  void initState() {
    super.initState();
    weeklyRoutines = {};
    for (int i = 0; i < 7; i++) {
      weeklyRoutines[i] = [];
    }
    
    final templates = ref.read(routineProvider).routineTemplates['skin_care'] ?? const [];
    
    for (final template in templates) {
      if (template['isActive'] == false) continue;
      
      final repeatRule = template['repeatRule']?.toString() ?? '';
      List<int> days;
      if (repeatRule.startsWith('weekly:')) {
        days = repeatRule.substring(7).split(',').map((e) => int.tryParse(e) ?? 1).map((d) => d - 1).toList();
      } else if (repeatRule == 'weekdays') {
        days = [0, 1, 2, 3, 4];
      } else if (repeatRule == 'weekends') {
        days = [5, 6];
      } else {
        days = [0, 1, 2, 3, 4, 5, 6];
      }

      final startTime = template['startTime']?.toString() ?? '07:30';
      final endTime = template['endTime']?.toString() ?? '07:45';
      final parsedStart = _parseHoursFrom6AM(startTime);
      final parsedEnd = _parseHoursFrom6AM(endTime);
      double duration = parsedEnd - parsedStart;
      if (duration <= 0) duration += 24;

      final title = template['title']?.toString() ?? '';
      final id = template['templateId']?.toString() ?? 'skin_${DateTime.now().microsecondsSinceEpoch}';

      final List<dynamic> rawSteps = template['steps'] is List ? template['steps'] : [];
      final steps = rawSteps.map((s) {
        if (s is Map) return SkinCareStep(s['name']?.toString() ?? '');
        return SkinCareStep(s.toString());
      }).toList();

      final block = SkinCareRoutineBlock(
        id: id,
        title: title,
        start: parsedStart,
        duration: duration,
        icon: Icons.spa_rounded,
        color: _cycleColors[_colorIndex++ % _cycleColors.length],
        hasTopTape: true,
        hasBottomTape: true,
        steps: steps,
        reminderEnabled: template['reminderEnabled'] == true,
      );

      for (final day in days) {
        if (day >= 0 && day <= 6) {
          weeklyRoutines[day]!.add(SkinCareRoutineBlock(
            id: 'skin_${day}_$id',
            title: block.title,
            start: block.start,
            duration: block.duration,
            icon: block.icon,
            color: block.color,
            hasTopTape: block.hasTopTape,
            hasBottomTape: block.hasBottomTape,
            steps: block.steps.map((s) => SkinCareStep(s.name)).toList(),
            reminderEnabled: block.reminderEnabled,
          ));
        }
      }
    }

    for (int i = 0; i < 7; i++) {
      weeklyRoutines[i]!.sort((a, b) => a.start.compareTo(b.start));
      if (weeklyRoutines[i]!.isEmpty) {
        weeklyRoutines[i]!.add(SkinCareRoutineBlock(
          id: 'add_$i',
          title: '',
          start: 2.0, // 8:00 AM
          isAdd: true,
        ));
      } else {
        final last = weeklyRoutines[i]!.last;
        double nextStart = last.start + last.duration + 0.5;
        if (nextStart > 23.5) nextStart = 23.5;
        weeklyRoutines[i]!.add(SkinCareRoutineBlock(
          id: 'add_$i',
          title: '',
          start: nextStart,
          isAdd: true,
        ));
      }
    }
  }


  @override
  void dispose() {
    _textImportCtrl.dispose();
    super.dispose();
  }

  List<SkinCareRoutineBlock> get items => weeklyRoutines[_day]!;

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
      if (from6AM < 0) from6AM += 24; // If it's 2 AM, it's 20 hours after 6 AM.
      return from6AM;
    } catch (e) {
      return 0.0;
    }
  }

  Future<void> _showEditDialog(int index) async {
    final item = items[index];
    List<SkinCareStep> tempSteps = List.from(item.steps);

    TextEditingController nameCtrl = TextEditingController(text: item.title);
    TextEditingController stepCtrl = TextEditingController();
    TextEditingController startTimeCtrl =
        TextEditingController(text: item.displayStartTime);
    TextEditingController endTimeCtrl =
        TextEditingController(text: item.displayEndTime);
    bool tempReminder = item.reminderEnabled;

    await showDialog(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(builder: (context, setDialogState) {
            return AlertDialog(
                backgroundColor: Colors.white.withValues(alpha: 0.95),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24)),
                title: Text(
                    item.isAdd ? 'Add Routine Block' : 'Edit Routine Details',
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, color: Color(0xFF0F111A))),
                content: SizedBox(
                  width: double.maxFinite,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: nameCtrl,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700),
                          decoration: InputDecoration(
                            labelText: 'Block Name (e.g. Morning Ritual)',
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
                                  labelText: 'Start (e.g. 7:00 AM)',
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
                                  labelText: 'End (e.g. 7:30 AM)',
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
                        const SizedBox(height: 16),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Reminder'),
                          value: tempReminder,
                          onChanged: (value) {
                            setDialogState(() => tempReminder = value);
                          },
                        ),
                        const Divider(),
                        const SizedBox(height: 8),
                        const Text('Steps (Products / Actions):',
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF334155))),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: tempSteps.asMap().entries.map((e) {
                            int sIdx = e.key;
                            SkinCareStep s = e.value;
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: const Color(0xFFE2E8F0)),
                                  boxShadow: [
                                    BoxShadow(
                                        color: Colors.black
                                            .withValues(alpha: 0.05),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2))
                                  ]),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(s.name,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF334155))),
                                  const SizedBox(width: 6),
                                  GestureDetector(
                                    onTap: () {
                                      setDialogState(() {
                                        tempSteps.removeAt(sIdx);
                                      });
                                    },
                                    child: const Icon(Icons.close_rounded,
                                        size: 16, color: Color(0xFF94A3B8)),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: stepCtrl,
                                decoration: InputDecoration(
                                  hintText: 'New step...',
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  isDense: true,
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none),
                                ),
                                onSubmitted: (val) {
                                  if (val.trim().isNotEmpty) {
                                    setDialogState(() {
                                      tempSteps.add(SkinCareStep(val.trim()));
                                      stepCtrl.clear();
                                    });
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                if (stepCtrl.text.trim().isNotEmpty) {
                                  setDialogState(() {
                                    tempSteps.add(
                                        SkinCareStep(stepCtrl.text.trim()));
                                    stepCtrl.clear();
                                  });
                                }
                              },
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                    color: const Color(0xFF10B981),
                                    borderRadius: BorderRadius.circular(12)),
                                child: const Icon(Icons.add_rounded,
                                    color: Colors.white),
                              ),
                            )
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
                        setState(() {
                          item.title = nameCtrl.text.isEmpty
                              ? 'New Block'
                              : nameCtrl.text;

                          double parsedStart =
                              _parseHoursFrom6AM(startTimeCtrl.text);
                          double parsedEnd =
                              _parseHoursFrom6AM(endTimeCtrl.text);
                          if (parsedEnd <= parsedStart && parsedEnd != 0.0) {
                            parsedEnd += 24;
                          }
                          item.start = parsedStart;
                          item.duration = parsedEnd - parsedStart > 0.5
                              ? parsedEnd - parsedStart
                              : 0.5;

                          item.steps = List.from(tempSteps);
                          item.reminderEnabled = tempReminder;
                          if (item.isAdd) {
                            item.isAdd = false;
                            item.hasTopTape = true;
                            item.hasBottomTape = true;
                            item.icon = Icons.spa_rounded;
                            item.duration = 1.5; // default UI height
                            item.color =
                                _cycleColors[_colorIndex % _cycleColors.length];
                            _colorIndex++;
                            // Insert an Add button below this block
                            items.insert(
                                index + 1,
                                SkinCareRoutineBlock(
                                  id: 'add_${DateTime.now().millisecondsSinceEpoch}',
                                  title: '',
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

  Widget _buildDroplet(double size,
      {Color color = Colors.white, String text = '', bool isActive = false}) {
    // Custom 3D liquid bubble
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
          // Soft bottom inner glow
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
          // Top sharp specular pill highlight
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
          // Text content
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

  Widget _buildStepPill(SkinCareStep step, Color baseColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.8), width: 1),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 3,
              offset: const Offset(0, 1)),
        ],
      ),
      child: Text(
        step.name,
        style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B)),
      ),
    );
  }

  Widget _buildColoredBlock(int index, SkinCareRoutineBlock item) {
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
                                if (item.icon != null) ...[
                                  Icon(item.icon,
                                      color: item.color!.withValues(alpha: 0.9),
                                      size: 24),
                                  const SizedBox(width: 8),
                                ],
                                Expanded(
                                    child: Text(item.title,
                                        style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w900,
                                            color: Color(0xFF0F111A)))),
                                const Icon(Icons.more_vert_rounded,
                                    color: Color(0xFF64748B), size: 18),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Row with Time Pill + Step Pills wrapping beautifully
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                // Time Pill
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
                                // Steps
                                ...item.steps
                                    .map((s) => _buildStepPill(s, item.color!)),
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

  Widget _buildAddButton(int index, SkinCareRoutineBlock item) {
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
                    // Small droplets strictly decorating the add button
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

  // ── Placeholder title guard — titles users leave as the dialog default ──
  static const _kPlaceholderTitles = {'New Block', 'new block'};

  // BUILD
  Future<void> _save(WidgetRef ref) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    final notifier = ref.read(routineProvider.notifier);
    final templates = <Map<String, dynamic>>[];
    String format24h(double hoursFrom6AM) {
      final totalMinutes = ((hoursFrom6AM + 6) * 60).round();
      final h = (totalMinutes ~/ 60) % 24;
      final m = totalMinutes % 60;
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
    }

    try {
      for (int d = 0; d < 7; d++) {
        final itemsForDay = weeklyRoutines[d] ?? [];
        final morning = <SkinStep>[];
        final afternoon = <SkinStep>[];
        final night = <SkinStep>[];

        for (final item in itemsForDay) {
          if (item.isAdd) continue;
          // Skip blocks with blank or placeholder titles — do not save sample data.
          final cleanTitle = item.title.trim();
          if (cleanTitle.isEmpty || _kPlaceholderTitles.contains(cleanTitle)) {
            continue;
          }
          templates.add({
            // Use a stable, compact templateId built from day + title slug.
            'templateId':
                'skin_d${d + 1}_${cleanTitle.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}',
            'title': cleanTitle,
            'routineType': 'skin_care',
            'startTime': format24h(item.start),
            'endTime': format24h(item.start + item.duration),
            'repeatRule': 'weekly:${d + 1}',
            'steps': item.steps
                .map((s) => s.name.trim())
                .where((n) => n.isNotEmpty)
                .map((n) => {'name': n})
                .toList(),
            'notes': item.steps
                .map((s) => s.name.trim())
                .where((n) => n.isNotEmpty)
                .join(', '),
            'reminderEnabled': item.reminderEnabled,
            'isActive': true,
            'createdAt': DateTime.now().toIso8601String(),
            'updatedAt': DateTime.now().toIso8601String(),
          });
          for (final step in item.steps) {
            final stepName = step.name.trim();
            if (stepName.isEmpty) continue;
            final skinStep =
                SkinStep(emoji: '✨', name: stepName, tag: cleanTitle);
            if (item.start < 6.0) {
              morning.add(skinStep);
            } else if (item.start < 11.0) {
              afternoon.add(skinStep);
            } else {
              night.add(skinStep);
            }
          }
        }
        notifier.setSkinCarePlan(
            d, DaySkinPlan(morning: morning, afternoon: afternoon, night: night));
      }
      // Always mark skin care as set up, even on an empty save, so the
      // legacy DaySkinPlan fallback path is not used by the materializer.
      notifier.markSkinCareSetUp();
      await notifier.setRoutineTemplates(
        'skin_care',
        templates,
        importMetadata: _pendingImportMetadata,
      );
      widget.onComplete();
    } catch (e) {
      debugPrint('[SkinCareSetup] _save failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not save skin care routine. Please try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<List<Map<String, dynamic>>> _previewGeneratedSkinTemplates(
    String? sourceText, {
    required String source,
    Map<String, dynamic>? imageMetadata,
  }) async {
    final generated =
        await ref.read(routineRepositoryProvider).previewRoutineImport(
              routineType: 'skin_care',
              mode: source,
              sourceText: sourceText,
              imageMetadata: imageMetadata,
            );
    if (generated.isNotEmpty) {
      return generated.map(_normalizeSkinTemplate).toList();
    }
    if (source == 'skin_care_photo') {
      throw StateError('No skin care products were detected in the photo.');
    }
    return _fallbackSkinTemplatesFromText(sourceText ?? '');
  }

  Future<void> _generateTextSkinCareReview() async {
    final sourceText = _textImportCtrl.text.trim();
    if (sourceText.isEmpty || _isGenerating) return;
    await _openGeneratedSkinReview(sourceText, source: 'skin_care_text');
  }

  Future<void> _generatePhotoSkinCareReview() async {
    if (_isGenerating) return;
    final imageMetadata = _photoImportMetadata;
    if (imageMetadata == null) {
      setState(() {
        _generationError =
            'Add a clear product photo first, then generate the routine.';
      });
      return;
    }
    await _openGeneratedSkinReview(
      null,
      source: 'skin_care_photo',
      imageMetadata: _skinCarePhotoMetadata(imageMetadata),
    );
  }

  Future<void> _openGeneratedSkinReview(
    String? sourceText, {
    required String source,
    Map<String, dynamic>? imageMetadata,
  }) async {
    setState(() {
      _isGenerating = true;
      _generationError = null;
    });
    final importMetadata = {
      'mode': source,
      if (sourceText != null && sourceText.trim().isNotEmpty)
        'sourceText': sourceText.trim(),
      if (imageMetadata?['path'] != null) 'photoPath': imageMetadata?['path'],
      if (imageMetadata != null) 'imageMetadata': imageMetadata,
      'createdAt': DateTime.now().toIso8601String(),
    };

    List<Map<String, dynamic>> templates = const [];
    try {
      templates = await _previewGeneratedSkinTemplates(
        sourceText,
        source: source,
        imageMetadata: imageMetadata,
      );
    } catch (e) {
      debugPrint('[SkinCareSetup] routineImport preview failed: $e');
      if (source == 'skin_care_photo') {
        await _clearPhotoAfterFailedImport(imageMetadata);
        if (mounted) {
          setState(() {
            _generationError =
                'We could not read skin care products from that photo. Try a clearer image with labels visible.';
          });
        }
        return;
      } else {
        templates = _fallbackSkinTemplatesFromText(sourceText ?? '');
        importMetadata['fallbackReason'] = e.toString();
        if (mounted) {
          setState(() => _generationError =
              'AI endpoint failed. Showing a local draft you can still edit.');
        }
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }

    final suggestionIds = templates
        .map((template) => template['_suggestionId']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList();
    if (suggestionIds.isNotEmpty) {
      importMetadata['suggestionIds'] = suggestionIds;
    }

    if (!mounted) return;
    final accepted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => RoutineReviewScreen(
          title: 'Review skin care routine',
          routineType: 'skin_care',
          templates: templates,
          onRegenerate: () => _previewGeneratedSkinTemplates(
            sourceText,
            source: source,
            imageMetadata: imageMetadata,
          ),
          onAcceptAll: (reviewed) async {
            await _acceptGeneratedSkinTemplates(reviewed, importMetadata);
          },
        ),
      ),
    );
    if (accepted == true && mounted) {
      Navigator.pop(context);
    }
  }

  Map<String, dynamic> _skinCarePhotoMetadata(Map<String, dynamic> metadata) {
    return {
      ...metadata,
      'source': 'skin_care_photo_upload',
      'routineType': 'skin_care',
      'uploadedAt': metadata['uploadedAt'] ?? DateTime.now().toIso8601String(),
    };
  }

  Future<void> _pickSkinCarePhoto() async {
    if (_isUploadingPhoto || _isGenerating) return;
    if (!ref.read(appFeatureFlagsProvider).skinProductImageImportReady) {
      _showPhotoAiComingSoon();
      return;
    }

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: const Text('Camera'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Gallery'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final previousMetadata = _photoImportMetadata;
    setState(() {
      _isUploadingPhoto = true;
      _generationError = null;
    });
    try {
      final metadata = await _imageUploadService.pickCompressAndUpload(
        source: source,
        routineType: 'skin_care',
      );
      if (!mounted || metadata == null) return;
      setState(() {
        _photoImportMetadata = metadata;
      });
      await _deletePhotoMetadataQuietly(previousMetadata);
    } catch (e) {
      debugPrint('[SkinCareSetup] photo upload failed: $e');
      if (mounted) {
        setState(() {
          _generationError =
              'We could not use that photo. Try a clear JPG or PNG with product labels visible.';
        });
      }
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  void _showPhotoAiComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
            'Product photo AI is coming soon. Text AI and manual setup still work.'),
      ),
    );
  }

  Future<void> _removeSkinCarePhoto() async {
    if (_isUploadingPhoto || _isGenerating) return;
    final metadata = _photoImportMetadata;
    setState(() {
      _isUploadingPhoto = true;
      _generationError = null;
    });
    try {
      await _deletePhotoMetadataQuietly(metadata);
      if (mounted) setState(() => _photoImportMetadata = null);
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  Future<void> _clearPhotoAfterFailedImport(
    Map<String, dynamic>? imageMetadata,
  ) async {
    final currentPath = _photoImportMetadata?['path']?.toString();
    final failedPath = imageMetadata?['path']?.toString();
    if (currentPath != null &&
        failedPath != null &&
        currentPath == failedPath &&
        mounted) {
      setState(() => _photoImportMetadata = null);
    }
    await _deletePhotoMetadataQuietly(imageMetadata);
  }

  Future<void> _deletePhotoMetadataQuietly(
    Map<String, dynamic>? metadata,
  ) async {
    if (metadata == null) return;
    try {
      await _imageUploadService.deleteUploadedMetadata(metadata);
    } catch (_) {
      // Best-effort cleanup for draft photo uploads.
    }
  }

  String _photoUploadLabel(Map<String, dynamic> metadata) {
    final sizeBytes = metadata['sizeBytes'];
    if (sizeBytes is num) {
      final kb = (sizeBytes / 1000).ceil();
      return 'Photo attached ($kb KB)';
    }
    return 'Photo attached';
  }

  List<Map<String, dynamic>> _fallbackSkinTemplatesFromText(String sourceText) {
    final text = sourceText.toLowerCase();
    final morningSteps = <String>[];
    final nightSteps = <String>[];
    if (text.contains('vitamin c')) morningSteps.add('Vitamin C');
    if (text.contains('spf') || text.contains('sunscreen')) {
      morningSteps.add('SPF');
    }
    if (text.contains('retinol')) nightSteps.add('Retinol');
    if (text.contains('moistur')) {
      morningSteps.add('Moisturiser');
      nightSteps.add('Moisturiser');
    }
    if (morningSteps.isEmpty && nightSteps.isEmpty) {
      final steps = sourceText
          .split(RegExp(r',|\n'))
          .map((step) => step.trim())
          .where((step) => step.isNotEmpty)
          .toList();
      morningSteps.addAll(steps.isEmpty ? ['Cleanse', 'Moisturiser'] : steps);
    }

    final templates = <Map<String, dynamic>>[];
    if (morningSteps.isNotEmpty) {
      templates.add(_normalizeSkinTemplate({
        'templateId':
            'skin_ai_morning_${DateTime.now().microsecondsSinceEpoch}',
        'title': 'Morning skin care',
        'startTime': '07:30',
        'endTime': '07:45',
        'repeatRule': 'daily',
        'timingRule': 'morning',
        'weekdayRule': 'daily',
        'steps': morningSteps.map((name) => {'name': name}).toList(),
        'notes': 'Generated from text import',
        'confidence': 0.55,
        'warnings': ['Local fallback draft'],
      }));
    }
    if (nightSteps.isNotEmpty) {
      templates.add(_normalizeSkinTemplate({
        'templateId': 'skin_ai_night_${DateTime.now().microsecondsSinceEpoch}',
        'title': 'Night skin care',
        'startTime': '21:30',
        'endTime': '21:45',
        'repeatRule': 'daily',
        'timingRule': 'night',
        'weekdayRule': 'daily',
        'steps': nightSteps.map((name) => {'name': name}).toList(),
        'notes': 'Generated from text import',
        'confidence': 0.55,
        'warnings': ['Local fallback draft'],
      }));
    }
    return templates;
  }

  Map<String, dynamic> _normalizeSkinTemplate(Map<String, dynamic> template) {
    final next = Map<String, dynamic>.from(template);
    final startTime = _normalize24h(
        next['startTime']?.toString() ?? next['time']?.toString() ?? '07:30');
    next['routineType'] = 'skin_care';
    next['startTime'] = startTime;
    next['time'] = startTime;
    next['endTime'] = _normalize24h(
      next['endTime']?.toString() ?? _endTimeFrom24h(startTime, 15),
    );
    next['repeatRule'] =
        next['repeatRule']?.toString().trim().isNotEmpty == true
            ? next['repeatRule'].toString().trim()
            : 'daily';
    next['weekdayRule'] =
        next['weekdayRule']?.toString().trim().isNotEmpty == true
            ? next['weekdayRule'].toString().trim()
            : next['repeatRule'];
    next['timingRule'] =
        next['timingRule']?.toString().trim().isNotEmpty == true
            ? next['timingRule'].toString().trim()
            : _timingRuleFor24h(startTime);
    next['steps'] = _templateSteps(next);
    next['notes'] = next['notes']?.toString() ?? '';
    next['confidence'] = _templateConfidence(next['confidence']);
    next['warnings'] = _templateWarnings(next['warnings']);
    next['reminderEnabled'] = next['reminderEnabled'] == true;
    next['isActive'] = next['isActive'] ?? true;
    next['createdAt'] = next['createdAt'] ?? DateTime.now().toIso8601String();
    next['updatedAt'] = DateTime.now().toIso8601String();
    next['templateId'] =
        next['templateId']?.toString().trim().isNotEmpty == true
            ? next['templateId'].toString().trim()
            : 'skin_${DateTime.now().microsecondsSinceEpoch}';
    return next;
  }

  Map<String, dynamic> _skinTemplateForSave(Map<String, dynamic> template) {
    final next = _normalizeSkinTemplate(template);
    next.remove('_suggestionId');
    return next;
  }

  List<Map<String, dynamic>> _templateSteps(Map<String, dynamic> template) {
    final raw = template['steps'];
    final steps = <String>[];
    if (raw is List) {
      for (final step in raw) {
        if (step is Map) {
          final name = step['name']?.toString().trim() ??
              step['title']?.toString().trim() ??
              '';
          if (name.isNotEmpty) steps.add(name);
        } else {
          final name = step.toString().trim();
          if (name.isNotEmpty) steps.add(name);
        }
      }
    }
    if (steps.isEmpty) {
      steps.addAll((template['notes']?.toString() ?? '')
          .split(RegExp(r',|\n'))
          .map((step) => step.trim())
          .where((step) => step.isNotEmpty));
    }
    return steps.map((name) => {'name': name}).toList();
  }

  List<String> _templateWarnings(Object? raw) {
    if (raw is List) {
      return raw
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    final value = raw?.toString().trim() ?? '';
    return value.isEmpty ? const [] : [value];
  }

  double _templateConfidence(Object? raw) {
    final value = raw is num ? raw.toDouble() : double.tryParse('$raw') ?? 0.75;
    return value.clamp(0.0, 1.0).toDouble();
  }

  String _normalize24h(String raw) {
    final parsed = _parseHoursFrom6AM(raw);
    final totalMinutes = ((parsed + 6) * 60).round();
    final h = (totalMinutes ~/ 60) % 24;
    final m = totalMinutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  String _endTimeFrom24h(String startTime, int durationMinutes) {
    final parts = startTime.split(':');
    final hour = int.tryParse(parts.first) ?? 7;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    final start = DateTime(2026, 1, 1, hour, minute);
    final end = start.add(Duration(minutes: durationMinutes));
    return '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}';
  }

  String _timingRuleFor24h(String time) {
    final hour = int.tryParse(time.split(':').first) ?? 7;
    if (hour < 12) return 'morning';
    if (hour < 17) return 'afternoon';
    return 'night';
  }

  Future<void> _acceptGeneratedSkinTemplates(
    List<Map<String, dynamic>> reviewed,
    Map<String, dynamic> importMetadata,
  ) async {
    final templates = reviewed.map(_skinTemplateForSave).toList();
    _applySkinCarePlansFromTemplates(templates);
    ref.read(routineProvider.notifier).markSkinCareSetUp();
    await ref.read(routineProvider.notifier).setRoutineTemplates(
          'skin_care',
          templates,
          importMetadata: importMetadata,
        );
    await _markSuggestionsAccepted(reviewed);
    widget.onComplete();
  }

  void _applySkinCarePlansFromTemplates(List<Map<String, dynamic>> templates) {
    final plans = List.generate(
      7,
      (_) => (
        morning: <SkinStep>[],
        afternoon: <SkinStep>[],
        night: <SkinStep>[],
      ),
    );

    for (final template in templates) {
      final days = _daysForRepeatRule(template['repeatRule']?.toString() ?? '');
      final title = template['title']?.toString() ?? 'Skin care';
      final startTime = template['startTime']?.toString() ?? '07:30';
      final hour = int.tryParse(startTime.split(':').first) ?? 7;
      final steps = _templateSteps(template)
          .map((step) => SkinStep(
                emoji: '✨',
                name: step['name']?.toString() ?? '',
                tag: title,
              ))
          .where((step) => step.name.trim().isNotEmpty)
          .toList();
      for (final day in days) {
        if (hour < 12) {
          plans[day].morning.addAll(steps);
        } else if (hour < 17) {
          plans[day].afternoon.addAll(steps);
        } else {
          plans[day].night.addAll(steps);
        }
      }
    }

    for (var i = 0; i < 7; i++) {
      ref.read(routineProvider.notifier).setSkinCarePlan(
            i,
            DaySkinPlan(
              morning: plans[i].morning,
              afternoon: plans[i].afternoon,
              night: plans[i].night,
            ),
          );
    }
  }

  List<int> _daysForRepeatRule(String repeatRule) {
    final clean = repeatRule.trim().toLowerCase();
    if (clean.isEmpty || clean == 'daily' || clean == 'everyday') {
      return const [0, 1, 2, 3, 4, 5, 6];
    }
    if (clean.startsWith('weekly:')) {
      final days = clean
          .substring('weekly:'.length)
          .split(',')
          .map((item) => int.tryParse(item.trim()))
          .whereType<int>()
          .map((day) => (day - 1).clamp(0, 6))
          .toSet()
          .toList();
      return days.isEmpty ? const [0, 1, 2, 3, 4, 5, 6] : days;
    }
    if (clean == 'weekdays') return const [0, 1, 2, 3, 4];
    if (clean == 'weekends') return const [5, 6];
    return const [0, 1, 2, 3, 4, 5, 6];
  }

  Future<void> _markSuggestionsAccepted(
    List<Map<String, dynamic>> templates,
  ) async {
    final ids = templates
        .map((template) => template['_suggestionId']?.toString() ?? '')
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
        source: 'skin_care_setup',
        payload: {'suggestionId': suggestionId},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Gradient tape header colors matching image (Blue, Cyan, Green, Pink)
    const headerColors = [
      Color(0xFFA7F3D0),
      Color(0xFF34D399),
      Color(0xFF10B981),
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LiquidBg(
        child: Stack(children: [
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 16),
                // Header
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
                        'SKIN CARE SETUP',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: kSub,
                          letterSpacing: 1.5,
                        ),
                      ),
                      _isSaving
                          ? const SizedBox(
                              width: 44,
                              height: 44,
                              child: Center(
                                child: SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Color(0xFF10B981),
                                  ),
                                ),
                              ),
                            )
                          : LiquidIconBtn(
                              icon: Icons.check_rounded,
                              size: 44,
                              onTap: () async {
                                await _save(ref);
                                // _save calls widget.onComplete() on success;
                                // on error it shows a snackbar and stays open.
                              },
                            ),
                    ],
                  ),
                ),

                // ── 7 Droplets Day Selector ──
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
                          color: const Color(0xFF10B981),
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
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'Manual',
                        icon: Icon(Icons.tune_rounded),
                        label: Text('Manual'),
                      ),
                      ButtonSegment(
                        value: 'Text AI',
                        icon: Icon(Icons.text_fields_rounded),
                        label: Text('Text AI'),
                      ),
                      ButtonSegment(
                        value: 'Photo AI',
                        icon: Icon(Icons.photo_camera_rounded),
                        label: Text('Photo AI'),
                      ),
                    ],
                    selected: {_setupMode},
                    onSelectionChanged: (value) =>
                        setState(() => _setupMode = value.first),
                  ),
                ),
                if (_setupMode == 'Text AI')
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.85)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _textImportCtrl,
                            minLines: 3,
                            maxLines: 5,
                            decoration: const InputDecoration(
                              hintText: 'Vitamin C, retinol, SPF, moisturiser',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          if (_generationError != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              _generationError!,
                              style: const TextStyle(
                                color: Color(0xFFB91C1C),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          FilledButton.icon(
                            onPressed: _isGenerating
                                ? null
                                : _generateTextSkinCareReview,
                            icon: _isGenerating
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.auto_awesome_rounded),
                            label: const Text('Generate'),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_setupMode == 'Photo AI')
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.85)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _isUploadingPhoto || _isGenerating
                                      ? null
                                      : _pickSkinCarePhoto,
                                  icon: _isUploadingPhoto
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Icon(_photoImportMetadata == null
                                          ? Icons.add_a_photo_rounded
                                          : Icons.check_circle_rounded),
                                  label: Text(_photoImportMetadata == null
                                      ? ref
                                              .watch(appFeatureFlagsProvider)
                                              .skinProductImageImportReady
                                          ? 'Add product photo'
                                          : 'Coming soon'
                                      : _photoUploadLabel(
                                          _photoImportMetadata!)),
                                ),
                              ),
                              if (_photoImportMetadata != null) ...[
                                const SizedBox(width: 8),
                                Tooltip(
                                  message: 'Remove photo',
                                  child: IconButton.filledTonal(
                                    onPressed:
                                        _isUploadingPhoto || _isGenerating
                                            ? null
                                            : _removeSkinCarePhoto,
                                    icon: const Icon(Icons.close_rounded),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (_generationError != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              _generationError!,
                              style: const TextStyle(
                                color: Color(0xFFB91C1C),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                          if (!ref
                              .watch(appFeatureFlagsProvider)
                              .skinProductImageImportReady) ...[
                            const SizedBox(height: 8),
                            const Text(
                              'Photo AI is coming soon. Use Text AI or manual setup for now.',
                              style: TextStyle(
                                color: Color(0xFF334155),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          FilledButton.icon(
                            onPressed: _isGenerating ||
                                    _isUploadingPhoto ||
                                    _photoImportMetadata == null
                                ? null
                                : _generatePhotoSkinCareReview,
                            icon: _isGenerating
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.auto_awesome_rounded),
                            label: const Text('Generate'),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 12),

                // ── "Set Your Fixed Skincare Routine" Glass Header ──
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
                                'Set Your Fixed Skincare Routine',
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

                // ── Main Glass Card ──
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
                              // Inner Header
                              const Padding(
                                padding: EdgeInsets.fromLTRB(24, 28, 24, 16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Your Fixed Skincare Schedule.',
                                        style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF1E293B),
                                            letterSpacing: -0.5)),
                                    SizedBox(height: 6),
                                    Text(
                                        'Maximize your daily potential with a consistent rhythm.',
                                        style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF475569))),
                                  ],
                                ),
                              ),

                              // Real Back Arrow inside the droplet
                              // (Oops I didn't put the icon in. I will just leave it like earlier, but actually adding an icon here is better)

                              // Timeline ScrollView
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
                                      height: 24 *
                                          kHourHeight, // 24 hours: 6 AM to 6 AM next day
                                      child: Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          // Glass Ruler
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

                                          // Axis Ticks
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

                                          // Blocks
                                          ...items.asMap().entries.map((entry) {
                                            int idx = entry.key;
                                            SkinCareRoutineBlock item =
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
                                ), // ShaderMask
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
