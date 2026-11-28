// End-to-end sign-in test against the Firebase Auth emulator (#11).
//
// Runs the real app with the real FirebaseAuthRepository, on a simulator,
// emulator or phone. It creates its own test accounts, so no seed data is
// needed.
//
//   firebase emulators:start --only auth
//   flutter test integration_test/auth_flow_test.dart \
//     --dart-define=EMULATOR_HOST=localhost
//
// EMULATOR_HOST works as for `flutter run` (see README). Not part of CI,
// because it needs a device and a running emulator.
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:patient_tracker/features/auth/screens/login_screen.dart';
import 'package:patient_tracker/features/auth/screens/no_access_screen.dart';
import 'package:patient_tracker/features/patients/screens/patient_list_screen.dart';

import 'support/emulator.dart';

const _noRole = 'e2e-norole@test.local';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initEmulators();
    await createAccount(e2eNurse, role: 'nurse');
    await createAccount(_noRole);
    await FirebaseAuth.instance.signOut();
  });

  testWidgets('a wrong password shows an error and stays on login', (
    tester,
  ) async {
    await startApp(tester);
    await signIn(tester, e2eNurse, 'wrong-password');

    await pumpUntilFound(tester, find.text('Incorrect email or password.'));
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('an account without a role is stopped', (tester) async {
    await startApp(tester);
    await signIn(tester, _noRole, testPassword);

    await pumpUntilFound(tester, find.byType(NoAccessScreen));

    await tester.tap(find.text('Sign out'));
    await pumpUntilFound(tester, find.byType(LoginScreen));
  });

  testWidgets('a nurse signs in, sees the patients and signs out', (
    tester,
  ) async {
    await startApp(tester);
    await signIn(tester, e2eNurse, testPassword);

    await pumpUntilFound(tester, find.byType(PatientListScreen));
    final token = await FirebaseAuth.instance.currentUser!.getIdTokenResult();
    expect(token.claims?['role'], 'nurse');

    await tester.tap(find.byTooltip('Sign out'));
    await pumpUntilFound(tester, find.byType(LoginScreen));
    expect(FirebaseAuth.instance.currentUser, isNull);
  });
}
