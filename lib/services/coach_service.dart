import 'package:optivus2/services/task_service.dart';
import 'package:optivus2/services/streak_service.dart';
import 'package:optivus2/services/habit_service.dart';
import 'package:optivus2/repositories/user_repository.dart';
import 'package:optivus2/services/gemini_service.dart';

class CoachService {
  final TaskService _taskService;
  final StreakService _streakService;
  final HabitService _habitService;
  final UserRepository _userRepo;

  CoachService({
    required TaskService taskService,
    required StreakService streakService,
    required HabitService habitService,
    required UserRepository userRepo,
  })  : _taskService = taskService,
        _streakService = streakService,
        _habitService = habitService,
        _userRepo = userRepo;

  Future<String> generateSystemPrompt(String coachName, String tone) async {
    // 1. Fetch onboarding data for goals and bad habits
    final onboarding = await _userRepo.getOnboardingData();
    final goals = (onboarding?['goals'] as List?)?.join(', ') ?? 'No specific goals set';
    final badHabits = (onboarding?['badHabits'] as List?)?.join(', ') ?? 'None specified';

    // 2. Fetch today's tasks
    final today = DateTime.now();
    final tasks = await _taskService.tasksFor(today).first;
    final tasksList = tasks
        .map((t) => "- ${t.type.name} at ${t.plannedStart.hour}:${t.plannedStart.minute.toString().padLeft(2, '0')}")
        .join('\n');

    // 3. Fetch active streaks
    final activeHabits = await _habitService.habits().first;
    final streaksList = <String>[];
    for (var habit in activeHabits) {
      final streak = await _streakService.getStreak(habit.id);
      if (streak != null && streak.currentCount > 0) {
        streaksList.add("- ${habit.name}: ${streak.currentCount} days");
      }
    }
    final streaksText = streaksList.isNotEmpty ? streaksList.join('\n') : "No active streaks yet.";

    return '''You are the user's personal Optivus AI life coach. Your name is $coachName.
Your tone should be: $tone.
User's main goals: $goals.
Habits trying to break: $badHabits.

Current Context:
Today's Tasks:
${tasksList.isEmpty ? "None scheduled for today." : tasksList}

Active Streaks:
$streaksText

You are embedded in their daily timeline app. Keep responses engaging, supportive, and relatively concise (1-3 paragraphs max) so they fit well in a chat bubble.''';
  }

  Future<GeminiChatSession> startChat(String coachName, String tone, {List<Map<String, dynamic>>? initialHistory}) async {
    final systemPrompt = await generateSystemPrompt(coachName, tone);
    return GeminiService().startChat(systemPrompt, initialHistory: initialHistory);
  }
}
