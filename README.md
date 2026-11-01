# cross_platform_mobile_app_project
CPMA project winter 2026/27
Hospital Patient Tracking System - CPMA project

## Minimum platform versions

| Platform | Minimum | Where it is set |
|---|---|---|
| Android | API 24 (Android 7.0) | `minSdk` in `android/app/build.gradle.kts` |
| iOS | 15.0 | `IPHONEOS_DEPLOYMENT_TARGET` in `ios/Runner.xcodeproj/project.pbxproj` |

These are the lowest versions Flutter 3.47 supports. Both are pinned explicitly so that upgrading Flutter cannot change them without anyone noticing. If a plugin we add later (Firebase, NFC) needs a higher minimum, raise it here and in the file listed above.
