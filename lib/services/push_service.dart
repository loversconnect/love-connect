import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:lerolove/services/backend_api.dart';
import 'package:lerolove/services/message_alert_service.dart';

class PushService {
  PushService._();

  static final PushService instance = PushService._();

  final BackendApi _api = BackendApi();
  final StreamController<Map<String, dynamic>> _eventsController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get events => _eventsController.stream;

  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _openedSub;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static const String _messagesChannelId = 'lerolove_messages';
  static const String _generalChannelId = 'lerolove_general';

  String? _backendToken;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);
    await _initLocalNotifications();

    _tokenRefreshSub = messaging.onTokenRefresh.listen((newToken) {
      final backendToken = _backendToken;
      if (backendToken == null || backendToken.isEmpty) return;
      unawaited(_registerToken(backendToken, newToken));
    });

    _foregroundSub = FirebaseMessaging.onMessage.listen((message) {
      _eventsController.add(message.data);
      unawaited(_handleForegroundMessageNotification(message));
    });

    _openedSub = FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _eventsController.add(message.data);
    });

    final initial = await messaging.getInitialMessage();
    if (initial != null) {
      _eventsController.add(initial.data);
    }
  }

  Future<void> bindBackendSession(String backendToken) async {
    _backendToken = backendToken;
    await initialize();

    final token = await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty) {
      debugPrint('PushService: FirebaseMessaging returned no device token.');
      return;
    }
    await _registerToken(backendToken, token);
  }

  Future<void> unbindBackendSession() async {
    final backendToken = _backendToken;
    _backendToken = null;

    if (backendToken == null || backendToken.isEmpty) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;
      await _api.removeDeviceToken(token: backendToken, deviceToken: token);
    } catch (_) {}
  }

  Future<void> dispose() async {
    await _tokenRefreshSub?.cancel();
    await _foregroundSub?.cancel();
    await _openedSub?.cancel();
    await _eventsController.close();
  }

  Future<void> _registerToken(String backendToken, String deviceToken) async {
    try {
      await _api.upsertDeviceToken(
        token: backendToken,
        deviceToken: deviceToken,
        platform: _platformLabel(),
      );
    } catch (error) {
      debugPrint('PushService: device token registration failed: $error');
    }
  }

  Future<void> _initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(settings);
    await _createAndroidChannels();
  }

  Future<void> _createAndroidChannels() async {
    if (kIsWeb || !Platform.isAndroid) return;
    final android = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return;

    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        _messagesChannelId,
        'Messages',
        description: 'Alerts for new chat messages',
        importance: Importance.max,
        playSound: true,
      ),
    );
    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        _generalChannelId,
        'General',
        description: 'General alerts such as matches',
        importance: Importance.high,
        playSound: true,
      ),
    );
  }

  bool _isChatMessage(RemoteMessage message) {
    final type = (message.data['type'] ?? '').toString();
    if (type == 'chat.message') return true;
    return message.data.containsKey('chatId');
  }

  Future<void> _handleForegroundMessageNotification(
    RemoteMessage message,
  ) async {
    if (!_isChatMessage(message)) return;

    final title =
        message.notification?.title ??
        (message.data['title']?.toString() ?? 'New message');
    final body =
        message.notification?.body ??
        (message.data['body']?.toString() ?? 'You received a new message.');

    final customRingtoneUri = await MessageAlertService.getRingtoneUri();
    final useCustomRingtone =
        !kIsWeb &&
        Platform.isAndroid &&
        customRingtoneUri != null &&
        customRingtoneUri.trim().isNotEmpty;

    final androidDetails = AndroidNotificationDetails(
      _messagesChannelId,
      'Messages',
      channelDescription: 'Alerts for new chat messages',
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.message,
      playSound: !useCustomRingtone,
    );

    const iosDetails = DarwinNotificationDetails(presentSound: true);
    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
    );

    if (useCustomRingtone) {
      await MessageAlertService.playSelectedRingtone();
    }
  }

  String _platformLabel() {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isWindows) return 'windows';
    if (Platform.isLinux) return 'linux';
    return 'unknown';
  }
}
