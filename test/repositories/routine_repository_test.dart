import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus2/repositories/routine_repository.dart';
import 'package:optivus2/services/firestore_service.dart';

void main() {
  test('saveRoutineTemplates strips transient image URLs before Firestore save',
      () async {
    const uid = 'uid_123';
    final firestore = FakeFirebaseFirestore();
    final auth = MockFirebaseAuth(
      mockUser: MockUser(uid: uid),
      signedIn: true,
    );
    final service = FirestoreService(db: firestore, auth: auth);
    final repository = RoutineRepository(service);

    await repository.saveRoutineTemplates(
      'eating',
      [
        {
          'templateId': 'breakfast',
          'title': 'Breakfast',
          'routineType': 'eating',
          'startTime': '08:00',
          'endTime': '08:30',
          'repeatRule': 'daily',
        },
      ],
      importMetadata: {
        'mode': 'eating_mess_photo',
        'imageMetadata': {
          'objectKey': 'users/$uid/uploads/eating/1715289300000.jpg',
          'path': 'users/$uid/uploads/eating/1715289300000.jpg',
          'storagePath': 'users/$uid/uploads/eating/1715289300000.jpg',
          'contentType': 'image/jpeg',
          'sizeBytes': 240000,
          'provider': 'cloudflare_r2',
          'downloadUrl': 'https://uploads.example/r2/photo.jpg',
          'url': 'https://uploads.example/r2/photo.jpg',
          'publicUrl': 'https://uploads.example/r2/photo.jpg',
          'uploadUrl': 'https://r2.example/signed-put',
          'base64': 'forbidden',
          'data': 'forbidden',
        },
      },
    );

    final snap = await firestore
        .collection('users')
        .doc(uid)
        .collection('routine')
        .doc('current')
        .get();
    final imports = snap.data()?['imports'] as Map;
    final eatingImport = imports['eating'] as Map;
    final imageMetadata = eatingImport['imageMetadata'] as Map;

    expect(imageMetadata['objectKey'],
        'users/$uid/uploads/eating/1715289300000.jpg');
    expect(imageMetadata['provider'], 'cloudflare_r2');
    expect(imageMetadata.containsKey('downloadUrl'), isFalse);
    expect(imageMetadata.containsKey('url'), isFalse);
    expect(imageMetadata.containsKey('publicUrl'), isFalse);
    expect(imageMetadata.containsKey('uploadUrl'), isFalse);
    expect(imageMetadata.containsKey('base64'), isFalse);
    expect(imageMetadata.containsKey('data'), isFalse);
  });
}
