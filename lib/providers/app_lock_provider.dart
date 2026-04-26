import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:lerolove/Utils/app_i18n.dart';
import 'package:lerolove/providers/language_provider.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLockProvider extends ChangeNotifier {
  static const String _enabledKey = 'app_lock_enabled';
  static const String _biometricKey = 'app_lock_biometric_enabled';
  static const String _passcodeHashKey = 'app_lock_passcode_hash';
  static const String _languageKey = 'app_language';

  final LocalAuthentication _auth = LocalAuthentication();

  bool _isReady = false;
  bool _enabled = false;
  bool _biometricEnabled = false;
  String? _passcodeHash;
  bool _isLocked = false;

  bool get isReady => _isReady;
  bool get enabled => _enabled;
  bool get biometricEnabled => _biometricEnabled;
  bool get hasPasscode => _passcodeHash != null && _passcodeHash!.isNotEmpty;
  bool get isLocked => _enabled && _isLocked;

  AppLockProvider() {
    unawaited(_load());
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_enabledKey) ?? false;
    _biometricEnabled = prefs.getBool(_biometricKey) ?? false;
    _passcodeHash = prefs.getString(_passcodeHashKey);
    _isReady = true;
    notifyListeners();
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    if (!value) {
      _isLocked = false;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, _enabled);
    notifyListeners();
  }

  Future<void> setBiometricEnabled(bool value) async {
    _biometricEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricKey, _biometricEnabled);
    notifyListeners();
  }

  Future<void> setPasscode(String passcode) async {
    _passcodeHash = _hash(passcode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_passcodeHashKey, _passcodeHash!);
    notifyListeners();
  }

  Future<void> clearPasscode() async {
    _passcodeHash = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_passcodeHashKey);
    if (!_biometricEnabled) {
      _enabled = false;
      await prefs.setBool(_enabledKey, false);
    }
    notifyListeners();
  }

  bool verifyPasscode(String input) {
    if (!hasPasscode) return false;
    return _hash(input) == _passcodeHash;
  }

  Future<bool> hasBiometricSupport() async {
    try {
      final available = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      return available && canCheck;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticateWithBiometrics() async {
    if (!_biometricEnabled) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawLanguage = prefs.getString(_languageKey) ?? 'en';
      final language = rawLanguage == 'ny'
          ? AppLanguage.chichewa
          : AppLanguage.english;
      return await _auth.authenticate(
        localizedReason: AppI18n.tr('unlock_app_prompt', language),
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  void lockNow() {
    if (!_enabled) return;
    if (_isLocked) return;
    _isLocked = true;
    notifyListeners();
  }

  void unlock() {
    if (!_isLocked) return;
    _isLocked = false;
    notifyListeners();
  }

  String _hash(String input) {
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
  }
}
