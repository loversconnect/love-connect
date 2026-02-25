import 'package:flutter/material.dart';

class Responsive {
  static double _clamp(double value, double min, double max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  static double scale(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return _clamp(width / 390.0, 0.9, 1.15);
  }

  static double font(BuildContext context, double size) {
    return size * scale(context);
  }

  static double icon(BuildContext context, double size) {
    return size * scale(context);
  }

  static EdgeInsets pagePadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final horizontal = _clamp(width * 0.06, 16, 32);
    final vertical = _clamp(width * 0.06, 16, 28);
    return EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical);
  }

  static int gridColumns(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 360) return 2;
    if (width < 600) return 3;
    if (width < 900) return 4;
    return 5;
  }
}
