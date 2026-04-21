import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:lerolove/services/backend_api.dart';

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

  String? _backendToken;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);

    _tokenRefreshSub = messaging.onTokenRefresh.listen((newToken) {
      final backendToken = _backendToken;
      if (backendToken == null || backendToken.isEmpty) return;
      unawaited(_registerToken(backendToken, newToken));
    });

    _foregroundSub = FirebaseMessaging.onMessage.listen((message) {
      _eventsController.add(message.data);
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
    if (token == null || token.isEmpty) return;
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
    } catch (_) {}
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
