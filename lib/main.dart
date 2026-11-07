import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/firebase/firebase_setup.dart';

Future<void> main() async {
  // Needed because Firebase talks to native code before runApp.
  WidgetsFlutterBinding.ensureInitialized();
  await initFirebase();

  // ProviderScope stores the state of every Riverpod provider in the app.
  runApp(const ProviderScope(child: PatientTrackerApp()));
}
