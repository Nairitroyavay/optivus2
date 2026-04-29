import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/errors/app_errors.dart';
import '../models/event_model.dart';

const _kProcessedPrefix = 'optivus_processed_events';

class EventService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final StreamController<EventModel> _eventBus =
      StreamController<EventModel>.broadcast();
  final Set<String> _processedIds = {};

  bool _cacheLoaded = false;

  EventService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  String get _uid {
    final user = _auth.currentUser;
    if (user == null) throw const NotAuthenticatedError();
    return user.uid;
  }

  CollectionReference<Map<String, dynamic>> get _eventsRef =>
      _firestore.collection('users').doc(_uid).collection('events');

  CollectionReference<Map<String, dynamic>> get _eventsRecentRef =>
      _firestore.collection('users').doc(_uid).collection('events_recent');

  Future<void> emit({
    required String eventName,
    required Map<String, dynamic> payload,
    String source = 'ui',
    WriteBatch? batch,
  }) async {
    final now = DateTime.now();
    final eventId = _generateDeterministicEventId(
      eventName: eventName,
      ts: now,
      payload: payload,
    );

    final event = EventModel(
      eventId: eventId,
      eventName: eventName,
      ts: now,
      deviceLocalTs: now,
      source: source,
      payload: Map<String, dynamic>.from(payload),
    );

    final eventDoc = event.toFirestore();

    if (batch != null) {
      batch.set(_eventsRef.doc(eventId), eventDoc);
      batch.set(_eventsRecentRef.doc(eventId), eventDoc);
      _publishLocally(event);
    } else {
      final writeBatch = _firestore.batch();
      writeBatch.set(_eventsRef.doc(eventId), eventDoc);
      writeBatch.set(_eventsRecentRef.doc(eventId), eventDoc);
      await writeBatch.commit();
      _publishLocally(event);
    }

    _processedIds.add(eventId);
    unawaited(_persistProcessedId(eventId));
  }

  Stream<EventModel> on(String eventName) {
    return _eventBus.stream.where((event) => event.eventName == eventName);
  }

  Stream<EventModel> onAny() => _eventBus.stream;

  /// Replays the most recent 50 events from `events_recent` on app startup.
  ///
  /// Events already present in the local processed-ID cache are skipped.
  /// Fresh events are re-published on the local stream in chronological order
  /// so downstream subscribers (for example EventOrchestrator) can catch up.
  Future<void> replayRecentEvents() async {
    await _loadProcessedCache();

    try {
      final snap = await _eventsRecentRef
          .orderBy('ts', descending: true)
          .limit(50)
          .get();

      final docs = snap.docs.toList().reversed;
      for (final doc in docs) {
        final eventId = doc.id;
        if (_processedIds.contains(eventId)) continue;

        final event = EventModel.fromFirestore(doc);
        _publishLocally(event);
        _processedIds.add(eventId);
        unawaited(_persistProcessedId(eventId));
      }
    } catch (e) {
      debugPrint('[EventService] Replay failed: $e');
    }
  }

  void dispose() {
    _eventBus.close();
  }

  void _publishLocally(EventModel event) {
    if (!_eventBus.isClosed) {
      _eventBus.add(event);
    }
  }

  String _generateDeterministicEventId({
    required String eventName,
    required DateTime ts,
    required Map<String, dynamic> payload,
  }) {
    final canonicalPayload = _canonicalize(payload);
    final seed = jsonEncode({
      'eventName': eventName,
      'ts': ts.toUtc().toIso8601String(),
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

  Future<void> _persistProcessedId(String eventId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList(_kProcessedPrefix) ?? [];
      stored.add(eventId);

      if (stored.length > 200) {
        stored.removeRange(0, stored.length - 200);
      }

      await prefs.setStringList(_kProcessedPrefix, stored);
    } catch (e) {
      debugPrint('[EventService] Failed to persist processed ID: $e');
    }
  }
}
