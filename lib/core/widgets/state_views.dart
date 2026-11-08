import 'package:flutter/material.dart';

/// Full-area views for the three non-data states of a screen.
///
/// They are meant to be used with a Riverpod `AsyncValue`:
///
/// ```dart
/// patients.when(
///   loading: () => const LoadingState(),
///   error: (_, _) => ErrorState(
///     message: 'Could not load patients.',
///     onRetry: () => ref.invalidate(patientsProvider),
///   ),
///   data: (list) => list.isEmpty
///       ? const EmptyState(title: 'No patients found')
///       : PatientList(list),
/// );
/// ```

/// Shown while data is being fetched.
class LoadingState extends StatelessWidget {
  const LoadingState({super.key, this.message});

  /// Optional text below the spinner, for example 'Loading patients...'.
  final String? message;

  @override
  Widget build(BuildContext context) {
    final message = this.message;
    return _StateLayout(
      children: [
        CircularProgressIndicator(semanticsLabel: message ?? 'Loading'),
        if (message != null) ...[
          const SizedBox(height: 16),
          // Excluded because the spinner's label already announces it.
          ExcludeSemantics(child: Text(message, textAlign: TextAlign.center)),
        ],
      ],
    );
  }
}

/// Shown when a request succeeded but there is nothing to display.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.inbox_outlined,
  });

  final String title;
  final String? message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return _StateLayout(
      children: [
        Icon(icon, size: 48, color: colors.onSurfaceVariant),
        const SizedBox(height: 16),
        _Title(title),
        if (message case final message?) _Message(message),
      ],
    );
  }
}

/// Shown when loading failed.
///
/// [message] is displayed to staff, so pass readable text and not a raw
/// exception. Leave [onRetry] null when retrying cannot help, for example when
/// access was denied; the retry button is then hidden.
class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    this.title = 'Something went wrong',
    required this.message,
    this.onRetry,
    this.retryLabel = 'Try again',
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final onRetry = this.onRetry;
    return _StateLayout(
      children: [
        // A live region makes screen readers announce the error when it
        // replaces the content, without the user having to find it.
        Semantics(
          liveRegion: true,
          container: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: colors.error),
              const SizedBox(height: 16),
              _Title(title),
              _Message(message),
            ],
          ),
        ),
        if (onRetry != null) ...[
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: Text(retryLabel),
          ),
        ],
      ],
    );
  }
}

/// Centers the content and lets it scroll, so it does not overflow on small
/// screens or with large system font sizes.
class _StateLayout extends StatelessWidget {
  const _StateLayout({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.titleMedium,
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
