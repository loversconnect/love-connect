import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:lerolove/Screens/Profile%20detail%20screen.dart';
import 'package:lerolove/Screens/Discovery%20settings%20screen.dart';
import 'package:lerolove/Screens/Chat%20detail%20screen.dart';
import 'package:lerolove/models/user_profile.dart';
import 'package:lerolove/Utils/photo_image.dart';
import 'package:lerolove/providers/discovery_provider.dart';
import 'package:lerolove/providers/matches_provider.dart';
import 'package:lerolove/Utils/app_i18n.dart';
import 'package:lerolove/Utils/responsive.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DiscoverTab extends StatefulWidget {
  const DiscoverTab({Key? key}) : super(key: key);

  @override
  State<DiscoverTab> createState() => _DiscoverTabState();
}

class _DiscoverTabState extends State<DiscoverTab>
    with SingleTickerProviderStateMixin {
  double _dragDistance = 0;
  bool _showSwipeHint = true;
  AnimationController? _swipeController;
  Animation<double>? _swipeAnimation;
  bool _isAnimatingOut = false;
  bool _isViewingProfileDetails = false;
  String? _actionChipLabel;
  Timer? _actionChipTimer;
  String? _lastPrecachedImage;
  bool _locationHintShownThisRun = false;

  @override
  void initState() {
    super.initState();
    _swipeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _restoreHints();
  }

  @override
  void dispose() {
    _actionChipTimer?.cancel();
    _swipeController?.dispose();
    super.dispose();
  }

  Future<void> _restoreHints() async {
    final prefs = await SharedPreferences.getInstance();
    final dismissed = prefs.getBool('discover_swipe_hint_seen') ?? false;
    if (!mounted) return;
    setState(() {
      _showSwipeHint = !dismissed;
    });
  }

  void _dismissSwipeHint() {
    if (!_showSwipeHint) return;
    setState(() {
      _showSwipeHint = false;
    });
    SharedPreferences.getInstance().then(
      (prefs) => prefs.setBool('discover_swipe_hint_seen', true),
    );
  }

  void _showActionChip(String label) {
    _actionChipTimer?.cancel();
    setState(() {
      _actionChipLabel = label;
    });
    _actionChipTimer = Timer(const Duration(milliseconds: 1450), () {
      if (!mounted) return;
      setState(() {
        _actionChipLabel = null;
      });
    });
  }

  void _animateSwipeTo(double target, {VoidCallback? onComplete}) {
    _swipeController ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _swipeController!.stop();
    _swipeController!.reset();
    _isAnimatingOut = target != 0;
    _swipeAnimation =
        Tween<double>(begin: _dragDistance, end: target).animate(
          CurvedAnimation(
            parent: _swipeController!,
            curve: Curves.easeOutCubic,
          ),
        )..addListener(() {
          setState(() {
            _dragDistance = _swipeAnimation!.value;
          });
        });

    _swipeController!.forward().whenComplete(() {
      if (target == 0) {
        setState(() {
          _dragDistance = 0;
          _isAnimatingOut = false;
        });
      }
      if (onComplete != null) {
        onComplete();
      }
    });
  }

  void _onSwipe(bool liked) {
    final discovery = context.read<DiscoveryProvider>();
    final profiles = discovery.discoverProfiles;
    if (profiles.isEmpty) return;

    final currentProfile = profiles.first;
    setState(() {
      _dragDistance = 0;
      _isAnimatingOut = false;
    });
    _dismissSwipeHint();

    if (liked) {
      discovery.likeProfile(currentProfile).then((result) {
        if (!mounted) return;
        if (result != null &&
            result.isMatch &&
            (result.matchId?.isNotEmpty ?? false)) {
          final matchId = result.matchId!;
          final peerId = (result.peerUserId?.isNotEmpty ?? false)
              ? result.peerUserId!
              : currentProfile.id;
          final peerName = (result.peerName?.isNotEmpty ?? false)
              ? result.peerName!
              : currentProfile.name;
          final peerPhoto = (result.peerPhotoUrl?.isNotEmpty ?? false)
              ? result.peerPhotoUrl
              : (currentProfile.photoUrls.isNotEmpty
                    ? currentProfile.photoUrls.first
                    : null);

          context.read<MatchesProvider>().registerMatch(
            matchId: matchId,
            peerUserId: peerId,
            peerName: peerName,
            peerPhotoUrl: peerPhoto,
            queuePrompt: false,
          );
          context.read<MatchesProvider>().markMatchPromptShown(matchId);
          _showActionChip(context.tr('saved'));
          _showMessagePrompt(currentProfile, matchId);
        } else {
          final errorText = discovery.error;
          if (errorText != null && errorText.trim().isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.trError(errorText)),
                backgroundColor: Colors.redAccent,
              ),
            );
            return;
          }
          _showActionChip(context.tr('saved'));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${context.tr('like_sent_to_prefix')} ${currentProfile.name}',
              ),
              duration: const Duration(milliseconds: 1400),
            ),
          );
        }
      });
    } else {
      _showActionChip(context.tr('saved'));
      discovery.passProfile(currentProfile.id);
    }
  }

  Future<void> _openProfileDetail(UserProfile profile) async {
    final discovery = context.read<DiscoveryProvider>();
    final existingMatch = context.read<MatchesProvider>().matchForPeer(
      profile.id,
    );
    _dismissSwipeHint();
    setState(() {
      _isViewingProfileDetails = true;
    });
    final action = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileDetailScreen(
          name: profile.name,
          age: profile.age,
          distance: discovery.isDistanceHidden(profile)
              ? 0
              : discovery.distanceFromCurrent(profile).round(),
          bio: profile.bio,
          userId: profile.id,
          matchId: existingMatch?.id,
          isOnline: profile.isOnline,
          photos: profile.photoUrls,
        ),
      ),
    );
    if (mounted) {
      setState(() {
        _isViewingProfileDetails = false;
      });
    }

    if (!mounted || action == null) return;
    _onSwipe(action);
  }

  void _openDiscoverySettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DiscoverySettingsScreen()),
    );
  }

  void _showMessagePrompt(UserProfile profile, String matchId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final colorScheme = Theme.of(context).colorScheme;
        final textTheme = Theme.of(context).textTheme;
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
                    size: Responsive.icon(context, 58),
                    color: colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.tr('its_a_match'),
                    style: textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${context.tr('match_prompt_liked_each_other')} ${profile.name} ${context.tr('match_prompt_start_chat')}',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onBackground.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 20),
                  CircleAvatar(
                    radius: 44,
                    backgroundColor: colorScheme.surfaceVariant,
                    child: ClipOval(
                      child: SizedBox.expand(
                        child: PhotoImage(
                          path: profile.photoUrls.isNotEmpty
                              ? profile.photoUrls.first
                              : null,
                          placeholderIcon: Icons.person,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    profile.name,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 30),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(color: colorScheme.primary),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(context.tr('keep_swiping')),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChatDetailScreen(
                                  matchName: profile.name,
                                  matchId: matchId,
                                  peerUserId: profile.id,
                                  matchPhotoUrl: profile.photoUrls.isNotEmpty
                                      ? profile.photoUrls.first
                                      : null,
                                ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(context.tr('message_now')),
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
  }

  Future<void> _openChatForProfile(UserProfile profile) async {
    final match = context.read<MatchesProvider>().matchForPeer(profile.id);
    if (match == null) return;

    await context.read<MatchesProvider>().markAsRead(match.id);
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatDetailScreen(
          matchName: match.peerName ?? profile.name,
          matchId: match.id,
          peerUserId: profile.id,
          matchPhotoUrl:
              match.peerPhotoUrl ??
              (profile.photoUrls.isNotEmpty ? profile.photoUrls.first : null),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final discovery = context.watch<DiscoveryProvider>();
    final matchesProvider = context.watch<MatchesProvider>();
    final profiles = discovery.discoverProfiles;
    _precacheNextCardImage(profiles);
    _maybeShowLocationHint(discovery.error);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/icons/app_icon.png',
                width: Responsive.icon(context, 28),
                height: Responsive.icon(context, 28),
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 8),
            Text(context.tr('app_name')),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: context.tr('discovery_settings'),
            onPressed: _openDiscoverySettings,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<DiscoveryProvider>().refreshProfiles(),
        child: LayoutBuilder(
          builder: (context, constraints) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(
                height: constraints.maxHeight,
                child: discovery.isLoading && profiles.isEmpty
                    ? _buildDiscoverSkeleton()
                    : profiles.isEmpty
                    ? _buildEmptyState(discovery)
                    : Column(
                        children: [
                          if (discovery.isOffline)
                            _buildOfflineBanner(discovery.queuedActionsCount),
                          _buildSortRow(discovery),
                          Expanded(
                            child: Stack(
                              children: [
                                if (profiles.length > 1)
                                  Positioned.fill(
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: RepaintBoundary(
                                        child: _buildProfileCard(
                                          profiles[1],
                                          discovery,
                                          matchesProvider,
                                        ),
                                      ),
                                    ),
                                  ),
                                Positioned.fill(
                                  child: GestureDetector(
                                    onPanUpdate: (details) {
                                      _dismissSwipeHint();
                                      if (_isAnimatingOut) return;
                                      setState(() {
                                        _dragDistance += details.delta.dx;
                                      });
                                    },
                                    onPanEnd: (details) {
                                      if (_isAnimatingOut) return;
                                      final velocity =
                                          details.velocity.pixelsPerSecond.dx;
                                      final shouldSwipe =
                                          _dragDistance.abs() > 100 ||
                                          velocity.abs() > 800;
                                      final direction = _dragDistance >= 0
                                          ? 1
                                          : -1;

                                      if (shouldSwipe) {
                                        final screenWidth = MediaQuery.of(
                                          context,
                                        ).size.width;
                                        _animateSwipeTo(
                                          direction * (screenWidth + 120),
                                          onComplete: () =>
                                              _onSwipe(direction > 0),
                                        );
                                      } else {
                                        _animateSwipeTo(0);
                                      }
                                    },
                                    child: Transform.translate(
                                      offset: Offset(_dragDistance, 0),
                                      child: Transform.rotate(
                                        angle: _dragDistance / 1000,
                                        child: Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: RepaintBoundary(
                                            child: _buildProfileCard(
                                              profiles.first,
                                              discovery,
                                              matchesProvider,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 16,
                                  left: 0,
                                  right: 0,
                                  child: IgnorePointer(
                                    child: AnimatedOpacity(
                                      duration: const Duration(
                                        milliseconds: 300,
                                      ),
                                      opacity: _showSwipeHint ? 1 : 0,
                                      child: Center(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: colorScheme.surface
                                                .withOpacity(0.92),
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                            border: Border.all(
                                              color: colorScheme.primary
                                                  .withOpacity(0.2),
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(
                                                  0.06,
                                                ),
                                                blurRadius: 12,
                                                offset: const Offset(0, 6),
                                              ),
                                            ],
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.swipe,
                                                size: Responsive.icon(
                                                  context,
                                                  18,
                                                ),
                                                color: colorScheme.primary,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                context.tr('swipe_right_like_left_pass'),
                                                style: TextStyle(
                                                  fontSize: Responsive.font(
                                                    context,
                                                    12,
                                                  ),
                                                  fontWeight: FontWeight.w600,
                                                  color: colorScheme.onSurface,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                if (_dragDistance.abs() > 20)
                                  Positioned.fill(
                                    child: IgnorePointer(
                                      child: Center(
                                        child: Transform.rotate(
                                          angle: -0.2,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 24,
                                              vertical: 12,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _dragDistance > 0
                                                  ? colorScheme.primary
                                                        .withOpacity(0.9)
                                                  : Colors.red.withValues(
                                                      alpha: 0.9,
                                                    ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color: Colors.white,
                                                width: 3,
                                              ),
                                            ),
                                            child: Text(
                                              _dragDistance > 0
                                                  ? context.tr('like_big')
                                                  : context.tr('nope_big'),
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: Responsive.font(
                                                  context,
                                                  32,
                                                ),
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 2,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                if (!_isViewingProfileDetails)
                                  Positioned(
                                    bottom: 40,
                                    left: 0,
                                    right: 0,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (_actionChipLabel != null)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 8,
                                            ),
                                            child: _buildActionChip(
                                              _actionChipLabel!,
                                            ),
                                          ),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            _buildActionButton(
                                              icon: Icons.close,
                                              color: Colors.red,
                                              onTap: () => _onSwipe(false),
                                              size: Responsive.icon(
                                                context,
                                                60,
                                              ),
                                              label: context.tr('pass'),
                                            ),
                                            const SizedBox(width: 40),
                                            matchesProvider.hasActiveMatchWith(
                                                  profiles.first.id,
                                                )
                                                ? _buildActionButton(
                                                    icon: Icons.chat_bubble,
                                                    color: colorScheme.primary,
                                                    onTap: () =>
                                                        _openChatForProfile(
                                                          profiles.first,
                                                        ),
                                                    size: Responsive.icon(
                                                      context,
                                                      70,
                                                    ),
                                                    label: context.tr('message'),
                                                  )
                                                : _buildActionButton(
                                                    icon: Icons.favorite,
                                                    color: colorScheme.primary,
                                                    onTap: () => _onSwipe(true),
                                                    size: Responsive.icon(
                                                      context,
                                                      70,
                                                    ),
                                                    label: context.tr('like_big'),
                                                  ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          context.tr('tap_or_swipe'),
                                          style: TextStyle(
                                            fontSize: Responsive.font(
                                              context,
                                              12,
                                            ),
                                            color: colorScheme.onSurface
                                                .withOpacity(0.6),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _precacheNextCardImage(List<UserProfile> profiles) {
    if (!mounted || profiles.length < 2) return;
    final path = profiles[1].photoUrls.isNotEmpty
        ? profiles[1].photoUrls.first
        : '';
    if (path.isEmpty || path == _lastPrecachedImage) return;
    _lastPrecachedImage = path;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (path.startsWith('http://') || path.startsWith('https://')) {
        precacheImage(NetworkImage(path), context);
        return;
      }
      if (!kIsWeb) {
        precacheImage(FileImage(File(path)), context);
      }
    });
  }

  Future<void> _maybeShowLocationHint(String? errorText) async {
    if (_locationHintShownThisRun) return;
    if (!AppI18n.isLocationError(errorText)) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final shown = prefs.getBool('hint_location_required_shown') ?? false;
    if (shown || !mounted) return;
    _locationHintShownThisRun = true;
    await prefs.setBool('hint_location_required_shown', true);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.tr('discover_location_hint')),
        duration: Duration(seconds: 3),
      ),
    );
  }

  Widget _buildActionChip(String text) {
    final colorScheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w700,
          fontSize: Responsive.font(context, 12),
        ),
      ),
    );
  }

  Widget _buildOfflineBanner(int queuedCount) {
    final colorScheme = Theme.of(context).colorScheme;
    final queuedText = queuedCount > 0
        ? '${context.tr('queued_actions_prefix')} $queuedCount ${queuedCount == 1 ? context.tr('queued_action_single') : context.tr('queued_action_plural')}'
        : context.tr('offline_sync');
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        queuedCount > 0 ? '${context.tr('offline_sync')} $queuedText' : queuedText,
        style: TextStyle(
          color: colorScheme.onErrorContainer,
          fontWeight: FontWeight.w600,
          fontSize: Responsive.font(context, 12),
        ),
      ),
    );
  }

  Widget _buildSyncingChip() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            context.tr('syncing'),
            style: TextStyle(
              color: colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w700,
              fontSize: Responsive.font(context, 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortRow(DiscoveryProvider discovery) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          ChoiceChip(
            label: Text(
              context.tr('nearby_first'),
              style: TextStyle(
                color: discovery.discoverSortMode == DiscoverSortMode.nearby
                    ? Colors.white
                    : colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            selected: discovery.discoverSortMode == DiscoverSortMode.nearby,
            showCheckmark: true,
            checkmarkColor: colorScheme.onPrimary,
            onSelected: (_) => discovery.setSortMode(DiscoverSortMode.nearby),
          ),
          const SizedBox(width: 10),
          ChoiceChip(
            label: Text(
              context.tr('best_relation'),
              style: TextStyle(
                color: discovery.discoverSortMode == DiscoverSortMode.bestMatch
                    ? Colors.white
                    : colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            selected: discovery.discoverSortMode == DiscoverSortMode.bestMatch,
            showCheckmark: true,
            checkmarkColor: colorScheme.onPrimary,
            onSelected: (_) =>
                discovery.setSortMode(DiscoverSortMode.bestMatch),
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (discovery.isSyncing)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: _buildSyncingChip(),
                ),
              Text(
                '${discovery.estimatedMatches} ${context.tr('nearby_count_suffix')}',
                style: TextStyle(
                  fontSize: Responsive.font(context, 13),
                  fontWeight: FontWeight.w600,
                  color: colorScheme.primary,
                ),
              ),
              if (discovery.syncLabel() != null)
                Text(
                  discovery.syncLabel()!,
                  style: TextStyle(
                    fontSize: Responsive.font(context, 11),
                    color: colorScheme.onSurface.withValues(alpha: 0.65),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard(
    UserProfile profile,
    DiscoveryProvider discovery,
    MatchesProvider matchesProvider,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final score = discovery.compatibilityScore(profile);
    final hiddenDistance = discovery.isDistanceHidden(profile);
    final distance = discovery.distanceFromCurrent(profile).round();
    final existingMatch = matchesProvider.matchForPeer(profile.id);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Container(
              color: colorScheme.surfaceVariant,
              child: PhotoImage(
                path: profile.photoUrls.isNotEmpty
                    ? profile.photoUrls.first
                    : null,
                placeholderIcon: Icons.person,
              ),
            ),
            Positioned(
              top: 16,
              left: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withOpacity(0.92),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '$score% ${context.tr('relation_suffix')}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: Responsive.font(context, 12),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (existingMatch != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.94),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.favorite,
                            color: colorScheme.primary,
                            size: Responsive.icon(context, 14),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            context.tr('matched'),
                            style: TextStyle(
                              color: colorScheme.primary,
                              fontSize: Responsive.font(context, 12),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _buildDiscoverReasons(
                      profile,
                      discovery,
                      hiddenDistance,
                      distance,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: Responsive.pagePadding(context),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.8),
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            profile.name,
                            style: TextStyle(
                              fontSize: Responsive.font(context, 28),
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${context.tr('age_prefix')} ${profile.age}',
                          style: TextStyle(
                            fontSize: Responsive.font(context, 18),
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (profile.isOnline) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.greenAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          color: Colors.white70,
                          size: Responsive.icon(context, 16),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          hiddenDistance
                              ? context.tr('distance_hidden')
                              : '$distance ${context.tr('km_away_suffix')}',
                          style: TextStyle(
                            fontSize: Responsive.font(context, 15),
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(width: 10),
                        if (profile.isVerified)
                          Icon(
                            Icons.verified,
                            color: Colors.lightBlueAccent,
                            size: Responsive.icon(context, 16),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      profile.bio,
                      style: TextStyle(
                        fontSize: Responsive.font(context, 15),
                        color: Colors.white,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: profile.interests
                          .take(3)
                          .map(
                            (interest) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                interest,
                                style: TextStyle(
                                  fontSize: Responsive.font(context, 12),
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: Column(
                children: [
                  if (existingMatch != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: FilledButton.icon(
                        onPressed: () => _openChatForProfile(profile),
                        icon: const Icon(Icons.chat_bubble_outline),
                        label: Text(context.tr('message')),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          backgroundColor: colorScheme.primary.withValues(
                            alpha: 0.95,
                          ),
                          foregroundColor: colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  GestureDetector(
                    onTap: () => _openProfileDetail(profile),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.info_outline,
                        color: colorScheme.primary,
                        size: Responsive.icon(context, 20),
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

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    double size = 60,
    String? label,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: colorScheme.surface,
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.35), width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: color, size: size * 0.5),
          ),
        ),
        if (label != null) ...[
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: Responsive.font(context, 12),
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEmptyState(DiscoveryProvider discovery) {
    final errorText = discovery.error;
    final hasError = errorText != null && errorText.trim().isNotEmpty;
    final filteredOutBySettings =
        !hasError &&
        discovery.hasBackendCandidates &&
        discovery.estimatedMatches == 0;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasError
                ? Icons.location_off_outlined
                : filteredOutBySettings
                ? Icons.filter_alt_off_outlined
                : Icons.inbox_outlined,
            size: Responsive.icon(context, 80),
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            hasError
                ? context.tr('discovery_needs_location')
                : filteredOutBySettings
                ? context.tr('no_new_profiles_title')
                : context.tr('no_more_profiles_title'),
            style: TextStyle(
              fontSize: Responsive.font(context, 20),
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasError
                ? errorText
                : filteredOutBySettings
                ? context.tr('no_profiles_fit_preferences')
                : context.tr('no_profiles_subtitle'),
            style: TextStyle(
              fontSize: Responsive.font(context, 15),
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () =>
                context.read<DiscoveryProvider>().refreshProfiles(),
            icon: const Icon(Icons.refresh),
            label: Text(context.tr('reload_nearby')),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
          if (filteredOutBySettings) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => context
                  .read<DiscoveryProvider>()
                  .resetFiltersToBroadDefaults(),
              icon: const Icon(Icons.tune),
              label: Text(context.tr('try_broader_search')),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildDiscoverReasons(
    UserProfile profile,
    DiscoveryProvider discovery,
    bool hiddenDistance,
    int distance,
  ) {
    final List<String> reasons = <String>[];
    final sharedInterests = discovery.sharedInterestCount(profile);
    if (sharedInterests > 0) {
      reasons.add('$sharedInterests ${context.tr('shared_interests')}');
    }
    if (!hiddenDistance && distance <= 10) {
      reasons.add(context.tr('near_you'));
    }
    if (profile.isOnline) {
      reasons.add(context.tr('recently_active'));
    }
    if (reasons.isEmpty) {
      reasons.add(context.tr('within_filters'));
    }
    return reasons
        .take(2)
        .map(
          (reason) => Builder(
            builder: (context) {
              final colorScheme = Theme.of(context).colorScheme;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                  ),
                ),
                child: Text(
                  reason,
                  style: TextStyle(
                    color: colorScheme.onPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: Responsive.font(context, 11),
                  ),
                ),
              );
            },
          ),
        )
        .toList(growable: false);
  }

  Widget _buildDiscoverSkeleton() {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _skeletonBar(width: 170, height: 36, color: colorScheme),
          const SizedBox(height: 14),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: colorScheme.surfaceVariant.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: 16,
                    top: 16,
                    child: _skeletonBar(
                      width: 110,
                      height: 28,
                      color: colorScheme,
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 24,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _skeletonBar(
                          width: 140,
                          height: 22,
                          color: colorScheme,
                        ),
                        const SizedBox(height: 8),
                        _skeletonBar(
                          width: 180,
                          height: 14,
                          color: colorScheme,
                        ),
                        const SizedBox(height: 8),
                        _skeletonBar(
                          width: 220,
                          height: 14,
                          color: colorScheme,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _skeletonBar({
    required double width,
    required double height,
    required ColorScheme color,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color.surfaceContainerHighest.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }
}
