// lib/services/event_service.dart
//
// The pub-sub bus. Every other service depends on this.
// Per ServiceContracts §1 — owns writing events to Firestore atomically,
// broadcasting to local subscribers, and replay on app start.
//
// Hard rules:
// 1. Writes go to BOTH events and events_recent in the same transaction.
// 2. Duplicate eventIds are rejected (idempotent).
// 3. The local stream fires only AFTER the Firestore write is at least queued.
// 4. events_recent is the fast UI cache; events is the source of truth.

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/errors/app_errors.dart';
import '../core/utils/device_id.dart';
import '../core/utils/uuid_generator.dart';
import '../models/event_model.dart';

/// Key prefix for the processed-events cache in SharedPreferences.
const _kProcessedPrefix = 'optivus_processed_events';

class EventService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  /// In-memory broadcast stream — listeners get events immediately after write.
  final StreamController<Event> _eventBus =
      StreamController<Event>.broadcast();

  /// Cache of processed event IDs to prevent re-processing on replay.
  final Set<String> _processedIds = {};

  /// Whether we've loaded the processed cache from disk yet.
  bool _cacheLoaded = false;

  EventService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  // ── Helpers ──────────────────────────────────────────────────────────────

  /// Current authenticated user's UID. Throws if not logged in.
  String get _uid {
    final user = _auth.currentUser;
    if (user == null) throw const NotAuthenticatedError();
    return user.uid;
  }

  /// Reference to user's events collection (source of truth).
  CollectionReference<Map<String, dynamic>> get _eventsRef =>
      _firestore.collection('users').doc(_uid).collection('events');

  /// Reference to user's events_recent collection (fast UI cache).
  CollectionReference<Map<String, dynamic>> get _eventsRecentRef =>
      _firestore.collection('users').doc(_uid).collection('events_recent');

  // ── Core API ────────────────────────────────────────────────────────────

  /// Emit an event to Firestore and broadcast on the local stream.
  ///
  /// Per ServiceContracts §1.2:
  /// - If [batch] is provided, the event write is added to it (caller commits).
  /// - If [batch] is null, EventService creates its own transaction with dedup.
  /// - The local stream fires only after the write is at least queued.
  Future<void> emit({
    required String eventName,
    required Map<String, dynamic> payload,
    int payloadVersion = 1,
    EventSource source = EventSource.ui,
    WriteBatch? batch,
  }) async {
    final deviceId = await getDeviceId();
    final now = DateTime.now();
    final eventId = generateId(); // UUIDv7

    final event = Event(
      eventId: eventId,
      eventName: eventName,
      ts: now, // Will be overwritten by server timestamp on read-back
      deviceLocalTs: now,
      source: source,
      deviceId: deviceId,
      payloadVersion: payloadVersion,
      payload: payload,
      schemaVersion: 1,
    );

    final eventDoc = event.toFirestore();

    if (batch != null) {
      // Caller owns the batch — just add our writes.
      batch.set(_eventsRef.doc(eventId), eventDoc);
      batch.set(_eventsRecentRef.doc(eventId), eventDoc);
      // Fire on local bus immediately (optimistic — batch will commit).
      _publishLocally(event);
    } else {
      // We own the write — use a transaction for idempotent dedup.
      // Per DB Schema §1A.3 "Server-side eventId deduplication (mandatory)".
      final wrote = await _writeEventIdempotent(
        eventId: eventId,
        eventDoc: eventDoc,
      );

      if (!wrote) {
        // Duplicate — safe to ignore per contract.
        debugPrint('[EventService] Duplicate event ignored: $eventId');
        return;
      }

      _publishLocally(event);
    }

    // Mark as processed so replay doesn't re-fire it.
    _processedIds.add(eventId);
    _persistProcessedId(eventId);
  }

  /// Subscribe to a single event type.
  Stream<Event> on(String eventName) {
    return _eventBus.stream.where((e) => e.eventName == eventName);
  }

  /// Subscribe to all events.
  Stream<Event> onAny() => _eventBus.stream;

  /// Called once during app startup, after auth is restored.
  ///
  /// Per ServiceContracts §1.2 replayRecentEvents:
  /// 1. Read events_recent ordered by ts ASC, limit 50.
  /// 2. For each, check _processedIds cache.
  /// 3. If not seen → fire on local stream, add to cache.
  /// 4. If seen → skip.
  Future<void> replayRecentEvents() async {
    await _loadProcessedCache();

    try {
      final snap = await _eventsRecentRef
          .orderBy('ts', descending: false)
          .limit(50)
          .get();

      for (final doc in snap.docs) {
        final eventId = doc.id;
        if (_processedIds.contains(eventId)) continue;

        final event = Event.fromFirestore(doc);
        _publishLocally(event);
        _processedIds.add(eventId);
        _persistProcessedId(eventId);
      }
    } catch (e) {
      debugPrint('[EventService] Replay failed: $e');
      // Non-fatal — the app still works, just some events may not trigger
      // their listeners until the next write or a future replay.
    }
  }

  /// Clean up resources.
  void dispose() {
    _eventBus.close();
  }

  // ── Private ─────────────────────────────────────────────────────────────

  /// Publish an event on the local in-memory bus.
  void _publishLocally(Event event) {
    if (!_eventBus.isClosed) {
      _eventBus.add(event);
    }
  }

  /// Idempotent dual-write via Firestore transaction.
  /// Returns true if a new event was written, false if duplicate.
  ///
  /// Per DB Schema §1A.3:
  /// "The transaction read-then-write makes 'first writer wins' atomic."
  Future<bool> _writeEventIdempotent({
    required String eventId,
    required Map<String, dynamic> eventDoc,
  }) {
    final eventsDocRef = _eventsRef.doc(eventId);
    final recentDocRef = _eventsRecentRef.doc(eventId);

    return _firestore.runTransaction<bool>((tx) async {
      final existing = await tx.get(eventsDocRef);
      if (existing.exists) {
        return false; // Duplicate — do nothing.
      }
      tx.set(eventsDocRef, eventDoc);
      tx.set(recentDocRef, eventDoc);
      return true;
    });
  }

  /// Load the processed-events cache from SharedPreferences.
  Future<void> _loadProcessedCache() async {
    if (_cacheLoaded) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList(_kProcessedPrefix) ?? [];
      _processedIds.addAll(stored);
    } catch (e) {
      debugPrint('[EventService] Failed to load processed cache: $e');
    }
    _cacheLoaded = true;
  }

  /// Persist a newly-processed event ID to SharedPreferences.
  /// Caps at 200 entries to avoid unbounded growth.
  Future<void> _persistProcessedId(String eventId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList(_kProcessedPrefix) ?? [];
      stored.add(eventId);

      // Cap: keep only the newest 200 processed IDs.
      if (stored.length > 200) {
        stored.removeRange(0, stored.length - 200);
      }
      await prefs.setStringList(_kProcessedPrefix, stored);
    } catch (e) {
      // Non-fatal — worst case is a duplicate replay on next startup.
      debugPrint('[EventService] Failed to persist processed ID: $e');
    }
  }
}
