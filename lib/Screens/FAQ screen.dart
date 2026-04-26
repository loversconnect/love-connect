import 'package:flutter/material.dart';
import 'package:lerolove/Utils/app_i18n.dart';
import 'package:lerolove/Utils/responsive.dart';

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = <({String q, String a})>[
      (q: context.tr('faq_q1'), a: context.tr('faq_a1')),
      (q: context.tr('faq_q2'), a: context.tr('faq_a2')),
      (q: context.tr('faq_q3'), a: context.tr('faq_a3')),
      (q: context.tr('faq_q4'), a: context.tr('faq_a4')),
      (q: context.tr('faq_q5'), a: context.tr('faq_a5')),
      (q: context.tr('faq_q6'), a: context.tr('faq_a6')),
      (q: context.tr('faq_q7'), a: context.tr('faq_a7')),
      (q: context.tr('faq_q8'), a: context.tr('faq_a8')),
      (q: context.tr('faq_q9'), a: context.tr('faq_a9')),
    ];
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('faq'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text(
            context.tr('faq_heading'),
            style: textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: Responsive.font(context, 20),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr('faq_subtitle'),
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 14),
          ...items.map(
            (item) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 2,
                ),
                childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                title: Text(
                  item.q,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: Responsive.font(context, 15),
                  ),
                ),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      item.a,
                      style: textTheme.bodyMedium?.copyWith(
                        height: 1.4,
                        color: colorScheme.onSurface.withValues(alpha: 0.82),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
