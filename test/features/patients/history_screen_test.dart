import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:patient_tracker/app.dart';
import 'package:patient_tracker/core/connectivity.dart';
import 'package:patient_tracker/core/widgets/state_views.dart';
import 'package:patient_tracker/data/models/app_user.dart';
import 'package:patient_tracker/data/repositories/auth_repository.dart';
import 'package:patient_tracker/data/repositories/patient_repository.dart';
import 'package:patient_tracker/features/patients/screens/history_screen.dart';
import 'package:patient_tracker/features/patients/screens/patient_list_screen.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/fake_patient_repository.dart';

const _doctor = AppUser(
  uid: 'doctor-1',
  email: 'doctor@example.com',
  role: UserRole.doctor,
);

/// Starts the app as [user] and pushes [route].
Future<void> _start(
  WidgetTester tester,
  FakePatientRepository patients, {
  AppUser user = nurse,
  String route = '/patients/HPT-TEST01/history',
  bool settle = true,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          FakeAuthRepository(user: user),
        ),
        patientRepositoryProvider.overrideWithValue(patients),
        isOnlineProvider.overrideWith((ref) => Stream.value(true)),
      ],
      child: const PatientTrackerApp(),
    ),
  );
  await tester.pump();
  await tester.pump();
  unawaited(
    GoRouter.of(tester.element(find.byType(PatientListScreen))).push(route),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump();
  }
}

/// A repository whose only patient has [entries] as their history.
FakePatientRepository _withHistory(List<Object> entries) =>
    FakePatientRepository(patients: [testPatient()])
      ..history['HPT-TEST01'] = entries.cast();

void main() {
  testWidgets('lists transfers newest first with from → to, time and nurse', (
    tester,
  ) async {
    final now = DateTime.now();
    await _start(
      tester,
      _withHistory([
        testHistoryEntry(
          eventId: 'e2',
          from: 'radiology',
          to: 'ward-a',
          at: now,
          byName: 'Nurse Two',
        ),
        testHistoryEntry(
          eventId: 'e1',
          from: 'er',
          to: 'radiology',
          at: now.subtract(const Duration(days: 1)),
          byName: 'Nurse One',
        ),
      ]),
    );

    expect(find.byType(HistoryScreen), findsOneWidget);
    expect(find.text('Test Patient 01'), findsOneWidget);

    final newest = find.text('Radiology → Ward A');
    final oldest = find.text('Emergency → Radiology');
    expect(newest, findsOneWidget);
    expect(oldest, findsOneWidget);
    expect(
      tester.getTopLeft(newest).dy,
      lessThan(tester.getTopLeft(oldest).dy),
    );
    expect(find.textContaining('· Nurse Two'), findsOneWidget);
    expect(find.textContaining('Yesterday, '), findsOneWidget);
    expect(find.textContaining('· Nurse One'), findsOneWidget);
  });

  testWidgets('a patient without transfers shows an empty state', (
    tester,
  ) async {
    await _start(tester, FakePatientRepository(patients: [testPatient()]));

    expect(find.text('No transfers yet'), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('a new transfer appears at the top by itself', (tester) async {
    final repository = _withHistory([
      testHistoryEntry(from: 'er', to: 'ward-a'),
    ]);
    await _start(tester, repository);

    await repository.transferPatient(
      patientId: 'HPT-TEST01',
      toLocation: 'radiology',
      eventId: 'e2',
      expectedVersion: 1,
    );
    await tester.pumpAndSettle();

    final tiles = tester
        .widgetList<ListTile>(find.byType(ListTile))
        .map((t) => (t.title! as Text).data)
        .toList();
    expect(tiles, ['Ward A → Radiology', 'Emergency → Ward A']);
  });

  testWidgets('shows the ID when a location is missing', (tester) async {
    await _start(
      tester,
      _withHistory([testHistoryEntry(from: 'old-ward', to: 'ward-a')]),
    );

    expect(find.text('old-ward → Ward A'), findsOneWidget);
  });

  for (final user in [nurse, _doctor]) {
    testWidgets('opens from the details screen for a ${user.role!.name}', (
      tester,
    ) async {
      await _start(
        tester,
        _withHistory([testHistoryEntry()]),
        user: user,
        route: '/patients/HPT-TEST01',
      );

      await tester.tap(find.text('Movement history'));
      await tester.pumpAndSettle();

      expect(find.byType(HistoryScreen), findsOneWidget);
      expect(find.text('Emergency → Ward A'), findsOneWidget);
    });
  }

  testWidgets('shows a loading state until the history arrives', (
    tester,
  ) async {
    final repository = _withHistory([testHistoryEntry()])
      ..gate = Completer<void>();
    await _start(tester, repository, settle: false);

    expect(
      find.descendant(
        of: find.byType(HistoryScreen),
        matching: find.byType(LoadingState),
      ),
      findsOneWidget,
    );

    repository.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Emergency → Ward A'), findsOneWidget);
  });

  testWidgets('shows an error with a retry that reloads the history', (
    tester,
  ) async {
    final repository = _withHistory([testHistoryEntry()])
      ..failHistoryOnListen = true;
    await _start(tester, repository);

    expect(find.text('Could not load the movement history.'), findsOneWidget);

    repository.failHistoryOnListen = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('Emergency → Ward A'), findsOneWidget);
  });

  testWidgets('an unknown patient shows "not found"', (tester) async {
    await _start(
      tester,
      FakePatientRepository(patients: [testPatient()]),
      route: '/patients/HPT-NOPE/history',
    );

    expect(find.text('Patient not found'), findsOneWidget);
  });

  testWidgets('meets tap target and contrast guidelines', (tester) async {
    final handle = tester.ensureSemantics();
    await _start(tester, _withHistory([testHistoryEntry()]));

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  });

  void useSmallScreenWithLargeText(WidgetTester tester) {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }

  testWidgets('the list does not overflow on a small screen with large text', (
    tester,
  ) async {
    useSmallScreenWithLargeText(tester);
    await _start(
      tester,
      _withHistory([
        testHistoryEntry(from: 'radiology', to: 'ward-a'),
        testHistoryEntry(byName: 'A Nurse With A Rather Long Name'),
      ]),
    );

    expect(find.text('Radiology → Ward A'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the empty state does not overflow on a small screen with '
      'large text', (tester) async {
    useSmallScreenWithLargeText(tester);
    await _start(tester, FakePatientRepository(patients: [testPatient()]));

    expect(find.text('No transfers yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
