import 'package:flutter/material.dart';
import 'package:lerolove/Utils/app_i18n.dart';
import 'package:lerolove/providers/moderation_provider.dart';
import 'package:lerolove/Utils/responsive.dart';
import 'package:provider/provider.dart';

class BlockedUsersScreen extends StatelessWidget {
  const BlockedUsersScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final blockedUsers = context.watch<ModerationProvider>().blockedUsers;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('blocked_users_title')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: blockedUsers.isEmpty
          ? _buildEmptyState(context)
          : ListView.builder(
              itemCount: blockedUsers.length,
              itemBuilder: (context, index) {
                final user = blockedUsers[index];
                return _buildBlockedUserItem(
                  context,
                  userId: user.userId,
                  name: user.name,
                  blockedDate: user.blockedAt,
                );
              },
            ),
    );
  }

  Widget _buildBlockedUserItem(
    BuildContext context, {
    required String userId,
    required String name,
    required DateTime? blockedDate,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: colorScheme.surfaceVariant,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: colorScheme.surfaceVariant,
            child: Text(
              name.isNotEmpty ? name[0] : '?',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _friendlyDate(context, blockedDate),
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onBackground.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _unblockUser(context, userId, name),
            style: TextButton.styleFrom(
              foregroundColor: colorScheme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: Text(
              context.tr('unblock'),
              style: TextStyle(
                fontSize: Responsive.font(context, 14),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _unblockUser(BuildContext context, String userId, String name) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('${context.tr('unblock')} $name?'),
          content: Text(context.tr('unblock_user_confirm_suffix')),
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
                await context.read<ModerationProvider>().unblockUser(userId);
                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$name ${context.tr('user_unblocked_suffix')}'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.primary,
              ),
              child: Text(context.tr('unblock')),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.block,
              size: Responsive.icon(context, 80),
              color: colorScheme.onSurface.withOpacity(0.4),
            ),
            const SizedBox(height: 24),
            Text(
              context.tr('no_blocked_users'),
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              context.tr('blocked_users_empty'),
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge?.copyWith(
                color: colorScheme.onBackground.withOpacity(0.7),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _friendlyDate(BuildContext context, DateTime? date) {
    if (date == null) return context.tr('blocked_recently');
    final diff = DateTime.now().difference(date);
    if (diff.inDays <= 0) return context.tr('blocked_today');
    if (diff.inDays == 1) return context.tr('blocked_yesterday');
    if (diff.inDays < 7) {
      return '${diff.inDays} ${context.tr('blocked_days_ago_suffix')}';
    }
    return '${date.day}/${date.month}/${date.year}';
  }
}
