// lib/models/habit_log_model.dart
//
// Habit log entry per DB Schema §1A.5.
// Stored at: users/{uid}/habit_logs/{logId}
// Append-only — once written, never updated.
// Corrections become new log entries with metadata.correctsLogId.

import 'package:cloud_firestore/cloud_firestore.dart';

class HabitLog {
  final String logId;
  final String habitId;
  final DateTime occurredAt;
  final DateTime loggedAt;
  final num? quantity; // for good habits
  final String? unit;
  final String? trigger; // for bad habits (stress, boredom, etc.)
  final String? note;
  final String? source; // manual | notification | coach | auto
  final int schemaVersion;

  const HabitLog({
    required this.logId,
    required this.habitId,
    required this.occurredAt,
    required this.loggedAt,
    this.quantity,
    this.unit,
    this.trigger,
    this.note,
    this.source = 'manual',
    this.schemaVersion = 1,
  });

  factory HabitLog.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return HabitLog(
      logId: data['logId'] as String? ?? doc.id,
      habitId: data['habitId'] as String,
      occurredAt: (data['occurredAt'] as Timestamp).toDate(),
      loggedAt: (data['loggedAt'] as Timestamp).toDate(),
      quantity: data['quantity'] as num?,
      unit: data['unit'] as String?,
      trigger: data['trigger'] as String?,
      note: data['note'] as String?,
      source: data['source'] as String? ?? 'manual',
      schemaVersion: data['schemaVersion'] as int? ?? 1,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'logId': logId,
      'habitId': habitId,
      'occurredAt': Timestamp.fromDate(occurredAt),
      'loggedAt': Timestamp.fromDate(loggedAt),
      if (quantity != null) 'quantity': quantity,
      if (unit != null) 'unit': unit,
      if (trigger != null) 'trigger': trigger,
      if (note != null) 'note': note,
      'source': source,
      'schemaVersion': schemaVersion,
    };
  }
}
