import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:patient_tracker/app.dart';
import 'package:patient_tracker/core/widgets/state_views.dart';
import 'package:patient_tracker/data/models/app_user.dart';
import 'package:patient_tracker/data/models/patient.dart';
import 'package:patient_tracker/data/repositories/auth_repository.dart';
import 'package:patient_tracker/data/repositories/patient_repository.dart';
import 'package:patient_tracker/features/patients/screens/patient_details_screen.dart';
import 'package:patient_tracker/features/patients/screens/patient_list_screen.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/fake_patient_repository.dart';

const _doctor = AppUser(
  uid: 'doctor-1',
  email: 'doctor@example.com',
  role: UserRole.doctor,
);

/// Starts the whole app signed in as [user] and opens [patientId]'s details.
Future<void> _openDetails(
  WidgetTester tester,
  FakePatientRepository patients, {
  String patientId = 'HPT-TEST01',
  AppUser user = nurse,
  bool settle = true,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          FakeAuthRepository(user: user),
        ),
        patientRepositoryProvider.overrideWithValue(patients),
      ],
      child: const PatientTrackerApp(),
    ),
  );
  // The list has to show first; hold its data back too if asked to.
  await tester.pump();
  await tester.pump();
  unawaited(
    GoRouter.of(tester.element(find.byType(PatientListScreen)))
        .push('/patients/$patientId'),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump();
  }
}

void main() {
  testWidgets('shows status, last recorded location and admission details', (
    tester,
  ) async {
    await _openDetails(
      tester,
      FakePatientRepository(
        patients: [
          testPatient(
            location: 'radiology',
            status: PatientStatus.readyForDischarge,
          ),
        ],
      ),
    );

    expect(find.byType(PatientDetailsScreen), findsOneWidget);
    // In the app bar and as the heading.
    expect(find.text('Test Patient 01'), findsNWidgets(2));
    expect(find.text('HPT-TEST01'), findsOneWidget);
    expect(find.text('Ready for Discharge'), findsOneWidget);
    expect(find.text('Radiology'), findsOneWidget);
    expect(find.textContaining('Recorded: '), findsOneWidget);
    expect(find.text('40 years'), findsOneWidget);
    expect(find.text('Observation'), findsOneWidget);
    expect(find.text('Admitted'), findsOneWidget);
  });

  testWidgets('says the location is the last recorded one, not live', (
    tester,
  ) async {
    await _openDetails(
      tester,
      FakePatientRepository(patients: [testPatient()]),
    );

    expect(find.text('Last recorded location'), findsOneWidget);
    expect(
      find.textContaining('Changes only when a transfer is confirmed'),
      findsOneWidget,
    );
  });

  testWidgets('updates by itself when the patient changes', (tester) async {
    final repository = FakePatientRepository(patients: [testPatient()]);
    await _openDetails(tester, repository);
    expect(find.text('Ward A'), findsOneWidget);

    repository.update([
      testPatient(location: 'er', status: PatientStatus.admitted),
    ]);
    await tester.pumpAndSettle();

    expect(find.text('Ward A'), findsNothing);
    expect(find.text('Emergency'), findsOneWidget);
    expect(find.text('Admitted'), findsNWidgets(2)); // status and the label
  });

  group('the action matches the role', () {
    testWidgets('a nurse can transfer but not change the status', (
      tester,
    ) async {
      await _openDetails(
        tester,
        FakePatientRepository(patients: [testPatient()]),
      );

      expect(find.text('Transfer patient'), findsOneWidget);
      expect(find.text('Change status'), findsNothing);
    });

    testWidgets('a doctor can change the status but not transfer', (
      tester,
    ) async {
      await _openDetails(
        tester,
        FakePatientRepository(patients: [testPatient()]),
        user: _doctor,
      );

      expect(find.text('Change status'), findsOneWidget);
      expect(find.text('Transfer patient'), findsNothing);
    });

    testWidgets('until #21 exists, the button says it is not ready', (
      tester,
    ) async {
      await _openDetails(
        tester,
        FakePatientRepository(patients: [testPatient()]),
      );

      await tester.tap(find.text('Transfer patient'));
      await tester.pump();

      expect(find.text('Transfers are not available yet.'), findsOneWidget);
    });
  });

  testWidgets('an unknown ID shows "not found" and no action', (tester) async {
    await _openDetails(
      tester,
      FakePatientRepository(patients: [testPatient()]),
      patientId: 'HPT-NOPE',
    );

    expect(find.text('Patient not found'), findsOneWidget);
    expect(find.textContaining('HPT-NOPE'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('shows a loading state until the data arrives', (tester) async {
    final repository = FakePatientRepository(patients: [testPatient()])
      ..gate = Completer<void>();
    await _openDetails(tester, repository, settle: false);

    expect(
      find.descendant(
        of: find.byType(PatientDetailsScreen),
        matching: find.byType(LoadingState),
      ),
      findsOneWidget,
    );

    repository.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Ward A'), findsOneWidget);
  });

  testWidgets('shows an error with a retry that reloads the patient', (
    tester,
  ) async {
    final repository = FakePatientRepository(patients: [testPatient()])
      ..failOnListen = true;
    await _openDetails(tester, repository);

    expect(find.text('Could not load this patient.'), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget); // only the retry

    repository.failOnListen = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('Could not load this patient.'), findsNothing);
    expect(find.text('Ward A'), findsOneWidget);
  });

  testWidgets('meets tap target and contrast guidelines', (tester) async {
    final handle = tester.ensureSemantics();
    await _openDetails(
      tester,
      FakePatientRepository(patients: [testPatient()]),
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
    // At 3x text the tile is taller than the screen, so open it directly.
    unawaited(
      GoRouter.of(tester.element(find.byType(PatientListScreen)))
          .push('/patients/HPT-TEST01'),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PatientDetailsScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
