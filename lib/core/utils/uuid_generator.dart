// lib/core/utils/uuid_generator.dart
//
// UUIDv7 generator — all Optivus document IDs use this.
// UUIDv7 is time-ordered (ms-precision Unix timestamp in the high bits)
// so Firestore documents are naturally sorted by creation time.
// Per DB Schema Part 2 — "All IDs are UUIDs, generated client-side
// (UUIDv7 preferred — naturally sorted). Not auto-increment."

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Generate a new UUIDv7 string (time-ordered, globally unique).
String generateId() => _uuid.v7();

/// Generate a short ID for human-readable composite keys.
/// Returns the first 8 hex chars of a UUIDv4 (not time-ordered).
String generateShortId() => _uuid.v4().replaceAll('-', '').substring(0, 8);

/// Generates a deterministic ID from event details for idempotency.
String generateDeterministicId({
  required String eventName,
  required DateTime timestamp,
  required Map<String, dynamic> payload,
  String? uid,
  String? source,
  int? payloadVersion,
}) {
  final canonicalPayload = _canonicalize(payload);
  final seed = jsonEncode({
    'eventName': eventName,
    'timestamp': timestamp.toUtc().toIso8601String(),
    if (uid != null) 'uid': uid,
    if (source != null) 'source': source,
    if (payloadVersion != null) 'payloadVersion': payloadVersion,
    'payload': canonicalPayload,
  });
  return sha256.convert(utf8.encode(seed)).toString();
}

Object? _canonicalize(Object? value) {
  if (value is Map) {
    final sortedKeys = value.keys.map((key) => key.toString()).toList()..sort();
    return {
      for (final key in sortedKeys) key: _canonicalize(value[key]),
    };
  }

  if (value is List) {
    return value.map(_canonicalize).toList();
  }

  if (value is DateTime) {
    return value.toUtc().toIso8601String();
  }

  if (value is Timestamp) {
    return value.toDate().toUtc().toIso8601String();
  }

  return value;
}
