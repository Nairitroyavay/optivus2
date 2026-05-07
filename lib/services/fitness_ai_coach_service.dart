// lib/services/fitness_ai_coach_service.dart
//
// Post-activity AI feedback service.
// Builds a structured prompt from activity metrics, goals, and history.
// Calls GeminiService (Cloud Function) and stores feedback on the activity doc.
// Data privacy: data is used only for the user's coaching experience.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/fitness_activity_model.dart';
import '../models/fitness_goal_model.dart';
import '../services/firestore_service.dart';
import '../services/gemini_service.dart';

class FitnessAICoachService {
  final FirestoreService _firestoreService;
  final GeminiService _geminiService;
  FitnessAICoachService({
    required FirestoreService firestoreService,
    GeminiService? geminiService,
  })  : _firestoreService = firestoreService,
        _geminiService = geminiService ?? GeminiService();

  /// Generates AI feedback for a completed activity and persists it.
  Future<String> generateAndSaveFeedback(FitnessActivityModel activity) async {
    if (activity.status != FitnessActivityStatus.completed) return '';
    if (activity.aiFeedback.isNotEmpty) return activity.aiFeedback;

    try {
      final prompt = await _buildPrompt(activity);
      final feedback = await _geminiService.generate(
        systemPrompt: _kSystemPrompt,
        userMessage: prompt,
      );

      await _firestoreService
          .userCollection(FirestoreService.kFitnessActivities)
          .doc(activity.activityId)
          .update({'aiFeedback': feedback, 'updatedAt': FieldValue.serverTimestamp()});

      debugPrint('[FitnessAICoach] Feedback saved for ${activity.activityId}');
      return feedback;
    } catch (e) {
      debugPrint('[FitnessAICoach] Failed: $e');
      const fallback = 'Great effort on completing your workout! Keep it up.';
      try {
        await _firestoreService
            .userCollection(FirestoreService.kFitnessActivities)
            .doc(activity.activityId)
            .update({'aiFeedback': fallback, 'updatedAt': FieldValue.serverTimestamp()});
      } catch (_) {}
      return fallback;
    }
  }

  static const _kSystemPrompt = 'You are the user\'s personal fitness coach inside the Optivus app. '
      'Analyze the completed workout data and provide a short, encouraging, '
      'and actionable feedback message (2-4 sentences). '
      'Be specific, reference actual metrics, suggest one concrete improvement. '
      'Keep tone motivating, not judgmental. Return only the final text, no JSON/markdown.';

  Future<String> _buildPrompt(FitnessActivityModel activity) async {
    final buf = StringBuffer()
      ..writeln('=== Completed Activity ===')
      ..writeln('Type: ${activity.activityType.displayName}')
      ..writeln('Duration: ${_fmtDur(activity.activeDuration)}');
    if (activity.distanceMeters > 0) {
      buf.writeln('Distance: ${(activity.distanceMeters / 1000).toStringAsFixed(2)} km');
    }
    if (activity.averagePaceSecondsPerKm != null && activity.averagePaceSecondsPerKm! > 0) {
      final p = activity.averagePaceSecondsPerKm!;
      buf.writeln("Avg Pace: ${p ~/ 60}'${(p % 60).round().toString().padLeft(2, '0')}\" /km");
    }
    if (activity.calories != null) buf.writeln('Calories: ${activity.calories}');
    if (activity.averageHeartRate != null) buf.writeln('Avg HR: ${activity.averageHeartRate} bpm');

    final goals = await _fetchActiveGoals();
    if (goals.isNotEmpty) {
      buf.writeln('\n=== Active Goals ===');
      for (final g in goals) {
        buf.writeln('- ${g.goalType}: ${g.currentValue}/${g.targetValue} ${g.unit}');
      }
    }
    return buf.toString();
  }

  Future<List<FitnessGoalModel>> _fetchActiveGoals() async {
    try {
      final snap = await _firestoreService
          .userCollection(FirestoreService.kFitnessGoals)
          .where('status', isEqualTo: 'active').limit(10).get();
      return snap.docs.map((d) => FitnessGoalModel.fromMap(d.data(), fallbackId: d.id)).toList();
    } catch (_) { return const []; }
  }

  static String _fmtDur(Duration d) {
    final h = d.inHours; final m = d.inMinutes % 60; final s = d.inSeconds % 60;
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }
}
