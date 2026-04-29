import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum BootstrapState { initializing, unauthenticated, needsOnboarding, ready }

class AppBootstrapNotifier extends StateNotifier<BootstrapState> {
  StreamSubscription<User?>? _authSubscription;

  AppBootstrapNotifier() : super(BootstrapState.initializing) {
    _init();
  }

  void _init() {
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user == null) {
        state = BootstrapState.unauthenticated;
      } else {
        try {
          final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
          if (!doc.exists) {
            state = BootstrapState.needsOnboarding;
          } else {
            final data = doc.data()!;
            final hasCompletedOnboarding = data['hasCompletedOnboarding'] as bool? ?? false;
            if (hasCompletedOnboarding) {
              state = BootstrapState.ready;
            } else {
              state = BootstrapState.needsOnboarding;
            }
          }
        } catch (e) {
          // If we fail to fetch, default to needsOnboarding or remain in initializing if we want to block.
          // We'll use needsOnboarding to allow the UI to handle it.
          state = BootstrapState.needsOnboarding;
        }
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}

final bootstrapProvider = StateNotifierProvider<AppBootstrapNotifier, BootstrapState>((ref) {
  return AppBootstrapNotifier();
});
