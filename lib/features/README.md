# features/

One folder per feature. Each person mostly works inside their own feature folder, which keeps merge conflicts small.

Planned folders (create a folder when you start its issue):

| Folder | What it contains | Issues |
|---|---|---|
| `auth/` | login screen, sign-out | #11 |
| `scan/` | NFC and QR scanning, `patientId` lookup | #13, #14, #15 |
| `patients/` | patient list, search/filter, patient details | #16, #26, #27 |
| `transfer/` | transfer screen and confirmation | #21, #22 |
| `history/` | movement history screen | #24 |

Inside a feature folder, use `screens/`, `widgets/` and a `providers.dart` file for that feature's Riverpod providers.
A feature may import from `core/` and `data/`, but not from another feature's folder.
