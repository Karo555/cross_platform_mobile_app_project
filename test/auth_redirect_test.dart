import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patient_tracker/app.dart';
import 'package:patient_tracker/data/models/app_user.dart';
import 'package:patient_tracker/data/repositories/auth_repository.dart';

import 'support/fake_auth_repository.dart';

void main() {
  const signedOut = AsyncData<AppUser?>(null);
  const signedIn = AsyncData<AppUser?>(nurse);
  const noRole = AsyncData<AppUser?>(
    AppUser(uid: 'u', email: 'x@example.com', role: null),
  );
  const patientRoute = '/patients/P-1';

  group('while the session is being restored', () {
    const loading = AsyncLoading<AppUser?>();

    test('every route waits on the loading screen', () {
      expect(authRedirect(loading, patientRoute), '/loading');
      expect(authRedirect(loading, '/login'), '/loading');
    });

    test('the loading screen stays', () {
      expect(authRedirect(loading, '/loading'), isNull);
    });
  });

  group('signed out', () {
    test('a patient route goes to login', () {
      expect(authRedirect(signedOut, patientRoute), '/login');
    });

    test('the login screen stays', () {
      expect(authRedirect(signedOut, '/login'), isNull);
    });
  });

  group('signed in without a role', () {
    test('a patient route goes to no-access', () {
      expect(authRedirect(noRole, patientRoute), '/no-access');
    });

    test('the login screen goes to no-access', () {
      expect(authRedirect(noRole, '/login'), '/no-access');
    });
  });

  group('signed in with a role', () {
    test('a patient route stays', () {
      expect(authRedirect(signedIn, patientRoute), isNull);
    });

    test('auth screens go home', () {
      expect(authRedirect(signedIn, '/login'), '/');
      expect(authRedirect(signedIn, '/loading'), '/');
      expect(authRedirect(signedIn, '/no-access'), '/');
    });
  });

  test('an auth error locks the app even with a previous user', () async {
    final auth = FakeAuthRepository(user: nurse);
    final container = ProviderContainer.test(
      overrides: [authRepositoryProvider.overrideWithValue(auth)],
      retry: (_, _) => null,
    );
    final state = container.listen(authStateProvider, (_, _) {});
    await container.read(authStateProvider.future);
    await pumpEventQueue(); // Lets the fake start listening for changes.

    auth.emitError(Exception('failed'));
    await pumpEventQueue();

    expect(state.read().value, nurse, reason: 'the stale user stays readable');
    expect(authRedirect(state.read(), patientRoute), '/login');
  });

  group('UserRole.fromClaim', () {
    test('accepts the known roles', () {
      expect(UserRole.fromClaim('nurse'), UserRole.nurse);
      expect(UserRole.fromClaim('doctor'), UserRole.doctor);
    });

    test('rejects missing and unknown values', () {
      expect(UserRole.fromClaim(null), isNull);
      expect(UserRole.fromClaim('admin'), isNull);
      expect(UserRole.fromClaim('Nurse'), isNull);
      expect(UserRole.fromClaim(1), isNull);
    });
  });
}
