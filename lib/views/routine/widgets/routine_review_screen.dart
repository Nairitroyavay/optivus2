import 'package:flutter/material.dart';

class RoutineReviewScreen extends StatefulWidget {
  final String title;
  final String routineType;
  final List<Map<String, dynamic>> templates;
  final Future<List<Map<String, dynamic>>> Function()? onRegenerate;
  final Future<void> Function(List<Map<String, dynamic>> templates) onAcceptAll;

  const RoutineReviewScreen({
    super.key,
    required this.title,
    required this.routineType,
    required this.templates,
    required this.onAcceptAll,
    this.onRegenerate,
  });

  @override
  State<RoutineReviewScreen> createState() => _RoutineReviewScreenState();
}

class _RoutineReviewScreenState extends State<RoutineReviewScreen> {
  late List<Map<String, dynamic>> _templates;
  bool _saving = false;
  bool _regenerating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _templates = widget.templates.map(_normalizeTemplate).toList();
  }

  Map<String, dynamic> _normalizeTemplate(Map<String, dynamic> raw) {
    final template = Map<String, dynamic>.from(raw);
    final startTime = _normalizeTime(
      template['startTime']?.toString() ?? template['time']?.toString() ?? '',
      fallback: '07:30',
    );
    template['routineType'] = template['routineType'] ?? widget.routineType;
    template['startTime'] = startTime;
    template['time'] = startTime;
    template['endTime'] = _normalizeTime(
      template['endTime']?.toString() ?? '',
      fallback: _endTime(startTime, 15),
    );
    template['repeatRule'] = _repeatRule(template);
    template['timingRule'] =
        template['timingRule']?.toString().trim().isNotEmpty == true
            ? template['timingRule'].toString().trim()
            : _timingRuleFor(startTime);
    template['weekdayRule'] =
        template['weekdayRule']?.toString().trim().isNotEmpty == true
            ? template['weekdayRule'].toString().trim()
            : template['repeatRule'];
    template['steps'] = _stepsFrom(template['steps'], template['notes']);
    template['warnings'] = _stringList(template['warnings']);
    template['confidence'] = _confidence(template['confidence']);
    template['notes'] = template['notes']?.toString() ?? '';
    template['reminderEnabled'] = template['reminderEnabled'] == true;
    template['isActive'] = template['isActive'] ?? true;
    return template;
  }

  static String _repeatRule(Map<String, dynamic> template) {
    final weekdayRule = template['weekdayRule']?.toString().trim();
    final repeatRule = template['repeatRule']?.toString().trim();
    if (repeatRule != null && repeatRule.isNotEmpty) return repeatRule;
    if (weekdayRule != null && weekdayRule.isNotEmpty) return weekdayRule;
    return 'daily';
  }

  static List<Map<String, dynamic>> _stepsFrom(Object? raw, Object? notes) {
    final values = <String>[];
    if (raw is List) {
      for (final step in raw) {
        if (step is Map) {
          final name = step['name']?.toString().trim() ??
              step['title']?.toString().trim() ??
              '';
          if (name.isNotEmpty) values.add(name);
        } else {
          final name = step.toString().trim();
          if (name.isNotEmpty) values.add(name);
        }
      }
    }
    if (values.isEmpty) {
      values.addAll((notes?.toString() ?? '')
          .split(RegExp(r',|\n'))
          .map((step) => step.trim())
          .where((step) => step.isNotEmpty));
    }
    return values.map((name) => {'name': name}).toList();
  }

  static List<String> _stringList(Object? raw) {
    if (raw is List) {
      return raw
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    final value = raw?.toString().trim() ?? '';
    return value.isEmpty ? const [] : [value];
  }

  static double _confidence(Object? raw) {
    final value = raw is num ? raw.toDouble() : double.tryParse('$raw') ?? 0.75;
    return value.clamp(0.0, 1.0).toDouble();
  }

  Future<void> _regenerate() async {
    final callback = widget.onRegenerate;
    if (callback == null) return;
    setState(() {
      _regenerating = true;
      _error = null;
    });
    try {
      final next = await callback();
      if (!mounted) return;
      setState(() => _templates = next.map(_normalizeTemplate).toList());
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _regenerating = false);
    }
  }

  Future<void> _acceptAll() async {
    if (_templates.isEmpty || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onAcceptAll(_templates.map(_normalizeTemplate).toList());
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _addTemplate() {
    setState(() {
      _templates.add(_normalizeTemplate({
        'templateId':
            '${widget.routineType}_${DateTime.now().microsecondsSinceEpoch}',
        'title': 'New routine block',
        'startTime': '07:30',
        'endTime': '07:45',
        'repeatRule': 'daily',
        'steps': [
          {'name': 'Cleanse'}
        ],
        'notes': '',
        'confidence': 0.75,
        'warnings': const [],
      }));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: 'Add',
            onPressed: _addTemplate,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(
                _error!,
                style: const TextStyle(
                  color: Color(0xFFB91C1C),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _templates.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                return _RoutineReviewCard(
                  key: ValueKey(_templates[index]['templateId'] ?? index),
                  template: _templates[index],
                  onChanged: (next) {
                    setState(
                        () => _templates[index] = _normalizeTemplate(next));
                  },
                  onRemove: () => setState(() => _templates.removeAt(index)),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _regenerating ? null : _regenerate,
                    icon: _regenerating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome_rounded),
                    label: const Text('Regenerate'),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed:
                        _saving || _templates.isEmpty ? null : _acceptAll,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_rounded),
                    label: const Text('Accept all'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoutineReviewCard extends StatelessWidget {
  final Map<String, dynamic> template;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final VoidCallback onRemove;

  const _RoutineReviewCard({
    super.key,
    required this.template,
    required this.onChanged,
    required this.onRemove,
  });

  void _set(String key, Object? value) {
    onChanged({...template, key: value});
  }

  @override
  Widget build(BuildContext context) {
    final warnings = _warningsText(template['warnings']);
    final steps = (template['steps'] as List? ?? const [])
        .map((step) => step is Map ? step['name'] : step)
        .map((step) => step?.toString().trim() ?? '')
        .where((step) => step.isNotEmpty)
        .join(', ');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: template['title']?.toString() ?? '',
                  decoration: const InputDecoration(labelText: 'Title'),
                  onChanged: (value) => _set('title', value),
                ),
              ),
              IconButton(
                tooltip: 'Remove',
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: template['startTime']?.toString() ?? '',
                  decoration: const InputDecoration(labelText: 'Time'),
                  onChanged: (value) {
                    final time = _normalizeTime(value, fallback: value);
                    onChanged({
                      ...template,
                      'time': time,
                      'startTime': time,
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  initialValue: template['endTime']?.toString() ?? '',
                  decoration: const InputDecoration(labelText: 'End'),
                  onChanged: (value) {
                    _set('endTime', _normalizeTime(value, fallback: value));
                  },
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: template['timingRule']?.toString() ?? '',
                  decoration: const InputDecoration(labelText: 'Timing rule'),
                  onChanged: (value) => _set('timingRule', value),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  initialValue: template['weekdayRule']?.toString() ??
                      template['repeatRule']?.toString() ??
                      '',
                  decoration: const InputDecoration(labelText: 'Weekday rule'),
                  onChanged: (value) {
                    onChanged({
                      ...template,
                      'weekdayRule': value,
                      'repeatRule': value,
                    });
                  },
                ),
              ),
            ],
          ),
          TextFormField(
            initialValue: steps,
            decoration: const InputDecoration(labelText: 'Steps'),
            minLines: 1,
            maxLines: 3,
            onChanged: (value) {
              _set(
                'steps',
                value
                    .split(RegExp(r',|\n'))
                    .map((step) => step.trim())
                    .where((step) => step.isNotEmpty)
                    .map((name) => {'name': name})
                    .toList(),
              );
            },
          ),
          TextFormField(
            initialValue: template['notes']?.toString() ?? '',
            decoration: const InputDecoration(labelText: 'Notes'),
            onChanged: (value) => _set('notes', value),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetaChip(
                icon: Icons.verified_outlined,
                label:
                    'Confidence ${(((template['confidence'] as num?)?.toDouble() ?? 0.75) * 100).round()}%',
              ),
              if (warnings.isNotEmpty)
                _MetaChip(
                  icon: Icons.warning_amber_rounded,
                  label: warnings,
                  color: const Color(0xFF92400E),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static String _warningsText(Object? raw) {
    if (raw is List) {
      return raw
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .join(', ');
    }
    return raw?.toString().trim() ?? '';
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MetaChip({
    required this.icon,
    required this.label,
    this.color = const Color(0xFF334155),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _normalizeTime(String raw, {required String fallback}) {
  final text = raw.trim().toUpperCase();
  final amPm = RegExp(r'^(\d{1,2})(?::(\d{2}))?\s*([AP]M)$').firstMatch(text);
  if (amPm != null) {
    var hour = int.tryParse(amPm.group(1)!) ?? 0;
    final minute = int.tryParse(amPm.group(2) ?? '0') ?? 0;
    final suffix = amPm.group(3);
    if (suffix == 'PM' && hour != 12) hour += 12;
    if (suffix == 'AM' && hour == 12) hour = 0;
    if (hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59) {
      return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
    }
  }

  final hhmm = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(text);
  if (hhmm != null) {
    final hour = int.tryParse(hhmm.group(1)!) ?? -1;
    final minute = int.tryParse(hhmm.group(2)!) ?? -1;
    if (hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59) {
      return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
    }
  }

  return fallback;
}

String _endTime(String startTime, int durationMinutes) {
  final parts = startTime.split(':');
  final hour = int.tryParse(parts.first) ?? 7;
  final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
  final start = DateTime(2026, 1, 1, hour, minute);
  final end = start.add(Duration(minutes: durationMinutes));
  return '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}';
}

String _timingRuleFor(String time) {
  final hour = int.tryParse(time.split(':').first) ?? 7;
  if (hour < 12) return 'morning';
  if (hour < 17) return 'afternoon';
  return 'night';
}
