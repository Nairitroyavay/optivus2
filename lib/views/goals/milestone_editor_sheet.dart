import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus2/core/liquid_ui/liquid_ui.dart';
import 'package:optivus2/models/goal_model.dart';
import 'package:optivus2/providers/goal_provider.dart';

class MilestoneEditorSheet extends ConsumerStatefulWidget {
  final GoalModel goal;
  final GoalMilestone? existingMilestone;

  const MilestoneEditorSheet({
    super.key,
    required this.goal,
    this.existingMilestone,
  });

  static void show(BuildContext context, {required GoalModel goal, GoalMilestone? milestone}) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: MilestoneEditorSheet(goal: goal, existingMilestone: milestone),
      ),
    );
  }

  @override
  ConsumerState<MilestoneEditorSheet> createState() => _MilestoneEditorSheetState();
}

class _MilestoneEditorSheetState extends ConsumerState<MilestoneEditorSheet> {
  late TextEditingController _titleController;
  bool _isCompleted = false;
  bool _isAuto = false;
  DateTime? _dueDate;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.existingMilestone?.title ?? '');
    _isCompleted = widget.existingMilestone?.completed ?? false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
    );
    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      final repo = ref.read(goalRepositoryProvider);
      final isNew = widget.existingMilestone == null;
      final milestoneId = widget.existingMilestone?.milestoneId ?? 
          FirebaseFirestore.instance.collection('tmp').doc().id;

      final updatedMilestone = GoalMilestone(
        milestoneId: milestoneId,
        title: title,
        completed: _isCompleted,
        completedAt: _isCompleted 
            ? (widget.existingMilestone?.completedAt ?? DateTime.now())
            : null,
      );

      final currentMilestones = List<GoalMilestone>.from(widget.goal.milestones);
      
      if (isNew) {
        currentMilestones.add(updatedMilestone);
      } else {
        final index = currentMilestones.indexWhere((m) => m.milestoneId == milestoneId);
        if (index >= 0) {
          currentMilestones[index] = updatedMilestone;
        } else {
          currentMilestones.add(updatedMilestone); // fallback
        }
      }

      final updatedGoal = widget.goal.copyWith(
        milestones: currentMilestones,
        updatedAt: DateTime.now(),
      );

      await repo.updateGoal(updatedGoal);

      if (mounted) {
        Navigator.pop(context);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kBg,
        borderRadius: BorderRadius.circular(24),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: kSub.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.existingMilestone == null ? 'New Milestone' : 'Edit Milestone',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: kInk,
                    ),
                  ),
                  if (_isSaving)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: kMint),
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
              const SizedBox(height: 20),

              TextField(
                controller: _titleController,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: kInk,
                ),
                decoration: InputDecoration(
                  hintText: 'Milestone title',
                  hintStyle: TextStyle(color: kSub.withValues(alpha: 0.5)),
                  filled: true,
                  fillColor: kSub.withValues(alpha: 0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Manual / Auto Tracking
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Auto-Track Progress',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: kInk,
                    ),
                  ),
                  Switch(
                    value: _isAuto,
                    activeThumbColor: kMint,
                    onChanged: (val) {
                      setState(() => _isAuto = val);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Due Date
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
                        _dueDate == null
                            ? 'Select due date'
                            : '${_dueDate!.month}/${_dueDate!.day}/${_dueDate!.year}',
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
              const SizedBox(height: 24),

              if (widget.existingMilestone != null) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Completed',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: kInk,
                      ),
                    ),
                    Switch(
                      value: _isCompleted,
                      activeThumbColor: kMint,
                      onChanged: (val) {
                        setState(() => _isCompleted = val);
                      },
                    ),
                  ],
                ),
              ] else ...[
                // For new milestones, we also allow marking it completed initially (rare but possible)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Mark as completed',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: kInk,
                      ),
                    ),
                    Switch(
                      value: _isCompleted,
                      activeThumbColor: kMint,
                      onChanged: (val) {
                        setState(() => _isCompleted = val);
                      },
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
