import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus2/core/liquid_ui/liquid_ui.dart';
import 'package:optivus2/core/providers.dart';
import 'package:optivus2/models/habit_model.dart';

class LogHabitSheet extends ConsumerStatefulWidget {
  final HabitModel? habit;

  const LogHabitSheet({super.key, this.habit});

  @override
  ConsumerState<LogHabitSheet> createState() => _LogHabitSheetState();
}

class _LogHabitSheetState extends ConsumerState<LogHabitSheet> {
  HabitModel? _selectedHabit;
  late final TextEditingController _amountController;
  late final TextEditingController _unitController;
  final _triggerController = TextEditingController();
  final _noteController = TextEditingController();
  bool _isLogging = false;

  @override
  void initState() {
    super.initState();
    _selectedHabit = widget.habit;
    _amountController = TextEditingController(
      text: widget.habit?.kind == HabitKind.bad ? '1' : '',
    );
    _unitController = TextEditingController(text: widget.habit?.unit ?? '');
  }

  @override
  void dispose() {
    _amountController.dispose();
    _unitController.dispose();
    _triggerController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _selectHabit(HabitModel habit) {
    setState(() {
      _selectedHabit = habit;
      _amountController.text = habit.kind == HabitKind.bad ? '1' : '';
      _unitController.text = habit.unit;
      _triggerController.clear();
      _noteController.clear();
    });
  }

  Future<void> _submit() async {
    final habit = _selectedHabit;
    if (habit == null || _isLogging) return;

    final amountText = _amountController.text.trim();
    final parsed = amountText.isEmpty ? null : num.tryParse(amountText);
    if (amountText.isNotEmpty && (parsed == null || parsed <= 0)) {
      _showError('Enter a positive amount.');
      return;
    }

    setState(() => _isLogging = true);
    try {
      final habitService = ref.read(habitServiceProvider);
      final note = _noteController.text.trim();

      if (habit.kind == HabitKind.good) {
        await habitService.logGood(
          habit.id,
          amount: parsed ?? 1,
          unit: _unitController.text.trim().isEmpty
              ? habit.unit
              : _unitController.text.trim(),
          note: note.isEmpty ? null : note,
        );
      } else {
        await habitService.logSlip(
          habit.id,
          count: parsed ?? 1,
          trigger: _triggerController.text.trim().isEmpty
              ? null
              : _triggerController.text.trim(),
          note: note.isEmpty ? null : note,
        );
      }

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      _showError('Failed to log habit: $e');
    } finally {
      if (mounted) setState(() => _isLogging = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: kCoral),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: EdgeInsets.fromLTRB(24, 10, 24, 24 + bottom),
      child: SafeArea(
        top: false,
        child: AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: _selectedHabit == null ? _habitPicker() : _logForm(),
        ),
      ),
    );
  }

  Widget _habitPicker() {
    final habitsAsync = ref.watch(habitsProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const LiquidSheetHandle(),
        const SizedBox(height: 16),
        const Text(
          'Log Habit',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: kInk,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        habitsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator(color: kAmber)),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Failed to load habits\n$e',
              textAlign: TextAlign.center,
              style: const TextStyle(color: kCoral),
            ),
          ),
          data: (habits) {
            if (habits.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No habits yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: kSub, fontSize: 16),
                ),
              );
            }

            return ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 420),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const BouncingScrollPhysics(),
                itemCount: habits.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final habit = habits[index];
                  return _HabitChoiceTile(
                    habit: habit,
                    onTap: () => _selectHabit(habit),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _logForm() {
    final habit = _selectedHabit!;
    final isGood = habit.kind == HabitKind.good;
    final color = isGood ? kMint : kCoral;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const LiquidSheetHandle(),
          const SizedBox(height: 16),
          Row(
            children: [
              if (widget.habit == null)
                IconButton(
                  tooltip: 'Back',
                  icon: const Icon(Icons.arrow_back_rounded, color: kInk),
                  onPressed: _isLogging
                      ? null
                      : () => setState(() => _selectedHabit = null),
                ),
              _HabitIcon(habit: habit, color: color),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isGood ? 'Log Good Habit' : 'Log Slip',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: kInk,
                      ),
                    ),
                    Text(
                      habit.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: kSub.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          if (isGood) ...[
            Row(
              children: [
                Expanded(
                  child: LiquidTextField(
                    hint: 'Amount',
                    prefixIcon: Icons.add_circle_outline_rounded,
                    controller: _amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    suffixWidget: Text(
                      habit.unit,
                      style: TextStyle(
                        color: kSub.withValues(alpha: 0.75),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 112,
                  child: LiquidTextField(
                    hint: 'Unit',
                    prefixIcon: Icons.straighten_rounded,
                    controller: _unitController,
                  ),
                ),
              ],
            ),
          ] else ...[
            LiquidTextField(
              hint: 'Count',
              prefixIcon: Icons.tag_rounded,
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            LiquidTextField(
              hint: 'Trigger (stress, boredom, social...)',
              prefixIcon: Icons.flash_on_rounded,
              controller: _triggerController,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: kMint.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: kMint.withValues(alpha: 0.25)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.health_and_safety_rounded,
                      color: kMint.withValues(alpha: 0.9), size: 20),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Log it, reset, and take the next useful step. One slip does not define the rest of today.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                        color: kInk,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          LiquidTextField(
            hint: 'Note (optional)',
            prefixIcon: Icons.edit_note_rounded,
            controller: _noteController,
          ),
          const SizedBox(height: 22),
          LiquidButton(
            label: _isLogging ? 'Logging...' : (isGood ? 'Log' : 'Log Slip'),
            color: color,
            leading: Icon(
              isGood ? Icons.check_rounded : Icons.add_alert_rounded,
              color: Colors.white,
              size: 19,
            ),
            onTap: _isLogging ? null : _submit,
          ),
          const SizedBox(height: 10),
          LiquidButton.outline(
            label: 'Cancel',
            color: kSub,
            height: 48,
            onTap: _isLogging ? null : () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
  }
}

class _HabitChoiceTile extends StatelessWidget {
  final HabitModel habit;
  final VoidCallback onTap;

  const _HabitChoiceTile({required this.habit, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isGood = habit.kind == HabitKind.good;
    final color = isGood ? kMint : kCoral;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: LiquidCard.solid(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        radius: 20,
        tint: color.withValues(alpha: 0.08),
        child: Row(
          children: [
            _HabitIcon(habit: habit, color: color),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    habit.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: kInk,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isGood
                        ? '${habit.dailyGoal ?? 1} ${habit.unit}/day'
                        : 'Slip tracking',
                    style: TextStyle(
                      fontSize: 12,
                      color: kSub.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: color),
          ],
        ),
      ),
    );
  }
}

class _HabitIcon extends StatelessWidget {
  final HabitModel habit;
  final Color color;

  const _HabitIcon({required this.habit, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Center(
        child: habit.emoji != null && habit.emoji!.isNotEmpty
            ? Text(habit.emoji!, style: const TextStyle(fontSize: 23))
            : Icon(
                habit.kind == HabitKind.good
                    ? Icons.check_circle_outline_rounded
                    : Icons.block_rounded,
                color: color,
                size: 23,
              ),
      ),
    );
  }
}
