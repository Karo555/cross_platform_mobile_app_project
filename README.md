# cross_platform_mobile_app_project
CPMA project winter 2026/27
Hospital Patient Tracking System - CPMA project

## Minimum platform versions

| Platform | Minimum | Where it is set |
|---|---|---|
| Android | API 24 (Android 7.0) | `minSdk` in `android/app/build.gradle.kts` |
| iOS | 15.0 | `IPHONEOS_DEPLOYMENT_TARGET` in `ios/Runner.xcodeproj/project.pbxproj` |

These are the lowest versions Flutter 3.47 supports. Both are pinned explicitly so that upgrading Flutter cannot change them without anyone noticing. If a plugin we add later (Firebase, NFC) needs a higher minimum, raise it here and in the file listed above.

## Architecture

### Folder layout

```
lib/
  main.dart   starts the app inside a Riverpod ProviderScope
  app.dart    MaterialApp + the go_router routes
  core/       shared, non-Firebase code (theme, constants, helpers)
  data/       models + repositories; the only code that talks to Firebase
  features/   one folder per feature (auth, scan, patients, transfer, history)
```

Each folder has its own `README.md` saying what belongs there. Create a feature folder when you start its issue.

### State management: Riverpod

We use [`flutter_riverpod`](https://pub.dev/packages/flutter_riverpod), without code generation.
- Firestore live updates map directly onto a `StreamProvider`, which we need for live sync between devices.
- Tests can replace a repository with a fake through `ProviderScope(overrides: ...)`, so they don't need Firebase.
- Widgets read state with `ref.watch(...)` in a `ConsumerWidget`.

### Routing: go_router

We use [`go_router`](https://pub.dev/packages/go_router), maintained by the Flutter team.
- Routes are paths, for example `/patients/:patientId`, which fits "scan a wristband, open that patient".
- The router is created in `routerProvider` (`lib/app.dart`). It can read other providers, so the login redirect is one central rule instead of a check on every screen.

## Development

### Run the app locally

Debug builds talk to the local Firebase emulators. `flutter run` does not start them, so use two terminals. Do the [Firebase setup](#firebase-setup-4) once first.

1. Terminal 1, keep it running: `firebase emulators:start --only auth,firestore`
2. Terminal 2: `flutter pub get`, then `flutter devices` to find the device ID.
3. Terminal 2: `flutter run -d <device-id>` with the `EMULATOR_HOST` for that device, from the table in [Point the app at the emulators](#point-the-app-at-the-emulators). A bare `flutter run` uses `10.0.2.2`, which only works from an Android emulator.

`--dart-define` values are fixed at build time, so restart the app after changing one; hot reload keeps the old value. In VS Code, `.vscode/launch.json` has a ready-made configuration for each target.

The Auth emulator starts empty and the app has no sign-up screen. To create a test account, run the end-to-end tests once with the same `EMULATOR_HOST` as the app (see [End-to-end tests](#end-to-end-tests)). They create `e2e-nurse@test.local` with password `test1234` and the `nurse` role. These exist only in the local emulator. An account you create yourself in the Emulator UI also needs a `role` custom claim (`nurse` or `doctor`), or it stops at the "no access" screen.

### Checks

```bash
flutter analyze        # must report no issues (CI fails otherwise)
flutter test           # must pass (CI runs this too)
```

The lint rules in `analysis_options.yaml` are stricter than the Flutter defaults, for example `unawaited_futures` and `strict-casts`. The project-specific ones have a comment saying why. Even "info" findings fail `flutter analyze`, so run it before every push.

### End-to-end tests

`integration_test/` runs the real app against the Auth emulator on a simulator or phone. It creates its own test accounts. CI does not run it, because it needs a device.

```bash
firebase emulators:start --only auth
flutter test integration_test --dart-define=EMULATOR_HOST=YOUR_EMULATOR_HOST
```

Replace `YOUR_EMULATOR_HOST` with the same value as for `flutter run` (see the table under [Point the app at the emulators](#point-the-app-at-the-emulators)).

## Firebase setup (#4)

Firebase project: `patient-tracker-cpma` (Spark plan). During development the app talks to the **local Firebase Emulator Suite**, never to real data.

### One-time install
1. [Node.js](https://nodejs.org) (LTS), then `npm install -g firebase-tools`
2. Java JDK 21 (the Firestore emulator needs it): `java -version` must work
3. `firebase login` (ask Akash to add you to the project)
4. FlutterFire CLI: `dart pub global activate flutterfire_cli`
5. `cd functions` then `npm install`

On Windows, if PowerShell says running scripts is disabled, use `firebase.cmd` instead of `firebase`.

### Generate the config files (not committed)
`lib/firebase_options.dart`, `android/app/google-services.json` and `ios/Runner/GoogleService-Info.plist` are gitignored. Generate them once:

```bash
flutterfire configure --project=patient-tracker-cpma --platforms=android,ios,web --android-package-name=com.cpma.patient_tracker --ios-bundle-id=com.cpma.patientTracker --yes
```

If your copy of `lib/firebase_options.dart` was generated before web support was added (#68), run the command again. Otherwise the app throws `UnsupportedError` in the browser.

The iOS plist is only written on a Mac. CI uses the fake `lib/firebase_options.example.dart` instead (see `.github/workflows/ci.yml`).

### Run the emulators
```bash
firebase emulators:start --only auth,firestore
```
Auth `9099`, Firestore `8080`, Emulator UI at http://localhost:4000. Rules come from `firestore.rules`. Run `firebase emulators:start` without `--only` if you also need the Functions emulator (`5001`).

### Point the app at the emulators
Debug builds use the emulators automatically (`lib/data/firebase/firebase_setup.dart`). Tell the app where your PC is:

| Device | Command |
|---|---|
| Android emulator | `flutter run` (default host `10.0.2.2`) |
| Android phone over USB | `adb reverse tcp:9099 tcp:9099` and `adb reverse tcp:8080 tcp:8080`, then `flutter run --dart-define=EMULATOR_HOST=localhost` |
| Phone over Wi-Fi | `flutter run --dart-define=EMULATOR_HOST=<your PC's IP>` (firewall must allow ports 8080/9099) |
| iOS simulator | `flutter run --dart-define=EMULATOR_HOST=localhost`. The flag is required: the simulator cannot reach `10.0.2.2` |
| Web (Chrome) | `flutter run -d chrome --dart-define=EMULATOR_HOST=localhost`. The flag is required, because the browser cannot reach `10.0.2.2`. Without Chrome, use `-d web-server --web-port 8000` and open http://localhost:8000 in any browser |

Add `-d <device-id>` when more than one device is connected. A phone over Wi-Fi must be on the same network as the PC.

If the login screen says **"No connection. Check your network and try again."**:
1. Check that `firebase emulators:start --only auth,firestore` is still running.
2. Check that `EMULATOR_HOST` matches the device, as in the table above.
3. Over Wi-Fi, check that the firewall lets the phone reach ports `9099` and `8080` on the PC.

Add `--dart-define=USE_EMULATOR=false` only to use the real Firebase project on purpose. It needs a network connection and a real account in the project.
