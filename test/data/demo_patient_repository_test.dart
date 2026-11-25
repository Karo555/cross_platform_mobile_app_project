import 'package:flutter_test/flutter_test.dart';
import 'package:patient_tracker/data/models/patient.dart';
import 'package:patient_tracker/data/repositories/demo_patient_repository.dart';

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
}
