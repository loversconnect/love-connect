class MatchThread {
  const MatchThread({
    required this.id,
    required this.userIds,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.lastSenderId,
    required this.unreadCounts,
    required this.isActive,
    required this.isMatch,
    required this.likedByMe,
    required this.likedMe,
    required this.conversationReady,
    this.peerName,
    this.peerPhotoUrl,
  });

  final String id;
  final List<String> userIds;
  final String lastMessage;
  final DateTime? lastMessageAt;
  final String? lastSenderId;
  final Map<String, int> unreadCounts;
  final bool isActive;
  final bool isMatch;
  final bool likedByMe;
  final bool likedMe;
  final bool conversationReady;
  final String? peerName;
  final String? peerPhotoUrl;

  int unreadFor(String userId) => unreadCounts[userId] ?? 0;
  bool get isIntroThread => !isMatch;
  bool get isIncomingIntro => likedMe && !likedByMe;
  bool get isOutgoingIntro => likedByMe && !likedMe;

  factory MatchThread.fromJson(Map<String, dynamic> json) {
    return MatchThread(
      id: (json['id'] as String?) ?? '',
      userIds: ((json['userIds'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(growable: false),
      lastMessage: (json['lastMessage'] as String?) ?? '',
      lastMessageAt: DateTime.tryParse(
        (json['lastMessageAt'] as String?) ?? '',
      ),
      lastSenderId: json['lastSenderId'] as String?,
      unreadCounts:
          ((json['unreadCounts'] as Map?) ?? const <String, dynamic>{}).map(
            (key, value) => MapEntry(key.toString(), (value as num).toInt()),
          ),
      isActive: (json['isActive'] as bool?) ?? true,
      isMatch: (json['isMatch'] as bool?) ?? true,
      likedByMe: (json['likedByMe'] as bool?) ?? true,
      likedMe: (json['likedMe'] as bool?) ?? true,
      conversationReady: (json['conversationReady'] as bool?) ?? true,
      peerName: json['peerName'] as String?,
      peerPhotoUrl: json['peerPhotoUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userIds': userIds,
      'lastMessage': lastMessage,
      'lastMessageAt': lastMessageAt?.toIso8601String(),
      'lastSenderId': lastSenderId,
      'unreadCounts': unreadCounts,
      'isActive': isActive,
      'isMatch': isMatch,
      'likedByMe': likedByMe,
      'likedMe': likedMe,
      'conversationReady': conversationReady,
      'peerName': peerName,
      'peerPhotoUrl': peerPhotoUrl,
    };
  }

  MatchThread copyWith({
    String? id,
    List<String>? userIds,
    String? lastMessage,
    DateTime? lastMessageAt,
    String? lastSenderId,
    Map<String, int>? unreadCounts,
    bool? isActive,
    bool? isMatch,
    bool? likedByMe,
    bool? likedMe,
    bool? conversationReady,
    String? peerName,
    String? peerPhotoUrl,
  }) {
    return MatchThread(
      id: id ?? this.id,
      userIds: userIds ?? this.userIds,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      lastSenderId: lastSenderId ?? this.lastSenderId,
      unreadCounts: unreadCounts ?? this.unreadCounts,
      isActive: isActive ?? this.isActive,
      isMatch: isMatch ?? this.isMatch,
      likedByMe: likedByMe ?? this.likedByMe,
      likedMe: likedMe ?? this.likedMe,
      conversationReady: conversationReady ?? this.conversationReady,
      peerName: peerName ?? this.peerName,
      peerPhotoUrl: peerPhotoUrl ?? this.peerPhotoUrl,
    );
  }
}

class MatchPrompt {
  const MatchPrompt({
    required this.matchId,
    required this.peerUserId,
    required this.peerName,
    this.peerPhotoUrl,
  });

  final String matchId;
  final String peerUserId;
  final String peerName;
  final String? peerPhotoUrl;
}

class ChatMessageModel {
  const ChatMessageModel({
    required this.id,
    required this.senderId,
    required this.text,
    required this.sentAt,
    required this.readAt,
    this.isPending = false,
    this.isFailed = false,
  });

  final String id;
  final String senderId;
  final String text;
  final DateTime? sentAt;
  final DateTime? readAt;
  final bool isPending;
  final bool isFailed;

  bool get isRead => readAt != null;
  bool get isDelivered => !isPending && !isFailed;

  ChatMessageModel copyWith({
    String? id,
    String? senderId,
    String? text,
    DateTime? sentAt,
    DateTime? readAt,
    bool? isPending,
    bool? isFailed,
  }) {
    return ChatMessageModel(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      text: text ?? this.text,
      sentAt: sentAt ?? this.sentAt,
      readAt: readAt ?? this.readAt,
      isPending: isPending ?? this.isPending,
      isFailed: isFailed ?? this.isFailed,
    );
  }
}

class BlockedUser {
  const BlockedUser({
    required this.userId,
    required this.name,
    required this.blockedAt,
  });

  final String userId;
  final String name;
  final DateTime? blockedAt;
}
