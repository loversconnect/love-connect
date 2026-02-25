import 'package:flutter/material.dart';
import 'package:lerolove/Screens/Preferences%20screen.dart';
import 'package:lerolove/Utils/responsive.dart';

class AddPhotosScreen extends StatefulWidget {
  const AddPhotosScreen({Key? key}) : super(key: key);

  @override
  State<AddPhotosScreen> createState() => _AddPhotosScreenState();
}

class _AddPhotosScreenState extends State<AddPhotosScreen> {
  final List<String?> _photos = List.filled(6, null);

  bool get _hasMinimumPhotos => _photos.where((p) => p != null).length >= 1;

  void _addPhoto(int index) {
    // In real app: Open image picker
    // For demo, just mark as added
    setState(() {
      _photos[index] = 'photo_$index';
    });
  }

  void _removePhoto(int index) {
    setState(() {
      _photos[index] = null;
    });
  }

  void _continue() {
    if (_hasMinimumPhotos) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const PreferencesScreen()),
      );
    }
  }

  void _skip() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PreferencesScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

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
                      'At least 1 photo required',
                      style: textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onBackground.withOpacity(0.7),
                        fontSize: Responsive.font(context, 15),
                      ),
                    ),
                    const SizedBox(height: 32),
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
                          onLongPress: () => hasPhoto ? _removePhoto(index) : null,
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
                                Center(
                                  child: Icon(
                                    Icons.photo,
                                    size: Responsive.icon(context, 48),
                                    color: colorScheme.primary.withOpacity(0.5),
                                  ),
                                ),
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
                                        color: Colors.black.withOpacity(0.6),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'Main',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: Responsive.font(context, 10),
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
                                  color: colorScheme.onSurface.withOpacity(0.4),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  index == 0 ? 'Main' : '${index + 1}',
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
                              'Photos should be clear and show your face. Tap to add, long-press to remove.',
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onBackground.withOpacity(0.7),
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
                      onPressed: _hasMinimumPhotos ? _continue : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _hasMinimumPhotos
                            ? colorScheme.primary
                            : colorScheme.surfaceVariant,
                        foregroundColor: _hasMinimumPhotos
                            ? colorScheme.onPrimary
                            : colorScheme.onSurface,
                      ),
                      child: const Text('Continue'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _skip,
                    child: const Text('Skip for Now'),
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
