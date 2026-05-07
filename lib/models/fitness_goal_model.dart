// lib/models/fitness_goal_model.dart
//
// Fitness-specific goal stored at: /users/{uid}/fitnessGoals/{goalId}

import 'package:cloud_firestore/cloud_firestore.dart';

class FitnessGoalModel {
  final String goalId;
  final String goalType; // weekly_distance, weekly_activities, weekly_duration, monthly_distance
  final double targetValue;
  final double currentValue;
  final String unit; // 'km', 'count', 'minutes', etc.
  final DateTime? startDate;
  final DateTime? endDate;
  final String status; // 'active', 'completed', 'expired'
  final DateTime createdAt;
  final DateTime updatedAt;

  const FitnessGoalModel({
    required this.goalId,
    required this.goalType,
    this.targetValue = 0,
    this.currentValue = 0,
    this.unit = 'km',
    this.startDate,
    this.endDate,
    this.status = 'active',
    required this.createdAt,
    required this.updatedAt,
  });

  factory FitnessGoalModel.fromMap(
    Map<String, dynamic> map, {
    String fallbackId = '',
  }) {
    return FitnessGoalModel(
      goalId: map['goalId'] as String? ?? map['id'] as String? ?? fallbackId,
      goalType: map['goalType'] as String? ?? 'weekly_distance',
      targetValue: (map['targetValue'] as num?)?.toDouble() ?? 0,
      currentValue: (map['currentValue'] as num?)?.toDouble() ?? 0,
      unit: map['unit'] as String? ?? 'km',
      startDate: _asDateTime(map['startDate']),
      endDate: _asDateTime(map['endDate']),
      status: _normalizeStatus(map['status'] as String?),
      createdAt: _asDateTime(map['createdAt']) ?? DateTime.now(),
      updatedAt: _asDateTime(map['updatedAt']) ?? DateTime.now(),
    );
  }

  factory FitnessGoalModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return FitnessGoalModel.fromMap(data, fallbackId: doc.id);
  }

  Map<String, dynamic> toMap() {
    return {
      'goalId': goalId,
      'goalType': goalType,
      'targetValue': targetValue,
      'currentValue': currentValue,
      'unit': unit,
      if (startDate != null) 'startDate': Timestamp.fromDate(startDate!),
      if (endDate != null) 'endDate': Timestamp.fromDate(endDate!),
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  FitnessGoalModel copyWith({
    String? goalId,
    String? goalType,
    double? targetValue,
    double? currentValue,
    String? unit,
    DateTime? startDate,
    DateTime? endDate,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FitnessGoalModel(
      goalId: goalId ?? this.goalId,
      goalType: goalType ?? this.goalType,
      targetValue: targetValue ?? this.targetValue,
      currentValue: currentValue ?? this.currentValue,
      unit: unit ?? this.unit,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  double get progressPct =>
      targetValue > 0 ? (currentValue / targetValue).clamp(0.0, 1.0) : 0.0;
}

const _validStatuses = {'active', 'completed', 'expired'};

String _normalizeStatus(String? value) {
  if (value == null || value.trim().isEmpty) return 'active';
  final normalized = value.trim().toLowerCase();
  return _validStatuses.contains(normalized) ? normalized : 'active';
}

DateTime? _asDateTime(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}
