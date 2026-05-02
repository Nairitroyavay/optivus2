import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus2/core/liquid_ui/liquid_ui.dart';
import 'package:optivus2/core/providers.dart';
import 'package:optivus2/core/utils/uuid_generator.dart';
import 'package:optivus2/providers/routine_provider.dart';

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
  String notes;
  bool reminderEnabled;

  _SupplementItem({
    required this.templateId,
    required this.title,
    required this.dosage,
    required this.time,
    this.durationMinutes = 5,
    this.repeatRule = 'daily',
    this.notes = '',
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
      'dosage': dosage.trim(),
      'notes': notes.trim(),
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
        notes: item['notes']?.toString() ?? '',
        reminderEnabled: item['reminderEnabled'] == true,
      );
    }));
    if (_items.isEmpty) {
      _items.add(_SupplementItem(
        templateId: generateId(),
        title: 'Vitamin D',
        dosage: '1000 IU',
        time: '08:00',
        notes: 'With breakfast',
      ));
    }
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
    if (sourceText.isEmpty) return;
    var generated = <Map<String, dynamic>>[];
    try {
      generated =
          await ref.read(routineRepositoryProvider).previewRoutineImport(
                routineType: 'supplements',
                mode: 'text_ai',
                sourceText: sourceText,
              );
    } catch (e) {
      debugPrint('[SupplementSetup] routineImport preview failed: $e');
    }

    final items = generated.isNotEmpty
        ? generated.map(_supplementFromTemplate).toList()
        : _supplementsFromText(sourceText);
    _showSupplementReview(items, {
      'mode': 'text_ai',
      'sourceText': sourceText,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  List<_SupplementItem> _supplementsFromText(String sourceText) {
    final lines = sourceText
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    return lines.map((line) {
      final parts = line.split(RegExp(r'[,|-]')).map((p) => p.trim()).toList();
      return _SupplementItem(
        templateId: generateId(),
        title: parts.isNotEmpty ? parts[0] : line,
        dosage: parts.length > 1 ? parts[1] : '',
        time: parts.length > 2 ? _normalizeTime(parts[2]) : '08:00',
        notes: 'Generated from text import',
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
      notes: template['notes']?.toString() ?? '',
      reminderEnabled: template['reminderEnabled'] == true,
    );
  }

  Future<void> _showSupplementReview(
    List<_SupplementItem> items,
    Map<String, dynamic> importMetadata,
  ) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final review = List<_SupplementItem>.from(items);
        return StatefulBuilder(builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.72,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Review generated supplements',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.separated(
                      itemCount: review.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) => _SupplementCard(
                        item: review[index],
                        onChanged: () => setSheetState(() {}),
                        onDelete: () =>
                            setSheetState(() => review.removeAt(index)),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _generateFromText();
                        },
                        child: const Text('Regenerate'),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: () {
                          setState(() {
                            _items
                              ..clear()
                              ..addAll(review);
                            _pendingImportMetadata = importMetadata;
                          });
                          Navigator.pop(ctx);
                        },
                        child: const Text('Accept all'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  Future<void> _save() async {
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
                  child: TextField(
                    controller: _textImportCtrl,
                    minLines: 3,
                    maxLines: 5,
                    decoration: InputDecoration(
                      hintText:
                          'Paste supplement plan. One per line: Vitamin D, 1000 IU, 08:00',
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.82),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon: IconButton(
                        onPressed: _generateFromText,
                        icon: const Icon(Icons.auto_awesome_rounded),
                      ),
                    ),
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

String _endTime(String startTime, int durationMinutes) {
  final parts = startTime.split(':');
  final hour = int.tryParse(parts.first) ?? 8;
  final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
  final start = DateTime(2026, 1, 1, hour, minute);
  final end = start.add(Duration(minutes: durationMinutes));
  return '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}';
}
