import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:lerolove/services/api_config.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class DiscoveryUserDto {
  DiscoveryUserDto({
    required this.id,
    required this.name,
    required this.gender,
    required this.birthDate,
    required this.photos,
    required this.distanceKm,
    this.isOnline,
    this.isVerified,
  });

  final String id;
  final String name;
  final String gender;
  final DateTime birthDate;
  final List<String> photos;
  final double distanceKm;
  final bool? isOnline;
  final bool? isVerified;
}

class SwipeResultDto {
  SwipeResultDto({
    required this.isMatch,
    this.matchId,
    this.chatId,
    this.conversationReady,
    this.peerUserId,
    this.peerName,
    this.peerPhotoUrl,
    this.message,
  });

  final bool isMatch;
  final String? matchId;
  final String? chatId;
  final bool? conversationReady;
  final String? peerUserId;
  final String? peerName;
  final String? peerPhotoUrl;
  final String? message;
}

class OtpVerifyResultDto {
  OtpVerifyResultDto({
    required this.success,
    this.message,
    this.accessToken,
    this.refreshToken,
    this.isNewUser,
    this.userId,
  });

  final bool success;
  final String? message;
  final String? accessToken;
  final String? refreshToken;
  final bool? isNewUser;
  final String? userId;
}

class BackendProfileDto {
  BackendProfileDto({
    required this.id,
    required this.name,
    required this.gender,
    required this.birthDate,
    required this.phone,
    required this.bio,
    required this.photos,
    required this.lat,
    required this.lng,
  });

  final String id;
  final String name;
  final String gender;
  final DateTime? birthDate;
  final String? phone;
  final String? bio;
  final List<String> photos;
  final double? lat;
  final double? lng;
}

class AuthSessionDto {
  AuthSessionDto({
    required this.accessToken,
    required this.refreshToken,
    this.tokenType,
    this.expiresIn,
  });

  final String accessToken;
  final String refreshToken;
  final String? tokenType;
  final String? expiresIn;
}

class ChatMessageDto {
  ChatMessageDto({
    required this.id,
    required this.senderId,
    required this.content,
    required this.createdAt,
    this.isRead,
  });

  final String id;
  final String senderId;
  final String content;
  final DateTime? createdAt;
  final bool? isRead;
}

class BlockedUserDto {
  BlockedUserDto({
    required this.userId,
    required this.name,
    required this.blockedAt,
  });

  final String userId;
  final String name;
  final DateTime? blockedAt;
}

class MatchSummaryDto {
  MatchSummaryDto({
    required this.matchId,
    required this.peerUserId,
    required this.peerName,
    this.peerPhotoUrl,
    this.matchedAt,
  });

  final String matchId;
  final String peerUserId;
  final String peerName;
  final String? peerPhotoUrl;
  final DateTime? matchedAt;
}

class PrivacySettingsDto {
  PrivacySettingsDto({
    required this.discoverable,
    required this.showOnlineStatus,
    required this.showDistanceInDiscovery,
    required this.allowMessagesFromMatchesOnly,
  });

  final bool discoverable;
  final bool showOnlineStatus;
  final bool showDistanceInDiscovery;
  final bool allowMessagesFromMatchesOnly;
}

class BackendApi {
  BackendApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  final String _baseUrl = ApiConfig.baseUrl;
  static const Duration _requestTimeout = Duration(seconds: 12);

  Uri _uri(String path, [Map<String, String>? query]) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final sanitizedBase = _baseUrl.replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.parse('$sanitizedBase$normalizedPath');
    if (query == null || query.isEmpty) return uri;
    return uri.replace(queryParameters: query);
  }

  Future<http.Response> _get(Uri uri, {Map<String, String>? headers}) {
    return _client
        .get(uri, headers: headers)
        .timeout(
          _requestTimeout,
          onTimeout: () => throw ApiException('Request timed out'),
        );
  }

  Future<http.Response> _post(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) {
    return _client
        .post(uri, headers: headers, body: body)
        .timeout(
          _requestTimeout,
          onTimeout: () => throw ApiException('Request timed out'),
        );
  }

  Future<http.Response> _put(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) {
    return _client
        .put(uri, headers: headers, body: body)
        .timeout(
          _requestTimeout,
          onTimeout: () => throw ApiException('Request timed out'),
        );
  }

  Map<String, String> _headers({String? token}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  dynamic _decode(http.Response response) {
    if (response.body.trim().isEmpty) return null;
    return jsonDecode(response.body);
  }

  String? _tokenFromMap(Map<String, dynamic>? map) {
    if (map == null) return null;
    final directToken =
        map['access_token'] ?? map['accessToken'] ?? map['token'] ?? map['jwt'];
    if (directToken is String && directToken.isNotEmpty) return directToken;

    final data = map['data'];
    if (data is Map<String, dynamic>) {
      return _tokenFromMap(data);
    }
    return null;
  }

  String? _refreshTokenFromMap(Map<String, dynamic>? map) {
    if (map == null) return null;
    final direct = map['refresh_token'] ?? map['refreshToken'];
    if (direct is String && direct.isNotEmpty) return direct;
    final data = map['data'];
    if (data is Map<String, dynamic>) {
      return _refreshTokenFromMap(data);
    }
    return null;
  }

  AuthSessionDto _sessionFromBody(Map<String, dynamic> body) {
    final access = _tokenFromMap(body);
    final refresh = _refreshTokenFromMap(body);
    if (access == null || access.isEmpty) {
      throw ApiException('Missing access token from response');
    }
    if (refresh == null || refresh.isEmpty) {
      throw ApiException('Missing refresh token from response');
    }
    return AuthSessionDto(
      accessToken: access,
      refreshToken: refresh,
      tokenType: body['token_type'] as String?,
      expiresIn: body['expires_in']?.toString(),
    );
  }

  List<dynamic> _listFromBody(dynamic body) {
    if (body is List) return body;
    if (body is Map<String, dynamic>) {
      final candidates = [body['data'], body['users'], body['messages']];
      for (final value in candidates) {
        if (value is List) return value;
      }
    }
    return const [];
  }

  Map<String, dynamic> _mapFromBody(dynamic body) {
    if (body is Map<String, dynamic>) return body;
    return const {};
  }

  void _ensureSuccess(
    http.Response response, {
    String fallback = 'Request failed',
  }) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;

    final decoded = _decode(response);
    String message = fallback;
    if (decoded is Map<String, dynamic>) {
      final rawMessage = decoded['message'];
      if (rawMessage is String && rawMessage.isNotEmpty) {
        message = rawMessage;
      } else if (rawMessage is List && rawMessage.isNotEmpty) {
        message = rawMessage.join(', ');
      }
    }
    throw ApiException(message, statusCode: response.statusCode);
  }

  Future<AuthSessionDto> register({
    required String email,
    required String password,
    required String name,
    required String gender,
    required String birthDateIso,
  }) async {
    final response = await _post(
      _uri('/auth/register'),
      headers: _headers(),
      body: jsonEncode({
        'email': email,
        'password': password,
        'name': name,
        'gender': gender,
        'birthDate': birthDateIso,
      }),
    );
    _ensureSuccess(response, fallback: 'Registration failed');
    final body = _mapFromBody(_decode(response));
    return _sessionFromBody(body);
  }

  Future<AuthSessionDto> login({
    required String email,
    required String password,
  }) async {
    final response = await _post(
      _uri('/auth/login'),
      headers: _headers(),
      body: jsonEncode({'email': email, 'password': password}),
    );
    _ensureSuccess(response, fallback: 'Login failed');
    final body = _mapFromBody(_decode(response));
    return _sessionFromBody(body);
  }

  Future<AuthSessionDto> refresh({required String refreshToken}) async {
    final response = await _post(
      _uri('/auth/refresh'),
      headers: _headers(),
      body: jsonEncode({'refreshToken': refreshToken}),
    );
    _ensureSuccess(response, fallback: 'Session refresh failed');
    final body = _mapFromBody(_decode(response));
    return _sessionFromBody(body);
  }

  Future<void> logout({required String refreshToken}) async {
    final response = await _post(
      _uri('/auth/logout'),
      headers: _headers(),
      body: jsonEncode({'refreshToken': refreshToken}),
    );
    _ensureSuccess(response, fallback: 'Logout failed');
  }

  Future<void> sendOtp({required String phone}) async {
    final response = await _post(
      _uri('/auth/send-otp'),
      headers: _headers(),
      body: jsonEncode({'phone': phone}),
    );
    _ensureSuccess(response, fallback: 'Failed to send OTP');
  }

  Future<OtpVerifyResultDto> verifyOtp({
    required String phone,
    required String otp,
  }) async {
    final response = await _post(
      _uri('/auth/verify-otp'),
      headers: _headers(),
      body: jsonEncode({'phone': phone, 'otp': otp}),
    );
    _ensureSuccess(response, fallback: 'Failed to verify OTP');
    final body = _mapFromBody(_decode(response));
    final user = _mapFromBody(body['user']);
    return OtpVerifyResultDto(
      success: (body['success'] as bool?) ?? true,
      message: body['message'] as String?,
      accessToken: body['access_token'] as String?,
      refreshToken: body['refresh_token'] as String?,
      isNewUser: body['isNewUser'] as bool?,
      userId: user['id'] as String?,
    );
  }

  Future<BackendProfileDto> me({required String token}) async {
    final response = await _get(
      _uri('/users/me'),
      headers: _headers(token: token),
    );
    _ensureSuccess(response, fallback: 'Failed to load profile');
    final body = _mapFromBody(_decode(response));
    final photosRaw = body['photos'];
    return BackendProfileDto(
      id: (body['id'] as String?) ?? '',
      name: (body['name'] as String?) ?? '',
      gender: (body['gender'] as String?) ?? 'OTHER',
      birthDate: DateTime.tryParse((body['birthDate'] as String?) ?? ''),
      phone: body['phone'] as String?,
      bio: body['bio'] as String?,
      photos: ((photosRaw as List?) ?? const [])
          .map((e) => e.toString())
          .toList(growable: false),
      lat: (body['lat'] as num?)?.toDouble(),
      lng: (body['lng'] as num?)?.toDouble(),
    );
  }

  Future<void> updateLocation({
    required String token,
    required double lat,
    required double lng,
  }) async {
    final body = jsonEncode({'lat': lat, 'lng': lng});
    final response = await _put(
      _uri('/users/location'),
      headers: _headers(token: token),
      body: body,
    );
    if (response.statusCode == 404 || response.statusCode == 405) {
      final fallbackResponse = await _put(
        _uri('/users/locationUpdate'),
        headers: _headers(token: token),
        body: body,
      );
      _ensureSuccess(fallbackResponse, fallback: 'Failed to update location');
      return;
    }
    _ensureSuccess(response, fallback: 'Failed to update location');
  }

  Future<void> updateUserProfile({
    required String token,
    String? name,
    String? gender,
    String? birthDateIso,
    List<String>? photos,
  }) async {
    final payload = <String, dynamic>{};
    if (name != null && name.trim().isNotEmpty) {
      payload['name'] = name.trim();
    }
    if (gender != null && gender.trim().isNotEmpty) {
      payload['gender'] = gender.trim();
    }
    if (birthDateIso != null && birthDateIso.trim().isNotEmpty) {
      payload['birthDate'] = birthDateIso.trim();
    }
    if (photos != null) {
      payload['photos'] = photos;
    }
    if (payload.isEmpty) return;

    final response = await _put(
      _uri('/users/profile'),
      headers: _headers(token: token),
      body: jsonEncode(payload),
    );
    _ensureSuccess(response, fallback: 'Failed to update profile');
  }

  Future<List<BlockedUserDto>> blockedUsers({required String token}) async {
    final response = await _get(
      _uri('/users/blocks'),
      headers: _headers(token: token),
    );
    _ensureSuccess(response, fallback: 'Failed to load blocked users');
    final body = _listFromBody(_decode(response));
    return body
        .map<BlockedUserDto>((raw) {
          final map = raw as Map<String, dynamic>;
          return BlockedUserDto(
            userId: (map['userId'] as String?) ?? '',
            name: (map['name'] as String?) ?? 'Unknown',
            blockedAt: DateTime.tryParse((map['blockedAt'] as String?) ?? ''),
          );
        })
        .where((e) => e.userId.isNotEmpty)
        .toList(growable: false);
  }

  Future<void> blockUser({
    required String token,
    required String userId,
  }) async {
    final response = await _post(
      _uri('/users/block'),
      headers: _headers(token: token),
      body: jsonEncode({'userId': userId}),
    );
    _ensureSuccess(response, fallback: 'Failed to block user');
  }

  Future<void> unblockUser({
    required String token,
    required String userId,
  }) async {
    final response = await _post(
      _uri('/users/unblock'),
      headers: _headers(token: token),
      body: jsonEncode({'userId': userId}),
    );
    _ensureSuccess(response, fallback: 'Failed to unblock user');
  }

  Future<void> reportUser({
    required String token,
    required String reportedUserId,
    required String reason,
    String? details,
    String? matchId,
  }) async {
    final payload = <String, dynamic>{
      'reportedUserId': reportedUserId,
      'reason': reason,
    };
    if (details != null && details.trim().isNotEmpty) {
      payload['details'] = details.trim();
    }
    if (matchId != null && matchId.trim().isNotEmpty) {
      payload['matchId'] = matchId.trim();
    }

    final response = await _post(
      _uri('/users/report'),
      headers: _headers(token: token),
      body: jsonEncode(payload),
    );
    _ensureSuccess(response, fallback: 'Failed to report user');
  }

  Future<void> deleteMyAccount({required String token}) async {
    final response = await _post(
      _uri('/users/account/delete'),
      headers: _headers(token: token),
      body: jsonEncode(const {}),
    );
    _ensureSuccess(response, fallback: 'Failed to delete account');
  }

  Future<void> upsertDeviceToken({
    required String token,
    required String deviceToken,
    required String platform,
  }) async {
    final response = await _post(
      _uri('/users/device-token'),
      headers: _headers(token: token),
      body: jsonEncode({'token': deviceToken, 'platform': platform}),
    );
    _ensureSuccess(response, fallback: 'Failed to register notification token');
  }

  Future<void> removeDeviceToken({
    required String token,
    required String deviceToken,
  }) async {
    final response = await _post(
      _uri('/users/device-token/remove'),
      headers: _headers(token: token),
      body: jsonEncode({'token': deviceToken}),
    );
    _ensureSuccess(response, fallback: 'Failed to remove notification token');
  }

  Future<PrivacySettingsDto> getPrivacySettings({required String token}) async {
    final response = await _get(
      _uri('/users/privacy'),
      headers: _headers(token: token),
    );
    _ensureSuccess(response, fallback: 'Failed to load privacy settings');
    final body = _mapFromBody(_decode(response));
    final data = _mapFromBody(body['data']);
    final source = data.isNotEmpty ? data : body;
    return PrivacySettingsDto(
      discoverable: (source['discoverable'] as bool?) ?? true,
      showOnlineStatus: (source['showOnlineStatus'] as bool?) ?? true,
      showDistanceInDiscovery:
          (source['showDistanceInDiscovery'] as bool?) ?? true,
      allowMessagesFromMatchesOnly:
          (source['allowMessagesFromMatchesOnly'] as bool?) ?? true,
    );
  }

  Future<PrivacySettingsDto> updatePrivacySettings({
    required String token,
    bool? discoverable,
    bool? showOnlineStatus,
    bool? showDistanceInDiscovery,
    bool? allowMessagesFromMatchesOnly,
  }) async {
    final payload = <String, dynamic>{};
    if (discoverable != null) {
      payload['discoverable'] = discoverable;
    }
    if (showOnlineStatus != null) {
      payload['showOnlineStatus'] = showOnlineStatus;
    }
    if (showDistanceInDiscovery != null) {
      payload['showDistanceInDiscovery'] = showDistanceInDiscovery;
    }
    if (allowMessagesFromMatchesOnly != null) {
      payload['allowMessagesFromMatchesOnly'] = allowMessagesFromMatchesOnly;
    }
    if (payload.isEmpty) {
      throw ApiException('No privacy settings provided');
    }

    final response = await _put(
      _uri('/users/privacy'),
      headers: _headers(token: token),
      body: jsonEncode(payload),
    );
    _ensureSuccess(response, fallback: 'Failed to update privacy settings');
    final body = _mapFromBody(_decode(response));
    final data = _mapFromBody(body['data']);
    final source = data.isNotEmpty ? data : body;

    return PrivacySettingsDto(
      discoverable: (source['discoverable'] as bool?) ?? true,
      showOnlineStatus: (source['showOnlineStatus'] as bool?) ?? true,
      showDistanceInDiscovery:
          (source['showDistanceInDiscovery'] as bool?) ?? true,
      allowMessagesFromMatchesOnly:
          (source['allowMessagesFromMatchesOnly'] as bool?) ?? true,
    );
  }

  bool _isRemoteUrl(String value) {
    final lower = value.toLowerCase();
    return lower.startsWith('http://') || lower.startsWith('https://');
  }

  Future<String> uploadProfilePhoto({
    required String token,
    required String filePath,
  }) async {
    final normalizedPath = filePath.trim();
    if (normalizedPath.isEmpty) {
      throw ApiException('Photo path is empty');
    }
    if (_isRemoteUrl(normalizedPath)) {
      return normalizedPath;
    }

    final request = http.MultipartRequest('POST', _uri('/users/upload-photo'));
    request.headers['Accept'] = 'application/json';
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(
      await http.MultipartFile.fromPath('photo', normalizedPath),
    );

    late final http.StreamedResponse streamed;
    try {
      streamed = await request.send().timeout(
        _requestTimeout,
        onTimeout: () => throw ApiException('Photo upload timed out'),
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Photo upload failed: $e');
    }

    final response = await http.Response.fromStream(streamed);
    _ensureSuccess(response, fallback: 'Failed to upload photo');
    final body = _mapFromBody(_decode(response));
    final directUrl = body['url'];
    if (directUrl is String && directUrl.trim().isNotEmpty) {
      return directUrl.trim();
    }
    final dataUrl = _mapFromBody(body['data'])['url'];
    if (dataUrl is String && dataUrl.trim().isNotEmpty) {
      return dataUrl.trim();
    }
    throw ApiException('Photo upload succeeded but no URL was returned');
  }

  Future<List<DiscoveryUserDto>> discovery({
    required String token,
    required double radiusKm,
  }) async {
    final response = await _get(
      _uri('/users/discovery', {'radius': radiusKm.round().toString()}),
      headers: _headers(token: token),
    );
    _ensureSuccess(response, fallback: 'Failed to load discovery');
    final body = _listFromBody(_decode(response));

    return body
        .map<DiscoveryUserDto>((raw) {
          final map = raw as Map<String, dynamic>;
          final photosRaw = map['photos'] ?? map['photoUrls'] ?? map['images'];
          final distanceRaw =
              map['distance'] ?? map['distanceKm'] ?? map['distance_km'];
          return DiscoveryUserDto(
            id:
                (map['id'] as String?) ??
                (map['_id'] as String?) ??
                (map['userId'] as String?) ??
                '',
            name: (map['name'] as String?) ?? 'Unknown',
            gender: (map['gender'] as String?) ?? 'OTHER',
            birthDate:
                DateTime.tryParse((map['birthDate'] as String?) ?? '') ??
                DateTime(1999, 1, 1),
            photos: ((photosRaw as List?) ?? const [])
                .map((p) => p.toString())
                .toList(growable: false),
            distanceKm: (distanceRaw as num?)?.toDouble() ?? 0,
            isOnline: map['isOnline'] is bool ? map['isOnline'] as bool : null,
            isVerified: map['isVerified'] is bool
                ? map['isVerified'] as bool
                : null,
          );
        })
        .where((e) => e.id.isNotEmpty)
        .toList(growable: false);
  }

  Future<SwipeResultDto> swipe({
    required String token,
    required String swipedId,
    required bool action,
  }) async {
    final response = await _post(
      _uri('/swipes'),
      headers: _headers(token: token),
      body: jsonEncode({'swipedId': swipedId, 'action': action}),
    );
    _ensureSuccess(response, fallback: 'Failed to send swipe');
    final body = _mapFromBody(_decode(response));
    final result = <String, dynamic>{..._mapFromBody(body['data']), ...body};
    return SwipeResultDto(
      isMatch: (result['isMatch'] as bool?) ?? false,
      matchId: result['matchId'] as String?,
      chatId: result['chatId'] as String?,
      conversationReady: result['conversationReady'] as bool?,
      peerUserId: _mapFromBody(result['peer'])['id'] as String?,
      peerName: _mapFromBody(result['peer'])['name'] as String?,
      peerPhotoUrl: _mapFromBody(result['peer'])['photoUrl'] as String?,
      message: result['message'] as String?,
    );
  }

  Future<void> unmatch({
    required String token,
    required String peerUserId,
  }) async {
    final response = await _post(
      _uri('/swipes/unmatch'),
      headers: _headers(token: token),
      body: jsonEncode({'peerUserId': peerUserId}),
    );
    _ensureSuccess(response, fallback: 'Failed to unmatch');
  }

  Future<List<MatchSummaryDto>> myMatches({required String token}) async {
    final response = await _get(
      _uri('/swipes/matches'),
      headers: _headers(token: token),
    );
    _ensureSuccess(response, fallback: 'Failed to load matches');
    final body = _listFromBody(_decode(response));
    return body
        .map<MatchSummaryDto>((raw) {
          final map = raw as Map<String, dynamic>;
          return MatchSummaryDto(
            matchId: (map['matchId'] as String?) ?? '',
            peerUserId: (map['peerUserId'] as String?) ?? '',
            peerName: (map['peerName'] as String?) ?? 'Match',
            peerPhotoUrl: map['peerPhotoUrl'] as String?,
            matchedAt: DateTime.tryParse((map['matchedAt'] as String?) ?? ''),
          );
        })
        .where((e) => e.matchId.isNotEmpty && e.peerUserId.isNotEmpty)
        .toList(growable: false);
  }

  Future<ChatMessageDto> sendMessage({
    required String token,
    required String receiverId,
    required String content,
  }) async {
    final response = await _post(
      _uri('/chat/send'),
      headers: _headers(token: token),
      body: jsonEncode({'receiverId': receiverId, 'content': content}),
    );
    _ensureSuccess(response, fallback: 'Failed to send message');
    final body = _mapFromBody(_decode(response));
    final dataMap = _mapFromBody(body['data']);
    final dataMessageMap = _mapFromBody(dataMap['message']);
    final topMessageMap = _mapFromBody(body['message']);
    final messageBody = dataMessageMap.isNotEmpty
        ? dataMessageMap
        : (topMessageMap.isNotEmpty ? topMessageMap : body);

    return ChatMessageDto(
      id:
          (messageBody['_id'] as String?) ??
          (messageBody['id'] as String?) ??
          '',
      senderId:
          (messageBody['senderId'] as String?) ??
          (_mapFromBody(messageBody['sender'])['_id'] as String?) ??
          '',
      content:
          (messageBody['content'] as String?) ??
          (messageBody['text'] as String?) ??
          '',
      createdAt: DateTime.tryParse((messageBody['createdAt'] as String?) ?? ''),
      isRead: messageBody['isRead'] as bool?,
    );
  }

  Future<void> markChatRead({
    required String token,
    required String receiverId,
  }) async {
    final response = await _post(
      _uri('/chat/read/$receiverId'),
      headers: _headers(token: token),
      body: jsonEncode(const {}),
    );
    _ensureSuccess(response, fallback: 'Failed to mark chat as read');
  }

  Future<List<dynamic>> adminReports({
    required String token,
    String status = 'open',
  }) async {
    final response = await _get(
      _uri('/users/admin/reports', {'status': status}),
      headers: _headers(token: token),
    );
    _ensureSuccess(response, fallback: 'Failed to load admin reports');
    return _listFromBody(_decode(response));
  }

  Future<void> adminBanUser({
    required String token,
    required String userId,
    String? reason,
  }) async {
    final payload = <String, dynamic>{'userId': userId};
    if (reason != null && reason.trim().isNotEmpty) {
      payload['reason'] = reason.trim();
    }
    final response = await _post(
      _uri('/users/admin/ban'),
      headers: _headers(token: token),
      body: jsonEncode(payload),
    );
    _ensureSuccess(response, fallback: 'Failed to ban user');
  }

  Future<void> adminResolveReport({
    required String token,
    required String reportId,
    required String status,
    String? note,
  }) async {
    final payload = <String, dynamic>{'status': status};
    if (note != null && note.trim().isNotEmpty) {
      payload['note'] = note.trim();
    }
    final response = await _post(
      _uri('/users/admin/reports/$reportId/resolve'),
      headers: _headers(token: token),
      body: jsonEncode(payload),
    );
    _ensureSuccess(response, fallback: 'Failed to resolve report');
  }

  Future<void> adminUnbanUser({
    required String token,
    required String userId,
  }) async {
    final response = await _post(
      _uri('/users/admin/unban'),
      headers: _headers(token: token),
      body: jsonEncode({'userId': userId}),
    );
    _ensureSuccess(response, fallback: 'Failed to unban user');
  }

  Future<List<ChatMessageDto>> history({
    required String token,
    required String receiverId,
  }) async {
    final response = await _get(
      _uri('/chat/history/$receiverId'),
      headers: _headers(token: token),
    );
    _ensureSuccess(response, fallback: 'Failed to load chat history');
    final body = _listFromBody(_decode(response));

    return body
        .map<ChatMessageDto>((raw) {
          final map = raw as Map<String, dynamic>;
          return ChatMessageDto(
            id: (map['_id'] as String?) ?? (map['id'] as String?) ?? '',
            senderId:
                (map['senderId'] as String?) ??
                (_mapFromBody(map['sender'])['_id'] as String?) ??
                '',
            content:
                (map['content'] as String?) ?? (map['text'] as String?) ?? '',
            createdAt: DateTime.tryParse((map['createdAt'] as String?) ?? ''),
            isRead: map['isRead'] as bool?,
          );
        })
        .toList(growable: false);
  }

  Future<bool> ping() async {
    try {
      final response = await _get(_uri('/api/docs'));
      return response.statusCode >= 200 && response.statusCode < 500;
    } catch (_) {
      return false;
    }
  }
}
