// test/services/rule_engine_service_contract_test.dart
//
// Contract tests for RuleEngineService.
// All groups are skipped (TODO) — the server-side rule evaluation job and full
// speak-budget enforcement are not yet implemented.
//
// Intended public surface (lib/services/rule_engine_service.dart exists at 25 KB):
//   RuleEngineService.evaluate(contextSnapshot) → List<RuleDecision>
//   RuleEngineService.evaluateForUid(uid) → List<RuleDecision>
//   RuleEngineService.canSpeak(uid, {channel}) → bool
//   RuleEngineService.recordDecision(uid, decision) → void
//
// Key rule: crisis_intervention_slips (priority 1) fires when slipsToday >= 3.
//
// Firestore paths:
//   /users/{uid}/events_recent   (read)
//   /users/{uid}/coach_speak_log (read/write)
//   /users/{uid}/suggestions/{suggestionId} (write)

import 'package:flutter_test/flutter_test.dart';

import 'package:optivus2/core/constants/event_names.dart';
import 'package:optivus2/models/context_snapshot.dart';
import 'package:optivus2/models/event_model.dart';
import 'package:optivus2/services/rule_engine_service.dart';

EventModel _event(
  String eventName, {
  Map<String, dynamic> payload = const {},
}) {
  return EventModel(
    eventId: 'event_1',
    eventName: eventName,
    uid: 'test_uid_123',
    timestamp: DateTime.utc(2026, 5, 9),
    source: 'test',
    payload: payload,
    deviceId: 'test_device',
  );
}

void main() {
  group('RuleEngineService — event contract', () {
    test('all rule input events are canonical EventNames values', () {
      for (final rule in RuleEngineService.rules) {
        expect(
          rule.event == '*' || EventNames.all.contains(rule.event),
          isTrue,
          reason: '${rule.id} references non-canonical event ${rule.event}',
        );
      }
    });

    test('missed gym rule uses the canonical routine window missed event', () {
      expect(
        RuleEngineService.ruleMissedGymOneOff.event,
        EventNames.routineWindowMissed,
      );
    });
  });

  group('RuleEngineService.evaluate — focused contract', () {
    test('fires smoking pattern rule from current habit slip payload fields',
        () {
      final rule = RuleEngineService().evaluate(
        const ContextSnapshot(),
        _event(
          EventNames.badHabitSlipLogged,
          payload: {
            'habitName': 'Smoking',
            'countTodayAfter': 4,
          },
        ),
      );

      expect(rule, isNotNull);
      expect(rule!.id, 'rule_smoking_pattern_4_cigs');
      expect(rule.event, EventNames.badHabitSlipLogged);
    });

    test('fires critical slips rule for canonical bad habit slip event', () {
      final rule = RuleEngineService().evaluate(
        const ContextSnapshot(
          badHabitSlipsToday: 3,
          userState: 'slipping',
        ),
        _event(EventNames.badHabitSlipLogged),
      );

      expect(rule, isNotNull);
      expect(rule!.id, 'rule_multiple_slips_critical');
      expect(rule.aiIntent, 'crisis_intervention_slips');
      expect(rule.priority, 1);
    });

    test('fires screen time crossing rule from event metadata payload', () {
      final rule = RuleEngineService().evaluate(
        const ContextSnapshot(),
        _event(
          EventNames.badHabitSlipLogged,
          payload: {'crossingCount': 2},
        ),
      );

      expect(rule, isNotNull);
      expect(rule!.id, 'rule_screen_time_second_crossing');
      expect(rule.event, EventNames.badHabitSlipLogged);
    });
  });

  // ── evaluate — output shape ──────────────────────────────────────────────────

  group('RuleEngineService.evaluate — output shape', () {
    test(
      'TODO: returns a List<RuleDecision> — never null',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: each RuleDecision has a non-empty ruleId, fired (bool), and priority (int)',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: unfired decisions include a non-empty silenceReason string',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: fired decisions include a non-null aiIntent string',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: decisions are returned ordered by priority ascending (lower = higher urgency)',
      () {},
      skip: 'Not yet implemented',
    );
  });

  // ── crisis intervention rule ─────────────────────────────────────────────────

  group('RuleEngineService — crisis_intervention_slips rule', () {
    test(
      'TODO: rule fires when context.slipsToday >= 3',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: fired decision has aiIntent == crisis_intervention_slips',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: fired decision has priority == 1',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: rule does not fire when context.slipsToday < 3',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: silenceReason is non-empty when rule does not fire',
      () {},
      skip: 'Not yet implemented',
    );
  });

  // ── speak budget ─────────────────────────────────────────────────────────────

  group('RuleEngineService.canSpeak', () {
    test(
      'TODO: returns true when speak log count for today is below the per-channel cap',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: returns false when speak log count meets or exceeds the cap',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: channel param scopes the budget check (coach vs notification vs suggestion)',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: cap value is read from Remote Config, not hard-coded',
      () {},
      skip: 'Not yet implemented',
    );
  });

  // ── recordDecision ───────────────────────────────────────────────────────────

  group('RuleEngineService.recordDecision', () {
    test(
      'TODO: writes a speak log entry to /users/{uid}/coach_speak_log when decision is fired',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: does not write a speak log entry when decision is not fired',
      () {},
      skip: 'Not yet implemented',
    );
  });

  // ── evaluateForUid ───────────────────────────────────────────────────────────

  group('RuleEngineService.evaluateForUid — data loading', () {
    test(
      'TODO: reads events_recent to build context before evaluating',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: throws NotAuthenticatedError when uid is empty',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: returns empty list without throwing when events_recent is empty',
      () {},
      skip: 'Not yet implemented',
    );
  });

  // ── AI key safety ────────────────────────────────────────────────────────────

  group('RuleEngineService — AI key safety', () {
    test(
      'TODO: rule evaluation does not call AI directly — AI is invoked only via Cloud Function',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: no AI API key is embedded in rule definitions or decision payloads',
      () {},
      skip: 'Not yet implemented',
    );
  });
}
