import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:lerolove/models/user_profile.dart';
import 'package:lerolove/providers/auth_provider.dart';
import 'package:lerolove/services/backend_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileProvider extends ChangeNotifier {
  final BackendApi _backendApi = BackendApi();
  static const _localProfilePrefix = 'local_profile_';

  AuthProvider? _auth;

  UserProfile? _currentProfile;
  UserProfile? get currentProfile => _currentProfile;

  bool _isLoading = false;
  bool get isLoading => _isLoading;
  bool _isProfileReady = true;
  bool get isProfileReady => _isProfileReady;

  String? _error;
  String? get error => _error;
  bool _isOffline = false;
  bool get isOffline => _isOffline;
  Timer? _profileSyncRetryTimer;
  _PendingProfileSync? _pendingProfileSync;

  String _localProfileKey(String uid) => '$_localProfilePrefix$uid';

  void bind(AuthProvider auth) {
    if (_auth?.uid == auth.uid) return;
    _auth = auth;
    _error = null;
    _isProfileReady = false;
    _currentProfile = null;

    final uid = auth.uid;
    if (uid == null) {
      _isProfileReady = true;
      notifyListeners();
      return;
    }

    _currentProfile = _defaultLocalProfile(
      uid: uid,
      phone: auth.currentPhoneNumber ?? '',
    );
    notifyListeners();
    unawaited(
      _restoreLocalProfile(
        uid,
        auth.currentPhoneNumber ?? '',
      ).then((_) => syncFromBackendIfAvailable()).whenComplete(() {
        _isProfileReady = true;
        notifyListeners();
      }),
    );
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
  }

  Future<void> updateDiscoveryPreferences(
    DiscoveryPreferences preferences,
  ) async {
    final uid = _auth?.uid;
    if (uid == null) return;

    _currentProfile =
        (_currentProfile ??
                _defaultLocalProfile(
                  uid: uid,
                  phone: _auth?.currentPhoneNumber ?? '',
                ))
            .copyWith(preferences: preferences, lastSeen: DateTime.now());

    await _persistLocalProfile(uid);
    final profile = _currentProfile;
    await _syncLocalProfileToBackend(
      name: profile?.name,
      gender: profile?.gender,
      photos: profile?.photoUrls,
    );
    notifyListeners();
  }

  Future<void> updateOnlineStatus(bool isOnline) async {
    final uid = _auth?.uid;
    if (uid == null) return;

    _currentProfile = _currentProfile?.copyWith(
      isOnline: isOnline,
      lastSeen: DateTime.now(),
    );
    await _persistLocalProfile(uid);
    notifyListeners();
  }

  bool get hasCompletedProfile {
    final profile = _currentProfile;
    if (profile == null) return false;
    return profile.hasCompletedBasics &&
        profile.hasSelfiePhoto &&
        profile.hasLocationSet;
  }

  Future<void> updateLocalLocation({
    required double latitude,
    required double longitude,
  }) async {
    final uid = _auth?.uid;
    if (uid == null) return;

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

  Future<void> syncFromBackendIfAvailable() async {
    final uid = _auth?.uid;
    if (uid == null) return;

    final token = await _tryGetBackendToken();
    if (token == null) return;

    try {
      final dto = await _backendApi.me(token: token);
      if (dto.id.isEmpty) return;
      final parts = _splitName(dto.name);
      _currentProfile =
          (_currentProfile ??
                  _defaultLocalProfile(
                    uid: uid,
                    phone: _auth?.currentPhoneNumber ?? '',
                  ))
              .copyWith(
                firstName: parts.$1,
                lastName: parts.$2,
                age: _ageFromBirthDate(dto.birthDate),
                gender: dto.gender,
                phoneNumber: (dto.phone?.trim().isNotEmpty ?? false)
                    ? dto.phone
                    : (_auth?.currentPhoneNumber ?? ''),
                bio: dto.bio ?? _currentProfile?.bio ?? '',
                photoUrls: dto.photos,
                latitude: dto.lat,
                longitude: dto.lng,
                createdAt: dto.createdAt,
                trialEndDate: dto.trialEndDate,
                subscriptionActive: dto.subscriptionActive,
                subscriptionStatus: dto.subscriptionStatus,
                subscriptionEndDate: dto.subscriptionEndDate,
                lastSeen: DateTime.now(),
              );
      await _persistLocalProfile(uid);
      _error = null;
      notifyListeners();
    } catch (_) {
      // keep local profile fallback if backend fetch fails
    }
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
      'createdAt': profile.createdAt?.toIso8601String(),
      'trialEndDate': profile.trialEndDate?.toIso8601String(),
      'subscriptionActive': profile.subscriptionActive,
      'subscriptionStatus': profile.subscriptionStatus,
      'subscriptionEndDate': profile.subscriptionEndDate?.toIso8601String(),
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
        createdAt: DateTime.tryParse((map['createdAt'] as String?) ?? ''),
        trialEndDate: DateTime.tryParse((map['trialEndDate'] as String?) ?? ''),
        subscriptionActive: (map['subscriptionActive'] as bool?) ?? false,
        subscriptionStatus: map['subscriptionStatus'] as String?,
        subscriptionEndDate: DateTime.tryParse(
          (map['subscriptionEndDate'] as String?) ?? '',
        ),
        preferences: DiscoveryPreferences.fromMap(
          map['preferences'] as Map<String, dynamic>?,
        ),
      );
    } catch (_) {
      _currentProfile = _defaultLocalProfile(uid: uid, phone: fallbackPhone);
    }

    notifyListeners();
  }

  (String, String) _splitName(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return ('', '');
    final first = parts.first;
    final last = parts.length > 1 ? parts.sublist(1).join(' ') : '';
    return (first, last);
  }

  int _ageFromBirthDate(DateTime? birthDate) {
    if (birthDate == null) return 0;
    final now = DateTime.now();
    var age = now.year - birthDate.year;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return age < 0 ? 0 : age;
  }

  @override
  void dispose() {
    _profileSyncRetryTimer?.cancel();
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
    final token = await _requireBackendToken();

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
    final token = await _tryGetBackendToken();
    if (token == null) {
      _queueProfileSync(
        name: name,
        gender: gender,
        birthDate: birthDate,
        photos: photos,
      );
      return;
    }

    try {
      await _backendApi.updateUserProfile(
        token: token,
        name: name,
        gender: gender == null ? null : _normalizeGender(gender),
        birthDateIso: birthDate?.toIso8601String(),
        photos: photos,
      );
      _isOffline = false;
      _pendingProfileSync = null;
    } catch (_) {
      _queueProfileSync(
        name: name,
        gender: gender,
        birthDate: birthDate,
        photos: photos,
      );
    }
  }

  void _queueProfileSync({
    String? name,
    String? gender,
    DateTime? birthDate,
    List<String>? photos,
  }) {
    _isOffline = true;
    _pendingProfileSync = _PendingProfileSync(
      name: name,
      gender: gender,
      birthDate: birthDate,
      photos: photos,
    );
    _error = 'You are offline. Profile changes were saved and will sync soon.';
    notifyListeners();
    _profileSyncRetryTimer ??= Timer.periodic(const Duration(seconds: 12), (_) {
      unawaited(_flushPendingProfileSync());
    });
  }

  Future<void> _flushPendingProfileSync() async {
    final queued = _pendingProfileSync;
    if (queued == null) return;
    final token = await _tryGetBackendToken();
    if (token == null) return;
    try {
      await _backendApi.updateUserProfile(
        token: token,
        name: queued.name,
        gender: queued.gender == null ? null : _normalizeGender(queued.gender!),
        birthDateIso: queued.birthDate?.toIso8601String(),
        photos: queued.photos,
      );
      _pendingProfileSync = null;
      _isOffline = false;
      _error = null;
      notifyListeners();
    } catch (_) {
      _isOffline = true;
    }
  }

  Future<String?> _tryGetBackendToken() async {
    final auth = _auth;
    if (auth == null) return null;

    for (var attempt = 0; attempt < 3; attempt++) {
      final ready = await auth.ensureBackendSession();
      final token = auth.backendToken;
      if (ready && token != null && token.isNotEmpty) {
        return token;
      }
      await Future<void>.delayed(Duration(milliseconds: 300 * (attempt + 1)));
    }
    return null;
  }

  Future<String> _requireBackendToken() async {
    final token = await _tryGetBackendToken();
    if (token != null) return token;
    throw Exception('Backend session unavailable');
  }
}

class _PendingProfileSync {
  const _PendingProfileSync({
    this.name,
    this.gender,
    this.birthDate,
    this.photos,
  });

  final String? name;
  final String? gender;
  final DateTime? birthDate;
  final List<String>? photos;
}
