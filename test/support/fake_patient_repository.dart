import 'dart:async';

import 'package:patient_tracker/data/models/location.dart';
import 'package:patient_tracker/data/models/patient.dart';
import 'package:patient_tracker/data/repositories/patient_repository.dart';

const testLocations = [
  Location(id: 'er', name: 'Emergency'),
  Location(id: 'ward-a', name: 'Ward A'),
  Location(id: 'radiology', name: 'Radiology'),
];

/// A synthetic patient for tests. Only pass what the test is about.
Patient testPatient({
  String patientId = 'HPT-TEST01',
  String name = 'Test Patient 01',
  String location = 'ward-a',
  PatientStatus status = PatientStatus.inTreatment,
  DateTime? locationUpdatedAt,
}) {
  final updatedAt = locationUpdatedAt ?? DateTime.now();
  return Patient(
    patientId: patientId,
    name: name,
    age: 40,
    condition: 'Observation',
    admissionDate: updatedAt.subtract(const Duration(days: 1)),
    currentLocation: location,
    status: status,
    lastUpdated: updatedAt,
    locationUpdatedAt: updatedAt,
    version: 1,
  );
}

/// In-memory [PatientRepository] for tests.
class FakePatientRepository implements PatientRepository {
  FakePatientRepository({
    this.patients = const [],
    this.locations = testLocations,
  });

  /// The current list. Reported again whenever the stream is re-subscribed.
  List<Patient> patients;
  final List<Location> locations;
  final _patientChanges = StreamController<List<Patient>>.broadcast();

  /// When set, nothing is emitted until it completes, so screens stay loading.
  Completer<void>? gate;

  /// When true, subscribing to [watchPatients] fails.
  bool failOnListen = false;

  /// Replaces the list, like a change pushed by a Firestore listener.
  void update(List<Patient> newPatients) {
    patients = newPatients;
    _patientChanges.add(newPatients);
  }

  @override
  Stream<List<Patient>> watchPatients() async* {
    await gate?.future;
    if (failOnListen) throw Exception('patients unavailable');
    yield patients;
    yield* _patientChanges.stream;
  }

  @override
  Stream<Patient?> watchPatient(String patientId) => watchPatients().map(
    (list) => list.where((p) => p.patientId == patientId).firstOrNull,
  );

  @override
  Stream<List<Location>> watchLocations() async* {
    await gate?.future;
    yield locations;
  }
}
