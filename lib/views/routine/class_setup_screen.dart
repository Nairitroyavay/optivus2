import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:optivus2/core/config/feature_flags.dart';
import 'package:optivus2/core/constants/event_names.dart';
import 'package:optivus2/core/liquid_ui/liquid_ui.dart';
import 'package:optivus2/core/providers.dart';
import 'package:optivus2/providers/routine_provider.dart';
import 'package:optivus2/services/image_upload_service.dart';

String _formatTimeFromStart(double hoursFrom6AM) {
  int totalMinutes = ((hoursFrom6AM + 6) * 60).round();
  int h = (totalMinutes ~/ 60) % 24;
  int m = totalMinutes % 60;
  String ampm = h < 12 ? 'AM' : 'PM';
  int displayH = h == 0 ? 12 : (h > 12 ? h - 12 : h);
  String displayM = m.toString().padLeft(2, '0');
  return "$displayH:$displayM $ampm";
}

class ClassRoutineBlock {
  final String id;
  String subject;
  String room;
  String professor;
  double start; // For vertical position (hours from 6 AM)
  double duration; // For vertical size (hours length)
  IconData? icon;
  Color? color;

  bool isAdd;
  bool hasTopTape;
  bool hasBottomTape;
  bool reminderEnabled;
  int? weekday;
  String? suggestionId;

  String get displayStartTime => _formatTimeFromStart(start);
  String get displayEndTime => _formatTimeFromStart(start + duration);

  ClassRoutineBlock({
    required this.id,
    required this.subject,
    this.room = '',
    this.professor = '',
    required this.start,
    this.duration = 1.0,
    this.icon,
    this.color,
    this.isAdd = false,
    this.hasTopTape = false,
    this.hasBottomTape = false,
    this.reminderEnabled = false,
    this.weekday,
    this.suggestionId,
  });
}

class ClassSetupScreen extends ConsumerStatefulWidget {
  final VoidCallback onComplete;
  const ClassSetupScreen({super.key, required this.onComplete});

  @override
  ConsumerState<ClassSetupScreen> createState() => _ClassSetupScreenState();
}

class _ClassSetupScreenState extends ConsumerState<ClassSetupScreen> {
  int _day = 0; // 0 for Mon, 6 for Sun
  late Map<int, List<ClassRoutineBlock>> weeklyRoutines;

  final double kHourHeight = 84.0;
  final double kLeftOffset = 64.0;

  final List<Color> _cycleColors = [
    const Color(0xFF378ADD), // Blue
    const Color(0xFFF59E0B), // Orange/Gold
    const Color(0xFF10B981), // Green
    const Color(0xFF8B5CF6), // Purple
    const Color(0xFFF43F5E), // Rose
  ];
  int _colorIndex = 0;
  Map<String, dynamic>? _pendingImportMetadata;
  final ImageUploadService _imageUploadService = ImageUploadService();
  String _setupMode = 'Manual';
  bool _isImportingPhoto = false;
  String? _photoImportError;

  @override
  void initState() {
    super.initState();
    weeklyRoutines = {};
    for (int i = 0; i < 7; i++) {
      weeklyRoutines[i] = [
        ClassRoutineBlock(
          id: 'add1_$i',
          subject: '',
          start: 3.0,
          isAdd: true,
        ),
        ClassRoutineBlock(
          id: 'add2_$i',
          subject: '',
          start: 7.0,
          isAdd: true,
        ),
      ];
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final savedClasses = ref.read(routineProvider).classes;
      if (savedClasses.isEmpty || !mounted) return;

      final next = <int, List<ClassRoutineBlock>>{
        for (int i = 0; i < 7; i++) i: <ClassRoutineBlock>[],
      };

      for (final item in savedClasses) {
        final dayIndex = (item.weekday - 1).clamp(0, 6);
        final start = _hoursFrom6Am(item.startTime);
        final end = _hoursFrom6Am(item.endTime);
        final duration = (end - start).clamp(0.5, 18.0).toDouble();
        next[dayIndex]!.add(
          ClassRoutineBlock(
            id: 'class_${dayIndex}_${item.subject}_${item.startTime}',
            subject: item.subject,
            room: item.room,
            professor: item.professor,
            start: start,
            duration: duration,
            icon: Icons.school_rounded,
            color: Color(int.parse(item.colorHex.replaceAll('#', '0xFF'))),
            hasTopTape: true,
            hasBottomTape: true,
          ),
        );
      }

      for (int i = 0; i < 7; i++) {
        next[i]!.sort((a, b) => a.start.compareTo(b.start));
        next[i]!.add(ClassRoutineBlock(
          id: 'add_saved_$i',
          subject: '',
          start: 7.0,
          isAdd: true,
        ));
      }

      setState(() => weeklyRoutines = next);
    });
  }

  double _hoursFrom6Am(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length < 2) return 3.0;
    final hour = int.tryParse(parts[0]) ?? 9;
    final minute = int.tryParse(parts[1]) ?? 0;
    return ((hour + minute / 60) - 6).clamp(0.0, 18.0).toDouble();
  }

  List<ClassRoutineBlock> get items => weeklyRoutines[_day]!;

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

    TextEditingController subjectCtrl =
        TextEditingController(text: item.subject);
    TextEditingController roomCtrl = TextEditingController(text: item.room);
    TextEditingController profCtrl =
        TextEditingController(text: item.professor);
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
                title: Text(item.isAdd ? 'Add Class' : 'Edit Class Details',
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
                          controller: subjectCtrl,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700),
                          decoration: InputDecoration(
                            labelText: 'Subject',
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
                                controller: roomCtrl,
                                style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w600),
                                decoration: InputDecoration(
                                  labelText: 'Room',
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
                                controller: profCtrl,
                                style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w600),
                                decoration: InputDecoration(
                                  labelText: 'Professor',
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
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: startTimeCtrl,
                                style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w600),
                                decoration: InputDecoration(
                                  labelText: 'Start (e.g. 9:00 AM)',
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
                                  labelText: 'End (e.g. 10:00 AM)',
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
                          item.subject = subjectCtrl.text.isEmpty
                              ? 'New Class'
                              : subjectCtrl.text;
                          item.room = roomCtrl.text;
                          item.professor = profCtrl.text;
                          item.reminderEnabled = tempReminder;

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

                          if (item.isAdd) {
                            item.isAdd = false;
                            item.hasTopTape = true;
                            item.hasBottomTape = true;
                            item.icon = Icons.school_rounded;
                            item.duration = 1.0;
                            item.color =
                                _cycleColors[_colorIndex % _cycleColors.length];
                            _colorIndex++;
                            // Insert an Add button below this block
                            items.insert(
                                index + 1,
                                ClassRoutineBlock(
                                  id: 'add_${DateTime.now().millisecondsSinceEpoch}',
                                  subject: '',
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

  Widget _buildColoredBlock(int index, ClassRoutineBlock item) {
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
                                    child: Text(item.subject,
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
                                if (item.room.isNotEmpty)
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
                                    child: Text(item.room,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF1E293B))),
                                  ),
                                if (item.professor.isNotEmpty)
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
                                    child: Text(item.professor,
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

  Widget _buildAddButton(int index, ClassRoutineBlock item) {
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
    final allClasses = <ClassItem>[];
    final templates = <Map<String, dynamic>>[];

    String format24h(double hoursFrom6AM) {
      int totalMinutes = ((hoursFrom6AM + 6) * 60).round();
      int h = (totalMinutes ~/ 60) % 24;
      int m = totalMinutes % 60;
      return "${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}";
    }

    for (int d = 0; d < 7; d++) {
      final itemsForDay = weeklyRoutines[d] ?? [];
      int weekday = d + 1;
      for (final item in itemsForDay) {
        if (!item.isAdd) {
          String colorHex = '#FFFFFF';
          if (item.color != null) {
            colorHex =
                '#${(item.color!.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
          }
          allClasses.add(ClassItem(
            subject: item.subject,
            room: item.room,
            professor: item.professor,
            startTime: format24h(item.start),
            endTime: format24h(item.start + item.duration),
            weekday: weekday,
            colorHex: colorHex,
          ));
          templates.add({
            'templateId': 'class_${weekday}_${item.id}',
            'title': item.subject,
            'routineType': 'classes',
            'weekday': weekday,
            'subject': item.subject,
            'startTime': format24h(item.start),
            'endTime': format24h(item.start + item.duration),
            'start': format24h(item.start),
            'end': format24h(item.start + item.duration),
            'repeatRule': 'weekly:$weekday',
            'room': item.room,
            'professor': item.professor,
            'colorHex': colorHex,
            'reminderEnabled': item.reminderEnabled,
            'isActive': true,
            'createdAt': DateTime.now().toIso8601String(),
            'updatedAt': DateTime.now().toIso8601String(),
          });
        }
      }
    }
    notifier.setClasses(allClasses);
    await notifier.setRoutineTemplates(
      'classes',
      templates,
      importMetadata: _pendingImportMetadata,
    );
    widget.onComplete();
  }

  Future<void> _showImportOptions() async {
    if (_isImportingPhoto) return;
    if (!FeatureFlags.classTimetableImageImportReady) {
      _showImageImportComingSoon();
      return;
    }
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: const Text('Camera'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Gallery'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    await _pickUploadAndImportPhoto(source);
  }

  void _showImageImportComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
            'Timetable photo import is coming soon. Add classes manually.'),
      ),
    );
  }

  Future<void> _pickUploadAndImportPhoto(ImageSource source) async {
    setState(() {
      _setupMode = 'Photo OCR';
      _isImportingPhoto = true;
      _photoImportError = null;
    });

    Map<String, dynamic>? imageMetadata;
    try {
      final uploaded = await _imageUploadService.pickCompressAndUpload(
        source: source,
        routineType: 'classes',
      );
      if (!mounted || uploaded == null) return;

      imageMetadata = {
        ...uploaded,
        'source': 'class_timetable_photo',
        'routineType': 'classes',
        'uploadedAt': DateTime.now().toIso8601String(),
      };

      final generated =
          await ref.read(routineRepositoryProvider).previewRoutineImport(
                routineType: 'classes',
                mode: 'class_timetable_photo',
                imageMetadata: imageMetadata,
              );
      if (!mounted) return;

      final blocks = generated
          .asMap()
          .entries
          .map((entry) => _classBlockFromTemplate(entry.value, entry.key))
          .where((block) => block.subject.trim().isNotEmpty)
          .toList();
      if (blocks.isEmpty) {
        await _deleteUploadedImageQuietly(imageMetadata);
        if (!mounted) return;
        setState(() {
          _photoImportError =
              'No classes were detected. Try a clearer timetable photo.';
        });
        return;
      }

      final accepted = await _showClassReview(blocks, {
        'mode': 'class_timetable_photo',
        'imageMetadata': imageMetadata,
        'suggestionIds': blocks
            .map((block) => block.suggestionId ?? '')
            .where((id) => id.isNotEmpty)
            .toSet()
            .toList(),
        'createdAt': DateTime.now().toIso8601String(),
      });
      if (accepted != true) {
        await _deleteUploadedImageQuietly(imageMetadata);
      }
    } catch (e) {
      debugPrint('[ClassSetup] routineImport preview failed: $e');
      await _deleteUploadedImageQuietly(imageMetadata);
      if (mounted) {
        setState(() {
          _photoImportError =
              'Photo OCR failed. Check the timetable image and endpoint configuration.';
        });
      }
    } finally {
      if (mounted) setState(() => _isImportingPhoto = false);
    }
  }

  Future<void> _deleteUploadedImageQuietly(
    Map<String, dynamic>? imageMetadata,
  ) async {
    try {
      await _imageUploadService.deleteUploadedMetadata(imageMetadata);
    } catch (e) {
      debugPrint('[ClassSetup] upload cleanup failed: $e');
    }
  }

  ClassRoutineBlock _classBlockFromTemplate(
    Map<String, dynamic> template,
    int index,
  ) {
    final start = _parseHoursFrom6AM(
        (template['start'] ?? template['startTime'])?.toString() ?? '9:00 AM');
    var end = _parseHoursFrom6AM(
        (template['end'] ?? template['endTime'])?.toString() ?? '10:00 AM');
    if (end <= start) end += 24;
    final color = _cycleColors[(_colorIndex + index) % _cycleColors.length];
    return ClassRoutineBlock(
      id: template['templateId']?.toString() ??
          'generated_${DateTime.now().microsecondsSinceEpoch}',
      subject: (template['subject'] ?? template['title'])?.toString() ??
          'Imported Class',
      room: template['room']?.toString() ?? '',
      professor: template['professor']?.toString() ?? '',
      start: start,
      duration: (end > start ? end - start : 1.0).clamp(0.5, 4.0).toDouble(),
      icon: Icons.school_rounded,
      color: color,
      hasTopTape: true,
      hasBottomTape: true,
      reminderEnabled: template['reminderEnabled'] == true,
      weekday: _weekdayFromTemplate(template),
      suggestionId: template['_suggestionId']?.toString(),
    );
  }

  int _weekdayFromTemplate(Map<String, dynamic> template) {
    final direct = _weekdayFromValue(template['weekday']);
    if (direct != null) return direct;
    final repeatRule = template['repeatRule']?.toString() ?? '';
    final weeklyMatch = RegExp(r'weekly:(\d)').firstMatch(repeatRule);
    if (weeklyMatch != null) {
      return _clampWeekday(int.parse(weeklyMatch.group(1)!));
    }
    return _clampWeekday(_day + 1);
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
    return labels[(weekday - 1).clamp(0, 6).toInt()];
  }

  String _format24h(double hoursFrom6AM) {
    int totalMinutes = ((hoursFrom6AM + 6) * 60).round();
    int h = (totalMinutes ~/ 60) % 24;
    int m = totalMinutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  Future<bool> _showClassReview(
    List<ClassRoutineBlock> blocks,
    Map<String, dynamic> importMetadata,
  ) async {
    return await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          builder: (ctx) {
            final review = List<ClassRoutineBlock>.from(blocks);
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
                      const Text('Review imported classes',
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
                                          initialValue: item.subject,
                                          decoration: const InputDecoration(
                                            labelText: 'Subject',
                                            border: OutlineInputBorder(),
                                          ),
                                          onChanged: (value) =>
                                              item.subject = value.trim(),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          initialValue: item.room,
                                          decoration: const InputDecoration(
                                            labelText: 'Room',
                                            border: OutlineInputBorder(),
                                          ),
                                          onChanged: (value) =>
                                              item.room = value.trim(),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: TextFormField(
                                          initialValue: item.professor,
                                          decoration: const InputDecoration(
                                            labelText: 'Professor',
                                            border: OutlineInputBorder(),
                                          ),
                                          onChanged: (value) =>
                                              item.professor = value.trim(),
                                        ),
                                      ),
                                    ],
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
                                                    .clamp(0.5, 4.0)
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
                                                    .clamp(0.5, 4.0)
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
                                            item.subject.trim().isNotEmpty)
                                        .toList();
                                    await _markSuggestionsAccepted(accepted);
                                    if (!mounted) return;
                                    setState(() {
                                      _applyReviewedClasses(accepted);
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

  void _applyReviewedClasses(List<ClassRoutineBlock> review) {
    for (int d = 0; d < 7; d++) {
      final existing =
          (weeklyRoutines[d] ?? []).where((item) => !item.isAdd).toList();
      final imported = review
          .where((item) => (item.weekday ?? _day + 1) == d + 1)
          .map((item) {
        item.weekday = d + 1;
        item.isAdd = false;
        item.hasTopTape = true;
        item.hasBottomTape = true;
        item.icon = Icons.school_rounded;
        item.color ??= _cycleColors[_colorIndex % _cycleColors.length];
        return item;
      }).toList();
      final next = [...existing, ...imported]
        ..sort((a, b) => a.start.compareTo(b.start));
      next.add(ClassRoutineBlock(
        id: 'add_imported_${d}_${DateTime.now().microsecondsSinceEpoch}',
        subject: '',
        start: next.isEmpty ? 7.0 : next.last.start + next.last.duration + 0.5,
        isAdd: true,
      ));
      weeklyRoutines[d] = next;
    }
  }

  Future<void> _markSuggestionsAccepted(
    List<ClassRoutineBlock> blocks,
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
        source: 'class_setup',
        payload: {'suggestionId': suggestionId},
      );
    }
  }

  Widget _buildModeTabs() {
    Widget tab(String label, IconData icon) {
      final selected = _setupMode == label;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _setupMode = label),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 42,
            decoration: BoxDecoration(
              color: selected
                  ? const Color(0xFF0F111A)
                  : Colors.white.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.9),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon,
                    size: 18,
                    color: selected ? Colors.white : const Color(0xFF475569)),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: selected ? Colors.white : const Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(18),
          border:
              Border.all(color: Colors.white.withValues(alpha: 0.9), width: 1),
        ),
        child: Row(
          children: [
            tab('Manual', Icons.edit_calendar_rounded),
            const SizedBox(width: 4),
            tab('Photo OCR', Icons.document_scanner_rounded),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoOcrPanel() {
    if (_setupMode != 'Photo OCR') return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(18),
          border:
              Border.all(color: Colors.white.withValues(alpha: 0.9), width: 1),
        ),
        child: Row(
          children: [
            Icon(Icons.document_scanner_rounded,
                color: _isImportingPhoto
                    ? const Color(0xFF64748B)
                    : const Color(0xFF2563EB)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                !FeatureFlags.classTimetableImageImportReady
                    ? 'Photo OCR is coming soon. Manual class setup still works.'
                    : _photoImportError ??
                        (_isImportingPhoto
                            ? 'Uploading and reading timetable...'
                            : 'Pick a timetable photo to extract weekly classes.'),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _photoImportError == null
                      ? const Color(0xFF334155)
                      : const Color(0xFFB91C1C),
                ),
              ),
            ),
            const SizedBox(width: 10),
            FilledButton.icon(
              onPressed: _isImportingPhoto ? null : _showImportOptions,
              icon: _isImportingPhoto
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.image_rounded, size: 18),
              label: const Text('Pick'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const headerColors = [
      Color(0xFF93C5FD),
      Color(0xFF60A5FA),
      Color(0xFF3B82F6),
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isImportingPhoto ? null : _showImportOptions,
        icon: _isImportingPhoto
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.document_scanner_rounded),
        label: Text(_isImportingPhoto
            ? 'Reading'
            : FeatureFlags.classTimetableImageImportReady
                ? 'Photo OCR'
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
                        'CLASS SETUP',
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
                          color: const Color(0xFF378ADD),
                          text: days[i],
                          isActive: isSel,
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 12),
                _buildModeTabs(),
                _buildPhotoOcrPanel(),
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
                                'Set Your Weekly Class Schedule',
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
                                    Text('Your Fixed Classes.',
                                        style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF1E293B),
                                            letterSpacing: -0.5)),
                                    SizedBox(height: 6),
                                    Text(
                                        'Stay on top of your semester with a clear timetable.',
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
                                            ClassRoutineBlock item =
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
