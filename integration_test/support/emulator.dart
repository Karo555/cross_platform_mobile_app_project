// Helpers shared by the end-to-end tests. They run the real app against the
// Firebase Emulator Suite, never against the real project.
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patient_tracker/app.dart';
import 'package:patient_tracker/data/firebase/firebase_setup.dart';
import 'package:patient_tracker/features/auth/screens/login_screen.dart';

/// Where the emulators run, as seen from the device. Same as for
/// `flutter run` (see README).
const emulatorHost = String.fromEnvironment(
  'EMULATOR_HOST',
  defaultValue: '10.0.2.2',
);
const _projectId = 'patient-tracker-cpma';

/// Password of every account the end-to-end tests create.
const testPassword = 'test1234';

/// A nurse account for the end-to-end tests. Created in the Auth emulator by
/// [createAccount]; it exists nowhere else.
const e2eNurse = 'e2e-nurse@test.local';

/// Connects to the emulators. Fails if the build points at the real project,
/// so the tests can never create accounts or move patients there.
Future<void> initEmulators() async {
  if (!const bool.fromEnvironment('USE_EMULATOR', defaultValue: true)) {
    fail('The end-to-end tests only run against the emulator.');
  }
  await initFirebase();
}

/// Starts the app with a new ProviderScope, so no state leaks between tests,
/// and waits for the login screen.
Future<void> startApp(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(key: UniqueKey(), child: const PatientTrackerApp()),
  );
  await pumpUntilFound(tester, find.byType(LoginScreen));
}

/// Fills in the login form and submits it.
Future<void> signIn(WidgetTester tester, String email, String password) async {
  await tester.enterText(find.byType(TextFormField).at(0), email);
  await tester.enterText(find.byType(TextFormField).at(1), password);
  await tester.tap(find.text('Sign in'));
}

/// Pumps until [finder] finds something, or fails after [timeout].
///
/// `pumpAndSettle` cannot be used: spinners never settle while a real
/// network request is running.
Future<void> pumpUntilFound(
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
/// sets its `role` claim. Leaves the account signed in. Uses the emulator's
/// admin API, which accepts the fixed token `owner`.
Future<void> createAccount(String email, {String? role}) async {
  final auth = FirebaseAuth.instance;
  try {
    await auth.createUserWithEmailAndPassword(
      email: email,
      password: testPassword,
    );
  } on FirebaseAuthException catch (e) {
    if (e.code != 'email-already-in-use') rethrow;
    await auth.signInWithEmailAndPassword(
      email: email,
      password: testPassword,
    );
  }
  final uid = auth.currentUser!.uid;

  final client = HttpClient();
  try {
    final request = await client.postUrl(
      Uri.http(
        '$emulatorHost:9099',
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
