# Milestone: scan-to-transfer on both platforms (#25)

The flow from Sec. 7 of the project plan, on iOS and on Android:

> Sign in → scan NFC/QR → open patient → transfer → history entry visible

## What it depends on

| Step | Issue | State |
|---|---|---|
| Sign in | #11 | Done |
| Scan NFC / QR | #13, #14 | Open |
| Scanned ID opens the record | #15 | Open |
| Patient details, live from Firestore | #16 | In progress |
| Transfer UI | #21 | Done |
| Transfer written to Firestore atomically | #22 | Open |
| Movement history | #24 | Done |
| Synthetic data in the emulator | #10 | PR #66 |

Until all of these are done, the milestone can only be shown with the demo
data and without the scan.

## Automated run

`integration_test/scan_to_transfer_test.dart` drives the whole flow in the
real app: sign in as a nurse, open a patient, transfer them, and check that
the transfer is the newest history entry. Until #15 is in, it opens the
patient from the list instead of from a scan.

```bash
# Terminal 1
firebase emulators:start --only auth,firestore

# Terminal 2: once per platform
flutter test integration_test/scan_to_transfer_test.dart -d <ios-device> \
  --dart-define=EMULATOR_HOST=localhost
flutter test integration_test/scan_to_transfer_test.dart -d <android-device> \
  --dart-define=EMULATOR_HOST=10.0.2.2
```

Use the same `EMULATOR_HOST` as for `flutter run` (see the README). Once the
app reads Firestore (#16, #22), seed the emulator (#10) and add
`--dart-define=E2E_PATIENT_ID=<a seeded patientId>`.

## Manual run with recording

The scan needs a real NFC tag or QR code, so the recorded run is by hand, on
a physical phone (#5, #6), using tags and codes from #8.

1. Start the emulators and seed them (#10).
2. Start a screen recording: Control Centre → Screen Recording on iOS;
   `adb shell screenrecord /sdcard/scan-to-transfer.mp4` on Android (stop
   with Ctrl+C, then `adb pull /sdcard/scan-to-transfer.mp4`).
3. Sign in as `nurse1@test.local`.
4. Scan the patient's NFC tag. Repeat once with the QR code.
5. On the patient's record, tap **Transfer patient**, choose a destination,
   and confirm.
6. Check that the record shows the new location, then open
   **Movement history** and check that the transfer is at the top, with the
   nurse's name.
7. Stop the recording.

Keep recordings out of Git: upload them to the team's shared folder and link
them below. They show synthetic data only.

## Results

| Platform | Device | Automated test | Manual run | Recording | Date | By |
|---|---|---|---|---|---|---|
| iOS | | | | | | |
| Android | | | | | | |
