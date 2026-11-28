// End-to-end test of the scan-to-transfer milestone (#25):
//
//   sign in → identify the patient → open the record → transfer → the new
//   entry is at the top of the movement history
//
// Runs the real app on a simulator, emulator or phone, signed in through the
// Auth emulator. Run it once on iOS and once on Android:
//
//   firebase emulators:start --only auth,firestore
//   flutter test integration_test/scan_to_transfer_test.dart \
//     --dart-define=EMULATOR_HOST=localhost
//
// Patient data comes from whatever `patientRepositoryProvider` uses in that
// build: the demo data by default, or Firestore once #16 and #22 are in. For
// Firestore, seed the emulator (#10) and pass the patient to move, for
// example `--dart-define=E2E_PATIENT_ID=HPT-000002`. The test reads the
// patient's current location and picks the first other one, so it can be
// run again on the same data.
//
// Not yet covered, so #25 stays open until they are added:
// - The scan itself. NFC (#13), QR (#14) and the lookup (#15) do not exist
//   yet, so [_identifyPatient] opens the record from the list instead. Once
//   #15 is in, replace it with the lookup the scanners call, so the test
//   opens the same route a scan does.
// - The screen recording, which is taken by hand (see
//   docs/milestones/scan-to-transfer.md).
//
// Not part of CI, because it needs a device and running emulators.
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:patient_tracker/features/patients/screens/history_screen.dart';
import 'package:patient_tracker/features/patients/screens/patient_details_screen.dart';
import 'package:patient_tracker/features/patients/screens/patient_list_screen.dart';
import 'package:patient_tracker/features/patients/screens/transfer_screen.dart';

import 'support/emulator.dart';

/// The patient to move. The default is a demo patient (in the Emergency
/// department, with no history yet).
const _patientId = String.fromEnvironment(
  'E2E_PATIENT_ID',
  defaultValue: 'HPT-DEMO03',
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initEmulators();
    await createAccount(e2eNurse, role: 'nurse');
    await FirebaseAuth.instance.signOut();
  });

  testWidgets('a nurse moves a patient and sees it in the history', (
    tester,
  ) async {
    await startApp(tester);

    // 1. Sign in.
    await signIn(tester, e2eNurse, testPassword);
    await pumpUntilFound(tester, find.byType(PatientListScreen));

    // 2. Identify the patient and open the record.
    await _identifyPatient(tester, _patientId);
    await pumpUntilFound(tester, find.byType(PatientDetailsScreen));
    await pumpUntilFound(tester, find.text('Transfer patient'));

    // 3. Transfer: pick the first location the patient is not in, confirm.
    await tester.tap(find.text('Transfer patient'));
    await pumpUntilFound(tester, find.text('Choose the destination'));
    final from = _textStartingWith(tester, 'Last recorded location: ');
    final destination = find.descendant(
      of: find.byType(TransferScreen),
      matching: find.byType(ListTile),
    );
    expect(destination, findsWidgets, reason: 'no other location to move to');
    final to =
        (tester.widget<ListTile>(destination.first).title! as Text).data!;
    expect(to, isNot(from));

    await tester.tap(destination.first);
    await pumpUntilFound(tester, find.text('Confirm transfer'));
    await tester.tap(find.widgetWithText(FilledButton, 'Transfer'));

    // Back on the record only once the backend has accepted the transfer,
    // and the record already shows the new location.
    await pumpUntilFound(tester, find.text('Moved to $to.'));
    expect(find.byType(PatientDetailsScreen), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(PatientDetailsScreen),
        matching: find.text(to),
      ),
      findsOneWidget,
    );

    // 4. The transfer is the newest history entry.
    await tester.tap(find.text('Movement history'));
    await pumpUntilFound(tester, find.byType(HistoryScreen));
    final entries = find.descendant(
      of: find.byType(HistoryScreen),
      matching: find.byType(ListTile),
    );
    await pumpUntilFound(tester, entries);
    final newest = tester.widget<ListTile>(entries.first);
    expect((newest.title! as Text).data, '$from → $to');
  });
}

/// Stand-in for the scan until #13–#15 exist: opens [patientId] from the
/// patient list, which goes to the same route a scan will.
Future<void> _identifyPatient(WidgetTester tester, String patientId) async {
  final tile = find.text(patientId);
  await pumpUntilFound(tester, find.byType(ListView));
  await tester.scrollUntilVisible(
    tile,
    200,
    scrollable: find.descendant(
      of: find.byType(ListView),
      matching: find.byType(Scrollable),
    ),
  );
  await tester.tap(tile);
}

/// The rest of the one text on screen that starts with [prefix].
String _textStartingWith(WidgetTester tester, String prefix) {
  final finder = find.byWidgetPredicate(
    (w) => w is Text && (w.data?.startsWith(prefix) ?? false),
  );
  expect(finder, findsOneWidget);
  return tester.widget<Text>(finder).data!.substring(prefix.length);
}
