import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lerolove/Utils/app_i18n.dart';
import 'package:lerolove/Utils/responsive.dart';

class SupportCenterScreen extends StatelessWidget {
  const SupportCenterScreen({super.key});

  static const String supportEmail = 'loversconnectmw@gmail.com';

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('support_center'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: colorScheme.primary.withValues(alpha: 0.08),
              border: Border.all(
                color: colorScheme.primary.withValues(alpha: 0.22),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('need_help'),
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: Responsive.font(context, 20),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.tr('support_desc'),
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.78),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: ListTile(
              leading: const Icon(Icons.email_outlined),
              title: Text(context.tr('support_email')),
              subtitle: const Text(supportEmail),
              trailing: TextButton(
                onPressed: () async {
                  await Clipboard.setData(
                    const ClipboardData(text: supportEmail),
                  );
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(context.tr('support_email_copied'))),
                  );
                },
                child: Text(context.tr('copy')),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(context.tr('when_contacting_support')),
              subtitle: Text(context.tr('when_contacting_support_desc')),
            ),
          ),
          const SizedBox(height: 6),
          Card(
            child: ListTile(
              leading: const Icon(Icons.schedule_outlined),
              title: Text(context.tr('response_time')),
              subtitle: Text(context.tr('response_time_desc')),
            ),
          ),
        ],
      ),
    );
  }
}
