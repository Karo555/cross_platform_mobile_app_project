import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/history_entry.dart';
import '../models/location.dart';
import '../models/patient.dart';
import 'auth_repository.dart';
import 'demo_patient_repository.dart';

/// Reads patients and locations. Screens use this instead of `cloud_firestore`.
abstract interface class PatientRepository {
  /// All patients, ordered by name. Emits the current list on listen and again
  /// after every change, so no screen needs a manual refresh.
  Stream<List<Patient>> watchPatients();

  /// One patient. Emits on listen and after every change, and emits null if
  /// no patient has this ID.
  Stream<Patient?> watchPatient(String patientId);

  /// The places a patient can be in. Read-only for the app.
  Stream<List<Location>> watchLocations();

  /// One patient's transfers, newest first (#24). Emits on listen and again
  /// after every new transfer. Empty if the patient was never transferred.
  Stream<List<HistoryEntry>> watchHistory(String patientId);

  /// Sets the patient's status (doctors only, #19). Changes `status`,
  /// `lastUpdated` and `version`; the location and `locationUpdatedAt` stay
  /// as they are, also for [PatientStatus.discharged].
  ///
  /// Completes only once the backend has accepted the write, and throws if it
  /// did not. It must not queue the write for later, so the Firestore
  /// version uses a transaction, which fails instead of waiting offline.
  Future<void> changeStatus(String patientId, PatientStatus status);

  /// Moves the patient to [toLocation] (nurses only, #21). Changes
  /// `currentLocation`, `locationUpdatedAt`, `lastUpdated` and `version`, and
  /// adds a history entry in the same atomic write (#22).
  ///
  /// [eventId] identifies this one transfer: pass the same ID when retrying,
  /// so a retry after a lost response does not move the patient twice (#34).
  /// [expectedVersion] is the `version` the nurse saw when confirming; if the
  /// patient has changed since, this throws [TransferConflict] and writes
  /// nothing (#35). The checks run in the order listed in `docs/schema.md`.
  ///
  /// Like [changeStatus], completes only once the backend has accepted the
  /// write, and never queues it offline.
  Future<void> transferPatient({
    required String patientId,
    required String toLocation,
    required String eventId,
    required int expectedVersion,
  });
}

/// Thrown by [PatientRepository.transferPatient] when the patient changed
/// after the nurse confirmed, for example because someone else moved them
/// first. Nothing was written.
class TransferConflict implements Exception {
  const TransferConflict();

  @override
  String toString() => 'TransferConflict: the patient changed meanwhile';
}

/// Replace [DemoPatientRepository] with the Firestore implementation once it
/// exists. Tests override this provider.
final patientRepositoryProvider = Provider<PatientRepository>(
  (ref) => DemoPatientRepository(
    // Who made a transfer, for the history. Firestore takes it from the
    // signed-in user's token instead.
    currentUser: () => ref.read(authStateProvider).value,
  ),
);

/// All locations, for any screen that shows a location name or lets the user
/// pick one (for example the transfer flow, #21).
final locationsProvider = StreamProvider<List<Location>>(
  (ref) => ref.watch(patientRepositoryProvider).watchLocations(),
);
