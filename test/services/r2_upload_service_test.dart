import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:optivus2/core/config/app_config.dart';
import 'package:optivus2/services/image_upload_service.dart';
import 'package:optivus2/services/r2_upload_service.dart';

void main() {
  group('R2UploadService', () {
    test('signed upload success parses Worker response and extra fields',
        () async {
      final requests = <http.Request>[];
      final auth = MockFirebaseAuth(
        mockUser: MockUser(uid: 'uid_123'),
        signedIn: true,
      );
      final service = R2UploadService(
        auth: auth,
        config: _r2Config(),
        client: MockClient((request) async {
          requests.add(request);
          if (request.method == 'POST') {
            return http.Response(
              jsonEncode({
                'ok': true,
                'uploadUrl': 'https://r2.example/upload',
                'objectKey':
                    'users/uid_123/uploads/skin_care/1715289300000.jpg',
                'path': 'users/uid_123/uploads/skin_care/1715289300000.jpg',
                'contentType': 'image/jpeg',
                'sizeBytes': 3,
                'requiredHeaders': {
                  'Content-Type': 'image/jpeg',
                  'Content-Length': '3',
                },
                'ignoredExtraField': true,
                'publicUrl': 'https://cdn.example/not-stored.jpg',
              }),
              200,
            );
          }
          return http.Response('', 200);
        }),
      );

      final metadata = await service.uploadBytes(
        bytes: Uint8List.fromList([1, 2, 3]),
        routineType: 'skin care',
        contentType: ImageUploadService.jpegMimeType,
      );

      expect(metadata, {
        'objectKey': 'users/uid_123/uploads/skin_care/1715289300000.jpg',
        'path': 'users/uid_123/uploads/skin_care/1715289300000.jpg',
        'contentType': 'image/jpeg',
        'sizeBytes': 3,
        'provider': 'cloudflare_r2',
      });
      expect(metadata.containsKey('url'), isFalse);
      expect(metadata.containsKey('mimeType'), isFalse);
      expect(requests, hasLength(2));
    });

    test('upload request sends JPEG bytes with Worker-required headers',
        () async {
      late http.Request signedRequest;
      late http.Request putRequest;
      final bytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xD9]);
      final auth = MockFirebaseAuth(
        mockUser: MockUser(uid: 'uid_123'),
        signedIn: true,
      );
      final service = R2UploadService(
        auth: auth,
        config: _r2Config(),
        client: MockClient((request) async {
          if (request.method == 'POST') {
            signedRequest = request;
            return http.Response(
              jsonEncode({
                'uploadUrl': 'https://r2.example/upload',
                'objectKey': 'users/uid_123/uploads/classes/1715289300000.jpg',
                'path': 'users/uid_123/uploads/classes/1715289300000.jpg',
                'contentType': 'image/jpeg',
                'sizeBytes': bytes.length,
                'requiredHeaders': {
                  'Content-Type': 'image/jpeg',
                  'Content-Length': bytes.length.toString(),
                },
              }),
              200,
            );
          }
          putRequest = request;
          return http.Response('', 200);
        }),
      );

      await service.uploadBytes(
        bytes: bytes,
        routineType: 'classes',
        contentType: ImageUploadService.jpegMimeType,
      );

      final signedPayload = jsonDecode(signedRequest.body) as Map;
      expect(signedPayload['contentType'], 'image/jpeg');
      expect(signedPayload['sizeBytes'], bytes.length);
      expect(
        signedPayload['objectKey'],
        startsWith('users/uid_123/uploads/classes/'),
      );
      expect(putRequest.method, 'PUT');
      expect(putRequest.url.toString(), 'https://r2.example/upload');
      expect(putRequest.headers['Content-Type'], 'image/jpeg');
      expect(putRequest.headers['Content-Length'], bytes.length.toString());
      expect(putRequest.bodyBytes, bytes);
    });

    test('profile uploads use the Worker profile object path', () async {
      late http.Request signedRequest;
      final auth = MockFirebaseAuth(
        mockUser: MockUser(uid: 'uid_123'),
        signedIn: true,
      );
      final service = R2UploadService(
        auth: auth,
        config: _r2Config(),
        client: MockClient((request) async {
          if (request.method == 'POST') {
            signedRequest = request;
            return http.Response(
              jsonEncode({
                'uploadUrl': 'https://r2.example/upload',
                'objectKey': 'users/uid_123/profile/1715289300000.jpg',
                'path': 'users/uid_123/profile/1715289300000.jpg',
                'contentType': 'image/jpeg',
                'sizeBytes': 2,
                'requiredHeaders': {
                  'Content-Type': 'image/jpeg',
                  'Content-Length': '2',
                },
              }),
              200,
            );
          }
          return http.Response('', 200);
        }),
      );

      final metadata = await service.uploadProfileBytes(
        bytes: Uint8List.fromList([1, 2]),
        contentType: ImageUploadService.jpegMimeType,
      );

      final signedPayload = jsonDecode(signedRequest.body) as Map;
      expect(signedPayload['objectKey'], startsWith('users/uid_123/profile/'));
      expect(metadata['objectKey'], 'users/uid_123/profile/1715289300000.jpg');
    });

    test('delete cleanup success posts objectKey to Worker', () async {
      late http.Request deleteRequest;
      final auth = MockFirebaseAuth(
        mockUser: MockUser(uid: 'uid_123'),
        signedIn: true,
      );
      final service = R2UploadService(
        auth: auth,
        config: _r2Config(),
        client: MockClient((request) async {
          deleteRequest = request;
          return http.Response(
            jsonEncode({
              'ok': true,
              'deleted': true,
              'objectKey': 'users/uid_123/profile/1715289300000.jpg',
              'path': 'users/uid_123/profile/1715289300000.jpg',
            }),
            200,
          );
        }),
      );

      await service.deleteUploadedMetadata({
        'objectKey': 'users/uid_123/profile/1715289300000.jpg',
        'path': 'users/uid_123/profile/1715289300000.jpg',
      });

      expect(deleteRequest.method, 'POST');
      expect(deleteRequest.url.toString(), 'https://worker.example/delete');
      expect(jsonDecode(deleteRequest.body), {
        'objectKey': 'users/uid_123/profile/1715289300000.jpg',
      });
    });

    test('returned metadata contains no Firebase Storage URL or base64 data',
        () async {
      final auth = MockFirebaseAuth(
        mockUser: MockUser(uid: 'uid_123'),
        signedIn: true,
      );
      final service = R2UploadService(
        auth: auth,
        config: _r2Config(),
        client: MockClient((request) async {
          if (request.method == 'POST') {
            return http.Response(
              jsonEncode({
                'uploadUrl': 'https://r2.example/upload',
                'objectKey': 'users/uid_123/uploads/eating/1715289300000.jpg',
                'path': 'users/uid_123/uploads/eating/1715289300000.jpg',
                'contentType': 'image/jpeg',
                'sizeBytes': 3,
                'requiredHeaders': {
                  'Content-Type': 'image/jpeg',
                  'Content-Length': '3',
                },
                'publicUrl':
                    'https://firebasestorage.googleapis.com/forbidden.jpg',
                'base64': 'forbidden',
              }),
              200,
            );
          }
          return http.Response('', 200);
        }),
      );

      final metadata = await service.uploadBytes(
        bytes: Uint8List.fromList([1, 2, 3]),
        routineType: 'eating',
        contentType: ImageUploadService.jpegMimeType,
      );

      final encoded = jsonEncode(metadata);
      expect(encoded, isNot(contains('firebasestorage.googleapis.com')));
      expect(encoded, isNot(contains('storage.googleapis.com')));
      expect(encoded, isNot(contains('base64')));
      expect(
          metadata.keys,
          unorderedEquals([
            'objectKey',
            'path',
            'contentType',
            'sizeBytes',
            'provider',
          ]));
    });
  });

  group('ImageUploadService', () {
    test('upload disabled returns safe failure before reading image bytes',
        () async {
      final service = ImageUploadService(
        auth: MockFirebaseAuth(
          mockUser: MockUser(uid: 'uid_123'),
          signedIn: true,
        ),
        featureFlags: AppFeatureFlags.defaults(),
      );

      await expectLater(
        service.uploadPickedImage(
          XFile.fromData(Uint8List.fromList([1, 2, 3])),
          routineType: 'skin_care',
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'Image uploads are coming soon.',
          ),
        ),
      );
    });

    test('delete cleanup failure is non-fatal', () async {
      final service = ImageUploadService(
        auth: MockFirebaseAuth(
          mockUser: MockUser(uid: 'uid_123'),
          signedIn: true,
        ),
        r2UploadService: _ThrowingDeleteR2UploadService(),
        featureFlags: AppFeatureFlags.defaults(),
      );

      await service.deleteUploadedMetadata({
        'objectKey': 'users/uid_123/profile/1715289300000.jpg',
      });
    });
  });
}

R2EndpointConfig _r2Config() => const R2EndpointConfig(
      signedUploadEndpoint: 'https://worker.example/sign',
      deleteUploadEndpoint: 'https://worker.example/delete',
    );

class _ThrowingDeleteR2UploadService extends R2UploadService {
  _ThrowingDeleteR2UploadService()
      : super(
          auth: MockFirebaseAuth(
            mockUser: MockUser(uid: 'uid_123'),
            signedIn: true,
          ),
          config: _r2Config(),
          client: MockClient((_) async => http.Response('', 500)),
        );

  @override
  Future<void> deleteUploadedMetadata(Map<String, dynamic>? metadata) async {
    throw StateError('delete failed');
  }
}
