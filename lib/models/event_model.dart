// lib/models/event_model.dart
//
// The Event envelope — every event in Optivus uses this shape.
// Per ServiceContracts §1.3 and DB Schema §1A.5.
//
// The event log is append-only. Nothing is ever mutated or deleted.
// Corrections are new events, not edits.

import 'package:cloud_firestore/cloud_firestore.dart';

/// Who originated the event.
enum EventSource {
  ui,
  system,
  ai;

  /// Parse from Firestore string.
  static EventSource fromString(String value) {
    switch (value) {
      case 'ui':
        return EventSource.ui;
      case 'system':
        return EventSource.system;
      case 'ai':
        return EventSource.ai;
      default:
        return EventSource.ui;
    }
  }
}

/// Immutable event envelope.
class Event {
  final String eventId;
  final String eventName;
  final DateTime ts;
  final DateTime? deviceLocalTs;
  final EventSource source;
  final String deviceId;
  final int payloadVersion;
  final Map<String, dynamic> payload;
  final int schemaVersion;

  const Event({
    required this.eventId,
    required this.eventName,
    required this.ts,
    this.deviceLocalTs,
    required this.source,
    required this.deviceId,
    this.payloadVersion = 1,
    required this.payload,
    this.schemaVersion = 1,
  });

  /// Construct from Firestore document snapshot.
  factory Event.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Event(
      eventId: data['eventId'] as String? ?? doc.id,
      eventName: data['eventName'] as String,
      ts: (data['ts'] as Timestamp).toDate(),
      deviceLocalTs: data['deviceLocalTs'] != null
          ? (data['deviceLocalTs'] as Timestamp).toDate()
          : null,
      source: EventSource.fromString(data['source'] as String? ?? 'ui'),
      deviceId: data['deviceId'] as String? ?? '',
      payloadVersion: data['payloadVersion'] as int? ?? 1,
      payload: Map<String, dynamic>.from(data['payload'] as Map? ?? {}),
      schemaVersion: data['schemaVersion'] as int? ?? 1,
    );
  }

  /// Serialize for Firestore writes.
  /// Uses `FieldValue.serverTimestamp()` for `ts` so the server sets the time.
  Map<String, dynamic> toFirestore() {
    return {
      'eventId': eventId,
      'eventName': eventName,
      'ts': FieldValue.serverTimestamp(),
      'deviceLocalTs': deviceLocalTs != null
          ? Timestamp.fromDate(deviceLocalTs!)
          : Timestamp.fromDate(DateTime.now()),
      'source': source.name,
      'deviceId': deviceId,
      'payloadVersion': payloadVersion,
      'payload': payload,
      'schemaVersion': schemaVersion,
    };
  }

  /// Create a copy with overridden fields.
  Event copyWith({
    String? eventId,
    String? eventName,
    DateTime? ts,
    DateTime? deviceLocalTs,
    EventSource? source,
    String? deviceId,
    int? payloadVersion,
    Map<String, dynamic>? payload,
    int? schemaVersion,
  }) {
    return Event(
      eventId: eventId ?? this.eventId,
      eventName: eventName ?? this.eventName,
      ts: ts ?? this.ts,
      deviceLocalTs: deviceLocalTs ?? this.deviceLocalTs,
      source: source ?? this.source,
      deviceId: deviceId ?? this.deviceId,
      payloadVersion: payloadVersion ?? this.payloadVersion,
      payload: payload ?? this.payload,
      schemaVersion: schemaVersion ?? this.schemaVersion,
    );
  }

  @override
  String toString() => 'Event($eventName, id=$eventId)';
}
