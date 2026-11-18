import 'dart:async';

import 'package:patient_tracker/data/models/history_entry.dart';
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

/// A synthetic history entry for tests.
HistoryEntry testHistoryEntry({
  String eventId = 'event-1',
  String patientId = 'HPT-TEST01',
  String from = 'er',
  String to = 'ward-a',
  DateTime? at,
  String byName = 'Test Nurse',
}) => HistoryEntry(
  eventId: eventId,
  patientId: patientId,
  fromLocation: from,
  toLocation: to,
  timestamp: at ?? DateTime.now(),
  updatedBy: 'nurse-1',
  updatedByName: byName,
);

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

  /// Transfers per patient, newest first.
  final history = <String, List<HistoryEntry>>{};
  final _historyChanges = StreamController<void>.broadcast();

  /// When true, subscribing to [watchHistory] fails.
  bool failHistoryOnListen = false;

  @override
  Stream<List<HistoryEntry>> watchHistory(String patientId) async* {
    await gate?.future;
    if (failHistoryOnListen) throw Exception('history unavailable');
    yield history[patientId] ?? const [];
    await for (final _ in _historyChanges.stream) {
      yield history[patientId] ?? const [];
    }
  }

  final changeStatusCalls = <({String patientId, PatientStatus status})>[];
  final transferCalls =
      <
        ({
          String patientId,
          String toLocation,
          String eventId,
          int expectedVersion,
        })
      >[];

  /// When set, writes wait for this before finishing, so they stay in flight.
  Completer<void>? writeGate;

  /// When set, writes throw this and change nothing.
  Object? writeError;

  @override
  Future<void> changeStatus(String patientId, PatientStatus status) async {
    changeStatusCalls.add((patientId: patientId, status: status));
    await writeGate?.future;
    if (writeError case final error?) throw error;
    update([
      for (final p in patients)
        p.patientId == patientId ? p.withStatus(status, at: DateTime.now()) : p,
    ]);
  }

  @override
  Future<void> transferPatient({
    required String patientId,
    required String toLocation,
    required String eventId,
    required int expectedVersion,
  }) async {
    transferCalls.add((
      patientId: patientId,
      toLocation: toLocation,
      eventId: eventId,
      expectedVersion: expectedVersion,
    ));
    await writeGate?.future;
    if (writeError case final error?) throw error;
    final at = DateTime.now();
    final from = patients.firstWhere((p) => p.patientId == patientId);
    history[patientId] = [
      testHistoryEntry(
        eventId: eventId,
        patientId: patientId,
        from: from.currentLocation,
        to: toLocation,
        at: at,
      ),
      ...?history[patientId],
    ];
    update([
      for (final p in patients)
        p.patientId == patientId ? p.withTransfer(toLocation, at: at) : p,
    ]);
    _historyChanges.add(null);
  }
}
