import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus2/core/liquid_ui/liquid_ui.dart';
import 'package:optivus2/models/goal_model.dart';
import 'package:optivus2/providers/goal_provider.dart';

class IdentityEditorScreen extends ConsumerStatefulWidget {
  final String? initialTitle;
  final String? initialColorHex;
  final GoalModel? existingGoal;

  const IdentityEditorScreen({
    super.key,
    this.initialTitle,
    this.initialColorHex,
    this.existingGoal,
  });

  @override
  ConsumerState<IdentityEditorScreen> createState() => _IdentityEditorScreenState();
}

class _IdentityEditorScreenState extends ConsumerState<IdentityEditorScreen> {
  late TextEditingController _titleController;
  late TextEditingController _emojiController;
  late TextEditingController _definitionController;
  late TextEditingController _contributorsController;
  late TextEditingController _milestoneController;

  String _selectedColor = '#14B8A6';
  DateTime? _targetDate;
  bool _isOngoing = true;
  bool _isSaving = false;

  final List<String> _colors = [
    '#22C55E', // Green
    '#3B82F6', // Blue
    '#A855F7', // Purple
    '#EAB308', // Yellow
    '#14B8A6', // Teal
    '#06B6D4', // Cyan
    '#F97316', // Orange
    '#EC4899', // Pink
  ];

  @override
  void initState() {
    super.initState();
    final goal = widget.existingGoal;
    _titleController = TextEditingController(text: goal?.title ?? widget.initialTitle ?? '');
    _emojiController = TextEditingController(text: goal?.iconName ?? '');
    _definitionController = TextEditingController(text: goal?.why ?? '');
    _contributorsController = TextEditingController(text: goal?.connectedRoutineTypes.join(', ') ?? '');
    _milestoneController = TextEditingController();
    
    _selectedColor = goal?.colorHex ?? widget.initialColorHex ?? _colors[4];
    _targetDate = goal?.targetDate;
    _isOngoing = goal?.targetDate == null;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _emojiController.dispose();
    _definitionController.dispose();
    _contributorsController.dispose();
    _milestoneController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
    );
    if (picked != null) {
      setState(() {
        _targetDate = picked;
        _isOngoing = false;
      });
    }
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      final goalRepo = ref.read(goalRepositoryProvider);
      final isNew = widget.existingGoal == null;
      final docId = widget.existingGoal?.goalId ?? 
          FirebaseFirestore.instance.collection('tmp').doc().id;

      final milestones = List<GoalMilestone>.from(widget.existingGoal?.milestones ?? []);
      if (isNew && _milestoneController.text.trim().isNotEmpty) {
        milestones.add(GoalMilestone(
          milestoneId: FirebaseFirestore.instance.collection('tmp').doc().id,
          title: _milestoneController.text.trim(),
        ));
      }

      final newGoal = GoalModel(
        goalId: docId,
        title: title,
        iconName: _emojiController.text.trim(), 
        colorHex: _selectedColor,
        why: _definitionController.text.trim(),
        connectedRoutineTypes: _contributorsController.text
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList(),
        targetDate: _isOngoing ? null : _targetDate,
        milestones: milestones,
        status: widget.existingGoal?.status ?? GoalStatus.active,
        createdAt: widget.existingGoal?.createdAt,
      );

      if (isNew) {
        await goalRepo.createGoal(newGoal);
      } else {
        await goalRepo.updateGoal(newGoal);
      }

      if (mounted) {
        Navigator.pop(context);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Color _parseColor(String colorHex) {
    if (colorHex.length == 7) {
      try {
        return Color(int.parse(colorHex.substring(1, 7), radix: 16) + 0xFF000000);
      } catch (_) {}
    }
    return kMint;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          widget.existingGoal == null ? 'New Identity' : 'Edit Identity',
          style: const TextStyle(
            color: kInk,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        iconTheme: const IconThemeData(color: kInk),
        actions: [
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(right: 16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: kMint),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _save,
              child: const Text(
                'Save',
                style: TextStyle(
                  color: kMint,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Emoji and Title
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: kSub.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: TextField(
                        controller: _emojiController,
                        textAlign: TextAlign.center,
                        maxLength: 2,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          counterText: '',
                          hintText: '🎯',
                        ),
                        style: const TextStyle(fontSize: 28),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _titleController,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: kInk,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Identity Name',
                        hintStyle: TextStyle(
                          color: kSub.withValues(alpha: 0.5),
                        ),
                        border: UnderlineInputBorder(
                          borderSide: BorderSide(color: kSub.withValues(alpha: 0.2)),
                        ),
                        focusedBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: kMint, width: 2),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Colors
              const Text(
                'Color',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: kSub,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _colors.map((c) {
                  final color = _parseColor(c);
                  final isSelected = c == _selectedColor;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedColor = c);
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: kInk, width: 3)
                            : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),

              // Definition
              const Text(
                'One-Sentence Definition',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: kSub,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _definitionController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'e.g. I am the type of person who...',
                  filled: true,
                  fillColor: kSub.withValues(alpha: 0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Suggested Contributors
              const Text(
                'Suggested Contributors',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: kSub,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _contributorsController,
                decoration: InputDecoration(
                  hintText: 'e.g. Running, Drinking Water...',
                  filled: true,
                  fillColor: kSub.withValues(alpha: 0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Target Date / Ongoing
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Ongoing Identity',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: kInk,
                    ),
                  ),
                  Switch(
                    value: _isOngoing,
                    activeThumbColor: kMint,
                    onChanged: (val) {
                      setState(() => _isOngoing = val);
                    },
                  ),
                ],
              ),
              if (!_isOngoing) ...[
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _selectDate,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: kSub.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, color: kSub, size: 20),
                        const SizedBox(width: 12),
                        Text(
                          _targetDate == null
                              ? 'Select target date'
                              : '${_targetDate!.month}/${_targetDate!.day}/${_targetDate!.year}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: kInk,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 32),

              // Initial Milestone (Only on create)
              if (widget.existingGoal == null) ...[
                const Text(
                  'Initial Milestone',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: kSub,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _milestoneController,
                  decoration: InputDecoration(
                    hintText: 'e.g. Run first 5k',
                    filled: true,
                    fillColor: kSub.withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
