import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:lerolove/models/match_models.dart';
import 'package:lerolove/providers/auth_provider.dart';
import 'package:lerolove/services/backend_api.dart';

class ModerationProvider extends ChangeNotifier {
  final BackendApi _backendApi = BackendApi();

  AuthProvider? _auth;

  List<BlockedUser> _blockedUsers = const [];
  List<BlockedUser> get blockedUsers => _blockedUsers;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  void bind(AuthProvider auth) {
    final changed =
        _auth?.backendUserId != auth.backendUserId ||
        _auth?.backendToken != auth.backendToken;
    _auth = auth;
    if (!changed) return;

    _blockedUsers = const [];
    _error = null;

    if (!auth.isBackendAuthenticated || auth.backendToken == null) {
      notifyListeners();
      return;
    }

    unawaited(refreshBlockedUsers());
  }

  Future<bool> _ensureReady() async {
    final auth = _auth;
    if (auth == null) return false;
    for (var attempt = 0; attempt < 3; attempt++) {
      final ready = await auth.ensureBackendSession();
      if (ready && auth.backendToken != null && auth.backendToken!.isNotEmpty) {
        return true;
      }
      await Future<void>.delayed(Duration(milliseconds: 300 * (attempt + 1)));
    }
    _error = 'Backend session unavailable';
    notifyListeners();
    return false;
  }

  Future<void> refreshBlockedUsers() async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (!await _ensureReady()) {
        _isLoading = false;
        notifyListeners();
        return;
      }
      final token = _auth!.backendToken!;
      final rows = await _backendApi.blockedUsers(token: token);
      _blockedUsers = rows
          .map(
            (row) => BlockedUser(
              userId: row.userId,
              name: row.name,
              blockedAt: row.blockedAt,
            ),
          )
          .toList(growable: false);
    } catch (e) {
      _error = 'Could not load blocked users: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> blockUser({required String userId, required String name}) async {
    _error = null;
    notifyListeners();

    try {
      if (!await _ensureReady()) return;
      final token = _auth!.backendToken!;
      await _backendApi.blockUser(token: token, userId: userId);
      await refreshBlockedUsers();
    } catch (e) {
      _error = 'Could not block user: $e';
      notifyListeners();
    }
  }

  Future<void> unblockUser(String userId) async {
    _error = null;
    notifyListeners();

    try {
      if (!await _ensureReady()) return;
      final token = _auth!.backendToken!;
      await _backendApi.unblockUser(token: token, userId: userId);
      await refreshBlockedUsers();
    } catch (e) {
      _error = 'Could not unblock user: $e';
      notifyListeners();
    }
  }

  Future<void> reportUser({
    required String reportedUserId,
    required String reason,
    String? details,
    String? matchId,
  }) async {
    _error = null;
    notifyListeners();

    try {
      if (!await _ensureReady()) return;
      final token = _auth!.backendToken!;
      await _backendApi.reportUser(
        token: token,
        reportedUserId: reportedUserId,
        reason: reason,
        details: details,
        matchId: matchId,
      );
    } catch (e) {
      _error = 'Could not submit report: $e';
      notifyListeners();
    }
  }
}
