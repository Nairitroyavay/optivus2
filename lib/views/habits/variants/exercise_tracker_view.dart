import 'package:flutter/material.dart';
import 'package:optivus2/core/liquid_ui/liquid_ui.dart';
import 'package:optivus2/models/habit_model.dart';
import 'package:optivus2/views/habits/variants/tracker_variant_base.dart';

class ExerciseTrackerView extends StatelessWidget {
  final HabitModel habit;

  const ExerciseTrackerView({super.key, required this.habit});

  @override
  Widget build(BuildContext context) {
    return TrackerVariantView(
      habit: habit,
      title: 'Exercise',
      statusLabel: 'Today volume',
      emptyLabel: 'No exercise logs in the last 7 days.',
      insightCopy:
          'AI interpretation placeholder: relate workout consistency to sleep, energy, and recovery days.',
      icon: Icons.fitness_center_rounded,
      accent: kCoral,
    );
  }
}
