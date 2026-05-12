import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus2/core/constants/event_names.dart';
import 'package:optivus2/core/liquid_ui/liquid_ui.dart';
import 'package:optivus2/core/providers.dart';
import 'package:optivus2/core/utils/uuid_generator.dart';
import 'package:optivus2/providers/routine_provider.dart';
import 'package:optivus2/views/routine/widgets/routine_review_screen.dart';

class SupplementSetupScreen extends ConsumerStatefulWidget {
  final VoidCallback onComplete;
  const SupplementSetupScreen({super.key, required this.onComplete});

  @override
  ConsumerState<SupplementSetupScreen> createState() =>
      _SupplementSetupScreenState();
}

class _SupplementItem {
  String templateId;
  String title;
  String dosage;
  String time;
  int durationMinutes;
  String repeatRule;
  String timingRule;
  String notes;
  List<String> warnings;
  double confidence;
  bool reminderEnabled;

  _SupplementItem({
    required this.templateId,
    required this.title,
    required this.dosage,
    required this.time,
    this.durationMinutes = 5,
    this.repeatRule = 'daily',
    this.timingRule = 'after breakfast',
    this.notes = '',
    this.warnings = const [],
    this.confidence = 0.75,
    this.reminderEnabled = false,
  });

  Map<String, dynamic> toTemplate() {
    final now = DateTime.now().toIso8601String();
    return {
      'templateId': templateId,
      'title': title.trim(),
      'routineType': 'supplements',
      'startTime': time,
      'endTime': _endTime(time, durationMinutes),
      'repeatRule': repeatRule,
      'timingRule': timingRule,
      'weekdayRule': repeatRule,
      'dosage': dosage.trim(),
      'notes': notes.trim(),
      'warnings': warnings,
      'confidence': confidence,
      'reminderEnabled': reminderEnabled,
      'isActive': true,
      'createdAt': now,
      'updatedAt': now,
    };
  }
}

class _SupplementSetupScreenState extends ConsumerState<SupplementSetupScreen> {
  final _textImportCtrl = TextEditingController();
  final List<_SupplementItem> _items = [];
  String _mode = 'Manual';
  Map<String, dynamic>? _pendingImportMetadata;
  bool _isGenerating = false;
  String? _generationError;

  @override
  void initState() {
    super.initState();
    final saved =
        ref.read(routineProvider).routineTemplates['supplements'] ?? const [];
    _items.addAll(saved.map((item) {
      return _SupplementItem(
        templateId: item['templateId']?.toString() ?? generateId(),
        title: item['title']?.toString() ?? '',
        dosage: item['dosage']?.toString() ?? '',
        time: item['startTime']?.toString() ?? '08:00',
        durationMinutes: 5,
        repeatRule: item['repeatRule']?.toString() ?? 'daily',
        timingRule: _normalizeTimingRule(item['timingRule']?.toString() ?? ''),
        notes: item['notes']?.toString() ?? '',
        warnings: _stringList(item['warnings']),
        confidence: _templateConfidence(item['confidence']),
        reminderEnabled: item['reminderEnabled'] == true,
      );
    }));
    // Do NOT seed a default entry for new users; they start with an empty list
    // and add items manually via the + button.
  }

  @override
  void dispose() {
    _textImportCtrl.dispose();
    super.dispose();
  }

  void _addBlank() {
    setState(() {
      _items.add(_SupplementItem(
        templateId: generateId(),
        title: '',
        dosage: '',
        time: '08:00',
      ));
    });
  }

  Future<void> _generateFromText() async {
    final sourceText = _textImportCtrl.text.trim();
    if (sourceText.isEmpty || _isGenerating) return;

    setState(() {
      _isGenerating = true;
      _generationError = null;
    });

    List<Map<String, dynamic>> templates;
    final importMetadata = <String, dynamic>{
      'mode': 'supplement_text',
      'sourceText': sourceText,
      'createdAt': DateTime.now().toIso8601String(),
    };
    try {
      templates = await _previewSupplementTemplates(sourceText);
    } catch (e) {
      debugPrint('[SupplementSetup] routineImport preview failed: $e');
      templates = _supplementsFromText(sourceText)
          .map((item) => item.toTemplate())
          .toList();
      importMetadata['fallbackReason'] = e.toString();
      if (mounted) {
        setState(() => _generationError =
            'AI endpoint failed. Showing a local draft you can still edit.');
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }

    final suggestionIds = templates
        .map((template) => template['_suggestionId']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList();
    if (suggestionIds.isNotEmpty) {
      importMetadata['suggestionIds'] = suggestionIds;
      for (final suggestionId in suggestionIds) {
        await ref.read(eventServiceProvider).emit(
              eventName: EventNames.suggestionGenerated,
              source: 'supplement_setup',
              payload: {'suggestionId': suggestionId},
            );
      }
    }

    if (!mounted) return;
    final accepted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => RoutineReviewScreen(
          title: 'Review supplements',
          routineType: 'supplements',
          templates: templates,
          onRegenerate: () => _previewSupplementTemplates(sourceText),
          onAcceptAll: (reviewed) async {
            await _acceptGeneratedSupplements(reviewed, importMetadata);
          },
        ),
      ),
    );
    if (accepted == true && mounted) {
      Navigator.pop(context);
    } else if (mounted && suggestionIds.isNotEmpty) {
      // Review was dismissed — emit suggestion_dismissed.
      for (final suggestionId in suggestionIds) {
        await ref.read(eventServiceProvider).emit(
              eventName: EventNames.suggestionDismissed,
              source: 'supplement_setup',
              payload: {'suggestionId': suggestionId},
            );
      }
    }
  }

  Future<List<Map<String, dynamic>>> _previewSupplementTemplates(
    String sourceText,
  ) async {
    List<Map<String, dynamic>> generated = const [];
    try {
      generated =
          await ref.read(routineRepositoryProvider).previewRoutineImport(
                routineType: 'supplements',
                mode: 'supplement_text',
                sourceText: sourceText,
              );
    } catch (e) {
      debugPrint('[SupplementSetup] routineImport preview failed: $e');
    }
    return generated.isNotEmpty
        ? generated.map(_normalizeSupplementTemplate).toList()
        : _supplementsFromText(sourceText)
            .map((item) => item.toTemplate())
            .toList();
  }

  List<_SupplementItem> _supplementsFromText(String sourceText) {
    final entries = sourceText
        .split(RegExp(r'\n|,|;'))
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toList();
    return entries.asMap().entries.map((entry) {
      final line = entry.value;
      final parts =
          line.split(RegExp(r'\s+-\s+|\s+\|\s+')).map((p) => p.trim()).toList();
      final defaults = _defaultSupplementTiming(entry.key, parts.first);
      return _SupplementItem(
        templateId: generateId(),
        title: parts.isNotEmpty ? parts[0] : line,
        dosage: parts.length > 1 ? parts[1] : _defaultSupplementDosage(line),
        time: parts.length > 2 ? _normalizeTime(parts[2]) : defaults.time,
        timingRule: defaults.timingRule,
        notes: 'Generated from text import',
        warnings: const ['Local fallback draft'],
        confidence: 0.55,
      );
    }).toList();
  }

  _SupplementItem _supplementFromTemplate(Map<String, dynamic> template) {
    return _SupplementItem(
      templateId: template['templateId']?.toString() ?? generateId(),
      title: template['title']?.toString() ?? '',
      dosage: template['dosage']?.toString() ?? '',
      time: _normalizeTime(template['startTime']?.toString() ?? '08:00'),
      repeatRule: template['repeatRule']?.toString() ?? 'daily',
      timingRule:
          _normalizeTimingRule(template['timingRule']?.toString() ?? ''),
      notes: template['notes']?.toString() ?? '',
      warnings: _stringList(template['warnings']),
      confidence: _templateConfidence(template['confidence']),
      reminderEnabled: template['reminderEnabled'] == true,
    );
  }

  Map<String, dynamic> _normalizeSupplementTemplate(
    Map<String, dynamic> template,
  ) {
    final item = _supplementFromTemplate(template);
    final next = item.toTemplate();
    next['templateId'] =
        template['templateId']?.toString().trim().isNotEmpty == true
            ? template['templateId'].toString().trim()
            : item.templateId;
    next['time'] = next['startTime'];
    next['notes'] =
        _notesWithDosage(next['dosage']?.toString() ?? '', item.notes);
    if (template['_suggestionId'] != null) {
      next['_suggestionId'] = template['_suggestionId'];
    }
    return next;
  }

  Future<void> _acceptGeneratedSupplements(
    List<Map<String, dynamic>> reviewed,
    Map<String, dynamic> importMetadata,
  ) async {
    final templates = reviewed.map(_normalizeSupplementTemplate).toList();
    setState(() {
      _items
        ..clear()
        ..addAll(templates.map(_supplementFromTemplate));
      _pendingImportMetadata = importMetadata;
    });
    await ref.read(routineProvider.notifier).setRoutineTemplates(
          'supplements',
          templates.map(_templateForSave).toList(),
          importMetadata: importMetadata,
        );
    await _markSuggestionsAccepted(reviewed);
    await ref.read(eventServiceProvider).emit(
      eventName: EventNames.routineTemplateCreated,
      source: 'supplement_setup',
      payload: {
        'routineType': 'supplements',
        'source': importMetadata['mode'] ?? 'ai_import',
        'count': templates.length,
      },
    );
    widget.onComplete();
  }

  Map<String, dynamic> _templateForSave(Map<String, dynamic> template) {
    final next = Map<String, dynamic>.from(template);
    next.remove('_suggestionId');
    return next;
  }

  Future<void> _markSuggestionsAccepted(
    List<Map<String, dynamic>> templates,
  ) async {
    final ids = templates
        .map((template) => template['_suggestionId']?.toString() ?? '')
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
        source: 'supplement_setup',
        payload: {'suggestionId': suggestionId},
      );
    }
  }

  /// Returns a user-facing error string if any supplement entry has invalid
  /// fields, or null when everything is valid.
  String? _validate() {
    for (var i = 0; i < _items.length; i++) {
      final item = _items[i];
      final label = 'Supplement ${i + 1}';
      if (item.title.trim().isEmpty) {
        return '$label: name is required.';
      }
      if (item.dosage.trim().isEmpty) {
        return '$label (${item.title.trim()}): dosage is required.';
      }
      // Time must be HH:MM (24-hour).
      final timeOk = RegExp(r'^\d{2}:\d{2}$').hasMatch(item.time);
      if (!timeOk) {
        return '$label (${item.title.trim()}): time must be in HH:MM format.';
      }
    }
    return null;
  }

  Future<void> _save() async {
    if (_items.isEmpty) {
      // Allow saving an empty list (user deleted all supplements).
    } else {
      final error = _validate();
      if (error != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error)),
          );
        }
        return;
      }
    }
    final templates = _items
        .where((item) => item.title.trim().isNotEmpty)
        .map((item) => item.toTemplate())
        .toList();
    await ref.read(routineProvider.notifier).setRoutineTemplates(
          'supplements',
          templates,
          importMetadata: _pendingImportMetadata,
        );
    widget.onComplete();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LiquidBg(
        colors: const [Color(0xFF5EEAD4), Color(0xFFEFFEEC)],
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                    const Expanded(
                      child: Text(
                        'Supplements',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: kInk,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _addBlank,
                      icon: const Icon(Icons.add_rounded),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'Manual', label: Text('Manual')),
                    ButtonSegment(value: 'Text AI', label: Text('Text AI')),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (value) =>
                      setState(() => _mode = value.first),
                ),
              ),
              if (_mode == 'Text AI')
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _textImportCtrl,
                        minLines: 3,
                        maxLines: 5,
                        decoration: InputDecoration(
                          hintText: 'creatine, whey, vitamin D, omega 3',
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.82),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          suffixIcon: IconButton(
                            onPressed: _isGenerating ? null : _generateFromText,
                            icon: _isGenerating
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.auto_awesome_rounded),
                          ),
                        ),
                      ),
                      if (_generationError != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _generationError!,
                          style: const TextStyle(
                            color: Color(0xFFB91C1C),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      FilledButton.icon(
                        onPressed: _isGenerating ? null : _generateFromText,
                        icon: _isGenerating
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.auto_awesome_rounded),
                        label: const Text('Generate'),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    return _SupplementCard(
                      item: item,
                      onChanged: () => setState(() {}),
                      onDelete: () => setState(() => _items.removeAt(index)),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: _save,
                    child: const Text('Save Supplements'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SupplementCard extends StatelessWidget {
  final _SupplementItem item;
  final VoidCallback onChanged;
  final VoidCallback onDelete;

  const _SupplementCard({
    required this.item,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text('💊', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  initialValue: item.title,
                  decoration: const InputDecoration(labelText: 'Name'),
                  onChanged: (value) {
                    item.title = value;
                    onChanged();
                  },
                ),
              ),
              IconButton(
                  onPressed: onDelete, icon: const Icon(Icons.delete_outline)),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: item.dosage,
                  decoration: const InputDecoration(labelText: 'Dosage'),
                  onChanged: (value) {
                    item.dosage = value;
                    onChanged();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  initialValue: item.time,
                  decoration: const InputDecoration(labelText: 'Time'),
                  onChanged: (value) {
                    item.time = _normalizeTime(value);
                    onChanged();
                  },
                ),
              ),
            ],
          ),
          TextFormField(
            initialValue: item.notes,
            decoration: const InputDecoration(labelText: 'Product notes'),
            onChanged: (value) {
              item.notes = value;
              onChanged();
            },
          ),
          DropdownButtonFormField<String>(
            initialValue: item.timingRule,
            decoration: const InputDecoration(labelText: 'Timing rule'),
            items: const [
              DropdownMenuItem(
                value: 'after breakfast',
                child: Text('After breakfast'),
              ),
              DropdownMenuItem(
                value: 'after workout',
                child: Text('After workout'),
              ),
              DropdownMenuItem(
                value: 'after lunch',
                child: Text('After lunch'),
              ),
              DropdownMenuItem(
                value: 'before bed',
                child: Text('Before bed'),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                item.timingRule = value;
                onChanged();
              }
            },
          ),
          DropdownButtonFormField<String>(
            initialValue: item.repeatRule,
            decoration: const InputDecoration(labelText: 'Repeat days'),
            items: const [
              DropdownMenuItem(value: 'daily', child: Text('Daily')),
              DropdownMenuItem(
                  value: 'weekly:1,2,3,4,5', child: Text('Weekdays')),
              DropdownMenuItem(value: 'weekly:6,7', child: Text('Weekends')),
            ],
            onChanged: (value) {
              if (value != null) {
                item.repeatRule = value;
                onChanged();
              }
            },
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Reminder'),
            value: item.reminderEnabled,
            onChanged: (value) {
              item.reminderEnabled = value;
              onChanged();
            },
          ),
        ],
      ),
    );
  }
}

String _normalizeTime(String raw) {
  final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(raw.trim());
  if (match == null) return '08:00';
  final hour = (int.tryParse(match.group(1)!) ?? 8).clamp(0, 23);
  final minute = (int.tryParse(match.group(2)!) ?? 0).clamp(0, 59);
  return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

({String time, String timingRule}) _defaultSupplementTiming(
  int index,
  String name,
) {
  final clean = name.toLowerCase();
  if (clean.contains('whey') || clean.contains('protein')) {
    return (time: '18:30', timingRule: 'after workout');
  }
  if (clean.contains('omega') || clean.contains('fish oil')) {
    return (time: '13:30', timingRule: 'after lunch');
  }
  if (clean.contains('magnesium') || clean.contains('melatonin')) {
    return (time: '22:00', timingRule: 'before bed');
  }
  if (clean.contains('creatine')) {
    return (time: '18:30', timingRule: 'after workout');
  }
  if (clean.contains('vitamin d') || clean.contains('multi')) {
    return (time: '08:30', timingRule: 'after breakfast');
  }
  const defaults = [
    (time: '08:30', timingRule: 'after breakfast'),
    (time: '18:30', timingRule: 'after workout'),
    (time: '13:30', timingRule: 'after lunch'),
    (time: '22:00', timingRule: 'before bed'),
  ];
  return defaults[index % defaults.length];
}

String _defaultSupplementDosage(String name) {
  final clean = name.toLowerCase();
  if (clean.contains('creatine')) return '3-5 g';
  if (clean.contains('whey') || clean.contains('protein')) return '1 scoop';
  if (clean.contains('vitamin d')) return '1000 IU';
  if (clean.contains('omega')) return '1 capsule';
  return '';
}

String _normalizeTimingRule(String raw) {
  final clean = raw.trim().toLowerCase();
  const allowed = {
    'after breakfast',
    'after workout',
    'after lunch',
    'before bed',
  };
  if (allowed.contains(clean)) return clean;
  if (clean.contains('workout') || clean.contains('exercise')) {
    return 'after workout';
  }
  if (clean.contains('lunch')) return 'after lunch';
  if (clean.contains('bed') || clean.contains('night')) return 'before bed';
  return 'after breakfast';
}

List<String> _stringList(Object? raw) {
  if (raw is List) {
    return raw
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
  final value = raw?.toString().trim() ?? '';
  return value.isEmpty ? const [] : [value];
}

double _templateConfidence(Object? raw) {
  final value = raw is num ? raw.toDouble() : double.tryParse('$raw') ?? 0.75;
  return value.clamp(0.0, 1.0).toDouble();
}

String _notesWithDosage(String dosage, String notes) {
  final cleanDosage = dosage.trim();
  final cleanNotes = notes.trim();
  if (cleanDosage.isEmpty) return cleanNotes;
  if (cleanNotes.toLowerCase().contains('dosage:')) return cleanNotes;
  if (cleanNotes.isEmpty) return 'Dosage: $cleanDosage';
  return 'Dosage: $cleanDosage. $cleanNotes';
}

String _endTime(String startTime, int durationMinutes) {
  final parts = startTime.split(':');
  final hour = int.tryParse(parts.first) ?? 8;
  final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
  final start = DateTime(2026, 1, 1, hour, minute);
  final end = start.add(Duration(minutes: durationMinutes));
  return '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}';
}
