import 'package:flutter_test/flutter_test.dart';
import 'package:patient_tracker/data/models/patient.dart';
import 'package:patient_tracker/data/repositories/demo_patient_repository.dart';
import 'package:patient_tracker/data/repositories/patient_repository.dart';

void main() {
  final repository = DemoPatientRepository();

  test('demo data follows the schema', () async {
    final patients = await repository.watchPatients().first;
    final locations = await repository.watchLocations().first;
    final locationIds = locations.map((l) => l.id).toSet();

    expect(patients, isNotEmpty);
    expect(
      patients.map((p) => p.patientId).toSet(),
      hasLength(patients.length),
    );
    for (final patient in patients) {
      expect(locationIds, contains(patient.currentLocation));
    }
    for (final id in locationIds) {
      expect(id, matches(RegExp(r'^[a-z0-9-]+$')));
    }
  });

  test('patients are ordered by name, like the Firestore query', () async {
    final names = (await repository.watchPatients().first)
        .map((p) => p.name)
        .toList();
    expect(names, [...names]..sort());
  });

  group('changeStatus', () {
    test('changes only status, lastUpdated and version', () async {
      final repository = DemoPatientRepository(writeDelay: Duration.zero);
      final before = (await repository.watchPatients().first).first;
      final newStatus = PatientStatus.values.firstWhere(
        (s) => s != before.status,
      );

      await repository.changeStatus(before.patientId, newStatus);
      final after = await repository.watchPatient(before.patientId).first;

      expect(after!.status, newStatus);
      expect(after.version, before.version + 1);
      expect(after.lastUpdated.isAfter(before.lastUpdated), isTrue);
      expect(after.currentLocation, before.currentLocation);
      expect(after.locationUpdatedAt, before.locationUpdatedAt);
      expect(after.name, before.name);
    });

    test('discharging keeps the location', () async {
      final repository = DemoPatientRepository(writeDelay: Duration.zero);
      final before = (await repository.watchPatients().first).firstWhere(
        (p) => p.status != PatientStatus.discharged,
      );

      await repository.changeStatus(before.patientId, PatientStatus.discharged);
      final after = await repository.watchPatient(before.patientId).first;

      expect(after!.status, PatientStatus.discharged);
      expect(after.currentLocation, before.currentLocation);
    });

    test('open listeners see the change', () async {
      final repository = DemoPatientRepository(writeDelay: Duration.zero);
      final id = (await repository.watchPatients().first).first.patientId;
      final statuses = repository
          .watchPatient(id)
          .map((p) => p!.status)
          .take(2)
          .toList();
      await Future<void>.delayed(Duration.zero); // let the listener start

      await repository.changeStatus(id, PatientStatus.discharged);

      expect((await statuses).last, PatientStatus.discharged);
    });

    test('an unknown patient throws', () {
      final repository = DemoPatientRepository(writeDelay: Duration.zero);
      expect(
        repository.changeStatus('HPT-NOPE', PatientStatus.admitted),
        throwsStateError,
      );
    });
  });

  group('transferPatient', () {
    Future<(DemoPatientRepository, Patient, String)> setUp() async {
      final repository = DemoPatientRepository(writeDelay: Duration.zero);
      final patient = (await repository.watchPatients().first).first;
      final to = (await repository.watchLocations().first)
          .firstWhere((l) => l.id != patient.currentLocation)
          .id;
      return (repository, patient, to);
    }

    test('moves the patient and keeps the status', () async {
      final (repository, before, to) = await setUp();

      await repository.transferPatient(
        patientId: before.patientId,
        toLocation: to,
        eventId: 'event-1',
        expectedVersion: before.version,
      );
      final after = await repository.watchPatient(before.patientId).first;

      expect(after!.currentLocation, to);
      expect(after.locationUpdatedAt.isAfter(before.locationUpdatedAt), isTrue);
      expect(after.lastUpdated, after.locationUpdatedAt);
      expect(after.version, before.version + 1);
      expect(after.status, before.status);
    });

    test('a retry with the same event ID changes nothing (#34)', () async {
      final (repository, before, to) = await setUp();
      Future<void> transfer() => repository.transferPatient(
        patientId: before.patientId,
        toLocation: to,
        eventId: 'event-1',
        expectedVersion: before.version,
      );

      await transfer();
      // The version is now out of date, but a retry must still succeed.
      await transfer();

      final after = await repository.watchPatient(before.patientId).first;
      expect(after!.version, before.version + 1);
    });

    test(
      'an out-of-date version is a conflict and writes nothing (#35)',
      () async {
        final (repository, before, to) = await setUp();

        await expectLater(
          repository.transferPatient(
            patientId: before.patientId,
            toLocation: to,
            eventId: 'event-1',
            expectedVersion: before.version - 1,
          ),
          throwsA(isA<TransferConflict>()),
        );

        final after = await repository.watchPatient(before.patientId).first;
        expect(after!.currentLocation, before.currentLocation);
        expect(after.version, before.version);
      },
    );

    test('an unknown location throws', () async {
      final (repository, before, _) = await setUp();
      expect(
        repository.transferPatient(
          patientId: before.patientId,
          toLocation: 'nowhere',
          eventId: 'event-1',
          expectedVersion: before.version,
        ),
        throwsStateError,
      );
    });
  });
}
