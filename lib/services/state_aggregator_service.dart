import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/event_names.dart';
import '../models/context_snapshot.dart';
import '../models/streak_model.dart';

class StateAggregatorService {
  final FirebaseFirestore _firestore;

  StateAggregatorService({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<ContextSnapshot> buildSnapshot(String uid) async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final tomorrowStart = todayStart.add(const Duration(days: 1));

    final eventsRecentRef =
        _firestore.collection('users').doc(uid).collection('events_recent');
    final streaksRef = _firestore.collection('users').doc(uid).collection('streaks');

    final eventsSnap = await eventsRecentRef
        .where('ts', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
        .where('ts', isLessThan: Timestamp.fromDate(tomorrowStart))
        .get();

    int tasksCompletedToday = 0;
    int goodHabitsLoggedToday = 0;
    int badHabitSlipsToday = 0;

    for (final doc in eventsSnap.docs) {
      final eventName = doc.data()['eventName'] as String? ?? '';
      switch (eventName) {
        case EventNames.taskCompleted:
          tasksCompletedToday++;
          break;
        case EventNames.goodHabitLogged:
          goodHabitsLoggedToday++;
          break;
        case EventNames.badHabitSlipLogged:
          badHabitSlipsToday++;
          break;
      }
    }

    final streaksSnap =
        await streaksRef.where('state', isEqualTo: StreakState.active.name).get();

    var longestActiveStreak = 0;
    for (final doc in streaksSnap.docs) {
      final streak = Streak.fromFirestore(doc);
      if (streak.currentCount > longestActiveStreak) {
        longestActiveStreak = streak.currentCount;
      }
    }

    return ContextSnapshot(
      tasksCompletedToday: tasksCompletedToday,
      goodHabitsLoggedToday: goodHabitsLoggedToday,
      badHabitSlipsToday: badHabitSlipsToday,
      longestActiveStreak: longestActiveStreak,
      userState: _deriveUserState(
        tasksCompletedToday: tasksCompletedToday,
        goodHabitsLoggedToday: goodHabitsLoggedToday,
        badHabitSlipsToday: badHabitSlipsToday,
        longestActiveStreak: longestActiveStreak,
      ),
    );
  }

  String _deriveUserState({
    required int tasksCompletedToday,
    required int goodHabitsLoggedToday,
    required int badHabitSlipsToday,
    required int longestActiveStreak,
  }) {
    final positiveSignals =
        tasksCompletedToday + goodHabitsLoggedToday + (longestActiveStreak > 0 ? 1 : 0);

    if (badHabitSlipsToday >= 3 && positiveSignals == 0) {
      return 'relapsing';
    }

    if (badHabitSlipsToday > 0 && positiveSignals > 0) {
      return 'recovering';
    }

    if (badHabitSlipsToday > 0) {
      return 'slipping';
    }

    return 'on_track';
  }
}
