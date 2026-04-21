import 'package:flutter/foundation.dart';
import 'package:lerolove/providers/auth_provider.dart';
import 'package:lerolove/services/backend_api.dart';

class AdminProvider extends ChangeNotifier {
  final BackendApi _api = BackendApi();

  AuthProvider? _auth;

  void bind(AuthProvider auth) {
    _auth = auth;
    notifyListeners();
  }

  bool get hasSession {
    final token = _auth?.backendToken;
    return token != null && token.isNotEmpty;
  }

  Future<List<dynamic>> loadOpenReports() async {
    final token = _auth?.backendToken;
    if (token == null || token.isEmpty) return const [];
    return _api.adminReports(token: token, status: 'open');
  }

  Future<void> setReportStatus({
    required String reportId,
    required String status,
    String? note,
  }) async {
    final token = _auth?.backendToken;
    if (token == null || token.isEmpty) return;
    await _api.adminResolveReport(
      token: token,
      reportId: reportId,
      status: status,
      note: note,
    );
  }

  Future<void> banUser({required String userId, String? reason}) async {
    final token = _auth?.backendToken;
    if (token == null || token.isEmpty) return;
    await _api.adminBanUser(token: token, userId: userId, reason: reason);
  }

  Future<void> unbanUser({required String userId}) async {
    final token = _auth?.backendToken;
    if (token == null || token.isEmpty) return;
    await _api.adminUnbanUser(token: token, userId: userId);
  }
}
