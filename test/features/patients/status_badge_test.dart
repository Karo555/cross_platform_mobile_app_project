import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patient_tracker/core/theme.dart';
import 'package:patient_tracker/data/models/patient.dart';
import 'package:patient_tracker/features/patients/widgets/status_badge.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      'every status has its own label and icon (${brightness.name})',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(brightness),
            home: Scaffold(
              body: Column(
                children: [
                  for (final status in PatientStatus.values)
                    StatusBadge(status),
                ],
              ),
            ),
          ),
        );

        for (final status in PatientStatus.values) {
          expect(find.text(status.value), findsOneWidget);
        }
        final icons = tester
            .widgetList<Icon>(find.byType(Icon))
            .map((icon) => icon.icon)
            .toSet();
        // Distinct icons, so the status never depends on colour alone.
        expect(icons, hasLength(PatientStatus.values.length));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
      },
    );
  }

  group('PatientStatus.fromValue', () {
    test('reads every stored value', () {
      for (final status in PatientStatus.values) {
        expect(PatientStatus.fromValue(status.value), status);
      }
    });

    test('returns null for unknown or differently written values', () {
      expect(PatientStatus.fromValue('in treatment'), isNull);
      expect(PatientStatus.fromValue('inTreatment'), isNull);
      expect(PatientStatus.fromValue(null), isNull);
    });
  });
}
