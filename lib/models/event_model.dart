import 'package:cloud_firestore/cloud_firestore.dart';

class EventModel {
  final String eventId;
  final String eventName;
  final DateTime ts;
  final DateTime deviceLocalTs;
  final String source;
  final Map<String, dynamic> payload;

  const EventModel({
    required this.eventId,
    required this.eventName,
    required this.ts,
    required this.deviceLocalTs,
    required this.source,
    required this.payload,
  });

  factory EventModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return EventModel(
      eventId: data['eventId'] as String? ?? doc.id,
      eventName: data['eventName'] as String? ?? '',
      ts: _asDateTime(data['ts']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      deviceLocalTs:
          _asDateTime(data['deviceLocalTs']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      source: data['source'] as String? ?? '',
      payload: Map<String, dynamic>.from(data['payload'] as Map? ?? const {}),
    );
  }

  factory EventModel.fromMap(Map<String, dynamic> map) {
    return EventModel(
      eventId: map['eventId'] as String? ?? '',
      eventName: map['eventName'] as String? ?? '',
      ts: _asDateTime(map['ts']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      deviceLocalTs:
          _asDateTime(map['deviceLocalTs']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      source: map['source'] as String? ?? '',
      payload: Map<String, dynamic>.from(map['payload'] as Map? ?? const {}),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'eventId': eventId,
      'eventName': eventName,
      'ts': Timestamp.fromDate(ts),
      'deviceLocalTs': Timestamp.fromDate(deviceLocalTs),
      'source': source,
      'payload': payload,
      'schemaVersion': 1,
    };
  }

  Map<String, dynamic> toMap() => toFirestore();

  EventModel copyWith({
    String? eventId,
    String? eventName,
    DateTime? ts,
    DateTime? deviceLocalTs,
    String? source,
    Map<String, dynamic>? payload,
  }) {
    return EventModel(
      eventId: eventId ?? this.eventId,
      eventName: eventName ?? this.eventName,
      ts: ts ?? this.ts,
      deviceLocalTs: deviceLocalTs ?? this.deviceLocalTs,
      source: source ?? this.source,
      payload: payload ?? this.payload,
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
