import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/location.dart';
import '../models/patient.dart';
import 'demo_patient_repository.dart';

/// Reads patients and locations. Screens use this instead of `cloud_firestore`.
abstract interface class PatientRepository {
  /// All patients, ordered by name. Emits the current list on listen and again
  /// after every change, so no screen needs a manual refresh.
  Stream<List<Patient>> watchPatients();

  /// The places a patient can be in. Read-only for the app.
  Stream<List<Location>> watchLocations();
}

/// Replace [DemoPatientRepository] with the Firestore implementation once it
/// exists. Tests override this provider.
final patientRepositoryProvider = Provider<PatientRepository>(
  (ref) => DemoPatientRepository(),
);

/// All locations, for any screen that shows a location name or lets the user
/// pick one (for example the transfer flow, #21).
final locationsProvider = StreamProvider<List<Location>>(
  (ref) => ref.watch(patientRepositoryProvider).watchLocations(),
);
