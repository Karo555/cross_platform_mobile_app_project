# Test devices

Physical devices we build and test on. NFC and camera behaviour can only be
verified on real hardware, so record every device here (#5, #6).

| Platform | Device | Model | OS version | NFC | Owner | Verified |
|---|---|---|---|---|---|---|
| Android | Samsung Galaxy S24 | SM-S921B | Android 15 (API 35) | Yes | Akash | 2026-11-08: debug build installs and starts (#6) |
| iOS | iPhone 13 | | | Yes | Karolina | Not yet (#5) |

## Android: run on a phone

1. Turn on Developer options and USB debugging on the phone, then connect it by USB.
2. `flutter devices` should list the phone.
3. Start the emulators (`firebase emulators:start`), forward their ports to the
   phone, and run the app against `localhost`:

   ```sh
   adb reverse tcp:9099 tcp:9099   # Auth emulator
   adb reverse tcp:8080 tcp:8080   # Firestore emulator
   flutter run -d <device id> --dart-define=EMULATOR_HOST=localhost
   ```

   A plain `flutter run` uses the default host `10.0.2.2`, which only works
   from the Android emulator. A phone can't reach it, so every sign-in and
   Firestore call times out. For running over Wi-Fi instead of USB, see
   "Firebase setup" in the README.

## Permissions

Declared in `android/app/src/main/AndroidManifest.xml`:

- `android.permission.NFC`: read NFC wristbands. Granted at install, no prompt.
- `android.permission.CAMERA`: scan QR codes. Android must ask the user at
  runtime. The app doesn't ask yet: the prompt is added in #14, and until then
  the camera can't be used.
- `uses-feature` NFC, camera and camera autofocus with `required="false"`, so
  devices without NFC, a camera or autofocus can still install the app. The
  runtime check that picks NFC or QR is added in #13 and #14.
