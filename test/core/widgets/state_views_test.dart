import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patient_tracker/core/widgets/state_views.dart';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('LoadingState', () {
    testWidgets('shows a spinner without text by default', (tester) async {
      await tester.pumpWidget(_host(const LoadingState()));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('shows the optional message', (tester) async {
      await tester.pumpWidget(_host(const LoadingState(message: 'Loading...')));

      expect(find.text('Loading...'), findsOneWidget);
    });
  });

  group('EmptyState', () {
    testWidgets('shows title, message and icon', (tester) async {
      await tester.pumpWidget(
        _host(
          const EmptyState(
            title: 'No transfers yet',
            message: 'Transfers will appear here.',
            icon: Icons.history,
          ),
        ),
      );

      expect(find.text('No transfers yet'), findsOneWidget);
      expect(find.text('Transfers will appear here.'), findsOneWidget);
      expect(find.byIcon(Icons.history), findsOneWidget);
    });
  });

  group('ErrorState', () {
    testWidgets('calls onRetry when the button is tapped', (tester) async {
      var retries = 0;
      await tester.pumpWidget(
        _host(ErrorState(message: 'Could not load.', onRetry: () => retries++)),
      );

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text('Could not load.'), findsOneWidget);

      await tester.tap(find.text('Try again'));
      expect(retries, 1);
    });

    testWidgets('hides the button without onRetry', (tester) async {
      await tester.pumpWidget(_host(const ErrorState(message: 'Denied.')));

      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('announces the error to screen readers', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_host(const ErrorState(message: 'Denied.')));

      final node = tester.getSemantics(find.text('Denied.'));
      expect(node.getSemanticsData().flagsCollection.isLiveRegion, isTrue);
      handle.dispose();
    });

    testWidgets('retry button meets tap target guidelines', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(ErrorState(message: 'Could not load.', onRetry: () {})),
      );

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      handle.dispose();
    });
  });

  testWidgets('does not overflow on a small screen with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(320, 480),
          textScaler: TextScaler.linear(3),
        ),
        child: _host(
          ErrorState(
            message: 'Could not load the patient list. ' * 8,
            onRetry: () {},
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
