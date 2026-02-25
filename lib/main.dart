import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lerolove/Screens/Splash%20screen.dart';
import 'package:lerolove/Utils/app_state.dart';
import 'package:lerolove/Utils/theme_manager.dart';
import 'package:lerolove/Utils/chat_background_manager.dart';
import 'package:lerolove/Utils/responsive.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Set portrait orientation only
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set status bar style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(
    // Wrap with MultiProvider for both theme managers
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeManager()),
        ChangeNotifierProvider(create: (_) => ChatBackgroundManager()),
        ChangeNotifierProvider(create: (_) => AppState()),
      ],
      child: const DatingApp(),
    ),
  );
}

class DatingApp extends StatelessWidget {
  const DatingApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeManager>(
      builder: (context, themeManager, child) {
        return MaterialApp(
          title: 'Malawi Dating',
          debugShowCheckedModeBanner: false,
          // Use themes from ThemeManager
          theme: ThemeManager.lightTheme,
          darkTheme: ThemeManager.darkTheme,
          themeMode: themeManager.themeMode,
          home: const SplashScreen(),
          builder: (context, child) {
            final media = MediaQuery.of(context);
            final scale = Responsive.scale(context);
            return MediaQuery(
              data: media.copyWith(
                textScaleFactor: media.textScaleFactor * scale,
              ),
              child: IconTheme.merge(
                data: IconThemeData(size: 24 * scale),
                child: child ?? const SizedBox.shrink(),
              ),
            );
          },
        );
      },
    );
  }
}
