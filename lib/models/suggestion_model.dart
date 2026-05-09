import 'package:cloud_firestore/cloud_firestore.dart';

class SuggestionModel {
  static const validStatuses = {
    'pending',
    'generated',
    'accepted',
    'dismissed',
  };

  final String suggestionId;
  final String title;
  final String body;
  final String reason;
  final String emoji;
  final String action;
  final String status;
  final String source;
  final String targetSurface;
  final String category;
  final String routineType;
  final int gapDays;
  final List<String> suggestionIds;
  final Map<String, dynamic> metadata;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? acceptedAt;
  final DateTime? dismissedAt;
  final int schemaVersion;
  final Map<String, dynamic> extra;

  const SuggestionModel({
    required this.suggestionId,
    this.title = '',
    this.body = '',
    this.reason = '',
    this.emoji = '',
    this.action = '',
    this.status = 'pending',
    this.source = '',
    this.targetSurface = '',
    this.category = '',
    this.routineType = '',
    this.gapDays = 0,
    this.suggestionIds = const [],
    this.metadata = const {},
    this.createdAt,
    this.updatedAt,
    this.acceptedAt,
    this.dismissedAt,
    this.schemaVersion = 1,
    this.extra = const {},
  });

  factory SuggestionModel.fromMap(
    Map<String, dynamic> map, {
    String fallbackId = '',
  }) {
    final suggestionId = _cleanString(
      map['suggestionId'] ?? map['suggestion_id'] ?? map['id'] ?? fallbackId,
    );
    return SuggestionModel(
      suggestionId: suggestionId,
      title: _cleanString(map['title']),
      body: _cleanString(map['body'] ?? map['message'] ?? map['description']),
      reason: _cleanString(map['reason']),
      emoji: _cleanString(map['emoji']),
      action: _cleanString(map['action']),
      status: _normalizeStatus(map['status']),
      source: _cleanString(map['source']),
      targetSurface: _cleanString(map['targetSurface'] ?? map['surface']),
      category: _cleanString(map['category']),
      routineType: _cleanString(map['routineType']),
      gapDays: _asInt(map['gapDays']),
      suggestionIds: _stringList(map['suggestionIds']),
      metadata: _stringKeyMap(map['metadata']),
      createdAt: _asDateTime(map['createdAt']),
      updatedAt: _asDateTime(map['updatedAt']),
      acceptedAt: _asDateTime(map['acceptedAt']),
      dismissedAt: _asDateTime(map['dismissedAt']),
      schemaVersion: _asInt(map['schemaVersion'], fallback: 1),
      extra: _extra(map, _knownKeys),
    );
  }

  factory SuggestionModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return SuggestionModel.fromMap(
      doc.data() ?? const <String, dynamic>{},
      fallbackId: doc.id,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      ...extra,
      'suggestionId': suggestionId,
      'title': title,
      if (body.isNotEmpty) 'body': body,
      if (reason.isNotEmpty) 'reason': reason,
      if (emoji.isNotEmpty) 'emoji': emoji,
      if (action.isNotEmpty) 'action': action,
      'status': status,
      if (source.isNotEmpty) 'source': source,
      if (targetSurface.isNotEmpty) 'targetSurface': targetSurface,
      if (category.isNotEmpty) 'category': category,
      if (routineType.isNotEmpty) 'routineType': routineType,
      if (gapDays > 0) 'gapDays': gapDays,
      'suggestionIds': suggestionIds,
      'metadata': metadata,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      if (acceptedAt != null) 'acceptedAt': Timestamp.fromDate(acceptedAt!),
      if (dismissedAt != null) 'dismissedAt': Timestamp.fromDate(dismissedAt!),
      'schemaVersion': schemaVersion,
    };
  }

  SuggestionModel copyWith({
    String? suggestionId,
    String? title,
    String? body,
    String? reason,
    String? emoji,
    String? action,
    String? status,
    String? source,
    String? targetSurface,
    String? category,
    String? routineType,
    int? gapDays,
    List<String>? suggestionIds,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? acceptedAt,
    DateTime? dismissedAt,
    int? schemaVersion,
    Map<String, dynamic>? extra,
  }) {
    return SuggestionModel(
      suggestionId: suggestionId ?? this.suggestionId,
      title: title ?? this.title,
      body: body ?? this.body,
      reason: reason ?? this.reason,
      emoji: emoji ?? this.emoji,
      action: action ?? this.action,
      status: status == null ? this.status : _normalizeStatus(status),
      source: source ?? this.source,
      targetSurface: targetSurface ?? this.targetSurface,
      category: category ?? this.category,
      routineType: routineType ?? this.routineType,
      gapDays: gapDays ?? this.gapDays,
      suggestionIds: suggestionIds ?? this.suggestionIds,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      dismissedAt: dismissedAt ?? this.dismissedAt,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      extra: extra ?? this.extra,
    );
  }
}

const _knownKeys = {
  'suggestionId',
  'title',
  'body',
  'reason',
  'emoji',
  'action',
  'status',
  'source',
  'targetSurface',
  'category',
  'routineType',
  'gapDays',
  'suggestionIds',
  'metadata',
  'createdAt',
  'updatedAt',
  'acceptedAt',
  'dismissedAt',
  'schemaVersion',
};

String _cleanString(Object? value) => value?.toString().trim() ?? '';

String _normalizeStatus(Object? value) {
  final status = _cleanString(value).toLowerCase();
  if (status.isEmpty) return 'pending';
  return SuggestionModel.validStatuses.contains(status) ? status : 'pending';
}

int _asInt(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

List<String> _stringList(Object? value) {
  if (value is! List) return const [];
  return value
      .map((item) => item.toString().trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
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
