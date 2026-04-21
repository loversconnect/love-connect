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

  List<UserProfile> _allProfiles = const [];
  bool _isLoading = false;
  String? _error;

  bool get isLoading => _isLoading;
  String? get error => _error;

  void bind(AuthProvider auth, ProfileProvider profileProvider) {
    final authChanged = _auth?.uid != auth.uid;
    _auth = auth;
    _profileProvider = profileProvider;

    if (!authChanged) return;

    _dismissedProfileIds.clear();
    _likedProfileIds.clear();
    _blockedProfileIds.clear();
    _backendDistanceKmByUserId.clear();
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
      final ready = await auth.ensureBackendSession();
      if (!ready || auth.backendToken == null) {
        throw Exception('Backend session unavailable');
      }

      final me = _profileProvider?.currentProfile;
      double? lat = me?.latitude;
      double? lng = me?.longitude;
      if (lat == null || lng == null) {
        final current = await _resolveCurrentLocation();
        if (current != null) {
          lat = current.latitude;
          lng = current.longitude;
          await _profileProvider?.updateLocalLocation(
            latitude: lat,
            longitude: lng,
          );
        }
      }
      if (lat != null && lng != null) {
        await _backendApi.updateLocation(
          token: auth.backendToken!,
          lat: lat,
          lng: lng,
        );
      }

      final backendUsers = await _backendApi.discovery(
        token: auth.backendToken!,
        radiusKm: maxDistanceKm,
      );

      _backendDistanceKmByUserId
        ..clear()
        ..addEntries(
          backendUsers
              .where((dto) => dto.id.isNotEmpty)
              .map((dto) => MapEntry(dto.id, dto.distanceKm)),
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
              isOnline: false,
              isVerified: false,
              lastSeen: null,
              latitude: null,
              longitude: null,
              role: 'user',
              preferences: const DiscoveryPreferences(),
            );
          })
          .toList(growable: false);
    } catch (_) {
      _error = 'Could not load nearby profiles.';
    }

    _isLoading = false;
    notifyListeners();
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
    interestedIn = interestedInValue;
    ageRange = ageRangeValue;
    maxDistanceKm = maxDistanceKmValue;
    showOnlineOnly = showOnlineOnlyValue;
    verifiedProfilesOnly = verifiedProfilesOnlyValue;
    discoverSortMode = discoverSortModeValue;
    notifyListeners();
    await loadProfiles();
  }

  Future<String?> likeProfile(UserProfile profile) async {
    final auth = _auth;
    if (auth == null) return null;
    final token = auth.backendToken;
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
      if (!result.isMatch) return null;
      return result.matchId;
    } catch (_) {
      return null;
    }
  }

  void passProfile(String profileId) {
    _dismissedProfileIds.add(profileId);
    notifyListeners();
    unawaited(_sendPassSwipe(profileId));
  }

  Future<void> _sendPassSwipe(String profileId) async {
    final auth = _auth;
    if (auth == null) return;
    final token = auth.backendToken;
    if (token == null || token.isEmpty) return;

    try {
      await _backendApi.swipe(token: token, swipedId: profileId, action: false);
    } catch (_) {
      // Keep UX smooth if a pass call fails; profile remains dismissed locally.
    }
  }

  void resetDiscoverQueue() {
    _dismissedProfileIds.clear();
    notifyListeners();
  }

  int compatibilityScore(UserProfile profile) {
    final myInterests =
        _profileProvider?.currentProfile?.interests ?? const <String>[];

    final sharedCount = profile.interests
        .where((interest) => myInterests.contains(interest))
        .length;
    final interestScore = (sharedCount * 25).clamp(0, 60);

    final distance = distanceTo(profile, _profileProvider?.currentProfile);
    final distanceBase = maxDistanceKm <= 0 ? 1 : maxDistanceKm;
    final distanceFactor = ((distanceBase - distance) / distanceBase).clamp(
      0.0,
      1.0,
    );
    final distanceScore = (distanceFactor * 30).round();

    final midpoint = (ageRange.start + ageRange.end) / 2;
    final ageDelta = (profile.age - midpoint).abs();
    final ageScore = (10 - ageDelta).clamp(0, 10).round();

    return (interestScore + distanceScore + ageScore).clamp(0, 100);
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
    if (showOnlineOnlyValue && !profile.isOnline) {
      return false;
    }
    if (verifiedProfilesOnlyValue && !profile.isVerified) {
      return false;
    }

    return true;
  }

  double distanceTo(UserProfile other, UserProfile? me) {
    final backendDistance = _backendDistanceKmByUserId[other.id];
    if (backendDistance != null) {
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
}
