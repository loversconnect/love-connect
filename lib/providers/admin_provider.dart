import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:lerolove/providers/profile_provider.dart';

class AdminProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  ProfileProvider? _profileProvider;

  void bind(ProfileProvider profileProvider) {
    _profileProvider = profileProvider;
    notifyListeners();
  }

  bool get isAdmin => _profileProvider?.currentProfile?.role == 'admin';

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> loadOpenReports({
    int limit = 50,
  }) async {
    if (!isAdmin) return const [];

    final snapshot = await _firestore
        .collection('reports')
        .where('status', isEqualTo: 'open')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs;
  }

  Future<void> setReportStatus({
    required String reportId,
    required String status,
  }) async {
    if (!isAdmin) return;

    await _firestore.collection('reports').doc(reportId).set({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
