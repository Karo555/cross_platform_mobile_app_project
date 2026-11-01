import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The app's router, provided through Riverpod so that later issues can
/// read other providers here (for example auth state for a login redirect).
final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const _PlaceholderHomeScreen(),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

class PatientTrackerApp extends ConsumerWidget {
  const PatientTrackerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Patient Tracker',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal)),
      routerConfig: ref.watch(routerProvider),
    );
  }
}

/// Temporary start screen until real screens are added (login is #11,
/// patient list is #26).
class _PlaceholderHomeScreen extends StatelessWidget {
  const _PlaceholderHomeScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Patient Tracker')),
      body: const Center(child: Text('Patient Tracker')),
    );
  }
}
