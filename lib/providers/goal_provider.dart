import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers.dart';
import '../models/goal_model.dart';
import '../repositories/goal_repository.dart';

final goalRepositoryProvider = Provider<GoalRepository>((ref) {
  return GoalRepository(
    ref.read(firestoreServiceProvider),
    eventService: ref.read(eventServiceProvider),
  );
});

final goalProvider = StreamProvider<List<GoalModel>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) {
    return Stream.value([]);
  }

  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('goals')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) {
    return snapshot.docs
        .map((doc) => GoalModel.fromFirestore(doc))
        .where((goal) => goal.status != GoalStatus.archived)
        .toList();
  });
});
