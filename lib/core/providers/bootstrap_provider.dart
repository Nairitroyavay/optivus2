import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus2/core/providers.dart';
import 'package:optivus2/models/user_model.dart';
import 'package:optivus2/services/event_service.dart';

enum BootstrapState { initializing, unauthenticated, needsOnboarding, ready }

class AppBootstrapNotifier extends StateNotifier<BootstrapState> {
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userSubscription;
  final EventService _eventService;
  final Future<void> Function() _ensureOrchestratorInitialized;

  AppBootstrapNotifier({
    required EventService eventService,
    required Future<void> Function() ensureOrchestratorInitialized,
  })  : _eventService = eventService,
        _ensureOrchestratorInitialized = ensureOrchestratorInitialized,
        super(BootstrapState.initializing) {
    _init();
  }

  void _init() {
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen(
      _handleAuthChanged,
      onError: (_) => _setState(BootstrapState.unauthenticated),
    );
  }

  Future<void> _handleAuthChanged(User? user) async {
    await _userSubscription?.cancel();
    _userSubscription = null;

    if (user == null) {
      _setState(BootstrapState.unauthenticated);
      return;
    }

    _userSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen(
      (doc) async {
        try {
          if (!doc.exists) {
            _setState(BootstrapState.needsOnboarding);
            return;
          }

          final userModel = UserModel.fromFirestore(doc);
          if (!userModel.hasCompletedOnboarding) {
            _setState(BootstrapState.needsOnboarding);
            return;
          }

          await _ensureOrchestratorInitialized();
          await _eventService.replayRecentEvents();
          _setState(BootstrapState.ready);
        } catch (e) {
          debugPrint('[Bootstrap] Failed to resolve user state: $e');
          _setState(BootstrapState.needsOnboarding);
        }
      },
      onError: (Object error) {
        debugPrint('[Bootstrap] User document listener failed: $error');
        _setState(BootstrapState.needsOnboarding);
      },
    );
  }

  void _setState(BootstrapState nextState) {
    if (state == nextState) return;
    debugPrint('[Bootstrap] ${state.name} -> ${nextState.name}');
    state = nextState;
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _userSubscription?.cancel();
    super.dispose();
  }
}

final bootstrapProvider = StateNotifierProvider<AppBootstrapNotifier, BootstrapState>((ref) {
  return AppBootstrapNotifier(
    eventService: ref.read(eventServiceProvider),
    ensureOrchestratorInitialized: () async {
      ref.read(eventOrchestratorProvider);
    },
  );
});
