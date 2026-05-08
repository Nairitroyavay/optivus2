import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class R2UploadService {
  static const String signedUploadEndpoint = String.fromEnvironment(
    'R2_SIGNED_UPLOAD_ENDPOINT',
  );
  static const String deleteUploadEndpoint = String.fromEnvironment(
    'R2_DELETE_UPLOAD_ENDPOINT',
  );

  final FirebaseAuth _auth;
  final http.Client _client;

  R2UploadService({
    FirebaseAuth? auth,
    http.Client? client,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _client = client ?? http.Client();

  Future<Map<String, dynamic>> uploadBytes({
    required Uint8List bytes,
    required String routineType,
    required String contentType,
  }) async {
    if (signedUploadEndpoint.trim().isEmpty) {
      throw StateError('Cloudflare R2 upload endpoint is not configured.');
    }

    final user = _auth.currentUser;
    final uid = user?.uid;
    if (user == null || uid == null) {
      throw StateError('A signed-in user is required to upload images.');
    }

    final token = await user.getIdToken();
    final safeRoutineType = _safePathSegment(routineType);
    final timestamp = DateTime.now().toUtc().millisecondsSinceEpoch;
    final objectKey = 'users/$uid/uploads/$safeRoutineType/$timestamp.jpg';

    final signedResponse = await _client.post(
      Uri.parse(signedUploadEndpoint),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'objectKey': objectKey,
        'contentType': contentType,
        'sizeBytes': bytes.length,
        'routineType': safeRoutineType,
      }),
    );
    if (signedResponse.statusCode < 200 || signedResponse.statusCode >= 300) {
      throw StateError('Cloudflare R2 signed upload request failed.');
    }

    final body = jsonDecode(signedResponse.body);
    if (body is! Map<String, dynamic>) {
      throw StateError('Cloudflare R2 signed upload response was invalid.');
    }

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
    if (objectKey.isEmpty || deleteUploadEndpoint.trim().isEmpty) return;

    final user = _auth.currentUser;
    if (user == null) return;
    final token = await user.getIdToken();
    await _client.post(
      Uri.parse(deleteUploadEndpoint),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'objectKey': objectKey}),
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
