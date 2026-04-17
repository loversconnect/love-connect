import 'package:flutter/material.dart';
import 'package:lerolove/models/match_models.dart';
import 'package:lerolove/providers/auth_provider.dart';
import 'package:lerolove/providers/matches_provider.dart';
import 'package:lerolove/providers/moderation_provider.dart';
import 'package:provider/provider.dart';
import 'package:lerolove/Utils/chat_background_manager.dart';
import 'package:lerolove/Utils/responsive.dart';

class ChatDetailScreen extends StatefulWidget {
  const ChatDetailScreen({
    Key? key,
    required this.matchName,
    required this.matchId,
    this.peerUserId,
  }) : super(key: key);

  final String matchName;
  final String matchId;
  final String? peerUserId;

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _showSafetyBanner = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MatchesProvider>().markAsRead(widget.matchId);
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    await context.read<MatchesProvider>().sendMessage(
      matchId: widget.matchId,
      text: text,
    );

    _messageController.clear();

    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  void _showReportDialog() {
    if (widget.peerUserId == null) return;
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
      title: Text(reason, style: TextStyle(color: colorScheme.onSurface)),
      contentPadding: EdgeInsets.zero,
      onTap: () async {
        Navigator.of(context).pop();
        await context.read<ModerationProvider>().reportUser(
          reportedUserId: widget.peerUserId!,
          reason: reason,
          matchId: widget.matchId,
        );
        if (!mounted) return;
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
                style: TextStyle(color: colorScheme.onSurface.withOpacity(0.8)),
              ),
            ),
            TextButton(
              onPressed: () async {
                await context.read<MatchesProvider>().unmatch(widget.matchId);
                if (!context.mounted) return;
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Unmatch'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _blockUser() async {
    if (widget.peerUserId == null) return;
    await context.read<ModerationProvider>().blockUser(
      userId: widget.peerUserId!,
      name: widget.matchName,
    );
    if (!mounted) return;
    await context.read<MatchesProvider>().unmatch(widget.matchId);
    if (!mounted) return;
    Navigator.pop(context);
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
    final auth = context.watch<AuthProvider>();
    final myUid = auth.backendUserId ?? auth.uid;

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
              child: Text(
                widget.matchName,
                style: TextStyle(
                  fontSize: Responsive.font(context, 16),
                  color: colorScheme.onSurface,
                ),
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
                value: 'block',
                child: Row(
                  children: [
                    Icon(
                      Icons.block,
                      size: Responsive.icon(context, 20),
                      color: Colors.red,
                    ),
                    const SizedBox(width: 12),
                    const Text('Block', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'unmatch',
                child: Row(
                  children: [
                    Icon(
                      Icons.remove_circle_outline,
                      size: Responsive.icon(context, 20),
                      color: Colors.red,
                    ),
                    const SizedBox(width: 12),
                    const Text('Unmatch', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'report') {
                _showReportDialog();
              } else if (value == 'block') {
                _blockUser();
              } else if (value == 'unmatch') {
                _showUnmatchDialog();
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Consumer<ChatBackgroundManager>(
              builder: (context, bgManager, child) {
                return bgManager.getBackgroundWidget(isDark);
              },
            ),
          ),
          Column(
            children: [
              if (_showSafetyBanner)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
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
              Expanded(
                child: StreamBuilder<List<ChatMessageModel>>(
                  stream: context.read<MatchesProvider>().messagesStream(
                    widget.matchId,
                  ),
                  builder: (context, snapshot) {
                    final messages =
                        snapshot.data ?? const <ChatMessageModel>[];
                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        final isSent = message.senderId == myUid;
                        return _buildMessage(
                          message: message,
                          isSent: isSent,
                          isDark: isDark,
                        );
                      },
                    );
                  },
                ),
              ),
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
                          style: TextStyle(color: colorScheme.onSurface),
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
                          buildCounter:
                              (
                                context, {
                                required currentLength,
                                required isFocused,
                                maxLength,
                              }) {
                                return null;
                              },
                          onSubmitted: (_) => _sendMessage(),
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

  Widget _buildMessage({
    required ChatMessageModel message,
    required bool isSent,
    required bool isDark,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isSent
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isSent) ...[
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
              crossAxisAlignment: isSent
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
                    color: isSent
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
                      color: isSent
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
                      _formatTime(message.sentAt),
                      style: TextStyle(
                        fontSize: Responsive.font(context, 11),
                        color: colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                    if (isSent) ...[
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

  String _formatTime(DateTime? timestamp) {
    if (timestamp == null) return 'Now';
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${timestamp.day}/${timestamp.month}';
    }
  }
}
