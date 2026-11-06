/// What a signed-in user is allowed to do. Comes from the `role` custom claim
/// of the ID token and is set by a trusted process, never by the app.
enum UserRole {
  nurse('Nurse'),
  doctor('Doctor');

  const UserRole(this.label);

  /// Text shown in the UI.
  final String label;

  /// Returns the role for a custom claim value, or null if it is missing or
  /// unknown, so that an unexpected value never grants access.
  static UserRole? fromClaim(Object? claim) =>
      UserRole.values.asNameMap()[claim];
}

/// The signed-in user.
class AppUser {
  const AppUser({required this.uid, required this.email, required this.role});

  final String uid;
  final String email;

  /// Null when the account has no valid role. Such a user is signed in but
  /// must not reach any patient screen.
  final UserRole? role;
}
