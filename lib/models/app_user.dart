import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  const AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.emailVerified,
    required this.createdAt,
    required this.updatedAt,
    this.lastLoginAt,
    this.photoUrl,
    this.onboardingCompleted = false,
    this.preferences = const <String, dynamic>{},
  });

  final String uid;
  final String email;
  final String displayName;
  final bool emailVerified;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastLoginAt;
  final String? photoUrl;
  final bool onboardingCompleted;
  final Map<String, dynamic> preferences;

  factory AppUser.fromFirestore(Map<String, dynamic> data) {
    final uid = (data['uid'] as String? ?? '').trim();
    if (uid.isEmpty) {
      throw const FormatException('User document is missing a valid uid field.');
    }

    final email = (data['email'] as String? ?? '').trim().toLowerCase();
    final displayName = (data['displayName'] as String? ?? '').trim();

    return AppUser(
      uid: uid,
      email: email,
      displayName: displayName,
      emailVerified: data['emailVerified'] as bool? ?? false,
      createdAt: _readDateTime(data['createdAt']),
      updatedAt: _readDateTime(data['updatedAt']),
      lastLoginAt: _readNullableDateTime(data['lastLoginAt']),
      photoUrl: (data['photoUrl'] as String?)?.trim(),
      onboardingCompleted: data['onboardingCompleted'] as bool? ?? false,
      preferences: _readPreferences(data['preferences']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return <String, dynamic>{
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'emailVerified': emailVerified,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'lastLoginAt': lastLoginAt,
      'photoUrl': photoUrl,
      'onboardingCompleted': onboardingCompleted,
      'preferences': preferences,
    };
  }

  static DateTime _readDateTime(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  static DateTime? _readNullableDateTime(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    return null;
  }

  static Map<String, dynamic> _readPreferences(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map(
        (key, dynamic mapValue) => MapEntry(key.toString(), mapValue),
      );
    }
    return const <String, dynamic>{};
  }
}
