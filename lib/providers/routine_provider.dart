import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MODELS
// ─────────────────────────────────────────────────────────────────────────────

/// A fixed block on the 24-hour schedule (from onboarding "Set Your Fixed Schedule")
class FixedBlock {
  final String id;
  final String title;
  final String emoji;
  final int    startMinute; // minutes from midnight, 0–1439
  final int    endMinute;
  final String colorHex;

  const FixedBlock({
    required this.id,
    required this.title,
    required this.emoji,
    required this.startMinute,
    required this.endMinute,
    required this.colorHex,
  });

  String get startLabel => _fmt(startMinute);
  String get endLabel   => _fmt(endMinute);

  static String _fmt(int m) {
    final h    = m ~/ 60;
    final min  = m % 60;
    final ampm = h < 12 ? 'AM' : 'PM';
    final h12  = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '${h12.toString().padLeft(2,'0')}:${min.toString().padLeft(2,'0')} $ampm';
  }

  FixedBlock copyWith({int? startMinute, int? endMinute}) => FixedBlock(
    id: id, title: title, emoji: emoji,
    startMinute: startMinute ?? this.startMinute,
    endMinute:   endMinute   ?? this.endMinute,
    colorHex: colorHex,
  );
}

/// One skin-care step
class SkinStep {
  final String emoji;
  final String name;
  final String tag;
  const SkinStep({required this.emoji, required this.name, required this.tag});
}

/// Skin care plan for one day: three time slots
class DaySkinPlan {
  final List<SkinStep> morning;
  final List<SkinStep> afternoon;
  final List<SkinStep> night;
  const DaySkinPlan({
    this.morning   = const [],
    this.afternoon = const [],
    this.night     = const [],
  });

  bool get isEmpty =>
      morning.isEmpty && afternoon.isEmpty && night.isEmpty;

  DaySkinPlan copyWith({
    List<SkinStep>? morning,
    List<SkinStep>? afternoon,
    List<SkinStep>? night,
  }) => DaySkinPlan(
    morning:   morning   ?? this.morning,
    afternoon: afternoon ?? this.afternoon,
    night:     night     ?? this.night,
  );
}

/// One meal slot
class MealItem {
  final String emoji;
  final String name;
  final String time; // "08:00 AM"
  const MealItem({required this.emoji, required this.name, required this.time});
}

/// Eating plan for one day: four meal slots
class DayMealPlan {
  final MealItem? breakfast;
  final MealItem? lunch;
  final MealItem? snack;
  final MealItem? dinner;
  const DayMealPlan({this.breakfast, this.lunch, this.snack, this.dinner});

  bool get isEmpty =>
      breakfast == null && lunch == null &&
      snack == null && dinner == null;

  List<MealItem> get all => [
    if (breakfast != null) breakfast!,
    if (lunch     != null) lunch!,
    if (snack     != null) snack!,
    if (dinner    != null) dinner!,
  ];

  DayMealPlan copyWith({
    MealItem? breakfast, MealItem? lunch,
    MealItem? snack,     MealItem? dinner,
  }) => DayMealPlan(
    breakfast: breakfast ?? this.breakfast,
    lunch:     lunch     ?? this.lunch,
    snack:     snack     ?? this.snack,
    dinner:    dinner    ?? this.dinner,
  );
}

/// One class in the weekly timetable
class ClassItem {
  final String subject;
  final String room;
  final String professor;
  final String startTime;   // "09:00"
  final String endTime;     // "10:00"
  final int    weekday;     // 1=Mon … 7=Sun
  final String colorHex;
  const ClassItem({
    required this.subject, required this.room,
    required this.professor, required this.startTime,
    required this.endTime, required this.weekday,
    required this.colorHex,
  });
}

class CustomTask {
  final String id;
  final String title;
  final String emoji;
  final String time;   // "HH:MM"
  final DateTime date;
  final Color color;

  const CustomTask({
    required this.id,
    required this.title,
    required this.emoji,
    required this.time,
    required this.date,
    required this.color,
  });
}

/// Long-term commitments set by the User or AI
class LongTermGoal {
  final String id;
  final String title;
  final String emoji;
  final DateTime startDate;
  final DateTime endDate;
  final String? dailyTaskTime; // "HH:MM"
  final String colorHex;

  const LongTermGoal({
    required this.id,
    required this.title,
    required this.emoji,
    required this.startDate,
    required this.endDate,
    this.dailyTaskTime,
    required this.colorHex,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// STATE CLASSES
// ─────────────────────────────────────────────────────────────────────────────

class RoutineState {
  // Fixed 24h schedule blocks (from onboarding)
  final List<FixedBlock> fixedBlocks;
  final bool fixedScheduleSetUp;

  // Skin care: 7 days (0=Mon … 6=Sun)
  final List<DaySkinPlan> skinCarePlans;
  final bool skinCareSetUp;

  // Eating: 7 days
  final List<DayMealPlan> mealPlans;
  final bool eatingSetUp;

  // Classes
  final List<ClassItem> classes;
  final bool classesSetUp;

  // Long-Term Goals
  final List<LongTermGoal> longTermGoals;

  const RoutineState({
    this.fixedBlocks       = const [],
    this.fixedScheduleSetUp = false,
    List<DaySkinPlan>? skinCarePlans,
    this.skinCareSetUp     = false,
    List<DayMealPlan>? mealPlans,
    this.eatingSetUp       = false,
    this.classes           = const [],
    this.classesSetUp      = false,
    this.longTermGoals     = const [],
  })  : skinCarePlans = skinCarePlans ??
            const [
              DaySkinPlan(), DaySkinPlan(), DaySkinPlan(), DaySkinPlan(),
              DaySkinPlan(), DaySkinPlan(), DaySkinPlan(),
            ],
        mealPlans = mealPlans ??
            const [
              DayMealPlan(), DayMealPlan(), DayMealPlan(), DayMealPlan(),
              DayMealPlan(), DayMealPlan(), DayMealPlan(),
            ];

  RoutineState copyWith({
    List<FixedBlock>?    fixedBlocks,
    bool?                fixedScheduleSetUp,
    List<DaySkinPlan>?   skinCarePlans,
    bool?                skinCareSetUp,
    List<DayMealPlan>?   mealPlans,
    bool?                eatingSetUp,
    List<ClassItem>?     classes,
    bool?                classesSetUp,
    List<LongTermGoal>?  longTermGoals,
  }) => RoutineState(
    fixedBlocks:        fixedBlocks        ?? this.fixedBlocks,
    fixedScheduleSetUp: fixedScheduleSetUp ?? this.fixedScheduleSetUp,
    skinCarePlans:      skinCarePlans      ?? this.skinCarePlans,
    skinCareSetUp:      skinCareSetUp      ?? this.skinCareSetUp,
    mealPlans:          mealPlans          ?? this.mealPlans,
    eatingSetUp:        eatingSetUp        ?? this.eatingSetUp,
    classes:            classes            ?? this.classes,
    classesSetUp:       classesSetUp       ?? this.classesSetUp,
    longTermGoals:      longTermGoals      ?? this.longTermGoals,
  );

  // ── Convenience getters ──────────────────────────────────────────────────

  /// 0=Mon … 6=Sun
  DaySkinPlan skinPlanForDay(int weekdayIndex) =>
      skinCarePlans[weekdayIndex.clamp(0, 6)];

  DayMealPlan mealPlanForDay(int weekdayIndex) =>
      mealPlans[weekdayIndex.clamp(0, 6)];

  /// Classes for a given weekday (1=Mon … 7=Sun, same as DateTime.weekday)
  List<ClassItem> classesForDay(int weekday) =>
      classes.where((c) => c.weekday == weekday).toList()
        ..sort((a, b) => a.startTime.compareTo(b.startTime));
}

// ─────────────────────────────────────────────────────────────────────────────
// NOTIFIER
// ─────────────────────────────────────────────────────────────────────────────

class RoutineNotifier extends StateNotifier<RoutineState> {
  RoutineNotifier() : super(const RoutineState()) {
    Future.microtask(() {
      setFixedBlocks(kDefaultFixedBlocks);
      // Seed default long-term goals for demonstration
      final now = DateTime.now();
      setLongTermGoals([
        LongTermGoal(
          id: 'goal_quit_smoking',
          title: 'Quit smoking and alcohol',
          emoji: '🚭',
          startDate: now,
          endDate: now.add(const Duration(days: 14)), // 2 weeks
          colorHex: '#CBD5E1', // grey
        ),
        LongTermGoal(
          id: 'goal_gym',
          title: 'Gym Workout',
          emoji: '💪',
          startDate: now,
          endDate: now.add(const Duration(days: 90)), // 3 months
          dailyTaskTime: '10:00',
          colorHex: '#38BDF8', // light blue
        ),
      ]);
    });
  }

  // ── Fixed schedule ───────────────────────────────────────────────────────

  void setFixedBlocks(List<FixedBlock> blocks) {
    state = state.copyWith(
      fixedBlocks: blocks,
      fixedScheduleSetUp: true,
    );
  }

  void updateFixedBlock(FixedBlock updated) {
    final list = state.fixedBlocks.map((b) =>
        b.id == updated.id ? updated : b).toList();
    state = state.copyWith(fixedBlocks: list);
  }

  // ── Skin care ────────────────────────────────────────────────────────────

  void setSkinCarePlan(int dayIndex, DaySkinPlan plan) {
    final plans = List<DaySkinPlan>.from(state.skinCarePlans);
    plans[dayIndex] = plan;
    state = state.copyWith(skinCarePlans: plans, skinCareSetUp: true);
  }

  void markSkinCareSetUp() =>
      state = state.copyWith(skinCareSetUp: true);

  // ── Eating ───────────────────────────────────────────────────────────────

  void setMealPlan(int dayIndex, DayMealPlan plan) {
    final plans = List<DayMealPlan>.from(state.mealPlans);
    plans[dayIndex] = plan;
    state = state.copyWith(mealPlans: plans, eatingSetUp: true);
  }

  void markEatingSetUp() =>
      state = state.copyWith(eatingSetUp: true);

  // ── Classes ──────────────────────────────────────────────────────────────

  void setClasses(List<ClassItem> classes) {
    state = state.copyWith(classes: classes, classesSetUp: true);
  }

  void addClass(ClassItem c) {
    state = state.copyWith(
      classes: [...state.classes, c],
      classesSetUp: true,
    );
  }

  void removeClass(ClassItem c) {
    state = state.copyWith(
      classes: state.classes.where((x) =>
          x.subject != c.subject || x.weekday != c.weekday).toList(),
    );
  }

  // ── Long-Term Goals ────────────────────────────────────────────────────────
  
  void setLongTermGoals(List<LongTermGoal> goals) {
    state = state.copyWith(longTermGoals: goals);
  }

  void addLongTermGoal(LongTermGoal goal) {
    state = state.copyWith(longTermGoals: [...state.longTermGoals, goal]);
  }

  void removeLongTermGoal(String id) {
    state = state.copyWith(
      longTermGoals: state.longTermGoals.where((g) => g.id != id).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PROVIDERS
// ─────────────────────────────────────────────────────────────────────────────

final routineProvider =
    StateNotifierProvider<RoutineNotifier, RoutineState>(
  (_) => RoutineNotifier(),
);

final customTasksProvider =
    StateProvider<Map<String, List<CustomTask>>>((ref) => {});

final isPremiumProvider =
    StateProvider<bool>((ref) => false);

// ─────────────────────────────────────────────────────────────────────────────
// DEFAULT SEED DATA  (used when app is demoed without going through onboarding)
// ─────────────────────────────────────────────────────────────────────────────

const kDefaultFixedBlocks = <FixedBlock>[
  FixedBlock(id:'sleep',   title:'Sleep',   emoji:'🛏️',
      startMinute:  0, endMinute: 390, colorHex:'#C084FC'), // 12AM–6:30AM
  FixedBlock(id:'classes', title:'Classes', emoji:'🎓',
      startMinute:540, endMinute: 720, colorHex:'#378ADD'), // 9AM–12PM
  FixedBlock(id:'eating',  title:'Eating',  emoji:'🍽️',
      startMinute:780, endMinute:1020, colorHex:'#FF9560'), // 1PM–5PM
];

const kDefaultSkinPlan = DaySkinPlan(
  morning: [
    SkinStep(emoji:'🟡', name:'Vitamin C Serum', tag:'Brightening'),
    SkinStep(emoji:'☀️', name:'SPF 50 Sunscreen', tag:'UV Protection'),
  ],
  afternoon: [
    SkinStep(emoji:'🫧', name:'Face Wash', tag:'Gentle Cleanser'),
  ],
  night: [
    SkinStep(emoji:'🌙', name:'Repair Night Cream', tag:'Deep Moisturizing'),
  ],
);

const kDefaultMealPlanMon = DayMealPlan(
  breakfast: MealItem(emoji:'🥣', name:'Oatmeal & Berries',        time:'08:00 AM'),
  lunch:     MealItem(emoji:'🥗', name:'Grilled Chicken Salad',    time:'01:00 PM'),
  snack:     MealItem(emoji:'🍎', name:'Green Apple & Walnuts',    time:'05:00 PM'),
  dinner:    MealItem(emoji:'🍣', name:'Salmon with Asparagus',    time:'08:30 PM'),
);

const kDefaultClasses = <ClassItem>[
  ClassItem(subject:'Data Structures', room:'Room 304',
      professor:'Prof. Sarah Jenkins',
      startTime:'09:00', endTime:'10:00', weekday:3,
      colorHex:'#378ADD'),
  ClassItem(subject:'Operating Systems', room:'Lab A',
      professor:'Dr. Alan Turing',
      startTime:'11:00', endTime:'12:00', weekday:3,
      colorHex:'#FF9560'),
  ClassItem(subject:'Chemistry Lab', room:'Building C',
      professor:'Ms. Curie',
      startTime:'14:00', endTime:'15:00', weekday:3,
      colorHex:'#9B8FFF'),
];
