import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/state_views.dart';
import '../../../data/repositories/auth_repository.dart';

/// For an account that signed in but has no valid role. Without a role it
/// cannot use any patient screen, so signing out is the only action.
class NoAccessScreen extends ConsumerWidget {
  const NoAccessScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: ErrorState(
          title: 'No access',
          message:
              'Your account has no role assigned. Contact your administrator.',
          retryLabel: 'Sign out',
          onRetry: () => ref.read(authRepositoryProvider).signOut(),
        ),
      ),
    );
  }
}
