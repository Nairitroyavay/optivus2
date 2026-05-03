import 'package:flutter/material.dart';
import 'package:optivus2/core/liquid_ui/liquid_ui.dart';
import 'package:optivus2/models/habit_model.dart';
import 'package:optivus2/views/habits/variants/tracker_variant_base.dart';

class ProcrastinationTrackerView extends StatelessWidget {
  final HabitModel habit;

  const ProcrastinationTrackerView({super.key, required this.habit});

  @override
  Widget build(BuildContext context) {
    return TrackerVariantView(
      habit: habit,
      title: 'Procrastination',
      statusLabel: 'Today delays',
      emptyLabel: 'No procrastination logs in the last 7 days.',
      insightCopy:
          'AI interpretation placeholder: identify task types, times, and context switches that precede delay.',
      icon: Icons.hourglass_bottom_rounded,
      accent: kPurple,
    );
  }
}
