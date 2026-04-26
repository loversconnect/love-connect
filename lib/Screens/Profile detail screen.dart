import 'package:flutter/material.dart';
import 'package:lerolove/Utils/app_i18n.dart';
import 'package:lerolove/Utils/responsive.dart';
import 'package:lerolove/Utils/photo_image.dart';
import 'package:lerolove/providers/matches_provider.dart';
import 'package:lerolove/providers/moderation_provider.dart';
import 'package:provider/provider.dart';

class ProfileDetailScreen extends StatefulWidget {
  final String name;
  final int age;
  final int distance;
  final String bio;
  final bool isOnline;
  final List<String> photos;
  final String userId;
  final String? matchId;

  const ProfileDetailScreen({
    Key? key,
    required this.name,
    required this.age,
    required this.distance,
    required this.bio,
    required this.userId,
    this.matchId,
    this.isOnline = false,
    this.photos = const <String>[],
  }) : super(key: key);

  @override
  State<ProfileDetailScreen> createState() => _ProfileDetailScreenState();
}

class _ProfileDetailScreenState extends State<ProfileDetailScreen> {
  final PageController _pageController = PageController();
  int _currentPhotoIndex = 0;
  bool _isModerationBusy = false;
  int get _totalPhotos => widget.photos.isEmpty ? 1 : widget.photos.length;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onLike() {
    Navigator.pop(context, true); // Return true for like
  }

  void _onPass() {
    Navigator.pop(context, false); // Return false for pass
  }

  void _showReportDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String? selectedReason;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('${context.tr('report')} ${widget.name}'),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.tr('why_reporting_profile')),
                  const SizedBox(height: 16),
                  _buildReportOption(context.tr('inappropriate_photos'), selectedReason, (
                    value,
                  ) {
                    setState(() => selectedReason = value);
                  }),
                  _buildReportOption(context.tr('harassment'), selectedReason, (value) {
                    setState(() => selectedReason = value);
                  }),
                  _buildReportOption(context.tr('fake_profile'), selectedReason, (value) {
                    setState(() => selectedReason = value);
                  }),
                  _buildReportOption(context.tr('spam'), selectedReason, (value) {
                    setState(() => selectedReason = value);
                  }),
                  _buildReportOption(context.tr('other'), selectedReason, (value) {
                    setState(() => selectedReason = value);
                  }),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(context.tr('cancel')),
                ),
                TextButton(
                  onPressed: selectedReason != null
                      ? () async {
                          if (_isModerationBusy) return;
                          setState(() {
                            _isModerationBusy = true;
                          });
                          Navigator.pop(context);
                          try {
                            await context.read<ModerationProvider>().reportUser(
                              reportedUserId: widget.userId,
                              reason: selectedReason!,
                              matchId: widget.matchId,
                            );
                            await context.read<ModerationProvider>().blockUser(
                              userId: widget.userId,
                              name: widget.name,
                            );
                            if (widget.matchId != null &&
                                widget.matchId!.isNotEmpty) {
                              try {
                                await context.read<MatchesProvider>().unmatch(
                                  widget.matchId!,
                                );
                              } catch (_) {}
                            }
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  context.tr('report_submitted_and_blocked'),
                                ),
                              ),
                            );
                            Navigator.pop(context, false);
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('${context.tr('could_not_report_prefix')}: $e')),
                            );
                          } finally {
                            if (mounted) {
                              setState(() {
                                _isModerationBusy = false;
                              });
                            }
                          }
                        }
                      : null,
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: Text(context.tr('submit_report')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildReportOption(
    String reason,
    String? selectedReason,
    Function(String?) onChanged,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return RadioListTile<String>(
      title: Text(reason),
      value: reason,
      groupValue: selectedReason,
      onChanged: onChanged,
      activeColor: colorScheme.primary,
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }

  void _showBlockDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('${context.tr('block')} ${widget.name}?'),
          content: Text(context.tr('block_confirm_body')),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.tr('cancel')),
            ),
            TextButton(
              onPressed: () async {
                if (_isModerationBusy) return;
                setState(() {
                  _isModerationBusy = true;
                });
                Navigator.pop(context);
                try {
                  await context.read<ModerationProvider>().blockUser(
                    userId: widget.userId,
                    name: widget.name,
                  );
                  if (widget.matchId != null && widget.matchId!.isNotEmpty) {
                    try {
                      await context.read<MatchesProvider>().unmatch(
                        widget.matchId!,
                      );
                    } catch (_) {}
                  }
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${widget.name} ${context.tr('user_blocked_suffix')}')),
                  );
                  Navigator.pop(context, false);
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${context.tr('could_not_block_user_prefix')}: $e')),
                  );
                } finally {
                  if (mounted) {
                    setState(() {
                      _isModerationBusy = false;
                    });
                  }
                }
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text(context.tr('block')),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Stack(
        children: [
          // Photo Gallery
          PageView.builder(
            controller: _pageController,
            itemCount: _totalPhotos,
            onPageChanged: (index) {
              setState(() {
                _currentPhotoIndex = index;
              });
            },
            itemBuilder: (context, index) {
              final photoPath = widget.photos.isNotEmpty
                  ? widget.photos[index]
                  : null;
              return Container(
                color: colorScheme.surfaceVariant,
                child: PhotoImage(
                  path: photoPath,
                  placeholderIcon: Icons.person,
                ),
              );
            },
          ),
          // Gradient Overlay
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
                  colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                ),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          widget.name,
                          style: TextStyle(
                            fontSize: Responsive.font(context, 32),
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${widget.age}',
                          style: TextStyle(
                            fontSize: Responsive.font(context, 28),
                            color: Colors.white,
                          ),
                        ),
                        if (widget.isOnline) ...[
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2E8B57),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              context.tr('online'),
                              style: TextStyle(
                                fontSize: Responsive.font(context, 12),
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          color: Colors.white70,
                          size: Responsive.icon(context, 18),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${widget.distance} ${context.tr('km_away_suffix')}',
                          style: TextStyle(
                            fontSize: Responsive.font(context, 16),
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.bio,
                      style: TextStyle(
                        fontSize: Responsive.font(context, 16),
                        color: Colors.white,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Top Bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Back Button
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.4),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    // Menu Button
                    PopupMenuButton(
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.4),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.more_vert, color: Colors.white),
                      ),
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'report',
                          child: Row(
                            children: [
                              Icon(Icons.flag, color: Colors.red),
                              SizedBox(width: 12),
                              Text(context.tr('report')),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'block',
                          child: Row(
                            children: [
                              Icon(Icons.block, color: Colors.red),
                              SizedBox(width: 12),
                              Text(context.tr('block')),
                            ],
                          ),
                        ),
                      ],
                      onSelected: (value) {
                        if (value == 'report') {
                          _showReportDialog();
                        } else if (value == 'block') {
                          _showBlockDialog();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Photo Indicators
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: List.generate(_totalPhotos, (index) {
                    return Expanded(
                      child: Container(
                        height: 3,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: index == _currentPhotoIndex
                              ? Colors.white
                              : Colors.white.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
          // Action Buttons
          Positioned(
            bottom: 120,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Pass Button
                GestureDetector(
                  onTap: _onPass,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.close,
                      color: Colors.red,
                      size: Responsive.icon(context, 30),
                    ),
                  ),
                ),
                const SizedBox(width: 32),
                // Like Button
                GestureDetector(
                  onTap: _onLike,
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.favorite,
                      color: colorScheme.primary,
                      size: Responsive.icon(context, 35),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
