// lib/core/utils/uuid_generator.dart
//
// UUIDv7 generator — all Optivus document IDs use this.
// UUIDv7 is time-ordered (ms-precision Unix timestamp in the high bits)
// so Firestore documents are naturally sorted by creation time.
// Per DB Schema Part 2 — "All IDs are UUIDs, generated client-side
// (UUIDv7 preferred — naturally sorted). Not auto-increment."

import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Generate a new UUIDv7 string (time-ordered, globally unique).
String generateId() => _uuid.v7();

/// Generate a short ID for human-readable composite keys.
/// Returns the first 8 hex chars of a UUIDv4 (not time-ordered).
String generateShortId() => _uuid.v4().replaceAll('-', '').substring(0, 8);
