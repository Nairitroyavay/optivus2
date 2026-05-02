import 'package:flutter/material.dart';

const _kInk = Color(0xFF0F111A);
const _kSub = Color(0xFF6B7280);
const _kAmber = Color(0xFFFFB830);

enum AddTaskMode { oneOff, repeating }

class AddTaskRequest {
  final AddTaskMode mode;
  final String title;
  final DateTime date;
  final TimeOfDay time;
  final int durationMinutes;
  final String routineType;
  final String category;
  final String notes;
  final bool reminderEnabled;
  final String emoji;
  final Color color;

  const AddTaskRequest({
    required this.mode,
    required this.title,
    required this.date,
    required this.time,
    required this.durationMinutes,
    required this.routineType,
    required this.category,
    required this.notes,
    required this.reminderEnabled,
    required this.emoji,
    required this.color,
  });

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
  AddTaskMode _mode = AddTaskMode.oneOff;
  String _routineType = 'custom';
  String _category = 'Personal';
  String _selectedEmoji = '📌';
  Color _selectedColor = _kAmber;
  bool _reminderEnabled = false;
  bool _saving = false;
  String? _error;

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
      lastDate: DateTime.now().add(const Duration(days: 365)),
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

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    final duration = int.tryParse(_durationCtrl.text.trim()) ?? 0;
    if (title.isEmpty) {
      setState(() => _error = 'Enter a title.');
      return;
    }
    if (duration <= 0 || duration > 480) {
      setState(() => _error = 'Duration must be between 1 and 480 minutes.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await widget.onSubmit(AddTaskRequest(
        mode: _mode,
        title: title,
        date: _selectedDate,
        time: _selectedTime,
        durationMinutes: duration,
        routineType: _routineType,
        category: _category,
        notes: _notesCtrl.text.trim(),
        reminderEnabled: _reminderEnabled,
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
            Row(
              children: [
                Expanded(
                  child: _ModeChip(
                    label: 'One-off',
                    selected: _mode == AddTaskMode.oneOff,
                    onTap: () => setState(() => _mode = AddTaskMode.oneOff),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ModeChip(
                    label: 'Repeating',
                    selected: _mode == AddTaskMode.repeating,
                    onTap: () => setState(() => _mode = AddTaskMode.repeating),
                  ),
                ),
              ],
            ),
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
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _quickEmojis.map((emoji) {
                final selected = emoji == _selectedEmoji;
                return _IconChoice(
                  label: emoji,
                  selected: selected,
                  color: _selectedColor,
                  onTap: () => setState(() => _selectedEmoji = emoji),
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
                'Reminder',
                style: TextStyle(fontWeight: FontWeight.w800, color: _kInk),
              ),
              subtitle: const Text('Schedule a reminder 5 minutes before'),
              onChanged: (value) => setState(() => _reminderEnabled = value),
            ),
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
                onPressed: _saving ? null : _save,
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
                        _mode == AddTaskMode.oneOff
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
