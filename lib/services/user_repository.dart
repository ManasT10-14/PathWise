import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/app_user.dart';

class UserRepository {
  UserRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _users => _db.collection('users');

  DocumentReference<Map<String, dynamic>> doc(String uid) => _users.doc(uid);

  Stream<AppUser?> watchUser(String uid) {
    return doc(uid).snapshots().map((s) {
      if (!s.exists || s.data() == null) return null;
      return AppUser.fromFirestore(uid, s.data()!);
    });
  }

  Future<AppUser?> fetchUser(String uid) async {
    final s = await doc(uid).get();
    if (!s.exists || s.data() == null) return null;
    return AppUser.fromFirestore(uid, s.data()!);
  }

  /// Creates default profile if missing; always refreshes [lastLoginDate].
  Future<AppUser> ensureUserDocument(User firebaseUser) async {
    final ref = doc(firebaseUser.uid);
    final snap = await ref.get();
    final now = FieldValue.serverTimestamp();

    if (!snap.exists) {
      final model = AppUser(
        uid: firebaseUser.uid,
        name: firebaseUser.displayName ?? 'User',
        email: firebaseUser.email ?? '',
        resume: '',
        skills: [],
        interests: [],
        careerGoals: '',
        role: UserRole.user,
        createdAt: DateTime.now(),
        lastLoginDate: DateTime.now(),
      );
      await ref.set({
        ...model.toFirestore(),
        'createdAt': now,
        'lastLoginDate': now,
      });
    } else {
      await ref.update({'lastLoginDate': now});
    }

    final after = await ref.get();
    return AppUser.fromFirestore(firebaseUser.uid, after.data()!);
  }

  Future<void> updateProfile(AppUser user) async {
    await doc(user.uid).update({
      'name': user.name,
      'email': user.email,
      'resume': user.resume,
      'skills': user.skills,
      'interests': user.interests,
      'careerGoals': user.careerGoals,
      'lastLoginDate': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setRole(String uid, UserRole role) async {
    await doc(uid).update({'role': role.name});
  }

  Stream<List<AppUser>> watchAllUsers() {
    return _users.snapshots().map(
          (q) => q.docs.map((d) => AppUser.fromFirestore(d.id, d.data())).toList(),
        );
  }
}
