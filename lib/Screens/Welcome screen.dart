import 'package:flutter/material.dart';
import 'package:lerolove/Screens/Phone%20entry%20screen.dart';
import 'package:lerolove/Utils/responsive.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                colorScheme.background,
                colorScheme.surfaceVariant.withOpacity(0.3),
              ],
            ),
          ),
          child: Padding(
            padding: Responsive.pagePadding(context),
            child: Column(
              children: [
                const Spacer(),
                // Illustration/Hero Image
                Container(
                  height: Responsive.icon(context, 280),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      colors: [
                        colorScheme.surface,
                        colorScheme.surfaceVariant.withOpacity(0.7),
                      ],
                    ),
                    border: Border.all(
                      color: colorScheme.secondary.withOpacity(0.25),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.primary.withOpacity(0.06),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        top: 18,
                        right: 18,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: colorScheme.secondary.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      Center(
                        child: Icon(
                          Icons.favorite_rounded,
                          size: Responsive.icon(context, 120),
                          color: colorScheme.primary.withOpacity(0.25),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 48),
                // Title
                Text(
                  'Welcome to\nLoversConnect',
                  textAlign: TextAlign.center,
                  style: textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 16),
                // Description
                Text(
                  'Connect with people around you.\nFind meaningful relationships.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onBackground.withOpacity(0.7),
                    height: 1.5,
                  ),
                ),
                const Spacer(),
                // Get Started Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PhoneEntryScreen(),
                        ),
                      );
                    },
                    child: const Text('Get Started'),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'We never post without permission.',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onBackground.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 16),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
