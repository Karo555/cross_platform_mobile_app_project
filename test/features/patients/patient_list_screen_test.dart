import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patient_tracker/app.dart';
import 'package:patient_tracker/core/widgets/state_views.dart';
import 'package:patient_tracker/data/models/patient.dart';
import 'package:patient_tracker/data/repositories/auth_repository.dart';
import 'package:patient_tracker/data/repositories/patient_repository.dart';
import 'package:patient_tracker/features/patients/screens/patient_details_screen.dart';
import 'package:patient_tracker/features/patients/widgets/patient_tile.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/fake_patient_repository.dart';

/// Starts the whole app as a signed-in nurse, so routing is tested too.
Future<void> _pumpApp(
  WidgetTester tester,
  FakePatientRepository patients, {
  bool settle = true,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          FakeAuthRepository(user: nurse),
        ),
        patientRepositoryProvider.overrideWithValue(patients),
      ],
      child: const PatientTrackerApp(),
    ),
  );
  if (settle) await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows name, status, ID and last recorded location', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      FakePatientRepository(
        patients: [
          testPatient(),
          testPatient(
            patientId: 'HPT-TEST02',
            name: 'Test Patient 02',
            location: 'radiology',
            status: PatientStatus.discharged,
          ),
        ],
      ),
    );

    expect(find.byType(PatientTile), findsNWidgets(2));
    expect(find.text('Test Patient 01'), findsOneWidget);
    expect(find.text('HPT-TEST01'), findsOneWidget);
    expect(find.text('In Treatment'), findsOneWidget);
    expect(find.textContaining('Last recorded: Ward A'), findsOneWidget);
    expect(find.text('Discharged'), findsOneWidget);
    expect(find.textContaining('Last recorded: Radiology'), findsOneWidget);
  });

  testWidgets('updates by itself when a patient is transferred', (
    tester,
  ) async {
    final repository = FakePatientRepository(patients: [testPatient()]);
    await _pumpApp(tester, repository);
    expect(find.textContaining('Last recorded: Ward A'), findsOneWidget);

    repository.update([testPatient(location: 'radiology')]);
    await tester.pumpAndSettle();

    expect(find.textContaining('Last recorded: Ward A'), findsNothing);
    expect(find.textContaining('Last recorded: Radiology'), findsOneWidget);
  });

  testWidgets('shows the location ID if the location is unknown', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      FakePatientRepository(patients: [testPatient(location: 'icu')]),
    );

    expect(find.textContaining('Last recorded: icu'), findsOneWidget);
  });

  testWidgets('tapping a patient opens their details', (tester) async {
    await _pumpApp(tester, FakePatientRepository(patients: [testPatient()]));

    await tester.tap(find.text('Test Patient 01'));
    await tester.pumpAndSettle();

    expect(find.byType(PatientDetailsScreen), findsOneWidget);
    expect(find.text('HPT-TEST01'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.byType(PatientTile), findsOneWidget);
  });

  testWidgets('shows a loading state until the data arrives', (tester) async {
    final repository = FakePatientRepository(patients: [testPatient()])
      ..gate = Completer<void>();
    await _pumpApp(tester, repository, settle: false);
    await tester.pump();

    expect(find.byType(LoadingState), findsOneWidget);

    repository.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(PatientTile), findsOneWidget);
  });

  testWidgets('shows an empty state without patients', (tester) async {
    await _pumpApp(tester, FakePatientRepository());

    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('No patients'), findsOneWidget);
  });

  testWidgets('shows an error with a retry that reloads the list', (
    tester,
  ) async {
    final repository = FakePatientRepository(patients: [testPatient()])
      ..failOnListen = true;
    await _pumpApp(tester, repository);

    expect(find.byType(ErrorState), findsOneWidget);

    repository.failOnListen = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.byType(ErrorState), findsNothing);
    expect(find.byType(PatientTile), findsOneWidget);
  });

  testWidgets('a row is read out as one item, without the dot', (tester) async {
    final handle = tester.ensureSemantics();
    await _pumpApp(tester, FakePatientRepository(patients: [testPatient()]));

    final label = tester
        .getSemantics(find.byType(PatientTile))
        .getSemanticsData()
        .label;
    expect(label, contains('Test Patient 01'));
    expect(label, contains('In Treatment'));
    expect(label, contains('ID HPT-TEST01'));
    expect(label, contains('Last recorded in Ward A at'));
    expect(label, isNot(contains('·')));
    handle.dispose();
  });

  testWidgets('rows meet tap target and contrast guidelines', (tester) async {
    final handle = tester.ensureSemantics();
    await _pumpApp(
      tester,
      FakePatientRepository(
        patients: [
          for (final status in PatientStatus.values)
            testPatient(
              patientId: 'HPT-${status.name}',
              name: 'Patient ${status.name}',
              status: status,
            ),
        ],
      ),
    );

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

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(user: nurse),
          ),
          patientRepositoryProvider.overrideWithValue(
            FakePatientRepository(
              patients: [
                testPatient(
                  name: 'Test Patient With A Very Long Double-Barrelled Name',
                  status: PatientStatus.readyForDischarge,
                ),
              ],
            ),
          ),
        ],
        child: const MediaQuery(
          data: MediaQueryData(
            size: Size(320, 480),
            textScaler: TextScaler.linear(3),
          ),
          child: PatientTrackerApp(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
