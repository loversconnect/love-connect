import 'package:flutter/material.dart';
import 'package:lerolove/Screens/Add%20photos%20screen.dart';
import 'package:provider/provider.dart';
import 'package:lerolove/Screens/Main%20app%20screen.dart';
import 'package:lerolove/Screens/Preferences%20screen.dart';
import 'package:lerolove/Screens/Profile%20basics%20screen.dart';
import 'package:lerolove/Screens/Welcome%20screen.dart';
import 'package:lerolove/providers/auth_provider.dart';
import 'package:lerolove/providers/profile_provider.dart';
import 'package:lerolove/Utils/responsive.dart';
import 'dart:async';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _controller.forward();

    unawaited(_resolveAndNavigate());
  }

  Future<void> _resolveAndNavigate() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final auth = context.read<AuthProvider>();
    while (!auth.hasRestoredSession && mounted) {
      await Future.delayed(const Duration(milliseconds: 80));
    }
    if (!mounted) return;

    final profile = context.read<ProfileProvider>();
    final waitUntil = DateTime.now().add(const Duration(seconds: 2));
    while (auth.isAuthenticated &&
        !profile.isProfileReady &&
        mounted &&
        DateTime.now().isBefore(waitUntil)) {
      await Future.delayed(const Duration(milliseconds: 80));
    }
    if (!mounted) return;

    final Widget nextScreen;
    if (!auth.isAuthenticated) {
      nextScreen = const WelcomeScreen();
    } else {
      final data = profile.currentProfile;
      if (data == null || !data.hasCompletedBasics) {
        nextScreen = const ProfileBasicsScreen();
      } else if (!data.hasSelfiePhoto) {
        nextScreen = const AddPhotosScreen();
      } else if (!data.hasLocationSet) {
        nextScreen = const PreferencesScreen();
      } else {
        nextScreen = const MainAppScreen();
      }
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => nextScreen),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colorScheme.primary,
              colorScheme.secondary.withOpacity(0.8),
            ],
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App Icon/Logo
                  Container(
                    width: Responsive.icon(context, 120),
                    height: Responsive.icon(context, 120),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(
                        Responsive.icon(context, 30),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.favorite,
                      size: Responsive.icon(context, 60),
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // App Name
                  Text(
                    'LoversConnect',
                    style: textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onPrimary,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Tagline
                  Text(
                    'Find love with confidence',
                    style: textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onPrimary.withOpacity(0.8),
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
