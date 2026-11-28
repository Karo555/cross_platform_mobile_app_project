import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/history_entry.dart';
import '../models/location.dart';
import '../models/patient.dart';
import 'patient_repository.dart';

/// [PatientRepository] backed by Cloud Firestore, using the collections in
/// `docs/schema.md`.
///
/// Every `watch` method is a snapshot listener, so a change made on another
/// device reaches every open screen without a refresh (#16). The listener
/// stops when the stream's subscription is cancelled, which the
/// `autoDispose` providers do once no screen shows the data any more.
///
/// Writes run as transactions. A transaction needs the server, so a write
/// made offline fails instead of being queued (#32). It also means that
/// snapshots never carry a server timestamp that is still pending, so every
/// timestamp field can be read as required.
class FirestorePatientRepository implements PatientRepository {
  FirestorePatientRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _patients =>
      _db.collection('patients');

  @override
  Stream<List<Patient>> watchPatients() => _patients
      .orderBy('name')
      .snapshots()
      .map(
        (snapshot) => List.unmodifiable(
          // A malformed document is left out instead of failing the whole
          // list: one bad record must not hide every other patient.
          snapshot.docs.map(_patientOrNull).nonNulls,
        ),
      );

  @override
  Stream<Patient?> watchPatient(String patientId) {
    // An ID with a slash would address a different document, so it cannot
    // be a patient. Scanned IDs are validated in #15; this guards the route.
    if (patientId.isEmpty || patientId.contains('/')) {
      return Stream.value(null);
    }
    return _patients
        .doc(patientId)
        .snapshots()
        // Here a malformed document is an error, so the screen says it could
        // not load the patient instead of showing wrong data.
        .map((doc) => doc.exists ? patientFromFirestore(doc) : null);
  }

  @override
  Stream<List<Location>> watchLocations() => _db
      .collection('locations')
      .snapshots()
      .map(
        (snapshot) => List.unmodifiable(
          // Sorted here rather than in the query, so it needs no index
          // (docs/schema.md, Indexes).
          snapshot.docs.map(locationFromFirestore).toList()
            ..sort((a, b) => a.name.compareTo(b.name)),
        ),
      );

  @override
  Stream<List<HistoryEntry>> watchHistory(String patientId) {
    if (patientId.isEmpty || patientId.contains('/')) {
      return Stream.value(const []);
    }
    return _patients
        .doc(patientId)
        .collection('history')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              List.unmodifiable(snapshot.docs.map(historyEntryFromFirestore)),
        );
  }

  @override
  Future<void> changeStatus(String patientId, PatientStatus status) {
    final ref = _patients.doc(patientId);
    return _db.runTransaction((transaction) async {
      final doc = await transaction.get(ref);
      if (!doc.exists) throw StateError('No patient with ID $patientId');
      final version = doc.data()?['version'];
      if (version is! int) {
        throw FormatException('Patient $patientId has no valid version');
      }
      // The fields listed for a status change in docs/schema.md. The
      // location and locationUpdatedAt stay as they are.
      transaction.update(ref, {
        'status': status.value,
        'lastUpdated': FieldValue.serverTimestamp(),
        'version': version + 1,
      });
    });
  }

  /// Not implemented yet: the transfer write is #22, which also decides
  /// between a client transaction and a callable Cloud Function.
  @override
  Future<void> transferPatient({
    required String patientId,
    required String toLocation,
    required String eventId,
    required int expectedVersion,
  }) => Future.error(
    UnimplementedError('Transfers on Firestore are added in #22'),
  );
}

/// Reads a `patients/{patientId}` document. Throws [FormatException] if a
/// required field is missing or has the wrong type.
@visibleForTesting
Patient patientFromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data() ?? const {};
  final status = PatientStatus.fromValue(data['status']);
  if (status == null) {
    throw FormatException(
      'Patient ${doc.id} has unknown status',
      data['status'],
    );
  }
  return Patient(
    patientId: doc.id,
    name: _field<String>(doc, 'name'),
    age: _field<int>(doc, 'age'),
    condition: _field<String>(doc, 'condition'),
    admissionDate: _field<Timestamp>(doc, 'admissionDate').toDate(),
    currentLocation: _field<String>(doc, 'currentLocation'),
    status: status,
    lastUpdated: _field<Timestamp>(doc, 'lastUpdated').toDate(),
    locationUpdatedAt: _field<Timestamp>(doc, 'locationUpdatedAt').toDate(),
    version: _field<int>(doc, 'version'),
  );
}

/// Reads a `locations/{locationId}` document.
@visibleForTesting
Location locationFromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) =>
    Location(id: doc.id, name: _field<String>(doc, 'name'));

/// Reads a `patients/{patientId}/history/{eventId}` document.
@visibleForTesting
HistoryEntry historyEntryFromFirestore(
  DocumentSnapshot<Map<String, dynamic>> doc,
) => HistoryEntry(
  eventId: doc.id,
  patientId: _field<String>(doc, 'patientId'),
  fromLocation: _field<String>(doc, 'fromLocation'),
  toLocation: _field<String>(doc, 'toLocation'),
  timestamp: _field<Timestamp>(doc, 'timestamp').toDate(),
  updatedBy: _field<String>(doc, 'updatedBy'),
  updatedByName: _field<String>(doc, 'updatedByName'),
);

Patient? _patientOrNull(DocumentSnapshot<Map<String, dynamic>> doc) {
  try {
    return patientFromFirestore(doc);
  } on FormatException catch (e) {
    debugPrint('Skipping malformed patient ${doc.id}: $e');
    return null;
  }
}

T _field<T>(DocumentSnapshot<Map<String, dynamic>> doc, String name) {
  final value = doc.data()?[name];
  if (value is T) return value;
  throw FormatException(
    '${doc.reference.path} has no valid $name (expected $T)',
    value,
  );
}
