import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/patient.dart';
import '../../data/repositories/patient_repository.dart';

/// All patients, ordered by name. Updates by itself when any patient changes.
final patientsProvider = StreamProvider<List<Patient>>(
  (ref) => ref.watch(patientRepositoryProvider).watchPatients(),
);
