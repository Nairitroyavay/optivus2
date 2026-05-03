import 'package:flutter/material.dart';
import 'package:optivus2/core/liquid_ui/liquid_ui.dart';
import 'package:optivus2/models/habit_model.dart';
import 'package:optivus2/views/habits/variants/tracker_variant_base.dart';

class ScreenTimeTrackerView extends StatelessWidget {
  final HabitModel habit;

  const ScreenTimeTrackerView({super.key, required this.habit});

  @override
  Widget build(BuildContext context) {
    return TrackerVariantView(
      habit: habit,
      title: 'Screen Time',
      statusLabel: 'Today logged',
      emptyLabel: 'No screen-time check-ins logged this week.',
      insightCopy:
          'AI interpretation placeholder: compare logged usage with focus blocks and late-day drift.',
      icon: Icons.phone_android_rounded,
      accent: kBlue,
    );
  }
}
