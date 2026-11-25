import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/connectivity.dart';
import '../../../data/models/patient.dart';
import '../../../data/repositories/patient_repository.dart';

/// Lets a doctor pick a new status for [patient] and confirm it (#19).
///
/// Returns the new status once the backend has accepted it, or null if the
/// doctor cancelled. While the write is in flight the dialog cannot be closed,
/// and if it fails the dialog stays open with the choice kept, so the doctor
/// can try again.
Future<PatientStatus?> showChangeStatusDialog(
  BuildContext context, {
  required Patient patient,
  required String locationName,
}) => showDialog<PatientStatus>(
  context: context,
  builder: (_) =>
      ChangeStatusDialog(patient: patient, locationName: locationName),
);

class ChangeStatusDialog extends ConsumerStatefulWidget {
  const ChangeStatusDialog({
    super.key,
    required this.patient,
    required this.locationName,
  });

  final Patient patient;
  final String locationName;

  @override
  ConsumerState<ChangeStatusDialog> createState() => _ChangeStatusDialogState();
}

class _ChangeStatusDialogState extends ConsumerState<ChangeStatusDialog> {
  PatientStatus? _selected;
  bool _saving = false;
  bool _failed = false;

  PatientStatus get _current => widget.patient.status;

  Future<void> _confirm(PatientStatus status) async {
    setState(() {
      _saving = true;
      _failed = false;
    });
    try {
      await ref
          .read(patientRepositoryProvider)
          .changeStatus(widget.patient.patientId, status);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _failed = true;
        });
      }
      return;
    }
    if (mounted) Navigator.of(context).pop(status);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final offline = ref.watch(isOnlineProvider).value == false;
    final selected = _selected;
    final canConfirm =
        selected != null && selected != _current && !_saving && !offline;

    return PopScope(
      // Closing mid-write would hide whether the change went through.
      canPop: !_saving,
      child: AlertDialog(
        title: const Text('Change status'),
        // Scrolls instead of overflowing with large text on small screens.
        scrollable: true,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.patient.name} · ${widget.patient.patientId}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            RadioGroup<PatientStatus>(
              groupValue: selected ?? _current,
              onChanged: (status) {
                if (_saving || status == null) return;
                setState(() {
                  _selected = status;
                  _failed = false;
                });
              },
              child: Column(
                children: [
                  for (final status in PatientStatus.values)
                    RadioListTile<PatientStatus>(
                      value: status,
                      enabled: !_saving,
                      contentPadding: EdgeInsets.zero,
                      title: Text(status.value),
                      subtitle: status == _current
                          ? const Text('Current status')
                          : null,
                    ),
                ],
              ),
            ),
            if (selected != null && selected != _current) ...[
              const SizedBox(height: 8),
              Text(
                '${_current.value} → ${selected.value}',
                semanticsLabel: 'From ${_current.value} to ${selected.value}',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              // Discharged is a status, not a place (docs/schema.md).
              Text(
                'The last recorded location (${widget.locationName}) stays '
                'the same.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
            if (offline) ...[
              const SizedBox(height: 12),
              _Notice(
                icon: Icons.cloud_off,
                text: 'You are offline. Connect to change the status.',
                color: colors.onSurfaceVariant,
              ),
            ] else if (_failed) ...[
              const SizedBox(height: 12),
              _Notice(
                icon: Icons.error_outline,
                text: 'The status was not changed. Try again.',
                color: colors.error,
                liveRegion: true,
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: canConfirm ? () => _confirm(selected) : null,
            child: _saving
                ? SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      semanticsLabel: 'Saving',
                      color: colors.onSurface,
                    ),
                  )
                : const Text('Confirm'),
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.text,
    required this.color,
    this.liveRegion = false,
  });

  final IconData icon;
  final String text;
  final Color color;

  /// Announces the text to screen readers as soon as it appears.
  final bool liveRegion;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: liveRegion,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(child: Icon(icon, size: 20, color: color)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
