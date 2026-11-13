/// A place a patient can be in: a `locations/{locationId}` document.
class Location {
  const Location({required this.id, required this.name});

  /// Stable lowercase slug, for example `ward-a`. Patients and history store
  /// this, not the name.
  final String id;

  /// Display name, for example `Ward A`.
  final String name;
}
