import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lerolove/Utils/app_i18n.dart';
import 'package:lerolove/Utils/face_match_validator.dart';
import 'package:lerolove/Utils/photo_image.dart';
import 'package:lerolove/Utils/responsive.dart';
import 'package:lerolove/providers/profile_provider.dart';
import 'package:provider/provider.dart';

class ManagePhotosScreen extends StatefulWidget {
  const ManagePhotosScreen({Key? key}) : super(key: key);

  @override
  State<ManagePhotosScreen> createState() => _ManagePhotosScreenState();
}

class _ManagePhotosScreenState extends State<ManagePhotosScreen> {
  final List<String?> _photos = List<String?>.filled(6, null);
  final ImagePicker _picker = ImagePicker();
  final FaceDetector _faceDetector = FaceMatchValidator.buildDetector();

  bool _hasChanges = false;
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
    FaceMatchValidator.loadSelfieSignature().then((value) {
      _selfieReference = value;
    });
  }

  Future<void> _addPhoto(int index) async {
    if (_isValidatingFace) return;

    if (index > 0 && _photos[0] == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('main_selfie_first'))),
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
        _hasChanges = true;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            index == 0
                ? context.tr('camera_permission_error')
                : context.tr('gallery_permission_error'),
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
      final result = await FaceMatchValidator.validatePhoto(
        detector: _faceDetector,
        imagePath: imagePath,
        isSelfieSlot: isSelfieSlot,
        reference: _selfieReference,
      );
      if (!result.success) {
        return result.message ?? context.tr('face_verification_failed');
      }

      if (isSelfieSlot && result.signature != null) {
        _selfieReference = result.signature;
        await FaceMatchValidator.saveSelfieSignature(result.signature!);
      }

      return null;
    } catch (_) {
      return context.tr('face_check_failed');
    } finally {
      if (mounted) {
        setState(() {
          _isValidatingFace = false;
        });
      }
    }
  }

  void _removePhoto(int index) {
    if (index == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('main_selfie_cannot_delete'))),
      );
      return;
    }
    setState(() {
      _photos[index] = null;
      _hasChanges = true;
    });
  }

  Future<void> _saveChanges() async {
    if (_photos[0] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('main_selfie_required'))),
      );
      return;
    }

    final cleaned = _photos.whereType<String>().toList(growable: false);
    final profileProvider = context.read<ProfileProvider>();
    await profileProvider.updateProfile(photoUrls: cleaned);
    if (!mounted) return;
    if (profileProvider.error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(content: Text(context.trError(profileProvider.error!))),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.tr('photos_updated')),
        duration: Duration(seconds: 2),
      ),
    );
    setState(() {
      _hasChanges = false;
    });
    Navigator.pop(context);
  }

  void _showDeleteConfirmation(int index) {
    if (index == 0) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(context.tr('main_selfie_protected')),
            content: Text(context.tr('main_selfie_protected_desc')),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(context.tr('ok')),
              ),
            ],
          );
        },
      );
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(context.tr('delete_photo')),
          content: Text(context.tr('delete_photo_confirm')),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.tr('cancel')),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _removePhoto(index);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text(context.tr('delete')),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final profileProvider = context.watch<ProfileProvider>();
    final photoCount = _photos.where((p) => p != null).length;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_hasChanges) {
              _showUnsavedChangesDialog();
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(context.tr('manage_photos_title')),
        actions: [
          if (_hasChanges)
            TextButton(
              onPressed: profileProvider.isLoading ? null : _saveChanges,
              child: profileProvider.isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(context.tr('save')),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: Responsive.pagePadding(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isValidatingFace) ...[
                LinearProgressIndicator(
                  minHeight: 4,
                  color: colorScheme.primary,
                ),
                const SizedBox(height: 10),
                Text(
                  context.tr('validating_face'),
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.65),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: [
                      colorScheme.surface,
                      colorScheme.surfaceVariant.withOpacity(0.6),
                    ],
                  ),
                  border: Border.all(
                    color: colorScheme.secondary.withOpacity(0.25),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: colorScheme.primary,
                      size: Responsive.icon(context, 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr('photo_tips'),
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: Responsive.font(context, 15),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            context.tr('photo_tips_desc'),
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onBackground.withOpacity(0.7),
                              height: 1.4,
                              fontSize: Responsive.font(context, 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    context.tr('your_photos'),
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: Responsive.font(context, 20),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: photoCount >= 1
                          ? colorScheme.primary.withOpacity(0.12)
                          : colorScheme.error.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$photoCount / 6',
                      style: TextStyle(
                        fontSize: Responsive.font(context, 14),
                        fontWeight: FontWeight.w600,
                        color: photoCount >= 1
                            ? colorScheme.primary
                            : colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                context.tr('at_least_one_photo'),
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onBackground.withOpacity(0.6),
                  fontSize: Responsive.font(context, 14),
                ),
              ),
              const SizedBox(height: 24),
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
                    onTap: () {
                      if (!hasPhoto) {
                        _addPhoto(index);
                        return;
                      }
                      if (index == 0) {
                        _addPhoto(0);
                        return;
                      }
                      _showReplacePhotoOptions(index);
                    },
                    onLongPress: () => hasPhoto && index > 0
                        ? _showDeleteConfirmation(index)
                        : null,
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
                                    borderRadius: BorderRadius.circular(12),
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
                                    onTap: () => index == 0
                                        ? _addPhoto(0)
                                        : _showDeleteConfirmation(index),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFD64B6C),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        index == 0
                                            ? Icons.camera_alt
                                            : Icons.close,
                                        size: Responsive.icon(context, 16),
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
                                        color: Colors.black.withOpacity(0.7),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        context.tr('main_photo'),
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
                                if (index > 0)
                                  Positioned(
                                    bottom: 8,
                                    left: 8,
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.5),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Text(
                                        '${index + 1}',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: Responsive.font(
                                            context,
                                            11,
                                          ),
                                          fontWeight: FontWeight.bold,
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
                                  color: colorScheme.onSurface.withOpacity(0.4),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  index == 0
                                      ? context.tr('selfie')
                                      : context.tr('add_photo'),
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onBackground.withOpacity(
                                      0.6,
                                    ),
                                    fontSize: Responsive.font(context, 12),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colorScheme.secondary.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.lightbulb_outline,
                          color: colorScheme.primary,
                          size: Responsive.icon(context, 20),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          context.tr('photo_guidelines'),
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: colorScheme.primary,
                            fontSize: Responsive.font(context, 15),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildGuideline('✓ ${context.tr('guide_clear_recent')}'),
                    _buildGuideline('✓ ${context.tr('guide_show_face')}'),
                    _buildGuideline('✓ ${context.tr('guide_variety')}'),
                    _buildGuideline('✗ ${context.tr('guide_no_group_main')}'),
                    _buildGuideline('✗ ${context.tr('guide_no_sunglasses')}'),
                    _buildGuideline('✗ ${context.tr('guide_no_offensive')}'),
                    _buildGuideline('✓ ${context.tr('guide_main_selfie_protected')}'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showReplacePhotoOptions(int index) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: Text(context.tr('replace_photo')),
                onTap: () {
                  Navigator.of(context).pop();
                  _addPhoto(index);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: Text(
                  context.tr('delete_photo'),
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  _showDeleteConfirmation(index);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGuideline(String text) {
    final isPositive = text.startsWith('✓');
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text.substring(0, 1),
            style: TextStyle(
              fontSize: Responsive.font(context, 14),
              color: isPositive ? const Color(0xFF2E8B57) : colorScheme.error,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text.substring(2),
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onBackground.withOpacity(0.7),
                height: 1.4,
                fontSize: Responsive.font(context, 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showUnsavedChangesDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(context.tr('unsaved_changes')),
          content: Text(context.tr('unsaved_changes_confirm')),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              child: Text(context.tr('discard')),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _saveChanges();
              },
              child: Text(context.tr('save')),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _faceDetector.close();
    super.dispose();
  }
}
