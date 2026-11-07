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
3. `flutter run -d <device id>`

To use the Firebase emulators from a phone, see "Firebase setup" in the README.

## Permissions

Declared in `android/app/src/main/AndroidManifest.xml`:

- `android.permission.NFC`: read NFC wristbands. Granted at install, no prompt.
- `android.permission.CAMERA`: scan QR codes. Android asks the user at runtime (#14).
- `uses-feature` NFC and camera with `required="false"`, so devices without NFC can
  still install the app and use QR instead.
