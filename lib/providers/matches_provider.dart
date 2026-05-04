import 'dart:async';
import 'dart:collection';
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
  Timer? _recoveryTimer;
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
  final Set<String> _queuedLocalIds = <String>{};
  final Set<String> _retryInFlightLocalIds = <String>{};
  final ListQueue<String> _pendingMatchPromptIds = ListQueue<String>();
  final Set<String> _shownMatchPromptIds = <String>{};
  Timer? _retryTimer;
  bool _isRetryingQueuedMessages = false;
  bool _isRecoveryTickRunning = false;

  List<MatchThread> _matches = const [];
  List<MatchThread> get matches =>
      _matches.where((m) => m.isActive).toList(growable: false);

  bool _isLoading = false;
  bool get isLoading => _isLoading;
  bool _isOffline = false;
  DateTime? _lastSyncedAt;
  DateTime? _lastHistorySyncedAt;
  DateTime? _lastBackgroundHistoryRefreshAt;
  DateTime? _lastSocketReconnectAttemptAt;
  bool _socketConnected = false;

  bool get isOffline => _isOffline;
  bool get isSyncing =>
      _isLoading || _isRetryingQueuedMessages || _isRecoveryTickRunning;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  DateTime? get lastHistorySyncedAt => _lastHistorySyncedAt;
  int get queuedMessagesCount => _queuedMessages.length;
  bool isPeerTyping(String matchId) => _typingByMatchId[matchId] == true;
  MatchPrompt? get pendingMatchPrompt {
    while (_pendingMatchPromptIds.isNotEmpty) {
      final matchId = _pendingMatchPromptIds.first;
      final thread = matchById(matchId);
      final peerUserId = _matchPeerMap[matchId];
      if (thread != null &&
          thread.isActive &&
          peerUserId != null &&
          peerUserId.isNotEmpty) {
        return MatchPrompt(
          matchId: matchId,
          peerUserId: peerUserId,
          peerName: thread.peerName?.trim().isNotEmpty == true
              ? thread.peerName!
              : 'Match',
          peerPhotoUrl: thread.peerPhotoUrl,
        );
      }
      _pendingMatchPromptIds.removeFirst();
    }
    return null;
  }

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
  String _shownPromptsKey(String backendUserId) =>
      'shown_match_prompts_$backendUserId';
  String _pendingPromptsKey(String backendUserId) =>
      'pending_match_prompts_$backendUserId';

  void bind(AuthProvider auth) {
    final changed =
        _auth?.backendUserId != auth.backendUserId ||
        _auth?.isBackendAuthenticated != auth.isBackendAuthenticated;
    _auth = auth;
    if (!changed) return;

    _pollTimer?.cancel();
    _recoveryTimer?.cancel();
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
    _queuedLocalIds.clear();
    _retryInFlightLocalIds.clear();
    _pendingMatchPromptIds.clear();
    _shownMatchPromptIds.clear();
    _isRetryingQueuedMessages = false;
    _retryTimer?.cancel();
    _retryTimer = null;
    _lastBackgroundHistoryRefreshAt = null;
    _lastSocketReconnectAttemptAt = null;
    _socketConnected = false;
    _isRecoveryTickRunning = false;
    _matches = const [];

    if (!auth.isBackendAuthenticated || auth.backendUserId == null) {
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    _loadPersistedMatches().then((_) async {
      await _syncBackendMatches();
      await _refreshRecentHistories(limit: 3);
      _isLoading = false;
      notifyListeners();
      _startPolling();
      _startRecoveryLoop();
      _connectSocket();
      _bindPushEvents();
    });
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      unawaited(_syncBackendMatches());
      unawaited(_retryQueuedMessages());
    });
  }

  void _startRecoveryLoop() {
    _recoveryTimer?.cancel();
    _recoveryTimer = Timer.periodic(const Duration(seconds: 8), (_) async {
      if (_auth == null || !(_auth?.isBackendAuthenticated ?? false)) return;
      if (_isOffline || !_socketConnected) {
        if (_isRecoveryTickRunning) return;
        _isRecoveryTickRunning = true;
        notifyListeners();
        try {
          _ensureSocketConnected();
          await _syncBackendMatches();
          await _refreshLoadedHistoriesIfStale();
          await _retryQueuedMessages();
        } finally {
          _isRecoveryTickRunning = false;
          notifyListeners();
        }
      }
    });
  }

  Future<void> refreshNow() async {
    await _syncBackendMatches();
    await _refreshRecentHistories(limit: 5);
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
          .setReconnectionAttempts(1000000)
          .setReconnectionDelay(1500)
          .setReconnectionDelayMax(8000)
          .setTimeout(10000)
          .setAuth({'token': token})
          .disableAutoConnect()
          .build(),
    );

    socket.onConnect((_) {
      _socketConnected = true;
      _isOffline = false;
      _lastSyncedAt = DateTime.now();
      _lastSocketReconnectAttemptAt = null;
      for (final peerId in _matchPeerMap.values) {
        socket.emit('chat.join', {'peerId': peerId});
      }
      notifyListeners();
      unawaited(_syncBackendMatches());
      unawaited(_refreshLoadedHistories());
      unawaited(_retryQueuedMessages());
    });

    socket.onReconnect((_) {
      _socketConnected = true;
      _isOffline = false;
      _lastSyncedAt = DateTime.now();
      _lastSocketReconnectAttemptAt = null;
      notifyListeners();
      unawaited(_syncBackendMatches());
      unawaited(_refreshLoadedHistories());
      unawaited(_retryQueuedMessages());
    });

    socket.onDisconnect((_) {
      _socketConnected = false;
      _isOffline = true;
      notifyListeners();
    });

    socket.onConnectError((_) {
      _socketConnected = false;
      _isOffline = true;
      notifyListeners();
    });

    socket.onReconnectError((_) {
      _socketConnected = false;
      _isOffline = true;
      notifyListeners();
    });

    socket.onError((_) {
      _socketConnected = false;
      _isOffline = true;
      notifyListeners();
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

    socket.on('like.received', (raw) async {
      if (raw is! Map) return;
      final map = raw.map((k, v) => MapEntry(k.toString(), v));
      final chatId = (map['chatId'] ?? '').toString();
      final otherUserId = (map['otherUserId'] ?? '').toString();
      if (chatId.isEmpty || otherUserId.isEmpty) return;
      await registerThread(
        matchId: chatId,
        peerUserId: otherUserId,
        peerName: (map['otherName'] ?? 'Someone').toString(),
        isMatch: false,
        likedByMe: false,
        likedMe: true,
        conversationReady: true,
        queuePrompt: false,
      );
    });

    socket.on('chat.typing', (raw) {
      if (raw is! Map) return;
      final map = raw.map((k, v) => MapEntry(k.toString(), v));
      _handleRealtimeTyping(map);
    });

    socket.connect();
    _lastSocketReconnectAttemptAt = DateTime.now();
    _socket = socket;
  }

  void _ensureSocketConnected() {
    final token = _auth?.backendToken;
    if (token == null || token.isEmpty) return;

    final socket = _socket;
    if (socket == null) {
      _connectSocket();
      return;
    }

    if (socket.connected) return;

    final lastAttempt = _lastSocketReconnectAttemptAt;
    if (lastAttempt != null &&
        DateTime.now().difference(lastAttempt) <
            const Duration(seconds: 5)) {
      return;
    }

    _lastSocketReconnectAttemptAt = DateTime.now();

    try {
      final manager = socket.io;
      final options = manager.options ?? <String, dynamic>{};
      options['auth'] = {'token': token};
      manager.options = options;
      socket.connect();
    } catch (_) {
      _socket?.dispose();
      _socket = null;
      _connectSocket();
    }
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
          unawaited(_refreshRecentHistories(limit: 3));
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
      } else if (type == 'like.received') {
        final chatId = (event['chatId'] ?? '').toString();
        if (chatId.isNotEmpty) {
          unawaited(_syncBackendMatches().then((_) => _refreshHistory(chatId)));
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

    final shownRaw = prefs.getStringList(_shownPromptsKey(auth.backendUserId!));
    if (shownRaw != null) {
      _shownMatchPromptIds
        ..clear()
        ..addAll(shownRaw.where((id) => id.trim().isNotEmpty));
    }

    final pendingRaw = prefs.getStringList(
      _pendingPromptsKey(auth.backendUserId!),
    );
    if (pendingRaw != null) {
      _pendingMatchPromptIds
        ..clear()
        ..addAll(pendingRaw.where((id) => id.trim().isNotEmpty));
    }
  }

  Future<void> _syncBackendMatches() async {
    final auth = _auth;
    final token = await _resolveToken();
    final me = auth?.backendUserId;
    if (token == null || token.isEmpty || me == null) return;

    try {
      final backendMatches = await _backendApi.myMatches(token: token);

      final wasOffline = _isOffline;
      _isOffline = false;
      _lastSyncedAt = DateTime.now();
      if (backendMatches.isEmpty) {
        for (final match in _matches) {
          final peer = _otherUserId(match);
          if (peer != null && peer.isNotEmpty) {
            _matchPeerMap[match.id] = peer;
          }
        }
        if (wasOffline) {
          notifyListeners();
        }
        return;
      }

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
          isMatch: dto.isMatch,
          likedByMe: dto.likedByMe,
          likedMe: dto.likedMe,
          conversationReady: dto.conversationReady,
          peerName: dto.peerName,
          peerPhotoUrl: dto.peerPhotoUrl,
        );

        final index = copy.indexWhere((m) => m.id == dto.matchId);
        if (index >= 0) {
          final existing = copy[index];
          copy[index] = existing.copyWith(
            userIds: thread.userIds,
            isActive: true,
            isMatch: thread.isMatch,
            likedByMe: thread.likedByMe,
            likedMe: thread.likedMe,
            conversationReady: thread.conversationReady,
            peerName: thread.peerName,
            peerPhotoUrl: thread.peerPhotoUrl,
          );
        } else {
          copy.add(thread);
          if (dto.isMatch) {
            _queueMatchPrompt(matchId: dto.matchId);
          }
        }
        _matchPeerMap[dto.matchId] = dto.peerUserId;
        changed = true;
      }

      if (changed) {
        _matches = copy;
        await _persistMatches();
      }
      await _persistPromptState();
      notifyListeners();
    } catch (e) {
      final wasOffline = _isOffline;
      if (_isConnectivityError(e)) {
        _isOffline = true;
      }
      if (wasOffline != _isOffline) {
        notifyListeners();
      }
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

  Future<void> _persistPromptState() async {
    final auth = _auth;
    if (auth == null || auth.backendUserId == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _shownPromptsKey(auth.backendUserId!),
      _shownMatchPromptIds.toList(growable: false),
    );
    await prefs.setStringList(
      _pendingPromptsKey(auth.backendUserId!),
      _pendingMatchPromptIds.toList(growable: false),
    );
  }

  void _queueMatchPrompt({required String matchId}) {
    if (matchId.isEmpty ||
        _shownMatchPromptIds.contains(matchId) ||
        _pendingMatchPromptIds.contains(matchId)) {
      return;
    }
    _pendingMatchPromptIds.add(matchId);
  }

  Future<void> markMatchPromptShown(String matchId) async {
    if (matchId.isEmpty) return;
    _shownMatchPromptIds.add(matchId);
    _pendingMatchPromptIds.remove(matchId);
    await _persistPromptState();
    notifyListeners();
  }

  Future<void> dismissPendingMatchPrompt() async {
    final current = pendingMatchPrompt;
    if (current == null) return;
    await markMatchPromptShown(current.matchId);
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
    bool queuePrompt = true,
  }) async {
    await registerThread(
      matchId: matchId,
      peerUserId: peerUserId,
      peerName: peerName,
      peerPhotoUrl: peerPhotoUrl,
      queuePrompt: queuePrompt,
      isMatch: true,
      likedByMe: true,
      likedMe: true,
      conversationReady: true,
    );
  }

  Future<void> registerThread({
    required String matchId,
    required String peerUserId,
    required String peerName,
    String? peerPhotoUrl,
    bool queuePrompt = false,
    required bool isMatch,
    required bool likedByMe,
    required bool likedMe,
    bool conversationReady = true,
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
      isMatch: isMatch,
      likedByMe: likedByMe,
      likedMe: likedMe,
      conversationReady: conversationReady,
      peerName: peerName,
      peerPhotoUrl: peerPhotoUrl,
    );

    if (existingIndex >= 0) {
      final copy = [..._matches];
      final existing = copy[existingIndex];
      copy[existingIndex] = existing.copyWith(
        userIds: thread.userIds,
        isActive: true,
        isMatch: isMatch || existing.isMatch,
        likedByMe: likedByMe || existing.likedByMe,
        likedMe: likedMe || existing.likedMe,
        conversationReady: conversationReady || existing.conversationReady,
        peerName: peerName,
        peerPhotoUrl: peerPhotoUrl ?? existing.peerPhotoUrl,
      );
      _matches = copy;
    } else {
      _matches = [thread, ..._matches];
    }
    _matchPeerMap[matchId] = peerUserId;
    if (queuePrompt) {
      _queueMatchPrompt(matchId: matchId);
    }
    await _persistMatches();
    await _persistPromptState();
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
    _loadedHistories.add(matchId);
    unawaited(_refreshHistory(matchId));
    return controller.stream;
  }

  Future<void> _refreshRecentHistories({int limit = 3}) async {
    final targets = <String>{..._loadedHistories};
    final sortedMatches = [...matches]..sort((a, b) {
      final aTime = a.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });

    for (final thread in sortedMatches) {
      if (targets.length >= limit) break;
      targets.add(thread.id);
    }

    await _refreshSelectedHistories(targets);
  }

  Future<void> _refreshLoadedHistories() async {
    await _refreshSelectedHistories(_loadedHistories);
  }

  Future<void> _refreshLoadedHistoriesIfStale() async {
    final last = _lastBackgroundHistoryRefreshAt;
    if (last != null &&
        DateTime.now().difference(last) < const Duration(seconds: 45)) {
      return;
    }
    _lastBackgroundHistoryRefreshAt = DateTime.now();
    await _refreshLoadedHistories();
  }

  Future<void> _refreshSelectedHistories(Iterable<String> matchIds) async {
    final seen = <String>{};
    for (final matchId in matchIds) {
      if (matchId.isEmpty || !seen.add(matchId)) continue;
      await _refreshHistory(matchId);
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
    } catch (e) {
      if (e is ApiException && e.statusCode == 404) {
        _cachedMessages[matchId] = const <ChatMessageModel>[];
        _loadedHistories.add(matchId);
        _messageStreams[matchId]?.add(const <ChatMessageModel>[]);
        _isOffline = false;
        _lastHistorySyncedAt = DateTime.now();
        notifyListeners();
        return;
      }

      final wasOffline = _isOffline;
      if (_isConnectivityError(e)) {
        _isOffline = true;
      }
      final cached = _cachedMessages[matchId] ?? const <ChatMessageModel>[];
      if (cached.isNotEmpty) {
        _loadedHistories.add(matchId);
        _messageStreams[matchId]?.add(cached);
      }
      if (wasOffline != _isOffline || cached.isNotEmpty) {
        notifyListeners();
      }
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

  void _applyServerConfirmedMessage({
    required String matchId,
    required String localId,
    required ChatMessageDto dto,
  }) {
    final existing = [
      ...(_cachedMessages[matchId] ?? const <ChatMessageModel>[]),
    ];
    final confirmed = ChatMessageModel(
      id: dto.id.isEmpty ? localId : dto.id,
      senderId: dto.senderId,
      text: dto.content,
      sentAt: dto.createdAt ?? DateTime.now(),
      readAt: dto.isRead == true ? (dto.createdAt ?? DateTime.now()) : null,
      isPending: false,
      isFailed: false,
    );

    final localIndex = existing.indexWhere((m) => m.id == localId);
    final confirmedIndex = existing.indexWhere(
      (m) => m.id == confirmed.id && confirmed.id.isNotEmpty,
    );

    if (localIndex >= 0) {
      existing[localIndex] = confirmed;
    } else if (confirmedIndex >= 0) {
      existing[confirmedIndex] = confirmed;
    } else {
      existing.add(confirmed);
    }

    existing.sort(
      (a, b) => (a.sentAt ?? DateTime(1970)).compareTo(
        b.sentAt ?? DateTime(1970),
      ),
    );

    _cachedMessages[matchId] = existing;
    _loadedHistories.add(matchId);
    _messageStreams[matchId]?.add(existing);
    _matches = _matches
        .map((m) {
          if (m.id != matchId) return m;
          return m.copyWith(
            lastMessage: confirmed.text,
            lastMessageAt: confirmed.sentAt ?? DateTime.now(),
            lastSenderId: confirmed.senderId,
            isActive: true,
          );
        })
        .toList(growable: false);
    _isOffline = false;
    _lastHistorySyncedAt = DateTime.now();
    unawaited(_persistMatches());
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
      final sent = await _backendApi.sendMessage(
        token: token,
        receiverId: peerId,
        content: content,
      );
      _applyServerConfirmedMessage(
        matchId: matchId,
        localId: localId,
        dto: sent,
      );
    } catch (e) {
      if (_isBlockedOrPolicyError(e)) {
        _markLocalMessageFailed(matchId: matchId, localId: localId);
        _queuedMessages.removeWhere((item) => item.localId == localId);
        _queuedLocalIds.remove(localId);
        _retryInFlightLocalIds.remove(localId);
        _isOffline = false;
        rethrow;
      }
      _markLocalMessageFailed(matchId: matchId, localId: localId);
      if (!_queuedLocalIds.contains(localId)) {
        _queuedMessages.add(
          _QueuedMessage(matchId: matchId, text: content, localId: localId),
        );
        _queuedLocalIds.add(localId);
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
    _queuedMessages.removeWhere((m) => m.localId == message.id);
    _queuedLocalIds.remove(message.id);
    _retryInFlightLocalIds.remove(message.id);
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
    final token = await _resolveToken();
    final peerId = _matchPeerMap[matchId] ?? _derivePeerId(matchId);
    if (token == null || token.isEmpty || peerId == null || peerId.isEmpty) {
      throw ApiException('Unable to unmatch right now. Please try again.');
    }

    await _backendApi.unmatch(token: token, peerUserId: peerId);

    _matches = _matches
        .map((m) {
          if (m.id != matchId) return m;
          return m.copyWith(isActive: false);
        })
        .toList(growable: false);
    _cachedMessages.remove(matchId);
    _loadedHistories.remove(matchId);
    _typingByMatchId.remove(matchId);
    _messageStreams[matchId]?.add(const <ChatMessageModel>[]);
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
    _recoveryTimer?.cancel();
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
    if (_queuedMessages.isEmpty || _isRetryingQueuedMessages) return;
    _isRetryingQueuedMessages = true;
    notifyListeners();
    final auth = _auth;
    final token = await _resolveToken();
    if (auth == null || token == null || token.isEmpty) {
      _isRetryingQueuedMessages = false;
      notifyListeners();
      return;
    }
    final pending = List<_QueuedMessage>.from(_queuedMessages);
    try {
      for (final item in pending) {
        if (_retryInFlightLocalIds.contains(item.localId)) continue;
        final peerId = _matchPeerMap[item.matchId];
        if (peerId == null) continue;
        _retryInFlightLocalIds.add(item.localId);
        try {
          final sent = await _backendApi.sendMessage(
            token: token,
            receiverId: peerId,
            content: item.text,
          );
          _queuedMessages.removeWhere((m) => m.localId == item.localId);
          _queuedLocalIds.remove(item.localId);
          _applyServerConfirmedMessage(
            matchId: item.matchId,
            localId: item.localId,
            dto: sent,
          );
        } catch (e) {
          if (_isBlockedOrPolicyError(e)) {
            _queuedMessages.removeWhere((m) => m.localId == item.localId);
            _queuedLocalIds.remove(item.localId);
            _markLocalMessageFailed(
              matchId: item.matchId,
              localId: item.localId,
            );
            _isOffline = false;
            continue;
          }
          _isOffline = true;
        } finally {
          _retryInFlightLocalIds.remove(item.localId);
        }
      }
    } finally {
      _isRetryingQueuedMessages = false;
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

  bool _isConnectivityError(Object error) {
    if (error is ApiException) {
      final text = error.message.toLowerCase();
      return text.contains('timed out') ||
          text.contains('timeout') ||
          text.contains('socket') ||
          text.contains('network') ||
          text.contains('failed host lookup') ||
          text.contains('connection') ||
          error.statusCode == null;
    }
    final text = error.toString().toLowerCase();
    return text.contains('socket') ||
        text.contains('network') ||
        text.contains('timeout') ||
        text.contains('connection') ||
        text.contains('failed host lookup');
  }

  bool _isBlockedOrPolicyError(Object error) {
    if (error is! ApiException) return false;
    final text = error.message.toLowerCase();
    final status = error.statusCode;
    if (status != null && status >= 500) return false;
    return text.contains('block settings') ||
        text.contains('blocked') ||
        text.contains('only accepts messages from matched users') ||
        text.contains('accepts messages from matched users') ||
        text.contains('send a like before starting a chat') ||
        text.contains('cannot send message to this user');
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
