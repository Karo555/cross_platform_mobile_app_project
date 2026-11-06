import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patient_tracker/data/repositories/auth_repository.dart';
import 'package:patient_tracker/features/auth/screens/login_screen.dart';

import '../../support/fake_auth_repository.dart';

void main() {
  late FakeAuthRepository auth;

  Future<void> pumpLogin(WidgetTester tester) async {
    auth = FakeAuthRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(auth)],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );
  }

  Future<void> fillIn(
    WidgetTester tester, {
    String email = 'nurse@example.com',
    String password = 'secret',
  }) async {
    await tester.enterText(find.byType(TextFormField).at(0), email);
    await tester.enterText(find.byType(TextFormField).at(1), password);
  }

  testWidgets('empty fields show errors and do not call the backend', (
    tester,
  ) async {
    await pumpLogin(tester);

    await tester.tap(find.text('Sign in'));
    await tester.pump();

    expect(find.text('Enter your email'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);
    expect(auth.signInCalls, isEmpty);
  });

  testWidgets('a malformed email is rejected', (tester) async {
    await pumpLogin(tester);
    await fillIn(tester, email: 'not-an-email');

    await tester.tap(find.text('Sign in'));
    await tester.pump();

    expect(find.text('Enter a valid email'), findsOneWidget);
    expect(auth.signInCalls, isEmpty);
  });

  testWidgets('the email is trimmed but the password is not', (tester) async {
    await pumpLogin(tester);
    await fillIn(tester, email: ' a@example.com ', password: ' spaced ');

    await tester.tap(find.text('Sign in'));
    await tester.pump();

    expect(auth.signInCalls.single.email, 'a@example.com');
    expect(auth.signInCalls.single.password, ' spaced ');
  });

  for (final (error, message) in [
    (AuthError.invalidCredentials, 'Incorrect email or password.'),
    (AuthError.network, 'No connection. Check your network and try again.'),
    (AuthError.tooManyRequests, 'Too many attempts. Try again later.'),
  ]) {
    testWidgets('shows a message for ${error.name}', (tester) async {
      await pumpLogin(tester);
      auth.signInError = error;
      await fillIn(tester);

      await tester.tap(find.text('Sign in'));
      await tester.pump();

      expect(find.text(message), findsOneWidget);
      expect(find.text('Sign in'), findsOneWidget, reason: 'can try again');
    });
  }

  testWidgets('a retry clears the previous error', (tester) async {
    await pumpLogin(tester);
    auth.signInError = AuthError.network;
    await fillIn(tester);
    await tester.tap(find.text('Sign in'));
    await tester.pump();

    auth.signInError = null;
    auth.signInGate = Completer();
    await tester.tap(find.text('Sign in'));
    await tester.pump();

    expect(find.textContaining('No connection'), findsNothing);
    auth.signInGate!.complete();
    await tester.pump();
  });

  testWidgets('cannot submit twice while signing in', (tester) async {
    await pumpLogin(tester);
    auth.signInGate = Completer();
    await fillIn(tester);

    await tester.tap(find.text('Sign in'));
    await tester.pump();

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(auth.signInCalls, hasLength(1));

    auth.signInGate!.complete();
    await tester.pump();
  });

  testWidgets('the password can be shown and hidden', (tester) async {
    await pumpLogin(tester);
    bool obscured() => tester
        .widget<EditableText>(
          find.descendant(
            of: find.byType(TextFormField).at(1),
            matching: find.byType(EditableText),
          ),
        )
        .obscureText;

    expect(obscured(), isTrue);

    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();

    expect(obscured(), isFalse);
  });

  testWidgets('fits a small screen with large text', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pumpLogin(tester);

    expect(tester.takeException(), isNull);
  });
}
