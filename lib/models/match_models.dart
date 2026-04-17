import 'package:cloud_firestore/cloud_firestore.dart';

class MatchThread {
  const MatchThread({
    required this.id,
    required this.userIds,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.lastSenderId,
    required this.unreadCounts,
    required this.isActive,
    this.peerName,
  });

  final String id;
  final List<String> userIds;
  final String lastMessage;
  final DateTime? lastMessageAt;
  final String? lastSenderId;
  final Map<String, int> unreadCounts;
  final bool isActive;
  final String? peerName;

  int unreadFor(String userId) => unreadCounts[userId] ?? 0;

  factory MatchThread.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final unreadRaw =
        (data['unreadCounts'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};

    return MatchThread(
      id: doc.id,
      userIds: ((data['userIds'] as List<dynamic>?) ?? const [])
          .map((e) => e.toString())
          .toList(growable: false),
      lastMessage: (data['lastMessage'] as String?) ?? '',
      lastMessageAt: (data['lastMessageAt'] as Timestamp?)?.toDate(),
      lastSenderId: data['lastSenderId'] as String?,
      unreadCounts: unreadRaw.map(
        (key, value) => MapEntry(key, (value as num).toInt()),
      ),
      isActive: (data['isActive'] as bool?) ?? true,
      peerName: data['peerName'] as String?,
    );
  }

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
      peerName: json['peerName'] as String?,
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
      'peerName': peerName,
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
    String? peerName,
  }) {
    return MatchThread(
      id: id ?? this.id,
      userIds: userIds ?? this.userIds,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      lastSenderId: lastSenderId ?? this.lastSenderId,
      unreadCounts: unreadCounts ?? this.unreadCounts,
      isActive: isActive ?? this.isActive,
      peerName: peerName ?? this.peerName,
    );
  }
}

class ChatMessageModel {
  const ChatMessageModel({
    required this.id,
    required this.senderId,
    required this.text,
    required this.sentAt,
    required this.readAt,
  });

  final String id;
  final String senderId;
  final String text;
  final DateTime? sentAt;
  final DateTime? readAt;

  bool get isRead => readAt != null;

  factory ChatMessageModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return ChatMessageModel(
      id: doc.id,
      senderId: (data['senderId'] as String?) ?? '',
      text: (data['text'] as String?) ?? '',
      sentAt: (data['sentAt'] as Timestamp?)?.toDate(),
      readAt: (data['readAt'] as Timestamp?)?.toDate(),
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

  factory BlockedUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return BlockedUser(
      userId: doc.id,
      name: (data['name'] as String?) ?? 'Unknown',
      blockedAt: (data['blockedAt'] as Timestamp?)?.toDate(),
    );
  }
}
