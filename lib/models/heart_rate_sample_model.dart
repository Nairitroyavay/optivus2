// lib/models/heart_rate_sample_model.dart
//
// Heart rate time-series sample stored at:
//   /users/{uid}/fitnessActivities/{activityId}/heartRateSamples/{sampleId}

import 'package:cloud_firestore/cloud_firestore.dart';

class HeartRateSampleModel {
  final String sampleId;
  final int bpm;
  final DateTime timestamp;
  final String source; // 'watch', 'phone', 'chest_strap', 'unknown'

  const HeartRateSampleModel({
    required this.sampleId,
    required this.bpm,
    required this.timestamp,
    this.source = 'unknown',
  });

  factory HeartRateSampleModel.fromMap(
    Map<String, dynamic> map, {
    String fallbackId = '',
  }) {
    return HeartRateSampleModel(
      sampleId:
          map['sampleId'] as String? ?? map['id'] as String? ?? fallbackId,
      bpm: (map['bpm'] as num?)?.toInt() ?? 0,
      timestamp: _asDateTime(map['timestamp']) ?? DateTime.now(),
      source: map['source'] as String? ?? 'unknown',
    );
  }

  factory HeartRateSampleModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return HeartRateSampleModel.fromMap(data, fallbackId: doc.id);
  }

  Map<String, dynamic> toMap() {
    return {
      'sampleId': sampleId,
      'bpm': bpm,
      'timestamp': Timestamp.fromDate(timestamp),
      'source': source,
    };
  }

  HeartRateSampleModel copyWith({
    String? sampleId,
    int? bpm,
    DateTime? timestamp,
    String? source,
  }) {
    return HeartRateSampleModel(
      sampleId: sampleId ?? this.sampleId,
      bpm: bpm ?? this.bpm,
      timestamp: timestamp ?? this.timestamp,
      source: source ?? this.source,
    );
  }
}

DateTime? _asDateTime(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}
