import 'package:flutter/material.dart';
import 'package:optivus2/core/liquid_ui/liquid_ui.dart';
import 'package:optivus2/models/habit_model.dart';
import 'package:optivus2/views/habits/variants/tracker_variant_base.dart';

class RoutineCompletionTrackerView extends StatelessWidget {
  final HabitModel habit;

  const RoutineCompletionTrackerView({super.key, required this.habit});

  @override
  Widget build(BuildContext context) {
    return TrackerVariantView(
      habit: habit,
      title: 'Routine Completion',
      statusLabel: 'Today routine score',
      emptyLabel: 'No routine summaries for the last 7 days.',
      insightCopy:
          'AI interpretation placeholder: read day-close summaries to explain which routines drive the score.',
      icon: Icons.fact_check_rounded,
      accent: kBlue,
      dataMode: VariantDataMode.dailySummaries,
    );
  }
}
