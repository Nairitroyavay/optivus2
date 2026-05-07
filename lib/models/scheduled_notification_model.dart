// lib/models/scheduled_notification_model.dart
//
// Persisted at: /users/{uid}/scheduled_notifications/{notifId}
//
// Each document represents a single scheduled local notification intent.
// The orchestrator creates these; future cleanup jobs can mark them
// 'delivered' or 'cancelled' based on observed outcomes.
//
// schemaVersion: 1

import 'package:cloud_firestore/cloud_firestore.dart';

/// V1 notification categories.
abstract final class NotifCategory {
  static const taskReminder = 'task_reminder';
  static const taskEndReminder = 'task_end_reminder';
  static const streakMilestone = 'streak_milestone';
  static const slipRecovery = 'slip_recovery';
}

/// Lifecycle status of the scheduled notification.
abstract final class NotifStatus {
  static const pending = 'pending';
  static const cancelled = 'cancelled';
  static const delivered = 'delivered';
  static const sent = 'sent';
  static const tapped = 'tapped';
  static const dismissed = 'dismissed';
  static const suppressed = 'suppressed';
  static const missed = 'missed';
}

class ScheduledNotification {
  /// Deterministic ID: sha256(category + entityKey + scheduledFor.toUtc().toIso8601String())
  final String notifId;

  /// One of [NotifCategory] constants.
  final String category;

  /// Wall-clock UTC time the local notification fires.
  final DateTime scheduledFor;

  /// Set for task-category notifications.
  final String? taskId;

  /// Set for habit/streak-category notifications.
  final String? habitId;

  /// Routine/template id used with date/time/category for lifecycle dedupe.
  final String? routineTemplateId;

  /// YYYY-MM-DD local date string for deduplication.
  final String? scheduledDate;

  /// HH:mm local time string for deduplication.
  final String? scheduledTime;

  /// P1 to P6 priority.
  final String? priority;

  /// Human-readable scheduling intent used in lifecycle event payloads.
  final String? intentDescription;

  /// Upstream event that caused this notification to be scheduled.
  final String? triggerEventId;

  final String? title;
  final String? body;

  /// One of [NotifStatus] constants. Defaults to 'pending'.
  final String status;

  /// Server-side creation timestamp.
  final DateTime createdAt;

  final int schemaVersion;

  const ScheduledNotification({
    required this.notifId,
    required this.category,
    required this.scheduledFor,
    this.taskId,
    this.habitId,
    this.routineTemplateId,
    this.scheduledDate,
    this.scheduledTime,
    this.priority,
    this.intentDescription,
    this.triggerEventId,
    this.title,
    this.body,
    this.status = NotifStatus.pending,
    required this.createdAt,
    this.schemaVersion = 1,
  });

  factory ScheduledNotification.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data() ?? <String, dynamic>{};
    return ScheduledNotification(
      notifId: d['notifId'] as String? ?? doc.id,
      category: d['category'] as String? ?? '',
      scheduledFor: _asDateTime(d['scheduledFor']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      taskId: d['taskId'] as String?,
      habitId: d['habitId'] as String?,
      routineTemplateId: d['routineTemplateId'] as String?,
      scheduledDate: d['scheduledDate'] as String?,
      scheduledTime: d['scheduledTime'] as String?,
      priority: d['priority'] as String?,
      intentDescription: d['intentDescription'] as String?,
      triggerEventId: d['triggerEventId'] as String?,
      title: d['title'] as String?,
      body: d['body'] as String?,
      status: d['status'] as String? ?? NotifStatus.pending,
      createdAt:
          _asDateTime(d['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      schemaVersion: d['schemaVersion'] as int? ?? 1,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'notifId': notifId,
        'category': category,
        'scheduledFor': Timestamp.fromDate(scheduledFor.toUtc()),
        if (taskId != null) 'taskId': taskId,
        if (habitId != null) 'habitId': habitId,
        if (routineTemplateId != null) 'routineTemplateId': routineTemplateId,
        if (scheduledDate != null) 'scheduledDate': scheduledDate,
        if (scheduledTime != null) 'scheduledTime': scheduledTime,
        if (priority != null) 'priority': priority,
        if (intentDescription != null) 'intentDescription': intentDescription,
        if (triggerEventId != null) 'triggerEventId': triggerEventId,
        if (title != null) 'title': title,
        if (body != null) 'body': body,
        'status': status,
        'createdAt': FieldValue.serverTimestamp(),
        'schemaVersion': schemaVersion,
      };

  static DateTime? _asDateTime(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
