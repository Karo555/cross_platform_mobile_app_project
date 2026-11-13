import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patient_tracker/app.dart';
import 'package:patient_tracker/data/models/app_user.dart';
import 'package:patient_tracker/data/repositories/auth_repository.dart';
import 'package:patient_tracker/features/auth/screens/login_screen.dart';
import 'package:patient_tracker/features/auth/screens/no_access_screen.dart';
import 'package:patient_tracker/features/patients/screens/patient_list_screen.dart';

import 'support/fake_auth_repository.dart';

Future<void> _pumpApp(WidgetTester tester, FakeAuthRepository auth) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(auth)],
      child: const PatientTrackerApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('App without Firebase starts on the login screen', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: PatientTrackerApp()));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('A restored session skips the login screen', (tester) async {
    await _pumpApp(tester, FakeAuthRepository(user: nurse));

    expect(find.byType(LoginScreen), findsNothing);
    expect(find.byType(PatientListScreen), findsOneWidget);
  });

  testWidgets('Signing in and out moves between login and home', (
    tester,
  ) async {
    await _pumpApp(tester, FakeAuthRepository());

    await tester.enterText(find.byType(TextFormField).at(0), 'a@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'secret');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.byType(PatientListScreen), findsOneWidget);

    await tester.tap(find.byTooltip('Sign out'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('An account without a role is stopped and can sign out', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      FakeAuthRepository(
        user: const AppUser(uid: 'u', email: 'x@example.com', role: null),
      ),
    );

    expect(find.byType(NoAccessScreen), findsOneWidget);

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
  });

  group('When the auth stream fails', () {
    // Riverpod re-subscribes by itself after a failure, with a growing delay.
    const afterRetries = Duration(seconds: 30);

    testWidgets('the app locks immediately and stays locked', (tester) async {
      final auth = FakeAuthRepository(user: nurse);
      await _pumpApp(tester, auth);

      auth.failOnListen = true;
      auth.emitError(Exception('token refresh failed'));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);

      await tester.pump(afterRetries);
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('a retry restores a session that is still valid', (
      tester,
    ) async {
      final auth = FakeAuthRepository(user: nurse);
      await _pumpApp(tester, auth);

      auth.emitError(Exception('blip'));
      await tester.pump(afterRetries);
      await tester.pumpAndSettle();

      expect(find.byType(PatientListScreen), findsOneWidget);
    });

    testWidgets('a retry does not restore a session that has ended', (
      tester,
    ) async {
      final auth = FakeAuthRepository(user: nurse);
      await _pumpApp(tester, auth);

      auth.user = null;
      auth.emitError(Exception('session revoked'));
      await tester.pump(afterRetries);
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
    });
  });
}
