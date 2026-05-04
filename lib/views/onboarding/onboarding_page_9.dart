import 'dart:async' show unawaited;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus2/core/providers.dart';
import 'package:optivus2/providers/onboarding_provider.dart';
import 'package:optivus2/providers/routine_provider.dart';
import 'package:optivus2/views/routine/widgets/fixed_schedule_editor.dart';
import 'package:optivus2/views/screens/onboarding_screen.dart';

class OnboardingPage9 extends ConsumerStatefulWidget {
  const OnboardingPage9({super.key});

  @override
  ConsumerState<OnboardingPage9> createState() => _OnboardingPage9State();
}

class _OnboardingPage9State extends ConsumerState<OnboardingPage9> {
  List<FixedScheduleTemplate> _templates = const [];
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final saved = ref.read(onboardingProvider).fixedSchedule;
      setState(() {
        _templates =
            saved.map((m) => FixedScheduleTemplate.fromMap(m)).toList();
        _isLoaded = true;
      });
    });
  }

  void _onChanged(List<FixedScheduleTemplate> templates) {
    _templates = templates;

    // 1. Update onboarding draft (debounced Firestore write at /onboarding/state)
    ref.read(onboardingProvider.notifier).updateFixedSchedule(
          templates.map((t) => t.toMap()).toList(),
        );
    ref.read(onboardingProvider.notifier).saveToFirestoreDebounced(9);

    // 2. Mirror to /users/{uid}/routine/current.templates.fixed_schedule
    ref
        .read(routineProvider.notifier)
        .setFixedScheduleTemplates(templates);
    unawaited(
      ref
          .read(routineRepositoryProvider)
          .saveFixedScheduleTemplates(templates),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPadding =
        MediaQuery.of(context).padding.top + kIndicatorOverlayH;
    final bottomPadding =
        MediaQuery.of(context).padding.bottom + kButtonOverlayH;

    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, topPadding + 16, 20, bottomPadding + 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RichText(
            textAlign: TextAlign.center,
            text: const TextSpan(
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F111A),
                height: 1.15,
                letterSpacing: -1.0,
              ),
              children: [
                TextSpan(text: 'Set Your '),
                TextSpan(
                  text: 'Fixed Schedule',
                  style: TextStyle(color: Color(0xFF3B82F6)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Add your daily non-negotiables (work, classes, sleep).',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: FixedScheduleEditor(
              // Re-init the editor once the onboarding draft has been loaded.
              key: ValueKey(_isLoaded),
              initialTemplates: _templates,
              onChanged: _onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
