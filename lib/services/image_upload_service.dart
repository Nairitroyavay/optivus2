import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

class ImageUploadService {
  static const int maxUploadBytes = 1000 * 1000;
  static const String jpegMimeType = 'image/jpeg';

  final FirebaseAuth _auth;
  final FirebaseStorage _storage;
  final ImagePicker _imagePicker;

  ImageUploadService({
    FirebaseAuth? auth,
    FirebaseStorage? storage,
    ImagePicker? imagePicker,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _storage = storage ?? FirebaseStorage.instance,
        _imagePicker = imagePicker ?? ImagePicker();

  Future<XFile?> pickImage(ImageSource source) {
    return _imagePicker.pickImage(
      source: source,
      requestFullMetadata: false,
    );
  }

  Future<Map<String, dynamic>?> pickCompressAndUpload({
    required ImageSource source,
    required String routineType,
  }) async {
    final pickedFile = await pickImage(source);
    if (pickedFile == null) return null;

    return uploadPickedImage(
      pickedFile,
      routineType: routineType,
    );
  }

  Future<Map<String, dynamic>> uploadPickedImage(
    XFile pickedFile, {
    required String routineType,
  }) async {
    final uid = _requireUid();
    final originalBytes = await pickedFile.readAsBytes();
    final compressedBytes = await compressToJpegUnderLimit(originalBytes);
    final safeRoutineType = _safePathSegment(routineType);
    final timestamp = DateTime.now().toUtc().millisecondsSinceEpoch;
    final path = 'users/$uid/uploads/$safeRoutineType/$timestamp.jpg';
    final ref = _storage.ref().child(path);

    late final TaskSnapshot snapshot;
    late final String downloadUrl;
    try {
      snapshot = await ref.putData(
        compressedBytes,
        SettableMetadata(
          contentType: jpegMimeType,
          customMetadata: {
            'uid': uid,
            'routineType': safeRoutineType,
          },
        ),
      );
      downloadUrl = await snapshot.ref.getDownloadURL();
    } catch (_) {
      await _deleteIfPresent(ref);
      rethrow;
    }

    return {
      'path': snapshot.ref.fullPath,
      'sizeBytes': compressedBytes.length,
      'mimeType': jpegMimeType,
      'downloadUrl': downloadUrl,
    };
  }

  Future<Uint8List> compressToJpegUnderLimit(Uint8List bytes) {
    return compute(_compressJpegUnderLimit, bytes);
  }

  Future<void> deleteUpload(String path) async {
    final uid = _requireUid();
    final expectedPrefix = 'users/$uid/uploads/';
    if (!path.startsWith(expectedPrefix)) {
      throw ArgumentError.value(path, 'path', 'Upload is not owned by $uid.');
    }
    await _deleteIfPresent(_storage.ref().child(path));
  }

  Future<void> deleteUploadedMetadata(Map<String, dynamic>? metadata) async {
    final path = metadata?['path'];
    if (path is String && path.isNotEmpty) {
      await deleteUpload(path);
    }
  }

  String _requireUid() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('A signed-in user is required to upload images.');
    }
    return uid;
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

  static Future<void> _deleteIfPresent(Reference ref) async {
    try {
      await ref.delete();
    } on FirebaseException catch (e) {
      if (e.code != 'object-not-found') rethrow;
    }
  }
}

Uint8List _compressJpegUnderLimit(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw const FormatException('Unsupported image format.');
  }

  final oriented = img.bakeOrientation(decoded);
  final longestSide =
      oriented.width > oriented.height ? oriented.width : oriented.height;
  var targetLongestSide = longestSide > 1600 ? 1600 : longestSide;
  var quality = 88;
  var current = _resizeToLongestSide(oriented, targetLongestSide);

  for (var attempt = 0; attempt < 18; attempt++) {
    final encoded = Uint8List.fromList(img.encodeJpg(
      current,
      quality: quality,
    ));
    if (encoded.length < ImageUploadService.maxUploadBytes) {
      return encoded;
    }

    if (quality > 52) {
      quality -= 8;
      continue;
    }

    if (targetLongestSide > 640) {
      targetLongestSide =
          (targetLongestSide * 0.82).round().clamp(640, 1600).toInt();
      current = _resizeToLongestSide(oriented, targetLongestSide);
      quality = 82;
      continue;
    }

    if (quality > 32) {
      quality -= 5;
    }
  }

  throw StateError('Unable to compress image below 1 MB.');
}

img.Image _resizeToLongestSide(img.Image source, int targetLongestSide) {
  final longestSide =
      source.width > source.height ? source.width : source.height;
  if (longestSide <= targetLongestSide) return source;

  if (source.width >= source.height) {
    return img.copyResize(
      source,
      width: targetLongestSide,
      interpolation: img.Interpolation.average,
    );
  }

  return img.copyResize(
    source,
    height: targetLongestSide,
    interpolation: img.Interpolation.average,
  );
}
