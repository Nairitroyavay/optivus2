import 'package:flutter/material.dart';
import 'package:optivus2/core/liquid_ui/liquid_ui.dart';
import 'package:optivus2/models/habit_model.dart';
import 'package:optivus2/views/habits/variants/tracker_variant_base.dart';

class HydrationTrackerView extends StatelessWidget {
  final HabitModel habit;

  const HydrationTrackerView({super.key, required this.habit});

  @override
  Widget build(BuildContext context) {
    return TrackerVariantView(
      habit: habit,
      title: 'Hydration',
      statusLabel: 'Today intake',
      emptyLabel: 'No hydration logs in the last 7 days.',
      insightCopy:
          'AI interpretation placeholder: connect hydration consistency with energy, workout, and sleep patterns.',
      icon: Icons.water_drop_rounded,
      accent: kBlue,
    );
  }
}
