import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MessageAlertService {
  MessageAlertService._();

  static const String _channelName = 'lerolove/notifications';
  static const MethodChannel _channel = MethodChannel(_channelName);

  static const String _ringtoneUriKey = 'message_ringtone_uri';
  static const String _ringtoneTitleKey = 'message_ringtone_title';

  static bool get _supportsNativeRingtonePicker =>
      !kIsWeb && Platform.isAndroid;

  static Future<String?> getRingtoneUri() async {
    final prefs = await SharedPreferences.getInstance();
    final uri = prefs.getString(_ringtoneUriKey);
    if (uri == null || uri.trim().isEmpty) return null;
    return uri.trim();
  }

  static Future<String> getRingtoneTitle() async {
    final prefs = await SharedPreferences.getInstance();
    final title = prefs.getString(_ringtoneTitleKey);
    if (title == null || title.trim().isEmpty) {
      return 'Default phone ringtone';
    }
    return title;
  }

  static Future<void> pickRingtone() async {
    if (!_supportsNativeRingtonePicker) return;
    final currentUri = await getRingtoneUri();
    final response = await _channel.invokeMethod<dynamic>(
      'pickMessageRingtone',
      {'currentUri': currentUri},
    );

    if (response is! Map) return;
    final map = Map<String, dynamic>.from(response);
    final uri = (map['uri'] as String?)?.trim();
    final title = (map['title'] as String?)?.trim();

    final prefs = await SharedPreferences.getInstance();
    if (uri == null || uri.isEmpty) {
      await prefs.remove(_ringtoneUriKey);
      await prefs.setString(_ringtoneTitleKey, 'Default phone ringtone');
      return;
    }

    await prefs.setString(_ringtoneUriKey, uri);
    await prefs.setString(
      _ringtoneTitleKey,
      (title == null || title.isEmpty) ? 'Custom ringtone' : title,
    );
  }

  static Future<void> playSelectedRingtone() async {
    if (!_supportsNativeRingtonePicker) return;
    final uri = await getRingtoneUri();
    await _channel.invokeMethod<void>('playMessageRingtone', {'uri': uri});
  }

  static Future<void> stopRingtone() async {
    if (!_supportsNativeRingtonePicker) return;
    await _channel.invokeMethod<void>('stopMessageRingtone');
  }
}
