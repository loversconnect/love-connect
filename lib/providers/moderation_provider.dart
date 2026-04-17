import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:lerolove/models/match_models.dart';
import 'package:lerolove/providers/auth_provider.dart';

class ModerationProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  AuthProvider? _auth;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _blockedSub;

  List<BlockedUser> _blockedUsers = const [];
  List<BlockedUser> get blockedUsers => _blockedUsers;

  void bind(AuthProvider auth) {
    final changed = _auth?.uid != auth.uid;
    _auth = auth;
    if (!changed) return;

    _blockedSub?.cancel();
    _blockedUsers = const [];

    final uid = auth.uid;
    if (uid == null) {
      notifyListeners();
      return;
    }

    _blockedSub = _firestore
        .collection('users')
        .doc(uid)
        .collection('blocks')
        .orderBy('blockedAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      _blockedUsers = snapshot.docs.map(BlockedUser.fromDoc).toList(growable: false);
      notifyListeners();
    });
  }

  Future<void> blockUser({
    required String userId,
    required String name,
  }) async {
    final uid = _auth?.uid;
    if (uid == null) return;

    await _firestore.collection('users').doc(uid).collection('blocks').doc(userId).set({
      'name': name,
      'blockedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> unblockUser(String userId) async {
    final uid = _auth?.uid;
    if (uid == null) return;

    await _firestore.collection('users').doc(uid).collection('blocks').doc(userId).delete();
  }

  Future<void> reportUser({
    required String reportedUserId,
    required String reason,
    String? details,
    String? matchId,
  }) async {
    final uid = _auth?.uid;
    if (uid == null) return;

    await _firestore.collection('reports').add({
      'reporterUserId': uid,
      'reportedUserId': reportedUserId,
      'reason': reason,
      'details': details ?? '',
      'matchId': matchId,
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  void dispose() {
    _blockedSub?.cancel();
    super.dispose();
  }
}
