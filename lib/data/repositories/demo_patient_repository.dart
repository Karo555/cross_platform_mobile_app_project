import '../models/location.dart';
import '../models/patient.dart';
import 'patient_repository.dart';

/// Synthetic patients and locations, so the screens can be built and tried
/// before the Firestore implementation exists. Contains no real data.
///
/// The `patientId` values are placeholders until the format is defined (#8).
/// Delete this class once [patientRepositoryProvider] uses Firestore.
class DemoPatientRepository implements PatientRepository {
  DemoPatientRepository({DateTime? now}) : _now = now ?? DateTime.now();

  final DateTime _now;

  static const _locations = [
    Location(id: 'er', name: 'Emergency'),
    Location(id: 'ward-a', name: 'Ward A'),
    Location(id: 'ward-b', name: 'Ward B'),
    Location(id: 'radiology', name: 'Radiology'),
    Location(id: 'laboratory', name: 'Laboratory'),
  ];

  @override
  Stream<List<Patient>> watchPatients() => Stream.value(_patients());

  @override
  Stream<List<Location>> watchLocations() => Stream.value(_locations);

  List<Patient> _patients() {
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
