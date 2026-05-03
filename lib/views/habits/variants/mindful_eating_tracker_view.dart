import 'package:flutter/material.dart';
import 'package:optivus2/core/liquid_ui/liquid_ui.dart';
import 'package:optivus2/models/habit_model.dart';
import 'package:optivus2/views/habits/variants/tracker_variant_base.dart';

class MindfulEatingTrackerView extends StatelessWidget {
  final HabitModel habit;

  const MindfulEatingTrackerView({super.key, required this.habit});

  @override
  Widget build(BuildContext context) {
    return TrackerVariantView(
      habit: habit,
      title: 'Mindful Eating',
      statusLabel: 'Today check-ins',
      emptyLabel: 'No mindful eating check-ins in the last 7 days.',
      insightCopy:
          'AI interpretation placeholder: keep food feedback neutral and pattern-focused, never punitive.',
      icon: Icons.restaurant_menu_rounded,
      accent: kMint,
    );
  }
}
