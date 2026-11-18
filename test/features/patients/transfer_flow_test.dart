import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:patient_tracker/app.dart';
import 'package:patient_tracker/core/connectivity.dart';
import 'package:patient_tracker/data/models/app_user.dart';
import 'package:patient_tracker/data/repositories/auth_repository.dart';
import 'package:patient_tracker/data/repositories/patient_repository.dart';
import 'package:patient_tracker/features/patients/screens/patient_details_screen.dart';
import 'package:patient_tracker/features/patients/screens/patient_list_screen.dart';
import 'package:patient_tracker/features/patients/screens/transfer_screen.dart';
import 'package:patient_tracker/features/patients/widgets/transfer_dialog.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/fake_patient_repository.dart';

const _doctor = AppUser(
  uid: 'doctor-1',
  email: 'doctor@example.com',
  role: UserRole.doctor,
);

final _uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

/// Starts the app as [user] and pushes [route]. The only patient is in
/// Ward A unless the repository says otherwise.
Future<void> _start(
  WidgetTester tester,
  FakePatientRepository patients, {
  AppUser user = nurse,
  bool online = true,
  String route = '/patients/HPT-TEST01',
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          FakeAuthRepository(user: user),
        ),
        patientRepositoryProvider.overrideWithValue(patients),
        isOnlineProvider.overrideWith((ref) => Stream.value(online)),
      ],
      child: const PatientTrackerApp(),
    ),
  );
  await tester.pumpAndSettle();
  unawaited(
    GoRouter.of(tester.element(find.byType(PatientListScreen))).push(route),
  );
  await tester.pumpAndSettle();
}

/// From the details screen, opens the transfer screen and picks [to].
Future<void> _chooseDestination(WidgetTester tester, String to) async {
  await tester.tap(find.text('Transfer patient'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(ListTile, to));
  await tester.pumpAndSettle();
}

Finder get _dialog => find.byType(TransferDialog);

Finder _inDialog(Finder finder) =>
    find.descendant(of: _dialog, matching: finder);

void main() {
  testWidgets('lists every destination except the current location', (
    tester,
  ) async {
    await _start(tester, FakePatientRepository(patients: [testPatient()]));

    await tester.tap(find.text('Transfer patient'));
    await tester.pumpAndSettle();

    expect(find.byType(TransferScreen), findsOneWidget);
    expect(find.text('Last recorded location: Ward A'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Emergency'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Radiology'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Ward A'), findsNothing);
  });

  testWidgets('the list follows the patient when someone else moves them', (
    tester,
  ) async {
    final repository = FakePatientRepository(patients: [testPatient()]);
    await _start(tester, repository);
    await tester.tap(find.text('Transfer patient'));
    await tester.pumpAndSettle();

    repository.update([testPatient(location: 'er')]);
    await tester.pumpAndSettle();

    expect(find.text('Last recorded location: Emergency'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Emergency'), findsNothing);
    expect(find.widgetWithText(ListTile, 'Ward A'), findsOneWidget);
  });

  testWidgets('the confirmation shows the patient and from → to', (
    tester,
  ) async {
    await _start(tester, FakePatientRepository(patients: [testPatient()]));
    await _chooseDestination(tester, 'Radiology');

    expect(_dialog, findsOneWidget);
    expect(_inDialog(find.text('Test Patient 01')), findsOneWidget);
    expect(_inDialog(find.text('HPT-TEST01')), findsOneWidget);
    expect(_inDialog(find.text('From')), findsOneWidget);
    expect(_inDialog(find.text('Ward A')), findsOneWidget);
    expect(_inDialog(find.text('To')), findsOneWidget);
    expect(_inDialog(find.text('Radiology')), findsOneWidget);
  });

  testWidgets('Cancel goes back to the list without transferring', (
    tester,
  ) async {
    final repository = FakePatientRepository(patients: [testPatient()]);
    await _start(tester, repository);
    await _chooseDestination(tester, 'Radiology');

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(_dialog, findsNothing);
    expect(find.byType(TransferScreen), findsOneWidget);
    expect(repository.transferCalls, isEmpty);
    expect(repository.patients.single.currentLocation, 'ward-a');
  });

  testWidgets('shows success only after the backend accepted the transfer', (
    tester,
  ) async {
    final repository = FakePatientRepository(patients: [testPatient()])
      ..writeGate = Completer<void>();
    await _start(tester, repository);
    await _chooseDestination(tester, 'Radiology');

    await tester.tap(find.text('Transfer'));
    await tester.pump();

    final call = repository.transferCalls.single;
    expect(call.patientId, 'HPT-TEST01');
    expect(call.toLocation, 'radiology');
    expect(call.expectedVersion, 1);
    expect(call.eventId, matches(_uuid));

    // In flight: nothing can be pressed, and the dialog cannot be closed.
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
    expect(find.textContaining('Moved to'), findsNothing);

    repository.writeGate!.complete();
    await tester.pumpAndSettle();

    expect(_dialog, findsNothing);
    expect(find.byType(TransferScreen), findsNothing);
    expect(find.byType(PatientDetailsScreen), findsOneWidget);
    expect(find.text('Moved to Radiology.'), findsOneWidget);
    expect(find.text('Radiology'), findsOneWidget); // last recorded location
    expect(repository.transferCalls, hasLength(1));
  });

  testWidgets('a retry after a failure reuses the same event ID', (
    tester,
  ) async {
    final repository = FakePatientRepository(patients: [testPatient()])
      ..writeError = Exception('unavailable');
    await _start(tester, repository);
    await _chooseDestination(tester, 'Emergency');

    await tester.tap(find.text('Transfer'));
    await tester.pumpAndSettle();

    expect(_dialog, findsOneWidget);
    expect(
      find.text('The patient was not transferred. Try again.'),
      findsOneWidget,
    );
    expect(repository.patients.single.currentLocation, 'ward-a');

    repository.writeError = null;
    await tester.tap(find.text('Transfer'));
    await tester.pumpAndSettle();

    expect(find.text('Moved to Emergency.'), findsOneWidget);
    final ids = repository.transferCalls.map((c) => c.eventId).toSet();
    expect(repository.transferCalls, hasLength(2));
    expect(ids, hasLength(1));
  });

  testWidgets('each new transfer gets a new event ID', (tester) async {
    final repository = FakePatientRepository(patients: [testPatient()]);
    await _start(tester, repository);

    await _chooseDestination(tester, 'Emergency');
    await tester.tap(find.text('Transfer'));
    await tester.pumpAndSettle();
    await _chooseDestination(tester, 'Ward A');
    await tester.tap(find.text('Transfer'));
    await tester.pumpAndSettle();

    final ids = repository.transferCalls.map((c) => c.eventId).toSet();
    expect(ids, hasLength(2));
  });

  testWidgets('a conflict says why and offers no retry', (tester) async {
    final repository = FakePatientRepository(patients: [testPatient()])
      ..writeError = const TransferConflict();
    await _start(tester, repository);
    await _chooseDestination(tester, 'Radiology');

    await tester.tap(find.text('Transfer'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('changed by someone else in the meantime'),
      findsOneWidget,
    );
    expect(_inDialog(find.text('Transfer')), findsNothing);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(_dialog, findsNothing);
    expect(find.byType(TransferScreen), findsOneWidget);
  });

  testWidgets('offline, the transfer cannot be confirmed', (tester) async {
    final repository = FakePatientRepository(patients: [testPatient()]);
    await _start(tester, repository, online: false);
    await _chooseDestination(tester, 'Radiology');

    expect(
      find.text('You are offline. Connect to transfer the patient.'),
      findsOneWidget,
    );
    final transfer = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Transfer'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(transfer.onPressed, isNull);
    expect(repository.transferCalls, isEmpty);
  });

  testWidgets('a doctor opening the transfer URL is turned away', (
    tester,
  ) async {
    await _start(
      tester,
      FakePatientRepository(patients: [testPatient()]),
      user: _doctor,
      route: '/patients/HPT-TEST01/transfer',
    );

    expect(find.text('Only nurses can transfer patients'), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('an unknown patient shows "not found"', (tester) async {
    await _start(
      tester,
      FakePatientRepository(patients: [testPatient()]),
      route: '/patients/HPT-NOPE/transfer',
    );

    expect(find.text('Patient not found'), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('the screen and dialog meet tap target and contrast guidelines', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _start(tester, FakePatientRepository(patients: [testPatient()]));
    await tester.tap(find.text('Transfer patient'));
    await tester.pumpAndSettle();

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));

    await tester.tap(find.widgetWithText(ListTile, 'Radiology'));
    await tester.pumpAndSettle();

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  });

  testWidgets('does not overflow on a small screen with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await _start(
      tester,
      FakePatientRepository(
        patients: [
          testPatient(
            name: 'Test Patient With A Very Long Double-Barrelled Name',
          ),
        ],
      ),
      route: '/patients/HPT-TEST01/transfer',
    );
    expect(tester.takeException(), isNull);

    final radiology = find.widgetWithText(ListTile, 'Radiology');
    // At this size the tile is further down than the list has built yet.
    await tester.scrollUntilVisible(
      radiology,
      100,
      scrollable: find.descendant(
        of: find.byType(TransferScreen),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(radiology);
    await tester.pumpAndSettle();

    expect(_dialog, findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
