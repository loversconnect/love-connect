import 'package:flutter/material.dart';
import 'package:lerolove/Utils/responsive.dart';

class ManagePhotosScreen extends StatefulWidget {
  const ManagePhotosScreen({Key? key}) : super(key: key);

  @override
  State<ManagePhotosScreen> createState() => _ManagePhotosScreenState();
}

class _ManagePhotosScreenState extends State<ManagePhotosScreen> {
  // Demo: Start with some photos already added
  final List<String?> _photos = [
    'photo_0', // Main photo
    'photo_1',
    null,
    'photo_3',
    null,
    null,
  ];

  bool _hasChanges = false;

  void _addPhoto(int index) {
    setState(() {
      _photos[index] = 'photo_$index';
      _hasChanges = true;
    });
  }

  void _removePhoto(int index) {
    setState(() {
      _photos[index] = null;
      _hasChanges = true;
    });
  }

  void _reorderPhotos(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    setState(() {
      final photo = _photos.removeAt(oldIndex);
      _photos.insert(newIndex, photo);
      _hasChanges = true;
    });
  }

  void _saveChanges() {
    // In real app: Upload to Firebase Storage
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Photos updated successfully'),
        duration: Duration(seconds: 2),
      ),
    );
    setState(() {
      _hasChanges = false;
    });
    Navigator.pop(context);
  }

  void _showDeleteConfirmation(int index) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Photo'),
          content: const Text('Are you sure you want to delete this photo?'),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _removePhoto(index);
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('Delete'),
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
        title: const Text('Manage Photos'),
        actions: [
          if (_hasChanges)
            TextButton(
              onPressed: _saveChanges,
              child: const Text(
                'Save',
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: Responsive.pagePadding(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info Card
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
                            'Photo Tips',
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: Responsive.font(context, 15),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Your first photo is your main profile photo. Drag to reorder. Long-press to delete.',
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
              // Photo Count
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Your Photos',
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
                'At least 1 photo required',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onBackground.withOpacity(0.6),
                  fontSize: Responsive.font(context, 14),
                ),
              ),
              const SizedBox(height: 24),
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
                    hasPhoto ? _showDeleteConfirmation(index) : null,
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
                          // Photo placeholder
                          Center(
                            child: Icon(
                              Icons.photo,
                              size: Responsive.icon(context, 48),
                              color: colorScheme.primary.withOpacity(0.5),
                            ),
                          ),
                          // Delete button
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Color(0xFFD64B6C),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.close,
                                size: Responsive.icon(context, 16),
                                color: Colors.white,
                              ),
                            ),
                          ),
                          // Main photo badge
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
                                  'Main Photo',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: Responsive.font(context, 10),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          // Photo number
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
                                    fontSize: Responsive.font(context, 11),
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
                            index == 0 ? 'Add Main' : 'Add Photo',
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onBackground.withOpacity(0.6),
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
              // Guidelines
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
                          'Photo Guidelines',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: colorScheme.primary,
                            fontSize: Responsive.font(context, 15),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildGuideline('✓ Use clear, recent photos of yourself'),
                    _buildGuideline('✓ Show your face clearly'),
                    _buildGuideline('✓ Include variety (close-up, full body, activities)'),
                    _buildGuideline('✗ No group photos as main photo'),
                    _buildGuideline('✗ No sunglasses covering your face'),
                    _buildGuideline('✗ No inappropriate or offensive content'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
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
          title: const Text('Unsaved Changes'),
          content: const Text(
            'You have unsaved changes. Do you want to save before leaving?',
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              child: const Text('Discard'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _saveChanges();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }
}
