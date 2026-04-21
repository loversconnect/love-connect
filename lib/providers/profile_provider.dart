import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:lerolove/models/user_profile.dart';
import 'package:lerolove/providers/auth_provider.dart';
import 'package:lerolove/services/backend_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final BackendApi _backendApi = BackendApi();
  static const _localProfilePrefix = 'local_profile_';

  AuthProvider? _auth;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _profileSub;

  UserProfile? _currentProfile;
  UserProfile? get currentProfile => _currentProfile;

  bool _isLoading = false;
  bool get isLoading => _isLoading;
  bool _isProfileReady = true;
  bool get isProfileReady => _isProfileReady;

  String? _error;
  String? get error => _error;

  bool _isLocalAuth(String? uid) => uid != null && uid.startsWith('local_');
  String _localProfileKey(String uid) => '$_localProfilePrefix$uid';

  void bind(AuthProvider auth) {
    if (_auth?.uid == auth.uid) return;
    _auth = auth;
    _error = null;
    _isProfileReady = false;

    _profileSub?.cancel();
    _currentProfile = null;

    final uid = auth.uid;
    if (uid == null) {
      _isProfileReady = true;
      notifyListeners();
      return;
    }

    if (_isLocalAuth(uid)) {
      _currentProfile = _defaultLocalProfile(
        uid: uid,
        phone: auth.currentPhoneNumber ?? '',
      );
      notifyListeners();
      unawaited(
        _restoreLocalProfile(uid, auth.currentPhoneNumber ?? '').whenComplete(
          () {
            _isProfileReady = true;
            notifyListeners();
          },
        ),
      );
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
      _isProfileReady = true;
      notifyListeners();
    });
  }

  Future<void> upsertBasics({
    required String firstName,
    required String lastName,
    required int age,
    required String gender,
    required String phoneNumber,
    DateTime? birthDate,
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
        final normalizedGender = _normalizeGender(gender);
        _currentProfile = UserProfile(
          id: uid,
          firstName: firstName,
          lastName: lastName,
          age: age,
          gender: normalizedGender,
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
        await _persistLocalProfile(uid);
        await _syncLocalProfileToBackend(
          name: '$firstName $lastName'.trim(),
          gender: normalizedGender,
          birthDate: birthDate,
          photos: _currentProfile?.photoUrls ?? const <String>[],
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

    _isLoading = true;
    _error = null;
    notifyListeners();

    if (_isLocalAuth(uid)) {
      try {
        List<String>? finalPhotoUrls = photoUrls;
        if (photoUrls != null) {
          finalPhotoUrls = await _resolvePhotoUrlsForBackend(photoUrls);
        }

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
                  photoUrls: finalPhotoUrls,
                  isVerified: isVerified,
                  lastSeen: DateTime.now(),
                );
        await _persistLocalProfile(uid);
        final profile = _currentProfile;
        await _syncLocalProfileToBackend(
          name: profile?.name,
          gender: profile?.gender,
          photos: profile?.photoUrls,
        );
      } catch (e) {
        _error = 'Could not update profile: $e';
      } finally {
        _isLoading = false;
        notifyListeners();
      }
      return;
    }

    final payload = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (bio != null) payload['bio'] = bio;
    if (interests != null) payload['interests'] = interests;
    if (photoUrls != null) payload['photoUrls'] = photoUrls;
    if (isVerified != null) payload['isVerified'] = isVerified;

    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .set(payload, SetOptions(merge: true));
    } catch (e) {
      _error = 'Could not update profile: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateOnlineStatus(bool isOnline) async {
    final uid = _auth?.uid;
    if (uid == null) return;

    if (_isLocalAuth(uid)) {
      _currentProfile = _currentProfile?.copyWith(
        isOnline: isOnline,
        lastSeen: DateTime.now(),
      );
      await _persistLocalProfile(uid);
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

  Future<void> updateLocalLocation({
    required double latitude,
    required double longitude,
  }) async {
    final uid = _auth?.uid;
    if (uid == null || !_isLocalAuth(uid)) return;

    _currentProfile =
        (_currentProfile ??
                _defaultLocalProfile(
                  uid: uid,
                  phone: _auth?.currentPhoneNumber ?? '',
                ))
            .copyWith(
              latitude: latitude,
              longitude: longitude,
              lastSeen: DateTime.now(),
            );
    await _persistLocalProfile(uid);
    notifyListeners();
  }

  UserProfile _defaultLocalProfile({
    required String uid,
    required String phone,
  }) {
    return UserProfile(
      id: uid,
      firstName: '',
      lastName: '',
      age: 0,
      gender: 'Other',
      phoneNumber: phone,
      bio: '',
      interests: const <String>[],
      photoUrls: const <String>[],
      isOnline: true,
      isVerified: false,
      lastSeen: DateTime.now(),
      preferences: const DiscoveryPreferences(),
      role: 'user',
    );
  }

  Future<void> _persistLocalProfile(String uid) async {
    final profile = _currentProfile;
    if (profile == null) return;

    final prefs = await SharedPreferences.getInstance();
    final payload = <String, dynamic>{
      'id': profile.id,
      'firstName': profile.firstName,
      'lastName': profile.lastName,
      'age': profile.age,
      'gender': profile.gender,
      'phoneNumber': profile.phoneNumber,
      'bio': profile.bio,
      'interests': profile.interests,
      'photoUrls': profile.photoUrls,
      'isOnline': profile.isOnline,
      'isVerified': profile.isVerified,
      'lastSeen': profile.lastSeen?.toIso8601String(),
      'latitude': profile.latitude,
      'longitude': profile.longitude,
      'role': profile.role,
      'preferences': profile.preferences.toMap(),
    };
    await prefs.setString(_localProfileKey(uid), jsonEncode(payload));
  }

  Future<void> _restoreLocalProfile(String uid, String fallbackPhone) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_localProfileKey(uid));
    if (raw == null || raw.isEmpty) return;

    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      _currentProfile = UserProfile(
        id: (map['id'] as String?) ?? uid,
        firstName: (map['firstName'] as String?) ?? '',
        lastName: (map['lastName'] as String?) ?? '',
        age: (map['age'] as num?)?.toInt() ?? 0,
        gender: (map['gender'] as String?) ?? 'Other',
        phoneNumber: (map['phoneNumber'] as String?)?.isNotEmpty == true
            ? (map['phoneNumber'] as String)
            : fallbackPhone,
        bio: (map['bio'] as String?) ?? '',
        interests: ((map['interests'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(growable: false),
        photoUrls: ((map['photoUrls'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(growable: false),
        isOnline: (map['isOnline'] as bool?) ?? true,
        isVerified: (map['isVerified'] as bool?) ?? false,
        lastSeen: DateTime.tryParse((map['lastSeen'] as String?) ?? ''),
        latitude: (map['latitude'] as num?)?.toDouble(),
        longitude: (map['longitude'] as num?)?.toDouble(),
        role: (map['role'] as String?) ?? 'user',
        preferences: DiscoveryPreferences.fromMap(
          map['preferences'] as Map<String, dynamic>?,
        ),
      );
    } catch (_) {
      _currentProfile = _defaultLocalProfile(uid: uid, phone: fallbackPhone);
    }

    notifyListeners();
  }

  @override
  void dispose() {
    _profileSub?.cancel();
    super.dispose();
  }

  String _normalizeGender(String value) {
    final upper = value.trim().toUpperCase();
    if (upper == 'MALE' || upper == 'MEN') return 'MALE';
    if (upper == 'FEMALE' || upper == 'WOMEN') return 'FEMALE';
    if (upper == 'OTHER') return 'OTHER';
    return 'OTHER';
  }

  bool _isRemoteUrl(String value) {
    final lower = value.toLowerCase();
    return lower.startsWith('http://') || lower.startsWith('https://');
  }

  Future<List<String>> _resolvePhotoUrlsForBackend(
    List<String> photoPaths,
  ) async {
    final auth = _auth;
    if (auth == null) {
      throw Exception('Not authenticated');
    }
    final ready = await auth.ensureBackendSession();
    final token = auth.backendToken;
    if (!ready || token == null || token.isEmpty) {
      throw Exception('Backend session unavailable');
    }

    final uploadedUrls = <String>[];
    for (final rawPath in photoPaths) {
      final path = rawPath.trim();
      if (path.isEmpty) continue;
      if (_isRemoteUrl(path)) {
        uploadedUrls.add(path);
        continue;
      }
      final uploaded = await _backendApi.uploadProfilePhoto(
        token: token,
        filePath: path,
      );
      uploadedUrls.add(uploaded);
    }
    return uploadedUrls;
  }

  Future<void> _syncLocalProfileToBackend({
    String? name,
    String? gender,
    DateTime? birthDate,
    List<String>? photos,
  }) async {
    final auth = _auth;
    if (auth == null) return;
    final ready = await auth.ensureBackendSession();
    final token = auth.backendToken;
    if (!ready || token == null || token.isEmpty) return;

    await _backendApi.updateUserProfile(
      token: token,
      name: name,
      gender: gender == null ? null : _normalizeGender(gender),
      birthDateIso: birthDate?.toIso8601String(),
      photos: photos,
    );
  }
}
