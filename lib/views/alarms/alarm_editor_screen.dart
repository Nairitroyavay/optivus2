import 'package:flutter/material.dart';

const _kInk = Color(0xFF10131D);
const _kSub = Color(0xFF6B7280);
const _kAmber = Color(0xFFFFB830);

class AlarmEditorResult {
  final String sound;
  final String soundAsset;
  final bool coachVoiceEnabled;
  final String vibrationPattern;
  final List<int> snoozeDurations;

  const AlarmEditorResult({
    required this.sound,
    required this.soundAsset,
    required this.coachVoiceEnabled,
    required this.vibrationPattern,
    required this.snoozeDurations,
  });

  static const defaults = AlarmEditorResult(
    sound: 'steady',
    soundAsset: 'assets/audio/ambient_atmospheric/ambient_atmospheric_01.mp3',
    coachVoiceEnabled: true,
    vibrationPattern: 'standard',
    snoozeDurations: [5, 10],
  );

  Map<String, dynamic> toMap() => {
        'sound': sound,
        'soundAsset': soundAsset,
        'coachVoiceEnabled': coachVoiceEnabled,
        'vibrationPattern': vibrationPattern,
        'snoozeDurations': snoozeDurations,
      };
}

class AlarmEditorScreen extends StatefulWidget {
  final AlarmEditorResult initial;

  const AlarmEditorScreen({
    super.key,
    this.initial = AlarmEditorResult.defaults,
  });

  @override
  State<AlarmEditorScreen> createState() => _AlarmEditorScreenState();
}

class _AlarmEditorScreenState extends State<AlarmEditorScreen> {
  late String _sound;
  late bool _coachVoiceEnabled;
  late String _vibrationPattern;
  late Set<int> _snoozeDurations;

  static const _sounds = [
    (
      'steady',
      'Steady',
      'assets/audio/ambient_atmospheric/ambient_atmospheric_01.mp3',
      Icons.graphic_eq_rounded
    ),
    (
      'bright',
      'Bright',
      'assets/audio/healing_432hz/healing_432hz_01.mp3',
      Icons.wb_sunny_rounded
    ),
    (
      'nature',
      'Nature',
      'assets/audio/nature_sounds/nature_sounds_01.mp3',
      Icons.forest_rounded
    ),
  ];

  static const _vibrations = [
    ('standard', 'Standard', Icons.vibration_rounded),
    ('pulse', 'Pulse', Icons.blur_on_rounded),
    ('urgent', 'Urgent', Icons.priority_high_rounded),
    ('none', 'Off', Icons.notifications_off_rounded),
  ];

  static const _snoozeOptions = [5, 10, 15, 30];

  @override
  void initState() {
    super.initState();
    _sound = widget.initial.sound;
    _coachVoiceEnabled = widget.initial.coachVoiceEnabled;
    _vibrationPattern = widget.initial.vibrationPattern;
    _snoozeDurations = widget.initial.snoozeDurations.toSet();
  }

  void _save() {
    final selectedSound = _sounds.firstWhere(
      (sound) => sound.$1 == _sound,
      orElse: () => _sounds.first,
    );
    final snoozes = _snoozeDurations.toList()..sort();
    Navigator.of(context).pop(AlarmEditorResult(
      sound: selectedSound.$1,
      soundAsset: selectedSound.$3,
      coachVoiceEnabled: _coachVoiceEnabled,
      vibrationPattern: _vibrationPattern,
      snoozeDurations: snoozes.isEmpty ? [5] : snoozes,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F7F8),
        foregroundColor: _kInk,
        elevation: 0,
        title: const Text(
          'Alarm',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text(
              'Done',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
        children: [
          const _SectionTitle('Sound'),
          const SizedBox(height: 8),
          for (final sound in _sounds) ...[
            _ChoiceRow(
              label: sound.$2,
              icon: sound.$4,
              selected: _sound == sound.$1,
              onTap: () => setState(() => _sound = sound.$1),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 10),
          _SwitchPanel(
            label: 'Coach voice',
            subtitle: 'Play a local coach sample when the alarm opens.',
            value: _coachVoiceEnabled,
            onChanged: (value) => setState(() => _coachVoiceEnabled = value),
          ),
          const SizedBox(height: 22),
          const _SectionTitle('Vibration'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final vibration in _vibrations)
                _ChipChoice(
                  label: vibration.$2,
                  icon: vibration.$3,
                  selected: _vibrationPattern == vibration.$1,
                  onTap: () => setState(() => _vibrationPattern = vibration.$1),
                ),
            ],
          ),
          const SizedBox(height: 22),
          const _SectionTitle('Snooze'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final minutes in _snoozeOptions)
                _DurationChoice(
                  minutes: minutes,
                  selected: _snoozeDurations.contains(minutes),
                  onTap: () => setState(() {
                    if (_snoozeDurations.contains(minutes)) {
                      if (_snoozeDurations.length > 1) {
                        _snoozeDurations.remove(minutes);
                      }
                    } else {
                      _snoozeDurations.add(minutes);
                    }
                  }),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String label;

  const _SectionTitle(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: _kSub,
        fontSize: 12,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _ChoiceRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ChoiceRow({
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
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? _kAmber : Colors.white,
            width: 1.3,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? _kAmber : _kSub),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: _kInk,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle_rounded, color: _kAmber),
          ],
        ),
      ),
    );
  }
}

class _SwitchPanel extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchPanel({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        value: value,
        activeThumbColor: _kAmber,
        title: Text(
          label,
          style: const TextStyle(color: _kInk, fontWeight: FontWeight.w900),
        ),
        subtitle: Text(subtitle),
        onChanged: onChanged,
      ),
    );
  }
}

class _ChipChoice extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ChipChoice({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      onPressed: onTap,
      avatar: Icon(icon, size: 17, color: selected ? Colors.white : _kSub),
      label: Text(label),
      labelStyle: TextStyle(
        color: selected ? Colors.white : _kSub,
        fontWeight: FontWeight.w800,
      ),
      backgroundColor: Colors.white,
      side: BorderSide.none,
      color: WidgetStatePropertyAll(selected ? _kInk : Colors.white),
    );
  }
}

class _DurationChoice extends StatelessWidget {
  final int minutes;
  final bool selected;
  final VoidCallback onTap;

  const _DurationChoice({
    required this.minutes,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      label: Text('$minutes min'),
      labelStyle: TextStyle(
        color: selected ? Colors.white : _kSub,
        fontWeight: FontWeight.w900,
      ),
      backgroundColor: Colors.white,
      selectedColor: _kAmber,
      side: BorderSide.none,
    );
  }
}
