import 'package:flutter/material.dart';
import 'package:lerolove/Screens/Chat%20detail%20screen.dart';
import 'package:lerolove/Utils/responsive.dart';

class MatchesTab extends StatefulWidget {
  const MatchesTab({Key? key}) : super(key: key);

  @override
  State<MatchesTab> createState() => _MatchesTabState();
}

class _MatchesTabState extends State<MatchesTab> {
  // Demo matches data
  final List<Map<String, dynamic>> _matches = [
    {
      'name': 'Thandiwe',
      'id': '1',
      'lastMessage': 'I\'m good too! Would love to know more about you 😊',
      'timestamp': '1 min ago',
      'unread': 1,
      'isOnline': true,
    },
    {
      'name': 'Chisomo',
      'id': '2',
      'lastMessage': 'Would love to grab coffee ☕',
      'timestamp': '1 hour ago',
      'unread': 0,
      'isOnline': false,
    },
    {
      'name': 'Mphatso',
      'id': '3',
      'lastMessage': 'That sounds amazing!',
      'timestamp': '3 hours ago',
      'unread': 0,
      'isOnline': true,
    },
    {
      'name': 'Kondwani',
      'id': '4',
      'lastMessage': 'See you then! 😊',
      'timestamp': 'Yesterday',
      'unread': 0,
      'isOnline': false,
    },
  ];

  String _searchQuery = '';
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredMatches {
    if (_searchQuery.isEmpty) {
      return _matches;
    }
    return _matches
        .where((match) =>
        match['name'].toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  void _showUnmatchConfirmation(
      BuildContext context, String matchId, String matchName) {
    final colorScheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: colorScheme.surface,
          title: Text(
            'Unmatch with $matchName?',
            style: TextStyle(color: colorScheme.onSurface),
          ),
          content: Text(
            'This action cannot be undone. Your conversation will be deleted.',
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
              onPressed: () {
                setState(() {
                  _matches.removeWhere((item) => item['id'] == matchId);
                });
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Unmatched with $matchName'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('Unmatch'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredMatches = _filteredMatches;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

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
                color: colorScheme.onSurface.withOpacity(0.6)),
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
      body: _matches.isEmpty
          ? _buildEmptyState()
          : filteredMatches.isEmpty
          ? _buildNoResultsState()
          : Column(
        children: [
          // Match count header
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
                    '${_matches.length} ${_matches.length == 1 ? 'Match' : 'Matches'}',
                    style: TextStyle(
                      fontSize: Responsive.font(context, 14),
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          // Matches list
          Expanded(
            child: ListView.builder(
              itemCount: filteredMatches.length,
              itemBuilder: (context, index) {
                final match = filteredMatches[index];
                return _buildMatchTile(match, index);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchTile(Map<String, dynamic> match, int index) {
    final hasUnread = (match['unread'] ?? 0) > 0;
    final isOnline = match['isOnline'] ?? false;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Dismissible(
      key: Key(match['id']),
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
            SizedBox(height: 4),
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
        _showUnmatchConfirmation(context, match['id'], match['name']);
        return false;
      },
      child: InkWell(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatDetailScreen(
                matchName: match['name'],
                matchId: match['id'],
              ),
            ),
          );

          if (hasUnread) {
            setState(() {
              match['unread'] = 0;
            });
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                  color: isDark ? Colors.grey[800]! : Colors.grey[200]!, width: 1),
            ),
          ),
          child: Row(
            children: [
              // Profile Photo with Online Indicator
              Stack(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: isDark ? Colors.grey[700] : Colors.grey[300],
                    child: Text(
                      match['name'][0],
                      style: TextStyle(
                        fontSize: Responsive.font(context, 20),
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  if (isOnline)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: isDark
                                  ? const Color(0xFF121212)
                                  : Colors.white,
                              width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              // Message Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          match['name'],
                          style: TextStyle(
                            fontSize: Responsive.font(context, 16),
                            fontWeight:
                            hasUnread ? FontWeight.bold : FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        Text(
                          match['timestamp'],
                          style: TextStyle(
                            fontSize: Responsive.font(context, 13),
                            color: hasUnread
                                ? colorScheme.primary
                                : (isDark ? Colors.grey[500] : Colors.grey[600]),
                            fontWeight:
                            hasUnread ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            match['lastMessage'],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: Responsive.font(context, 14),
                              color: hasUnread
                                  ? (isDark ? Colors.white : Colors.black87)
                                  : (isDark ? Colors.grey[400] : Colors.grey[600]),
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
                              match['unread'].toString(),
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
                  ],
                ),
              ),
            ],
          ),
        ),
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
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.explore),
            label: const Text('Start Discovering'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
            ),
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
          const SizedBox(height: 8),
          Text(
            'Try a different search term',
            style: TextStyle(
              fontSize: Responsive.font(context, 15),
              color: isDark ? Colors.grey[600] : Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
}

