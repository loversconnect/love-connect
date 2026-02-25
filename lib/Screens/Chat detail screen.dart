import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lerolove/Utils/chat_background_manager.dart';
import 'package:lerolove/Utils/responsive.dart';

class ChatDetailScreen extends StatefulWidget {
  final String matchName;
  final String matchId;

  const ChatDetailScreen({
    Key? key,
    required this.matchName,
    this.matchId = '',
  }) : super(key: key);

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isTyping = false;
  bool _showSafetyBanner = true;

  @override
  void initState() {
    super.initState();
    // Load initial demo messages
    _messages.addAll([
      ChatMessage(
        text: 'Hey! How are you doing?',
        isSent: false,
        timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
        isRead: true,
      ),
      ChatMessage(
        text: 'Hi! I\'m doing great, thanks for asking! How about you?',
        isSent: true,
        timestamp: DateTime.now().subtract(const Duration(minutes: 3)),
        isRead: true,
      ),
      ChatMessage(
        text: 'I\'m good too! Would love to know more about you 😊',
        isSent: false,
        timestamp: DateTime.now().subtract(const Duration(minutes: 1)),
        isRead: true,
      ),
    ]);
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(
        text: _messageController.text.trim(),
        isSent: true,
        timestamp: DateTime.now(),
        isRead: false,
      ));
    });

    _messageController.clear();

    // Auto-scroll to bottom
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    // Simulate typing indicator
    setState(() => _isTyping = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _isTyping = false);
    });
  }

  void _showReportDialog() {
    final colorScheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: colorScheme.surface,
          title: Text(
            'Report ${widget.matchName}',
            style: TextStyle(color: colorScheme.onSurface),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Why are you reporting this user?',
                style: TextStyle(color: colorScheme.onSurface.withOpacity(0.8)),
              ),
              const SizedBox(height: 16),
              _buildReportOption('Inappropriate photos'),
              _buildReportOption('Harassment'),
              _buildReportOption('Fake profile'),
              _buildReportOption('Spam'),
              _buildReportOption('Other'),
            ],
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildReportOption(String reason) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      title: Text(
        reason,
        style: TextStyle(color: colorScheme.onSurface),
      ),
      contentPadding: EdgeInsets.zero,
      onTap: () {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Report submitted: $reason'),
            duration: const Duration(seconds: 2),
          ),
        );
      },
    );
  }

  void _showUnmatchDialog() {
    final colorScheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: colorScheme.surface,
          title: Text(
            'Unmatch with ${widget.matchName}?',
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
                style: TextStyle(color: colorScheme.onSurface.withOpacity(0.8)),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop(); // Go back to matches list
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Unmatched with ${widget.matchName}'),
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
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: colorScheme.surfaceVariant,
              child: Text(
                widget.matchName[0],
                style: TextStyle(
                  fontSize: Responsive.font(context, 16),
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.matchName,
                    style: TextStyle(
                      fontSize: Responsive.font(context, 16),
                      color: colorScheme.onSurface,
                    ),
                  ),
                  if (_isTyping)
                    Text(
                      'typing...',
                      style: TextStyle(
                        fontSize: Responsive.font(context, 12),
                        color: colorScheme.onSurface.withOpacity(0.6),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton(
            icon: const Icon(Icons.more_vert),
            color: colorScheme.surface,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'report',
                child: Row(
                  children: [
                    Icon(
                      Icons.flag_outlined,
                      size: Responsive.icon(context, 20),
                      color: colorScheme.onSurface.withOpacity(0.7),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Report',
                      style: TextStyle(color: colorScheme.onSurface),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'unmatch',
                child: Row(
                  children: [
                    Icon(Icons.block,
                        size: Responsive.icon(context, 20),
                        color: Colors.red),
                    const SizedBox(width: 12),
                    Text(
                      'Unmatch',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'report') {
                _showReportDialog();
              } else if (value == 'unmatch') {
                _showUnmatchDialog();
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Chat background - REAL-TIME WALLPAPER
          Positioned.fill(
            child: Consumer<ChatBackgroundManager>(
              builder: (context, bgManager, child) {
                return bgManager.getBackgroundWidget(isDark);
              },
            ),
          ),

          // Chat content
          Column(
            children: [
              // Safety Banner
              if (_showSafetyBanner)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: const Color(0xFFFFF3CD).withOpacity(0.9),
                  child: Row(
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        size: Responsive.icon(context, 18),
                        color: Colors.orange[800],
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Never share personal info early. Keep conversations on the app.',
                          style: TextStyle(
                            fontSize: Responsive.font(context, 12),
                            color: Colors.orange[900],
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _showSafetyBanner = false;
                          });
                        },
                        child: const Text('Got it'),
                      ),
                    ],
                  ),
                ),

              // Messages List
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    return _buildMessage(_messages[index], isDark);
                  },
                ),
              ),

              // Typing Indicator
              if (_isTyping)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF2C2C2C)
                              : colorScheme.surfaceVariant.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildTypingDot(0),
                            const SizedBox(width: 4),
                            _buildTypingDot(200),
                            const SizedBox(width: 4),
                            _buildTypingDot(400),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              // Input Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  border: Border(
                    top: BorderSide(
                      color: colorScheme.surfaceVariant,
                      width: 1,
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          style: TextStyle(
                            color: colorScheme.onSurface,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Type a message...',
                            hintStyle: TextStyle(
                              color: colorScheme.onSurface.withOpacity(0.6),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide(
                                color: colorScheme.surfaceVariant,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide(
                                color: colorScheme.surfaceVariant,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide(
                                color: colorScheme.primary.withOpacity(0.4),
                              ),
                            ),
                            filled: true,
                            fillColor: isDark
                                ? const Color(0xFF2C2C2C)
                                : colorScheme.surfaceVariant,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          maxLines: null,
                          maxLength: 1000,
                          textCapitalization: TextCapitalization.sentences,
                          buildCounter: (context,
                              {required currentLength,
                                required isFocused,
                                maxLength}) {
                            return null; // Hide counter
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      iconSize: Responsive.icon(context, 20),
                      onPressed: _sendMessage,
                    ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(ChatMessage message, bool isDark) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
        message.isSent ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!message.isSent) ...[
            CircleAvatar(
              radius: 12,
              backgroundColor: colorScheme.surfaceVariant,
              child: Text(
                widget.matchName[0],
                style: TextStyle(
                  fontSize: Responsive.font(context, 10),
                  color: colorScheme.onSurface,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: message.isSent
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.7,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: message.isSent
                        ? colorScheme.primary
                        : (isDark
                        ? const Color(0xFF2C2C2C)
                        : colorScheme.surfaceVariant),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    message.text,
                    style: TextStyle(
                      fontSize: Responsive.font(context, 15),
                      color: message.isSent
                          ? colorScheme.onPrimary
                          : colorScheme.onSurface,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatTime(message.timestamp),
                      style: TextStyle(
                        fontSize: Responsive.font(context, 11),
                        color: colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                    if (message.isSent) ...[
                      const SizedBox(width: 4),
                      Icon(
                        message.isRead ? Icons.done_all : Icons.done,
                        size: Responsive.icon(context, 14),
                        color: message.isRead
                            ? colorScheme.primary
                            : colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingDot(int delay) {
    final colorScheme = Theme.of(context).colorScheme;
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 600 + delay),
      builder: (context, double value, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: colorScheme.onSurface.withOpacity(0.4 * value),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${timestamp.day}/${timestamp.month}';
    }
  }
}

class ChatMessage {
  final String text;
  final bool isSent;
  final DateTime timestamp;
  final bool isRead;

  ChatMessage({
    required this.text,
    required this.isSent,
    required this.timestamp,
    this.isRead = false,
  });
}
