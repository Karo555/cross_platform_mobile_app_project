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

```bash
flutter pub get        # install packages
flutter analyze        # must report no issues (CI fails otherwise)
flutter test           # must pass (CI runs this too)
flutter run            # run on a connected device or emulator
```

The lint rules in `analysis_options.yaml` are stricter than the Flutter defaults, for example `unawaited_futures` and `strict-casts`. The project-specific ones have a comment saying why. Even "info" findings fail `flutter analyze`, so run it before every push.
