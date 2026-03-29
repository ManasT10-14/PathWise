import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { user, expert, admin }

class AppUser {
  const AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.resume,
    required this.skills,
    required this.interests,
    required this.careerGoals,
    required this.role,
    required this.createdAt,
    required this.lastLoginDate,
  });

  final String uid;
  final String name;
  final String email;
  final String resume;
  final List<String> skills;
  final List<String> interests;
  final String careerGoals;
  final UserRole role;
  final DateTime? createdAt;
  final DateTime? lastLoginDate;

  static UserRole _parseRole(dynamic value) {
    final s = value?.toString().toLowerCase() ?? 'user';
    return UserRole.values.firstWhere(
      (e) => e.name == s,
      orElse: () => UserRole.user,
    );
  }

  static List<String> _stringList(dynamic v) {
    if (v == null) return [];
    if (v is List) return v.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList();
    if (v is String && v.isNotEmpty) return [v];
    return [];
  }

  static String _str(dynamic v, [String fallback = '']) {
    if (v == null) return fallback;
    if (v is List && v.isNotEmpty) return v.map((e) => e?.toString()).join(', ');
    return v.toString();
  }

  factory AppUser.fromFirestore(String uid, Map<String, dynamic> data) {
    String pick(String camel, List<String> legacy) {
      if (data[camel] != null) return _str(data[camel]);
      for (final k in legacy) {
        if (data[k] != null) return _str(data[k]);
      }
      return '';
    }

    final skills = <String>{};
    skills.addAll(_stringList(data['skills']));
    skills.addAll(_stringList(data['Skills']));

    final interests = <String>{};
    interests.addAll(_stringList(data['interests']));
    interests.addAll(_stringList(data['Interests']));

    DateTime? ts(dynamic v) {
      if (v is Timestamp) return v.toDate();
      return null;
    }

    return AppUser(
      uid: uid,
      name: pick('name', ['Name']),
      email: pick('email', ['Email']),
      resume: pick('resume', ['Resume']),
      skills: skills.toList(),
      interests: interests.toList(),
      careerGoals: pick('careerGoals', ['CareerGoals']),
      role: _parseRole(data['role'] ?? data['Role']),
      createdAt: ts(data['createdAt'] ?? data['CreatedAt']),
      lastLoginDate: ts(data['lastLoginDate'] ?? data['LastLoginDate']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'resume': resume,
      'skills': skills,
      'interests': interests,
      'careerGoals': careerGoals,
      'role': role.name,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'lastLoginDate': FieldValue.serverTimestamp(),
    };
  }

  AppUser copyWith({
    String? name,
    String? email,
    String? resume,
    List<String>? skills,
    List<String>? interests,
    String? careerGoals,
    UserRole? role,
  }) {
    return AppUser(
      uid: uid,
      name: name ?? this.name,
      email: email ?? this.email,
      resume: resume ?? this.resume,
      skills: skills ?? this.skills,
      interests: interests ?? this.interests,
      careerGoals: careerGoals ?? this.careerGoals,
      role: role ?? this.role,
      createdAt: createdAt,
      lastLoginDate: lastLoginDate,
    );
  }
}
