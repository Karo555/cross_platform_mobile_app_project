import 'package:flutter_test/flutter_test.dart';
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
}
