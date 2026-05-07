import 'package:flutter/material.dart';

import 'package:optivus2/core/liquid_ui/liquid_ui.dart';

enum ActivityPauseAction { resume, finish, cancel }

class ActivityPauseBottomSheet extends StatelessWidget {
  const ActivityPauseBottomSheet({super.key});

  static Future<ActivityPauseAction?> show(BuildContext context) {
    return showModalBottomSheet<ActivityPauseAction>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const ActivityPauseBottomSheet(),
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
                'Activity paused',
                style: TextStyle(
                  color: kInk,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Moving time and distance are stopped until you resume.',
                style: TextStyle(
                  color: kSub.withValues(alpha: 0.72),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              LiquidButton(
                label: 'Resume',
                leading: const Icon(Icons.play_arrow_rounded, color: kWhite),
                color: kMint,
                onTap: () =>
                    Navigator.of(context).pop(ActivityPauseAction.resume),
              ),
              const SizedBox(height: 10),
              LiquidButton(
                label: 'Finish',
                leading: const Icon(Icons.flag_rounded, color: kWhite),
                color: kBlue,
                onTap: () =>
                    Navigator.of(context).pop(ActivityPauseAction.finish),
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: () =>
                    Navigator.of(context).pop(ActivityPauseAction.cancel),
                icon: const Icon(Icons.close_rounded, color: kCoral),
                label: const Text(
                  'Cancel activity',
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
