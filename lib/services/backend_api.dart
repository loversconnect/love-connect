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
  });

  final String id;
  final String name;
  final String gender;
  final DateTime birthDate;
  final List<String> photos;
  final double distanceKm;
}

class SwipeResultDto {
  SwipeResultDto({required this.isMatch, this.matchId, this.message});

  final bool isMatch;
  final String? matchId;
  final String? message;
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

  Future<String> register({
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
    final token = _tokenFromMap(body);
    if (token == null || token.isEmpty) {
      throw ApiException('Missing access token from register response');
    }
    return token;
  }

  Future<String> login({
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
    final token = _tokenFromMap(body);
    if (token == null || token.isEmpty) {
      throw ApiException('Missing access token from login response');
    }
    return token;
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
      message: result['message'] as String?,
    );
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
