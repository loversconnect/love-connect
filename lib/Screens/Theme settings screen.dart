import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lerolove/Utils/theme_manager.dart';
import 'package:lerolove/Utils/chat_background_manager.dart';
import 'package:lerolove/Utils/responsive.dart';

class ThemeSettingsScreen extends StatelessWidget {
  const ThemeSettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Theme & Wallpaper'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        children: [
          // App Theme Section
          _buildSectionHeader(context, 'App Theme', isDark),
          _buildAppThemeOptions(context),

          const Divider(height: 32),

          // Chat Wallpaper Section
          _buildSectionHeader(context, 'Chat Wallpaper', isDark),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              'Choose a background for your chats',
              style: TextStyle(
                fontSize: Responsive.font(context, 14),
                color: colorScheme.onBackground.withOpacity(0.6),
              ),
            ),
          ),
          _buildChatBackgroundGrid(context),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, bool isDark) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      child: Text(
        title.toUpperCase(),
        style: textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: colorScheme.onBackground.withOpacity(0.6),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildAppThemeOptions(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Consumer<ThemeManager>(
      builder: (context, themeManager, child) {
        return Column(
          children: [
            RadioListTile<ThemeMode>(
              title: Row(
                children: [
                  Icon(
                    Icons.wb_sunny,
                    size: Responsive.icon(context, 20),
                    color: const Color(0xFFFFA726),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Light Mode',
                    style: TextStyle(
                      color: colorScheme.onBackground,
                    ),
                  ),
                ],
              ),
              subtitle: Text(
                'Bright and clean interface',
                style: TextStyle(
                  fontSize: Responsive.font(context, 13),
                  color: colorScheme.onBackground.withOpacity(0.6),
                ),
              ),
              value: ThemeMode.light,
              groupValue: themeManager.themeMode,
              activeColor: colorScheme.primary,
              onChanged: (value) {
                if (value != null) {
                  themeManager.setThemeMode(value);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Switched to Light Mode'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                }
              },
            ),
            RadioListTile<ThemeMode>(
              title: Row(
                children: [
                  Icon(
                    Icons.nightlight_round,
                    size: Responsive.icon(context, 20),
                    color: const Color(0xFF7E57C2),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Dark Mode',
                    style: TextStyle(
                      color: colorScheme.onBackground,
                    ),
                  ),
                ],
              ),
              subtitle: Text(
                'Easy on the eyes in low light',
                style: TextStyle(
                  fontSize: Responsive.font(context, 13),
                  color: colorScheme.onBackground.withOpacity(0.6),
                ),
              ),
              value: ThemeMode.dark,
              groupValue: themeManager.themeMode,
              activeColor: colorScheme.primary,
              onChanged: (value) {
                if (value != null) {
                  themeManager.setThemeMode(value);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Switched to Dark Mode'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                }
              },
            ),
            RadioListTile<ThemeMode>(
              title: Row(
                children: [
                  Icon(
                    Icons.brightness_auto,
                    size: Responsive.icon(context, 20),
                    color: const Color(0xFF66BB6A),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'System Default',
                    style: TextStyle(
                      color: colorScheme.onBackground,
                    ),
                  ),
                ],
              ),
              subtitle: Text(
                'Follow device settings',
                style: TextStyle(
                  fontSize: Responsive.font(context, 13),
                  color: colorScheme.onBackground.withOpacity(0.6),
                ),
              ),
              value: ThemeMode.system,
              groupValue: themeManager.themeMode,
              activeColor: colorScheme.primary,
              onChanged: (value) {
                if (value != null) {
                  themeManager.setThemeMode(value);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Following System Theme'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildChatBackgroundGrid(BuildContext context) {
    return Consumer<ChatBackgroundManager>(
      builder: (context, bgManager, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final colorScheme = Theme.of(context).colorScheme;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.75,
          ),
          itemCount: ChatBackgroundType.values.length,
          itemBuilder: (context, index) {
            final bgType = ChatBackgroundType.values[index];
            final isSelected = bgManager.currentBackground == bgType;

            return GestureDetector(
              onTap: () {
                bgManager.setBackground(bgType);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '${ChatBackgrounds.getName(bgType)} wallpaper applied!',
                    ),
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? colorScheme.primary
                        : colorScheme.surfaceVariant,
                    width: isSelected ? 3 : 1.5,
                  ),
                  boxShadow: isSelected
                      ? [
                    BoxShadow(
                      color: colorScheme.primary.withOpacity(0.3),
                      blurRadius: 8,
                      spreadRadius: 1,
                    )
                  ]
                      : null,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Stack(
                    children: [
                      // Background preview
                      Positioned.fill(
                        child: ChatBackgrounds.getBackground(bgType, isDark),
                      ),

                      // Demo message bubbles
                      Positioned(
                        top: 12,
                        left: 8,
                        right: 35,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF2C2C2C)
                                : colorScheme.surface,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Hey!',
                            style: TextStyle(
                              fontSize: Responsive.font(context, 9),
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 32,
                        right: 8,
                        left: 35,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Hi there!',
                            style: TextStyle(
                              fontSize: Responsive.font(context, 9),
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ),

                      // Selected checkmark
                      if (isSelected)
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.check,
                              size: Responsive.icon(context, 12),
                              color: Colors.white,
                            ),
                          ),
                        ),

                      // Name label
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.7),
                              ],
                            ),
                          ),
                          child: Text(
                            ChatBackgrounds.getName(bgType),
                            style: TextStyle(
                              fontSize: Responsive.font(context, 10),
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
