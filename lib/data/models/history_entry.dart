/// One transfer of a patient: a `patients/{patientId}/history/{eventId}`
/// document. Never changed or deleted once written (#23). See
/// `docs/schema.md` for what each field means.
class HistoryEntry {
  const HistoryEntry({
    required this.eventId,
    required this.patientId,
    required this.fromLocation,
    required this.toLocation,
    required this.timestamp,
    required this.updatedBy,
    required this.updatedByName,
  });

  final String eventId;
  final String patientId;

  /// Document IDs in `locations`, not display names.
  final String fromLocation;
  final String toLocation;

  /// Server time of the transfer.
  final DateTime timestamp;

  /// `uid` of the nurse who made the transfer.
  final String updatedBy;

  /// The nurse's name at the time, copied so the history stays readable
  /// without access to their `users` document.
  final String updatedByName;
}
