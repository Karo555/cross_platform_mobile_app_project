import 'package:flutter/material.dart';

import '../../../data/models/patient.dart';

/// A patient's status as a small label with an icon. The icon and the text
/// carry the meaning, so the badge still works for colour-blind users and in
/// greyscale; the colour only helps scanning the list.
class StatusBadge extends StatelessWidget {
  const StatusBadge(this.status, {super.key});

  final PatientStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final (icon, background, foreground) = switch (status) {
      PatientStatus.admitted => (
        Icons.login,
        colors.secondaryContainer,
        colors.onSecondaryContainer,
      ),
      PatientStatus.inTreatment => (
        Icons.healing_outlined,
        colors.primaryContainer,
        colors.onPrimaryContainer,
      ),
      PatientStatus.readyForDischarge => (
        Icons.task_alt,
        colors.tertiaryContainer,
        colors.onTertiaryContainer,
      ),
      PatientStatus.discharged => (
        Icons.logout,
        colors.surfaceContainerHighest,
        colors.onSurfaceVariant,
      ),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: foreground),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                status.value,
                style: theme.textTheme.labelLarge?.copyWith(color: foreground),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
