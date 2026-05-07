// lib/models/fitness_permission_state_model.dart
//
// In-memory permission state for fitness pre-start flow.
// Phase 1: stub values only. Phase 2 will wire to actual platform APIs.

enum GpsSignalStrength { none, weak, good, strong }

extension GpsSignalStrengthCodec on GpsSignalStrength {
  String toJson() => name;

  static GpsSignalStrength fromString(String? value) {
    switch (value) {
      case 'weak':
        return GpsSignalStrength.weak;
      case 'good':
        return GpsSignalStrength.good;
      case 'strong':
        return GpsSignalStrength.strong;
      default:
        return GpsSignalStrength.none;
    }
  }
}

class FitnessPermissionStateModel {
  final bool locationGranted;
  final bool locationAlwaysGranted;
  final bool motionGranted;
  final bool healthGranted;
  final bool bluetoothGranted;
  final GpsSignalStrength gpsSignalStrength;

  const FitnessPermissionStateModel({
    this.locationGranted = false,
    this.locationAlwaysGranted = false,
    this.motionGranted = false,
    this.healthGranted = false,
    this.bluetoothGranted = false,
    this.gpsSignalStrength = GpsSignalStrength.none,
  });

  /// Phase 1 stub: GPS activities show "not ready", non-GPS show "ready".
  factory FitnessPermissionStateModel.stub() {
    return const FitnessPermissionStateModel();
  }

  factory FitnessPermissionStateModel.fromMap(Map<String, dynamic> map) {
    return FitnessPermissionStateModel(
      locationGranted: map['locationGranted'] as bool? ?? false,
      locationAlwaysGranted: map['locationAlwaysGranted'] as bool? ?? false,
      motionGranted: map['motionGranted'] as bool? ?? false,
      healthGranted: map['healthGranted'] as bool? ?? false,
      bluetoothGranted: map['bluetoothGranted'] as bool? ?? false,
      gpsSignalStrength: GpsSignalStrengthCodec.fromString(
        map['gpsSignalStrength'] as String?,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'locationGranted': locationGranted,
      'locationAlwaysGranted': locationAlwaysGranted,
      'motionGranted': motionGranted,
      'healthGranted': healthGranted,
      'bluetoothGranted': bluetoothGranted,
      'gpsSignalStrength': gpsSignalStrength.toJson(),
      'isGpsReady': isGpsReady,
      'isNonGpsReady': isNonGpsReady,
    };
  }

  /// Returns true if all required permissions for a GPS activity are granted.
  bool get isGpsReady =>
      locationGranted && gpsSignalStrength != GpsSignalStrength.none;

  /// Returns true if non-GPS activities can start (always true in Phase 1).
  bool get isNonGpsReady => true;

  FitnessPermissionStateModel copyWith({
    bool? locationGranted,
    bool? locationAlwaysGranted,
    bool? motionGranted,
    bool? healthGranted,
    bool? bluetoothGranted,
    GpsSignalStrength? gpsSignalStrength,
  }) {
    return FitnessPermissionStateModel(
      locationGranted: locationGranted ?? this.locationGranted,
      locationAlwaysGranted:
          locationAlwaysGranted ?? this.locationAlwaysGranted,
      motionGranted: motionGranted ?? this.motionGranted,
      healthGranted: healthGranted ?? this.healthGranted,
      bluetoothGranted: bluetoothGranted ?? this.bluetoothGranted,
      gpsSignalStrength: gpsSignalStrength ?? this.gpsSignalStrength,
    );
  }
}
