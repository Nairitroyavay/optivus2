import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class CloudflareApiException implements Exception {
  final String endpointLabel;
  final String message;
  final int? statusCode;
  final String? responseBody;

  const CloudflareApiException({
    required this.endpointLabel,
    required this.message,
    this.statusCode,
    this.responseBody,
  });

  @override
  String toString() {
    final status = statusCode == null ? '' : ' ($statusCode)';
    return '$runtimeType$status: $message';
  }
}

class CloudflareConfigException extends CloudflareApiException {
  const CloudflareConfigException({
    required super.endpointLabel,
    required super.message,
  });
}

class CloudflareAuthException extends CloudflareApiException {
  const CloudflareAuthException({
    required super.endpointLabel,
    required super.message,
    super.statusCode,
    super.responseBody,
  });
}

class CloudflareRateLimitException extends CloudflareApiException {
  const CloudflareRateLimitException({
    required super.endpointLabel,
    required super.message,
    required super.statusCode,
    super.responseBody,
  });
}

class CloudflareServerException extends CloudflareApiException {
  const CloudflareServerException({
    required super.endpointLabel,
    required super.message,
    required super.statusCode,
    super.responseBody,
  });
}

class CloudflareHttpException extends CloudflareApiException {
  const CloudflareHttpException({
    required super.endpointLabel,
    required super.message,
    required super.statusCode,
    super.responseBody,
  });
}

class CloudflareTimeoutException extends CloudflareApiException {
  const CloudflareTimeoutException({
    required super.endpointLabel,
    required super.message,
  });
}

class CloudflareNetworkException extends CloudflareApiException {
  const CloudflareNetworkException({
    required super.endpointLabel,
    required super.message,
  });
}

class CloudflareInvalidJsonException extends CloudflareApiException {
  const CloudflareInvalidJsonException({
    required super.endpointLabel,
    required super.message,
    super.statusCode,
    super.responseBody,
  });
}

class CloudflareApiService {
  final FirebaseAuth? _auth;
  final http.Client _client;
  final Duration _timeout;

  CloudflareApiService({
    FirebaseAuth? auth,
    http.Client? client,
    Duration timeout = const Duration(seconds: 15),
  })  : _auth = auth,
        _client = client ?? http.Client(),
        _timeout = timeout;

  FirebaseAuth get _resolvedAuth => _auth ?? FirebaseAuth.instance;

  String requireCurrentUid({required String endpointLabel}) {
    final uid = _resolvedAuth.currentUser?.uid;
    if (uid == null || uid.trim().isEmpty) {
      throw CloudflareAuthException(
        endpointLabel: endpointLabel,
        message: 'Cannot call $endpointLabel without a signed-in user.',
      );
    }
    return uid;
  }

  Future<Map<String, dynamic>> postJson({
    required String endpoint,
    required String endpointLabel,
    required Map<String, dynamic> payload,
    String? missingEndpointMessage,
  }) async {
    final normalizedEndpoint = endpoint.trim();
    if (normalizedEndpoint.isEmpty) {
      throw CloudflareConfigException(
        endpointLabel: endpointLabel,
        message: missingEndpointMessage ??
            '$endpointLabel endpoint is not configured.',
      );
    }

    final token = await _firebaseIdToken(endpointLabel);
    late http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse(normalizedEndpoint),
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw CloudflareTimeoutException(
        endpointLabel: endpointLabel,
        message: '$endpointLabel timed out.',
      );
    } on CloudflareApiException {
      rethrow;
    } catch (error) {
      throw CloudflareNetworkException(
        endpointLabel: endpointLabel,
        message: '$endpointLabel network request failed: $error',
      );
    }

    _throwForStatus(endpointLabel, response);
    return _decodeJsonMap(endpointLabel, response);
  }

  Future<String> _firebaseIdToken(String endpointLabel) async {
    final user = _resolvedAuth.currentUser;
    if (user == null) {
      throw CloudflareAuthException(
        endpointLabel: endpointLabel,
        message: 'Cannot call $endpointLabel without a signed-in user.',
      );
    }

    final token = await user.getIdToken();
    if (token == null || token.trim().isEmpty) {
      throw CloudflareAuthException(
        endpointLabel: endpointLabel,
        message: 'Cannot call $endpointLabel without a Firebase ID token.',
      );
    }
    return token;
  }

  static Map<String, dynamic> _decodeJsonMap(
    String endpointLabel,
    http.Response response,
  ) {
    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw CloudflareInvalidJsonException(
        endpointLabel: endpointLabel,
        statusCode: response.statusCode,
        responseBody: response.body,
        message: '$endpointLabel returned malformed JSON.',
      );
    }
    if (decoded is! Map) {
      throw CloudflareInvalidJsonException(
        endpointLabel: endpointLabel,
        statusCode: response.statusCode,
        responseBody: response.body,
        message: '$endpointLabel returned invalid JSON.',
      );
    }
    return Map<String, dynamic>.from(decoded);
  }

  static void _throwForStatus(String endpointLabel, http.Response response) {
    final statusCode = response.statusCode;
    if (statusCode >= 200 && statusCode < 300) return;

    final message = '$endpointLabel failed with HTTP $statusCode.';
    if (statusCode == 401 || statusCode == 403) {
      throw CloudflareAuthException(
        endpointLabel: endpointLabel,
        statusCode: statusCode,
        responseBody: response.body,
        message: message,
      );
    }
    if (statusCode == 429) {
      throw CloudflareRateLimitException(
        endpointLabel: endpointLabel,
        statusCode: statusCode,
        responseBody: response.body,
        message: message,
      );
    }
    if (statusCode >= 500) {
      throw CloudflareServerException(
        endpointLabel: endpointLabel,
        statusCode: statusCode,
        responseBody: response.body,
        message: message,
      );
    }
    throw CloudflareHttpException(
      endpointLabel: endpointLabel,
      statusCode: statusCode,
      responseBody: response.body,
      message: message,
    );
  }
}
