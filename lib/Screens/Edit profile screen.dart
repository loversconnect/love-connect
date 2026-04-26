import 'package:flutter/material.dart';
import 'package:lerolove/Utils/app_i18n.dart';
import 'package:lerolove/providers/profile_provider.dart';
import 'package:lerolove/Utils/responsive.dart';
import 'package:provider/provider.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({Key? key}) : super(key: key);

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _nameController;
  final TextEditingController _bioController = TextEditingController(
    text: 'Love music and dancing. Looking for meaningful connections.',
  );

  final List<String> _availableInterests = [
    'Music',
    'Dancing',
    'Travel',
    'Fitness',
    'Cooking',
    'Reading',
    'Movies',
    'Sports',
    'Art',
    'Photography',
    'Gaming',
    'Hiking',
  ];

  final List<String> _selectedInterests = ['Music', 'Dancing', 'Travel'];
  final int _maxInterests = 5;
  final int _maxBioLength = 500;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final profile = context.read<ProfileProvider>().currentProfile;
    _nameController = TextEditingController(text: profile?.name ?? '');
    _bioController.text = profile?.bio ?? _bioController.text;
    _selectedInterests
      ..clear()
      ..addAll(profile?.interests ?? _selectedInterests);
  }

  void _toggleInterest(String interest) {
    setState(() {
      if (_selectedInterests.contains(interest)) {
        _selectedInterests.remove(interest);
      } else {
        if (_selectedInterests.length < _maxInterests) {
          _selectedInterests.add(interest);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${context.tr('select_up_to_interests')} $_maxInterests ${context.tr('interests').toLowerCase()}',
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    });
  }

  void _saveProfile() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('name_empty')),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    await context.read<ProfileProvider>().updateProfile(
          bio: _bioController.text.trim(),
          interests: _selectedInterests,
        );

    if (!mounted) return;
    setState(() {
      _isSaving = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.tr('profile_updated')),
        duration: const Duration(seconds: 2),
      ),
    );

    Navigator.pop(context);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('edit_profile_title')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: _saveProfile,
              child: Text(
                context.tr('save'),
                style: TextStyle(
                  fontSize: Responsive.font(context, 16),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: Responsive.pagePadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name Field
            Text(
              context.tr('display_name'),
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: Responsive.font(context, 16),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(hintText: context.tr('enter_your_name')),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 32),
            // Bio Field
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.tr('bio'),
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: Responsive.font(context, 16),
                  ),
                ),
                Text(
                  '${_bioController.text.length}/$_maxBioLength',
                  style: TextStyle(
                    fontSize: Responsive.font(context, 13),
                    color: _bioController.text.length > _maxBioLength
                        ? colorScheme.error
                        : colorScheme.onBackground.withOpacity(0.6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bioController,
              decoration: InputDecoration(
                hintText: context.tr('bio_hint'),
                alignLabelWithHint: true,
              ),
              maxLines: 5,
              maxLength: _maxBioLength,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (value) {
                setState(() {}); // Update character count
              },
            ),
            const SizedBox(height: 32),
            // Interests Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.tr('interests'),
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: Responsive.font(context, 16),
                  ),
                ),
                Text(
                  '${_selectedInterests.length}/$_maxInterests',
                  style: TextStyle(
                    fontSize: Responsive.font(context, 13),
                    color: colorScheme.onBackground.withOpacity(0.6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${context.tr('select_up_to_interests')} $_maxInterests ${context.tr('interests').toLowerCase()}',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onBackground.withOpacity(0.6),
                fontSize: Responsive.font(context, 13),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _availableInterests.map((interest) {
                final isSelected = _selectedInterests.contains(interest);
                return GestureDetector(
                  onTap: () => _toggleInterest(interest),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? colorScheme.primary
                            : colorScheme.surfaceVariant,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      interest,
                      style: TextStyle(
                        fontSize: Responsive.font(context, 14),
                        fontWeight: FontWeight.w500,
                        color: isSelected
                            ? colorScheme.onPrimary
                            : colorScheme.onBackground,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),
            // Info Box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colorScheme.secondary.withOpacity(0.2),
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
                      context.tr('changes_visible_now'),
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onBackground.withOpacity(0.7),
                        height: 1.4,
                      ),
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

