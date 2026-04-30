import 'package:cloud_firestore/cloud_firestore.dart';

class IdentityProfileModel {
  final List<String> identities;
  final int progressPct;
  final DateTime lastComputedAt;
  final int schemaVersion;

  const IdentityProfileModel({
    this.identities = const [],
    this.progressPct = 0,
    required this.lastComputedAt,
    this.schemaVersion = 1,
  });

  factory IdentityProfileModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return IdentityProfileModel(
      identities: List<String>.from(data['identities'] as List? ?? []),
      progressPct: data['progressPct'] as int? ?? 0,
      lastComputedAt: data['lastComputedAt'] != null
          ? (data['lastComputedAt'] is Timestamp
              ? (data['lastComputedAt'] as Timestamp).toDate()
              : DateTime.now())
          : DateTime.now(),
      schemaVersion: data['schemaVersion'] as int? ?? 1,
    );
  }

  factory IdentityProfileModel.fromMap(Map<String, dynamic> map) {
    return IdentityProfileModel(
      identities: List<String>.from(map['identities'] as List? ?? []),
      progressPct: map['progressPct'] as int? ?? 0,
      lastComputedAt: map['lastComputedAt'] != null
          ? (map['lastComputedAt'] is Timestamp
              ? (map['lastComputedAt'] as Timestamp).toDate()
              : DateTime.now())
          : DateTime.now(),
      schemaVersion: map['schemaVersion'] as int? ?? 1,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'identities': identities,
      'progressPct': progressPct,
      'lastComputedAt': Timestamp.fromDate(lastComputedAt),
      'schemaVersion': schemaVersion,
    };
  }

  Map<String, dynamic> toMap() => toFirestore();
}
