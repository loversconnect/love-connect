import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lerolove/Screens/Splash%20screen.dart';
import 'package:lerolove/Utils/app_state.dart';
import 'package:lerolove/Utils/theme_manager.dart';
import 'package:lerolove/Utils/chat_background_manager.dart';
import 'package:lerolove/Utils/responsive.dart';
import 'package:lerolove/firebase_options.dart';
import 'package:lerolove/providers/admin_provider.dart';
import 'package:lerolove/providers/auth_provider.dart';
import 'package:lerolove/providers/discovery_provider.dart';
import 'package:lerolove/providers/matches_provider.dart';
import 'package:lerolove/providers/moderation_provider.dart';
import 'package:lerolove/providers/profile_provider.dart';
import 'package:lerolove/services/push_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await PushService.instance.initialize();

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
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProxyProvider<AuthProvider, ProfileProvider>(
          create: (_) => ProfileProvider(),
          update: (_, auth, profile) {
            final provider = profile ?? ProfileProvider();
            provider.bind(auth);
            return provider;
          },
        ),
        ChangeNotifierProxyProvider2<
          AuthProvider,
          ProfileProvider,
          DiscoveryProvider
        >(
          create: (_) => DiscoveryProvider(),
          update: (_, auth, profile, discovery) {
            final provider = discovery ?? DiscoveryProvider();
            provider.bind(auth, profile);
            return provider;
          },
        ),
        ChangeNotifierProxyProvider<AuthProvider, MatchesProvider>(
          create: (_) => MatchesProvider(),
          update: (_, auth, matches) {
            final provider = matches ?? MatchesProvider();
            provider.bind(auth);
            return provider;
          },
        ),
        ChangeNotifierProxyProvider<AuthProvider, ModerationProvider>(
          create: (_) => ModerationProvider(),
          update: (_, auth, moderation) {
            final provider = moderation ?? ModerationProvider();
            provider.bind(auth);
            return provider;
          },
        ),
        ChangeNotifierProxyProvider<AuthProvider, AdminProvider>(
          create: (_) => AdminProvider(),
          update: (_, auth, admin) {
            final provider = admin ?? AdminProvider();
            provider.bind(auth);
            return provider;
          },
        ),
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
