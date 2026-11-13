import 'package:flutter/material.dart';

import '../../../data/models/patient.dart';
import 'recorded_location.dart';
import 'status_badge.dart';

/// One row of the patient list: name, status, ID and last recorded location.
///
/// The parts stack and wrap instead of sitting side by side, so long names
/// and large system font sizes never overflow.
class PatientTile extends StatelessWidget {
  const PatientTile({
    super.key,
    required this.patient,
    required this.locationName,
    required this.onTap,
  });

  final Patient patient;
  final String locationName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mutedColor = theme.colorScheme.onSurfaceVariant;

    // Screen readers announce the row as one item instead of four.
    return MergeSemantics(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(patient.name, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        StatusBadge(patient.status),
                        Text(
                          patient.patientId,
                          semanticsLabel: 'ID ${patient.patientId}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: mutedColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    RecordedLocation(
                      locationName: locationName,
                      recordedAt: patient.locationUpdatedAt,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: mutedColor),
            ],
          ),
        ),
      ),
    );
  }
}
