import 'package:flutter/material.dart';

import 'package:optivus2/views/alarms/alarm_editor_screen.dart';

const _kInk = Color(0xFF0F111A);
const _kSub = Color(0xFF6B7280);
const _kAmber = Color(0xFFFFB830);

// 'none' = one-off task; 'daily'/'weekdays'/'weekends'/'weekly' = repeating template
typedef RepeatRule = String;

class AddTaskRequest {
  /// Repeat rule: 'none' (one-off), 'daily', 'weekdays', 'weekends', 'weekly'.
  final String repeatRule;
  final String title;
  final DateTime date;
  final TimeOfDay time;
  final int durationMinutes;
  final String routineType;
  final String category;
  final String notes;
  final bool reminderEnabled;
  final String alarmSound;
  final String alarmSoundAsset;
  final bool alarmVoiceEnabled;
  final String alarmVibrationPattern;
  final List<int> alarmSnoozeDurations;
  final String emoji;
  final Color color;

  const AddTaskRequest({
    required this.repeatRule,
    required this.title,
    required this.date,
    required this.time,
    required this.durationMinutes,
    required this.routineType,
    required this.category,
    required this.notes,
    required this.reminderEnabled,
    this.alarmSound = 'steady',
    this.alarmSoundAsset =
        'assets/audio/ambient_atmospheric/ambient_atmospheric_01.mp3',
    this.alarmVoiceEnabled = true,
    this.alarmVibrationPattern = 'standard',
    this.alarmSnoozeDurations = const [5, 10],
    required this.emoji,
    required this.color,
  });

  bool get isOneOff => repeatRule == 'none';

  DateTime get plannedStart => DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );

  DateTime get plannedEnd =>
      plannedStart.add(Duration(minutes: durationMinutes));

  String get startTime =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  String get endTime =>
      '${plannedEnd.hour.toString().padLeft(2, '0')}:${plannedEnd.minute.toString().padLeft(2, '0')}';
}

class AddTaskSheet extends StatefulWidget {
  final DateTime initialDate;
  final Future<void> Function(AddTaskRequest request) onSubmit;

  const AddTaskSheet({
    super.key,
    required this.initialDate,
    required this.onSubmit,
  });

  @override
  State<AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends State<AddTaskSheet> {
  final _titleCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _durationCtrl = TextEditingController(text: '30');

  late DateTime _selectedDate;
  TimeOfDay _selectedTime = TimeOfDay.now();
  // UI repeat mode: 'none' | 'daily' | 'weekdays' | 'weekends' | 'custom'
  String _repeatRule = 'none';
  // Active weekdays for 'custom' mode. 1=Mon … 7=Sun. Always ≥1 when custom.
  Set<int> _customDays = {};
  String _routineType = 'custom';
  String _category = 'Personal';
  String _selectedEmoji = '📌';
  Color _selectedColor = _kAmber;
  // true once the user manually taps an emoji → stops auto-matching
  bool _userOverrodeEmoji = false;
  bool _reminderEnabled = false;
  AlarmEditorResult _alarmSettings = AlarmEditorResult.defaults;
  bool _saving = false;
  String? _error;

  // Expanded grid — covers all auto-matched emojis so the highlight always lands.
  static const _quickEmojis = [
    '📌',
    '🏋️',
    '📚',
    '🧘',
    '💧',
    '☕',
    '🎯',
    '💼',
    '🌿',
    '🎓',
    '🍽️',
    '💊',
    '🏏',
    '⚽',
    '🏃',
    '✍️',
    '🎵',
    '🎨',
    '🏊',
    '🚴',
    '💻',
    '😴',
    '🛒',
    '🙏',
  ];

  static const _colors = [
    Color(0xFFFFB830),
    Color(0xFF60D4A0),
    Color(0xFF378ADD),
    Color(0xFF9B8FFF),
    Color(0xFFFF6B6B),
    Color(0xFFFF9560),
    Color(0xFF78FDFF),
    Color(0xFFC084FC),
  ];

  static const _routineTypes = [
    'custom',
    'fixed_schedule',
    'skin_care',
    'classes',
    'eating',
    'supplements',
  ];

  static const _categories = [
    'Personal',
    'Work',
    'Study',
    'Health',
    'Meals',
    'Errands',
  ];

  // Returns the best emoji for [title] based on keywords, or null if no match.
  // Rules are checked in order — put more-specific phrases first.
  static String? _emojiForTitle(String title) {
    final t = title.toLowerCase();
    const rules = <(List<String>, String)>[
      // Sports & physical activity
      (['cricket'], '🏏'),
      (['badminton'], '🏸'),
      (['volleyball'], '🏐'),
      (['basketball'], '🏀'),
      (['football', 'soccer'], '⚽'),
      (['baseball'], '⚾'),
      (['rugby'], '🏉'),
      (['hockey'], '🏒'),
      (['tennis'], '🎾'),
      (['golf'], '⛳'),
      (['chess'], '♟️'),
      (['boxing', 'martial', 'karate', 'judo', 'mma'], '🥊'),
      (['swim', 'pool'], '🏊'),
      (['cycling', 'cycle', 'bicycle', 'biking'], '🚴'),
      (['bike', 'ride'], '🚴'),
      (['ski', 'snowboard'], '⛷️'),
      (['hike', 'hiking', 'trek'], '🥾'),
      (['run', 'jog', 'sprint', 'marathon'], '🏃'),
      (['gym', 'workout', 'lift', 'weights', 'exercise', 'training'], '🏋️'),
      (['yoga'], '🧘'),
      (['dance', 'dancing', 'zumba'], '💃'),
      (['walk', 'stroll'], '🚶'),
      // Learning & work
      (['study', 'revision', 'revise', 'exam', 'test', 'assignment'], '📚'),
      (['read', 'reading', 'book', 'novel'], '📚'),
      (['lecture', 'class', 'college', 'university', 'school'], '🎓'),
      (['code', 'coding', 'programming', 'develop', 'debug'], '💻'),
      (['meeting', 'standup', 'sprint', 'scrum'], '💼'),
      (['work', 'office', 'job', 'internship'], '💼'),
      (['project', 'deadline', 'task', 'deliverable'], '📋'),
      (['write', 'writing', 'blog', 'essay', 'journal', 'diary'], '✍️'),
      (['teach', 'teacher', 'tutor', 'mentor', 'professor'], '🎓'),
      (['practice', 'rehearsal', 'rehearse'], '🎵'),
      // Food & health
      (['dinner', 'lunch', 'breakfast', 'brunch', 'supper'], '🍽️'),
      (['cook', 'cooking', 'bake', 'baking', 'kitchen', 'meal prep'], '🍳'),
      (['eat', 'food', 'meal', 'snack'], '🍽️'),
      (['coffee', 'cafe', 'espresso', 'latte'], '☕'),
      (['water', 'hydrate', 'hydration', 'drink'], '💧'),
      (
        ['medicine', 'medication', 'pill', 'supplement', 'vitamin', 'capsule'],
        '💊'
      ),
      (['doctor', 'hospital', 'clinic', 'checkup', 'check-up', 'health'], '🏥'),
      (['dentist', 'teeth', 'dental'], '🦷'),
      (['skincare', 'skin care', 'moistur', 'face', 'serum', 'cleanser'], '🌿'),
      (['sleep', 'nap', 'rest', 'bed', 'bedtime'], '😴'),
      // Daily life
      (
        ['shop', 'shopping', 'grocery', 'groceries', 'market', 'supermarket'],
        '🛒'
      ),
      (
        ['clean', 'cleaning', 'laundry', 'dishes', 'vacuum', 'mop', 'wash'],
        '🧹'
      ),
      (['travel', 'trip', 'flight', 'airport', 'vacation', 'holiday'], '✈️'),
      (['birthday', 'party', 'celebrat', 'anniversary'], '🎉'),
      (['call', 'phone', 'zoom', 'video call', 'facetime'], '📞'),
      (
        ['pray', 'prayer', 'worship', 'church', 'temple', 'mosque', 'namaz'],
        '🙏'
      ),
      (['drive', 'driving', 'car', 'commute'], '🚗'),
      (['hair', 'haircut', 'barber', 'grooming', 'salon'], '✂️'),
      (['music', 'guitar', 'piano', 'sing', 'singing', 'drum', 'violin'], '🎵'),
      (
        ['art', 'draw', 'drawing', 'sketch', 'paint', 'painting', 'design'],
        '🎨'
      ),
      (['photo', 'camera', 'shoot', 'photography'], '📷'),
      (['money', 'pay', 'bank', 'finance', 'invest', 'budget', 'bill'], '💰'),
      (['friend', 'family', 'social', 'hangout', 'catch up'], '👥'),
      (['movie', 'film', 'cinema', 'netflix', 'show', 'series', 'watch'], '🎬'),
      (['game', 'gaming', 'play', 'playstation', 'xbox'], '🎮'),
      (['goal', 'target', 'aim'], '🎯'),
      (['appointment', 'schedule', 'calendar', 'reminder'], '📅'),
      (['meditation', 'mindful', 'breathe', 'breathing'], '🧘'),
      (['plant', 'garden', 'water plant', 'gardening'], '🌿'),
      (['pack', 'packing', 'unpack', 'luggage'], '🧳'),
    ];
    for (final (keywords, emoji) in rules) {
      for (final kw in keywords) {
        if (t.contains(kw)) return emoji;
      }
    }
    return null;
  }

  void _autoMatchEmoji(String title) {
    if (_userOverrodeEmoji) return;
    final matched = _emojiForTitle(title);
    if (matched != null && matched != _selectedEmoji) {
      _selectedEmoji = matched;
    } else if (title.trim().isEmpty && _selectedEmoji != '📌') {
      _selectedEmoji = '📌'; // reset to default when title cleared
    }
  }

  // Translates UI repeat mode + custom days into the Firestore-ready repeatRule
  // string passed to AddTaskRequest.
  String get _computedRepeatRule {
    switch (_repeatRule) {
      case 'none':
        return 'none';
      case 'daily':
        return 'daily';
      case 'weekdays':
        return 'weekly:1,2,3,4,5';
      case 'weekends':
        return 'weekly:6,7';
      case 'custom':
        final sorted = _customDays.toList()..sort();
        return sorted.isEmpty ? 'daily' : 'weekly:${sorted.join(',')}';
      case 'monthly':
        return 'monthly:${_selectedDate.day}';
      default:
        return 'daily';
    }
  }

  static String _ordinal(int n) {
    if (n >= 11 && n <= 13) return '${n}th';
    switch (n % 10) {
      case 1:
        return '${n}st';
      case 2:
        return '${n}nd';
      case 3:
        return '${n}rd';
      default:
        return '${n}th';
    }
  }

  bool get _canSave {
    if (_saving) return false;
    if (_titleCtrl.text.trim().isEmpty) return false;
    if (_repeatRule == 'custom' && _customDays.isEmpty) return false;
    final dur = int.tryParse(_durationCtrl.text.trim()) ?? 0;
    if (dur <= 0 || dur > 480) return false;
    return true;
  }

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime(
      widget.initialDate.year,
      widget.initialDate.month,
      widget.initialDate.day,
    );
    final now = TimeOfDay.now();
    _selectedTime = TimeOfDay(hour: (now.hour + 1).clamp(0, 23), minute: 0);
    _titleCtrl.addListener(() => setState(() {
          _autoMatchEmoji(_titleCtrl.text);
        }));
    _durationCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _notesCtrl.dispose();
    _durationCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: _kAmber),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = DateTime(picked.year, picked.month, picked.day);
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: _kAmber),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _editAlarm() async {
    final result = await Navigator.of(context).push<AlarmEditorResult>(
      MaterialPageRoute(
        builder: (_) => AlarmEditorScreen(initial: _alarmSettings),
        fullscreenDialog: true,
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _alarmSettings = result;
      _reminderEnabled = true;
    });
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    final duration = int.tryParse(_durationCtrl.text.trim()) ?? 0;
    if (title.isEmpty) {
      setState(() => _error = 'Enter a title.');
      return;
    }
    if (duration <= 0 || duration > 480) {
      setState(() => _error = 'Duration must be 1–480 minutes (max 8 hours).');
      return;
    }

    // Validate that the computed repeat rule is a known format.
    final computedRule = _computedRepeatRule;
    const validPrefixes = {'none', 'daily', 'weekly:', 'monthly:'};
    if (!validPrefixes.any((p) => computedRule.startsWith(p))) {
      setState(() => _error = 'Unsupported repeat rule.');
      return;
    }

    // Verify the computed time range is valid (catches midnight-crossing edge
    // cases where plannedEnd would wrap into the next day).
    final plannedStart = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
    final plannedEnd = plannedStart.add(Duration(minutes: duration));
    if (!plannedEnd.isAfter(plannedStart)) {
      setState(() => _error = 'End time must be after start time.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await widget.onSubmit(AddTaskRequest(
        repeatRule: _computedRepeatRule,
        title: title,
        date: _selectedDate,
        time: _selectedTime,
        durationMinutes: duration,
        routineType: _routineType,
        category: _category,
        notes: _notesCtrl.text.trim(),
        reminderEnabled: _reminderEnabled,
        alarmSound: _alarmSettings.sound,
        alarmSoundAsset: _alarmSettings.soundAsset,
        alarmVoiceEnabled: _alarmSettings.coachVoiceEnabled,
        alarmVibrationPattern: _alarmSettings.vibrationPattern,
        alarmSnoozeDurations: _alarmSettings.snoozeDurations,
        emoji: _selectedEmoji,
        color: _selectedColor,
      ));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save. Try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom +
            16,
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: _kInk.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Add Task',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: _kInk,
              ),
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final rule in const [
                    ('none', 'None'),
                    ('daily', 'Daily'),
                    ('weekdays', 'Weekdays'),
                    ('weekends', 'Weekends'),
                    ('custom', 'Custom days'),
                    ('monthly', 'Monthly'),
                  ]) ...[
                    _ModeChip(
                      label: rule.$2,
                      selected: _repeatRule == rule.$1,
                      onTap: () => setState(() {
                        _repeatRule = rule.$1;
                        // Pre-select the chosen date's weekday so the day picker
                        // is never empty when the user first opens custom mode.
                        if (rule.$1 == 'custom' && _customDays.isEmpty) {
                          _customDays = {_selectedDate.weekday};
                        }
                      }),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            if (_repeatRule == 'custom') ...[
              const SizedBox(height: 10),
              _WeekdayPicker(
                selected: _customDays,
                color: _selectedColor,
                onChanged: (days) => setState(() => _customDays = days),
              ),
            ],
            if (_repeatRule == 'monthly') ...[
              const SizedBox(height: 10),
              _RepeatHint(
                icon: Icons.calendar_month_rounded,
                label: 'Repeats every month on the '
                    '${_ordinal(_selectedDate.day)}',
                color: _selectedColor,
              ),
            ],
            if (_repeatRule == 'none') ...[
              const SizedBox(height: 6),
              _RepeatHint(
                icon: Icons.event_rounded,
                label: 'One-time task — pick any date up to 2 years ahead',
                color: _kSub,
              ),
            ],
            const SizedBox(height: 14),
            _TextField(
              controller: _titleCtrl,
              label: 'Title',
              hint: 'Deep work, gym, reading...',
              autofocus: true,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _PickTile(
                    label: 'Date',
                    value: _dateLabel(_selectedDate),
                    icon: Icons.calendar_today_rounded,
                    onTap: _pickDate,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _PickTile(
                    label: 'Time',
                    value: _selectedTime.format(context),
                    icon: Icons.schedule_rounded,
                    onTap: _pickTime,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _TextField(
                    controller: _durationCtrl,
                    label: 'Duration',
                    hint: '30',
                    keyboardType: TextInputType.number,
                    suffix: 'min',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DropdownField(
                    label: 'Type',
                    value: _routineType,
                    items: _routineTypes,
                    onChanged: (value) => setState(() => _routineType = value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _DropdownField(
              label: 'Category',
              value: _category,
              items: _categories,
              onChanged: (value) => setState(() => _category = value),
            ),
            const SizedBox(height: 12),
            _TextField(
              controller: _notesCtrl,
              label: 'Notes',
              hint: 'Optional details',
              minLines: 2,
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  transitionBuilder: (child, anim) => ScaleTransition(
                    scale: anim,
                    child: FadeTransition(opacity: anim, child: child),
                  ),
                  child: Text(
                    _selectedEmoji,
                    key: ValueKey(_selectedEmoji),
                    style: const TextStyle(fontSize: 30),
                  ),
                ),
                const SizedBox(width: 8),
                if (!_userOverrodeEmoji &&
                    _titleCtrl.text.trim().isNotEmpty &&
                    _emojiForTitle(_titleCtrl.text) != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _selectedColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'auto-matched',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _selectedColor,
                      ),
                    ),
                  ),
                const Spacer(),
                Text(
                  'Tap below to change',
                  style: TextStyle(
                    fontSize: 11,
                    color: _kSub.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _quickEmojis.map((emoji) {
                final selected = emoji == _selectedEmoji;
                return _IconChoice(
                  label: emoji,
                  selected: selected,
                  color: _selectedColor,
                  onTap: () => setState(() {
                    _selectedEmoji = emoji;
                    _userOverrodeEmoji = true;
                  }),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            Row(
              children: _colors.map((color) {
                final selected = color == _selectedColor;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedColor = color),
                    child: Container(
                      width: selected ? 32 : 26,
                      height: selected ? 32 : 26,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: selected
                            ? Border.all(color: _kInk, width: 2)
                            : null,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _reminderEnabled,
              activeThumbColor: _selectedColor,
              title: const Text(
                'Alarm',
                style: TextStyle(fontWeight: FontWeight.w800, color: _kInk),
              ),
              subtitle: Text(
                _reminderEnabled
                    ? '${_alarmSettings.sound} sound, '
                        '${_alarmSettings.vibrationPattern} vibration, '
                        '${_alarmSettings.snoozeDurations.join('/')} min snooze'
                    : 'Use the full-screen alarm flow for this task',
              ),
              onChanged: (value) => setState(() => _reminderEnabled = value),
            ),
            if (_reminderEnabled) ...[
              const SizedBox(height: 4),
              _AlarmConfigTile(
                settings: _alarmSettings,
                color: _selectedColor,
                onTap: _editAlarm,
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 4),
              Text(
                _error!,
                style: const TextStyle(
                  color: Color(0xFFDC2626),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _selectedColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _canSave ? _save : null,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _repeatRule == 'none'
                            ? 'Add Task'
                            : 'Add Repeating Template',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _dateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    if (day == today) return 'Today';
    if (day == today.add(const Duration(days: 1))) return 'Tomorrow';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}';
  }
}

class _ModeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ModeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        backgroundColor: selected ? _kInk : const Color(0xFFF4F4F5),
        foregroundColor: selected ? Colors.white : _kSub,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
    );
  }
}

class _PickTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  const _PickTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F4F5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, size: 17, color: _kSub),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          color: _kSub,
                          fontSize: 10,
                          fontWeight: FontWeight.w800)),
                  Text(value,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: _kInk, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final String? suffix;
  final bool autofocus;
  final TextInputType? keyboardType;
  final int minLines;
  final int maxLines;

  const _TextField({
    required this.controller,
    required this.label,
    required this.hint,
    this.suffix,
    this.autofocus = false,
    this.keyboardType,
    this.minLines = 1,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: keyboardType,
      minLines: minLines,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixText: suffix,
        filled: true,
        fillColor: const Color(0xFFF4F4F5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _DropdownField extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      items: [
        for (final item in items)
          DropdownMenuItem(value: item, child: Text(item.replaceAll('_', ' '))),
      ],
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFFF4F4F5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _IconChoice extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _IconChoice({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.16)
              : const Color(0xFFF4F4F5),
          borderRadius: BorderRadius.circular(12),
          border: selected ? Border.all(color: color, width: 1.5) : null,
        ),
        child: Center(child: Text(label, style: const TextStyle(fontSize: 19))),
      ),
    );
  }
}

class _AlarmConfigTile extends StatelessWidget {
  final AlarmEditorResult settings;
  final Color color;
  final VoidCallback onTap;

  const _AlarmConfigTile({
    required this.settings,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.11),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.24)),
        ),
        child: Row(
          children: [
            Icon(Icons.tune_rounded, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Alarm settings',
                    style: TextStyle(
                      color: _kInk,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Voice ${settings.coachVoiceEnabled ? "on" : "off"} · '
                    'snooze ${settings.snoozeDurations.join(", ")} min',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _kSub,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: _kSub),
          ],
        ),
      ),
    );
  }
}

class _RepeatHint extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _RepeatHint({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4F5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekdayPicker extends StatelessWidget {
  final Set<int> selected; // 1=Mon … 7=Sun
  final Color color;
  final ValueChanged<Set<int>> onChanged;

  const _WeekdayPicker({
    required this.selected,
    required this.color,
    required this.onChanged,
  });

  static const _labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  static const _fullLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (i) {
        final day = i + 1; // 1=Mon … 7=Sun
        final isSelected = selected.contains(day);
        return Tooltip(
          message: _fullLabels[i],
          child: GestureDetector(
            onTap: () {
              final next = Set<int>.from(selected);
              if (isSelected) {
                // Require at least one day to stay selected
                if (next.length > 1) next.remove(day);
              } else {
                next.add(day);
              }
              onChanged(next);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected ? color : const Color(0xFFF4F4F5),
                borderRadius: BorderRadius.circular(10),
                border: isSelected
                    ? Border.all(color: color.withValues(alpha: 0.6), width: 1)
                    : null,
              ),
              child: Center(
                child: Text(
                  _labels[i],
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: isSelected ? Colors.white : _kSub,
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
