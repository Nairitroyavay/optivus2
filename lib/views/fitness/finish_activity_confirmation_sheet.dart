import 'package:flutter/material.dart';

import 'package:optivus2/core/liquid_ui/liquid_ui.dart';

enum FinishActivityAction { save, resume, discard }

class FinishActivityConfirmationSheet extends StatelessWidget {
  final String distance;
  final String duration;
  final String paceOrSpeed;
  final String calories;

  const FinishActivityConfirmationSheet({
    super.key,
    required this.distance,
    required this.duration,
    required this.paceOrSpeed,
    required this.calories,
  });

  static Future<FinishActivityAction?> show(
    BuildContext context, {
    required String distance,
    required String duration,
    required String paceOrSpeed,
    required String calories,
  }) {
    return showModalBottomSheet<FinishActivityAction>(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      builder: (_) => FinishActivityConfirmationSheet(
        distance: distance,
        duration: duration,
        paceOrSpeed: paceOrSpeed,
        calories: calories,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: LiquidCard(
        frosted: true,
        padding: const EdgeInsets.all(18),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Finish activity?',
                style: TextStyle(
                  color: kInk,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _StatPill(label: 'Distance', value: distance),
                  _StatPill(label: 'Time', value: duration),
                  _StatPill(label: 'Pace/Speed', value: paceOrSpeed),
                  _StatPill(label: 'Calories', value: calories),
                ],
              ),
              const SizedBox(height: 18),
              LiquidButton(
                label: 'Finish and Save',
                leading: const Icon(Icons.check_rounded, color: kWhite),
                color: kMint,
                onTap: () =>
                    Navigator.of(context).pop(FinishActivityAction.save),
              ),
              const SizedBox(height: 10),
              LiquidButton(
                label: 'Resume',
                leading: const Icon(Icons.play_arrow_rounded, color: kWhite),
                color: kBlue,
                onTap: () =>
                    Navigator.of(context).pop(FinishActivityAction.resume),
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: () =>
                    Navigator.of(context).pop(FinishActivityAction.discard),
                icon: const Icon(Icons.delete_outline_rounded, color: kCoral),
                label: const Text(
                  'Discard',
                  style: TextStyle(
                    color: kCoral,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;

  const _StatPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 145,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kWhite.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kWhite.withValues(alpha: 0.85)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: kSub.withValues(alpha: 0.68),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: kInk,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
