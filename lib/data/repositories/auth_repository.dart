import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_user.dart';
import 'unconfigured_auth_repository.dart';

/// Why a sign-in failed.
enum AuthError {
  /// Wrong email or password. Deliberately does not say which one, so the
  /// login screen cannot be used to find out which accounts exist.
  invalidCredentials,
  userDisabled,
  tooManyRequests,
  network,
  notConfigured,
  unknown,
}

class AuthException implements Exception {
  const AuthException(this.error);

  final AuthError error;

  @override
  String toString() => 'AuthException(${error.name})';
}

/// Signs users in and out. Screens use this instead of `firebase_auth`.
abstract interface class AuthRepository {
  /// Emits the current user on listen, then again on every sign-in and
  /// sign-out. Emits null when nobody is signed in.
  Stream<AppUser?> authStateChanges();

  /// Throws [AuthException] if the sign-in fails. Implementations must map
  /// every failure to it. On success the new user arrives through
  /// [authStateChanges].
  Future<void> signIn({required String email, required String password});

  Future<void> signOut();
}

/// Replace [UnconfiguredAuthRepository] with the Firebase implementation once
/// the Firebase project is set up (#4). Tests override this provider.
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => const UnconfiguredAuthRepository(),
);

/// The signed-in user and their role, for any screen that needs them.
final authStateProvider = StreamProvider<AppUser?>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges(),
);
