import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patient_tracker/core/date_format.dart';

/// Formats [time] as seen at [now], with the device set to 24- or 12-hour.
Future<String> _format(
  WidgetTester tester,
  DateTime time, {
  required DateTime now,
  bool use24Hour = true,
}) async {
  late String result;
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(alwaysUse24HourFormat: use24Hour),
      child: MaterialApp(
        home: Builder(
          builder: (context) {
            result = formatRecordedTime(context, time, now: now);
            return const SizedBox();
          },
        ),
      ),
    ),
  );
  return result;
}

void main() {
  final now = DateTime(2026, 11, 8, 9, 30);

  testWidgets('today shows only the time', (tester) async {
    expect(
      await _format(tester, DateTime(2026, 11, 8, 0, 5), now: now),
      '00:05',
    );
  });

  testWidgets('yesterday says so', (tester) async {
    expect(
      await _format(tester, DateTime(2026, 11, 7, 23, 55), now: now),
      'Yesterday, 23:55',
    );
  });

  testWidgets('earlier days show the date', (tester) async {
    expect(
      await _format(tester, DateTime(2026, 11, 3, 14, 5), now: now),
      'Nov 3, 14:05',
    );
  });

  testWidgets('a time slightly in the future counts as today', (tester) async {
    expect(
      await _format(tester, DateTime(2026, 11, 8, 9, 31), now: now),
      '09:31',
    );
  });

  testWidgets('follows the 12-hour setting', (tester) async {
    expect(
      await _format(
        tester,
        DateTime(2026, 11, 8, 14, 5),
        now: DateTime(2026, 11, 8, 15),
        use24Hour: false,
      ),
      '2:05 PM',
    );
  });
}
