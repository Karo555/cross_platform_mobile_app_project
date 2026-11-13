import 'package:flutter/material.dart';

import '../../../core/date_format.dart';

/// "Last recorded: Ward A · 14:05".
///
/// Says *recorded* because the app only knows where a patient was last
/// transferred to, not where they are right now (#16). Use this wherever a
/// patient's location is shown, so the wording is the same everywhere.
class RecordedLocation extends StatelessWidget {
  const RecordedLocation({
    super.key,
    required this.locationName,
    required this.recordedAt,
  });

  final String locationName;
  final DateTime recordedAt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    final time = formatRecordedTime(context, recordedAt);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.place_outlined, size: 18, color: color),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            'Last recorded: $locationName · $time',
            // Screen readers would read the dot out loud.
            semanticsLabel: 'Last recorded in $locationName at $time',
            style: theme.textTheme.bodyMedium?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}
