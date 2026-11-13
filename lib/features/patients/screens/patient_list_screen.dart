import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/state_views.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/patient_repository.dart';
import '../providers.dart';
import '../widgets/patient_tile.dart';

/// The start screen: every patient with their status and last recorded
/// location. Changes appear by themselves, without a manual refresh (#26).
class PatientListScreen extends ConsumerWidget {
  const PatientListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Patients'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
          ),
        ],
      ),
      body: SafeArea(child: _buildBody(context, ref)),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref) {
    final patients = ref.watch(patientsProvider);
    final locations = ref.watch(locationsProvider);

    // Checked first: after an error the previous list is still readable, and
    // showing it without a warning would look up to date.
    if (patients.hasError || locations.hasError) {
      return ErrorState(
        message: 'Could not load the patient list.',
        onRetry: () {
          ref
            ..invalidate(patientsProvider)
            ..invalidate(locationsProvider);
        },
      );
    }

    final patientList = patients.value;
    final locationList = locations.value;
    if (patientList == null || locationList == null) {
      return const LoadingState(message: 'Loading patients...');
    }
    if (patientList.isEmpty) {
      return const EmptyState(
        title: 'No patients',
        message: 'Admitted patients will appear here.',
        icon: Icons.people_outline,
      );
    }

    final locationNames = {for (final l in locationList) l.id: l.name};
    return ListView.separated(
      itemCount: patientList.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final patient = patientList[index];
        return PatientTile(
          patient: patient,
          // The ID is better than nothing if a location is missing.
          locationName:
              locationNames[patient.currentLocation] ?? patient.currentLocation,
          onTap: () => context.push('/patients/${patient.patientId}'),
        );
      },
    );
  }
}
