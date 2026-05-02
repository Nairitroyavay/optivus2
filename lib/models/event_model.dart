import 'package:cloud_firestore/cloud_firestore.dart';

class EventModel {
  final String eventId;
  final String eventName;
  final String uid;
  final DateTime timestamp;
  final String source;
  final int schemaVersion;
  final int payloadVersion;
  final Map<String, dynamic> payload;
  final String deviceId;
  final String appVersion;

  EventModel({
    required this.eventId,
    required this.eventName,
    this.uid = '',
    DateTime? timestamp,
    DateTime? ts,
    DateTime? deviceLocalTs,
    required this.source,
    this.schemaVersion = 1,
    this.payloadVersion = 1,
    required this.payload,
    required this.deviceId,
    this.appVersion = '1.0.0',
  }) : timestamp = timestamp ??
            ts ??
            deviceLocalTs ??
            DateTime.fromMillisecondsSinceEpoch(0);

  DateTime get ts => timestamp;
  DateTime get deviceLocalTs => timestamp;

  factory EventModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return EventModel(
      eventId: data['eventId'] as String? ?? doc.id,
      eventName: data['eventName'] as String? ?? '',
      uid: data['uid'] as String? ?? '',
      timestamp: _asDateTime(data['timestamp']) ??
          _asDateTime(data['ts']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      source: data['source'] as String? ?? '',
      schemaVersion: data['schemaVersion'] as int? ?? 1,
      payloadVersion: data['payloadVersion'] as int? ?? 1,
      payload: Map<String, dynamic>.from(data['payload'] as Map? ?? const {}),
      deviceId: data['deviceId'] as String? ?? '',
      appVersion: data['appVersion'] as String? ?? '1.0.0',
    );
  }

  factory EventModel.fromMap(Map<String, dynamic> map) {
    return EventModel(
      eventId: map['eventId'] as String? ?? '',
      eventName: map['eventName'] as String? ?? '',
      uid: map['uid'] as String? ?? '',
      timestamp: _asDateTime(map['timestamp']) ??
          _asDateTime(map['ts']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      source: map['source'] as String? ?? '',
      schemaVersion: map['schemaVersion'] as int? ?? 1,
      payloadVersion: map['payloadVersion'] as int? ?? 1,
      payload: Map<String, dynamic>.from(map['payload'] as Map? ?? const {}),
      deviceId: map['deviceId'] as String? ?? '',
      appVersion: map['appVersion'] as String? ?? '1.0.0',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'eventId': eventId,
      'eventName': eventName,
      'uid': uid,
      'timestamp': Timestamp.fromDate(timestamp),
      'source': source,
      'schemaVersion': schemaVersion,
      'payloadVersion': payloadVersion,
      'payload': payload,
      'deviceId': deviceId,
      'appVersion': appVersion,
    };
  }

  Map<String, dynamic> toMap() => toFirestore();

  EventModel copyWith({
    String? eventId,
    String? eventName,
    String? uid,
    DateTime? timestamp,
    String? source,
    int? schemaVersion,
    int? payloadVersion,
    Map<String, dynamic>? payload,
    String? deviceId,
    String? appVersion,
  }) {
    return EventModel(
      eventId: eventId ?? this.eventId,
      eventName: eventName ?? this.eventName,
      uid: uid ?? this.uid,
      timestamp: timestamp ?? this.timestamp,
      source: source ?? this.source,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      payloadVersion: payloadVersion ?? this.payloadVersion,
      payload: payload ?? this.payload,
      deviceId: deviceId ?? this.deviceId,
      appVersion: appVersion ?? this.appVersion,
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
