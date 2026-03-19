import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'routine_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PALETTE
// ─────────────────────────────────────────────────────────────────────────────

const _kInk   = Color(0xFF0F111A);
const _kSub   = Color(0xFF6B7280);
const _kCard  = Colors.white;
const _kAmber = Color(0xFFFFB830);
const _kShad  = Color(0x0D000000);

// ─────────────────────────────────────────────────────────────────────────────
// CUSTOM TASK MODEL  (stored per-day in provider)
// ─────────────────────────────────────────────────────────────────────────────

class CustomTask {
  final String id;
  final String title;
  final String emoji;
  final String time;   // "HH:MM"
  final DateTime date;
  final Color color;

  const CustomTask({
    required this.id,
    required this.title,
    required this.emoji,
    required this.time,
    required this.date,
    required this.color,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// ADD TASK BOTTOM SHEET
// ─────────────────────────────────────────────────────────────────────────────

class AddTaskSheet extends StatefulWidget {
  /// Called when user saves a task — caller adds it to state
  final void Function(CustomTask task) onAdd;

  const AddTaskSheet({super.key, required this.onAdd});

  @override
  State<AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends State<AddTaskSheet> {
  final _titleCtrl = TextEditingController();

  // Selected values
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay(
    hour: TimeOfDay.now().hour + 1,
    minute: 0,
  );
  String _selectedEmoji = '📌';
  Color  _selectedColor = _kAmber;

  static const _quickEmojis = [
    '📌','🏋️','📚','🧘','💧','☕','🎯','💼',
    '🌿','🎓','🍽️','🏃','🎵','💡','🔥','⚡',
  ];

  static const _colors = [
    Color(0xFFFFB830), Color(0xFF60D4A0), Color(0xFF378ADD),
    Color(0xFF9B8FFF), Color(0xFFFF6B6B), Color(0xFFFF9560),
    Color(0xFF78FDFF), Color(0xFFC084FC),
  ];

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  // ── Date quick-select ────────────────────────────────────────────────────

  String _dateLabel(DateTime d) {
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sel   = DateTime(d.year, d.month, d.day);
    if (sel == today) return 'Today';
    if (sel == today.add(const Duration(days: 1))) return 'Tomorrow';
    return '${_kMonths[d.month - 1]} ${d.day}';
  }

  static const _kMonths = [
    'Jan','Feb','Mar','Apr','May','Jun',
    'Jul','Aug','Sep','Oct','Nov','Dec',
  ];

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: _kAmber),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: _kAmber),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  // ── Save ─────────────────────────────────────────────────────────────────

  void _save() {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;
    final hh = _selectedTime.hour.toString().padLeft(2, '0');
    final mm = _selectedTime.minute.toString().padLeft(2, '0');
    widget.onAdd(CustomTask(
      id:    '${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      emoji: _selectedEmoji,
      time:  '$hh:$mm',
      date:  _selectedDate,
      color: _selectedColor,
    ));
    Navigator.pop(context);
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: _kInk.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Title
              const Text('Add to Timeline',
                  style: TextStyle(fontSize: 20,
                      fontWeight: FontWeight.w900, color: _kInk)),
              const SizedBox(height: 18),

              // ── Day selector row ─────────────────────────────────────
              const Text('DAY',
                  style: TextStyle(fontSize: 10,
                      fontWeight: FontWeight.w700, color: _kSub,
                      letterSpacing: 1)),
              const SizedBox(height: 8),
              Row(children: [
                _dayChip('Today',
                    DateTime.now()),
                const SizedBox(width: 8),
                _dayChip('Tomorrow',
                    DateTime.now().add(const Duration(days: 1))),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _pickDate,
                  child: _pillBox(
                    child: Row(mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_month_outlined,
                            size: 14, color: _kSub),
                        const SizedBox(width: 5),
                        Text(_dateLabel(_selectedDate),
                            style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700,
                              color: _kInk,
                            )),
                      ]),
                  ),
                ),
              ]),
              const SizedBox(height: 16),

              // ── Time picker ──────────────────────────────────────────
              const Text('TIME',
                  style: TextStyle(fontSize: 10,
                      fontWeight: FontWeight.w700, color: _kSub,
                      letterSpacing: 1)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickTime,
                child: _pillBox(
                  full: true,
                  child: Row(children: [
                    const Icon(Icons.access_time_rounded,
                        size: 16, color: _kSub),
                    const SizedBox(width: 8),
                    Text(_selectedTime.format(context),
                        style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700,
                          color: _kInk,
                        )),
                    const Spacer(),
                    Icon(Icons.chevron_right_rounded,
                        color: _kSub.withOpacity(0.5), size: 18),
                  ]),
                ),
              ),
              const SizedBox(height: 16),

              // ── Emoji picker ─────────────────────────────────────────
              const Text('ICON',
                  style: TextStyle(fontSize: 10,
                      fontWeight: FontWeight.w700, color: _kSub,
                      letterSpacing: 1)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: _quickEmojis.map((e) {
                  final sel = e == _selectedEmoji;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedEmoji = e),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 42, height: 42,
                      decoration: BoxDecoration(
                        color: sel
                            ? _selectedColor.withOpacity(0.18)
                            : const Color(0xFFF4F4F4),
                        borderRadius: BorderRadius.circular(12),
                        border: sel
                            ? Border.all(color: _selectedColor,
                                width: 1.5)
                            : null,
                      ),
                      child: Center(
                        child: Text(e,
                            style: const TextStyle(fontSize: 20))),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // ── Color picker ─────────────────────────────────────────
              const Text('COLOR',
                  style: TextStyle(fontSize: 10,
                      fontWeight: FontWeight.w700, color: _kSub,
                      letterSpacing: 1)),
              const SizedBox(height: 8),
              Row(children: _colors.map((c) {
                final sel = c == _selectedColor;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedColor = c),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: sel ? 32 : 26,
                      height: sel ? 32 : 26,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: sel
                            ? Border.all(color: _kInk, width: 2)
                            : null,
                        boxShadow: sel
                            ? [BoxShadow(
                                color: c.withOpacity(0.4),
                                blurRadius: 8)]
                            : [],
                      ),
                    ),
                  ),
                );
              }).toList()),
              const SizedBox(height: 16),

              // ── Task title ───────────────────────────────────────────
              const Text('TASK',
                  style: TextStyle(fontSize: 10,
                      fontWeight: FontWeight.w700, color: _kSub,
                      letterSpacing: 1)),
              const SizedBox(height: 8),
              Row(children: [
                // Emoji preview
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: _selectedColor.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(_selectedEmoji,
                        style: const TextStyle(fontSize: 22))),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _titleCtrl,
                    autofocus: true,
                    style: const TextStyle(
                        fontSize: 15, color: _kInk,
                        fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: 'Task name…',
                      hintStyle: TextStyle(
                          color: _kSub.withOpacity(0.5),
                          fontSize: 15,
                          fontWeight: FontWeight.w400),
                      filled: true,
                      fillColor: const Color(0xFFF4F4F4),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 13),
                    ),
                    onSubmitted: (_) => _save(),
                  ),
                ),
              ]),
              const SizedBox(height: 24),

              // ── Save button ──────────────────────────────────────────
              GestureDetector(
                onTap: _save,
                child: Container(
                  height: 54,
                  decoration: BoxDecoration(
                    color: _selectedColor,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: _selectedColor.withOpacity(0.38),
                        blurRadius: 16, offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text('Add to Timeline',
                        style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800,
                          color: Colors.white,
                        )),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _dayChip(String label, DateTime date) {
    final sel = _dateLabel(_selectedDate) == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedDate = date),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: sel ? _kInk : const Color(0xFFF4F4F4),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700,
              color: sel ? Colors.white : _kSub,
            )),
      ),
    );
  }

  Widget _pillBox({required Widget child, bool full = false}) {
    return Container(
      width: full ? double.infinity : null,
      padding: const EdgeInsets.symmetric(
          horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4F4),
        borderRadius: BorderRadius.circular(14),
      ),
      child: child,
    );
  }
}
