import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:optivus2/core/config/feature_flags.dart';
import 'package:optivus2/services/r2_upload_service.dart';

class ImageUploadService {
  static const int maxUploadBytes = 1000 * 1000;
  static const String jpegMimeType = 'image/jpeg';

  final FirebaseAuth _auth;
  final R2UploadService _r2UploadService;
  final ImagePicker _imagePicker;

  ImageUploadService({
    FirebaseAuth? auth,
    R2UploadService? r2UploadService,
    ImagePicker? imagePicker,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _r2UploadService = r2UploadService ?? R2UploadService(auth: auth),
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
    _requireUid();
    if (!FeatureFlags.enableR2Uploads) {
      throw StateError('Image uploads are coming soon.');
    }
    final originalBytes = await pickedFile.readAsBytes();
    final compressedBytes = await compressToJpegUnderLimit(originalBytes);
    return _r2UploadService.uploadBytes(
      bytes: compressedBytes,
      routineType: routineType,
      contentType: jpegMimeType,
    );
  }

  Future<Uint8List> compressToJpegUnderLimit(Uint8List bytes) {
    return compute(_compressJpegUnderLimit, bytes);
  }

  Future<void> deleteUpload(String path) async {
    _requireUid();
    await _r2UploadService.deleteUploadedMetadata({'path': path});
  }

  Future<void> deleteUploadedMetadata(Map<String, dynamic>? metadata) async {
    _requireUid();
    await _r2UploadService.deleteUploadedMetadata(metadata);
  }

  String _requireUid() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('A signed-in user is required to upload images.');
    }
    return uid;
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
