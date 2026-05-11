import 'dart:async' show unawaited;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus2/core/constants/event_names.dart';
import 'package:optivus2/core/providers.dart';
import 'package:optivus2/models/fixed_schedule_validation.dart';
import 'package:optivus2/providers/routine_provider.dart';

const double kHourHeight = 60.0;
const double kLeftOffset = 64.0;

class FixedScheduleEditor extends ConsumerStatefulWidget {
  final List<FixedScheduleTemplate> initialTemplates;
  final void Function(List<FixedScheduleTemplate> templates)? onChanged;

  const FixedScheduleEditor({
    super.key,
    required this.initialTemplates,
    this.onChanged,
  });

  @override
  ConsumerState<FixedScheduleEditor> createState() =>
      _FixedScheduleEditorState();
}

class _FixedScheduleEditorState extends ConsumerState<FixedScheduleEditor> {
  late List<FixedScheduleTemplate> _templates;
  bool _allowOverlap = false;

  final List<Color> _cycleColors = [
    const Color(0xFFF43F5E),
    const Color(0xFF14B8A6),
    const Color(0xFF8B5CF6),
    const Color(0xFF3B82F6),
    const Color(0xFFF59E0B),
    const Color(0xFF10B981),
  ];
  int _colorIndex = 0;
  final Map<String, Color> _blockColors = {};

  Color _colorFor(String id) => _blockColors.putIfAbsent(
      id, () => _cycleColors[_colorIndex++ % _cycleColors.length]);

  @override
  void initState() {
    super.initState();
    _templates = List.from(widget.initialTemplates);
    // Pre-assign colors for existing templates so they're stable
    for (final t in _templates) {
      _colorFor(t.templateId);
    }
  }

  void _notify() => widget.onChanged?.call(List.unmodifiable(_templates));

  // ── Time helpers ──────────────────────────────────────────────────────────

  static TimeOfDay _parseTod(String s) {
    try {
      final p = s.split(':');
      return TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
    } catch (_) {
      return const TimeOfDay(hour: 9, minute: 0);
    }
  }

  static String _formatTod(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}';

  static int _toMinutes(String s) {
    final p = s.split(':');
    return int.parse(p[0]) * 60 + int.parse(p[1]);
  }

  static String _fromMinutes(int m) {
    final clamped = m.clamp(0, 1439);
    return '${(clamped ~/ 60).toString().padLeft(2, '0')}:'
        '${(clamped % 60).toString().padLeft(2, '0')}';
  }

  static String _formatAmPm(String hhmm) {
    final p = hhmm.split(':');
    int h = int.parse(p[0]);
    int m = int.parse(p[1]);
    final ampm = h >= 12 ? 'PM' : 'AM';
    int dh = h % 12;
    if (dh == 0) dh = 12;
    return '$dh:${m.toString().padLeft(2, '0')} $ampm';
  }

  int _durationMin(FixedScheduleTemplate t) {
    final s = _parseTod(t.startTime);
    final e = _parseTod(t.endTime);
    int d = (e.hour * 60 + e.minute) - (s.hour * 60 + s.minute);
    if (d <= 0) d += 1440;
    return d;
  }

  double _blockTop(FixedScheduleTemplate t) =>
      _toMinutes(t.startTime) / 60 * kHourHeight;

  double _blockHeight(FixedScheduleTemplate t) =>
      _durationMin(t) / 60 * kHourHeight;

  static const _validRepeatRules = ['daily', 'weekly:1,2,3,4,5', 'weekly:6,7'];
  static String _safeRepeat(String r) =>
      _validRepeatRules.contains(r) ? r : 'daily';

  // ── Icon inference ────────────────────────────────────────────────────────

  static IconData _iconFor(FixedScheduleTemplate t) {
    final text = '${t.title} ${t.category}'.toLowerCase();
    if (_any(text, ['sleep', 'bed', 'rest', 'nap'])) return Icons.bed_rounded;
    if (_any(text, [
      'gym',
      'workout',
      'exercise',
      'fitness',
      'yoga',
      'run',
      'sport',
      'train'
    ])) {
      return Icons.fitness_center_rounded;
    }
    if (_any(text, ['work', 'office', 'job', 'meeting', 'desk', 'task'])) {
      return Icons.work_rounded;
    }
    if (_any(text,
        ['school', 'study', 'learn', 'class', 'course', 'read', 'book'])) {
      return Icons.school_rounded;
    }
    if (_any(text, [
      'eat',
      'food',
      'meal',
      'breakfast',
      'lunch',
      'dinner',
      'cook',
      'snack'
    ])) {
      return Icons.restaurant_rounded;
    }
    if (_any(text, ['meditat', 'mindful', 'breathe', 'relax'])) {
      return Icons.self_improvement_rounded;
    }
    if (_any(text, ['walk', 'commute', 'travel', 'drive'])) {
      return Icons.directions_walk_rounded;
    }
    if (_any(text, ['shower', 'bath', 'hygiene', 'groom'])) {
      return Icons.shower_rounded;
    }
    if (_any(text, ['social', 'family', 'friend', 'call', 'chat'])) {
      return Icons.people_rounded;
    }
    return Icons.schedule_rounded;
  }

  static bool _any(String text, List<String> keywords) =>
      keywords.any((k) => text.contains(k));

  // ── Drag handlers ─────────────────────────────────────────────────────────

  void _onTopTapeDrag(int index, DragUpdateDetails d) {
    final deltaMin = (d.delta.dy / kHourHeight * 60).round();
    final t = _templates[index];
    final startMin = _toMinutes(t.startTime) + deltaMin;
    final endMin = _toMinutes(t.endTime);
    if (startMin < 0 || startMin >= endMin) return;
    setState(() {
      _templates[index] = t.copyWith(
        startTime: _fromMinutes(startMin.clamp(0, 1439)),
        updatedAt: DateTime.now().toIso8601String(),
      );
    });
    _notify();
  }

  void _onBottomTapeDrag(int index, DragUpdateDetails d) {
    final deltaMin = (d.delta.dy / kHourHeight * 60).round();
    final t = _templates[index];
    final startMin = _toMinutes(t.startTime);
    final endMin = _toMinutes(t.endTime) + deltaMin;
    if (endMin <= startMin || endMin > 1439) return;
    setState(() {
      _templates[index] = t.copyWith(
        endTime: _fromMinutes(endMin.clamp(0, 1439)),
        updatedAt: DateTime.now().toIso8601String(),
      );
    });
    _notify();
  }

  // ── Events ────────────────────────────────────────────────────────────────

  Future<void> _emitCreated(FixedScheduleTemplate t) =>
      ref.read(eventServiceProvider).emit(
        eventName: EventNames.routineTemplateCreated,
        source: 'fixed_schedule_editor',
        payload: {'templateId': t.templateId, 'routineType': 'fixed_schedule'},
      );

  Future<void> _emitUpdated(FixedScheduleTemplate t) =>
      ref.read(eventServiceProvider).emit(
        eventName: EventNames.routineTemplateUpdated,
        source: 'fixed_schedule_editor',
        payload: {'templateId': t.templateId, 'routineType': 'fixed_schedule'},
      );

  Future<void> _emitDeleted(String templateId) =>
      ref.read(eventServiceProvider).emit(
        eventName: EventNames.routineTemplateDeleted,
        source: 'fixed_schedule_editor',
        payload: {'templateId': templateId, 'routineType': 'fixed_schedule'},
      );

  // ── Edit dialog ───────────────────────────────────────────────────────────

  Future<void> _showEditDialog({
    FixedScheduleTemplate? existing,
    required int index,
    TimeOfDay? initialStart,
  }) async {
    final isNew = existing == null;

    TimeOfDay startTod = isNew
        ? (initialStart ?? const TimeOfDay(hour: 9, minute: 0))
        : _parseTod(existing.startTime);
    TimeOfDay endTod = isNew
        ? TimeOfDay(
            hour: ((initialStart?.hour ?? 9) + 1) % 24,
            minute: initialStart?.minute ?? 0,
          )
        : _parseTod(existing.endTime);
    String repeatRule =
        _safeRepeat(normalizeFixedScheduleRepeatRule(existing?.repeatRule));

    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final categoryCtrl = TextEditingController(text: existing?.category ?? '');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    bool reminderEnabled = existing?.reminderEnabled ?? false;

    int curDurMin() {
      int d = (endTod.hour * 60 + endTod.minute) -
          (startTod.hour * 60 + startTod.minute);
      if (d <= 0) d += 1440;
      return d;
    }

    String curDurStr() {
      final m = curDurMin();
      final h = m ~/ 60;
      final min = m % 60;
      if (h > 0 && min > 0) return '${h}h ${min}m';
      if (h > 0) return '${h}h';
      return '${min}m';
    }

    final durationCtrl = TextEditingController(text: curDurMin().toString());
    String? errorMsg;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(builder: (_, setModal) {
          return Padding(
            padding:
                EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(color: Color(0x1A000000), blurRadius: 20)
                ],
              ),
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isNew ? 'Add Task' : 'Edit Task',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F111A),
                          ),
                        ),
                        if (!isNew)
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.red),
                            onPressed: () {
                              final id = existing.templateId;
                              setState(() => _templates.removeAt(index));
                              _notify();
                              unawaited(_emitDeleted(id));
                              Navigator.pop(ctx);
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: titleCtrl,
                      decoration: _inputDecor('Task Title'),
                      onChanged: (_) {
                        if (errorMsg != null) setModal(() => errorMsg = null);
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final t = await showTimePicker(
                                  context: ctx, initialTime: startTod);
                              if (t != null) {
                                setModal(() {
                                  startTod = t;
                                  final dur =
                                      int.tryParse(durationCtrl.text.trim());
                                  if (dur != null && dur > 0 && dur < 1440) {
                                    final total =
                                        (t.hour * 60 + t.minute + dur) % 1440;
                                    endTod = TimeOfDay(
                                        hour: total ~/ 60, minute: total % 60);
                                  }
                                  errorMsg = null;
                                });
                              }
                            },
                            child: _timeTile(ctx, 'Start Time', startTod),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final t = await showTimePicker(
                                  context: ctx, initialTime: endTod);
                              if (t != null) {
                                setModal(() {
                                  endTod = t;
                                  durationCtrl.text = curDurMin().toString();
                                  errorMsg = null;
                                });
                              }
                            },
                            child: _timeTile(ctx, 'End Time', endTod),
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Duration: ${curDurStr()}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: durationCtrl,
                      keyboardType: TextInputType.number,
                      decoration: _inputDecor('Duration (minutes)'),
                      onChanged: (v) {
                        final dur = int.tryParse(v.trim());
                        if (dur == null || dur <= 0 || dur >= 1440) {
                          setModal(() =>
                              errorMsg = 'Duration must be 1 to 1439 minutes.');
                          return;
                        }
                        final total =
                            (startTod.hour * 60 + startTod.minute + dur) % 1440;
                        setModal(() {
                          endTod =
                              TimeOfDay(hour: total ~/ 60, minute: total % 60);
                          errorMsg = null;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    InputDecorator(
                      decoration: _inputDecor('Repeat'),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: repeatRule,
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(
                                value: 'daily', child: Text('Daily')),
                            DropdownMenuItem(
                                value: 'weekly:1,2,3,4,5',
                                child: Text('Weekdays')),
                            DropdownMenuItem(
                                value: 'weekly:6,7', child: Text('Weekends')),
                          ],
                          onChanged: (v) {
                            if (v != null) setModal(() => repeatRule = v);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: categoryCtrl,
                      decoration: _inputDecor('Category (Optional)'),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: notesCtrl,
                      maxLines: 2,
                      decoration: _inputDecor('Notes (Optional)'),
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile.adaptive(
                      title: const Text('Reminder',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0F111A))),
                      subtitle: const Text('5 minutes before start',
                          style: TextStyle(
                              fontSize: 13, color: Color(0xFF64748B))),
                      value: reminderEnabled,
                      onChanged: (v) => setModal(() => reminderEnabled = v),
                      contentPadding: EdgeInsets.zero,
                      activeTrackColor: const Color(0xFF3B82F6),
                    ),
                    if (errorMsg != null) ...[
                      const SizedBox(height: 16),
                      Text(errorMsg!,
                          style: const TextStyle(
                              color: Colors.red, fontWeight: FontWeight.w500)),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3B82F6),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () {
                          final dur = int.tryParse(durationCtrl.text.trim());
                          if (dur == null || dur <= 0 || dur >= 1440) {
                            setModal(() => errorMsg =
                                'Duration must be 1 to 1439 minutes.');
                            return;
                          }
                          final total =
                              (startTod.hour * 60 + startTod.minute + dur) %
                                  1440;
                          endTod =
                              TimeOfDay(hour: total ~/ 60, minute: total % 60);

                          final startTime = _formatTod(startTod);
                          final endTime = _formatTod(endTod);
                          final validationError =
                              validateFixedScheduleTemplateDraft(
                            title: titleCtrl.text,
                            startTime: startTime,
                            endTime: endTime,
                            existingTemplates: _templates,
                            currentTemplateId: existing?.templateId,
                            allowOverlap: _allowOverlap,
                          );
                          if (validationError != null) {
                            setModal(() => errorMsg = validationError);
                            return;
                          }

                          final now = DateTime.now().toIso8601String();
                          final templateMap = normalizeFixedScheduleTemplateMap(
                            {
                              ...?existing?.toMap(),
                              'templateId': existing?.templateId ??
                                  'sched_${DateTime.now().microsecondsSinceEpoch}',
                              'title': titleCtrl.text.trim(),
                              'startTime': startTime,
                              'endTime': endTime,
                              'repeatRule': repeatRule,
                              'category': categoryCtrl.text.trim(),
                              'notes': notesCtrl.text.trim(),
                              'isActive': existing?.isActive ?? true,
                              'reminderEnabled': reminderEnabled,
                              'reminderOffsetMinutes':
                                  existing?.reminderOffsetMinutes ?? 5,
                              'createdAt': existing?.createdAt ?? now,
                              'updatedAt': existing?.updatedAt ?? now,
                            },
                            index: isNew ? _templates.length : index,
                            touchUpdatedAt: true,
                          );
                          final template =
                              FixedScheduleTemplate.fromMap(templateMap);

                          setState(() {
                            if (isNew) {
                              _templates.add(template);
                              _colorFor(template.templateId);
                            } else {
                              _templates[index] = template;
                            }
                          });
                          _notify();
                          unawaited(isNew
                              ? _emitCreated(template)
                              : _emitUpdated(template));
                          Navigator.pop(ctx);
                        },
                        child: Text(
                          isNew ? 'Create Task' : 'Save Task',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        });
      },
    );

    titleCtrl.dispose();
    categoryCtrl.dispose();
    notesCtrl.dispose();
    durationCtrl.dispose();
  }

  // ── UI helpers ────────────────────────────────────────────────────────────

  InputDecoration _inputDecor(String label) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFFF1F5F9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      );

  Widget _timeTile(BuildContext ctx, String label, TimeOfDay time) => Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            const SizedBox(height: 4),
            Text(time.format(ctx),
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ],
        ),
      );

  // ── Timeline building ─────────────────────────────────────────────────────

  Widget _buildHeader() => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Checkbox(
                value: _allowOverlap,
                onChanged: (v) => setState(() => _allowOverlap = v ?? false),
                activeColor: const Color(0xFF3B82F6),
              ),
              const Text(
                'Allow Overlaps',
                style: TextStyle(
                    fontWeight: FontWeight.w600, color: Color(0xFF334155)),
              ),
            ],
          ),
          FilledButton.icon(
            onPressed: () => _showEditDialog(index: _templates.length),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Task'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      );

  List<Widget> _buildRulerLines() => List.generate(24, (i) {
        final label = i == 0
            ? '12 AM'
            : (i < 12 ? '$i AM' : (i == 12 ? '12 PM' : '${i - 12} PM'));
        return Positioned(
          top: i * kHourHeight - 10,
          left: 16,
          width: 44,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(label,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  )),
              const SizedBox(width: 8),
              Container(width: 4, height: 1.5, color: const Color(0xFFCBD5E1)),
            ],
          ),
        );
      });

  Widget _buildGlassPillar() => Positioned(
        top: 0,
        bottom: 0,
        left: 60,
        width: 10,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.9), width: 1.2),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Stack(
                children: List.generate(
                    24,
                    (i) => Positioned(
                          top: i * kHourHeight - 0.75,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Container(
                              width: 4,
                              height: 1.5,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                        )),
              ),
            ),
          ),
        ),
      );

  Widget _buildDroplet(double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(size),
          boxShadow: [
            BoxShadow(
                color: Colors.white.withValues(alpha: 0.4), blurRadius: 6),
          ],
        ),
      );

  Widget _buildTapeWithDrops({GestureDragUpdateCallback? onDrag}) =>
      MouseRegion(
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
                    child: const SizedBox.expand(),
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

  Widget _buildColoredBlock(int index, FixedScheduleTemplate t) {
    final top = _blockTop(t);
    final height = _blockHeight(t);
    final color = _colorFor(t.templateId);
    final icon = _iconFor(t);
    final timeText =
        'Start: ${_formatAmPm(t.startTime)} | End: ${_formatAmPm(t.endTime)}';

    return Positioned(
      top: top,
      left: kLeftOffset,
      right: 0,
      height: height,
      child: GestureDetector(
        onTap: () => _showEditDialog(existing: t, index: index),
        onLongPress: () => _showEditDialog(existing: t, index: index),
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
                      color.withValues(alpha: 0.3),
                      color.withValues(alpha: 0.05),
                    ],
                  ),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.8), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                        color: color.withValues(alpha: 0.2),
                        blurRadius: 16,
                        offset: const Offset(0, 6)),
                    BoxShadow(
                        color: Colors.white.withValues(alpha: 0.7),
                        blurRadius: 8,
                        offset: const Offset(-2, -2)),
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
                            horizontal: 16, vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Icon(icon,
                                    color: color.withValues(alpha: 0.9),
                                    size: 24),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    t.title,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF1E293B),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const Icon(Icons.more_vert_rounded,
                                    color: Color(0xFF64748B), size: 20),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Container(
                              height: 32,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.8),
                                    width: 1),
                              ),
                              child: Center(
                                child: Text(
                                  timeText,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF334155),
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
            ),
            // Top tape
            Positioned(
              top: -8,
              left: 0,
              right: 0,
              child: Center(
                child: _buildTapeWithDrops(
                    onDrag: (d) => _onTopTapeDrag(index, d)),
              ),
            ),
            // Bottom tape
            Positioned(
              bottom: -8,
              left: 0,
              right: 0,
              child: Center(
                child: _buildTapeWithDrops(
                    onDrag: (d) => _onBottomTapeDrag(index, d)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniBlock(int index, FixedScheduleTemplate t) {
    final top = _blockTop(t) + 4;
    const height = kHourHeight - 8;
    final icon = _iconFor(t);
    final color = _colorFor(t.templateId);

    return Positioned(
      top: top,
      left: kLeftOffset,
      right: 0,
      height: height,
      child: GestureDetector(
        onTap: () => _showEditDialog(existing: t, index: index),
        onLongPress: () => _showEditDialog(existing: t, index: index),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(height / 2),
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.8), width: 1.5),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 2)),
              BoxShadow(
                  color: Colors.white.withValues(alpha: 0.6),
                  blurRadius: 4,
                  offset: const Offset(-1, -1)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(height / 2),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(icon, color: color.withValues(alpha: 0.8), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        t.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF334155),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.more_vert_rounded,
                        color: Color(0xFF94A3B8), size: 18),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddButton(double startHour) {
    const height = 36.0;
    final top = startHour * kHourHeight - height / 2;
    final startTod = TimeOfDay(
      hour: startHour.floor(),
      minute: ((startHour - startHour.floor()) * 60).round(),
    );

    return Positioned(
      top: top,
      left: kLeftOffset,
      right: 0,
      height: height,
      child: GestureDetector(
        onTap: () => _showEditDialog(
          index: _templates.length,
          initialStart: startTod,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(height / 2),
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.7), width: 1.5),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 2)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(height / 2),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: const Center(
                child:
                    Icon(Icons.add_rounded, color: Color(0xFF8B5CF6), size: 28),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildBlocks() {
    final widgets = <Widget>[];
    for (int i = 0; i < _templates.length; i++) {
      final t = _templates[i];
      if (_durationMin(t) < 60) {
        widgets.add(_buildMiniBlock(i, t));
      } else {
        widgets.add(_buildColoredBlock(i, t));
      }
    }
    return widgets;
  }

  List<Widget> _buildAddButtons() {
    if (_templates.isNotEmpty) return [];
    return [
      _buildAddButton(7.5),
      _buildAddButton(12.5),
      _buildAddButton(18.0),
    ];
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Column(
      children: [
        _buildHeader(),
        const SizedBox(height: 8),
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.4),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(32)),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.8), width: 1.5),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 12,
                    offset: const Offset(0, -4)),
              ],
            ),
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(32)),
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
                        ..._buildRulerLines(),
                        _buildGlassPillar(),
                        ..._buildBlocks(),
                        ..._buildAddButtons(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
