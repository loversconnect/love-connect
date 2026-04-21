import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class PhotoImage extends StatelessWidget {
  const PhotoImage({
    super.key,
    required this.path,
    this.fit = BoxFit.cover,
    this.placeholderIcon = Icons.person,
    this.placeholderColor,
  });

  final String? path;
  final BoxFit fit;
  final IconData placeholderIcon;
  final Color? placeholderColor;

  bool _isNetworkPath(String value) {
    final lower = value.toLowerCase();
    return lower.startsWith('http://') || lower.startsWith('https://');
  }

  @override
  Widget build(BuildContext context) {
    final trimmed = path?.trim() ?? '';
    if (trimmed.isEmpty) {
      return _placeholder(context);
    }

    if (_isNetworkPath(trimmed)) {
      return Image.network(
        trimmed,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => _placeholder(context),
      );
    }

    if (!kIsWeb) {
      return Image.file(
        File(trimmed),
        fit: fit,
        errorBuilder: (context, error, stackTrace) => _placeholder(context),
      );
    }

    return _placeholder(context);
  }

  Widget _placeholder(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      color: colorScheme.surfaceVariant,
      alignment: Alignment.center,
      child: Icon(
        placeholderIcon,
        color: placeholderColor ?? colorScheme.onSurface.withOpacity(0.35),
      ),
    );
  }
}
