import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme.dart';
import 'core/widgets/state_views.dart';
import 'data/models/app_user.dart';
import 'data/repositories/auth_repository.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/no_access_screen.dart';
import 'features/patients/screens/patient_details_screen.dart';
import 'features/patients/screens/patient_list_screen.dart';

const _homeRoute = '/';
const _loadingRoute = '/loading';
const _loginRoute = '/login';
const _noAccessRoute = '/no-access';

/// The single rule that keeps users without a role out of the patient screens.
/// Returns where to go instead of [location], or null to stay.
///
/// New routes are protected automatically: everything except the screens
/// below requires a signed-in user with a valid role.
String? authRedirect(AsyncValue<AppUser?> auth, String location) {
  final required = _requiredRoute(auth);
  if (required != null) return location == required ? null : required;

  const authOnlyRoutes = {_loadingRoute, _loginRoute, _noAccessRoute};
  return authOnlyRoutes.contains(location) ? _homeRoute : null;
}

/// The route the user has to be on, or null if they may use the app.
String? _requiredRoute(AsyncValue<AppUser?> auth) {
  // Checked first: after an error the previous user is still in `auth.value`,
  // and an unknown auth state must not keep the screens open.
  if (auth.hasError) return _loginRoute;
  if (!auth.hasValue) return _loadingRoute;

  final user = auth.value;
  if (user == null) return _loginRoute;
  if (user.role == null) return _noAccessRoute;
  return null;
}

/// The app's router, provided through Riverpod so that it can read other
/// providers, such as the auth state for the login redirect.
final routerProvider = Provider<GoRouter>((ref) {
  // Tells the router to run its redirect again when the auth state changes.
  final auth = ValueNotifier<AsyncValue<AppUser?>>(const AsyncLoading());
  ref.onDispose(auth.dispose);
  ref.listen(
    authStateProvider,
    (_, next) => auth.value = next,
    fireImmediately: true,
  );

  final router = GoRouter(
    initialLocation: _homeRoute,
    refreshListenable: auth,
    redirect: (context, state) =>
        authRedirect(auth.value, state.matchedLocation),
    routes: [
      GoRoute(
        path: _homeRoute,
        builder: (context, state) => const PatientListScreen(),
      ),
      GoRoute(
        path: '/patients/:patientId',
        builder: (context, state) =>
            PatientDetailsScreen(patientId: state.pathParameters['patientId']!),
      ),
      GoRoute(
        path: _loadingRoute,
        builder: (context, state) => const Scaffold(body: LoadingState()),
      ),
      GoRoute(
        path: _loginRoute,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: _noAccessRoute,
        builder: (context, state) => const NoAccessScreen(),
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
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
