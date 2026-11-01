# data/

The only layer that talks to the backend (Firebase Auth and Firestore).

Put here:
- `models/`: plain Dart classes for `Patient`, `LocationEvent`, `AppUser`, `Location`, with `fromFirestore` / `toFirestore`
- `repositories/`: classes that read and write Firestore, for example `PatientRepository` (watch a patient, run the transfer transaction) and `AuthRepository`

Rules:
- Screens never import `cloud_firestore` or `firebase_auth` directly. They go through a repository.
- A transfer writes the patient's location and the history entry in one transaction. Timestamps come from the server, and the actor comes from the logged-in user, never from client input.
- Permissions are enforced by Firestore security rules, not here. This code only reports what the backend allowed or rejected.
