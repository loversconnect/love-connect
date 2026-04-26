class DiscoveryPreferences {
  const DiscoveryPreferences({
    this.interestedIn = 'Everyone',
    this.minAge = 20,
    this.maxAge = 35,
    this.maxDistanceKm = 25,
    this.showOnlineOnly = false,
    this.verifiedProfilesOnly = false,
    this.sortMode = 'nearby',
    this.ghostMode = false,
  });

  final String interestedIn;
  final int minAge;
  final int maxAge;
  final double maxDistanceKm;
  final bool showOnlineOnly;
  final bool verifiedProfilesOnly;
  final String sortMode;
  final bool ghostMode;

  Map<String, dynamic> toMap() {
    return {
      'interestedIn': interestedIn,
      'minAge': minAge,
      'maxAge': maxAge,
      'maxDistanceKm': maxDistanceKm,
      'showOnlineOnly': showOnlineOnly,
      'verifiedProfilesOnly': verifiedProfilesOnly,
      'sortMode': sortMode,
      'ghostMode': ghostMode,
    };
  }

  factory DiscoveryPreferences.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const DiscoveryPreferences();
    return DiscoveryPreferences(
      interestedIn: (map['interestedIn'] as String?) ?? 'Everyone',
      minAge: (map['minAge'] as num?)?.toInt() ?? 20,
      maxAge: (map['maxAge'] as num?)?.toInt() ?? 35,
      maxDistanceKm: (map['maxDistanceKm'] as num?)?.toDouble() ?? 25,
      showOnlineOnly: (map['showOnlineOnly'] as bool?) ?? false,
      verifiedProfilesOnly: (map['verifiedProfilesOnly'] as bool?) ?? false,
      sortMode: (map['sortMode'] as String?) ?? 'nearby',
      ghostMode: (map['ghostMode'] as bool?) ?? false,
    );
  }
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.age,
    required this.gender,
    required this.phoneNumber,
    required this.bio,
    required this.interests,
    required this.photoUrls,
    required this.isOnline,
    required this.isVerified,
    required this.lastSeen,
    required this.preferences,
    this.latitude,
    this.longitude,
    this.role = 'user',
  });

  final String id;
  final String firstName;
  final String lastName;
  final int age;
  final String gender;
  final String phoneNumber;
  final String bio;
  final List<String> interests;
  final List<String> photoUrls;
  final bool isOnline;
  final bool isVerified;
  final DateTime? lastSeen;
  final double? latitude;
  final double? longitude;
  final String role;
  final DiscoveryPreferences preferences;

  String get name {
    final full = '$firstName $lastName'.trim();
    return full.isEmpty ? 'Unknown' : full;
  }

  bool get hasCompletedBasics => firstName.trim().isNotEmpty && age >= 18;
  bool get hasSelfiePhoto => photoUrls.isNotEmpty;
  bool get hasLocationSet => latitude != null && longitude != null;

  int get completenessPercentage {
    var score = 0;
    if (firstName.trim().isNotEmpty) score += 10;
    if (lastName.trim().isNotEmpty) score += 10;
    if (age >= 18) score += 10;
    if (gender.trim().isNotEmpty) score += 5;
    if (phoneNumber.trim().isNotEmpty) score += 5;
    if (bio.trim().isNotEmpty) score += 15;
    if (interests.isNotEmpty) score += 10;
    if (photoUrls.isNotEmpty) score += 25;
    if (hasLocationSet) score += 10;
    return score.clamp(0, 100);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'firstName': firstName,
      'lastName': lastName,
      'age': age,
      'gender': gender,
      'phoneNumber': phoneNumber,
      'bio': bio,
      'interests': interests,
      'photoUrls': photoUrls,
      'isOnline': isOnline,
      'isVerified': isVerified,
      'lastSeen': lastSeen?.toIso8601String(),
      'preferences': preferences.toMap(),
      'location': {'lat': latitude, 'lng': longitude},
      'role': role,
    };
  }

  UserProfile copyWith({
    String? firstName,
    String? lastName,
    int? age,
    String? gender,
    String? phoneNumber,
    String? bio,
    List<String>? interests,
    List<String>? photoUrls,
    bool? isOnline,
    bool? isVerified,
    DateTime? lastSeen,
    double? latitude,
    double? longitude,
    DiscoveryPreferences? preferences,
    String? role,
  }) {
    return UserProfile(
      id: id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      bio: bio ?? this.bio,
      interests: interests ?? this.interests,
      photoUrls: photoUrls ?? this.photoUrls,
      isOnline: isOnline ?? this.isOnline,
      isVerified: isVerified ?? this.isVerified,
      lastSeen: lastSeen ?? this.lastSeen,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      preferences: preferences ?? this.preferences,
      role: role ?? this.role,
    );
  }
}
