import 'package:cloud_firestore/cloud_firestore.dart';

class UsageModel {
  final String monthKey;
  final String uid;
  final int aiRequests;
  final int routineImportPreviews;
  final int coachReplies;
  final int suggestionsGenerated;
  final int notificationsScheduled;
  final Map<String, int> counters;
  final Map<String, int> limits;
  final Map<String, dynamic> metadata;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int schemaVersion;
  final Map<String, dynamic> extra;

  const UsageModel({
    required this.monthKey,
    this.uid = '',
    this.aiRequests = 0,
    this.routineImportPreviews = 0,
    this.coachReplies = 0,
    this.suggestionsGenerated = 0,
    this.notificationsScheduled = 0,
    this.counters = const {},
    this.limits = const {},
    this.metadata = const {},
    this.createdAt,
    this.updatedAt,
    this.schemaVersion = 1,
    this.extra = const {},
  });

  factory UsageModel.fromMap(
    Map<String, dynamic> map, {
    String fallbackMonthKey = '',
  }) {
    return UsageModel(
      monthKey: _cleanString(map['monthKey'] ?? map['id'] ?? fallbackMonthKey),
      uid: _cleanString(map['uid']),
      aiRequests: _asInt(map['aiRequests']),
      routineImportPreviews: _asInt(map['routineImportPreviews']),
      coachReplies: _asInt(map['coachReplies']),
      suggestionsGenerated: _asInt(map['suggestionsGenerated']),
      notificationsScheduled: _asInt(map['notificationsScheduled']),
      counters: _intMap(map['counters']),
      limits: _intMap(map['limits']),
      metadata: _stringKeyMap(map['metadata']),
      createdAt: _asDateTime(map['createdAt']),
      updatedAt: _asDateTime(map['updatedAt']),
      schemaVersion: _asInt(map['schemaVersion'], fallback: 1),
      extra: _extra(map, _knownKeys),
    );
  }

  factory UsageModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return UsageModel.fromMap(
      doc.data() ?? const <String, dynamic>{},
      fallbackMonthKey: doc.id,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      ...extra,
      'monthKey': monthKey,
      if (uid.isNotEmpty) 'uid': uid,
      'aiRequests': aiRequests,
      'routineImportPreviews': routineImportPreviews,
      'coachReplies': coachReplies,
      'suggestionsGenerated': suggestionsGenerated,
      'notificationsScheduled': notificationsScheduled,
      'counters': counters,
      'limits': limits,
      'metadata': metadata,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      'schemaVersion': schemaVersion,
    };
  }

  UsageModel copyWith({
    String? monthKey,
    String? uid,
    int? aiRequests,
    int? routineImportPreviews,
    int? coachReplies,
    int? suggestionsGenerated,
    int? notificationsScheduled,
    Map<String, int>? counters,
    Map<String, int>? limits,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? schemaVersion,
    Map<String, dynamic>? extra,
  }) {
    return UsageModel(
      monthKey: monthKey ?? this.monthKey,
      uid: uid ?? this.uid,
      aiRequests: aiRequests ?? this.aiRequests,
      routineImportPreviews:
          routineImportPreviews ?? this.routineImportPreviews,
      coachReplies: coachReplies ?? this.coachReplies,
      suggestionsGenerated: suggestionsGenerated ?? this.suggestionsGenerated,
      notificationsScheduled:
          notificationsScheduled ?? this.notificationsScheduled,
      counters: counters ?? this.counters,
      limits: limits ?? this.limits,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      extra: extra ?? this.extra,
    );
  }
}

const _knownKeys = {
  'monthKey',
  'id',
  'uid',
  'aiRequests',
  'routineImportPreviews',
  'coachReplies',
  'suggestionsGenerated',
  'notificationsScheduled',
  'counters',
  'limits',
  'metadata',
  'createdAt',
  'updatedAt',
  'schemaVersion',
};

String _cleanString(Object? value) => value?.toString().trim() ?? '';

int _asInt(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

Map<String, int> _intMap(Object? value) {
  if (value is! Map) return const {};
  return {
    for (final entry in value.entries)
      entry.key.toString(): _asInt(entry.value),
  };
}

Map<String, dynamic> _stringKeyMap(Object? value) {
  if (value is! Map) return const {};
  return {
    for (final entry in value.entries) entry.key.toString(): entry.value,
  };
}

DateTime? _asDateTime(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

Map<String, dynamic> _extra(Map<String, dynamic> map, Set<String> knownKeys) {
  return {
    for (final entry in map.entries)
      if (!knownKeys.contains(entry.key)) entry.key: entry.value,
  };
}
