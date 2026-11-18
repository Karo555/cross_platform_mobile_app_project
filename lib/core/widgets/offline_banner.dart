import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../connectivity.dart';

/// Shows a banner above [child] while the device is offline (#30).
///
/// Placed once around the whole app in `MaterialApp.builder`, so every screen
/// gets it, including the login screen. The widget tree has the same shape
/// whether the banner is shown or not, so the screens below keep their state
/// (scroll position, text typed into a form) when the connection changes.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // While the status is still loading, or the check failed, show nothing:
    // a banner that flashes on every app start would teach users to ignore it.
    final offline = ref.watch(isOnlineProvider).value == false;

    return Column(
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.topCenter,
          child: offline
              ? const _Banner()
              : const SizedBox(width: double.infinity),
        ),
        Expanded(
          // The banner already keeps clear of the status bar, so the screen
          // below must not add that space a second time.
          child: MediaQuery.removePadding(
            context: context,
            removeTop: offline,
            child: child,
          ),
        ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Semantics(
      liveRegion: true,
      container: true,
      child: Material(
        color: colors.errorContainer,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(
                  Icons.cloud_off_outlined,
                  size: 20,
                  color: colors.onErrorContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'You are offline. Information may be out of date.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
