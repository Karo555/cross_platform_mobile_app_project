import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patient_tracker/app.dart';
import 'package:patient_tracker/core/connectivity.dart';
import 'package:patient_tracker/core/widgets/offline_banner.dart';
import 'package:patient_tracker/data/repositories/auth_repository.dart';
import 'package:patient_tracker/features/auth/screens/login_screen.dart';

import '../../support/fake_auth_repository.dart';

const _message = 'You are offline. Information may be out of date.';

/// Pumps the banner around a text field, with the online status coming from
/// [status].
Future<void> _pumpBanner(WidgetTester tester, Stream<bool> status) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [isOnlineProvider.overrideWith((ref) => status)],
      child: const MaterialApp(
        home: OfflineBanner(child: Scaffold(body: TextField())),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('isOnlineFrom', () {
    test('is false only when the plugin reports no network', () {
      expect(isOnlineFrom([ConnectivityResult.none]), isFalse);
      expect(isOnlineFrom([ConnectivityResult.wifi]), isTrue);
      expect(isOnlineFrom([ConnectivityResult.mobile]), isTrue);
      expect(
        isOnlineFrom([ConnectivityResult.wifi, ConnectivityResult.vpn]),
        isTrue,
      );
    });
  });

  testWidgets('shows the banner while offline', (tester) async {
    await _pumpBanner(tester, Stream.value(false));

    expect(find.text(_message), findsOneWidget);
  });

  testWidgets('shows no banner while online', (tester) async {
    await _pumpBanner(tester, Stream.value(true));

    expect(find.text(_message), findsNothing);
  });

  testWidgets('shows no banner while the status is unknown', (tester) async {
    await _pumpBanner(tester, const Stream.empty());
    expect(find.text(_message), findsNothing);

    await _pumpBanner(tester, Stream.error(Exception('plugin missing')));
    expect(find.text(_message), findsNothing);
  });

  testWidgets('appears and disappears as the connection changes', (
    tester,
  ) async {
    final status = StreamController<bool>();
    addTearDown(status.close);
    await _pumpBanner(tester, status.stream);

    status.add(false);
    await tester.pumpAndSettle();
    expect(find.text(_message), findsOneWidget);

    status.add(true);
    await tester.pumpAndSettle();
    expect(find.text(_message), findsNothing);
  });

  testWidgets('the screen below keeps its state when the banner toggles', (
    tester,
  ) async {
    final status = StreamController<bool>();
    addTearDown(status.close);
    await _pumpBanner(tester, status.stream);
    await tester.enterText(find.byType(TextField), 'half-typed note');

    status.add(false);
    await tester.pumpAndSettle();
    status.add(true);
    await tester.pumpAndSettle();

    expect(find.text('half-typed note'), findsOneWidget);
  });

  testWidgets('is shown on top of the app, including the login screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          isOnlineProvider.overrideWith((ref) => Stream.value(false)),
        ],
        child: const PatientTrackerApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text(_message), findsOneWidget);
  });
}
