import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/date_format.dart';
import '../../../core/widgets/state_views.dart';
import '../../../data/models/app_user.dart';
import '../../../data/models/location.dart';
import '../../../data/models/patient.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/patient_repository.dart';
import '../providers.dart';
import '../widgets/status_badge.dart';

/// One patient: status, last recorded location and admission details, with
/// the action the signed-in role may take. Updates by itself when the patient
/// changes (#16).
class PatientDetailsScreen extends ConsumerWidget {
  const PatientDetailsScreen({super.key, required this.patientId});

  final String patientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patient = ref.watch(patientProvider(patientId));
    final locations = ref.watch(locationsProvider);
    final role = ref.watch(authStateProvider).value?.role;

    final loaded = patient.value;
    return Scaffold(
      appBar: AppBar(title: Text(loaded?.name ?? 'Patient')),
      body: SafeArea(
        child: _buildBody(ref, patient: patient, locations: locations),
      ),
      bottomNavigationBar: loaded == null || role == null
          ? null
          : _ActionBar(role: role),
    );
  }

  Widget _buildBody(
    WidgetRef ref, {
    required AsyncValue<Patient?> patient,
    required AsyncValue<List<Location>> locations,
  }) {
    // Checked first: after an error the previous data is still readable, and
    // showing it without a warning would look up to date.
    if (patient.hasError || locations.hasError) {
      return ErrorState(
        message: 'Could not load this patient.',
        onRetry: () {
          ref
            ..invalidate(patientProvider(patientId))
            ..invalidate(locationsProvider);
        },
      );
    }
    final locationList = locations.value;
    if (!patient.hasValue || locationList == null) {
      return const LoadingState(message: 'Loading patient...');
    }

    final loaded = patient.value;
    if (loaded == null) {
      return EmptyState(
        title: 'Patient not found',
        message: 'There is no patient with ID $patientId.',
        icon: Icons.person_off_outlined,
      );
    }

    final locationName =
        locationList
            .where((l) => l.id == loaded.currentLocation)
            .firstOrNull
            ?.name ??
        // The ID is better than nothing if a location is missing.
        loaded.currentLocation;
    return _PatientDetails(patient: loaded, locationName: locationName);
  }
}

class _PatientDetails extends StatelessWidget {
  const _PatientDetails({required this.patient, required this.locationName});

  final Patient patient;
  final String locationName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mutedColor = theme.colorScheme.onSurfaceVariant;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(patient.name, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            StatusBadge(patient.status),
            Text(
              patient.patientId,
              semanticsLabel: 'ID ${patient.patientId}',
              style: theme.textTheme.bodyMedium?.copyWith(color: mutedColor),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _Section(
          title: 'Last recorded location',
          children: [
            Row(
              children: [
                Icon(Icons.place_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(locationName, style: theme.textTheme.titleLarge),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Recorded: '
              '${formatRecordedTime(context, patient.locationUpdatedAt)}',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            // The location is not tracked live (#16). Saying so here keeps
            // staff from trusting it more than they should.
            Text(
              'Changes only when a transfer is confirmed, so the patient may '
              'have moved since.',
              style: theme.textTheme.bodySmall?.copyWith(color: mutedColor),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _Section(
          title: 'Patient',
          children: [
            _InfoRow(label: 'Age', value: '${patient.age} years'),
            _InfoRow(label: 'Condition', value: patient.condition),
            _InfoRow(
              label: 'Admitted',
              value: formatRecordedTime(context, patient.admissionDate),
            ),
          ],
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card.outlined(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// A label above its value. Stacked instead of side by side, so long values
/// and large font sizes have the full width.
class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      // Read as "Age, 54 years" instead of two separate items.
      child: MergeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(value, style: theme.textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}

/// The one action the role may take, at the bottom where the thumb reaches
/// it: nurses transfer, doctors change the status. The rules enforce the
/// same split (#17); hiding the button is only for clarity.
class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final (label, icon, notReadyMessage) = switch (role) {
      UserRole.nurse => (
        'Transfer patient',
        Icons.swap_horiz,
        'Transfers are not available yet.',
      ),
      UserRole.doctor => (
        'Change status',
        Icons.edit_note,
        'Changing the status is not available yet.',
      ),
    };

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          icon: Icon(icon),
          label: Text(label),
          // Temporary until the transfer flow (#21) and the status picker
          // (#19) exist. Replace with navigation to them.
          onPressed: () => ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(notReadyMessage))),
        ),
      ),
    );
  }
}
