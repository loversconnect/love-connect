import 'package:flutter/material.dart';
import 'package:lerolove/models/match_models.dart';
import 'package:lerolove/providers/auth_provider.dart';
import 'package:lerolove/providers/matches_provider.dart';
import 'package:lerolove/providers/moderation_provider.dart';
import 'package:lerolove/Utils/app_feedback.dart';
import 'package:lerolove/Utils/app_i18n.dart';
import 'package:provider/provider.dart';
import 'package:lerolove/Utils/chat_background_manager.dart';
import 'package:lerolove/Utils/responsive.dart';
import 'package:lerolove/Utils/photo_image.dart';

class ChatDetailScreen extends StatefulWidget {
  const ChatDetailScreen({
    Key? key,
    required this.matchName,
    required this.matchId,
    this.peerUserId,
    this.matchPhotoUrl,
  }) : super(key: key);

  final String matchName;
  final String matchId;
  final String? peerUserId;
  final String? matchPhotoUrl;

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _showSafetyBanner = true;
  bool _isSending = false;
  bool _historyHydrationDone = false;
  DateTime? _lastAutoRefreshAt;
  bool? _lastOfflineState;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MatchesProvider>().markAsRead(widget.matchId);
      _hydrateConversation();
    });
  }

  Future<void> _hydrateConversation() async {
    final now = DateTime.now();
    if (_lastAutoRefreshAt != null &&
        now.difference(_lastAutoRefreshAt!).inSeconds < 2) {
      return;
    }
    _lastAutoRefreshAt = now;
    try {
      await context.read<MatchesProvider>().refreshConversation(widget.matchId);
    } catch (_) {
      // Ignore; UI handles offline and retry states.
    } finally {
      if (mounted) {
        setState(() {
          _historyHydrationDone = true;
        });
      }
    }
  }

  Future<void> _sendMessage() async {
    if (_isSending) return;
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();
    context.read<MatchesProvider>().sendTyping(
      matchId: widget.matchId,
      typing: false,
    );
    setState(() {
      _isSending = true;
    });

    try {
      await context.read<MatchesProvider>().sendMessage(
        matchId: widget.matchId,
        text: text,
      );
      if (!mounted) return;
      await context.read<MatchesProvider>().refreshConversation(widget.matchId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('message_failed_retry'))),
      );
      return;
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }

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
            '${context.tr('report')} ${widget.matchName}',
            style: TextStyle(color: colorScheme.onSurface),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('why_reporting_user'),
                style: TextStyle(color: colorScheme.onSurface.withOpacity(0.8)),
              ),
              const SizedBox(height: 16),
              _buildReportOption(context.tr('inappropriate_photos')),
              _buildReportOption(context.tr('harassment')),
              _buildReportOption(context.tr('fake_profile')),
              _buildReportOption(context.tr('spam')),
              _buildReportOption(context.tr('other')),
            ],
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.tr('cancel')),
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
            content: Text('${context.tr('report_submitted_prefix')}: $reason'),
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
            '${context.tr('unmatch_with')} ${widget.matchName}?',
            style: TextStyle(color: colorScheme.onSurface),
          ),
          content: Text(
            context.tr('unmatch_confirm_body'),
            style: TextStyle(color: colorScheme.onSurface.withOpacity(0.8)),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                context.tr('cancel'),
                style: TextStyle(color: colorScheme.onSurface.withOpacity(0.8)),
              ),
            ),
            TextButton(
              onPressed: () async {
                try {
                  await context.read<MatchesProvider>().unmatch(widget.matchId);
                  if (!context.mounted) return;
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                } catch (e) {
                  if (!context.mounted) return;
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(
                    SnackBar(
                      content: Text('${context.tr('unmatch_failed')}: $e'),
                    ),
                  );
                }
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text(context.tr('unmatch')),
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
    try {
      await context.read<MatchesProvider>().unmatch(widget.matchId);
    } catch (_) {}
    if (!mounted) return;
    Navigator.pop(context);
  }

  Widget _buildSyncingChip() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.95),
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

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final auth = context.watch<AuthProvider>();
    final matchesProvider = context.watch<MatchesProvider>();
    final isOffline = matchesProvider.isOffline;

    if (_lastOfflineState == true && isOffline == false) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        AppFeedback.showBottomStatus(
          context,
          message: context.tr('reconnected_messages_syncing'),
          success: true,
          duration: const Duration(milliseconds: 1100),
        );
      });
    }
    _lastOfflineState = isOffline;

    final myUid = auth.backendUserId ?? auth.uid;
    final thread = matchesProvider.matchById(widget.matchId);
    final peerId = widget.peerUserId ?? _peerFromThread(thread, myUid);
    final presence = _presenceState(
      matchesProvider: matchesProvider,
      thread: thread,
      myUid: myUid,
      peerId: peerId,
    );
    final hasConversationHint = (thread?.lastMessage ?? '').trim().isNotEmpty;
    final hasLoadedConversation = matchesProvider.hasLoadedConversation(
      widget.matchId,
    );

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
              child: ClipOval(
                child: SizedBox.expand(
                  child: PhotoImage(
                    path: widget.matchPhotoUrl,
                    placeholderIcon: Icons.person,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.matchName,
                    style: TextStyle(
                      fontSize: Responsive.font(context, 16),
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    presence.label,
                    style: TextStyle(
                      fontSize: Responsive.font(context, 12),
                      color: presence.color,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
                      context.tr('report'),
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
                    Text(
                      context.tr('block'),
                      style: const TextStyle(color: Colors.red),
                    ),
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
                    Text(
                      context.tr('unmatch'),
                      style: const TextStyle(color: Colors.red),
                    ),
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
                final isDark = Theme.of(context).brightness == Brightness.dark;
                return bgManager.getBackgroundWidget(isDark);
              },
            ),
          ),
          Column(
            children: [
              if (isOffline)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    context.tr('offline_sync'),
                    style: TextStyle(
                      color: colorScheme.onErrorContainer,
                      fontWeight: FontWeight.w600,
                      fontSize: Responsive.font(context, 12),
                    ),
                  ),
                ),
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
                          context.tr('safety_banner'),
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
                        child: Text(context.tr('got_it')),
                      ),
                    ],
                  ),
                ),
              if (matchesProvider.isSyncing)
                Align(
                  alignment: Alignment.centerLeft,
                  child: _buildSyncingChip(),
                ),
              Expanded(
                child: StreamBuilder<List<ChatMessageModel>>(
                  stream: context.read<MatchesProvider>().messagesStream(
                    widget.matchId,
                  ),
                  builder: (context, snapshot) {
                    final messages =
                        snapshot.data ?? const <ChatMessageModel>[];
                    if (messages.isNotEmpty &&
                        hasLoadedConversation &&
                        !_historyHydrationDone) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) return;
                        setState(() {
                          _historyHydrationDone = true;
                        });
                      });
                    }
                    if (messages.isEmpty &&
                        (!_historyHydrationDone || !hasLoadedConversation)) {
                      return _buildChatSkeleton();
                    }
                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: messages.isEmpty ? 1 : messages.length,
                      itemBuilder: (context, index) {
                        if (messages.isEmpty) {
                          if (matchesProvider.isOffline) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (!mounted) return;
                              _hydrateConversation();
                            });
                            return _buildLoadingConversationCard(
                              label: context.tr('offline_saved_chat'),
                            );
                          }
                          if (!_historyHydrationDone ||
                              !hasLoadedConversation ||
                              hasConversationHint) {
                            return _buildLoadingConversationCard();
                          }
                          return _buildConversationStarterCard();
                        }
                        final message = messages[index];
                        final isSent = message.senderId == myUid;
                        final previous = index > 0 ? messages[index - 1] : null;
                        final showDateSeparator = _shouldShowDateDivider(
                          previous?.sentAt,
                          message.sentAt,
                        );
                        return Column(
                          children: [
                            if (showDateSeparator)
                              _buildDateSeparator(message.sentAt),
                            _buildMessage(message: message, isSent: isSent),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
              if (matchesProvider.isPeerTyping(widget.matchId))
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${widget.matchName} is typing...',
                      style: TextStyle(
                        color: colorScheme.onSurface.withValues(alpha: 0.65),
                        fontSize: Responsive.font(context, 12),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
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
                          enabled: !_isSending,
                          decoration: InputDecoration(
                            hintText: context.tr('type_message_or_emoji'),
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
                            fillColor: colorScheme.surfaceContainerHighest,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          maxLines: null,
                          maxLength: 1000,
                          textCapitalization: TextCapitalization.sentences,
                          keyboardType: TextInputType.multiline,
                          onChanged: (value) {
                            context.read<MatchesProvider>().sendTyping(
                              matchId: widget.matchId,
                              typing: value.trim().isNotEmpty,
                            );
                          },
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
                          color: _isSending
                              ? colorScheme.primary.withValues(alpha: 0.6)
                              : colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: Icon(
                            _isSending ? Icons.hourglass_top : Icons.send,
                            color: Colors.white,
                          ),
                          iconSize: Responsive.icon(context, 20),
                          onPressed: _isSending ? null : _sendMessage,
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

  Widget _buildConversationStarterCard() {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 24),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: colorScheme.surface.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: colorScheme.primary.withValues(alpha: 0.14),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: colorScheme.surfaceVariant,
                  child: ClipOval(
                    child: SizedBox.expand(
                      child: PhotoImage(
                        path: widget.matchPhotoUrl,
                        placeholderIcon: Icons.person,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${context.tr('you_matched_with_prefix')} ${widget.matchName}',
                        style: TextStyle(
                          fontSize: Responsive.font(context, 16),
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.tr('break_ice'),
                        style: TextStyle(
                          fontSize: Responsive.font(context, 13),
                          color: colorScheme.onSurface.withValues(alpha: 0.68),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                context.tr('quick_starter_1'),
                context.tr('quick_starter_2'),
                context.tr('quick_starter_3'),
              ]
                  .map(
                    (text) => ActionChip(
                      label: Text(text),
                      onPressed: () {
                        _messageController
                          ..text = text
                          ..selection = TextSelection.collapsed(
                            offset: text.length,
                          );
                        setState(() {});
                      },
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessage({
    required ChatMessageModel message,
    required bool isSent,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bubbleColor = isSent
        ? (isDark ? colorScheme.primary : colorScheme.primaryContainer)
        : (isDark
              ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.95)
              : colorScheme.surface);
    final bubbleTextColor = isSent
        ? (isDark ? colorScheme.onPrimary : colorScheme.onPrimaryContainer)
        : colorScheme.onSurface;

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
                    color: bubbleColor,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: colorScheme.outline.withValues(alpha: 0.14),
                    ),
                  ),
                  child: GestureDetector(
                    onLongPress: () => _showMessageDetails(message, isSent),
                    child: Text(
                      message.text,
                      style: TextStyle(
                        fontSize: Responsive.font(context, 15),
                        color: bubbleTextColor,
                        height: 1.4,
                      ),
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
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: message.isPending
                            ? Row(
                                key: const ValueKey('sending'),
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: Responsive.icon(context, 12),
                                    height: Responsive.icon(context, 12),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 1.6,
                                      color: colorScheme.onSurface.withOpacity(
                                        0.65,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    context.tr('sending'),
                                    style: TextStyle(
                                      fontSize: Responsive.font(context, 10),
                                      color: colorScheme.onSurface.withOpacity(
                                        0.65,
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : message.isFailed
                            ? GestureDetector(
                                key: const ValueKey('failed'),
                                onTap: () async {
                                  try {
                                    await context
                                        .read<MatchesProvider>()
                                        .retryMessage(
                                          matchId: widget.matchId,
                                          message: message,
                                        );
                                  } catch (_) {
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          context.tr('retry_failed_check_connection'),
                                        ),
                                      ),
                                    );
                                  }
                                },
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.error_outline,
                                      size: Responsive.icon(context, 14),
                                      color: Colors.redAccent,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      context.tr('retry'),
                                      style: TextStyle(
                                        fontSize: Responsive.font(context, 10),
                                        color: Colors.redAccent,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : Icon(
                                key: ValueKey(message.isRead ? 'read' : 'sent'),
                                message.isRead ? Icons.done_all : Icons.done,
                                size: Responsive.icon(context, 14),
                                color: message.isRead
                                    ? colorScheme.primary
                                    : colorScheme.onSurface.withOpacity(0.6),
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
    );
  }

  Widget _buildLoadingConversationCard({String? label}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 28),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: colorScheme.surface.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label ?? context.tr('loading_conversation'),
                style: TextStyle(
                  fontSize: Responsive.font(context, 14),
                  color: colorScheme.onSurface.withValues(alpha: 0.78),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSeparator(DateTime? timestamp) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              color: colorScheme.outlineVariant.withValues(alpha: 0.4),
              thickness: 1,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              _dateLabel(timestamp),
              style: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.65),
                fontSize: Responsive.font(context, 12),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Divider(
              color: colorScheme.outlineVariant.withValues(alpha: 0.4),
              thickness: 1,
            ),
          ),
        ],
      ),
    );
  }

  bool _shouldShowDateDivider(DateTime? previous, DateTime? current) {
    if (current == null) return false;
    if (previous == null) return true;
    return previous.year != current.year ||
        previous.month != current.month ||
        previous.day != current.day;
  }

  String _dateLabel(DateTime? dateTime) {
    if (dateTime == null) return context.tr('today');
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(dateTime.year, dateTime.month, dateTime.day);
    final diff = today.difference(date).inDays;
    if (diff == 0) return context.tr('today');
    if (diff == 1) return context.tr('yesterday');
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showMessageDetails(ChatMessageModel message, bool isSent) {
    final colorScheme = Theme.of(context).colorScheme;
    final status = message.isFailed
        ? context.tr('failed')
        : message.isPending
        ? context.tr('sending')
        : message.isRead
        ? context.tr('read')
        : context.tr('delivered');

    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isSent ? context.tr('your_message') : '${widget.matchName} ${context.tr('message')}',
                style: TextStyle(
                  fontSize: Responsive.font(context, 16),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${context.tr('status')}: $status',
                style: TextStyle(
                  color: colorScheme.onSurface.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${context.tr('time')}: ${_formatTime(message.sentAt)}',
                style: TextStyle(
                  color: colorScheme.onSurface.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatSkeleton() {
    final colorScheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _bubbleSkeleton(widthFactor: 0.58, alignEnd: false, color: colorScheme),
        const SizedBox(height: 10),
        _bubbleSkeleton(widthFactor: 0.42, alignEnd: true, color: colorScheme),
        const SizedBox(height: 10),
        _bubbleSkeleton(widthFactor: 0.62, alignEnd: false, color: colorScheme),
      ],
    );
  }

  Widget _bubbleSkeleton({
    required double widthFactor,
    required bool alignEnd,
    required ColorScheme color,
  }) {
    return Align(
      alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        width: MediaQuery.of(context).size.width * widthFactor,
        height: 44,
        decoration: BoxDecoration(
          color: color.surfaceContainerHighest.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(18),
        ),
      ),
    );
  }

  String? _peerFromThread(MatchThread? thread, String? myUid) {
    if (thread == null || myUid == null) return null;
    for (final id in thread.userIds) {
      if (id != myUid) return id;
    }
    return null;
  }

  _PresenceState _presenceState({
    required MatchesProvider matchesProvider,
    required MatchThread? thread,
    required String? myUid,
    required String? peerId,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    if (matchesProvider.isPeerTyping(widget.matchId)) {
      return _PresenceState(context.tr('active_now'), colorScheme.primary);
    }

    final lastAt = thread?.lastMessageAt;
    final lastSender = thread?.lastSenderId;
    if (lastAt != null &&
        peerId != null &&
        lastSender == peerId &&
        DateTime.now().difference(lastAt).inMinutes <= 5) {
      return _PresenceState(context.tr('online'), Colors.green.shade600);
    }

    if (lastAt != null &&
        peerId != null &&
        lastSender == peerId &&
        DateTime.now().difference(lastAt).inHours <= 24) {
      return _PresenceState(context.tr('active_recently'), colorScheme.secondary);
    }

    return _PresenceState(
      context.tr('inactive'),
      colorScheme.onSurface.withValues(alpha: 0.6),
    );
  }

  String _formatTime(DateTime? timestamp) {
    if (timestamp == null) return context.tr('now');
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return context.tr('now');
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}${context.tr('minute_ago_suffix')}';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}${context.tr('hour_ago_suffix')}';
    } else {
      return '${timestamp.day}/${timestamp.month}';
    }
  }
}

class _PresenceState {
  const _PresenceState(this.label, this.color);

  final String label;
  final Color color;
}
