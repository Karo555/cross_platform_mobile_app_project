import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patient_tracker/core/date_format.dart';
import 'package:patient_tracker/core/widgets/today.dart';

/// Shows [time] as formatted below a [Today].
Widget _recordedAt(DateTime time) => MaterialApp(
  home: Today(
    child: Builder(
      builder: (context) => Text(formatRecordedTime(context, time)),
    ),
  ),
);

/// How long until just after the next local midnight.
Duration _pastMidnight() {
  final now = clock.now();
  return DateTime(now.year, now.month, now.day + 1).difference(now) +
      const Duration(seconds: 1);
}

void main() {
  testWidgets('a time from today says "Yesterday" once midnight passes', (
    tester,
  ) async {
    await tester.pumpWidget(_recordedAt(clock.now()));
    expect(find.textContaining('Yesterday'), findsNothing);

    await tester.pump(_pastMidnight());

    expect(find.textContaining('Yesterday'), findsOneWidget);
  });

  testWidgets('keeps updating on the nights after', (tester) async {
    await tester.pumpWidget(_recordedAt(clock.now()));

    await tester.pump(_pastMidnight());
    await tester.pump(_pastMidnight());

    // Two days ago shows the date instead.
    expect(find.textContaining('Yesterday'), findsNothing);
    expect(find.textContaining(','), findsOneWidget);
  });

  testWidgets('without a Today above, falls back to the clock', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Text(
            formatRecordedTime(
              context,
              clock.now().subtract(const Duration(days: 1)),
            ),
          ),
        ),
      ),
    );

    expect(find.textContaining('Yesterday'), findsOneWidget);
  });
}
