import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:optivus2/models/screen_time_log_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ScreenTimeBridge
//
// Thin typed wrapper around the native MethodChannel.
// All public methods are no-ops (return null / false) on non-Android platforms
// so no #ifdef guards are needed at the call-site.
// ─────────────────────────────────────────────────────────────────────────────

class ScreenTimeBridge {
  static const _channel = MethodChannel('com.example.optivus/screen_time');

  // ── Permission ─────────────────────────────────────────────────────────────

  /// Returns true when the PACKAGE_USAGE_STATS special permission is granted.
  /// Always false on non-Android platforms.
  Future<bool> hasPermission() async {
    if (!Platform.isAndroid) return false;
    try {
      final result = await _channel.invokeMethod<bool>('hasPermission');
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('[ScreenTimeBridge] hasPermission error: $e');
      return false;
    }
  }

  /// Opens the system "Usage access" settings page.
  /// No-op on non-Android platforms.
  Future<void> requestPermission() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('requestPermission');
    } on PlatformException catch (e) {
      debugPrint('[ScreenTimeBridge] requestPermission error: $e');
    }
  }

  // ── Query ──────────────────────────────────────────────────────────────────

  /// Queries today's usage stats and returns a typed snapshot.
  ///
  /// Returns null when:
  ///   - The platform is not Android
  ///   - The permission has not been granted
  ///   - The native side throws for any other reason
  Future<ScreenTimeSnapshot?> queryToday() async {
    if (!Platform.isAndroid) return null;
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>('query');
      if (raw == null) return null;
      return ScreenTimeSnapshot.fromMap(raw);
    } on PlatformException catch (e) {
      debugPrint(
          '[ScreenTimeBridge] queryToday error: ${e.code} – ${e.message}');
      return null;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ScreenTimeSnapshot — raw result from the native layer (before Firestore mapping)
// ─────────────────────────────────────────────────────────────────────────────

class ScreenTimeSnapshot {
  final int totalMinutes;
  final int unlockCount;
  final List<AppUsage> topApps;
  final int schemaVersion;

  /// Epoch milliseconds — when the device produced the snapshot.
  final int capturedAtMs;

  const ScreenTimeSnapshot({
    required this.totalMinutes,
    required this.unlockCount,
    required this.topApps,
    required this.capturedAtMs,
    this.schemaVersion = 1,
  });

  factory ScreenTimeSnapshot.fromMap(Map<String, dynamic> map) {
    final rawApps = map['topApps'];
    final apps = <AppUsage>[];
    if (rawApps is List) {
      for (final item in rawApps) {
        if (item is Map) {
          apps.add(AppUsage.fromMap(Map<String, dynamic>.from(item)));
        }
      }
    }
    return ScreenTimeSnapshot(
      totalMinutes: (map['totalMinutes'] as num?)?.toInt() ?? 0,
      unlockCount: (map['unlockCount'] as num?)?.toInt() ?? 0,
      topApps: apps,
      capturedAtMs: (map['capturedAt'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
      schemaVersion: (map['schemaVersion'] as num?)?.toInt() ?? 1,
    );
  }

  DateTime get capturedAt => DateTime.fromMillisecondsSinceEpoch(capturedAtMs);
}
