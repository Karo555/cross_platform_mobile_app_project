import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:patient_tracker/app.dart';

void main() {
  testWidgets('App starts on the placeholder home screen', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: PatientTrackerApp()));
    await tester.pumpAndSettle();

    expect(find.byType(AppBar), findsOneWidget);
    expect(find.text('Patient Tracker'), findsNWidgets(2));
  });
}
