import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:lerolove/models/user_profile.dart';
import 'package:lerolove/providers/auth_provider.dart';

class ProfileProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  AuthProvider? _auth;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _profileSub;

  UserProfile? _currentProfile;
  UserProfile? get currentProfile => _currentProfile;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  bool _isLocalAuth(String? uid) => uid != null && uid.startsWith('local_');

  void bind(AuthProvider auth) {
    if (_auth?.uid == auth.uid) return;
    _auth = auth;
    _error = null;

    _profileSub?.cancel();
    _currentProfile = null;

    final uid = auth.uid;
    if (uid == null) {
      notifyListeners();
      return;
    }

    if (_isLocalAuth(uid)) {
      _currentProfile =
          _currentProfile?.copyWith(
            phoneNumber:
                auth.currentPhoneNumber ?? _currentProfile?.phoneNumber ?? '',
          ) ??
          UserProfile(
            id: uid,
            firstName: '',
            lastName: '',
            age: 0,
            gender: 'Other',
            phoneNumber: auth.currentPhoneNumber ?? '',
            bio: '',
            interests: const <String>[],
            photoUrls: const <String>[],
            isOnline: true,
            isVerified: false,
            lastSeen: DateTime.now(),
            preferences: const DiscoveryPreferences(),
          );
      notifyListeners();
      return;
    }

    _profileSub = _firestore.collection('users').doc(uid).snapshots().listen((
      doc,
    ) {
      if (!doc.exists) {
        _currentProfile = null;
      } else {
        _currentProfile = UserProfile.fromDoc(doc);
      }
      notifyListeners();
    });
  }

  Future<void> upsertBasics({
    required String firstName,
    required String lastName,
    required int age,
    required String gender,
    required String phoneNumber,
  }) async {
    final uid = _auth?.uid;
    if (uid == null) {
      _error = 'Not signed in.';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (_isLocalAuth(uid)) {
        _currentProfile = UserProfile(
          id: uid,
          firstName: firstName,
          lastName: lastName,
          age: age,
          gender: gender,
          phoneNumber: phoneNumber,
          bio: _currentProfile?.bio ?? '',
          interests: _currentProfile?.interests ?? const <String>[],
          photoUrls: _currentProfile?.photoUrls ?? const <String>[],
          isOnline: true,
          isVerified: _currentProfile?.isVerified ?? false,
          lastSeen: DateTime.now(),
          preferences:
              _currentProfile?.preferences ?? const DiscoveryPreferences(),
          role: _currentProfile?.role ?? 'user',
        );
        _isLoading = false;
        notifyListeners();
        return;
      }

      await _firestore.collection('users').doc(uid).set({
        'firstName': firstName,
        'lastName': lastName,
        'age': age,
        'gender': gender,
        'phoneNumber': phoneNumber,
        'bio': _currentProfile?.bio ?? '',
        'interests': _currentProfile?.interests ?? const <String>[],
        'photoUrls': _currentProfile?.photoUrls ?? const <String>[],
        'isOnline': true,
        'isVerified': _currentProfile?.isVerified ?? false,
        'lastSeen': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'role': _currentProfile?.role ?? 'user',
        'preferences':
            (_currentProfile?.preferences ?? const DiscoveryPreferences())
                .toMap(),
      }, SetOptions(merge: true));
    } catch (_) {
      _error = 'Could not save profile basics.';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> updateProfile({
    String? bio,
    List<String>? interests,
    List<String>? photoUrls,
    bool? isVerified,
  }) async {
    final uid = _auth?.uid;
    if (uid == null) return;

    if (_isLocalAuth(uid)) {
      _currentProfile =
          (_currentProfile ??
                  UserProfile(
                    id: uid,
                    firstName: '',
                    lastName: '',
                    age: 0,
                    gender: 'Other',
                    phoneNumber: _auth?.currentPhoneNumber ?? '',
                    bio: '',
                    interests: const <String>[],
                    photoUrls: const <String>[],
                    isOnline: true,
                    isVerified: false,
                    lastSeen: DateTime.now(),
                    preferences: const DiscoveryPreferences(),
                  ))
              .copyWith(
                bio: bio,
                interests: interests,
                photoUrls: photoUrls,
                isVerified: isVerified,
                lastSeen: DateTime.now(),
              );
      notifyListeners();
      return;
    }

    final payload = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (bio != null) payload['bio'] = bio;
    if (interests != null) payload['interests'] = interests;
    if (photoUrls != null) payload['photoUrls'] = photoUrls;
    if (isVerified != null) payload['isVerified'] = isVerified;

    await _firestore
        .collection('users')
        .doc(uid)
        .set(payload, SetOptions(merge: true));
  }

  Future<void> updateOnlineStatus(bool isOnline) async {
    final uid = _auth?.uid;
    if (uid == null) return;

    if (_isLocalAuth(uid)) {
      _currentProfile = _currentProfile?.copyWith(
        isOnline: isOnline,
        lastSeen: DateTime.now(),
      );
      notifyListeners();
      return;
    }

    await _firestore.collection('users').doc(uid).set({
      'isOnline': isOnline,
      'lastSeen': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  bool get hasCompletedProfile {
    final profile = _currentProfile;
    if (profile == null) return false;
    return profile.hasCompletedBasics;
  }

  @override
  void dispose() {
    _profileSub?.cancel();
    super.dispose();
  }
}
