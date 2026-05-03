import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:optivus2/core/errors/app_errors.dart';
import 'package:optivus2/core/liquid_ui/liquid_ui.dart';
import 'package:optivus2/core/providers.dart';
import 'package:optivus2/core/utils/uuid_generator.dart';
import 'package:optivus2/models/habit_model.dart';

class HabitEditorScreen extends ConsumerStatefulWidget {
  final String? habitId;

  const HabitEditorScreen({super.key, this.habitId});

  @override
  ConsumerState<HabitEditorScreen> createState() => _HabitEditorScreenState();
}

class _HabitEditorScreenState extends ConsumerState<HabitEditorScreen> {
  final _nameController = TextEditingController();
  final _targetController = TextEditingController();
  final _unitController = TextEditingController(text: 'count');
  final _moneyController = TextEditingController();
  final _accountabilityController = TextEditingController();
  final _reminderTimeController = TextEditingController(text: '09:00');

  HabitModel? _existing;
  HabitKind _kind = HabitKind.good;
  BadHabitGoalType _badGoalType = BadHabitGoalType.eliminate;
  String _category = 'generic';
  final Set<int> _scheduleDays = {1, 2, 3, 4, 5, 6, 7};
  bool _remindersEnabled = false;
  bool _loading = false;
  bool _saving = false;
  String? _error;

  bool get _isEditing => widget.habitId != null;

  static const _categories = [
    'generic',
    'water',
    'hydration',
    'meditation',
    'reading',
    'exercise',
    'sleep',
    'steps',
    'nutrition',
    'smoking',
    'screen_time',
    'junk_food',
    'procrastination',
    'money_saving',
    'routine_completion',
  ];

  @override
  void initState() {
    super.initState();
    if (_isEditing) _loadHabit();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    _unitController.dispose();
    _moneyController.dispose();
    _accountabilityController.dispose();
    _reminderTimeController.dispose();
    super.dispose();
  }

  Future<void> _loadHabit() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final habit =
          await ref.read(habitServiceProvider).getHabit(widget.habitId!);
      if (habit == null) {
        setState(() => _error = 'Habit not found.');
        return;
      }

      _existing = habit;
      _kind = habit.kind;
      _badGoalType = habit.goalType ?? BadHabitGoalType.eliminate;
      _category = habit.trackerType;
      _nameController.text = habit.name;
      _targetController.text =
          (habit.kind == HabitKind.good ? habit.dailyGoal : habit.target)
                  ?.toString() ??
              '';
      _unitController.text = habit.unit;
      _moneyController.text = habit.costPerUnit?.toString() ?? '';
      _accountabilityController.text = habit.accountability ?? '';
      _remindersEnabled = habit.remindersEnabled;
      _reminderTimeController.text = habit.reminderTime ?? '09:00';
      _scheduleDays
        ..clear()
        ..addAll(habit.scheduleDays.isEmpty
            ? const [1, 2, 3, 4, 5, 6, 7]
            : habit.scheduleDays);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_saving) return;

    final name = _nameController.text.trim();
    final targetText = _targetController.text.trim();
    final target = targetText.isEmpty ? null : num.tryParse(targetText);
    final costText = _moneyController.text.trim();
    final cost = costText.isEmpty ? null : num.tryParse(costText);

    if (name.isEmpty) {
      _showError('Name is required.');
      return;
    }
    if (targetText.isNotEmpty && (target == null || target < 0)) {
      _showError('Target must be a non-negative number.');
      return;
    }
    if (_kind == HabitKind.good && (target == null || target <= 0)) {
      _showError('Good habits need a target greater than 0.');
      return;
    }
    if (_kind == HabitKind.bad &&
        _badGoalType == BadHabitGoalType.reduceToTarget &&
        target == null) {
      _showError('Reduction goals need a target.');
      return;
    }
    if (costText.isNotEmpty && (cost == null || cost < 0)) {
      _showError('Money value must be a non-negative number.');
      return;
    }
    if (_remindersEnabled && _parseReminderTime() == null) {
      _showError('Use reminder time as HH:mm.');
      return;
    }

    setState(() => _saving = true);
    try {
      final now = DateTime.now();
      final existing = _existing;
      final id = existing?.id ?? '${_category}_${generateShortId()}';
      final accountability = _accountabilityController.text.trim();
      final reminderTime = _reminderTimeController.text.trim();

      final habit = HabitModel(
        id: id,
        name: name,
        kind: _kind,
        unit: _unitController.text.trim().isEmpty
            ? 'count'
            : _unitController.text.trim(),
        trackerType: _category,
        dailyGoal: _kind == HabitKind.good ? target : null,
        goalType: _kind == HabitKind.bad ? _badGoalType : null,
        target: _kind == HabitKind.bad ? target : null,
        costPerUnit: cost,
        scheduleDays: _scheduleDays.toList()..sort(),
        remindersEnabled: _remindersEnabled,
        reminderTime: _remindersEnabled ? reminderTime : null,
        accountability: accountability.isEmpty ? null : accountability,
        identityTags: existing?.identityTags ?? const [],
        emoji: existing?.emoji,
        color: existing?.color,
        state: existing?.state ?? HabitState.active,
        pausedAt: existing?.pausedAt,
        archivedAt: existing?.archivedAt,
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
      );

      if (existing == null) {
        await ref.read(habitServiceProvider).createHabit(habit);
      } else {
        await ref.read(habitServiceProvider).updateHabit(habit);
      }

      await _writeReminderIntent(habit);

      if (mounted) context.go('/habits/${habit.id}');
    } on AppError catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('Failed to save habit: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _writeReminderIntent(HabitModel habit) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw const NotAuthenticatedError();

    final notifId = 'habit_reminder_${habit.id}';
    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('scheduled_notifications')
        .doc(notifId);

    if (!habit.remindersEnabled || habit.reminderTime == null) {
      if (_isEditing) {
        await ref.set({
          'notifId': notifId,
          'category': 'habit_reminder',
          'habitId': habit.id,
          'status': 'cancelled',
          'updatedAt': FieldValue.serverTimestamp(),
          'schemaVersion': 1,
        }, SetOptions(merge: true));
      }
      return;
    }

    await ref.set({
      'notifId': notifId,
      'category': 'habit_reminder',
      'habitId': habit.id,
      'status': 'pending',
      'reminderTime': habit.reminderTime,
      'scheduleDays': habit.scheduleDays,
      'scheduledFor': Timestamp.fromDate(_nextReminderDate()),
      'title': habit.name,
      'body': habit.kind == HabitKind.good
          ? 'Time to log ${habit.name}.'
          : 'Check in on ${habit.name}.',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'schemaVersion': 1,
    }, SetOptions(merge: true));
  }

  DateTime? _parseReminderTime() {
    final match =
        RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(_reminderTimeController.text);
    if (match == null) return null;
    final hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, hour, minute);
  }

  DateTime _nextReminderDate() {
    final today = _parseReminderTime() ?? DateTime.now();
    final now = DateTime.now();
    var candidate = today;
    for (var i = 0; i < 8; i++) {
      final weekday = candidate.weekday;
      if (_scheduleDays.contains(weekday) && candidate.isAfter(now)) {
        return candidate;
      }
      candidate = candidate.add(const Duration(days: 1));
      candidate = DateTime(candidate.year, candidate.month, candidate.day,
          today.hour, today.minute);
    }
    return today.isAfter(now) ? today : today.add(const Duration(days: 1));
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: kCoral),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: kInk,
        title: Text(_isEditing ? 'Edit Habit' : 'Add Habit'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kAmber))
          : _error != null
              ? _ErrorState(message: _error!, onRetry: _loadHabit)
              : ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                  children: [
                    _section(
                      title: 'Basics',
                      child: Column(
                        children: [
                          _SegmentedHabitType(
                            value: _kind,
                            onChanged: (kind) => setState(() => _kind = kind),
                          ),
                          const SizedBox(height: 14),
                          DropdownButtonFormField<String>(
                            initialValue: _categories.contains(_category)
                                ? _category
                                : 'generic',
                            decoration: _inputDecoration('Category'),
                            items: _categories
                                .map((category) => DropdownMenuItem(
                                      value: category,
                                      child:
                                          Text(category.replaceAll('_', ' ')),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _category = value);
                              }
                            },
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _nameController,
                            decoration: _inputDecoration('Name'),
                            textInputAction: TextInputAction.next,
                          ),
                        ],
                      ),
                    ),
                    _section(
                      title: 'Target',
                      child: Column(
                        children: [
                          if (_kind == HabitKind.bad) ...[
                            DropdownButtonFormField<BadHabitGoalType>(
                              initialValue: _badGoalType,
                              decoration: _inputDecoration('Goal type'),
                              items: BadHabitGoalType.values
                                  .map((type) => DropdownMenuItem(
                                        value: type,
                                        child: Text(_badGoalTypeLabel(type)),
                                      ))
                                  .toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _badGoalType = value);
                                }
                              },
                            ),
                            const SizedBox(height: 14),
                          ],
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _targetController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  decoration: _inputDecoration(
                                    _kind == HabitKind.good
                                        ? 'Daily target'
                                        : 'Allowed count',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 120,
                                child: TextField(
                                  controller: _unitController,
                                  decoration: _inputDecoration('Unit'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    _section(
                      title: 'Schedule',
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: List.generate(7, (index) {
                          final day = index + 1;
                          final selected = _scheduleDays.contains(day);
                          return FilterChip(
                            selected: selected,
                            label: Text(_weekdayLabel(day)),
                            selectedColor: kAmber.withValues(alpha: 0.25),
                            checkmarkColor: kInk,
                            onSelected: (value) {
                              setState(() {
                                if (value) {
                                  _scheduleDays.add(day);
                                } else if (_scheduleDays.length > 1) {
                                  _scheduleDays.remove(day);
                                }
                              });
                            },
                          );
                        }),
                      ),
                    ),
                    _section(
                      title: 'Support',
                      child: Column(
                        children: [
                          TextField(
                            controller: _moneyController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration:
                                _inputDecoration('Money value per unit'),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _accountabilityController,
                            decoration:
                                _inputDecoration('Accountability note/person'),
                          ),
                        ],
                      ),
                    ),
                    _section(
                      title: 'Reminders',
                      child: Column(
                        children: [
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            value: _remindersEnabled,
                            title: const Text('Reminder intent'),
                            subtitle: const Text(
                              'Stores a scheduled notification document.',
                            ),
                            onChanged: (value) {
                              setState(() => _remindersEnabled = value);
                            },
                          ),
                          if (_remindersEnabled)
                            TextField(
                              controller: _reminderTimeController,
                              keyboardType: TextInputType.datetime,
                              decoration: _inputDecoration('Time HH:mm'),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        child: LiquidButton(
          label: _saving ? 'Saving...' : 'Save Habit',
          color: kAmber,
          onTap: _saving ? null : _save,
        ),
      ),
    );
  }

  Widget _section({required String title, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: LiquidCard(
        radius: 20,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: kInk,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.74),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.9)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.9)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: kAmber.withValues(alpha: 0.8), width: 2),
      ),
    );
  }

  String _badGoalTypeLabel(BadHabitGoalType type) {
    switch (type) {
      case BadHabitGoalType.eliminate:
        return 'Eliminate';
      case BadHabitGoalType.reduceToTarget:
        return 'Reduce to target';
      case BadHabitGoalType.awarenessOnly:
        return 'Awareness only';
    }
  }

  String _weekdayLabel(int day) {
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return labels[day - 1];
  }
}

class _SegmentedHabitType extends StatelessWidget {
  final HabitKind value;
  final ValueChanged<HabitKind> onChanged;

  const _SegmentedHabitType({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<HabitKind>(
      segments: const [
        ButtonSegment(
          value: HabitKind.good,
          icon: Icon(Icons.check_circle_outline_rounded),
          label: Text('Build'),
        ),
        ButtonSegment(
          value: HabitKind.bad,
          icon: Icon(Icons.block_rounded),
          label: Text('Break'),
        ),
      ],
      selected: {value},
      onSelectionChanged: (selection) => onChanged(selection.first),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: kCoral, size: 44),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: kInk, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
