import 'package:flutter/material.dart';
import 'package:optivus2/core/liquid_ui/liquid_ui.dart';
import 'package:optivus2/models/habit_model.dart';
import 'package:optivus2/views/habits/variants/tracker_variant_base.dart';

class ReadingTrackerView extends StatelessWidget {
  final HabitModel habit;

  const ReadingTrackerView({super.key, required this.habit});

  @override
  Widget build(BuildContext context) {
    return TrackerVariantView(
      habit: habit,
      title: 'Reading',
      statusLabel: 'Today progress',
      emptyLabel: 'No reading logs in the last 7 days.',
      insightCopy:
          'AI interpretation placeholder: infer best reading windows from consistency and task load.',
      icon: Icons.auto_stories_rounded,
      accent: kAmber,
    );
  }
}
