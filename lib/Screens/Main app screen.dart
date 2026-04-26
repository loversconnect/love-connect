import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lerolove/Screens/Chat%20detail%20screen.dart';
import 'package:lerolove/Screens/Tabs/Discover%20tab.dart';
import 'package:lerolove/Screens/Tabs/Matches%20tab.dart';
import 'package:lerolove/Screens/Tabs/Settings%20tab.dart';
import 'package:lerolove/Utils/app_i18n.dart';
import 'package:lerolove/Utils/photo_image.dart';
import 'package:lerolove/models/match_models.dart';
import 'package:lerolove/providers/matches_provider.dart';
import 'package:lerolove/Utils/responsive.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MainAppScreen extends StatefulWidget {
  const MainAppScreen({super.key});

  @override
  State<MainAppScreen> createState() => _MainAppScreenState();
}

class _MainAppScreenState extends State<MainAppScreen> {
  static const String _tourSeenKey = 'main_tab_onboarding_seen_v1';
  int _currentIndex = 0;
  bool _isShowingMatchPrompt = false;

  // All tabs are now imported from separate files
  final List<Widget> _tabs = [
    const DiscoverTab(),
    const MatchesTab(),
    const SettingsTab(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_runOnboardingTourIfNeeded());
    });
  }

  Future<void> _runOnboardingTourIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool(_tourSeenKey) ?? false;
    if (seen || !mounted) return;

    final steps = <({int index, String title, String body})>[
      (
        index: 0,
        title: context.tr('tour_discover_title'),
        body: context.tr('tour_discover_body'),
      ),
      (
        index: 1,
        title: context.tr('tour_matches_title'),
        body: context.tr('tour_matches_body'),
      ),
      (
        index: 2,
        title: context.tr('tour_settings_title'),
        body: context.tr('tour_settings_body'),
      ),
    ];

    for (var i = 0; i < steps.length; i++) {
      if (!mounted) return;
      setState(() {
        _currentIndex = steps[i].index;
      });
      final proceed = await _showTourStep(
        title: steps[i].title,
        body: steps[i].body,
        isLast: i == steps.length - 1,
      );
      if (!mounted) return;
      if (!proceed) break;
    }

    await prefs.setBool(_tourSeenKey, true);
  }

  Future<bool> _showTourStep({
    required String title,
    required String body,
    required bool isLast,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(context.tr('skip')),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(context.tr(isLast ? 'done' : 'next')),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final matchesProvider = context.watch<MatchesProvider>();
    final unreadBadge = matchesProvider.unreadCountTotal();
    final pendingMatchPrompt = matchesProvider.pendingMatchPrompt;

    if (pendingMatchPrompt != null && !_isShowingMatchPrompt) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _isShowingMatchPrompt) return;
        unawaited(_showPendingMatchPrompt(pendingMatchPrompt));
      });
    }

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _tabs),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  icon: Icons.explore,
                  label: context.tr('discover'),
                  index: 0,
                  isDark: isDark,
                  colorScheme: colorScheme,
                ),
                _buildNavItem(
                  icon: Icons.chat_bubble,
                  label: context.tr('matches'),
                  index: 1,
                  badge: unreadBadge,
                  isDark: isDark,
                  colorScheme: colorScheme,
                ),
                _buildNavItem(
                  icon: Icons.settings,
                  label: context.tr('settings'),
                  index: 2,
                  isDark: isDark,
                  colorScheme: colorScheme,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showPendingMatchPrompt(MatchPrompt prompt) async {
    _isShowingMatchPrompt = true;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final colorScheme = Theme.of(dialogContext).colorScheme;
        final textTheme = Theme.of(dialogContext).textTheme;
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.favorite,
                    size: Responsive.icon(dialogContext, 58),
                    color: colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    dialogContext.tr('its_a_match'),
                    style: textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${dialogContext.tr('match_prompt_liked_each_other')} ${prompt.peerName} ${dialogContext.tr('match_prompt_start_chat')}',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.72),
                    ),
                  ),
                  const SizedBox(height: 20),
                  CircleAvatar(
                    radius: 44,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    child: ClipOval(
                      child: SizedBox.expand(
                        child: PhotoImage(
                          path: prompt.peerPhotoUrl,
                          placeholderIcon: Icons.person,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    prompt.peerName,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 30),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(dialogContext).pop(false),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(color: colorScheme.primary),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(dialogContext.tr('keep_swiping')),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(dialogContext).pop(true),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(dialogContext.tr('message_now')),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (!mounted) return;
    final matchesProvider = context.read<MatchesProvider>();
    final navigator = Navigator.of(context);
    await matchesProvider.markMatchPromptShown(prompt.matchId);
    _isShowingMatchPrompt = false;

    if (result == true) {
      setState(() {
        _currentIndex = 1;
      });
      await navigator.push(
        MaterialPageRoute(
          builder: (context) => ChatDetailScreen(
            matchName: prompt.peerName,
            matchId: prompt.matchId,
            peerUserId: prompt.peerUserId,
            matchPhotoUrl: prompt.peerPhotoUrl,
          ),
        ),
      );
    }
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
    required bool isDark,
    required ColorScheme colorScheme,
    int? badge,
  }) {
    final isSelected = _currentIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary.withValues(alpha: isDark ? 0.2 : 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.onSurface.withValues(alpha: 0.6),
                  size: Responsive.icon(context, 24),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: Responsive.font(context, 12),
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected
                        ? colorScheme.primary
                        : colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
            if (badge != null && badge > 0)
              Positioned(
                top: -4,
                right: -8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    badge > 9 ? '9+' : badge.toString(),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: Responsive.font(context, 10),
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
