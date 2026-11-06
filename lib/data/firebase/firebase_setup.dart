import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';

/// Where the Firebase Emulator Suite runs, as seen from the device.
///
/// Set it with `--dart-define=EMULATOR_HOST=<address>`:
/// - Android emulator: `10.0.2.2` (the default), which is the PC from inside
///   the emulator
/// - Physical phone: the PC's Wi-Fi IP address, for example `192.168.1.20`
/// - iOS simulator: `localhost`
const _emulatorHost = String.fromEnvironment(
  'EMULATOR_HOST',
  defaultValue: '10.0.2.2',
);

/// Set `--dart-define=USE_EMULATOR=false` to use the real Firebase project
/// from a debug build. Release builds never use the emulator.
const _useEmulator = bool.fromEnvironment('USE_EMULATOR', defaultValue: true);

/// Connects the app to Firebase. Must finish before `runApp`.
///
/// Debug builds talk to the local Emulator Suite, so development never
/// touches real data. The ports match `firebase.json`.
Future<void> initFirebase() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (kDebugMode && _useEmulator) {
    await FirebaseAuth.instance.useAuthEmulator(_emulatorHost, 9099);
    FirebaseFirestore.instance.useFirestoreEmulator(_emulatorHost, 8080);
  }
}
