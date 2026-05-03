import 'package:flutter/material.dart';
import 'package:optivus2/core/liquid_ui/liquid_ui.dart';
import 'package:optivus2/models/habit_model.dart';
import 'package:optivus2/views/habits/variants/tracker_variant_base.dart';

class MeditationTrackerView extends StatelessWidget {
  final HabitModel habit;

  const MeditationTrackerView({super.key, required this.habit});

  @override
  Widget build(BuildContext context) {
    return TrackerVariantView(
      habit: habit,
      title: 'Meditation',
      statusLabel: 'Today minutes',
      emptyLabel: 'No meditation sessions logged this week.',
      insightCopy:
          'AI interpretation placeholder: compare session timing with stress markers and task recovery.',
      icon: Icons.self_improvement_rounded,
      accent: kPurple,
    );
  }
}
