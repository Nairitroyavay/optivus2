import 'package:flutter/material.dart';
import 'package:optivus2/core/liquid_ui/liquid_ui.dart';
import 'package:optivus2/models/habit_model.dart';
import 'package:optivus2/views/habits/variants/tracker_variant_base.dart';

class MoneySavingTrackerView extends StatelessWidget {
  final HabitModel habit;

  const MoneySavingTrackerView({super.key, required this.habit});

  @override
  Widget build(BuildContext context) {
    return TrackerVariantView(
      habit: habit,
      title: 'Money Saving',
      statusLabel: 'Today saved units',
      emptyLabel: 'No money-saving logs in the last 7 days.',
      insightCopy:
          'AI interpretation placeholder: translate avoided actions into savings and identity progress.',
      icon: Icons.savings_rounded,
      accent: kMint,
    );
  }
}
