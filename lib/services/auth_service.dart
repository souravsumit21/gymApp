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
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user!;

      // Check if user already has a profile in Firestore
      final doc = await _db.collection('users').doc(user.uid).get();

      if (!doc.exists) {
        // First time — create profile
        final profile = UserProfile(
          uid: user.uid,
          email: user.email ?? '',
          displayName: user.displayName ?? 'Athlete',
          photoUrl: user.photoURL,
          createdAt: DateTime.now(),
          onboardingComplete: false,
        );
        await _db.collection('users').doc(user.uid).set(profile.toMap());
        return profile;
      } else {
        return UserProfile.fromMap(doc.data()!);
      }
    } catch (e) {
      throw AuthException('Google sign-in failed: ${e.toString()}');
    }
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
