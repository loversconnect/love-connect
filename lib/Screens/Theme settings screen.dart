import 'package:flutter/material.dart';
import 'package:lerolove/Utils/app_i18n.dart';
import 'package:provider/provider.dart';
import 'package:lerolove/Utils/theme_manager.dart';
import 'package:lerolove/Utils/chat_background_manager.dart';
import 'package:lerolove/Utils/responsive.dart';

class ThemeSettingsScreen extends StatelessWidget {
  const ThemeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('theme_settings_title')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        children: [
          // App Theme Section
          _buildSectionHeader(context, context.tr('app_theme'), isDark),
          _buildAppThemeOptions(context),

          const Divider(height: 32),

          // Chat Wallpaper Section
          _buildSectionHeader(context, context.tr('chat_wallpaper'), isDark),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              context.tr('choose_chat_background'),
              style: TextStyle(
                fontSize: Responsive.font(context, 14),
                color: colorScheme.onSurface.withValues(alpha: 0.6),
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
          color: colorScheme.onSurface.withValues(alpha: 0.6),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildAppThemeOptions(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);

    return Consumer<ThemeManager>(
      builder: (context, themeManager, child) {
        return Column(
          children: [
            _buildThemeModeOption(
              context,
              icon: Icons.wb_sunny,
              iconColor: const Color(0xFFFFA726),
              title: context.tr('light_mode'),
              subtitle: context.tr('bright_clean_interface'),
              value: ThemeMode.light,
              current: themeManager.themeMode,
              onSelected: () {
                themeManager.setThemeMode(ThemeMode.light);
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(context.tr('switched_light_mode')),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
            ),
            _buildThemeModeOption(
              context,
              icon: Icons.nightlight_round,
              iconColor: const Color(0xFF7E57C2),
              title: context.tr('dark_mode'),
              subtitle: context.tr('easy_on_eyes'),
              value: ThemeMode.dark,
              current: themeManager.themeMode,
              onSelected: () {
                themeManager.setThemeMode(ThemeMode.dark);
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(context.tr('dark_mode')),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
            ),
            _buildThemeModeOption(
              context,
              icon: Icons.brightness_auto,
              iconColor: const Color(0xFF66BB6A),
              title: context.tr('system_default'),
              subtitle: context.tr('follow_device_settings'),
              value: ThemeMode.system,
              current: themeManager.themeMode,
              onSelected: () {
                themeManager.setThemeMode(ThemeMode.system);
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(context.tr('following_system_theme')),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildThemeModeOption(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required ThemeMode value,
    required ThemeMode current,
    required VoidCallback onSelected,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final selected = current == value;
    return ListTile(
      onTap: onSelected,
      leading: Icon(icon, size: Responsive.icon(context, 20), color: iconColor),
      title: Text(title, style: TextStyle(color: colorScheme.onSurface)),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: Responsive.font(context, 13),
          color: colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      ),
      trailing: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_off,
        color: selected ? colorScheme.primary : colorScheme.outline,
      ),
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
                      '${_backgroundLabel(context, bgType)} ${context.tr('wallpaper_applied_suffix')}',
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
                        : colorScheme.surfaceContainerHighest,
                    width: isSelected ? 3 : 1.5,
                  ),
                  boxShadow: isSelected
                      ? [
                    BoxShadow(
                      color: colorScheme.primary.withValues(alpha: 0.3),
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
                            context.tr('sample_hey'),
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
                            context.tr('sample_hi_there'),
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
                                Colors.black.withValues(alpha: 0.7),
                              ],
                            ),
                          ),
                          child: Text(
                            _backgroundLabel(context, bgType),
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

  String _backgroundLabel(BuildContext context, ChatBackgroundType type) {
    switch (type) {
      case ChatBackgroundType.defaultLight:
        return context.tr('wallpaper_default_light');
      case ChatBackgroundType.defaultDark:
        return context.tr('wallpaper_default_dark');
      case ChatBackgroundType.whatsappClassic:
        return context.tr('wallpaper_classic');
      case ChatBackgroundType.geometric:
        return context.tr('wallpaper_geometric');
      case ChatBackgroundType.bubbles:
        return context.tr('wallpaper_bubbles');
      case ChatBackgroundType.waves:
        return context.tr('wallpaper_waves');
      case ChatBackgroundType.solidGray:
        return context.tr('wallpaper_solid_gray');
      case ChatBackgroundType.solidBlack:
        return context.tr('wallpaper_solid_black');
      case ChatBackgroundType.solidWhite:
        return context.tr('wallpaper_solid_white');
      case ChatBackgroundType.gradientBlue:
        return context.tr('wallpaper_blue_gradient');
      case ChatBackgroundType.gradientPurple:
        return context.tr('wallpaper_purple_gradient');
      case ChatBackgroundType.gradientGreen:
        return context.tr('wallpaper_green_gradient');
      case ChatBackgroundType.gradientOrange:
        return context.tr('wallpaper_orange_gradient');
      case ChatBackgroundType.dots:
        return context.tr('wallpaper_dots');
      case ChatBackgroundType.stripes:
        return context.tr('wallpaper_stripes');
    }
  }
}
