import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lerolove/Screens/Preferences%20screen.dart';
import 'package:lerolove/Utils/face_match_validator.dart';
import 'package:lerolove/Utils/photo_image.dart';
import 'package:lerolove/Utils/responsive.dart';
import 'package:lerolove/providers/profile_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AddPhotosScreen extends StatefulWidget {
  const AddPhotosScreen({Key? key}) : super(key: key);

  @override
  State<AddPhotosScreen> createState() => _AddPhotosScreenState();
}

class _AddPhotosScreenState extends State<AddPhotosScreen> {
  final List<String?> _photos = List<String?>.filled(6, null);
  final ImagePicker _picker = ImagePicker();
  final FaceDetector _faceDetector = FaceMatchValidator.buildDetector();
  bool _isValidatingFace = false;
  FaceSignature? _selfieReference;

  @override
  void initState() {
    super.initState();
    final existingPhotos =
        context.read<ProfileProvider>().currentProfile?.photoUrls ?? const [];
    for (var i = 0; i < existingPhotos.length && i < _photos.length; i++) {
      _photos[i] = existingPhotos[i];
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showSelfieHintOnce();
    });
    FaceMatchValidator.loadSelfieSignature().then((value) {
      _selfieReference = value;
    });
  }

  Future<void> _showSelfieHintOnce() async {
    final prefs = await SharedPreferences.getInstance();
    final shown = prefs.getBool('hint_selfie_required_shown') ?? false;
    if (shown || !mounted) return;
    await prefs.setBool('hint_selfie_required_shown', true);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Selfie in slot 1 is required for trust and profile safety.',
        ),
        duration: Duration(seconds: 3),
      ),
    );
  }

  bool get _hasMinimumPhotos => _photos.where((p) => p != null).length >= 1;
  bool get _hasRequiredSelfie => _photos[0] != null;

  Future<void> _addPhoto(int index) async {
    if (_isValidatingFace) return;

    if (index > 0 && !_hasRequiredSelfie) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please take your main selfie first (slot 1).'),
        ),
      );
      return;
    }

    try {
      final isSelfieSlot = index == 0;
      final selected = await _picker.pickImage(
        source: isSelfieSlot ? ImageSource.camera : ImageSource.gallery,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (selected == null) return;

      final validationError = await _validateFaceRules(
        imagePath: selected.path,
        isSelfieSlot: isSelfieSlot,
      );
      if (!mounted) return;
      if (validationError != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(validationError)));
        return;
      }

      setState(() {
        _photos[index] = selected.path;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            index == 0
                ? 'Could not open front camera. Please allow camera permission.'
                : 'Could not open gallery. Please check permissions.',
          ),
        ),
      );
    }
  }

  Future<String?> _validateFaceRules({
    required String imagePath,
    required bool isSelfieSlot,
  }) async {
    setState(() {
      _isValidatingFace = true;
    });

    try {
      if (!await File(imagePath).exists()) {
        return 'Could not read selected photo.';
      }

      final result = await FaceMatchValidator.validatePhoto(
        detector: _faceDetector,
        imagePath: imagePath,
        isSelfieSlot: isSelfieSlot,
        reference: _selfieReference,
      );
      if (!result.success) {
        return result.message ?? 'Face verification failed.';
      }

      if (isSelfieSlot && result.signature != null) {
        _selfieReference = result.signature;
        await FaceMatchValidator.saveSelfieSignature(result.signature!);
      }
      return null;
    } catch (_) {
      return 'Face check failed. Please retake the photo.';
    } finally {
      if (mounted) {
        setState(() {
          _isValidatingFace = false;
        });
      }
    }
  }

  void _removePhoto(int index) {
    setState(() {
      _photos[index] = null;
      if (index == 0) {
        _selfieReference = null;
        FaceMatchValidator.clearSelfieSignature();
      }
    });
  }

  Future<void> _continue() async {
    if (_hasMinimumPhotos && _hasRequiredSelfie) {
      final photos = _photos.whereType<String>().toList(growable: false);
      final profileProvider = context.read<ProfileProvider>();
      await profileProvider.updateProfile(photoUrls: photos);
      if (!mounted) return;
      if (profileProvider.error != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(profileProvider.error!)));
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const PreferencesScreen()),
      );
    }
  }

  @override
  void dispose() {
    _faceDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final profileProvider = context.watch<ProfileProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Photos'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: Responsive.pagePadding(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add Your Photos',
                      style: textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: Responsive.font(context, 28),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Main selfie is required first',
                      style: textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onBackground.withOpacity(0.7),
                        fontSize: Responsive.font(context, 15),
                      ),
                    ),
                    const SizedBox(height: 32),
                    if (_isValidatingFace) ...[
                      LinearProgressIndicator(
                        minHeight: 4,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Validating face...',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.65),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    // Photo Grid
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: Responsive.gridColumns(context),
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.75,
                      ),
                      itemCount: 6,
                      itemBuilder: (context, index) {
                        final hasPhoto = _photos[index] != null;

                        return GestureDetector(
                          onTap: () => hasPhoto ? null : _addPhoto(index),
                          onLongPress: () =>
                              hasPhoto ? _removePhoto(index) : null,
                          child: Container(
                            decoration: BoxDecoration(
                              color: hasPhoto
                                  ? colorScheme.secondary.withOpacity(0.15)
                                  : colorScheme.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: hasPhoto
                                    ? colorScheme.primary
                                    : colorScheme.surfaceVariant,
                                width: 2,
                              ),
                            ),
                            child: hasPhoto
                                ? Stack(
                                    children: [
                                      Positioned.fill(
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          child: PhotoImage(
                                            path: _photos[index],
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        top: 4,
                                        right: 4,
                                        child: GestureDetector(
                                          onTap: () => _removePhoto(index),
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: const BoxDecoration(
                                              color: Color(0xFFD64B6C),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.close,
                                              size: Responsive.icon(
                                                context,
                                                16,
                                              ),
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (index == 0)
                                        Positioned(
                                          bottom: 8,
                                          left: 8,
                                          right: 8,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withOpacity(
                                                0.6,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              'Main',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: Responsive.font(
                                                  context,
                                                  10,
                                                ),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  )
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.add_photo_alternate_outlined,
                                        size: Responsive.icon(context, 40),
                                        color: colorScheme.onSurface
                                            .withOpacity(0.4),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        index == 0 ? 'Selfie' : '${index + 1}',
                                        style: textTheme.bodySmall?.copyWith(
                                          color: colorScheme.onBackground
                                              .withOpacity(0.6),
                                          fontSize: Responsive.font(
                                            context,
                                            12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    // Helper Text
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: colorScheme.secondary.withOpacity(0.25),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: colorScheme.primary,
                            size: Responsive.icon(context, 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Take a clear selfie in slot 1 first. Then add more photos from gallery. Tap to add, long-press to remove.',
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onBackground.withOpacity(
                                  0.7,
                                ),
                                height: 1.4,
                                fontSize: Responsive.font(context, 13),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Bottom Buttons
            Padding(
              padding: Responsive.pagePadding(context),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed:
                          _hasMinimumPhotos &&
                              _hasRequiredSelfie &&
                              !profileProvider.isLoading
                          ? _continue
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _hasMinimumPhotos && _hasRequiredSelfie
                            ? colorScheme.primary
                            : colorScheme.surfaceVariant,
                        foregroundColor: _hasMinimumPhotos && _hasRequiredSelfie
                            ? colorScheme.onPrimary
                            : colorScheme.onSurface,
                      ),
                      child: profileProvider.isLoading
                          ? SizedBox(
                              width: Responsive.icon(context, 20),
                              height: Responsive.icon(context, 20),
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('Continue'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
