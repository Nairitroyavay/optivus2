import 'package:flutter/material.dart';
import 'package:optivus2/core/liquid_ui/liquid_ui.dart';
import 'package:optivus2/models/habit_model.dart';
import 'package:optivus2/views/habits/variants/tracker_variant_base.dart';

class SmokingTrackerView extends StatelessWidget {
  final HabitModel habit;

  const SmokingTrackerView({super.key, required this.habit});

  @override
  Widget build(BuildContext context) {
    return TrackerVariantView(
      habit: habit,
      title: 'Smoking',
      statusLabel: 'Today slips',
      emptyLabel: 'No slips logged in the last 7 days.',
      insightCopy:
          'AI interpretation placeholder: watch trigger clusters and relapse windows before suggesting recovery steps.',
      icon: Icons.smoke_free_rounded,
      accent: kCoral,
    );
  }
}
