import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus2/core/liquid_ui/liquid_ui.dart';

import '../../services/firestore_service.dart';
import '../../providers/goal_provider.dart';
import '../../providers/identity_provider.dart';
import '../../models/goal_model.dart';
import '../../models/suggestion_model.dart';
import '../goals/identity_card.dart';
import '../goals/today_identity_push_card.dart';
import '../goals/milestones_strip.dart';

// ═════════════════════════════════════════════════════════════════════════════
// Goals-surface AI suggestion provider (scoped, not in core/providers.dart)
// Follows the exact trackerSuggestionsProvider pattern.
// ═════════════════════════════════════════════════════════════════════════════

final goalsSuggestionsProvider = StreamProvider<List<SuggestionModel>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value(const []);
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('suggestions')
      .where('status', isEqualTo: 'pending')
      .where('targetSurface', isEqualTo: 'goals')
      .limit(1)
      .snapshots()
      .map((snap) => snap.docs
          .map((d) => SuggestionModel.fromMap(d.data(), fallbackId: d.id))
          .toList());
});

// ═════════════════════════════════════════════════════════════════════════════
// Goals-surface profile/main stream (for identityStatement).
// Reads /users/{uid}/profile/main — the canonical profile doc.
// ═════════════════════════════════════════════════════════════════════════════

final goalsProfileProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value(null);
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection(FirestoreService.kProfile)
      .doc(FirestoreService.kProfileDoc)
      .snapshots()
      .map((snap) => snap.exists ? snap.data() : null);
});

// ═════════════════════════════════════════════════════════════════════════════
// GOALS TAB — UF §9.1 full surface
// ═════════════════════════════════════════════════════════════════════════════

class GoalsTab extends ConsumerWidget {
  const GoalsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(goalProvider);
    final identityAsync = ref.watch(identityProvider);
    final profileAsync = ref.watch(goalsProfileProvider);

    final goals = goalsAsync.valueOrNull ?? [];
    final identity = identityAsync.valueOrNull;
    final profileDoc = profileAsync.valueOrNull;
    final progressPct = identity?.progressPct ?? 0;
    final identities = identity?.identities ?? const <String>[];

    // Derive identity statement — check profile/main.identityStatement first,
    // then fall back to joined identities from the identity profile.
    final identityStatement = _resolveIdentityStatement(profileDoc, identities);

    // Active goals only (exclude completed for the grid, but keep for milestones)
    final activeGoals =
        goals.where((g) => g.status == GoalStatus.active).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: goals.isEmpty && goalsAsync.isLoading
            ? const _GoalsShimmer()
            : goals.isEmpty
                ? _EmptyState()
                : CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      // ── 1. Header ──
                      SliverToBoxAdapter(
                        child: _SectionHeader(
                          progressPct: progressPct,
                          goalCount: goals.length,
                        ),
                      ),

                      // ── 2. Identity Statement Card ──
                      if (identityStatement != null)
                        SliverToBoxAdapter(
                          child: _IdentityStatementCard(
                            statement: identityStatement,
                          ),
                        ),

                      // ── 3. Today's Identity Push Card ──
                      if (activeGoals.isNotEmpty)
                        SliverToBoxAdapter(
                          child: TodayIdentityPushCard(
                            activeGoals: activeGoals,
                          ),
                        ),

                      // ── 4. Identity Grid (2-column) ──
                      SliverToBoxAdapter(
                        child: _IdentityGridSection(goals: goals),
                      ),

                      // ── 5. Milestones Strip ──
                      SliverToBoxAdapter(
                        child: MilestonesStrip(goals: goals),
                      ),

                      // ── 6. AI Insight Card ──
                      const SliverToBoxAdapter(
                        child: _GoalsAiInsightCard(),
                      ),

                      // Bottom spacing
                      const SliverToBoxAdapter(
                        child: SizedBox(height: 100),
                      ),
                    ],
                  ),
      ),
    );
  }

  /// Resolves the identity statement from profile/main or identity labels.
  String? _resolveIdentityStatement(
    Map<String, dynamic>? profileDoc,
    List<String> identities,
  ) {
    // 1. Try the identityStatement field from /users/{uid}/profile/main
    final raw = profileDoc?['identityStatement'];
    if (raw is String && raw.trim().isNotEmpty) return raw.trim();

    // 2. Fall back to a sentence built from identity labels
    if (identities.isEmpty) return null;
    if (identities.length == 1) return 'I am ${identities.first}.';
    final joined = identities.take(3).join(', ');
    return 'I am $joined.';
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// 1. SECTION HEADER
// ═════════════════════════════════════════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  final int progressPct;
  final int goalCount;
  const _SectionHeader({required this.progressPct, required this.goalCount});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'GOALS — $progressPct% Identity Match',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: kSub,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Your Identities',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: kInk,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// 2. IDENTITY STATEMENT CARD
// ═════════════════════════════════════════════════════════════════════════════

class _IdentityStatementCard extends StatelessWidget {
  final String statement;
  const _IdentityStatementCard({required this.statement});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: LiquidCard(
        frosted: true,
        tint: kAmber.withValues(alpha: 0.06),
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    kAmber.withValues(alpha: 0.22),
                    kCoral.withValues(alpha: 0.14),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.format_quote_rounded,
                size: 20,
                color: kAmber.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'IDENTITY STATEMENT',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: kSub,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    statement,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: kInk,
                      height: 1.5,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// 4. IDENTITY GRID — 2-column
// ═════════════════════════════════════════════════════════════════════════════

class _IdentityGridSection extends StatelessWidget {
  final List<GoalModel> goals;
  const _IdentityGridSection({required this.goals});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'IDENTITIES',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: kSub,
                letterSpacing: 1.2,
              ),
            ),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.88,
            ),
            itemCount: goals.length,
            itemBuilder: (context, index) {
              return IdentityCard(goal: goals[index]);
            },
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// 6. AI INSIGHT CARD
// ═════════════════════════════════════════════════════════════════════════════

class _GoalsAiInsightCard extends ConsumerWidget {
  const _GoalsAiInsightCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suggestionsAsync = ref.watch(goalsSuggestionsProvider);

    return suggestionsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (suggestions) {
        if (suggestions.isEmpty) return const SizedBox.shrink();

        final suggestion = suggestions.first;
        final title =
            suggestion.title.isEmpty ? 'AI Insight' : suggestion.title;
        final body = suggestion.body;
        final reason = suggestion.reason.isEmpty ? null : suggestion.reason;

        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: LiquidCard(
            frosted: true,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: kPurple.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.auto_awesome_rounded,
                        size: 18,
                        color: kPurple.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: kInk,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ],
                ),
                if (body.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    body,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: kInk.withValues(alpha: 0.7),
                      height: 1.5,
                    ),
                  ),
                ],
                if (reason != null && reason.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    reason,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: kPurple.withValues(alpha: 0.65),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// EMPTY STATE
// ═════════════════════════════════════════════════════════════════════════════

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: kAmber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                Icons.person_outline_rounded,
                size: 40,
                color: kAmber.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No identities yet',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: kInk,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Define who you want to become.\nYour identities shape your habits and goals.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: kSub.withValues(alpha: 0.7),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            LiquidButton(
              label: '+ Add Identity',
              color: kAmber,
              onTap: () {
                HapticFeedback.lightImpact();
                // Route to identity creation — stubbed for this task
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// SHIMMER LOADING SKELETON
// ═════════════════════════════════════════════════════════════════════════════

class _GoalsShimmer extends StatelessWidget {
  const _GoalsShimmer();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _shimmerBox(160, 14),
          const SizedBox(height: 10),
          _shimmerBox(200, 30),
          const SizedBox(height: 24),
          _shimmerBox(double.infinity, 100),
          const SizedBox(height: 16),
          _shimmerBox(double.infinity, 90),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _shimmerBox(double.infinity, 140)),
              const SizedBox(width: 12),
              Expanded(child: _shimmerBox(double.infinity, 140)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _shimmerBox(double.infinity, 140)),
              const SizedBox(width: 12),
              Expanded(child: _shimmerBox(double.infinity, 140)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _shimmerBox(double width, double height) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: kWhite.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
      ),
    );
  }
}
