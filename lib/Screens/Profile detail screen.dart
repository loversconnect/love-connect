import 'package:flutter/material.dart';
import 'package:lerolove/Utils/responsive.dart';
import 'package:lerolove/Utils/photo_image.dart';

class ProfileDetailScreen extends StatefulWidget {
  final String name;
  final int age;
  final int distance;
  final String bio;
  final bool isOnline;
  final List<String> photos;

  const ProfileDetailScreen({
    Key? key,
    required this.name,
    required this.age,
    required this.distance,
    required this.bio,
    this.isOnline = false,
    this.photos = const <String>[],
  }) : super(key: key);

  @override
  State<ProfileDetailScreen> createState() => _ProfileDetailScreenState();
}

class _ProfileDetailScreenState extends State<ProfileDetailScreen> {
  final PageController _pageController = PageController();
  int _currentPhotoIndex = 0;
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
              title: Text('Report ${widget.name}'),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Why are you reporting this profile?'),
                  const SizedBox(height: 16),
                  _buildReportOption('Inappropriate photos', selectedReason, (
                    value,
                  ) {
                    setState(() => selectedReason = value);
                  }),
                  _buildReportOption('Harassment', selectedReason, (value) {
                    setState(() => selectedReason = value);
                  }),
                  _buildReportOption('Fake profile', selectedReason, (value) {
                    setState(() => selectedReason = value);
                  }),
                  _buildReportOption('Spam', selectedReason, (value) {
                    setState(() => selectedReason = value);
                  }),
                  _buildReportOption('Other', selectedReason, (value) {
                    setState(() => selectedReason = value);
                  }),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: selectedReason != null
                      ? () {
                          // In real app: Submit report to Firebase
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Report submitted. User has been blocked.',
                              ),
                              duration: Duration(seconds: 2),
                            ),
                          );
                          Navigator.pop(context); // Return to discovery
                        }
                      : null,
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Submit Report'),
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
          title: Text('Block ${widget.name}?'),
          content: const Text(
            'You will no longer see this profile and they won\'t be able to see yours.',
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                // In real app: Add to blocked list in Firebase
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${widget.name} has been blocked'),
                    duration: const Duration(seconds: 2),
                  ),
                );
                Navigator.pop(context); // Return to discovery
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Block'),
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
                              'Online',
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
                          '${widget.distance} km away',
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
                            children: const [
                              Icon(Icons.flag, color: Colors.red),
                              SizedBox(width: 12),
                              Text('Report'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'block',
                          child: Row(
                            children: const [
                              Icon(Icons.block, color: Colors.red),
                              SizedBox(width: 12),
                              Text('Block'),
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
