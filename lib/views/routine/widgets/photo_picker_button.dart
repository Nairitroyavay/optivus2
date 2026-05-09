import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/providers.dart';
import '../../../services/image_upload_service.dart';

class PhotoPickerButton extends ConsumerStatefulWidget {
  final String routineType;
  final Map<String, dynamic>? initialMetadata;
  final ValueChanged<Map<String, dynamic>?> onChanged;
  final ImageUploadService? uploadService;
  final String label;
  final bool enabled;
  final bool deleteOnClear;

  const PhotoPickerButton({
    super.key,
    required this.routineType,
    required this.onChanged,
    this.initialMetadata,
    this.uploadService,
    this.label = 'Add photo',
    this.enabled = true,
    this.deleteOnClear = true,
  });

  @override
  ConsumerState<PhotoPickerButton> createState() => _PhotoPickerButtonState();
}

class _PhotoPickerButtonState extends ConsumerState<PhotoPickerButton> {
  ImageUploadService? _uploadService;
  Map<String, dynamic>? _metadata;
  bool _isBusy = false;

  ImageUploadService get _service =>
      widget.uploadService ??
      (_uploadService ??= ImageUploadService(
        featureFlags: ref.read(appFeatureFlagsProvider),
      ));

  @override
  void initState() {
    super.initState();
    _metadata = widget.initialMetadata;
  }

  @override
  void didUpdateWidget(PhotoPickerButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialMetadata != oldWidget.initialMetadata) {
      _metadata = widget.initialMetadata;
    }
  }

  Future<void> _chooseSource() async {
    if (_isBusy || !widget.enabled) return;
    if (!_uploadsEnabled) {
      _showComingSoon();
      return;
    }

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: const Text('Camera'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Gallery'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    await _pickCompressAndUpload(source);
  }

  bool get _uploadsEnabled {
    final flags = ref.read(appFeatureFlagsProvider);
    if (widget.routineType == 'profile') {
      return flags.profileImageUploadReady;
    }
    return flags.r2UploadsReady;
  }

  void _showComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Photo uploads are coming soon.')),
    );
  }

  Future<void> _pickCompressAndUpload(ImageSource source) async {
    final previousMetadata = _metadata;
    setState(() => _isBusy = true);
    try {
      final metadata = await _service.pickCompressAndUpload(
        source: source,
        routineType: widget.routineType,
      );
      if (!mounted || metadata == null) return;

      setState(() => _metadata = metadata);
      widget.onChanged(metadata);
      if (widget.deleteOnClear && previousMetadata != null) {
        await _deleteMetadataQuietly(previousMetadata);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Photo upload failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _deleteMetadataQuietly(Map<String, dynamic> metadata) async {
    try {
      await _service.deleteUploadedMetadata(metadata);
    } catch (_) {
      // Best-effort cleanup for replaced draft uploads.
    }
  }

  Future<void> _clearUpload() async {
    if (_isBusy || !widget.enabled) return;

    final metadata = _metadata;
    setState(() => _isBusy = true);
    try {
      if (widget.deleteOnClear) {
        await _service.deleteUploadedMetadata(metadata);
      }
      if (!mounted) return;

      setState(() => _metadata = null);
      widget.onChanged(null);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not remove photo: $e')),
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final metadata = _metadata;
    final hasUpload = metadata != null;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        OutlinedButton.icon(
          onPressed: _isBusy || !widget.enabled ? null : _chooseSource,
          icon: _isBusy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  hasUpload
                      ? Icons.check_circle_rounded
                      : Icons.add_a_photo_rounded,
                ),
          label: Text(hasUpload ? _uploadLabel(metadata) : widget.label),
        ),
        if (hasUpload) ...[
          const SizedBox(width: 8),
          Tooltip(
            message: 'Remove uploaded photo',
            child: IconButton.filledTonal(
              onPressed: _isBusy || !widget.enabled ? null : _clearUpload,
              icon: const Icon(Icons.close_rounded),
            ),
          ),
        ],
      ],
    );
  }

  static String _uploadLabel(Map<String, dynamic> metadata) {
    final sizeBytes = metadata['sizeBytes'];
    if (sizeBytes is num) {
      final kb = (sizeBytes / 1000).ceil();
      return 'Photo attached ($kb KB)';
    }
    return 'Photo attached';
  }
}
