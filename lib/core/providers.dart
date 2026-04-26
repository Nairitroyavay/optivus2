import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus2/services/firestore_service.dart';
import 'package:optivus2/repositories/user_repository.dart';
import 'package:optivus2/repositories/routine_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CENTRAL DI — Single source of truth for service & repository providers
// ─────────────────────────────────────────────────────────────────────────────

/// Wraps Firebase instances — never access Firebase directly outside this.
final firestoreServiceProvider = Provider<FirestoreService>(
  (_) => FirestoreService(),
);

/// User profile + onboarding persistence.
final userRepositoryProvider = Provider<UserRepository>(
  (ref) => UserRepository(ref.read(firestoreServiceProvider)),
);

/// Routine state persistence (save / load RoutineState).
final routineRepositoryProvider = Provider<RoutineRepository>(
  (ref) => RoutineRepository(ref.read(firestoreServiceProvider)),
);
