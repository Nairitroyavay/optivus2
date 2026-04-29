class ContextSnapshot {
  final int tasksCompletedToday;
  final int goodHabitsLoggedToday;
  final int badHabitSlipsToday;
  final int longestActiveStreak;
  final String userState;

  const ContextSnapshot({
    this.tasksCompletedToday = 0,
    this.goodHabitsLoggedToday = 0,
    this.badHabitSlipsToday = 0,
    this.longestActiveStreak = 0,
    this.userState = 'on_track',
  });

  factory ContextSnapshot.fromMap(Map<String, dynamic> map) {
    return ContextSnapshot(
      tasksCompletedToday: map['tasksCompletedToday'] as int? ?? 0,
      goodHabitsLoggedToday: map['goodHabitsLoggedToday'] as int? ?? 0,
      badHabitSlipsToday: map['badHabitSlipsToday'] as int? ?? 0,
      longestActiveStreak: map['longestActiveStreak'] as int? ?? 0,
      userState: map['userState'] as String? ?? 'on_track',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tasksCompletedToday': tasksCompletedToday,
      'goodHabitsLoggedToday': goodHabitsLoggedToday,
      'badHabitSlipsToday': badHabitSlipsToday,
      'longestActiveStreak': longestActiveStreak,
      'userState': userState,
    };
  }
}
