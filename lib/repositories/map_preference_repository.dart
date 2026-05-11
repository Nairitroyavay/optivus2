import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:optivus2/models/map_style_model.dart';
import 'package:optivus2/services/firestore_service.dart';

class MapPreferenceRepository {
  final FirestoreService _service;

  MapPreferenceRepository(this._service);

  DocumentReference<Map<String, dynamic>> get _mapSettingsRef =>
      _service.userSubdocument(
        FirestoreService.kSettings,
        FirestoreService.kMapSettingsDoc,
      );

  Stream<MapboxStyle> watchSelectedStyle() {
    try {
      _service.uid;
    } catch (_) {
      return Stream.value(MapboxStyles.defaultStyle);
    }

    return _mapSettingsRef.snapshots().map((snap) {
      if (!snap.exists) return MapboxStyles.defaultStyle;
      return MapboxStyles.byStorageId(
          snap.data()?['selectedStyleId'] as String?);
    }).handleError((_) => MapboxStyles.defaultStyle);
  }

  Future<MapboxStyle> getSelectedStyle() async {
    try {
      _service.uid;
    } catch (_) {
      return MapboxStyles.defaultStyle;
    }

    final doc = await _mapSettingsRef.get();
    if (!doc.exists) return MapboxStyles.defaultStyle;
    return MapboxStyles.byStorageId(doc.data()?['selectedStyleId'] as String?);
  }

  Future<void> saveSelectedStyle(MapboxStyle style) async {
    final data = style.toPreferenceMap(updatedAt: FieldValue.serverTimestamp());
    await _mapSettingsRef.set(data, SetOptions(merge: true));
  }
}
