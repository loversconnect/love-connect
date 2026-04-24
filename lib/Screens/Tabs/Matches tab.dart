import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lerolove/Screens/Chat%20detail%20screen.dart';
import 'package:lerolove/Screens/Main%20app%20screen.dart';
import 'package:lerolove/models/match_models.dart';
import 'package:lerolove/providers/auth_provider.dart';
import 'package:lerolove/providers/matches_provider.dart';
import 'package:lerolove/Utils/photo_image.dart';
import 'package:lerolove/Utils/responsive.dart';
import 'package:provider/provider.dart';

class MatchesTab extends StatefulWidget {
  const MatchesTab({Key? key}) : super(key: key);

  @override
  State<MatchesTab> createState() => _MatchesTabState();
}

class _MatchesTabState extends State<MatchesTab> {
  String _searchQuery = '';
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String? _statusChip;
  Timer? _statusTimer;

  @override
  void dispose() {
    _statusTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _showStatusChip(String text) {
    _statusTimer?.cancel();
    setState(() {
      _statusChip = text;
    });
    _statusTimer = Timer(const Duration(milliseconds: 1300), () {
      if (!mounted) return;
      setState(() {
        _statusChip = null;
      });
    });
  }

  void _showUnmatchConfirmation(
    BuildContext context,
    MatchThread match,
    String name,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: colorScheme.surface,
          title: Text(
            'Unmatch with $name?',
            style: TextStyle(color: colorScheme.onSurface),
          ),
          content: Text(
            'This action cannot be undone. Your conversation will be hidden.',
            style: TextStyle(color: colorScheme.onSurface.withOpacity(0.8)),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(color: colorScheme.onSurface.withOpacity(0.7)),
              ),
            ),
            TextButton(
              onPressed: () async {
                await context.read<MatchesProvider>().unmatch(match.id);
                if (!context.mounted) return;
                Navigator.of(context).pop();
                _showStatusChip('Updated');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Unmatched with $name'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Unmatch'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final auth = context.watch<AuthProvider>();
    final matchesProvider = context.watch<MatchesProvider>();
    final uid = auth.backendUserId ?? auth.uid;

    final matches = uid == null
        ? const <MatchThread>[]
        : matchesProvider.matches
              .where((match) {
                if (_searchQuery.isEmpty) return true;
                final otherId = _otherUserId(match, uid);
                return otherId.toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                );
              })
              .toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: TextStyle(color: colorScheme.onSurface),
                decoration: InputDecoration(
                  hintText: 'Search matches...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(
                    color: colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              )
            : const Text('Matches'),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _isSearching = false;
                  _searchQuery = '';
                  _searchController.clear();
                } else {
                  _isSearching = true;
                }
              });
            },
          ),
        ],
      ),
      body: uid == null
          ? _buildSignedOutState()
          : matchesProvider.isLoading
          ? _buildMatchesSkeleton()
          : RefreshIndicator(
              onRefresh: () => context.read<MatchesProvider>().refreshNow(),
              child: matchesProvider.matches.isEmpty
                  ? _buildRefreshableState(_buildEmptyState())
                  : matches.isEmpty
                  ? _buildRefreshableState(_buildNoResultsState())
                  : Column(
                      children: [
                        if (matchesProvider.isOffline)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.errorContainer.withValues(
                                alpha: 0.9,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'You are offline. We will sync when back online.',
                              style: TextStyle(
                                color: colorScheme.onErrorContainer,
                                fontWeight: FontWeight.w600,
                                fontSize: Responsive.font(context, 12),
                              ),
                            ),
                          ),
                        if (!_isSearching)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            color: colorScheme.surface,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.chat_bubble_outline,
                                  size: Responsive.icon(context, 18),
                                  color: colorScheme.onSurface.withOpacity(0.6),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${matchesProvider.matches.length} ${matchesProvider.matches.length == 1 ? 'Match' : 'Matches'}',
                                  style: TextStyle(
                                    fontSize: Responsive.font(context, 14),
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.onSurface.withOpacity(
                                      0.7,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                if (matchesProvider.syncLabel() != null)
                                  Expanded(
                                    child: Text(
                                      matchesProvider.syncLabel()!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                        fontSize: Responsive.font(context, 11),
                                        color: colorScheme.onSurface.withValues(
                                          alpha: 0.58,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        if (_statusChip != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: _buildStatusChip(_statusChip!),
                          ),
                        Expanded(
                          child: ListView.builder(
                            itemCount: matches.length,
                            itemBuilder: (context, index) {
                              final match = matches[index];
                              final otherId = _otherUserId(match, uid);
                              return _buildMatchTile(match, otherId, isDark);
                            },
                          ),
                        ),
                      ],
                    ),
            ),
    );
  }

  Widget _buildRefreshableState(Widget child) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.22),
        child,
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildMatchTile(MatchThread match, String otherUserId, bool isDark) {
    final colorScheme = Theme.of(context).colorScheme;
    final auth = context.read<AuthProvider>();
    final uid = auth.backendUserId ?? auth.uid!;
    final hasUnread = match.unreadFor(uid) > 0;

    final name = match.peerName ?? otherUserId;

    return Dismissible(
      key: Key(match.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.delete_outline,
              color: Colors.white,
              size: Responsive.icon(context, 28),
            ),
            const SizedBox(height: 4),
            Text(
              'Unmatch',
              style: TextStyle(
                color: Colors.white,
                fontSize: Responsive.font(context, 12),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        _showUnmatchConfirmation(context, match, name);
        return false;
      },
      child: InkWell(
        onTap: () async {
          await context.read<MatchesProvider>().markAsRead(match.id);
          _showStatusChip('Updated');
          if (!mounted) return;
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatDetailScreen(
                matchName: name,
                matchId: match.id,
                peerUserId: otherUserId,
                matchPhotoUrl: match.peerPhotoUrl,
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: isDark
                        ? Colors.grey[700]
                        : Colors.grey[300],
                    child: ClipOval(
                      child: SizedBox.expand(
                        child: PhotoImage(
                          path: match.peerPhotoUrl,
                          placeholderIcon: Icons.person,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: Responsive.font(context, 16),
                            fontWeight: hasUnread
                                ? FontWeight.bold
                                : FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        Text(
                          _formatTime(match.lastMessageAt),
                          style: TextStyle(
                            fontSize: Responsive.font(context, 13),
                            color: hasUnread
                                ? colorScheme.primary
                                : (isDark
                                      ? Colors.grey[500]
                                      : Colors.grey[600]),
                            fontWeight: hasUnread
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            match.lastMessage.isEmpty
                                ? 'New match. Start the conversation.'
                                : match.lastMessage,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: Responsive.font(context, 14),
                              color: hasUnread
                                  ? (isDark ? Colors.white : Colors.black87)
                                  : (isDark
                                        ? Colors.grey[400]
                                        : Colors.grey[600]),
                              fontWeight: hasUnread
                                  ? FontWeight.w500
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                        if (hasUnread) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 20,
                              minHeight: 20,
                            ),
                            child: Text(
                              match.unreadFor(uid).toString(),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: Responsive.font(context, 11),
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (match.lastMessage.isEmpty) ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton.tonalIcon(
                          onPressed: () async {
                            await context.read<MatchesProvider>().markAsRead(
                              match.id,
                            );
                            if (!mounted) return;
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChatDetailScreen(
                                  matchName: name,
                                  matchId: match.id,
                                  peerUserId: otherUserId,
                                  matchPhotoUrl: match.peerPhotoUrl,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.chat_bubble_outline),
                          label: const Text('Start Chat'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _otherUserId(MatchThread match, String myUid) {
    for (final id in match.userIds) {
      if (id != myUid) return id;
    }
    return match.userIds.isNotEmpty ? match.userIds.first : '';
  }

  String _formatTime(DateTime? timestamp) {
    if (timestamp == null) return '';
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h';
    } else {
      return '${timestamp.day}/${timestamp.month}';
    }
  }

  Widget _buildSignedOutState() {
    return Center(
      child: Text(
        'Sign in to view matches',
        style: TextStyle(fontSize: Responsive.font(context, 16)),
      ),
    );
  }

  Widget _buildEmptyState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: Responsive.icon(context, 80),
            color: isDark ? Colors.grey[700] : Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No matches yet',
            style: TextStyle(
              fontSize: Responsive.font(context, 20),
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey[400] : Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Keep swiping to find your match!',
            style: TextStyle(
              fontSize: Responsive.font(context, 15),
              color: isDark ? Colors.grey[600] : Colors.grey[500],
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const MainAppScreen()),
              );
            },
            icon: const Icon(Icons.explore),
            label: const Text('Go to Discover'),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: Responsive.icon(context, 80),
            color: isDark ? Colors.grey[700] : Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No matches found',
            style: TextStyle(
              fontSize: Responsive.font(context, 20),
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey[400] : Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String text) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
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

  Widget _buildMatchesSkeleton() {
    final colorScheme = Theme.of(context).colorScheme;
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: 6,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        color: colorScheme.outlineVariant.withValues(alpha: 0.2),
      ),
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.7,
                  ),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _skeletonLine(120, 14, colorScheme),
                    const SizedBox(height: 8),
                    _skeletonLine(double.infinity, 12, colorScheme),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _skeletonLine(double width, double height, ColorScheme colorScheme) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}
