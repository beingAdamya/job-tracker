import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_boot.dart';

class AuthService {
  static FirebaseAuth get _auth => FirebaseAuth.instance;

  // The signed-in user (null if nobody, or if Firebase did not start)
  static User? get user => FirebaseBoot.ready ? _auth.currentUser : null;

  // Fires on sign-in, sign-out and account changes
  static Stream<User?> get changes => _auth.userChanges();

  static Future<void> signIn(String email, String password) async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  // Creates the account (which also signs in) and emails a verification link
  static Future<void> signUp(String email, String password) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    try {
      await credential.user?.sendEmailVerification();
    } catch (_) {
      // The verify screen has a Resend button, so this is not fatal
    }
  }

  static Future<void> sendVerification() async {
    await _auth.currentUser?.sendEmailVerification();
  }

  // Asks Firebase for the latest and says whether the email is verified
  static Future<bool> refreshVerified() async {
    final current = _auth.currentUser;
    if (current == null) return false;
    await current.reload();
    return _auth.currentUser?.emailVerified ?? false;
  }

  static Future<void> resetPassword(String email) {
    return _auth.sendPasswordResetEmail(email: email.trim());
  }

  static Future<void> signOut() => _auth.signOut();

  // Friendly text for Firebase's error codes
  static String message(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'invalid-email':
          return 'That email address does not look right.';
        case 'user-disabled':
          return 'This account has been disabled.';
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'Wrong email or password.';
        case 'email-already-in-use':
          return 'An account with this email already exists. Try signing in.';
        case 'weak-password':
          return 'Please choose a stronger password (at least 8 characters).';
        case 'too-many-requests':
          return 'Too many attempts. Please wait a few minutes and try again.';
        case 'network-request-failed':
          return 'No internet connection. Check your network and try again.';
        case 'operation-not-allowed':
          return 'Email sign-in is not switched on yet (Firebase console → Authentication → Sign-in method).';
        default:
          return e.message ?? 'Something went wrong (${e.code}).';
      }
    }
    return 'Something went wrong. Please try again.';
  }
}