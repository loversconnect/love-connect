import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:lerolove/models/match_models.dart';
import 'package:lerolove/providers/auth_provider.dart';
import 'package:lerolove/services/backend_api.dart';
import 'package:lerolove/services/api_config.dart';
import 'package:lerolove/services/push_service.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:shared_preferences/shared_preferences.dart';

class MatchesProvider extends ChangeNotifier {
  final BackendApi _backendApi = BackendApi();

  AuthProvider? _auth;
  Timer? _pollTimer;
  io.Socket? _socket;
  StreamSubscription<Map<String, dynamic>>? _pushSub;
  final Map<String, StreamController<List<ChatMessageModel>>> _messageStreams =
      {};
  final Map<String, List<ChatMessageModel>> _cachedMessages = {};
  final Map<String, String> _matchPeerMap = {};
  final Set<String> _loadedHistories = <String>{};
  final Map<String, bool> _typingByMatchId = <String, bool>{};
  final Map<String, Timer> _typingDebounceTimers = <String, Timer>{};
  final List<_QueuedMessage> _queuedMessages = <_QueuedMessage>[];
  Timer? _retryTimer;

  List<MatchThread> _matches = const [];
  List<MatchThread> get matches =>
      _matches.where((m) => m.isActive).toList(growable: false);

  bool _isLoading = false;
  bool get isLoading => _isLoading;
  bool _isOffline = false;
  DateTime? _lastSyncedAt;
  DateTime? _lastHistorySyncedAt;

  bool get isOffline => _isOffline;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  DateTime? get lastHistorySyncedAt => _lastHistorySyncedAt;
  int get queuedMessagesCount => _queuedMessages.length;
  bool isPeerTyping(String matchId) => _typingByMatchId[matchId] == true;

  MatchThread? matchForPeer(String peerUserId) {
    for (final match in matches) {
      final peer = _matchPeerMap[match.id];
      if (peer == peerUserId) return match;
    }
    return null;
  }

  bool hasActiveMatchWith(String peerUserId) =>
      matchForPeer(peerUserId) != null;

  MatchThread? matchById(String matchId) {
    for (final match in _matches) {
      if (match.id == matchId) return match;
    }
    return null;
  }

  bool hasLoadedConversation(String matchId) =>
      _loadedHistories.contains(matchId);

  String _storageKey(String backendUserId) => 'backend_matches_$backendUserId';

  void bind(AuthProvider auth) {
    final changed =
        _auth?.backendUserId != auth.backendUserId ||
        _auth?.isBackendAuthenticated != auth.isBackendAuthenticated;
    _auth = auth;
    if (!changed) return;

    _pollTimer?.cancel();
    _socket?.dispose();
    _socket = null;
    _pushSub?.cancel();
    _pushSub = null;
    for (final stream in _messageStreams.values) {
      stream.close();
    }
    _messageStreams.clear();
    _cachedMessages.clear();
    _matchPeerMap.clear();
    _loadedHistories.clear();
    _typingByMatchId.clear();
    for (final timer in _typingDebounceTimers.values) {
      timer.cancel();
    }
    _typingDebounceTimers.clear();
    _queuedMessages.clear();
    _retryTimer?.cancel();
    _retryTimer = null;
    _matches = const [];

    if (!auth.isBackendAuthenticated || auth.backendUserId == null) {
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    _loadPersistedMatches().then((_) async {
      await _syncBackendMatches();
      await _refreshAllHistories();
      _isLoading = false;
      notifyListeners();
      _startPolling();
      _connectSocket();
      _bindPushEvents();
    });
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      unawaited(_syncBackendMatches());
      unawaited(_refreshAllHistories());
      unawaited(_retryQueuedMessages());
    });
  }

  Future<void> refreshNow() async {
    await _syncBackendMatches();
    await _refreshAllHistories();
    notifyListeners();
  }

  Future<void> refreshConversation(String matchId) async {
    await _refreshHistory(matchId);
    notifyListeners();
  }

  void _connectSocket() {
    final token = _auth?.backendToken;
    if (token == null || token.isEmpty) return;

    _socket?.dispose();
    _socket = null;

    final wsBase = ApiConfig.baseUrl
        .replaceFirst(RegExp(r'^https://'), 'wss://')
        .replaceFirst(RegExp(r'^http://'), 'ws://');

    final socket = io.io(
      '$wsBase/ws',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .enableReconnection()
          .setAuth({'token': token})
          .disableAutoConnect()
          .build(),
    );

    socket.onConnect((_) {
      for (final peerId in _matchPeerMap.values) {
        socket.emit('chat.join', {'peerId': peerId});
      }
    });

    socket.on('chat.message', (raw) {
      if (raw is! Map) return;
      final map = raw.map((k, v) => MapEntry(k.toString(), v));
      _handleRealtimeMessage(map);
    });

    socket.on('chat.read', (raw) {
      if (raw is! Map) return;
      final map = raw.map((k, v) => MapEntry(k.toString(), v));
      _handleRealtimeRead(map);
    });

    socket.on('match.created', (raw) async {
      if (raw is! Map) return;
      final map = raw.map((k, v) => MapEntry(k.toString(), v));
      final matchId = (map['matchId'] ?? '').toString();
      final otherUserId = (map['otherUserId'] ?? '').toString();
      if (matchId.isEmpty || otherUserId.isEmpty) return;
      await registerMatch(
        matchId: matchId,
        peerUserId: otherUserId,
        peerName: (map['otherName'] ?? 'Match').toString(),
      );
    });

    socket.on('chat.typing', (raw) {
      if (raw is! Map) return;
      final map = raw.map((k, v) => MapEntry(k.toString(), v));
      _handleRealtimeTyping(map);
    });

    socket.connect();
    _socket = socket;
  }

  void _bindPushEvents() {
    _pushSub?.cancel();
    _pushSub = PushService.instance.events.listen((event) {
      final type = (event['type'] ?? '').toString();
      if (type == 'chat.message') {
        final chatId = (event['chatId'] ?? '').toString();
        if (chatId.isNotEmpty) {
          unawaited(_refreshHistory(chatId));
        } else {
          unawaited(_refreshAllHistories());
        }
      } else if (type == 'match.created') {
        final matchId = (event['matchId'] ?? '').toString();
        final otherUserId = (event['otherUserId'] ?? '').toString();
        if (matchId.isNotEmpty && otherUserId.isNotEmpty) {
          unawaited(
            registerMatch(
              matchId: matchId,
              peerUserId: otherUserId,
              peerName: 'Match',
            ),
          );
        }
      }
    });
  }

  Future<void> _loadPersistedMatches() async {
    final auth = _auth;
    if (auth == null || auth.backendUserId == null) return;

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey(auth.backendUserId!));
    if (raw == null || raw.isEmpty) return;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      _matches = decoded
          .whereType<Map<String, dynamic>>()
          .map(MatchThread.fromJson)
          .toList(growable: false);
      for (final match in _matches) {
        final peer = _otherUserId(match);
        if (peer != null) _matchPeerMap[match.id] = peer;
      }
      _lastSyncedAt = DateTime.now();
    } catch (_) {
      _matches = const [];
    }
  }

  Future<void> _syncBackendMatches() async {
    final auth = _auth;
    final token = await _resolveToken();
    final me = auth?.backendUserId;
    if (token == null || token.isEmpty || me == null) return;

    try {
      final backendMatches = await _backendApi.myMatches(token: token);
      if (backendMatches.isEmpty) return;

      var changed = false;
      final copy = [..._matches];
      for (final dto in backendMatches) {
        final thread = MatchThread(
          id: dto.matchId,
          userIds: [me, dto.peerUserId]..sort(),
          lastMessage: '',
          lastMessageAt: dto.matchedAt ?? DateTime.now(),
          lastSenderId: null,
          unreadCounts: {me: 0},
          isActive: true,
          peerName: dto.peerName,
          peerPhotoUrl: dto.peerPhotoUrl,
        );

        final index = copy.indexWhere((m) => m.id == dto.matchId);
        if (index >= 0) {
          final existing = copy[index];
          copy[index] = existing.copyWith(
            userIds: thread.userIds,
            isActive: true,
            peerName: thread.peerName,
            peerPhotoUrl: thread.peerPhotoUrl,
          );
        } else {
          copy.add(thread);
        }
        _matchPeerMap[dto.matchId] = dto.peerUserId;
        changed = true;
      }

      if (changed) {
        _matches = copy;
        await _persistMatches();
      }
      _isOffline = false;
      _lastSyncedAt = DateTime.now();
      notifyListeners();
    } catch (_) {
      _isOffline = true;
    }
  }

  Future<void> _persistMatches() async {
    final auth = _auth;
    if (auth == null || auth.backendUserId == null) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(
      _matches.map((m) => m.toJson()).toList(growable: false),
    );
    await prefs.setString(_storageKey(auth.backendUserId!), raw);
  }

  String? _otherUserId(MatchThread match) {
    final me = _auth?.backendUserId;
    if (me == null) return null;
    for (final id in match.userIds) {
      if (id != me) return id;
    }
    return null;
  }

  Future<void> registerMatch({
    required String matchId,
    required String peerUserId,
    required String peerName,
    String? peerPhotoUrl,
  }) async {
    final me = _auth?.backendUserId;
    if (me == null) return;

    final existingIndex = _matches.indexWhere((m) => m.id == matchId);
    final thread = MatchThread(
      id: matchId,
      userIds: [me, peerUserId]..sort(),
      lastMessage: '',
      lastMessageAt: DateTime.now(),
      lastSenderId: null,
      unreadCounts: {me: 0},
      isActive: true,
      peerName: peerName,
      peerPhotoUrl: peerPhotoUrl,
    );

    if (existingIndex >= 0) {
      final copy = [..._matches];
      copy[existingIndex] = thread;
      _matches = copy;
    } else {
      _matches = [thread, ..._matches];
    }
    _matchPeerMap[matchId] = peerUserId;
    await _persistMatches();
    await _refreshHistory(matchId);
    _socket?.emit('chat.join', {'peerId': peerUserId});
    notifyListeners();
  }

  Stream<List<ChatMessageModel>> messagesStream(String matchId) {
    final existing = _messageStreams[matchId];
    if (existing != null) return existing.stream;

    final controller = StreamController<List<ChatMessageModel>>.broadcast();
    _messageStreams[matchId] = controller;
    controller.add(_cachedMessages[matchId] ?? const []);
    unawaited(_refreshHistory(matchId));
    return controller.stream;
  }

  Future<void> _refreshAllHistories() async {
    for (final thread in matches) {
      await _refreshHistory(thread.id);
    }
  }

  Future<void> _refreshHistory(String matchId) async {
    final auth = _auth;
    final token = await _resolveToken();
    final peerId = _matchPeerMap[matchId] ?? _derivePeerId(matchId);
    if (auth == null || token == null || peerId == null) {
      final cached = _cachedMessages[matchId] ?? const <ChatMessageModel>[];
      if (cached.isNotEmpty) {
        _loadedHistories.add(matchId);
        _messageStreams[matchId]?.add(cached);
        notifyListeners();
      }
      return;
    }

    try {
      final history = await _backendApi.history(
        token: token,
        receiverId: peerId,
      );
      final messages =
          history
              .map(
                (dto) => ChatMessageModel(
                  id: dto.id.isEmpty
                      ? DateTime.now().millisecondsSinceEpoch.toString()
                      : dto.id,
                  senderId: dto.senderId,
                  text: dto.content,
                  sentAt: dto.createdAt,
                  readAt: dto.isRead == true ? dto.createdAt : null,
                ),
              )
              .toList(growable: false)
            ..sort(
              (a, b) => (a.sentAt ?? DateTime(1970)).compareTo(
                b.sentAt ?? DateTime(1970),
              ),
            );

      _cachedMessages[matchId] = messages;
      _loadedHistories.add(matchId);
      _messageStreams[matchId]?.add(messages);
      _isOffline = false;
      _lastHistorySyncedAt = DateTime.now();

      if (messages.isNotEmpty) {
        final last = messages.last;
        _matches = _matches
            .map((m) {
              if (m.id != matchId) return m;
              return m.copyWith(
                lastMessage: last.text,
                lastMessageAt: last.sentAt ?? DateTime.now(),
                lastSenderId: last.senderId,
                isActive: true,
              );
            })
            .toList(growable: false);
        await _persistMatches();
      }
      notifyListeners();
    } catch (_) {
      _isOffline = true;
      final cached = _cachedMessages[matchId] ?? const <ChatMessageModel>[];
      if (cached.isNotEmpty) {
        _loadedHistories.add(matchId);
        _messageStreams[matchId]?.add(cached);
      }
      notifyListeners();
    }
  }

  String _pushLocalOutgoingMessage({
    required String matchId,
    required String senderId,
    required String text,
  }) {
    final now = DateTime.now();
    final localId = 'local_${now.microsecondsSinceEpoch}';
    final optimistic = ChatMessageModel(
      id: localId,
      senderId: senderId,
      text: text,
      sentAt: now,
      readAt: null,
      isPending: true,
      isFailed: false,
    );

    final existing = [
      ...(_cachedMessages[matchId] ?? const <ChatMessageModel>[]),
    ];
    existing.add(optimistic);
    existing.sort(
      (a, b) =>
          (a.sentAt ?? DateTime(1970)).compareTo(b.sentAt ?? DateTime(1970)),
    );

    _cachedMessages[matchId] = existing;
    _messageStreams[matchId]?.add(existing);
    _matches = _matches
        .map((m) {
          if (m.id != matchId) return m;
          return m.copyWith(
            lastMessage: text,
            lastMessageAt: now,
            lastSenderId: senderId,
            isActive: true,
          );
        })
        .toList(growable: false);
    notifyListeners();
    unawaited(_persistMatches());
    return localId;
  }

  void _markLocalMessageFailed({
    required String matchId,
    required String localId,
  }) {
    final existing = [
      ...(_cachedMessages[matchId] ?? const <ChatMessageModel>[]),
    ];
    final index = existing.indexWhere((m) => m.id == localId);
    if (index < 0) return;
    existing[index] = existing[index].copyWith(
      isPending: false,
      isFailed: true,
    );
    _cachedMessages[matchId] = existing;
    _messageStreams[matchId]?.add(existing);
    notifyListeners();
  }

  Future<void> sendMessage({
    required String matchId,
    required String text,
  }) async {
    final auth = _auth;
    final token = await _resolveToken();
    final me = auth?.backendUserId;
    final peerId = _matchPeerMap[matchId] ?? _derivePeerId(matchId);
    if (auth == null ||
        token == null ||
        me == null ||
        peerId == null ||
        text.trim().isEmpty) {
      return;
    }

    final content = text.trim();
    final localId = _pushLocalOutgoingMessage(
      matchId: matchId,
      senderId: me,
      text: content,
    );

    try {
      await _backendApi.sendMessage(
        token: token,
        receiverId: peerId,
        content: content,
      );
      _isOffline = false;
      await _refreshHistory(matchId);
    } catch (_) {
      _markLocalMessageFailed(matchId: matchId, localId: localId);
      if (_queuedMessages.every((item) => item.localId != localId)) {
        _queuedMessages.add(
          _QueuedMessage(matchId: matchId, text: content, localId: localId),
        );
      }
      _isOffline = true;
      _startRetryTimer();
      rethrow;
    }
  }

  Future<void> retryMessage({
    required String matchId,
    required ChatMessageModel message,
  }) async {
    final existing = [
      ...(_cachedMessages[matchId] ?? const <ChatMessageModel>[]),
    ];
    _cachedMessages[matchId] = existing
        .where((m) => m.id != message.id)
        .toList(growable: false);
    _messageStreams[matchId]?.add(_cachedMessages[matchId] ?? const []);
    notifyListeners();
    await sendMessage(matchId: matchId, text: message.text);
  }

  Future<void> markAsRead(String matchId) async {
    final me = _auth?.backendUserId;
    final token = _auth?.backendToken;
    final peerId = _matchPeerMap[matchId];
    if (me == null) return;
    _matches = _matches
        .map((m) {
          if (m.id != matchId) return m;
          final unread = Map<String, int>.from(m.unreadCounts);
          unread[me] = 0;
          return m.copyWith(unreadCounts: unread);
        })
        .toList(growable: false);
    await _persistMatches();
    notifyListeners();

    if (token != null && peerId != null) {
      try {
        await _backendApi.markChatRead(token: token, receiverId: peerId);
      } catch (_) {}
    }
  }

  Future<void> unmatch(String matchId) async {
    _matches = _matches
        .map((m) {
          if (m.id != matchId) return m;
          return m.copyWith(isActive: false);
        })
        .toList(growable: false);
    await _persistMatches();
    notifyListeners();
  }

  int unreadCountTotal() {
    final backendId = _auth?.backendUserId;
    if (backendId == null) return 0;
    return matches.fold<int>(0, (sum, item) => sum + item.unreadFor(backendId));
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _retryTimer?.cancel();
    _socket?.dispose();
    _pushSub?.cancel();
    for (final timer in _typingDebounceTimers.values) {
      timer.cancel();
    }
    for (final stream in _messageStreams.values) {
      stream.close();
    }
    super.dispose();
  }

  void _handleRealtimeMessage(Map<String, dynamic> payload) {
    final chatId = (payload['chatId'] ?? '').toString();
    final messageRaw = payload['message'];
    if (chatId.isEmpty || messageRaw is! Map) return;
    final me = _auth?.backendUserId;
    if (me == null) return;

    final messageMap = messageRaw.map((k, v) => MapEntry(k.toString(), v));
    final message = ChatMessageModel(
      id: (messageMap['id'] ?? '').toString(),
      senderId: (messageMap['senderId'] ?? '').toString(),
      text: (messageMap['content'] ?? '').toString(),
      sentAt: DateTime.tryParse((messageMap['createdAt'] ?? '').toString()),
      readAt: (messageMap['isRead'] == true)
          ? DateTime.tryParse((messageMap['createdAt'] ?? '').toString())
          : null,
      isPending: false,
      isFailed: false,
    );

    if (_matches.every((m) => m.id != chatId)) {
      // Recover gracefully when a realtime message arrives before local match sync.
      unawaited(_syncBackendMatches().then((_) => _refreshHistory(chatId)));
    }

    final existing = [
      ...(_cachedMessages[chatId] ?? const <ChatMessageModel>[]),
    ];
    final hasMessage = existing.any(
      (m) => m.id == message.id && m.id.isNotEmpty,
    );
    if (!hasMessage) {
      existing.add(message);
      existing.sort(
        (a, b) =>
            (a.sentAt ?? DateTime(1970)).compareTo(b.sentAt ?? DateTime(1970)),
      );
      _cachedMessages[chatId] = existing;
      _messageStreams[chatId]?.add(existing);
    }

    _matches = _matches
        .map((m) {
          if (m.id != chatId) return m;
          final unread = Map<String, int>.from(m.unreadCounts);
          final isIncoming =
              message.senderId.isNotEmpty && message.senderId != me;
          if (isIncoming) {
            unread[me] = (unread[me] ?? 0) + 1;
          }
          return m.copyWith(
            lastMessage: message.text,
            lastMessageAt: message.sentAt ?? DateTime.now(),
            lastSenderId: message.senderId,
            unreadCounts: unread,
            isActive: true,
          );
        })
        .toList(growable: false);

    unawaited(_persistMatches());
    _typingByMatchId[chatId] = false;
    _isOffline = false;
    _lastHistorySyncedAt = DateTime.now();
    notifyListeners();
  }

  void _handleRealtimeRead(Map<String, dynamic> payload) {
    final chatId = (payload['chatId'] ?? '').toString();
    if (chatId.isEmpty) return;
    final me = _auth?.backendUserId;
    if (me == null) return;

    final list = _cachedMessages[chatId];
    if (list == null || list.isEmpty) return;
    final readAt =
        DateTime.tryParse((payload['readAt'] ?? '').toString()) ??
        DateTime.now();

    final updated = list
        .map((m) {
          if (m.senderId != me || m.readAt != null) return m;
          return ChatMessageModel(
            id: m.id,
            senderId: m.senderId,
            text: m.text,
            sentAt: m.sentAt,
            readAt: readAt,
          );
        })
        .toList(growable: false);

    _cachedMessages[chatId] = updated;
    _messageStreams[chatId]?.add(updated);
    notifyListeners();
  }

  void sendTyping({required String matchId, required bool typing}) {
    final peerId = _matchPeerMap[matchId];
    if (peerId == null) return;
    _socket?.emit('chat.typing', {'peerId': peerId, 'typing': typing});

    _typingDebounceTimers[matchId]?.cancel();
    if (typing) {
      _typingDebounceTimers[matchId] = Timer(const Duration(seconds: 2), () {
        sendTyping(matchId: matchId, typing: false);
      });
    }
  }

  Future<void> _retryQueuedMessages() async {
    if (_queuedMessages.isEmpty) return;
    final auth = _auth;
    final token = await _resolveToken();
    if (auth == null || token == null || token.isEmpty) return;
    final pending = List<_QueuedMessage>.from(_queuedMessages);
    for (final item in pending) {
      final peerId = _matchPeerMap[item.matchId];
      if (peerId == null) continue;
      try {
        await _backendApi.sendMessage(
          token: token,
          receiverId: peerId,
          content: item.text,
        );
        _queuedMessages.removeWhere((m) => m.localId == item.localId);
        _isOffline = false;
        await _refreshHistory(item.matchId);
      } catch (_) {
        _isOffline = true;
      }
    }
    if (_queuedMessages.isEmpty) {
      _retryTimer?.cancel();
      _retryTimer = null;
    }
    notifyListeners();
  }

  void _handleRealtimeTyping(Map<String, dynamic> payload) {
    final chatId = (payload['chatId'] ?? '').toString();
    final senderId = (payload['senderId'] ?? '').toString();
    final typing = payload['typing'] == true;
    final me = _auth?.backendUserId;
    if (chatId.isEmpty || senderId.isEmpty || me == null || senderId == me) {
      return;
    }
    _typingByMatchId[chatId] = typing;
    notifyListeners();
  }

  String? syncLabel({bool history = false}) {
    final base = history ? _lastHistorySyncedAt : _lastSyncedAt;
    if (base == null) return null;
    final seconds = DateTime.now().difference(base).inSeconds;
    if (seconds < 1) return 'Last synced just now';
    return 'Last synced ${seconds}s ago';
  }

  Future<String?> _resolveToken() async {
    final auth = _auth;
    if (auth == null) return null;
    if (auth.backendToken != null && auth.backendToken!.isNotEmpty) {
      return auth.backendToken;
    }
    final ready = await auth.ensureBackendSession();
    if (!ready) return null;
    return auth.backendToken;
  }

  String? _derivePeerId(String matchId) {
    final me = _auth?.backendUserId;
    if (me == null) return null;
    MatchThread? thread;
    for (final m in _matches) {
      if (m.id == matchId) {
        thread = m;
        break;
      }
    }
    if (thread == null) return null;
    for (final id in thread.userIds) {
      if (id != me) return id;
    }
    return null;
  }

  void _startRetryTimer() {
    _retryTimer ??= Timer.periodic(const Duration(seconds: 8), (_) {
      unawaited(_retryQueuedMessages());
    });
  }
}

class _QueuedMessage {
  const _QueuedMessage({
    required this.matchId,
    required this.text,
    required this.localId,
  });

  final String matchId;
  final String text;
  final String localId;
}
