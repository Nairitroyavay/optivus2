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
    final signedEndpoint = _config.normalizedSignedUploadEndpoint;
    if (signedEndpoint.isEmpty) {
      throw StateError('Cloudflare R2 upload endpoint is not configured.');
    }

    final uid = _apiService.requireCurrentUid(
      endpointLabel: 'Cloudflare R2 signed upload endpoint',
    );
    final safeRoutineType = _safePathSegment(routineType);
    final timestamp = DateTime.now().toUtc().millisecondsSinceEpoch;
    final objectKey = 'users/$uid/uploads/$safeRoutineType/$timestamp.jpg';

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

    final uploadResponse = await _client.put(
      Uri.parse(uploadUrl),
      headers: {'Content-Type': contentType},
      body: bytes,
    );
    if (uploadResponse.statusCode < 200 || uploadResponse.statusCode >= 300) {
      throw StateError('Cloudflare R2 upload failed.');
    }

    final returnedKey = body['objectKey']?.toString() ?? objectKey;
    return {
      'path': returnedKey,
      'objectKey': returnedKey,
      'sizeBytes': bytes.length,
      'mimeType': contentType,
      if ((body['publicUrl']?.toString() ?? '').isNotEmpty)
        'url': body['publicUrl'].toString(),
      'provider': 'cloudflare_r2',
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
}
