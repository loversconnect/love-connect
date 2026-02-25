import 'package:flutter/material.dart';

enum DiscoverSortMode { nearby, bestMatch }

class DatingProfile {
  DatingProfile({
    required this.id,
    required this.name,
    required this.age,
    required this.distanceKm,
    required this.bio,
    required this.interests,
    required this.gender,
    this.isOnline = false,
    this.isVerified = false,
  });

  final String id;
  final String name;
  final int age;
  final int distanceKm;
  final String bio;
  final List<String> interests;
  final String gender;
  final bool isOnline;
  final bool isVerified;
}

class AppState extends ChangeNotifier {
  String interestedIn = 'Everyone';
  RangeValues ageRange = const RangeValues(20, 35);
  double maxDistanceKm = 25;
  bool showOnlineOnly = false;
  bool verifiedProfilesOnly = false;
  DiscoverSortMode discoverSortMode = DiscoverSortMode.nearby;

  String? firstName;
  String? lastName;
  String? phoneNumber;

  final List<String> myInterests = ['Music', 'Travel', 'Fitness', 'Cooking'];

  final List<DatingProfile> _allProfiles = [
    DatingProfile(
      id: 'p1',
      name: 'Thandiwe',
      age: 24,
      distanceKm: 3,
      bio: 'Love music and dancing.',
      interests: ['Music', 'Dancing', 'Travel'],
      gender: 'Female',
      isOnline: true,
      isVerified: true,
    ),
    DatingProfile(
      id: 'p2',
      name: 'Chisomo',
      age: 26,
      distanceKm: 5,
      bio: 'Coffee lover and bookworm.',
      interests: ['Coffee', 'Reading', 'Art'],
      gender: 'Female',
      isOnline: false,
      isVerified: true,
    ),
    DatingProfile(
      id: 'p3',
      name: 'Mphatso',
      age: 23,
      distanceKm: 7,
      bio: 'Adventure seeker and fitness enthusiast.',
      interests: ['Travel', 'Hiking', 'Fitness'],
      gender: 'Female',
      isOnline: true,
      isVerified: false,
    ),
    DatingProfile(
      id: 'p4',
      name: 'Kondwani',
      age: 28,
      distanceKm: 2,
      bio: 'Gym lover and weekend cook.',
      interests: ['Gym', 'Cooking', 'Sports'],
      gender: 'Male',
      isOnline: false,
      isVerified: true,
    ),
    DatingProfile(
      id: 'p5',
      name: 'Pemphero',
      age: 25,
      distanceKm: 10,
      bio: 'Artist and dreamer.',
      interests: ['Art', 'Photography', 'Music'],
      gender: 'Female',
      isOnline: true,
      isVerified: false,
    ),
    DatingProfile(
      id: 'p6',
      name: 'Yamikani',
      age: 30,
      distanceKm: 14,
      bio: 'Love road trips and deep conversations.',
      interests: ['Travel', 'Cooking', 'Movies'],
      gender: 'Male',
      isOnline: true,
      isVerified: true,
    ),
  ];

  final Set<String> _dismissedProfileIds = <String>{};
  final Set<String> _likedProfileIds = <String>{};

  List<DatingProfile> get discoverProfiles {
    final filtered = _allProfiles.where(_passesDiscoveryFilters).toList();
    if (discoverSortMode == DiscoverSortMode.nearby) {
      filtered.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    } else {
      filtered.sort((a, b) => compatibilityScore(b).compareTo(compatibilityScore(a)));
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

  void updateDiscoverySettings({
    required String interestedInValue,
    required RangeValues ageRangeValue,
    required double maxDistanceKmValue,
    required bool showOnlineOnlyValue,
    required bool verifiedProfilesOnlyValue,
    required DiscoverSortMode discoverSortModeValue,
  }) {
    interestedIn = interestedInValue;
    ageRange = ageRangeValue;
    maxDistanceKm = maxDistanceKmValue;
    showOnlineOnly = showOnlineOnlyValue;
    verifiedProfilesOnly = verifiedProfilesOnlyValue;
    discoverSortMode = discoverSortModeValue;
    notifyListeners();
  }

  void setDiscoverSortMode(DiscoverSortMode mode) {
    discoverSortMode = mode;
    notifyListeners();
  }

  void likeProfile(String profileId) {
    _likedProfileIds.add(profileId);
    _dismissedProfileIds.add(profileId);
    notifyListeners();
  }

  void passProfile(String profileId) {
    _dismissedProfileIds.add(profileId);
    notifyListeners();
  }

  void resetDiscoverQueue() {
    _dismissedProfileIds.clear();
    notifyListeners();
  }

  void setUserName({
    required String firstNameValue,
    required String lastNameValue,
  }) {
    firstName = firstNameValue;
    lastName = lastNameValue;
    notifyListeners();
  }

  void setPhoneNumber(String value) {
    phoneNumber = value;
    notifyListeners();
  }

  String get displayName {
    final full = '${firstName ?? ''} ${lastName ?? ''}'.trim();
    return full.isEmpty ? 'Your Name' : full;
  }

  String get displayPhone {
    final value = phoneNumber?.trim() ?? '';
    return value.isEmpty ? 'Your Phone' : value;
  }

  int compatibilityScore(DatingProfile profile) {
    final sharedCount = profile.interests
        .where((interest) => myInterests.contains(interest))
        .length;
    final interestScore = (sharedCount * 25).clamp(0, 60);

    final distanceBase = maxDistanceKm <= 0 ? 1 : maxDistanceKm;
    final distanceFactor =
        ((distanceBase - profile.distanceKm) / distanceBase).clamp(0.0, 1.0);
    final distanceScore = (distanceFactor * 30).round();

    final midpoint = (ageRange.start + ageRange.end) / 2;
    final ageDelta = (profile.age - midpoint).abs();
    final ageScore = (10 - ageDelta).clamp(0, 10).round();

    return (interestScore + distanceScore + ageScore).clamp(0, 100);
  }

  bool _passesDiscoveryFilters(DatingProfile profile) {
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
    DatingProfile profile, {
    required String interestedInValue,
    required RangeValues ageRangeValue,
    required double maxDistanceKmValue,
    required bool showOnlineOnlyValue,
    required bool verifiedProfilesOnlyValue,
    required bool includeDismissedProfiles,
  }) {
    if (!includeDismissedProfiles && _dismissedProfileIds.contains(profile.id)) {
      return false;
    }
    if (profile.distanceKm > maxDistanceKmValue.round()) {
      return false;
    }
    if (profile.age < ageRangeValue.start.round() || profile.age > ageRangeValue.end.round()) {
      return false;
    }
    if (interestedInValue != 'Everyone' && profile.gender != interestedInValue) {
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
}
