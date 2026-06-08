import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  // ── Google Sign-In ──────────────────────────────────────
  Future<UserProfile?> signInWithGoogle() async {
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null;

    try {
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user!;
      return _loadOrCreateProfile(user);
    } on FirebaseAuthException catch (e) {
      throw AuthException('Google sign-in failed: ${e.message}');
    }
  }

  Future<UserProfile> _loadOrCreateProfile(User user) async {
    try {
      final doc = await _db.collection('users').doc(user.uid).get();

      if (doc.exists) {
        return UserProfile.fromMap(doc.data()!);
      }

      final profile = _profileFromFirebaseUser(user);
      await _db.collection('users').doc(user.uid).set(profile.toMap());
      return profile;
    } catch (_) {
      // Firebase Auth already succeeded; don't fail sign-in if Firestore hiccups.
      return _profileFromFirebaseUser(user);
    }
  }

  UserProfile _profileFromFirebaseUser(User user) {
    return UserProfile(
      uid: user.uid,
      email: user.email ?? '',
      displayName: user.displayName ?? 'Athlete',
      photoUrl: user.photoURL,
      createdAt: DateTime.now(),
      onboardingComplete: false,
    );
  }

  // ── Sign Out ────────────────────────────────────────────
  Future<void> signOut() async {
    await Future.wait([
      _auth.signOut(),
      _googleSignIn.signOut(),
    ]);
  }

  // ── Load Profile ────────────────────────────────────────
  Future<UserProfile?> loadUserProfile(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserProfile.fromMap(doc.data()!);
  }

  // ── Update Profile ──────────────────────────────────────
  Future<void> updateProfile(UserProfile profile) async {
    await _db
        .collection('users')
        .doc(profile.uid)
        .set(profile.toMap(), SetOptions(merge: true));
  }

  /// Sets a unique username handle for sharing. Returns false if taken.
  Future<bool> setUsername(String uid, String username) async {
    final normalized = username.trim().toLowerCase();
    if (normalized.length < 3 || !RegExp(r'^[a-z0-9_]+$').hasMatch(normalized)) {
      throw AuthException(
        'Username must be 3+ characters (letters, numbers, underscores).',
      );
    }

    final handleRef = _db.collection('usernames').doc(normalized);
    final existing = await handleRef.get();
    if (existing.exists && existing.data()?['userId'] != uid) {
      return false;
    }

    final userDoc = await _db.collection('users').doc(uid).get();
    if (!userDoc.exists) throw AuthException('User not found.');

    final profile = UserProfile.fromMap(userDoc.data()!);
    final oldUsername = profile.username?.trim().toLowerCase();

    final batch = _db.batch();
    batch.set(handleRef, {'userId': uid});
    batch.set(
      _db.collection('users').doc(uid),
      {'username': normalized},
      SetOptions(merge: true),
    );
    if (oldUsername != null &&
        oldUsername.isNotEmpty &&
        oldUsername != normalized) {
      batch.delete(_db.collection('usernames').doc(oldUsername));
    }
    await batch.commit();
    return true;
  }

  // ── Delete Account ──────────────────────────────────────
  Future<void> deleteAccount() async {
    final uid = currentUser?.uid;
    if (uid == null) return;
    await _db.collection('users').doc(uid).delete();
    await currentUser!.delete();
    await _googleSignIn.signOut();
  }
}

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  @override
  String toString() => message;
}

// ── Riverpod Providers ──────────────────────────────────
final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

final userProfileProvider = FutureProvider.family<UserProfile?, String>(
  (ref, uid) async {
    return ref.watch(authServiceProvider).loadUserProfile(uid);
  },
);
