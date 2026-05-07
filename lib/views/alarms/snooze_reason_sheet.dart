import 'package:flutter/material.dart';

const _kInk = Color(0xFF10131D);
const _kSub = Color(0xFF6B7280);
const _kAmber = Color(0xFFFFB830);

class SnoozeReasonResult {
  final String reason;
  final String label;
  final int? snoozeMinutes;

  const SnoozeReasonResult({
    required this.reason,
    required this.label,
    this.snoozeMinutes,
  });
}

class SnoozeReasonSheet extends StatefulWidget {
  final String title;
  final String actionLabel;
  final List<int> snoozeDurations;

  const SnoozeReasonSheet({
    super.key,
    this.title = 'Why snooze?',
    this.actionLabel = 'Continue',
    this.snoozeDurations = const [],
  });

  static Future<SnoozeReasonResult?> show(
    BuildContext context, {
    String title = 'Why snooze?',
    String actionLabel = 'Continue',
    List<int> snoozeDurations = const [],
  }) {
    return showModalBottomSheet<SnoozeReasonResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SnoozeReasonSheet(
        title: title,
        actionLabel: actionLabel,
        snoozeDurations: snoozeDurations,
      ),
    );
  }

  @override
  State<SnoozeReasonSheet> createState() => _SnoozeReasonSheetState();
}

class _SnoozeReasonSheetState extends State<SnoozeReasonSheet> {
  final _otherCtrl = TextEditingController();
  String _selected = 'tired';
  int? _selectedMinutes;

  static const _reasons = [
    ('tired', 'Tired', Icons.bedtime_rounded),
    ('not_feeling_it', 'Not feeling it', Icons.sentiment_neutral_rounded),
    ('busy', 'Busy', Icons.work_history_rounded),
    ('other', 'Other', Icons.edit_note_rounded),
  ];

  @override
  void dispose() {
    _otherCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final selected = _reasons.firstWhere((item) => item.$1 == _selected);
    final custom = _otherCtrl.text.trim();
    Navigator.of(context).pop(SnoozeReasonResult(
      reason: _selected,
      label: _selected == 'other' && custom.isNotEmpty ? custom : selected.$2,
      snoozeMinutes: _selectedMinutes,
    ));
  }

  List<int> get _durations {
    final values = widget.snoozeDurations.where((value) => value > 0).toSet();
    final sorted = values.toList()..sort();
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final durations = _durations;
    _selectedMinutes ??= durations.isEmpty ? null : durations.first;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
        bottom: MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom +
            18,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
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
            const SizedBox(height: 18),
            Text(
              widget.title,
              style: const TextStyle(
                color: _kInk,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 14),
            for (final reason in _reasons) ...[
              _ReasonTile(
                label: reason.$2,
                icon: reason.$3,
                selected: _selected == reason.$1,
                onTap: () => setState(() => _selected = reason.$1),
              ),
              const SizedBox(height: 8),
            ],
            if (_selected == 'other') ...[
              const SizedBox(height: 4),
              TextField(
                controller: _otherCtrl,
                autofocus: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  hintText: 'What got in the way?',
                  filled: true,
                  fillColor: const Color(0xFFF4F4F5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
            if (durations.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Snooze for',
                style: TextStyle(
                  color: _kSub,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final minutes in durations)
                    ChoiceChip(
                      selected: _selectedMinutes == minutes,
                      onSelected: (_) {
                        setState(() => _selectedMinutes = minutes);
                      },
                      showCheckmark: false,
                      label: Text('$minutes min'),
                      labelStyle: TextStyle(
                        color:
                            _selectedMinutes == minutes ? Colors.white : _kSub,
                        fontWeight: FontWeight.w900,
                      ),
                      backgroundColor: const Color(0xFFF4F4F5),
                      selectedColor: _kAmber,
                      side: BorderSide.none,
                    ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: _kAmber,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  widget.actionLabel,
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
}

class _ReasonTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ReasonTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: selected
              ? _kAmber.withValues(alpha: 0.14)
              : const Color(0xFFF4F4F5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? _kAmber : Colors.transparent,
            width: 1.4,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? _kAmber : _kSub, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? _kInk : _kSub,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle_rounded, color: _kAmber, size: 19),
          ],
        ),
      ),
    );
  }
}
