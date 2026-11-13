import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_user.dart';
import 'auth_repository.dart';

/// [AuthRepository] backed by Firebase Authentication.
///
/// Firebase keeps the session on the device, so a user who restarts the app
/// is still signed in and [authStateChanges] reports them right away.
class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._auth);

  final FirebaseAuth _auth;

  /// Uses `idTokenChanges` rather than `authStateChanges`, because it also
  /// fires when the token is refreshed. A role changed by an administrator
  /// then reaches the app without signing out and in again.
  @override
  Stream<AppUser?> authStateChanges() =>
      _auth.idTokenChanges().asyncMap((user) async {
        if (user == null) return null;
        // Reads the cached token, so this also works offline.
        final token = await user.getIdTokenResult();
        return appUserFromToken(
          uid: user.uid,
          email: user.email,
          claims: token.claims,
        );
      });

  @override
  Future<void> signIn({required String email, required String password}) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      throw AuthException(authErrorForCode(e.code));
    } on Object {
      throw const AuthException(AuthError.unknown);
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();
}

/// Builds the [AppUser] from a Firebase user and the claims of its ID token.
/// The role comes only from the `role` claim (see docs/schema.md).
AppUser appUserFromToken({
  required String uid,
  required String? email,
  required Map<String, dynamic>? claims,
}) => AppUser(
  uid: uid,
  email: email ?? '',
  role: UserRole.fromClaim(claims?['role']),
);

/// Maps a [FirebaseAuthException.code] to an [AuthError].
///
/// Unknown email, wrong password and malformed email all become
/// [AuthError.invalidCredentials], so the login screen does not reveal which
/// accounts exist. Newer SDKs already report all of them as
/// `invalid-credential`; the older codes are kept for other platforms.
AuthError authErrorForCode(String code) => switch (code) {
  'invalid-credential' ||
  'invalid-email' ||
  'user-not-found' ||
  'wrong-password' ||
  'INVALID_LOGIN_CREDENTIALS' => AuthError.invalidCredentials,
  'user-disabled' => AuthError.userDisabled,
  'too-many-requests' => AuthError.tooManyRequests,
  'network-request-failed' => AuthError.network,
  _ => AuthError.unknown,
};
