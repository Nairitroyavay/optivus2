// lib/core/utils/device_id.dart
//
// Generates and persists a stable device ID on first launch.
// The ID appears in every event envelope (field: device_id)
// so we can distinguish events from the same user on different devices.

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

const _kDeviceIdKey = 'optivus_device_id';
const _uuid = Uuid();

/// Cached in-memory after first read.
String? _cachedDeviceId;

/// Returns a stable device ID. Creates one on first call and persists it.
Future<String> getDeviceId() async {
  if (_cachedDeviceId != null) return _cachedDeviceId!;

  final prefs = await SharedPreferences.getInstance();
  var id = prefs.getString(_kDeviceIdKey);
  if (id == null) {
    id = _uuid.v4();
    await prefs.setString(_kDeviceIdKey, id);
  }
  _cachedDeviceId = id;
  return id;
}
