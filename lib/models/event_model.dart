import 'package:cloud_firestore/cloud_firestore.dart';

class EventModel {
  final String eventId;
  final String eventName;
  final DateTime ts;
  final DateTime deviceLocalTs;
  final String deviceId;
  final String source;
  final String priority;
  final int payloadVersion;
  final Map<String, dynamic> payload;
  final int schemaVersion;

  const EventModel({
    required this.eventId,
    required this.eventName,
    required this.ts,
    required this.deviceLocalTs,
    required this.deviceId,
    required this.source,
    this.priority = 'normal',
    this.payloadVersion = 1,
    required this.payload,
    this.schemaVersion = 1,
  });

  factory EventModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return EventModel(
      eventId: data['eventId'] as String? ?? doc.id,
      eventName: data['eventName'] as String? ?? '',
      ts: _asDateTime(data['ts']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      deviceLocalTs: _asDateTime(data['deviceLocalTs']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      deviceId: data['deviceId'] as String? ?? '',
      source: data['source'] as String? ?? '',
      priority: data['priority'] as String? ?? 'normal',
      payloadVersion: data['payloadVersion'] as int? ?? 1,
      payload: Map<String, dynamic>.from(data['payload'] as Map? ?? const {}),
      schemaVersion: data['schemaVersion'] as int? ?? 1,
    );
  }

  factory EventModel.fromMap(Map<String, dynamic> map) {
    return EventModel(
      eventId: map['eventId'] as String? ?? '',
      eventName: map['eventName'] as String? ?? '',
      ts: _asDateTime(map['ts']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      deviceLocalTs: _asDateTime(map['deviceLocalTs']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      deviceId: map['deviceId'] as String? ?? '',
      source: map['source'] as String? ?? '',
      priority: map['priority'] as String? ?? 'normal',
      payloadVersion: map['payloadVersion'] as int? ?? 1,
      payload: Map<String, dynamic>.from(map['payload'] as Map? ?? const {}),
      schemaVersion: map['schemaVersion'] as int? ?? 1,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'eventId': eventId,
      'eventName': eventName,
      'ts': Timestamp.fromDate(ts),
      'deviceLocalTs': Timestamp.fromDate(deviceLocalTs),
      'deviceId': deviceId,
      'source': source,
      'priority': priority,
      'payloadVersion': payloadVersion,
      'payload': payload,
      'schemaVersion': schemaVersion,
    };
  }

  Map<String, dynamic> toMap() => toFirestore();

  EventModel copyWith({
    String? eventId,
    String? eventName,
    DateTime? ts,
    DateTime? deviceLocalTs,
    String? deviceId,
    String? source,
    String? priority,
    int? payloadVersion,
    Map<String, dynamic>? payload,
    int? schemaVersion,
  }) {
    return EventModel(
      eventId: eventId ?? this.eventId,
      eventName: eventName ?? this.eventName,
      ts: ts ?? this.ts,
      deviceLocalTs: deviceLocalTs ?? this.deviceLocalTs,
      deviceId: deviceId ?? this.deviceId,
      source: source ?? this.source,
      priority: priority ?? this.priority,
      payloadVersion: payloadVersion ?? this.payloadVersion,
      payload: payload ?? this.payload,
      schemaVersion: schemaVersion ?? this.schemaVersion,
    );
  }

  static DateTime? _asDateTime(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

typedef Event = EventModel;
