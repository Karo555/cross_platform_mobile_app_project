import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patient_tracker/data/models/patient.dart';
import 'package:patient_tracker/data/repositories/firestore_patient_repository.dart';
import 'package:patient_tracker/data/repositories/patient_repository.dart';
import 'package:patient_tracker/features/patients/providers.dart';

final _movedAt = DateTime.utc(2026, 11, 3, 14, 5);

/// A `patients/{patientId}` document as `docs/schema.md` describes it.
Map<String, dynamic> _patientDoc({
  String patientId = 'HPT-TEST01',
  String name = 'Test Patient 01',
  String location = 'ward-a',
  String status = 'In Treatment',
  int version = 1,
}) => {
  'patientId': patientId,
  'name': name,
  'age': 54,
  'condition': 'Observation',
  'admissionDate': Timestamp.fromDate(DateTime.utc(2026, 11, 2, 8, 30)),
  'currentLocation': location,
  'status': status,
  'lastUpdated': Timestamp.fromDate(_movedAt),
  'locationUpdatedAt': Timestamp.fromDate(_movedAt),
  'version': version,
};

Map<String, dynamic> _historyDoc(
  String eventId, {
  required DateTime at,
  String from = 'er',
  String to = 'ward-a',
}) => {
  'eventId': eventId,
  'patientId': 'HPT-TEST01',
  'fromLocation': from,
  'toLocation': to,
  'timestamp': Timestamp.fromDate(at),
  'updatedBy': 'nurse-uid-1',
  'updatedByName': 'Test Nurse',
};

void main() {
  late FakeFirebaseFirestore db;
  late FirestorePatientRepository repository;

  setUp(() {
    db = FakeFirebaseFirestore();
    repository = FirestorePatientRepository(db);
  });

  DocumentReference<Map<String, dynamic>> patientRef([
    String id = 'HPT-TEST01',
  ]) => db.collection('patients').doc(id);

  group('watchPatient', () {
    test('reads every field of the document', () async {
      await patientRef().set(_patientDoc(status: 'Ready for Discharge'));

      final patient = await repository.watchPatient('HPT-TEST01').first;

      expect(patient, isNotNull);
      expect(patient!.patientId, 'HPT-TEST01');
      expect(patient.name, 'Test Patient 01');
      expect(patient.age, 54);
      expect(patient.condition, 'Observation');
      expect(patient.admissionDate.toUtc(), DateTime.utc(2026, 11, 2, 8, 30));
      expect(patient.currentLocation, 'ward-a');
      expect(patient.status, PatientStatus.readyForDischarge);
      expect(patient.lastUpdated.toUtc(), _movedAt);
      expect(patient.locationUpdatedAt.toUtc(), _movedAt);
      expect(patient.version, 1);
    });

    test('emits again after every change, without a new read', () async {
      // The details screen relies on this to update live (#16).
      await patientRef().set(_patientDoc());
      final emitted = repository.watchPatient('HPT-TEST01');

      final expectation = expectLater(
        emitted.map((p) => p?.currentLocation),
        emitsInOrder(['ward-a', 'radiology', null]),
      );
      await Future<void>.delayed(Duration.zero);
      await patientRef().update({'currentLocation': 'radiology'});
      await Future<void>.delayed(Duration.zero);
      await patientRef().delete();

      await expectation;
    });

    test('emits null for an unknown ID', () async {
      expect(await repository.watchPatient('HPT-NOPE').first, isNull);
    });

    test('emits null for an ID that would address another path', () async {
      await db
          .collection('patients')
          .doc('HPT-TEST01')
          .collection('history')
          .doc('e1')
          .set(_historyDoc('e1', at: _movedAt));

      expect(
        await repository.watchPatient('HPT-TEST01/history/e1').first,
        isNull,
      );
      expect(await repository.watchPatient('').first, isNull);
    });

    test('fails for a malformed document instead of guessing', () async {
      await patientRef().set(_patientDoc(status: 'Somewhere'));

      expect(
        repository.watchPatient('HPT-TEST01').first,
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('watchPatients', () {
    test('orders patients by name', () async {
      await patientRef('HPT-B').set(_patientDoc(patientId: 'HPT-B', name: 'B'));
      await patientRef('HPT-A').set(_patientDoc(patientId: 'HPT-A', name: 'A'));

      final patients = await repository.watchPatients().first;

      expect(patients.map((p) => p.name), ['A', 'B']);
    });

    test('leaves out a malformed patient but keeps the others', () async {
      await patientRef('HPT-A').set(_patientDoc(patientId: 'HPT-A', name: 'A'));
      await patientRef('HPT-B')
          .set(_patientDoc(patientId: 'HPT-B', name: 'B')..remove('version'));

      final patients = await repository.watchPatients().first;

      expect(patients.map((p) => p.patientId), ['HPT-A']);
    });
  });

  test('watchLocations reads the ID and name, ordered by name', () async {
    await db.collection('locations').doc('ward-a').set({'name': 'Ward A'});
    await db.collection('locations').doc('er').set({'name': 'Emergency'});

    final locations = await repository.watchLocations().first;

    expect(locations.map((l) => (l.id, l.name)), [
      ('er', 'Emergency'),
      ('ward-a', 'Ward A'),
    ]);
  });

  test('watchHistory lists one patient\'s transfers, newest first', () async {
    final history = patientRef().collection('history');
    await history.doc('old').set(_historyDoc('old', at: _movedAt));
    await history
        .doc('new')
        .set(
          _historyDoc(
            'new',
            at: _movedAt.add(const Duration(hours: 1)),
            from: 'ward-a',
            to: 'radiology',
          ),
        );
    await patientRef('HPT-OTHER')
        .collection('history')
        .doc('other')
        .set(_historyDoc('other', at: _movedAt));

    final entries = await repository.watchHistory('HPT-TEST01').first;

    expect(entries.map((e) => e.eventId), ['new', 'old']);
    expect(entries.first.fromLocation, 'ward-a');
    expect(entries.first.toLocation, 'radiology');
    expect(entries.first.updatedByName, 'Test Nurse');
  });

  group('changeStatus', () {
    test('changes only status, lastUpdated and version', () async {
      await patientRef().set(_patientDoc(version: 4));

      await repository.changeStatus('HPT-TEST01', PatientStatus.discharged);
      final data = (await patientRef().get()).data()!;

      expect(data['status'], 'Discharged');
      expect(data['version'], 5);
      expect(data['lastUpdated'], isNot(Timestamp.fromDate(_movedAt)));
      // Discharged is a status, not a location (docs/schema.md).
      expect(data['currentLocation'], 'ward-a');
      expect(data['locationUpdatedAt'], Timestamp.fromDate(_movedAt));
    });

    test('fails for an unknown patient and writes nothing', () async {
      await expectLater(
        repository.changeStatus('HPT-NOPE', PatientStatus.admitted),
        throwsStateError,
      );
      expect((await patientRef('HPT-NOPE').get()).exists, isFalse);
    });
  });

  test('transferPatient is left to #22', () {
    expect(
      repository.transferPatient(
        patientId: 'HPT-TEST01',
        toLocation: 'er',
        eventId: 'e1',
        expectedVersion: 1,
      ),
      throwsUnimplementedError,
    );
  });

  test('patientProvider passes on Firestore changes as they happen', () async {
    // The details screen watches this provider, so this is the path a change
    // made on another device takes to the screen (#16).
    await patientRef().set(_patientDoc());
    final container = ProviderContainer(
      overrides: [patientRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    final statuses = <PatientStatus?>[];
    container.listen(
      patientProvider('HPT-TEST01'),
      (_, next) => statuses.add(next.value?.status),
      fireImmediately: true,
    );

    await pumpEventQueue();
    await repository.changeStatus('HPT-TEST01', PatientStatus.discharged);
    await pumpEventQueue();

    expect(statuses.nonNulls, [
      PatientStatus.inTreatment,
      PatientStatus.discharged,
    ]);
  });
}
