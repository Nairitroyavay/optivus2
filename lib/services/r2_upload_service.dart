import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:optivus2/core/config/app_config.dart';
import 'package:optivus2/services/cloudflare_api_service.dart';

class R2UploadService {
  final FirebaseAuth? _auth;
  final http.Client _client;
  final R2EndpointConfig _config;
  final CloudflareApiService _apiService;

  R2UploadService({
    FirebaseAuth? auth,
    http.Client? client,
    R2EndpointConfig? config,
    CloudflareApiService? apiService,
  })  : _auth = auth,
        _client = client ?? http.Client(),
        _config = config ?? AppBuildConfig.current.r2,
        _apiService = apiService ??
            CloudflareApiService(
              auth: auth,
              client: client,
            );

  static String get signedUploadEndpoint =>
      AppBuildConfig.current.r2.normalizedSignedUploadEndpoint;

  static String get deleteUploadEndpoint =>
      AppBuildConfig.current.r2.normalizedDeleteUploadEndpoint;

  Future<Map<String, dynamic>> uploadBytes({
    required Uint8List bytes,
    required String routineType,
    required String contentType,
  }) async {
    final uid = _apiService.requireCurrentUid(
      endpointLabel: 'Cloudflare R2 signed upload endpoint',
    );
    final objectKey = _objectKeyFor(
      uid: uid,
      routineType: routineType,
    );

    return _uploadBytesToObjectKey(
      bytes: bytes,
      objectKey: objectKey,
      routineType: routineType,
      contentType: contentType,
    );
  }

  Future<Map<String, dynamic>> uploadProfileBytes({
    required Uint8List bytes,
    required String contentType,
  }) async {
    final uid = _apiService.requireCurrentUid(
      endpointLabel: 'Cloudflare R2 signed upload endpoint',
    );
    final timestamp = DateTime.now().toUtc().millisecondsSinceEpoch;
    return _uploadBytesToObjectKey(
      bytes: bytes,
      objectKey: 'users/$uid/profile/$timestamp.jpg',
      routineType: 'profile',
      contentType: contentType,
    );
  }

  Future<Map<String, dynamic>> _uploadBytesToObjectKey({
    required Uint8List bytes,
    required String objectKey,
    required String routineType,
    required String contentType,
  }) async {
    final signedEndpoint = _config.normalizedSignedUploadEndpoint;
    if (signedEndpoint.isEmpty) {
      throw StateError('Cloudflare R2 upload endpoint is not configured.');
    }

    final safeRoutineType = _safePathSegment(routineType);

    final body = await _apiService.postJson(
      endpoint: signedEndpoint,
      endpointLabel: 'Cloudflare R2 signed upload endpoint',
      payload: {
        'objectKey': objectKey,
        'contentType': contentType,
        'sizeBytes': bytes.length,
        'routineType': safeRoutineType,
      },
    );

    final uploadUrl = body['uploadUrl']?.toString() ?? '';
    if (uploadUrl.isEmpty) {
      throw StateError('Cloudflare R2 signed upload URL was missing.');
    }

    final returnedKey = body['objectKey']?.toString() ?? objectKey;
    final returnedPath = body['path']?.toString() ?? returnedKey;
    final returnedContentType = body['contentType']?.toString() ?? contentType;
    final returnedSizeBytes = _intField(body['sizeBytes']) ?? bytes.length;
    final downloadUrl = _safeDownloadUrl(body['downloadUrl']);
    final uploadHeaders = _requiredUploadHeaders(
      body['requiredHeaders'],
      contentType: returnedContentType,
      sizeBytes: returnedSizeBytes,
    );

    final uploadResponse = await _client.put(
      Uri.parse(uploadUrl),
      headers: uploadHeaders,
      body: bytes,
    );
    if (uploadResponse.statusCode < 200 || uploadResponse.statusCode >= 300) {
      throw StateError('Cloudflare R2 upload failed.');
    }

    return {
      'objectKey': returnedKey,
      'path': returnedPath,
      'contentType': returnedContentType,
      'sizeBytes': returnedSizeBytes,
      'provider': 'cloudflare_r2',
      if (downloadUrl != null) 'downloadUrl': downloadUrl,
    };
  }

  Future<void> deleteUploadedMetadata(Map<String, dynamic>? metadata) async {
    final objectKey = metadata?['objectKey']?.toString() ??
        metadata?['path']?.toString() ??
        '';
    final deleteEndpoint = _config.normalizedDeleteUploadEndpoint;
    if (objectKey.isEmpty || deleteEndpoint.isEmpty) return;

    if ((_auth?.currentUser ?? FirebaseAuth.instance.currentUser) == null) {
      return;
    }
    await _apiService.postJson(
      endpoint: deleteEndpoint,
      endpointLabel: 'Cloudflare R2 delete upload endpoint',
      payload: {'objectKey': objectKey},
    );
  }

  static String _safePathSegment(String value) {
    final normalized = value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return normalized.isEmpty ? 'routine' : normalized;
  }

  static String _objectKeyFor({
    required String uid,
    required String routineType,
  }) {
    final safeRoutineType = _safePathSegment(routineType);
    final timestamp = DateTime.now().toUtc().millisecondsSinceEpoch;
    return 'users/$uid/uploads/$safeRoutineType/$timestamp.jpg';
  }

  static Map<String, String> _requiredUploadHeaders(
    Object? value, {
    required String contentType,
    required int sizeBytes,
  }) {
    final headers = <String, String>{};
    if (value is Map) {
      for (final entry in value.entries) {
        final key = entry.key?.toString() ?? '';
        if (key.isEmpty) continue;
        headers[key] = entry.value?.toString() ?? '';
      }
    }
    headers.putIfAbsent('Content-Type', () => contentType);
    headers.putIfAbsent('Content-Length', () => sizeBytes.toString());
    return headers;
  }

  static int? _intField(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static String? _safeDownloadUrl(Object? value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;
    final host = uri.host.toLowerCase();
    if (host.endsWith('googleapis.com') ||
        host.endsWith('firebasestorage.app')) {
      return null;
    }
    return raw;
  }
}
