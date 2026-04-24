import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppFeedback {
  AppFeedback._();

  static Future<void> showBottomStatus(
    BuildContext context, {
    required String message,
    bool success = true,
    Duration duration = const Duration(milliseconds: 1200),
  }) async {
    await HapticFeedback.lightImpact();
    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (sheetContext) {
        Future<void>.delayed(duration, () {
          if (sheetContext.mounted) {
            Navigator.of(sheetContext).pop();
          }
        });

        final colorScheme = Theme.of(sheetContext).colorScheme;
        final icon = success ? Icons.check_circle : Icons.info_outline;
        final bg = success
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerHighest;
        final fg = success
            ? colorScheme.onPrimaryContainer
            : colorScheme.onSurface;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.14),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(icon, color: fg, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      message,
                      style: TextStyle(
                        color: fg,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
