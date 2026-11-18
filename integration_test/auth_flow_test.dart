// End-to-end sign-in test against the Firebase Auth emulator (#11).
//
// Runs the real app with the real FirebaseAuthRepository, on a simulator,
// emulator or phone. It creates its own test accounts, so no seed data is
// needed.
//
//   firebase emulators:start --only auth
//   flutter test integration_test --dart-define=EMULATOR_HOST=localhost
//
// EMULATOR_HOST works as for `flutter run` (see README). Not part of CI,
// because it needs a device and a running emulator.
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:patient_tracker/app.dart';
import 'package:patient_tracker/data/firebase/firebase_setup.dart';
import 'package:patient_tracker/features/auth/screens/login_screen.dart';
import 'package:patient_tracker/features/auth/screens/no_access_screen.dart';
import 'package:patient_tracker/features/patients/screens/patient_list_screen.dart';

const _host = String.fromEnvironment('EMULATOR_HOST', defaultValue: '10.0.2.2');
const _projectId = 'patient-tracker-cpma';
const _password = 'test1234';

const _nurse = 'e2e-nurse@test.local';
const _noRole = 'e2e-norole@test.local';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Never create accounts in the real project.
    if (!const bool.fromEnvironment('USE_EMULATOR', defaultValue: true)) {
      fail('This test only runs against the emulator.');
    }
    await initFirebase();
    await _createAccount(_nurse, role: 'nurse');
    await _createAccount(_noRole);
    await FirebaseAuth.instance.signOut();
  });

  testWidgets('a wrong password shows an error and stays on login', (
    tester,
  ) async {
    await _startApp(tester);
    await _signIn(tester, _nurse, 'wrong-password');

    await _pumpUntilFound(tester, find.text('Incorrect email or password.'));
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('an account without a role is stopped', (tester) async {
    await _startApp(tester);
    await _signIn(tester, _noRole, _password);

    await _pumpUntilFound(tester, find.byType(NoAccessScreen));

    await tester.tap(find.text('Sign out'));
    await _pumpUntilFound(tester, find.byType(LoginScreen));
  });

  testWidgets('a nurse signs in, sees the patients and signs out', (
    tester,
  ) async {
    await _startApp(tester);
    await _signIn(tester, _nurse, _password);

    await _pumpUntilFound(tester, find.byType(PatientListScreen));
    final token = await FirebaseAuth.instance.currentUser!.getIdTokenResult();
    expect(token.claims?['role'], 'nurse');

    await tester.tap(find.byTooltip('Sign out'));
    await _pumpUntilFound(tester, find.byType(LoginScreen));
    expect(FirebaseAuth.instance.currentUser, isNull);
  });
}

Future<void> _startApp(WidgetTester tester) async {
  // A new ProviderScope each time, so no state leaks between tests.
  await tester.pumpWidget(
    ProviderScope(key: UniqueKey(), child: const PatientTrackerApp()),
  );
  await _pumpUntilFound(tester, find.byType(LoginScreen));
}

Future<void> _signIn(WidgetTester tester, String email, String password) async {
  await tester.enterText(find.byType(TextFormField).at(0), email);
  await tester.enterText(find.byType(TextFormField).at(1), password);
  await tester.tap(find.text('Sign in'));
}

/// `pumpAndSettle` cannot be used: the sign-in spinner never settles while a
/// real network request is running.
Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 15),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Not found within $timeout: $finder');
}

/// Creates the account in the Auth emulator if it does not exist yet, and
/// sets its `role` claim. Uses the emulator's admin API, which accepts the
/// fixed token `owner`.
Future<void> _createAccount(String email, {String? role}) async {
  final auth = FirebaseAuth.instance;
  try {
    await auth.createUserWithEmailAndPassword(
      email: email,
      password: _password,
    );
  } on FirebaseAuthException catch (e) {
    if (e.code != 'email-already-in-use') rethrow;
    await auth.signInWithEmailAndPassword(email: email, password: _password);
  }
  final uid = auth.currentUser!.uid;

  final client = HttpClient();
  try {
    final request = await client.postUrl(
      Uri.http(
        '$_host:9099',
        '/identitytoolkit.googleapis.com/v1/projects/$_projectId/accounts:update',
      ),
    );
    request.headers
      ..set(HttpHeaders.authorizationHeader, 'Bearer owner')
      ..contentType = ContentType.json;
    request.write(
      jsonEncode({
        'localId': uid,
        'customAttributes': jsonEncode({'role': ?role}),
      }),
    );
    final response = await request.close();
    await response.drain<void>();
    if (response.statusCode != HttpStatus.ok) {
      fail('Could not set the role of $email: HTTP ${response.statusCode}');
    }
  } finally {
    client.close();
  }
}
