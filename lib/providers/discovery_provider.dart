import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lerolove/models/user_profile.dart';
import 'package:lerolove/providers/auth_provider.dart';
import 'package:lerolove/providers/profile_provider.dart';
import 'package:lerolove/services/backend_api.dart';

enum DiscoverSortMode { nearby, bestMatch }

class DiscoveryProvider extends ChangeNotifier {
  final BackendApi _backendApi = BackendApi();

  AuthProvider? _auth;
  ProfileProvider? _profileProvider;

  String interestedIn = 'Everyone';
  RangeValues ageRange = const RangeValues(20, 35);
  double maxDistanceKm = 25;
  bool showOnlineOnly = false;
  bool verifiedProfilesOnly = false;
  DiscoverSortMode discoverSortMode = DiscoverSortMode.nearby;

  final Set<String> _dismissedProfileIds = <String>{};
  final Set<String> _likedProfileIds = <String>{};
  final Set<String> _blockedProfileIds = <String>{};
  final Map<String, double> _backendDistanceKmByUserId = <String, double>{};
  final Map<String, bool> _onlineKnownByUserId = <String, bool>{};
  final Map<String, bool> _verifiedKnownByUserId = <String, bool>{};

  List<UserProfile> _allProfiles = const [];
  bool _isLoading = false;
  String? _error;
  DateTime? _lastSyncedAt;
  bool _isOffline = false;
  final Set<String> _queuedLikeIds = <String>{};
  Timer? _retryTimer;

  bool get isLoading => _isLoading;
  String? get error => _error;
  int get backendCandidateCount => _allProfiles.length;
  bool get hasBackendCandidates => _allProfiles.isNotEmpty;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  bool get isOffline => _isOffline;
  int get queuedActionsCount => _queuedLikeIds.length;

  String? syncLabel() {
    if (_lastSyncedAt == null) return null;
    final seconds = DateTime.now().difference(_lastSyncedAt!).inSeconds;
    if (seconds < 1) return 'Last synced just now';
    return 'Last synced ${seconds}s ago';
  }

  void bind(AuthProvider auth, ProfileProvider profileProvider) {
    final authChanged = _auth?.uid != auth.uid;
    _auth = auth;
    _profileProvider = profileProvider;

    if (!authChanged) return;

    _dismissedProfileIds.clear();
    _likedProfileIds.clear();
    _blockedProfileIds.clear();
    _backendDistanceKmByUserId.clear();
    _onlineKnownByUserId.clear();
    _verifiedKnownByUserId.clear();
    _queuedLikeIds.clear();
    _allProfiles = const [];

    if (auth.uid != null) {
      _loadFromProfile();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(loadProfiles());
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  void _loadFromProfile() {
    final prefs = _profileProvider?.currentProfile?.preferences;
    if (prefs == null) return;

    interestedIn = _normalizeInterestedIn(prefs.interestedIn);
    ageRange = RangeValues(prefs.minAge.toDouble(), prefs.maxAge.toDouble());
    maxDistanceKm = prefs.maxDistanceKm;
    showOnlineOnly = prefs.showOnlineOnly;
    verifiedProfilesOnly = prefs.verifiedProfilesOnly;
    discoverSortMode = prefs.sortMode == 'bestMatch'
        ? DiscoverSortMode.bestMatch
        : DiscoverSortMode.nearby;
  }

  List<UserProfile> get discoverProfiles {
    final filtered = _allProfiles
        .where(_passesDiscoveryFilters)
        .toList(growable: false);
    final myProfile = _profileProvider?.currentProfile;

    if (discoverSortMode == DiscoverSortMode.nearby) {
      filtered.sort(
        (a, b) => distanceTo(a, myProfile).compareTo(distanceTo(b, myProfile)),
      );
    } else {
      filtered.sort(
        (a, b) => compatibilityScore(b).compareTo(compatibilityScore(a)),
      );
    }

    return filtered;
  }

  int get estimatedMatches => discoverProfiles.length;

  int estimateMatchesFor({
    required String interestedInValue,
    required RangeValues ageRangeValue,
    required double maxDistanceKmValue,
    required bool showOnlineOnlyValue,
    required bool verifiedProfilesOnlyValue,
  }) {
    return _allProfiles
        .where(
          (profile) => _passesDiscoveryFiltersWithParams(
            profile,
            interestedInValue: interestedInValue,
            ageRangeValue: ageRangeValue,
            maxDistanceKmValue: maxDistanceKmValue,
            showOnlineOnlyValue: showOnlineOnlyValue,
            verifiedProfilesOnlyValue: verifiedProfilesOnlyValue,
            includeDismissedProfiles: true,
          ),
        )
        .length;
  }

  Future<void> loadProfiles() async {
    final auth = _auth;
    if (auth == null || auth.uid == null) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final token = await _resolveBackendToken();
      if (token == null) {
        throw Exception('Backend session unavailable');
      }

      final current = await _resolveCurrentLocation();
      if (current == null) {
        throw Exception('Location permission is required for discovery');
      }
      final lat = current.latitude;
      final lng = current.longitude;

      await _profileProvider?.updateLocalLocation(
        latitude: lat,
        longitude: lng,
      );
      await _backendApi.updateLocation(token: token, lat: lat, lng: lng);

      final backendUsers = await _backendApi.discovery(
        token: token,
        radiusKm: maxDistanceKm,
      );

      _backendDistanceKmByUserId
        ..clear()
        ..addEntries(
          backendUsers
              .where((dto) => dto.id.isNotEmpty)
              .map((dto) => MapEntry(dto.id, dto.distanceKm)),
        );

      _onlineKnownByUserId
        ..clear()
        ..addEntries(
          backendUsers
              .where((dto) => dto.id.isNotEmpty && dto.isOnline != null)
              .map((dto) => MapEntry(dto.id, dto.isOnline!)),
        );

      _verifiedKnownByUserId
        ..clear()
        ..addEntries(
          backendUsers
              .where((dto) => dto.id.isNotEmpty && dto.isVerified != null)
              .map((dto) => MapEntry(dto.id, dto.isVerified!)),
        );

      _allProfiles = backendUsers
          .map((dto) {
            final parts = dto.name.trim().split(RegExp(r'\s+'));
            final firstName = parts.isNotEmpty ? parts.first : dto.name;
            final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';
            final age = _calculateAge(dto.birthDate);

            return UserProfile(
              id: dto.id,
              firstName: firstName,
              lastName: lastName,
              age: age,
              gender: dto.gender,
              phoneNumber: '',
              bio: '',
              interests: const <String>[],
              photoUrls: dto.photos,
              isOnline: dto.isOnline ?? false,
              isVerified: dto.isVerified ?? false,
              lastSeen: null,
              latitude: null,
              longitude: null,
              role: 'user',
              preferences: const DiscoveryPreferences(),
            );
          })
          .toList(growable: false);
      _isOffline = false;
      _lastSyncedAt = DateTime.now();
      await _flushQueuedLikes(token);
    } catch (e) {
      _backendDistanceKmByUserId.clear();
      _onlineKnownByUserId.clear();
      _verifiedKnownByUserId.clear();
      _allProfiles = const [];
      if (_isLikelyOfflineError(e)) {
        _isOffline = true;
      }
      _error = e.toString().contains('Location permission')
          ? 'Enable location permission to discover nearby people.'
          : 'Could not load nearby profiles.';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<String?> _resolveBackendToken() async {
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

  int _calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    var age = now.year - birthDate.year;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  Future<void> updateDiscoverySettings({
    required String interestedInValue,
    required RangeValues ageRangeValue,
    required double maxDistanceKmValue,
    required bool showOnlineOnlyValue,
    required bool verifiedProfilesOnlyValue,
    required DiscoverSortMode discoverSortModeValue,
  }) async {
    _error = null;
    interestedIn = interestedInValue;
    ageRange = ageRangeValue;
    maxDistanceKm = maxDistanceKmValue;
    showOnlineOnly = showOnlineOnlyValue;
    verifiedProfilesOnly = verifiedProfilesOnlyValue;
    discoverSortMode = discoverSortModeValue;
    _dismissedProfileIds.clear();

    await _profileProvider?.updateDiscoveryPreferences(
      DiscoveryPreferences(
        interestedIn: interestedInValue,
        minAge: ageRangeValue.start.round(),
        maxAge: ageRangeValue.end.round(),
        maxDistanceKm: maxDistanceKmValue,
        showOnlineOnly: showOnlineOnlyValue,
        verifiedProfilesOnly: verifiedProfilesOnlyValue,
        sortMode: discoverSortModeValue == DiscoverSortMode.bestMatch
            ? 'bestMatch'
            : 'nearby',
      ),
    );
    notifyListeners();
    await loadProfiles();
  }

  Future<SwipeResultDto?> likeProfile(UserProfile profile) async {
    final token = await _resolveBackendToken();
    if (token == null) return null;

    _likedProfileIds.add(profile.id);
    _dismissedProfileIds.add(profile.id);
    notifyListeners();

    try {
      final result = await _backendApi.swipe(
        token: token,
        swipedId: profile.id,
        action: true,
      );
      _error = null;
      _isOffline = false;
      _lastSyncedAt = DateTime.now();
      _queuedLikeIds.remove(profile.id);
      return result;
    } on ApiException catch (e) {
      _dismissedProfileIds.remove(profile.id);
      _likedProfileIds.remove(profile.id);
      if (_isLikelyOfflineError(e)) {
        _queuedLikeIds.add(profile.id);
        _startRetryQueue();
        _isOffline = true;
        _error = 'No internet right now. Like queued and will retry.';
      } else {
        _error = e.message;
      }
      notifyListeners();
      return null;
    } catch (e) {
      _dismissedProfileIds.remove(profile.id);
      _likedProfileIds.remove(profile.id);
      if (_isLikelyOfflineError(e)) {
        _queuedLikeIds.add(profile.id);
        _startRetryQueue();
        _isOffline = true;
        _error = 'No internet right now. Like queued and will retry.';
      } else {
        _error = 'Could not send like: $e';
      }
      notifyListeners();
      return null;
    }
  }

  void passProfile(String profileId) {
    _dismissedProfileIds.add(profileId);
    notifyListeners();
    unawaited(_sendPassSwipe(profileId));
  }

  Future<void> _sendPassSwipe(String profileId) async {
    final token = await _resolveBackendToken();
    if (token == null || token.isEmpty) return;

    try {
      await _backendApi.swipe(token: token, swipedId: profileId, action: false);
      _error = null;
      _isOffline = false;
      _lastSyncedAt = DateTime.now();
    } on ApiException catch (e) {
      if (_isLikelyOfflineError(e)) {
        _isOffline = true;
        _error = 'You are offline. We will sync when back online.';
      } else {
        _error = e.message;
      }
      notifyListeners();
    } catch (_) {
      // Keep UX smooth if a pass call fails; profile remains dismissed locally.
    }
  }

  void resetDiscoverQueue() {
    _dismissedProfileIds.clear();
    notifyListeners();
  }

  Future<void> refreshProfiles() async {
    _dismissedProfileIds.clear();
    _backendDistanceKmByUserId.clear();
    _onlineKnownByUserId.clear();
    _verifiedKnownByUserId.clear();
    _allProfiles = const [];
    notifyListeners();
    await loadProfiles();
  }

  void _startRetryQueue() {
    _retryTimer ??= Timer.periodic(const Duration(seconds: 12), (_) {
      final auth = _auth;
      if (auth?.backendToken == null || _queuedLikeIds.isEmpty) return;
      unawaited(_retryQueuedLikes());
    });
  }

  Future<void> _retryQueuedLikes() async {
    final token = await _resolveBackendToken();
    if (token == null) return;
    await _flushQueuedLikes(token);
    notifyListeners();
  }

  Future<void> _flushQueuedLikes(String token) async {
    if (_queuedLikeIds.isEmpty) return;
    final pending = _queuedLikeIds.toList(growable: false);
    var updated = false;
    for (final userId in pending) {
      try {
        await _backendApi.swipe(token: token, swipedId: userId, action: true);
        _queuedLikeIds.remove(userId);
        updated = true;
      } catch (_) {}
    }
    if (updated && _queuedLikeIds.isEmpty) {
      _error = null;
      _isOffline = false;
      _lastSyncedAt = DateTime.now();
    }
  }

  bool _isLikelyOfflineError(Object error) {
    final text = error.toString().toLowerCase();
    return text.contains('timed out') ||
        text.contains('socket') ||
        text.contains('network') ||
        text.contains('failed host lookup') ||
        text.contains('connection');
  }

  Future<void> resetFiltersToBroadDefaults() async {
    await updateDiscoverySettings(
      interestedInValue: 'Everyone',
      ageRangeValue: const RangeValues(18, 60),
      maxDistanceKmValue: 100,
      showOnlineOnlyValue: false,
      verifiedProfilesOnlyValue: false,
      discoverSortModeValue: DiscoverSortMode.nearby,
    );
  }

  int compatibilityScore(UserProfile profile) {
    final myInterests =
        _profileProvider?.currentProfile?.interests ?? const <String>[];
    final sharedCount = profile.interests
        .where((interest) => myInterests.contains(interest))
        .length;
    final interestScore = sharedCount <= 0
        ? 0
        : (sharedCount * 12).clamp(0, 36);

    final distance = distanceTo(profile, _profileProvider?.currentProfile);
    final distanceBase = maxDistanceKm <= 0 ? 1 : maxDistanceKm;
    final distanceFactor = ((distanceBase - distance) / distanceBase).clamp(
      0.0,
      1.0,
    );
    final distanceScore = (distanceFactor * 34).round();

    final minAge = ageRange.start.round();
    final maxAge = ageRange.end.round();
    final ageScore = profile.age >= minAge && profile.age <= maxAge
        ? 24
        : (12 - (profile.age - ((minAge + maxAge) / 2)).abs())
              .clamp(0, 12)
              .round();

    final interestPreference =
        interestedIn == 'Everyone' ||
        _normalizeGender(profile.gender) == _normalizeGender(interestedIn);
    final preferenceScore = interestPreference ? 22 : 0;

    final profileQualityScore =
        (profile.photoUrls.isNotEmpty ? 4 : 0) +
        (profile.bio.trim().isNotEmpty ? 6 : 0) +
        (profile.isVerified ? 4 : 0) +
        (profile.isOnline ? 2 : 0);

    final raw =
        interestScore +
        distanceScore +
        ageScore +
        preferenceScore +
        profileQualityScore;
    return raw.clamp(5, 100);
  }

  int sharedInterestCount(UserProfile profile) {
    final myInterests =
        _profileProvider?.currentProfile?.interests ?? const <String>[];
    if (myInterests.isEmpty || profile.interests.isEmpty) return 0;
    return profile.interests
        .where((interest) => myInterests.contains(interest))
        .length;
  }

  bool _passesDiscoveryFilters(UserProfile profile) {
    return _passesDiscoveryFiltersWithParams(
      profile,
      interestedInValue: interestedIn,
      ageRangeValue: ageRange,
      maxDistanceKmValue: maxDistanceKm,
      showOnlineOnlyValue: showOnlineOnly,
      verifiedProfilesOnlyValue: verifiedProfilesOnly,
      includeDismissedProfiles: false,
    );
  }

  bool _passesDiscoveryFiltersWithParams(
    UserProfile profile, {
    required String interestedInValue,
    required RangeValues ageRangeValue,
    required double maxDistanceKmValue,
    required bool showOnlineOnlyValue,
    required bool verifiedProfilesOnlyValue,
    required bool includeDismissedProfiles,
  }) {
    if (!includeDismissedProfiles &&
        _dismissedProfileIds.contains(profile.id)) {
      return false;
    }

    final myProfile = _profileProvider?.currentProfile;
    final distance = _distanceForFilter(profile, myProfile);
    if (distance > maxDistanceKmValue) {
      return false;
    }
    if (profile.age < ageRangeValue.start.round() ||
        profile.age > ageRangeValue.end.round()) {
      return false;
    }
    if (interestedInValue != 'Everyone' &&
        _normalizeGender(profile.gender) !=
            _normalizeGender(interestedInValue)) {
      return false;
    }
    final onlineKnown = _onlineKnownByUserId.containsKey(profile.id);
    if (showOnlineOnlyValue && onlineKnown && !profile.isOnline) return false;

    final verifiedKnown = _verifiedKnownByUserId.containsKey(profile.id);
    if (verifiedProfilesOnlyValue && verifiedKnown && !profile.isVerified) {
      return false;
    }

    return true;
  }

  double distanceTo(UserProfile other, UserProfile? me) {
    final backendDistance = _backendDistanceKmByUserId[other.id];
    if (backendDistance != null) {
      if (backendDistance < 0) {
        return maxDistanceKm * 0.6;
      }
      return backendDistance;
    }

    if (me?.latitude == null ||
        me?.longitude == null ||
        other.latitude == null ||
        other.longitude == null) {
      return maxDistanceKm + 1;
    }

    const radiusKm = 6371.0;
    final dLat = _degToRad(other.latitude! - me!.latitude!);
    final dLon = _degToRad(other.longitude! - me.longitude!);

    final lat1 = _degToRad(me.latitude!);
    final lat2 = _degToRad(other.latitude!);

    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return radiusKm * c;
  }

  double _distanceForFilter(UserProfile other, UserProfile? me) {
    final distance = distanceTo(other, me);
    if (distance.isFinite) return distance;
    return maxDistanceKm + 1;
  }

  double distanceFromCurrent(UserProfile other) {
    return distanceTo(other, _profileProvider?.currentProfile);
  }

  bool isDistanceHidden(UserProfile other) {
    final backendDistance = _backendDistanceKmByUserId[other.id];
    return backendDistance != null && backendDistance < 0;
  }

  double _degToRad(double degree) => degree * (math.pi / 180.0);

  String _normalizeInterestedIn(String value) {
    final upper = value.trim().toUpperCase();
    switch (upper) {
      case 'MALE':
      case 'MEN':
        return 'MALE';
      case 'FEMALE':
      case 'WOMEN':
        return 'FEMALE';
      case 'EVERYONE':
      case 'ALL':
      default:
        return 'Everyone';
    }
  }

  String _normalizeGender(String value) {
    final upper = value.trim().toUpperCase();
    if (upper == 'MALE' || upper == 'MEN') return 'MALE';
    if (upper == 'FEMALE' || upper == 'WOMEN') return 'FEMALE';
    if (upper == 'EVERYONE' || upper == 'ALL') return 'Everyone';
    return upper;
  }

  Future<Position?> _resolveCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      return Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  static String buildMatchId(String a, String b) {
    final ids = [a, b]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }
}
