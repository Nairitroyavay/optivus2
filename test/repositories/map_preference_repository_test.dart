import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus2/core/providers.dart';
import 'package:optivus2/models/map_style_model.dart';
import 'package:optivus2/repositories/map_preference_repository.dart';
import 'package:optivus2/services/firestore_service.dart';

void main() {
  const uid = 'uid_map';

  FirestoreService serviceFor(FakeFirebaseFirestore db, MockFirebaseAuth auth) {
    return FirestoreService(db: db, auth: auth);
  }

  group('MapPreferenceRepository', () {
    test('returns Coral when preference doc is missing', () async {
      final db = FakeFirebaseFirestore();
      final auth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: uid),
      );
      final repo = MapPreferenceRepository(serviceFor(db, auth));

      expect(await repo.getSelectedStyle(), MapboxStyles.coral);
    });

    test('invalid style id falls back to Coral', () async {
      final db = FakeFirebaseFirestore();
      final auth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: uid),
      );
      await db
          .collection('users')
          .doc(uid)
          .collection(FirestoreService.kSettings)
          .doc(FirestoreService.kMapSettingsDoc)
          .set({
        'selectedStyleId': 'invalid',
        'selectedStyleUri': 'mapbox://styles/example/invalid',
      });

      final repo = MapPreferenceRepository(serviceFor(db, auth));

      expect(await repo.getSelectedStyle(), MapboxStyles.coral);
    });

    test('persists selected style to /users/{uid}/settings/map', () async {
      final db = FakeFirebaseFirestore();
      final auth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: uid),
      );
      final repo = MapPreferenceRepository(serviceFor(db, auth));

      await repo.saveSelectedStyle(MapboxStyles.satellite);

      final doc = await db
          .collection('users')
          .doc(uid)
          .collection(FirestoreService.kSettings)
          .doc(FirestoreService.kMapSettingsDoc)
          .get();
      final data = doc.data()!;
      expect(data['selectedStyleId'], 'satellite');
      expect(data['selectedStyleUri'], MapboxStyles.satellite.styleUri);
      expect(data.keys, isNot(contains('accessToken')));
      expect(data.toString(), isNot(contains('MAPBOX_ACCESS_TOKEN')));
      expect(data.toString(), isNot(contains('pk.')));
    });

    test('watchSelectedStyle returns saved style', () async {
      final db = FakeFirebaseFirestore();
      final auth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: uid),
      );
      final repo = MapPreferenceRepository(serviceFor(db, auth));
      await repo.saveSelectedStyle(MapboxStyles.energy);

      expect(await repo.watchSelectedStyle().first, MapboxStyles.energy);
    });

    test('signed-out reads return Coral and do not crash', () async {
      final db = FakeFirebaseFirestore();
      final auth = MockFirebaseAuth(signedIn: false);
      final repo = MapPreferenceRepository(serviceFor(db, auth));

      expect(await repo.getSelectedStyle(), MapboxStyles.coral);
      expect(await repo.watchSelectedStyle().first, MapboxStyles.coral);
    });
  });

  group('selectedMapboxStyleProvider', () {
    test('returns saved style through repository provider', () async {
      final db = FakeFirebaseFirestore();
      final auth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: uid),
      );
      final service = serviceFor(db, auth);
      final repo = MapPreferenceRepository(service);
      await repo.saveSelectedStyle(MapboxStyles.monoLight);

      final container = ProviderContainer(
        overrides: [
          firestoreServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(container.dispose);

      expect(
        await container.read(selectedMapboxStyleProvider.future),
        MapboxStyles.monoLight,
      );
    });
  });
}
