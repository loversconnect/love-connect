import 'dart:async';
import 'dart:convert';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:lerolove/services/backend_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider() {
    _restoreLocalSession();
  }

  final BackendApi _backendApi = BackendApi();

  String? _localUid;
  String? _localPhoneNumber;

  String? get uid => _localUid;
  bool get isAuthenticated => _localUid != null;
  String? get currentPhoneNumber => _localPhoneNumber;
  String? _pendingOtpPhone;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  String? _backendToken;
  String? get backendToken => _backendToken;

  String? _backendUserId;
  String? get backendUserId => _backendUserId;

  bool _backendLoading = false;
  bool get backendLoading => _backendLoading;

  bool get isBackendAuthenticated =>
      _backendToken != null && _backendToken!.isNotEmpty;

  bool _pendingNotify = false;
  bool _isDisposed = false;

  void _notifySafely() {
    if (_isDisposed) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    final canNotifyNow =
        phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks;

    if (canNotifyNow) {
      notifyListeners();
      return;
    }

    if (_pendingNotify) return;
    _pendingNotify = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pendingNotify = false;
      if (_isDisposed) return;
      notifyListeners();
    });
  }

  void _setLoading(bool value) {
    _isLoading = value;
    _notifySafely();
  }

  void _setBackendLoading(bool value) {
    _backendLoading = value;
    _notifySafely();
  }

  void _setError(String? value) {
    _error = value;
    _notifySafely();
  }

  String _tokenKey(String uid) => 'backend_access_token_$uid';
  String _backendUserIdKey(String uid) => 'backend_user_id_$uid';
  String _backendEmailKey(String uid) => 'backend_email_$uid';
  String _backendPasswordKey(String uid) => 'backend_password_$uid';
  static const _localUidKey = 'local_auth_uid';
  static const _localPhoneKey = 'local_auth_phone';

  String _fallbackEmailForUid(String uid) => 'u_$uid@lerolove.app';
  String _fallbackPasswordForUid(String uid) => 'LeroLove_${uid}_Secure_2026';

  String? _extractBackendUserIdFromToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length < 2) return null;
      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final json = jsonDecode(decoded) as Map<String, dynamic>;
      final candidates = [json['sub'], json['userId'], json['id']];
      for (final value in candidates) {
        if (value is String && value.isNotEmpty) return value;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _restoreLocalSession() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUid = prefs.getString(_localUidKey);
    if (savedUid == null || savedUid.isEmpty) return;

    _localUid = savedUid;
    _localPhoneNumber = prefs.getString(_localPhoneKey);
    await ensureBackendSession();
    _notifySafely();
  }

  Future<bool> ensureBackendSession() async {
    final effectiveUid = uid;
    if (effectiveUid == null || effectiveUid.isEmpty) return false;
    if (_backendLoading) return false;
    if (isBackendAuthenticated) return true;

    _setBackendLoading(true);
    _setError(null);

    try {
      final prefs = await SharedPreferences.getInstance();

      final savedToken = prefs.getString(_tokenKey(effectiveUid));
      final savedBackendUserId = prefs.getString(
        _backendUserIdKey(effectiveUid),
      );
      if (savedToken != null && savedToken.isNotEmpty) {
        _backendToken = savedToken;
        _backendUserId =
            savedBackendUserId ?? _extractBackendUserIdFromToken(savedToken);
        _setBackendLoading(false);
        return true;
      }

      final email =
          prefs.getString(_backendEmailKey(effectiveUid)) ??
          _fallbackEmailForUid(effectiveUid);
      final password =
          prefs.getString(_backendPasswordKey(effectiveUid)) ??
          _fallbackPasswordForUid(effectiveUid);

      String token;
      try {
        token = await _backendApi.login(email: email, password: password);
      } on ApiException catch (_) {
        token = await _backendApi.register(
          email: email,
          password: password,
          name: 'Lero User',
          gender: 'OTHER',
          birthDateIso: '1999-01-01',
        );
      }

      _backendToken = token;
      _backendUserId = _extractBackendUserIdFromToken(token);

      await prefs.setString(_tokenKey(effectiveUid), token);
      await prefs.setString(_backendEmailKey(effectiveUid), email);
      await prefs.setString(_backendPasswordKey(effectiveUid), password);
      if (_backendUserId != null) {
        await prefs.setString(_backendUserIdKey(effectiveUid), _backendUserId!);
      }

      _setBackendLoading(false);
      return true;
    } catch (e) {
      _setError('Backend session error: $e');
      _setBackendLoading(false);
      return false;
    }
  }

  Future<void> _clearBackendState({required bool clearPersisted}) async {
    final effectiveUid = uid;
    _backendToken = null;
    _backendUserId = null;

    if (!clearPersisted || effectiveUid == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey(effectiveUid));
    await prefs.remove(_backendUserIdKey(effectiveUid));
  }

  Future<bool> continueWithoutOtp(String phoneNumber) async {
    _setLoading(true);
    _setError(null);

    try {
      final normalized = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
      final digitsOnly = normalized.replaceAll(RegExp(r'[^0-9]'), '');
      if (digitsOnly.isEmpty) {
        _setError('Invalid phone number.');
        _setLoading(false);
        return false;
      }

      _localUid = 'local_$digitsOnly';
      _localPhoneNumber = normalized.startsWith('+')
          ? normalized
          : '+$normalized';

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_localUidKey, _localUid!);
      await prefs.setString(_localPhoneKey, _localPhoneNumber!);

      unawaited(ensureBackendSession());
      _setLoading(false);
      return true;
    } catch (_) {
      _setError('Could not continue right now.');
      _setLoading(false);
      return false;
    }
  }

  Future<bool> startPhoneVerification(String phoneNumber) async {
    _setLoading(true);
    _setError(null);

    try {
      final normalized = phoneNumber.replaceAll(RegExp(r'\s+'), '');
      await _backendApi.sendOtp(phone: normalized);
      _pendingOtpPhone = normalized;
      _localPhoneNumber = normalized;
      _setLoading(false);
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      _setLoading(false);
      return false;
    } catch (_) {
      _setError('Could not send OTP. Please try again.');
      _setLoading(false);
      return false;
    }
  }

  Future<bool> verifySmsCode(String smsCode) async {
    final phone = _pendingOtpPhone ?? _localPhoneNumber;
    if (phone == null || phone.isEmpty) {
      _setError('Verification session expired. Request a new code.');
      return false;
    }

    _setLoading(true);
    _setError(null);

    try {
      final result = await _backendApi.verifyOtp(phone: phone, otp: smsCode);
      if (!result.success) {
        _setError(result.message ?? 'Invalid code.');
        _setLoading(false);
        return false;
      }

      final digitsOnly = phone.replaceAll(RegExp(r'[^0-9]'), '');
      _localUid = 'local_$digitsOnly';
      _localPhoneNumber = phone;
      _pendingOtpPhone = null;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_localUidKey, _localUid!);
      await prefs.setString(_localPhoneKey, _localPhoneNumber!);

      final backendOk = await ensureBackendSession();
      _setLoading(false);
      return backendOk;
    } on ApiException catch (e) {
      _setError(e.message);
      _setLoading(false);
      return false;
    } catch (_) {
      _setError('Could not verify code.');
      _setLoading(false);
      return false;
    }
  }

  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_localUidKey);
    await prefs.remove(_localPhoneKey);
    _localUid = null;
    _localPhoneNumber = null;
    await _clearBackendState(clearPersisted: true);
    _notifySafely();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
