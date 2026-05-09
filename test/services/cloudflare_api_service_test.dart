import 'dart:convert';

import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:optivus2/services/cloudflare_api_service.dart';

void main() {
  group('CloudflareApiService.postJson', () {
    test('sends Firebase ID token authorization and JSON headers', () async {
      late http.Request captured;
      final auth = MockFirebaseAuth(
        mockUser: MockUser(uid: 'uid_123'),
        signedIn: true,
      );
      final service = CloudflareApiService(
        auth: auth,
        client: MockClient((request) async {
          captured = request;
          return http.Response('{"ok":true}', 200);
        }),
      );

      final response = await service.postJson(
        endpoint: 'https://worker.example/api',
        endpointLabel: 'Test Worker',
        payload: {'hello': 'world'},
      );

      expect(response['ok'], isTrue);
      expect(captured.method, 'POST');
      expect(captured.url.toString(), 'https://worker.example/api');
      expect(captured.headers['Authorization'], startsWith('Bearer '));
      expect(captured.headers['Content-Type'], 'application/json');
      expect(captured.headers['Accept'], 'application/json');
      expect(jsonDecode(captured.body), {'hello': 'world'});
    });

    test('throws config error when endpoint is missing', () async {
      final service = CloudflareApiService(
        auth: MockFirebaseAuth(
          mockUser: MockUser(uid: 'uid_123'),
          signedIn: true,
        ),
        client: MockClient((_) async => http.Response('{}', 200)),
      );

      await expectLater(
        service.postJson(
          endpoint: ' ',
          endpointLabel: 'Missing Worker',
          payload: const {},
          missingEndpointMessage: 'MISSING_ENDPOINT is not configured.',
        ),
        throwsA(isA<CloudflareConfigException>()),
      );
    });

    test('throws auth error when no user is signed in', () async {
      final service = CloudflareApiService(
        auth: MockFirebaseAuth(signedIn: false),
        client: MockClient((_) async => http.Response('{}', 200)),
      );

      await expectLater(
        service.postJson(
          endpoint: 'https://worker.example/api',
          endpointLabel: 'Auth Worker',
          payload: const {},
        ),
        throwsA(isA<CloudflareAuthException>()),
      );
    });

    test('throws invalid JSON error when response is not an object', () async {
      final service = _serviceForStatus(200, '[1,2,3]');

      await expectLater(
        service.postJson(
          endpoint: 'https://worker.example/api',
          endpointLabel: 'JSON Worker',
          payload: const {},
        ),
        throwsA(isA<CloudflareInvalidJsonException>()),
      );
    });

    test('throws invalid JSON error when response is malformed', () async {
      final service = _serviceForStatus(200, 'not json');

      await expectLater(
        service.postJson(
          endpoint: 'https://worker.example/api',
          endpointLabel: 'Malformed Worker',
          payload: const {},
        ),
        throwsA(isA<CloudflareInvalidJsonException>()),
      );
    });

    test('maps 401 and 403 to auth errors', () async {
      for (final statusCode in [401, 403]) {
        final service = _serviceForStatus(statusCode, '{"error":"denied"}');

        await expectLater(
          service.postJson(
            endpoint: 'https://worker.example/api',
            endpointLabel: 'Auth Status Worker',
            payload: const {},
          ),
          throwsA(isA<CloudflareAuthException>()),
        );
      }
    });

    test('maps 429 to rate limit error', () async {
      final service = _serviceForStatus(429, '{"error":"slow down"}');

      await expectLater(
        service.postJson(
          endpoint: 'https://worker.example/api',
          endpointLabel: 'Rate Worker',
          payload: const {},
        ),
        throwsA(isA<CloudflareRateLimitException>()),
      );
    });

    test('maps 500-class responses to server errors', () async {
      final service = _serviceForStatus(500, '{"error":"boom"}');

      await expectLater(
        service.postJson(
          endpoint: 'https://worker.example/api',
          endpointLabel: 'Server Worker',
          payload: const {},
        ),
        throwsA(isA<CloudflareServerException>()),
      );
    });

    test('maps other non-success responses to HTTP errors', () async {
      final service = _serviceForStatus(400, '{"error":"bad request"}');

      await expectLater(
        service.postJson(
          endpoint: 'https://worker.example/api',
          endpointLabel: 'HTTP Worker',
          payload: const {},
        ),
        throwsA(isA<CloudflareHttpException>()),
      );
    });

    test('throws timeout error when request exceeds timeout', () async {
      final service = CloudflareApiService(
        auth: MockFirebaseAuth(
          mockUser: MockUser(uid: 'uid_123'),
          signedIn: true,
        ),
        timeout: const Duration(milliseconds: 10),
        client: MockClient((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 100));
          return http.Response('{}', 200);
        }),
      );

      await expectLater(
        service.postJson(
          endpoint: 'https://worker.example/api',
          endpointLabel: 'Slow Worker',
          payload: const {},
        ),
        throwsA(isA<CloudflareTimeoutException>()),
      );
    });

    test('throws network error when HTTP client fails', () async {
      final service = CloudflareApiService(
        auth: MockFirebaseAuth(
          mockUser: MockUser(uid: 'uid_123'),
          signedIn: true,
        ),
        client: MockClient((_) async {
          throw http.ClientException('connection failed');
        }),
      );

      await expectLater(
        service.postJson(
          endpoint: 'https://worker.example/api',
          endpointLabel: 'Network Worker',
          payload: const {},
        ),
        throwsA(isA<CloudflareNetworkException>()),
      );
    });
  });
}

CloudflareApiService _serviceForStatus(int statusCode, String body) {
  return CloudflareApiService(
    auth: MockFirebaseAuth(
      mockUser: MockUser(uid: 'uid_123'),
      signedIn: true,
    ),
    client: MockClient((_) async => http.Response(body, statusCode)),
  );
}
