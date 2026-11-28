import 'dart:async';

import '../models/app_user.dart';
import '../models/history_entry.dart';
import '../models/location.dart';
import '../models/patient.dart';
import 'patient_repository.dart';

/// Synthetic patients and locations, so the screens can be built and tried
/// until Firestore has rules and seed data. Contains no real data.
///
/// Changes are kept in memory until the app restarts, and every open screen
/// sees them, like with a Firestore listener.
///
/// The `patientId` values are placeholders until the format is defined (#8).
/// Delete this class once [patientRepositoryProvider] always uses Firestore.
class DemoPatientRepository implements PatientRepository {
  DemoPatientRepository({
    DateTime? now,
    this.writeDelay = const Duration(milliseconds: 600),
    AppUser? Function()? currentUser,
  }) : _now = now ?? DateTime.now(),
       _currentUser = currentUser ?? (() => null) {
    _current = _initialPatients();
    _history = _initialHistory(_current);
  }

  final DateTime _now;

  /// Who is signed in, recorded as the actor of a transfer.
  final AppUser? Function() _currentUser;

  /// How long a write takes, so the in-flight state can be seen and tried.
  final Duration writeDelay;

  late List<Patient> _current;
  final _changes = StreamController<List<Patient>>.broadcast();

  /// Every transfer, oldest first. Also tells whether an `eventId` was
  /// already applied, so a retry with the same ID changes nothing.
  late List<HistoryEntry> _history;
  final _historyChanges = StreamController<void>.broadcast();

  static const _locations = [
    Location(id: 'er', name: 'Emergency'),
    Location(id: 'ward-a', name: 'Ward A'),
    Location(id: 'ward-b', name: 'Ward B'),
    Location(id: 'radiology', name: 'Radiology'),
    Location(id: 'laboratory', name: 'Laboratory'),
  ];

  @override
  Stream<List<Patient>> watchPatients() async* {
    yield _current;
    yield* _changes.stream;
  }

  @override
  Stream<Patient?> watchPatient(String patientId) => watchPatients().map(
    (list) => list.where((p) => p.patientId == patientId).firstOrNull,
  );

  @override
  Stream<List<Location>> watchLocations() => Stream.value(_locations);

  @override
  Stream<List<HistoryEntry>> watchHistory(String patientId) async* {
    List<HistoryEntry> forPatient() => List.unmodifiable(
      _history.reversed.where((e) => e.patientId == patientId),
    );
    yield forPatient();
    await for (final _ in _historyChanges.stream) {
      yield forPatient();
    }
  }

  @override
  Future<void> changeStatus(String patientId, PatientStatus status) async {
    await Future<void>.delayed(writeDelay);
    final index = _current.indexWhere((p) => p.patientId == patientId);
    if (index == -1) throw StateError('No patient with ID $patientId');

    _replace(index, _current[index].withStatus(status, at: DateTime.now()));
  }

  @override
  Future<void> transferPatient({
    required String patientId,
    required String toLocation,
    required String eventId,
    required int expectedVersion,
  }) async {
    await Future<void>.delayed(writeDelay);
    final index = _current.indexWhere((p) => p.patientId == patientId);
    if (index == -1) throw StateError('No patient with ID $patientId');
    if (!_locations.any((l) => l.id == toLocation)) {
      throw StateError('No location with ID $toLocation');
    }

    // Same order as the Firestore version (docs/schema.md).
    if (_history.any((e) => e.eventId == eventId)) return;
    final patient = _current[index];
    if (patient.version != expectedVersion) throw const TransferConflict();

    final user = _currentUser();
    final at = DateTime.now();
    _history = List.unmodifiable([
      ..._history,
      HistoryEntry(
        eventId: eventId,
        patientId: patientId,
        fromLocation: patient.currentLocation,
        toLocation: toLocation,
        timestamp: at,
        updatedBy: user?.uid ?? 'demo-nurse',
        // AppUser has no display name yet; Firestore copies `displayName`
        // from `users/{uid}`.
        updatedByName: user?.email ?? 'Test Nurse',
      ),
    ]);
    _replace(index, patient.withTransfer(toLocation, at: at));
    _historyChanges.add(null);
  }

  void _replace(int index, Patient patient) {
    final updated = List.of(_current);
    updated[index] = patient;
    _current = List.unmodifiable(updated);
    _changes.add(_current);
  }

  /// One earlier move out of the ER for every patient who is somewhere else
  /// now, so the history screen has something to show. Patients still in
  /// the ER have no history, which shows the empty state.
  static List<HistoryEntry> _initialHistory(List<Patient> patients) =>
      List.unmodifiable([
        for (final p in patients)
          if (p.currentLocation != 'er')
            HistoryEntry(
              eventId: 'demo-${p.patientId}',
              patientId: p.patientId,
              fromLocation: 'er',
              toLocation: p.currentLocation,
              timestamp: p.locationUpdatedAt,
              updatedBy: 'demo-nurse',
              updatedByName: 'Test Nurse',
            ),
      ]);

  List<Patient> _initialPatients() {
    Patient patient(
      int number, {
      required int age,
      required String condition,
      required String location,
      required PatientStatus status,
      required Duration movedAgo,
      Duration admittedAgo = const Duration(days: 2),
    }) {
      final id = number.toString().padLeft(2, '0');
      final movedAt = _now.subtract(movedAgo);
      return Patient(
        patientId: 'HPT-DEMO$id',
        name: 'Test Patient $id',
        age: age,
        condition: condition,
        admissionDate: _now.subtract(admittedAgo),
        currentLocation: location,
        status: status,
        lastUpdated: movedAt,
        locationUpdatedAt: movedAt,
        version: 1,
      );
    }

    // Ordered by name, like the Firestore query.
    return List.unmodifiable([
      patient(
        1,
        age: 54,
        condition: 'Observation',
        location: 'ward-a',
        status: PatientStatus.inTreatment,
        movedAgo: const Duration(minutes: 35),
      ),
      patient(
        2,
        age: 71,
        condition: 'Hip fracture',
        location: 'radiology',
        status: PatientStatus.inTreatment,
        movedAgo: const Duration(minutes: 10),
      ),
      patient(
        3,
        age: 33,
        condition: 'Chest pain',
        location: 'er',
        status: PatientStatus.admitted,
        movedAgo: const Duration(minutes: 5),
        admittedAgo: const Duration(minutes: 5),
      ),
      patient(
        4,
        age: 8,
        condition: 'Appendicitis',
        location: 'ward-b',
        status: PatientStatus.readyForDischarge,
        movedAgo: const Duration(days: 1),
      ),
      patient(
        5,
        age: 46,
        condition: 'Pneumonia',
        location: 'ward-a',
        status: PatientStatus.readyForDischarge,
        movedAgo: const Duration(days: 2),
        admittedAgo: const Duration(days: 5),
      ),
      patient(
        6,
        age: 62,
        condition: 'Blood tests',
        location: 'laboratory',
        status: PatientStatus.inTreatment,
        movedAgo: const Duration(hours: 1),
      ),
      patient(
        7,
        age: 89,
        condition: 'Dehydration',
        location: 'ward-b',
        status: PatientStatus.discharged,
        movedAgo: const Duration(days: 3),
        admittedAgo: const Duration(days: 6),
      ),
      patient(
        8,
        age: 25,
        condition: 'Concussion',
        location: 'er',
        status: PatientStatus.admitted,
        movedAgo: const Duration(minutes: 20),
        admittedAgo: const Duration(minutes: 20),
      ),
    ]);
  }
}
