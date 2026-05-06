// lib/models/habit_log_model.dart
//
// Habit log entry per DB Schema §1A.5.
// Canonical path : users/{uid}/habit_logs/{logId}
// Legacy compat  : users/{uid}/habits/{habitId}/logs/{date}/items/{logId}
// Append-only — once written, never updated.
// Corrections become new log entries with metadata.correctsLogId.

import 'package:cloud_firestore/cloud_firestore.dart';

class HabitLog {
  final String logId;
  final String habitId;
  final String habitKind; // 'good' | 'bad'
  final String logType; // 'good' | 'slip'
  final DateTime occurredAt;
  final DateTime loggedAt;
  final num? quantity; // for good habits
  final String? unit;
  final String? trigger; // for bad habits (stress, boredom, etc.)
  final String? note;
  final String? relatedTaskId; // for procrastination
  final String? avoidedWith; // for procrastination (what they did instead)
  final DateTime? dismissedAt; // for auto-logs
  final String? source; // manual | notification | coach | auto
  final int? durationSec; // for meditation/session habits
  final String? type; // for meditation type
  final int? moodBefore; // for meditation lift
  final int? moodAfter; // for meditation lift
  final int schemaVersion;

  const HabitLog({
    required this.logId,
    required this.habitId,
    required this.habitKind,
    required this.logType,
    required this.occurredAt,
    required this.loggedAt,
    this.quantity,
    this.unit,
    this.trigger,
    this.note,
    this.relatedTaskId,
    this.avoidedWith,
    this.dismissedAt,
    this.source = 'manual',
    this.durationSec,
    this.type,
    this.moodBefore,
    this.moodAfter,
    this.schemaVersion = 1,
  });

  bool get isDismissed => dismissedAt != null;

  factory HabitLog.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return HabitLog(
      logId: data['logId'] as String? ?? doc.id,
      habitId: data['habitId'] as String? ?? '',
      habitKind: data['habitKind'] as String? ?? 'good',
      logType: data['logType'] as String? ?? 'good',
      occurredAt:
          _asDateTime(data['occurredAt'] ?? data['ts']) ?? DateTime.now(),
      loggedAt: _asDateTime(data['loggedAt']) ?? DateTime.now(),
      quantity: data['quantity'] as num? ?? data['amount'] as num?,
      unit: data['unit'] as String?,
      trigger: data['trigger'] as String? ??
          data['triggerTag'] as String? ??
          data['trigger_tag'] as String?,
      note: data['note'] as String?,
      relatedTaskId: data['relatedTaskId'] as String?,
      avoidedWith: data['avoidedWith'] as String?,
      dismissedAt: _asDateTime(data['dismissedAt']),
      source: data['source'] as String? ?? 'manual',
      durationSec: data['durationSec'] as int?,
      type: data['type'] as String?,
      moodBefore: data['moodBefore'] as int?,
      moodAfter: data['moodAfter'] as int?,
      schemaVersion: data['schemaVersion'] as int? ?? 1,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'logId': logId,
      'habitId': habitId,
      'habitKind': habitKind,
      'logType': logType,
      'occurredAt': Timestamp.fromDate(occurredAt),
      'loggedAt': Timestamp.fromDate(loggedAt),
      if (quantity != null) 'quantity': quantity,
      if (unit != null) 'unit': unit,
      if (trigger != null) 'trigger': trigger,
      if (trigger != null) 'triggerTag': trigger,
      if (trigger != null) 'trigger_tag': trigger,
      if (note != null) 'note': note,
      if (relatedTaskId != null) 'relatedTaskId': relatedTaskId,
      if (avoidedWith != null) 'avoidedWith': avoidedWith,
      if (dismissedAt != null) 'dismissedAt': Timestamp.fromDate(dismissedAt!),
      'source': source,
      if (durationSec != null) 'durationSec': durationSec,
      if (type != null) 'type': type,
      if (moodBefore != null) 'moodBefore': moodBefore,
      if (moodAfter != null) 'moodAfter': moodAfter,
      'schemaVersion': schemaVersion,
    };
  }

  static DateTime? _asDateTime(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
