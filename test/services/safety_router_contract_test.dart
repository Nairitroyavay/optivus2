// test/services/safety_router_contract_test.dart
//
// Contract tests for SafetyRouter.
// All groups are skipped (TODO) — SafetyRouter does not yet exist as a
// production class; these tests define the intended routing contract.
//
// Intended public surface (to be implemented):
//   SafetyRouter.classify(text) → SafetyBranch
//   SafetyRouter.route(uid, text, context) → SafetyRouteResult
//
// SafetyBranch values (planned):
//   SafetyBranch.normal     — standard coaching response
//   SafetyBranch.support    — gentle redirection + resource signpost
//   SafetyBranch.crisis     — immediate safety resources, no coaching
//
// Firestore paths:
//   /users/{uid}/coach_messages/{messageId}  (write on crisis/support)
//   /users/{uid}/coach_speak_log/{logId}     (write for budget tracking)
//
// Events:
//   safety_triggered (on support or crisis branch)

import 'package:flutter_test/flutter_test.dart';

void main() {
  // ── classify — branch detection ──────────────────────────────────────────────

  group('SafetyRouter.classify — normal branch', () {
    test(
      'TODO: everyday motivational text returns SafetyBranch.normal',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: habit progress question returns SafetyBranch.normal',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: routine scheduling request returns SafetyBranch.normal',
      () {},
      skip: 'Not yet implemented',
    );
  });

  group('SafetyRouter.classify — support branch', () {
    test(
      'TODO: text expressing persistent low mood returns SafetyBranch.support',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: text expressing burnout or overwhelm returns SafetyBranch.support',
      () {},
      skip: 'Not yet implemented',
    );
  });

  group('SafetyRouter.classify — crisis branch', () {
    test(
      'TODO: text containing explicit self-harm indicators returns SafetyBranch.crisis',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: text containing suicidal ideation returns SafetyBranch.crisis',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: empty or blank text defaults to SafetyBranch.normal',
      () {},
      skip: 'Not yet implemented',
    );
  });

  // ── route — response contract ────────────────────────────────────────────────

  group('SafetyRouter.route — normal branch', () {
    test(
      'TODO: returns SafetyRouteResult with branch=normal and no safetyContent',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: does not write a coach_message doc — caller handles normal replies',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: does not emit safety_triggered event on normal branch',
      () {},
      skip: 'Not yet implemented',
    );
  });

  group('SafetyRouter.route — crisis branch', () {
    test(
      'TODO: returns SafetyRouteResult with branch=crisis and non-empty safetyContent',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: safetyContent contains crisis resource text, not coaching advice',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: writes a coach_message doc with role=coach and safetyBranch=crisis',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: emits safety_triggered event with branch=crisis',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: does not call the normal AI coaching path',
      () {},
      skip: 'Not yet implemented',
    );
  });

  group('SafetyRouter.route — support branch', () {
    test(
      'TODO: returns SafetyRouteResult with branch=support and non-empty safetyContent',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: emits safety_triggered event with branch=support',
      () {},
      skip: 'Not yet implemented',
    );
  });

  // ── AI key safety ────────────────────────────────────────────────────────────

  group('SafetyRouter — AI key safety', () {
    test(
      'TODO: classification does not expose AI API keys in results or logs',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: crisis branch response is a static safe string — not AI-generated',
      () {},
      skip: 'Not yet implemented',
    );
  });

  // ── auth guard ───────────────────────────────────────────────────────────────

  group('SafetyRouter.route — auth guard', () {
    test(
      'TODO: throws NotAuthenticatedError when uid is empty',
      () {},
      skip: 'Not yet implemented',
    );
  });
}
