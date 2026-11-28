import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patient_tracker/app.dart';
import 'package:patient_tracker/data/repositories/auth_repository.dart';
import 'package:patient_tracker/data/repositories/firestore_patient_repository.dart';
import 'package:patient_tracker/data/repositories/patient_repository.dart';
import 'package:patient_tracker/features/patients/widgets/patient_tile.dart';

import '../../support/fake_auth_repository.dart';

/// The patient list on top of the real Firestore repository: the path a
/// change made on another device takes to the start screen (#26). Two real
/// devices are checked in #29.

/// A `patients/{patientId}` document as `docs/schema.md` describes it.
Map<String, dynamic> _patientDoc(
  String patientId, {
  required String name,
  String location = 'ward-a',
  String status = 'In Treatment',
}) {
  final now = Timestamp.now();
  return {
    'patientId': patientId,
    'name': name,
    'age': 54,
    'condition': 'Observation',
    'admissionDate': now,
    'currentLocation': location,
    'status': status,
    'lastUpdated': now,
    'locationUpdatedAt': now,
    'version': 1,
  };
}

void main() {
  late FakeFirebaseFirestore db;

  CollectionReference<Map<String, dynamic>> patients() =>
      db.collection('patients');

  setUp(() async {
    db = FakeFirebaseFirestore();
    await db.collection('locations').doc('ward-a').set({'name': 'Ward A'});
    await db.collection('locations').doc('radiology').set({
      'name': 'Radiology',
    });
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(user: nurse),
          ),
          patientRepositoryProvider.overrideWithValue(
            FirestorePatientRepository(db),
          ),
        ],
        child: const PatientTrackerApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The names in the order the list shows them.
  List<String> shownNames(WidgetTester tester) => [
    for (final tile in tester.widgetList<PatientTile>(find.byType(PatientTile)))
      tile.patient.name,
  ];

  testWidgets('shows every patient from Firestore, ordered by name', (
    tester,
  ) async {
    await patients()
        .doc('HPT-TEST02')
        .set(_patientDoc('HPT-TEST02', name: 'B'));
    await patients()
        .doc('HPT-TEST01')
        .set(_patientDoc('HPT-TEST01', name: 'A'));
    await pumpApp(tester);

    expect(shownNames(tester), ['A', 'B']);
    expect(find.text('HPT-TEST01'), findsOneWidget);
    expect(find.textContaining('Last recorded: Ward A'), findsNWidgets(2));
  });

  testWidgets('shows changes made elsewhere without a refresh', (tester) async {
    await patients()
        .doc('HPT-TEST01')
        .set(_patientDoc('HPT-TEST01', name: 'B'));
    await pumpApp(tester);
    expect(shownNames(tester), ['B']);

    // Admitted on another device.
    await patients()
        .doc('HPT-TEST02')
        .set(_patientDoc('HPT-TEST02', name: 'A'));
    await tester.pumpAndSettle();
    expect(shownNames(tester), ['A', 'B']);

    // Transferred and given a new status on another device.
    await patients().doc('HPT-TEST01').update({
      'currentLocation': 'radiology',
      'locationUpdatedAt': Timestamp.now(),
      'status': 'Ready for Discharge',
    });
    await tester.pumpAndSettle();
    expect(find.textContaining('Last recorded: Radiology'), findsOneWidget);
    expect(find.text('Ready for Discharge'), findsOneWidget);

    // Removed on another device.
    await patients().doc('HPT-TEST02').delete();
    await tester.pumpAndSettle();
    expect(shownNames(tester), ['B']);
  });

  testWidgets('shows a renamed location without a refresh', (tester) async {
    await patients()
        .doc('HPT-TEST01')
        .set(_patientDoc('HPT-TEST01', name: 'A'));
    await pumpApp(tester);

    await db.collection('locations').doc('ward-a').update({'name': 'Ward A2'});
    await tester.pumpAndSettle();

    expect(find.textContaining('Last recorded: Ward A2'), findsOneWidget);
  });
}
