import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/identity_profile_model.dart';

final identityProvider = StreamProvider<IdentityProfileModel?>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) {
    return Stream.value(null);
  }

  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('identity_profile')
      .doc('main')
      .snapshots()
      .map((doc) {
    if (doc.exists) {
      return IdentityProfileModel.fromFirestore(doc);
    }
    return null;
  });
});
