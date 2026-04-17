import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lerolove/Screens/Profile%20detail%20screen.dart';
import 'package:lerolove/Screens/Discovery%20settings%20screen.dart';
import 'package:lerolove/Screens/Chat%20detail%20screen.dart';
import 'package:lerolove/models/user_profile.dart';
import 'package:lerolove/providers/discovery_provider.dart';
import 'package:lerolove/providers/matches_provider.dart';
import 'package:lerolove/Utils/responsive.dart';

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

  @override
  void initState() {
    super.initState();
    _swipeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
  }

  @override
  void dispose() {
    _swipeController?.dispose();
    super.dispose();
  }

  void _dismissSwipeHint() {
    if (!_showSwipeHint) return;
    setState(() {
      _showSwipeHint = false;
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
      discovery.likeProfile(currentProfile).then((matchId) {
        if (!mounted) return;
        if (matchId != null) {
          context.read<MatchesProvider>().registerMatch(
            matchId: matchId,
            peerUserId: currentProfile.id,
            peerName: currentProfile.name,
          );
          _showMessagePrompt(currentProfile, matchId);
        }
      });
    } else {
      discovery.passProfile(currentProfile.id);
    }
  }

  Future<void> _openProfileDetail(UserProfile profile) async {
    final discovery = context.read<DiscoveryProvider>();
    _dismissSwipeHint();
    final action = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileDetailScreen(
          name: profile.name,
          age: profile.age,
          distance: discovery.distanceFromCurrent(profile).round(),
          bio: profile.bio,
          isOnline: profile.isOnline,
        ),
      ),
    );

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
                    'Like Sent',
                    style: textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start a conversation with ${profile.name}',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onBackground.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 20),
                  CircleAvatar(
                    radius: 44,
                    backgroundColor: colorScheme.surfaceVariant,
                    child: Text(
                      profile.name[0],
                      style: TextStyle(
                        fontSize: Responsive.font(context, 24),
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
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
                          child: const Text('Keep Swiping'),
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
                          child: const Text('Message Now'),
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

  Widget _buildMatchAvatar(String initial) {
    return CircleAvatar(
      radius: 40,
      backgroundColor: Colors.grey[300],
      child: Text(
        initial,
        style: TextStyle(
          fontSize: Responsive.font(context, 24),
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final discovery = context.watch<DiscoveryProvider>();
    final profiles = discovery.discoverProfiles;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(
              Icons.favorite,
              color: colorScheme.primary,
              size: Responsive.icon(context, 28),
            ),
            const SizedBox(width: 8),
            const Text('LoversConnect'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Discovery Settings',
            onPressed: _openDiscoverySettings,
          ),
        ],
      ),
      body: profiles.isEmpty
          ? _buildEmptyState()
          : Column(
              children: [
                _buildSortRow(discovery),
                Expanded(
                  child: Stack(
                    children: [
                      if (profiles.length > 1)
                        Positioned.fill(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: RepaintBoundary(
                              child: _buildProfileCard(profiles[1], discovery),
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
                            final direction = _dragDistance >= 0 ? 1 : -1;

                            if (shouldSwipe) {
                              final screenWidth = MediaQuery.of(
                                context,
                              ).size.width;
                              _animateSwipeTo(
                                direction * (screenWidth + 120),
                                onComplete: () => _onSwipe(direction > 0),
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
                            duration: const Duration(milliseconds: 300),
                            opacity: _showSwipeHint ? 1 : 0,
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.surface.withOpacity(0.92),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: colorScheme.primary.withOpacity(0.2),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.06),
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
                                      size: Responsive.icon(context, 18),
                                      color: colorScheme.primary,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Swipe right to Like · left to Pass',
                                      style: TextStyle(
                                        fontSize: Responsive.font(context, 12),
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
                                        ? colorScheme.primary.withOpacity(0.9)
                                        : Colors.red.withValues(alpha: 0.9),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 3,
                                    ),
                                  ),
                                  child: Text(
                                    _dragDistance > 0 ? 'LIKE' : 'NOPE',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: Responsive.font(context, 32),
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        bottom: 40,
                        left: 0,
                        right: 0,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildActionButton(
                                  icon: Icons.close,
                                  color: Colors.red,
                                  onTap: () => _onSwipe(false),
                                  size: Responsive.icon(context, 60),
                                  label: 'Pass',
                                ),
                                const SizedBox(width: 40),
                                _buildActionButton(
                                  icon: Icons.favorite,
                                  color: colorScheme.primary,
                                  onTap: () => _onSwipe(true),
                                  size: Responsive.icon(context, 70),
                                  label: 'Like',
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap or swipe',
                              style: TextStyle(
                                fontSize: Responsive.font(context, 12),
                                color: colorScheme.onSurface.withOpacity(0.6),
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
    );
  }

  Widget _buildSortRow(DiscoveryProvider discovery) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          ChoiceChip(
            label: const Text('Nearby First'),
            selected: discovery.discoverSortMode == DiscoverSortMode.nearby,
            onSelected: (_) => discovery.updateDiscoverySettings(
              interestedInValue: discovery.interestedIn,
              ageRangeValue: discovery.ageRange,
              maxDistanceKmValue: discovery.maxDistanceKm,
              showOnlineOnlyValue: discovery.showOnlineOnly,
              verifiedProfilesOnlyValue: discovery.verifiedProfilesOnly,
              discoverSortModeValue: DiscoverSortMode.nearby,
            ),
          ),
          const SizedBox(width: 10),
          ChoiceChip(
            label: const Text('Best Relation'),
            selected: discovery.discoverSortMode == DiscoverSortMode.bestMatch,
            onSelected: (_) => discovery.updateDiscoverySettings(
              interestedInValue: discovery.interestedIn,
              ageRangeValue: discovery.ageRange,
              maxDistanceKmValue: discovery.maxDistanceKm,
              showOnlineOnlyValue: discovery.showOnlineOnly,
              verifiedProfilesOnlyValue: discovery.verifiedProfilesOnly,
              discoverSortModeValue: DiscoverSortMode.bestMatch,
            ),
          ),
          const Spacer(),
          Text(
            '${discovery.estimatedMatches} nearby',
            style: TextStyle(
              fontSize: Responsive.font(context, 13),
              fontWeight: FontWeight.w600,
              color: colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard(UserProfile profile, DiscoveryProvider discovery) {
    final colorScheme = Theme.of(context).colorScheme;
    final score = discovery.compatibilityScore(profile);
    final distance = discovery.distanceFromCurrent(profile).round();
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
              child: Center(
                child: Icon(
                  Icons.person,
                  size: Responsive.icon(context, 120),
                  color: colorScheme.onSurface.withOpacity(0.35),
                ),
              ),
            ),
            Positioned(
              top: 16,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.92),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '$score% relation',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: Responsive.font(context, 12),
                    fontWeight: FontWeight.w700,
                  ),
                ),
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
                          '${profile.age}',
                          style: TextStyle(
                            fontSize: Responsive.font(context, 24),
                            color: Colors.white,
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
                          '$distance km away',
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
              child: GestureDetector(
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: Responsive.icon(context, 80),
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No more nearby profiles',
            style: TextStyle(
              fontSize: Responsive.font(context, 20),
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try expanding your distance or age range',
            style: TextStyle(
              fontSize: Responsive.font(context, 15),
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () =>
                context.read<DiscoveryProvider>().resetDiscoverQueue(),
            icon: const Icon(Icons.refresh),
            label: const Text('Reload Nearby'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}
