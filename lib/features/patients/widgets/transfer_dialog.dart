import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/connectivity.dart';
import '../../../core/event_id.dart';
import '../../../core/widgets/inline_notice.dart';
import '../../../data/models/location.dart';
import '../../../data/models/patient.dart';
import '../../../data/repositories/patient_repository.dart';

/// Asks the nurse to confirm moving [patient] from [from] to [to] (#21).
///
/// Returns true once the backend has accepted the transfer, or null if the
/// nurse cancelled. While the write is in flight the dialog cannot be closed.
/// If it fails the dialog stays open, so the nurse can try again; retries
/// reuse the same `eventId`, so they cannot move the patient twice (#34).
Future<bool?> showTransferDialog(
  BuildContext context, {
  required Patient patient,
  required Location from,
  required Location to,
}) => showDialog<bool>(
  context: context,
  builder: (_) => TransferDialog(patient: patient, from: from, to: to),
);

class TransferDialog extends ConsumerStatefulWidget {
  const TransferDialog({
    super.key,
    required this.patient,
    required this.from,
    required this.to,
  });

  final Patient patient;
  final Location from;
  final Location to;

  @override
  ConsumerState<TransferDialog> createState() => _TransferDialogState();
}

enum _Failure { retryable, conflict }

class _TransferDialogState extends ConsumerState<TransferDialog> {
  /// One ID for this transfer, however often the nurse retries it.
  final _eventId = newEventId();
  bool _saving = false;
  _Failure? _failure;

  Future<void> _confirm() async {
    setState(() {
      _saving = true;
      _failure = null;
    });
    try {
      await ref
          .read(patientRepositoryProvider)
          .transferPatient(
            patientId: widget.patient.patientId,
            toLocation: widget.to.id,
            eventId: _eventId,
            // The version the nurse is looking at, not the latest one: if
            // someone else changed the patient meanwhile, this must fail.
            expectedVersion: widget.patient.version,
          );
    } on TransferConflict {
      _fail(_Failure.conflict);
      return;
    } catch (_) {
      _fail(_Failure.retryable);
      return;
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  void _fail(_Failure failure) {
    if (!mounted) return;
    setState(() {
      _saving = false;
      _failure = failure;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final offline = ref.watch(isOnlineProvider).value == false;
    final conflict = _failure == _Failure.conflict;
    final canConfirm = !_saving && !offline && !conflict;

    return PopScope(
      // Closing mid-write would hide whether the transfer went through.
      canPop: !_saving,
      child: AlertDialog(
        title: const Text('Confirm transfer'),
        scrollable: true,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.patient.name, style: theme.textTheme.titleMedium),
            Text(
              widget.patient.patientId,
              semanticsLabel: 'ID ${widget.patient.patientId}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            MergeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Place(label: 'From', name: widget.from.name),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: ExcludeSemantics(
                      child: Icon(Icons.arrow_downward, color: colors.primary),
                    ),
                  ),
                  _Place(label: 'To', name: widget.to.name),
                ],
              ),
            ),
            if (offline) ...[
              const SizedBox(height: 16),
              InlineNotice(
                icon: Icons.cloud_off,
                text: 'You are offline. Connect to transfer the patient.',
                color: colors.onSurfaceVariant,
              ),
            ] else if (_failure != null) ...[
              const SizedBox(height: 16),
              InlineNotice(
                icon: Icons.error_outline,
                text: conflict
                    // Retrying cannot help: the "From" shown here is out of
                    // date.
                    ? 'This patient was changed by someone else in the '
                          'meantime, so they were not transferred. Go back '
                          'and check where they are now.'
                    : 'The patient was not transferred. Try again.',
                color: colors.error,
                liveRegion: true,
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            child: Text(conflict ? 'Close' : 'Cancel'),
          ),
          if (!conflict)
            FilledButton(
              onPressed: canConfirm ? _confirm : null,
              child: _saving
                  ? SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        semanticsLabel: 'Saving',
                        color: colors.onSurface,
                      ),
                    )
                  : const Text('Transfer'),
            ),
        ],
      ),
    );
  }
}

/// "From" or "To" above a location name, read as one item.
class _Place extends StatelessWidget {
  const _Place({required this.label, required this.name});

  final String label;
  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(name, style: theme.textTheme.titleLarge),
      ],
    );
  }
}
