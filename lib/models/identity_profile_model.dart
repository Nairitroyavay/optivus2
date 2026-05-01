import 'package:cloud_firestore/cloud_firestore.dart';

class IdentityProfileModel {
  final List<String> identities;
  final int progressPct;
  final DateTime lastComputedAt;
  final Map<String, dynamic> biometrics;
  final Map<String, dynamic> lifestyle;
  final Map<String, dynamic> sensitiveContext;
  final int schemaVersion;

  const IdentityProfileModel({
    this.identities = const [],
    this.progressPct = 0,
    required this.lastComputedAt,
    this.biometrics = const {},
    this.lifestyle = const {},
    this.sensitiveContext = const {},
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
      biometrics: data['biometrics'] is Map
          ? Map<String, dynamic>.from(data['biometrics'] as Map)
          : const {},
      lifestyle: data['lifestyle'] is Map
          ? Map<String, dynamic>.from(data['lifestyle'] as Map)
          : const {},
      sensitiveContext: data['sensitiveContext'] is Map
          ? Map<String, dynamic>.from(data['sensitiveContext'] as Map)
          : const {},
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
      biometrics: map['biometrics'] is Map
          ? Map<String, dynamic>.from(map['biometrics'] as Map)
          : const {},
      lifestyle: map['lifestyle'] is Map
          ? Map<String, dynamic>.from(map['lifestyle'] as Map)
          : const {},
      sensitiveContext: map['sensitiveContext'] is Map
          ? Map<String, dynamic>.from(map['sensitiveContext'] as Map)
          : const {},
      schemaVersion: map['schemaVersion'] as int? ?? 1,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'identities': identities,
      'progressPct': progressPct,
      'lastComputedAt': Timestamp.fromDate(lastComputedAt),
      'biometrics': biometrics,
      'lifestyle': lifestyle,
      'sensitiveContext': sensitiveContext,
      'schemaVersion': schemaVersion,
    };
  }

  Map<String, dynamic> toMap() => toFirestore();
}
