/// Where a patient is in their stay. Separate from the location: a discharged
/// patient keeps their last recorded location.
enum PatientStatus {
  admitted('Admitted'),
  inTreatment('In Treatment'),
  readyForDischarge('Ready for Discharge'),
  discharged('Discharged');

  const PatientStatus(this.value);

  /// Stored in Firestore exactly like this, and also the text shown in the UI.
  final String value;

  /// Returns the status for a stored value, or null if it is missing or
  /// unknown.
  static PatientStatus? fromValue(Object? value) {
    for (final status in values) {
      if (status.value == value) return status;
    }
    return null;
  }
}

/// The current state of one patient: a `patients/{patientId}` document.
/// See `docs/schema.md` for what each field means.
class Patient {
  const Patient({
    required this.patientId,
    required this.name,
    required this.age,
    required this.condition,
    required this.admissionDate,
    required this.currentLocation,
    required this.status,
    required this.lastUpdated,
    required this.locationUpdatedAt,
    required this.version,
  });

  final String patientId;
  final String name;
  final int age;
  final String condition;
  final DateTime admissionDate;

  /// Document ID in `locations`, not a display name. Look up the name to show
  /// it.
  final String currentLocation;
  final PatientStatus status;

  /// Last change of any kind.
  final DateTime lastUpdated;

  /// When [currentLocation] last changed. A status change does not touch it.
  final DateTime locationUpdatedAt;

  /// Goes up by 1 on every transfer and status change (#35).
  final int version;
}
