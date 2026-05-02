import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/errors/app_errors.dart';
import '../core/utils/device_id.dart';
import '../core/utils/uuid_generator.dart';
import '../models/event_model.dart';
import 'event_payload_validator.dart';

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
    String? eventId,
    String source = 'ui',
    String priority = 'normal',
    int payloadVersion = 1,
    WriteBatch? batch,
  }) async {
    final validation = EventPayloadValidator.validate(eventName, payload);
    if (!validation.isValid) {
      EventPayloadValidator.logFailure(validation);
      assert(() {
        throw FlutterError(validation.message!);
      }());
      return;
    }

    final now = DateTime.now();
    final deviceId = await getDeviceId();
    final uid = _uid;

    final generatedId = eventId ??
        generateDeterministicId(
          eventName: eventName,
          timestamp: now,
          uid: uid,
          source: source,
          payloadVersion: payloadVersion,
          payload: payload,
        );

    final event = EventModel(
      eventId: generatedId,
      eventName: eventName,
      uid: uid,
      timestamp: now,
      source: source,
      schemaVersion: 1,
      payloadVersion: payloadVersion,
      payload: Map<String, dynamic>.from(payload),
      deviceId: deviceId,
      appVersion: '1.0.0', // Fallback or could be loaded dynamically
    );

    final eventRef = _eventsRef.doc(generatedId);
    final eventDoc = event.toFirestore();

    if (batch != null) {
      final existingSnap = await eventRef.get();
      if (existingSnap.exists) {
        debugPrint(
            '[EventService] Event $generatedId already exists. Skipping duplicate.');
        return;
      }
      batch.set(eventRef, eventDoc);
      batch.set(_eventsRecentRef.doc(generatedId), eventDoc);
      _publishLocally(event);
      _processedIds.add(generatedId);
      unawaited(_persistProcessedId(generatedId));
    } else {
      final wasInserted =
          await _firestore.runTransaction<bool>((transaction) async {
        final existingSnap = await transaction.get(eventRef);
        if (existingSnap.exists) {
          debugPrint(
              '[EventService] Event $generatedId already exists. Skipping duplicate.');
          return false;
        }
        transaction.set(eventRef, eventDoc);
        transaction.set(_eventsRecentRef.doc(generatedId), eventDoc);
        return true;
      });

      if (wasInserted) {
        _publishLocally(event);
        _processedIds.add(generatedId);
        unawaited(_persistProcessedId(generatedId));
      }
    }
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
          .orderBy('timestamp', descending: true)
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
