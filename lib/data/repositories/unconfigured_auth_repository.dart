import '../models/app_user.dart';
import 'auth_repository.dart';

/// Used until Firebase is set up (#4). Nobody is ever signed in, so the app
/// runs but every patient screen stays locked. Delete this class then.
class UnconfiguredAuthRepository implements AuthRepository {
  const UnconfiguredAuthRepository();

  @override
  Stream<AppUser?> authStateChanges() => Stream.value(null);

  @override
  Future<void> signIn({required String email, required String password}) =>
      Future.error(const AuthException(AuthError.notConfigured));

  @override
  Future<void> signOut() async {}
}
