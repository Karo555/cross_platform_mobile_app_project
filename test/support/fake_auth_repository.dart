import 'dart:async';

import 'package:patient_tracker/data/models/app_user.dart';
import 'package:patient_tracker/data/repositories/auth_repository.dart';

const nurse = AppUser(
  uid: 'nurse-1',
  email: 'nurse@example.com',
  role: UserRole.nurse,
);

/// In-memory [AuthRepository] for tests.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.user, this.userOnSignIn = nurse});

  /// The current user. Reported again whenever the stream is re-subscribed.
  AppUser? user;
  final AppUser? userOnSignIn;
  final _changes = StreamController<AppUser?>.broadcast();

  /// When set, [signIn] throws this.
  AuthError? signInError;

  /// When set, [signIn] waits for this before finishing.
  Completer<void>? signInGate;

  final signInCalls = <({String email, String password})>[];

  /// When true, subscribing to [authStateChanges] fails.
  bool failOnListen = false;

  void emitError(Object error) => _changes.addError(error);

  @override
  Stream<AppUser?> authStateChanges() async* {
    if (failOnListen) throw Exception('auth unavailable');
    yield user;
    yield* _changes.stream;
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    signInCalls.add((email: email, password: password));
    await signInGate?.future;
    final error = signInError;
    if (error != null) throw AuthException(error);
    user = userOnSignIn;
    _changes.add(user);
  }

  @override
  Future<void> signOut() async {
    user = null;
    _changes.add(null);
  }
}
