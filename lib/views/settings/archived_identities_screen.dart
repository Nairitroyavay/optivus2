import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/liquid_ui/liquid_ui.dart';
import '../../models/goal_model.dart';
import '../../providers/goal_provider.dart';
import '../../repositories/goal_repository.dart';

final archivedIdentitiesProvider =
    StreamProvider.autoDispose<List<ArchivedIdentityRecord>>((ref) {
  return ref.watch(goalRepositoryProvider).watchInactiveGoals();
});

class ArchivedIdentitiesScreen extends ConsumerWidget {
  const ArchivedIdentitiesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final archivedAsync = ref.watch(archivedIdentitiesProvider);

    return LiquidBg(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: kInk),
            onPressed: () => context.pop(),
          ),
          title: const Text(
            'Archived identities',
            style: TextStyle(color: kInk, fontWeight: FontWeight.w700),
          ),
        ),
        body: archivedAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: kBlue),
          ),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Could not load archived identities: $e',
                textAlign: TextAlign.center,
                style: const TextStyle(color: kCoral),
              ),
            ),
          ),
          data: (records) {
            if (records.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No paused or archived identities yet.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: kSub),
                  ),
                ),
              );
            }

            return ListView.separated(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              itemBuilder: (context, index) => _ArchivedIdentityCard(
                record: records[index],
              ),
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemCount: records.length,
            );
          },
        ),
      ),
    );
  }
}

class _ArchivedIdentityCard extends ConsumerWidget {
  final ArchivedIdentityRecord record;

  const _ArchivedIdentityCard({required this.record});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goal = record.goal;
    final tag = goal.identityTag.isNotEmpty ? goal.identityTag : goal.title;
    final summary = record.archiveSummary;
    final isPaused = goal.status == GoalStatus.paused;

    return LiquidCard.solid(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: (isPaused ? kAmber : kSub).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isPaused
                      ? Icons.pause_circle_outline
                      : Icons.archive_outlined,
                  color: isPaused ? kAmber : kSub,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tag,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: kInk,
                      ),
                    ),
                    if (goal.archivedAt != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${isPaused ? 'Paused' : 'Archived'} ${_dateLabel(goal.archivedAt!)}',
                        style: const TextStyle(fontSize: 13, color: kSub),
                      ),
                    ] else if (isPaused) ...[
                      const SizedBox(height: 4),
                      const Text(
                        'Paused',
                        style: TextStyle(fontSize: 13, color: kSub),
                      ),
                    ],
                  ],
                ),
              ),
              Text(
                '${goal.progress}%',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: kMint,
                ),
              ),
            ],
          ),
          if (summary != null && summary.body.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: kAmber.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    summary.title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: kSub,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    summary.body,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.45,
                      color: kInk,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          LiquidButton.outline(
            label: 'Reactivate',
            color: kBlue,
            height: 48,
            leading: const Icon(Icons.restore_rounded, color: kBlue),
            onTap: () => _reactivate(context, ref, goal),
          ),
        ],
      ),
    );
  }

  Future<void> _reactivate(
    BuildContext context,
    WidgetRef ref,
    GoalModel goal,
  ) async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      await ref.read(goalRepositoryProvider).reactivateGoal(goal.goalId);
      messenger.showSnackBar(
        const SnackBar(content: Text('Identity reactivated.')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not reactivate identity: $e')),
      );
    }
  }

  static String _dateLabel(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }
}
