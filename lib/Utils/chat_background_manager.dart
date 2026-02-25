import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatBackgroundManager extends ChangeNotifier {
  static const String _backgroundKey = 'chat_background';
  ChatBackgroundType _currentBackground = ChatBackgroundType.defaultLight;

  ChatBackgroundType get currentBackground => _currentBackground;

  ChatBackgroundManager() {
    _loadBackground();
  }

  Future<void> _loadBackground() async {
    final prefs = await SharedPreferences.getInstance();
    final savedBg = prefs.getString(_backgroundKey) ?? 'defaultLight';
    _currentBackground = ChatBackgroundType.values.firstWhere(
          (bg) => bg.name == savedBg,
      orElse: () => ChatBackgroundType.defaultLight,
    );
    notifyListeners();
  }

  Future<void> setBackground(ChatBackgroundType background) async {
    _currentBackground = background;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_backgroundKey, background.name);
  }

  Widget getBackgroundWidget(bool isDarkMode) {
    return ChatBackgrounds.getBackground(_currentBackground, isDarkMode);
  }
}

// Chat background types
enum ChatBackgroundType {
  defaultLight,
  defaultDark,
  whatsappClassic,
  geometric,
  bubbles,
  waves,
  solidGray,
  solidBlack,
  solidWhite,
  gradientBlue,
  gradientPurple,
  gradientGreen,
  gradientOrange,
  dots,
  stripes,
}

// Chat background widgets
class ChatBackgrounds {
  static Widget getBackground(ChatBackgroundType type, bool isDarkMode) {
    switch (type) {
    // Default backgrounds
      case ChatBackgroundType.defaultLight:
        return Container(
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF0B141A) : const Color(0xFFECE5DD),
          ),
        );

      case ChatBackgroundType.defaultDark:
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0B141A),
          ),
        );

    // WhatsApp classic
      case ChatBackgroundType.whatsappClassic:
        return Container(
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF0B141A) : const Color(0xFFE5DDD5),
          ),
          child: CustomPaint(
            painter: WhatsAppPatternPainter(isDarkMode),
            size: Size.infinite,
          ),
        );

    // Geometric pattern
      case ChatBackgroundType.geometric:
        return Container(
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF121212) : Colors.white,
          ),
          child: CustomPaint(
            painter: GeometricPatternPainter(isDarkMode),
            size: Size.infinite,
          ),
        );

    // Bubbles pattern
      case ChatBackgroundType.bubbles:
        return Container(
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF0D1418) : const Color(0xFFF0F4F8),
          ),
          child: CustomPaint(
            painter: BubblesPatternPainter(isDarkMode),
            size: Size.infinite,
          ),
        );

    // Waves pattern
      case ChatBackgroundType.waves:
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDarkMode
                  ? [const Color(0xFF1A1A2E), const Color(0xFF16213E)]
                  : [const Color(0xFFE3F2FD), const Color(0xFFBBDEFB)],
            ),
          ),
          child: CustomPaint(
            painter: WavesPatternPainter(isDarkMode),
            size: Size.infinite,
          ),
        );

    // Solid colors
      case ChatBackgroundType.solidGray:
        return Container(
          color: isDarkMode ? const Color(0xFF1F1F1F) : const Color(0xFFF5F5F5),
        );

      case ChatBackgroundType.solidBlack:
        return Container(
          color: const Color(0xFF000000),
        );

      case ChatBackgroundType.solidWhite:
        return Container(
          color: const Color(0xFFFFFFFF),
        );

    // Gradients
      case ChatBackgroundType.gradientBlue:
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDarkMode
                  ? [
                const Color(0xFF0D47A1),
                const Color(0xFF1565C0),
                const Color(0xFF1976D2),
              ]
                  : [
                const Color(0xFFE3F2FD),
                const Color(0xFFBBDEFB),
                const Color(0xFF90CAF9),
              ],
            ),
          ),
        );

      case ChatBackgroundType.gradientPurple:
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDarkMode
                  ? [
                const Color(0xFF4A148C),
                const Color(0xFF6A1B9A),
                const Color(0xFF7B1FA2),
              ]
                  : [
                const Color(0xFFF3E5F5),
                const Color(0xFFE1BEE7),
                const Color(0xFFCE93D8),
              ],
            ),
          ),
        );

      case ChatBackgroundType.gradientGreen:
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: isDarkMode
                  ? [
                const Color(0xFF1B5E20),
                const Color(0xFF2E7D32),
                const Color(0xFF388E3C),
              ]
                  : [
                const Color(0xFFE8F5E9),
                const Color(0xFFC8E6C9),
                const Color(0xFFA5D6A7),
              ],
            ),
          ),
        );

      case ChatBackgroundType.gradientOrange:
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomLeft,
              end: Alignment.topRight,
              colors: isDarkMode
                  ? [
                const Color(0xFFE65100),
                const Color(0xFFF57C00),
                const Color(0xFFFF6F00),
              ]
                  : [
                const Color(0xFFFFF3E0),
                const Color(0xFFFFE0B2),
                const Color(0xFFFFCC80),
              ],
            ),
          ),
        );

    // Dots pattern
      case ChatBackgroundType.dots:
        return Container(
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF121212) : Colors.white,
          ),
          child: CustomPaint(
            painter: DotsPatternPainter(isDarkMode),
            size: Size.infinite,
          ),
        );

    // Stripes pattern
      case ChatBackgroundType.stripes:
        return Container(
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1A1A1A) : const Color(0xFFFAFAFA),
          ),
          child: CustomPaint(
            painter: StripesPatternPainter(isDarkMode),
            size: Size.infinite,
          ),
        );
    }
  }

  static String getName(ChatBackgroundType type) {
    switch (type) {
      case ChatBackgroundType.defaultLight:
        return 'Default Light';
      case ChatBackgroundType.defaultDark:
        return 'Default Dark';
      case ChatBackgroundType.whatsappClassic:
        return 'Classic';
      case ChatBackgroundType.geometric:
        return 'Geometric';
      case ChatBackgroundType.bubbles:
        return 'Bubbles';
      case ChatBackgroundType.waves:
        return 'Waves';
      case ChatBackgroundType.solidGray:
        return 'Solid Gray';
      case ChatBackgroundType.solidBlack:
        return 'Solid Black';
      case ChatBackgroundType.solidWhite:
        return 'Solid White';
      case ChatBackgroundType.gradientBlue:
        return 'Blue Gradient';
      case ChatBackgroundType.gradientPurple:
        return 'Purple Gradient';
      case ChatBackgroundType.gradientGreen:
        return 'Green Gradient';
      case ChatBackgroundType.gradientOrange:
        return 'Orange Gradient';
      case ChatBackgroundType.dots:
        return 'Dots';
      case ChatBackgroundType.stripes:
        return 'Stripes';
    }
  }
}

// Custom painters for patterns

class WhatsAppPatternPainter extends CustomPainter {
  final bool isDark;
  WhatsAppPatternPainter(this.isDark);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withOpacity(0.03)
      ..style = PaintingStyle.fill;

    const spacing = 20.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.5, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class GeometricPatternPainter extends CustomPainter {
  final bool isDark;
  GeometricPatternPainter(this.isDark);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withOpacity(0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    const spacing = 50.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawRect(
          Rect.fromLTWH(x, y, spacing * 0.7, spacing * 0.7),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class BubblesPatternPainter extends CustomPainter {
  final bool isDark;
  BubblesPatternPainter(this.isDark);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = (isDark ? Colors.white : const Color(0xFF0088CC)).withOpacity(0.08)
      ..style = PaintingStyle.fill;

    final random = [10.0, 15.0, 20.0, 12.0, 18.0];
    int index = 0;

    for (double x = 0; x < size.width; x += 80) {
      for (double y = 0; y < size.height; y += 80) {
        final radius = random[index % random.length];
        canvas.drawCircle(Offset(x + 20, y + 20), radius, paint);
        index++;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class WavesPatternPainter extends CustomPainter {
  final bool isDark;
  WavesPatternPainter(this.isDark);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final path = Path();
    const waveHeight = 30.0;
    const waveLength = 100.0;

    for (double i = 0; i < 5; i++) {
      path.reset();
      path.moveTo(0, size.height / 2 + (i * 50));

      for (double x = 0; x <= size.width; x += waveLength) {
        path.quadraticBezierTo(
          x + waveLength / 4,
          size.height / 2 + (i * 50) - waveHeight,
          x + waveLength / 2,
          size.height / 2 + (i * 50),
        );
        path.quadraticBezierTo(
          x + 3 * waveLength / 4,
          size.height / 2 + (i * 50) + waveHeight,
          x + waveLength,
          size.height / 2 + (i * 50),
        );
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class DotsPatternPainter extends CustomPainter {
  final bool isDark;
  DotsPatternPainter(this.isDark);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withOpacity(0.08)
      ..style = PaintingStyle.fill;

    const spacing = 30.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 3, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class StripesPatternPainter extends CustomPainter {
  final bool isDark;
  StripesPatternPainter(this.isDark);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withOpacity(0.05)
      ..style = PaintingStyle.fill;

    const stripeWidth = 40.0;
    for (double x = 0; x < size.width; x += stripeWidth * 2) {
      canvas.drawRect(
        Rect.fromLTWH(x, 0, stripeWidth, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}