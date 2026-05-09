import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';

class RoutineTemplateModel {
  final String templateId;
  final String title;
  final String routineType;
  final String startTime;
  final String endTime;
  final String repeatRule;
  final String category;
  final String notes;
  final List<Map<String, dynamic>> steps;
  final List<String> warnings;
  final double confidence;
  final bool reminderEnabled;
  final int reminderOffsetMinutes;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic> metadata;
  final Map<String, dynamic> extra;

  const RoutineTemplateModel({
    required this.templateId,
    required this.title,
    required this.routineType,
    this.startTime = '09:00',
    this.endTime = '09:30',
    this.repeatRule = 'daily',
    this.category = '',
    this.notes = '',
    this.steps = const [],
    this.warnings = const [],
    this.confidence = 1,
    this.reminderEnabled = false,
    this.reminderOffsetMinutes = 5,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
    this.metadata = const {},
    this.extra = const {},
  });

  factory RoutineTemplateModel.fromMap(
    Map<String, dynamic> map, {
    String fallbackRoutineType = 'custom',
    String fallbackId = '',
  }) {
    final title = _cleanString(map['title'] ?? map['name']);
    return RoutineTemplateModel(
      templateId: _cleanString(
        map['templateId'] ?? map['id'] ?? fallbackId,
      ),
      title: title,
      routineType: _cleanString(map['routineType']).isNotEmpty
          ? _cleanString(map['routineType'])
          : fallbackRoutineType,
      startTime: _normalizeTime(
        map['startTime'] ?? map['time'],
        fallback: '09:00',
      ),
      endTime: _normalizeTime(map['endTime'], fallback: '09:30'),
      repeatRule:
          _cleanString(map['repeatRule'] ?? map['weekdayRule']).isNotEmpty
              ? _cleanString(map['repeatRule'] ?? map['weekdayRule'])
              : 'daily',
      category: _cleanString(map['category']),
      notes: _cleanString(map['notes']),
      steps: _mapList(map['steps']),
      warnings: _stringList(map['warnings']),
      confidence:
          _asDouble(map['confidence'], fallback: 1).clamp(0, 1).toDouble(),
      reminderEnabled: map['reminderEnabled'] == true,
      reminderOffsetMinutes: _asInt(
        map['reminderOffsetMinutes'],
        fallback: 5,
      ).clamp(0, 180).toInt(),
      isActive: _asActive(map),
      createdAt: _asDateTime(map['createdAt']),
      updatedAt: _asDateTime(map['updatedAt']),
      metadata: _stringKeyMap(map['metadata']),
      extra: _extra(map, _knownKeys),
    );
  }

  factory RoutineTemplateModel.forSave(
    Map<String, dynamic> map, {
    String fallbackRoutineType = 'custom',
    String fallbackId = '',
    DateTime? now,
  }) {
    final timestamp = now ?? DateTime.now();
    final parsed = RoutineTemplateModel.fromMap(
      map,
      fallbackRoutineType: fallbackRoutineType,
      fallbackId: fallbackId,
    );
    final hasExplicitEndTime = _cleanString(map['endTime']).isNotEmpty;
    final normalized = hasExplicitEndTime
        ? parsed
        : parsed.copyWith(endTime: _timePlusMinutes(parsed.startTime, 30));
    final templateId = normalized.templateId.isNotEmpty
        ? normalized.templateId
        : 'tpl_${normalized.generateDeterministicHash()}';

    return normalized.copyWith(
      templateId: templateId,
      createdAt: normalized.createdAt ?? timestamp,
      updatedAt: timestamp,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      ...extra,
      'templateId': templateId,
      'title': title,
      'routineType': routineType,
      'startTime': startTime,
      'endTime': endTime,
      'repeatRule': repeatRule,
      if (category.isNotEmpty) 'category': category,
      if (notes.isNotEmpty) 'notes': notes,
      'steps': steps,
      'warnings': warnings,
      'confidence': confidence,
      'reminderEnabled': reminderEnabled,
      'reminderOffsetMinutes': reminderOffsetMinutes,
      'isActive': isActive,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      'metadata': metadata,
    };
  }

  RoutineTemplateModel copyWith({
    String? templateId,
    String? title,
    String? routineType,
    String? startTime,
    String? endTime,
    String? repeatRule,
    String? category,
    String? notes,
    List<Map<String, dynamic>>? steps,
    List<String>? warnings,
    double? confidence,
    bool? reminderEnabled,
    int? reminderOffsetMinutes,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? metadata,
    Map<String, dynamic>? extra,
  }) {
    return RoutineTemplateModel(
      templateId: templateId ?? this.templateId,
      title: title ?? this.title,
      routineType: routineType ?? this.routineType,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      repeatRule: repeatRule ?? this.repeatRule,
      category: category ?? this.category,
      notes: notes ?? this.notes,
      steps: steps ?? this.steps,
      warnings: warnings ?? this.warnings,
      confidence: confidence ?? this.confidence,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderOffsetMinutes:
          reminderOffsetMinutes ?? this.reminderOffsetMinutes,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
      extra: extra ?? this.extra,
    );
  }

  /// Generates a stable hash from a sorted map representation.
  String generateDeterministicHash() {
    final sortedMap = _sortMap(toMap());
    // Strip unstable fields that shouldn't affect uniqueness for a task generated on a specific date.
    sortedMap.remove('createdAt');
    sortedMap.remove('updatedAt');
    final jsonString = jsonEncode(sortedMap);
    return md5.convert(utf8.encode(jsonString)).toString().substring(0, 8);
  }

  static Map<String, dynamic> _sortMap(Map<String, dynamic> map) {
    final sortedKeys = map.keys.toList()..sort();
    return {
      for (final key in sortedKeys)
        key: map[key] is Map
            ? _sortMap(Map<String, dynamic>.from(map[key] as Map))
            : (map[key] is List ? _sortList(map[key] as List) : map[key]),
    };
  }

  static List<dynamic> _sortList(List<dynamic> list) {
    return list
        .map((e) => e is Map ? _sortMap(Map<String, dynamic>.from(e)) : e)
        .toList();
  }
}

const _knownKeys = {
  'templateId',
  'title',
  'routineType',
  'startTime',
  'endTime',
  'repeatRule',
  'category',
  'notes',
  'steps',
  'warnings',
  'confidence',
  'reminderEnabled',
  'reminderOffsetMinutes',
  'isActive',
  'createdAt',
  'updatedAt',
  'metadata',
};

String _cleanString(Object? value) => value?.toString().trim() ?? '';

String _normalizeTime(Object? value, {required String fallback}) {
  final text = _cleanString(value).toUpperCase();
  final amPm = RegExp(r'^(\d{1,2})(?::(\d{2}))?\s*([AP]M)$').firstMatch(text);
  if (amPm != null) {
    var hour = int.tryParse(amPm.group(1)!) ?? -1;
    final minute = int.tryParse(amPm.group(2) ?? '0') ?? -1;
    final suffix = amPm.group(3);
    if (suffix == 'PM' && hour != 12) hour += 12;
    if (suffix == 'AM' && hour == 12) hour = 0;
    return _validTime(hour, minute, fallback);
  }

  final hhmm = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(text);
  if (hhmm == null) return fallback;
  final hour = int.tryParse(hhmm.group(1)!) ?? -1;
  final minute = int.tryParse(hhmm.group(2)!) ?? -1;
  return _validTime(hour, minute, fallback);
}

String _validTime(int hour, int minute, String fallback) {
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return fallback;
  return '${hour.toString().padLeft(2, '0')}:'
      '${minute.toString().padLeft(2, '0')}';
}

String _timePlusMinutes(String hhmm, int deltaMinutes) {
  final normalized = _normalizeTime(hhmm, fallback: '09:00');
  final parts = normalized.split(':').map(int.parse).toList();
  final totalMinutes = (parts[0] * 60 + parts[1] + deltaMinutes) % 1440;
  final hour = totalMinutes ~/ 60;
  final minute = totalMinutes % 60;
  return '${hour.toString().padLeft(2, '0')}:'
      '${minute.toString().padLeft(2, '0')}';
}

bool _asActive(Map<String, dynamic> map) {
  if (map['isActive'] is bool) return map['isActive'] as bool;
  final lifecycle = _cleanString(map['state'] ?? map['status']).toLowerCase();
  if (lifecycle == 'inactive' ||
      lifecycle == 'archived' ||
      lifecycle == 'deleted') {
    return false;
  }
  return true;
}

List<Map<String, dynamic>> _mapList(Object? value) {
  if (value is! List) return const [];
  return value.map((item) {
    if (item is Map) {
      return {
        for (final entry in item.entries) entry.key.toString(): entry.value
      };
    }
    return {'name': item.toString()};
  }).toList(growable: false);
}

List<String> _stringList(Object? value) {
  if (value is! List) {
    final text = _cleanString(value);
    return text.isEmpty ? const [] : [text];
  }
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

int _asInt(Object? value, {required int fallback}) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

double _asDouble(Object? value, {required double fallback}) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
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
