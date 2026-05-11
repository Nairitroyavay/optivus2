String _cleanFixedScheduleString(Object? value) =>
    value?.toString().trim() ?? '';

bool isValidFixedScheduleTimeFormat(String value) {
  final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(value.trim());
  if (match == null) return false;
  final hour = int.tryParse(match.group(1)!);
  final minute = int.tryParse(match.group(2)!);
  if (hour == null || minute == null) return false;
  return hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59;
}

String normalizeFixedScheduleTime(
  Object? value, {
  required String fallback,
}) {
  final raw = _cleanFixedScheduleString(value);
  if (!isValidFixedScheduleTimeFormat(raw)) return fallback;
  final parts = raw.split(':');
  final hour = int.parse(parts[0]);
  final minute = int.parse(parts[1]);
  return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

String normalizeFixedScheduleRepeatRule(Object? value) {
  final raw = _cleanFixedScheduleString(value).toLowerCase();
  if (raw.isEmpty || raw == 'daily') return 'daily';
  if (raw == 'weekdays') return 'weekly:1,2,3,4,5';
  if (raw == 'weekends') return 'weekly:6,7';

  final weekly = RegExp(r'^weekly:(.+)$').firstMatch(raw);
  if (weekly == null) return raw;

  final weekdays = weekly
      .group(1)!
      .split(',')
      .map((part) => int.tryParse(part.trim()))
      .whereType<int>()
      .where((day) => day >= 1 && day <= 7)
      .toSet()
      .toList()
    ..sort();
  if (weekdays.isEmpty) return raw;
  return 'weekly:${weekdays.join(',')}';
}

int? fixedScheduleDurationMinutes(String startTime, String endTime) {
  if (!isValidFixedScheduleTimeFormat(startTime) ||
      !isValidFixedScheduleTimeFormat(endTime)) {
    return null;
  }
  final start = _fixedScheduleMinutes(startTime);
  var end = _fixedScheduleMinutes(endTime);
  if (end <= start) end += 1440;
  return end - start;
}

bool fixedScheduleRangesOverlap({
  required String startA,
  required String endA,
  required String startB,
  required String endB,
}) {
  final aMinutes = _occupiedMinutesForRange(startA, endA);
  final bMinutes = _occupiedMinutesForRange(startB, endB);
  if (aMinutes == null || bMinutes == null) return false;
  for (final minute in aMinutes) {
    if (bMinutes.contains(minute)) return true;
  }
  return false;
}

Map<String, dynamic> normalizeFixedScheduleTemplateMap(
  Map<String, dynamic> raw, {
  required int index,
  DateTime? now,
  bool preserveUnknown = true,
  bool touchUpdatedAt = false,
}) {
  final timestamp = (now ?? DateTime.now()).toIso8601String();
  final map = preserveUnknown
      ? <String, dynamic>{
          for (final entry in raw.entries) entry.key.toString(): entry.value
        }
      : <String, dynamic>{};

  final templateId = _cleanFixedScheduleString(raw['templateId'] ?? raw['id']);
  final createdAt = _cleanFixedScheduleString(raw['createdAt']);
  final updatedAt = _cleanFixedScheduleString(raw['updatedAt']);

  map['templateId'] =
      templateId.isNotEmpty ? templateId : 'fixed_schedule_${index + 1}';
  map['title'] = _cleanFixedScheduleString(raw['title'] ?? raw['name']);
  map['routineType'] = 'fixed_schedule';
  map['startTime'] = normalizeFixedScheduleTime(raw['startTime'] ?? raw['time'],
      fallback: '09:00');
  map['endTime'] =
      normalizeFixedScheduleTime(raw['endTime'], fallback: '10:00');
  map['repeatRule'] = normalizeFixedScheduleRepeatRule(raw['repeatRule']);
  map['category'] = _cleanFixedScheduleString(raw['category']);
  map['notes'] = _cleanFixedScheduleString(raw['notes']);
  map['reminderEnabled'] = raw['reminderEnabled'] == true;
  map['reminderOffsetMinutes'] =
      _fixedScheduleReminderOffsetMinutes(raw['reminderOffsetMinutes']);
  map['isActive'] = raw['isActive'] as bool? ?? true;
  map['createdAt'] = createdAt.isNotEmpty ? createdAt : timestamp;
  map['updatedAt'] = touchUpdatedAt
      ? timestamp
      : (updatedAt.isNotEmpty ? updatedAt : timestamp);

  return map;
}

String? validateFixedScheduleTemplateCandidate({
  required String title,
  required String startTime,
  required String endTime,
  required List<Map<String, dynamic>> existingTemplates,
  String? currentTemplateId,
  bool allowOverlap = false,
}) {
  if (_cleanFixedScheduleString(title).isEmpty) {
    return 'Title cannot be blank.';
  }
  if (!isValidFixedScheduleTimeFormat(startTime) ||
      !isValidFixedScheduleTimeFormat(endTime)) {
    return 'Time must use HH:mm format.';
  }
  if (startTime == endTime) {
    return 'Start and end time cannot be the same.';
  }

  final duration = fixedScheduleDurationMinutes(startTime, endTime);
  if (duration == null || duration <= 0 || duration >= 1440) {
    return 'Duration must be 1 to 1439 minutes.';
  }

  if (allowOverlap) return null;

  final currentId = _cleanFixedScheduleString(currentTemplateId);
  for (final existing in existingTemplates) {
    final existingId = _cleanFixedScheduleString(existing['templateId']);
    if (currentId.isNotEmpty && existingId == currentId) continue;

    final existingStart = _cleanFixedScheduleString(existing['startTime']);
    final existingEnd = _cleanFixedScheduleString(existing['endTime']);
    if (!isValidFixedScheduleTimeFormat(existingStart) ||
        !isValidFixedScheduleTimeFormat(existingEnd)) {
      continue;
    }

    if (fixedScheduleRangesOverlap(
      startA: startTime,
      endA: endTime,
      startB: existingStart,
      endB: existingEnd,
    )) {
      return 'Time overlaps with another task. Adjust times or allow overlaps.';
    }
  }

  return null;
}

int _fixedScheduleReminderOffsetMinutes(Object? value) {
  if (value is int) return value.clamp(0, 180);
  if (value is num) return value.round().clamp(0, 180);
  return int.tryParse(_cleanFixedScheduleString(value))?.clamp(0, 180) ?? 5;
}

int _fixedScheduleMinutes(String hhmm) {
  final parts = hhmm.split(':');
  return int.parse(parts[0]) * 60 + int.parse(parts[1]);
}

Set<int>? _occupiedMinutesForRange(String startTime, String endTime) {
  if (!isValidFixedScheduleTimeFormat(startTime) ||
      !isValidFixedScheduleTimeFormat(endTime)) {
    return null;
  }
  final start = _fixedScheduleMinutes(startTime);
  var end = _fixedScheduleMinutes(endTime);
  if (end <= start) end += 1440;
  final occupied = <int>{};
  for (var minute = start; minute < end; minute++) {
    occupied.add(minute % 1440);
  }
  return occupied;
}
