import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// [AuthService] acts as our authentication gateway.
///
/// **Why it uses Firebase Auth**:
/// 1. Firebase provides standard security, scaling, and integrations (e.g. Google Sign-In).
/// 2. It holds user sessions safely.
/// 3. It isolates user profiles so we can implement multi-tenant rules if needed.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Exposes a stream of authentication state changes.
  /// 
  /// **Why we use this**:
  /// Allows the UI ([MaterialApp] in `main.dart`) to dynamically toggle between
  /// the [LoginPage] and the [MainLayout] shell in real-time.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Retrieve the currently authenticated Firebase user profile details.
  User? get currentUser => _auth.currentUser;

  /// Authenticate an existing user with email/password credentials.
  /// 
  /// **Why it is used**: For simple form authentication before enabling OAuth SSO.
  Future<UserCredential> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Register a brand new user into Firebase Auth with email/password credentials.
  Future<UserCredential> signUpWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Triggers standard Google Authentication sign-in flow.
  /// 
  /// **Why we use this**:
  /// Standard SSO OAuth. Kicks off Google Identity flows on Web or native screens,
  /// extracts credentials, and exchanges them to generate a Firebase User credential.
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // 1. Trigger the Google sign-in dialog overlay (using the GoogleSignIn singleton instance and M3 authenticate() API)
      final GoogleSignInAccount googleUser = await GoogleSignIn.instance.authenticate();

      // 2. Fetch authentication tokens from Google (synchronous getter in google_sign_in 7.2.0)
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;
      
      // 3. Create a credential token mapper for Firebase using the ID token
      final OAuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      // 4. Authenticate session with Firebase Auth
      return await _auth.signInWithCredential(credential);
    } catch (e) {
      // Handle login cancellation gracefully
      if (e is GoogleSignInException && e.code == GoogleSignInExceptionCode.canceled) {
        print("User canceled Google sign in.");
        return null;
      }
      print("Google sign in service error: $e");
      rethrow;
    }
  }

  /// Signs the current user session out from Firebase Auth.
  /// 
  /// **Why we use this**: Invalidates active JWT tokens and triggers stream updates.
  Future<void> signOut() async {
    // Sign out from Firebase Auth
    await _auth.signOut();
    // Also disconnect Google Sign-In instance if it was active to allow clean re-logins
    try {
      await GoogleSignIn.instance.signOut();
    } catch (e) {
      print('Google sign out silent error: $e');
    }
  }
}

