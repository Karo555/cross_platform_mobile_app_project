import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/date_format.dart';
import '../../../core/widgets/state_views.dart';
import '../../../data/models/history_entry.dart';
import '../../../data/repositories/patient_repository.dart';
import '../providers.dart';

/// Every transfer of [patientId], newest first (#24). Updates by itself when
/// a new transfer is recorded. Open to nurses and doctors.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key, required this.patientId});

  final String patientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Movement history')),
      body: SafeArea(child: _buildBody(ref)),
    );
  }

  Widget _buildBody(WidgetRef ref) {
    final patient = ref.watch(patientProvider(patientId));
    final history = ref.watch(historyProvider(patientId));
    final locations = ref.watch(locationsProvider);

    if (patient.hasError || history.hasError || locations.hasError) {
      return ErrorState(
        message: 'Could not load the movement history.',
        onRetry: () {
          ref
            ..invalidate(patientProvider(patientId))
            ..invalidate(historyProvider(patientId))
            ..invalidate(locationsProvider);
        },
      );
    }
    final entries = history.value;
    final locationList = locations.value;
    if (!patient.hasValue || entries == null || locationList == null) {
      return const LoadingState(message: 'Loading history...');
    }
    final loaded = patient.value;
    if (loaded == null) {
      return EmptyState(
        title: 'Patient not found',
        message: 'There is no patient with ID $patientId.',
        icon: Icons.person_off_outlined,
      );
    }

    return _HistoryList(
      patientName: loaded.name,
      entries: entries,
      locationNames: {for (final l in locationList) l.id: l.name},
    );
  }
}

class _HistoryList extends StatelessWidget {
  const _HistoryList({
    required this.patientName,
    required this.entries,
    required this.locationNames,
  });

  final String patientName;
  final List<HistoryEntry> entries;
  final Map<String, String> locationNames;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(patientName, style: theme.textTheme.headlineSmall),
    );

    if (entries.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          const Expanded(
            child: EmptyState(
              title: 'No transfers yet',
              message: 'This patient has not been moved since admission.',
              icon: Icons.history,
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      itemCount: entries.length + 1,
      itemBuilder: (context, index) => index == 0
          ? header
          : _HistoryTile(entry: entries[index - 1], names: locationNames),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.entry, required this.names});

  final HistoryEntry entry;
  final Map<String, String> names;

  @override
  Widget build(BuildContext context) {
    // The ID is better than nothing if a location is missing.
    final from = names[entry.fromLocation] ?? entry.fromLocation;
    final to = names[entry.toLocation] ?? entry.toLocation;
    final time = formatRecordedTime(context, entry.timestamp);

    return MergeSemantics(
      child: ListTile(
        leading: const Icon(Icons.swap_horiz),
        title: Text('$from → $to', semanticsLabel: 'From $from to $to'),
        subtitle: Text('$time · ${entry.updatedByName}'),
      ),
    );
  }
}
