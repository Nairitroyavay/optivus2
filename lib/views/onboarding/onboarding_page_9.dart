import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus2/providers/onboarding_provider.dart';
import 'package:optivus2/views/screens/onboarding_screen.dart';

class ScheduleBlock {
  final String templateId;
  String title;
  TimeOfDay startTime;
  TimeOfDay endTime;
  String category;
  String notes;
  final String routineType;
  final String repeatRule;
  bool isActive;
  final String createdAt;
  String updatedAt;

  ScheduleBlock({
    required this.templateId,
    required this.title,
    required this.startTime,
    required this.endTime,
    this.category = '',
    this.notes = '',
    this.routineType = 'fixed_schedule',
    this.repeatRule = 'daily',
    this.isActive = true,
    String? createdAt,
    String? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now().toIso8601String(),
        updatedAt = updatedAt ?? DateTime.now().toIso8601String();

  Map<String, dynamic> toMap() => {
        'templateId': templateId,
        'title': title,
        'routineType': routineType,
        'startTime':
            '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}',
        'endTime':
            '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}',
        'repeatRule': repeatRule,
        'category': category,
        'notes': notes,
        'isActive': isActive,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory ScheduleBlock.fromMap(Map<String, dynamic> map) {
    TimeOfDay parseTime(String t) {
      try {
        final p = t.split(':');
        return TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
      } catch (_) {
        return const TimeOfDay(hour: 9, minute: 0);
      }
    }

    return ScheduleBlock(
      templateId: map['templateId'] ?? '',
      title: map['title'] ?? '',
      startTime: parseTime(map['startTime'] ?? '09:00'),
      endTime: parseTime(map['endTime'] ?? '10:00'),
      category: map['category'] ?? '',
      notes: map['notes'] ?? '',
      routineType: map['routineType'] ?? 'fixed_schedule',
      repeatRule: map['repeatRule'] ?? 'daily',
      isActive: map['isActive'] ?? true,
      createdAt: map['createdAt'],
      updatedAt: map['updatedAt'],
    );
  }

  int get startMinutes => startTime.hour * 60 + startTime.minute;
  int get endMinutes => endTime.hour * 60 + endTime.minute;
  int get durationMinutes {
    int mins = endMinutes - startMinutes;
    if (mins <= 0) mins += 1440;
    return mins;
  }

  /// Human-readable duration string (e.g. "1h 30m").
  String get durationString {
    final mins = durationMinutes;
    final h = mins ~/ 60;
    final m = mins % 60;
    if (h > 0 && m > 0) return '${h}h ${m}m';
    if (h > 0) return '${h}h';
    return '${m}m';
  }

  void setDurationMinutes(int minutes) {
    final total = (startMinutes + minutes) % 1440;
    endTime = TimeOfDay(hour: total ~/ 60, minute: total % 60);
  }

  bool overlapsWith(ScheduleBlock other) {
    final s1 = startMinutes;
    final e1 =
        endMinutes <= s1 ? endMinutes + 1440 : endMinutes; // handle overnight
    final s2 = other.startMinutes;
    final e2 =
        other.endMinutes <= s2 ? other.endMinutes + 1440 : other.endMinutes;

    // Standard overlap check: s1 < e2 && s2 < e1
    // Must also check the other's potential overnight wrap relative to us
    bool standardOverlap(int startA, int endA, int startB, int endB) {
      return startA < endB && startB < endA;
    }

    if (standardOverlap(s1, e1, s2, e2)) return true;
    if (e1 > 1440 && standardOverlap(s1 - 1440, e1 - 1440, s2, e2)) return true;
    if (e2 > 1440 && standardOverlap(s1, e1, s2 - 1440, e2 - 1440)) return true;

    return false;
  }
}

class OnboardingPage9 extends ConsumerStatefulWidget {
  const OnboardingPage9({super.key});

  @override
  ConsumerState<OnboardingPage9> createState() => _OnboardingPage9State();
}

class _OnboardingPage9State extends ConsumerState<OnboardingPage9> {
  late List<ScheduleBlock> _blocks = [];
  bool _allowOverlap = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final savedItems = ref.read(onboardingProvider).fixedSchedule;
      setState(() {
        _blocks = savedItems.map((m) => ScheduleBlock.fromMap(m)).toList();
      });
    });
  }

  void _updateProvider() {
    ref
        .read(onboardingProvider.notifier)
        .updateFixedSchedule(_blocks.map((e) => e.toMap()).toList());
    // Debounced save to Firestore so data persists across app restarts
    ref.read(onboardingProvider.notifier).saveToFirestoreDebounced(9);
  }

  Future<void> _showEditDialog(int? index) async {
    final isNew = index == null;
    ScheduleBlock block;
    if (isNew) {
      block = ScheduleBlock(
        templateId: 'sched_${DateTime.now().microsecondsSinceEpoch}',
        title: '',
        startTime: const TimeOfDay(hour: 9, minute: 0),
        endTime: const TimeOfDay(hour: 10, minute: 0),
      );
    } else {
      final existing = _blocks[index];
      block = ScheduleBlock(
        templateId: existing.templateId,
        title: existing.title,
        startTime: existing.startTime,
        endTime: existing.endTime,
        category: existing.category,
        notes: existing.notes,
        routineType: existing.routineType,
        repeatRule: existing.repeatRule,
        isActive: existing.isActive,
        createdAt: existing.createdAt,
        updatedAt: existing.updatedAt,
      );
    }

    final titleCtrl = TextEditingController(text: block.title);
    final categoryCtrl = TextEditingController(text: block.category);
    final notesCtrl = TextEditingController(text: block.notes);
    final durationCtrl =
        TextEditingController(text: block.durationMinutes.toString());
    String? errorMessage;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setModalState) {
          return Padding(
            padding:
                EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 20)
                ],
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(isNew ? 'Add Task' : 'Edit Task',
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F111A))),
                      if (!isNew)
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.red),
                          onPressed: () {
                            setState(() => _blocks.removeAt(index));
                            _updateProvider();
                            Navigator.pop(ctx);
                          },
                        )
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: titleCtrl,
                    decoration: InputDecoration(
                      labelText: 'Task Title',
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                    ),
                    onChanged: (_) {
                      if (errorMessage != null) {
                        setModalState(() => errorMessage = null);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final t = await showTimePicker(
                                context: ctx, initialTime: block.startTime);
                            if (t != null) {
                              setModalState(() {
                                block.startTime = t;
                                final minutes =
                                    int.tryParse(durationCtrl.text.trim());
                                if (minutes != null &&
                                    minutes > 0 &&
                                    minutes < 1440) {
                                  block.setDurationMinutes(minutes);
                                }
                                errorMessage = null;
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 16, horizontal: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Start Time',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF64748B))),
                                const SizedBox(height: 4),
                                Text(block.startTime.format(ctx),
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final t = await showTimePicker(
                                context: ctx, initialTime: block.endTime);
                            if (t != null) {
                              setModalState(() {
                                block.endTime = t;
                                durationCtrl.text =
                                    block.durationMinutes.toString();
                                errorMessage = null;
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 16, horizontal: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('End Time',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF64748B))),
                                const SizedBox(height: 4),
                                Text(block.endTime.format(ctx),
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Duration indicator
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Duration: ${block.durationString}',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF94A3B8)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: durationCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Duration (minutes)',
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                    ),
                    onChanged: (value) {
                      final minutes = int.tryParse(value.trim());
                      if (minutes == null || minutes <= 0 || minutes >= 1440) {
                        setModalState(() => errorMessage =
                            'Duration must be 1 to 1439 minutes.');
                        return;
                      }
                      setModalState(() {
                        block.setDurationMinutes(minutes);
                        errorMessage = null;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: categoryCtrl,
                    decoration: InputDecoration(
                      labelText: 'Category (Optional)',
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: notesCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Notes (Optional)',
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                    ),
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Text(errorMessage!,
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
                        if (titleCtrl.text.trim().isEmpty) {
                          setModalState(
                              () => errorMessage = 'Title cannot be blank.');
                          return;
                        }
                        if (block.startMinutes == block.endMinutes) {
                          setModalState(() => errorMessage =
                              'Start and end time cannot be the same.');
                          return;
                        }
                        final durationMinutes =
                            int.tryParse(durationCtrl.text.trim());
                        if (durationMinutes == null ||
                            durationMinutes <= 0 ||
                            durationMinutes >= 1440) {
                          setModalState(() => errorMessage =
                              'Duration must be 1 to 1439 minutes.');
                          return;
                        }
                        block.setDurationMinutes(durationMinutes);

                        // Overlap validation
                        if (!_allowOverlap) {
                          bool hasOverlap = false;
                          for (int i = 0; i < _blocks.length; i++) {
                            if (!isNew && i == index) continue;
                            if (block.overlapsWith(_blocks[i])) {
                              hasOverlap = true;
                              break;
                            }
                          }
                          if (hasOverlap) {
                            setModalState(() => errorMessage =
                                'Time overlaps with another task. Adjust times or allow overlaps.');
                            return;
                          }
                        }

                        block.title = titleCtrl.text.trim();
                        block.category = categoryCtrl.text.trim();
                        block.notes = notesCtrl.text.trim();
                        block.updatedAt = DateTime.now().toIso8601String();

                        setState(() {
                          if (isNew) {
                            _blocks.add(block);
                          } else {
                            _blocks[index] = block;
                          }
                        });
                        _updateProvider();
                        Navigator.pop(ctx);
                      },
                      child: Text(isNew ? 'Create Task' : 'Save Task',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
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

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top + kIndicatorOverlayH;
    final bottomPadding =
        MediaQuery.of(context).padding.bottom + kButtonOverlayH;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, topPadding + 16, 20, bottomPadding + 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RichText(
            textAlign: TextAlign.center,
            text: const TextSpan(
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F111A),
                height: 1.15,
                letterSpacing: -1.0,
              ),
              children: [
                TextSpan(text: 'Set Your '),
                TextSpan(
                  text: 'Fixed Schedule',
                  style: TextStyle(color: Color(0xFF3B82F6)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Add your daily non-negotiables (work, classes, sleep).',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Checkbox(
                    value: _allowOverlap,
                    onChanged: (val) =>
                        setState(() => _allowOverlap = val ?? false),
                    activeColor: const Color(0xFF3B82F6),
                  ),
                  const Text('Allow Overlaps',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF334155))),
                ],
              ),
              FilledButton.icon(
                onPressed: () => _showEditDialog(null),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add Task'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _blocks.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.calendar_month_rounded,
                            size: 64,
                            color: Colors.blueGrey.withValues(alpha: 0.2)),
                        const SizedBox(height: 16),
                        const Text('No fixed tasks yet.',
                            style: TextStyle(
                                color: Colors.blueGrey,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  )
                : ReorderableListView.builder(
                    itemCount: _blocks.length,
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (newIndex > oldIndex) newIndex -= 1;
                        final item = _blocks.removeAt(oldIndex);
                        _blocks.insert(newIndex, item);
                      });
                      _updateProvider();
                    },
                    itemBuilder: (context, index) {
                      final block = _blocks[index];
                      return Container(
                        key: ValueKey(block.templateId),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 10,
                                offset: const Offset(0, 4)),
                          ],
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          title: Text(block.title,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  color: Color(0xFF1E293B))),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                      '${block.startTime.format(context)} – ${block.endTime.format(context)}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF64748B))),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEFF6FF),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(block.durationString,
                                        style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF3B82F6))),
                                  ),
                                ],
                              ),
                              if (block.category.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(block.category,
                                    style: const TextStyle(
                                        color: Color(0xFF94A3B8),
                                        fontSize: 13)),
                              ]
                            ],
                          ),
                          trailing: const Icon(Icons.drag_handle_rounded,
                              color: Color(0xFFCBD5E1)),
                          onTap: () => _showEditDialog(index),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
