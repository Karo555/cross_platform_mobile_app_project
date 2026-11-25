import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:patient_tracker/app.dart';
import 'package:patient_tracker/core/connectivity.dart';
import 'package:patient_tracker/data/models/app_user.dart';
import 'package:patient_tracker/data/models/patient.dart';
import 'package:patient_tracker/data/repositories/auth_repository.dart';
import 'package:patient_tracker/data/repositories/patient_repository.dart';
import 'package:patient_tracker/features/patients/screens/patient_list_screen.dart';
import 'package:patient_tracker/features/patients/widgets/change_status_dialog.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/fake_patient_repository.dart';

const _doctor = AppUser(
  uid: 'doctor-1',
  email: 'doctor@example.com',
  role: UserRole.doctor,
);

/// Opens the details of the only patient as a doctor and taps
/// "Change status".
Future<void> _openDialog(
  WidgetTester tester,
  FakePatientRepository patients, {
  bool online = true,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          FakeAuthRepository(user: _doctor),
        ),
        patientRepositoryProvider.overrideWithValue(patients),
        isOnlineProvider.overrideWith((ref) => Stream.value(online)),
      ],
      child: const PatientTrackerApp(),
    ),
  );
  await tester.pumpAndSettle();
  unawaited(
    GoRouter.of(tester.element(find.byType(PatientListScreen)))
        .push('/patients/HPT-TEST01'),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Change status'));
  await tester.pumpAndSettle();
}

Finder get _dialog => find.byType(ChangeStatusDialog);

Finder _inDialog(Finder finder) =>
    find.descendant(of: _dialog, matching: finder);

FilledButton _confirmButton(WidgetTester tester) => tester.widget(
  find.ancestor(of: find.text('Confirm'), matching: find.byType(FilledButton)),
);

/// Selects [status] and waits until the buttons have finished animating.
Future<void> _pick(WidgetTester tester, PatientStatus status) async {
  final option = _inDialog(find.text(status.value));
  await tester.ensureVisible(option);
  await tester.pumpAndSettle();
  await tester.tap(option);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lists the four statuses and marks the current one', (
    tester,
  ) async {
    await _openDialog(tester, FakePatientRepository(patients: [testPatient()]));

    expect(_dialog, findsOneWidget);
    for (final status in PatientStatus.values) {
      expect(_inDialog(find.text(status.value)), findsOneWidget);
    }
    expect(
      find.descendant(
        of: find.widgetWithText(RadioListTile<PatientStatus>, 'In Treatment'),
        matching: find.text('Current status'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Confirm stays disabled until a different status is picked', (
    tester,
  ) async {
    await _openDialog(tester, FakePatientRepository(patients: [testPatient()]));
    expect(_confirmButton(tester).onPressed, isNull);

    await _pick(tester, PatientStatus.inTreatment); // the current one
    expect(_confirmButton(tester).onPressed, isNull);

    await _pick(tester, PatientStatus.readyForDischarge);
    expect(_confirmButton(tester).onPressed, isNotNull);
    expect(find.text('In Treatment → Ready for Discharge'), findsOneWidget);
  });

  testWidgets('Cancel closes the dialog without changing anything', (
    tester,
  ) async {
    final repository = FakePatientRepository(patients: [testPatient()]);
    await _openDialog(tester, repository);

    await _pick(tester, PatientStatus.discharged);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(_dialog, findsNothing);
    expect(repository.changeStatusCalls, isEmpty);
    expect(find.text('In Treatment'), findsOneWidget);
  });

  testWidgets('shows success only after the backend accepted the change', (
    tester,
  ) async {
    final repository = FakePatientRepository(patients: [testPatient()])
      ..writeGate = Completer<void>();
    await _openDialog(tester, repository);

    await _pick(tester, PatientStatus.readyForDischarge);
    await tester.tap(find.text('Confirm'));
    await tester.pump();

    // In flight: nothing can be pressed, and the dialog cannot be closed.
    expect(repository.changeStatusCalls, [
      (patientId: 'HPT-TEST01', status: PatientStatus.readyForDischarge),
    ]);
    expect(_inDialog(find.bySemanticsLabel('Saving')), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Cancel'))
          .onPressed,
      isNull,
    );
    await tester.binding.handlePopRoute(); // Android back button
    await tester.pump();
    expect(_dialog, findsOneWidget);
    expect(find.textContaining('Status changed'), findsNothing);

    repository.writeGate!.complete();
    await tester.pumpAndSettle();

    expect(_dialog, findsNothing);
    expect(find.text('Status changed to Ready for Discharge.'), findsOneWidget);
    expect(find.text('Ready for Discharge'), findsOneWidget); // the badge
    expect(find.byType(FilledButton), findsOneWidget); // tapping twice is safe
    expect(repository.changeStatusCalls, hasLength(1));
  });

  testWidgets('discharging keeps the last recorded location', (tester) async {
    final movedAt = DateTime.now().subtract(const Duration(hours: 3));
    final repository = FakePatientRepository(
      patients: [
        testPatient(location: 'radiology', locationUpdatedAt: movedAt),
      ],
    );
    await _openDialog(tester, repository);

    await _pick(tester, PatientStatus.discharged);
    expect(
      find.text('The last recorded location (Radiology) stays the same.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    final patient = repository.patients.single;
    expect(patient.status, PatientStatus.discharged);
    expect(patient.currentLocation, 'radiology');
    expect(patient.locationUpdatedAt, movedAt);
    expect(find.text('Radiology'), findsOneWidget);
    expect(find.text('Discharged'), findsOneWidget);
  });

  testWidgets('a failed write keeps the dialog open to try again', (
    tester,
  ) async {
    final repository = FakePatientRepository(patients: [testPatient()])
      ..writeError = Exception('permission-denied');
    await _openDialog(tester, repository);

    await _pick(tester, PatientStatus.admitted);
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(_dialog, findsOneWidget);
    expect(find.text('The status was not changed. Try again.'), findsOneWidget);
    expect(find.textContaining('Status changed'), findsNothing);
    expect(repository.patients.single.status, PatientStatus.inTreatment);

    repository.writeError = null;
    await tester.tap(find.text('Confirm')); // the choice was kept
    await tester.pumpAndSettle();

    expect(_dialog, findsNothing);
    expect(find.text('Status changed to Admitted.'), findsOneWidget);
    expect(repository.patients.single.status, PatientStatus.admitted);
  });

  testWidgets('offline, the change cannot be confirmed', (tester) async {
    final repository = FakePatientRepository(patients: [testPatient()]);
    await _openDialog(tester, repository, online: false);

    await _pick(tester, PatientStatus.admitted);

    expect(
      find.text('You are offline. Connect to change the status.'),
      findsOneWidget,
    );
    expect(_confirmButton(tester).onPressed, isNull);
    expect(repository.changeStatusCalls, isEmpty);
  });

  testWidgets('the dialog meets tap target and contrast guidelines', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _openDialog(tester, FakePatientRepository(patients: [testPatient()]));
    await _pick(tester, PatientStatus.discharged);

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  });

  testWidgets('the dialog does not overflow on a small screen with large '
      'text', (tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await _openDialog(tester, FakePatientRepository(patients: [testPatient()]));
    await _pick(tester, PatientStatus.discharged);

    expect(_dialog, findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
