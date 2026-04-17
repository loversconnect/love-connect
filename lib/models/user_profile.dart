import 'package:cloud_firestore/cloud_firestore.dart';

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

  Map<String, dynamic> toMap() {
    return {
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
      'lastSeen': lastSeen == null ? null : Timestamp.fromDate(lastSeen!),
      'preferences': preferences.toMap(),
      'location': {
        'lat': latitude,
        'lng': longitude,
      },
      'role': role,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory UserProfile.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final location = (data['location'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};

    return UserProfile(
      id: doc.id,
      firstName: (data['firstName'] as String?) ?? '',
      lastName: (data['lastName'] as String?) ?? '',
      age: (data['age'] as num?)?.toInt() ?? 0,
      gender: (data['gender'] as String?) ?? 'Other',
      phoneNumber: (data['phoneNumber'] as String?) ?? '',
      bio: (data['bio'] as String?) ?? '',
      interests: ((data['interests'] as List<dynamic>?) ?? const [])
          .map((e) => e.toString())
          .toList(growable: false),
      photoUrls: ((data['photoUrls'] as List<dynamic>?) ?? const [])
          .map((e) => e.toString())
          .toList(growable: false),
      isOnline: (data['isOnline'] as bool?) ?? false,
      isVerified: (data['isVerified'] as bool?) ?? false,
      lastSeen: (data['lastSeen'] as Timestamp?)?.toDate(),
      latitude: (location['lat'] as num?)?.toDouble(),
      longitude: (location['lng'] as num?)?.toDouble(),
      preferences:
          DiscoveryPreferences.fromMap(data['preferences'] as Map<String, dynamic>?),
      role: (data['role'] as String?) ?? 'user',
    );
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
