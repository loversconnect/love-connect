import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage { english, chichewa }

class LanguageProvider extends ChangeNotifier {
  static const String _storageKey = 'app_language';

  AppLanguage _language = AppLanguage.english;
  bool _ready = false;

  AppLanguage get language => _language;
  bool get isReady => _ready;

  LanguageProvider() {
    unawaited(_load());
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey) ?? 'en';
    _language = raw == 'ny' ? AppLanguage.chichewa : AppLanguage.english;
    _ready = true;
    notifyListeners();
  }

  Future<void> setLanguage(AppLanguage value) async {
    if (_language == value) return;
    _language = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, value == AppLanguage.chichewa ? 'ny' : 'en');
    notifyListeners();
  }
}
