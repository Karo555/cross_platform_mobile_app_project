import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/state_views.dart';
import '../../../data/models/app_user.dart';
import '../../../data/models/location.dart';
import '../../../data/models/patient.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/patient_repository.dart';
import '../providers.dart';
import '../widgets/transfer_dialog.dart';

/// Lets a nurse pick where [patientId] goes, then confirm it (#21).
///
/// Closes with the destination's name once the transfer has been accepted,
/// so the details screen can say where the patient went. Watches the patient
/// live, so the list always leaves out their current location.
class TransferScreen extends ConsumerWidget {
  const TransferScreen({super.key, required this.patientId});

  final String patientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Transfer patient')),
      body: SafeArea(child: _buildBody(context, ref)),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref) {
    // The button is only shown to nurses, but this screen can also be
    // reached by its URL. The rules enforce the same (#17).
    if (ref.watch(authStateProvider).value?.role != UserRole.nurse) {
      return const EmptyState(
        title: 'Only nurses can transfer patients',
        icon: Icons.lock_outline,
      );
    }

    final patient = ref.watch(patientProvider(patientId));
    final locations = ref.watch(locationsProvider);
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

    final current =
        locationList.where((l) => l.id == loaded.currentLocation).firstOrNull ??
        // The ID is better than nothing if a location is missing.
        Location(id: loaded.currentLocation, name: loaded.currentLocation);
    final destinations = locationList.where((l) => l.id != current.id).toList();

    return _DestinationList(
      patient: loaded,
      current: current,
      destinations: destinations,
    );
  }
}

class _DestinationList extends StatelessWidget {
  const _DestinationList({
    required this.patient,
    required this.current,
    required this.destinations,
  });

  final Patient patient;
  final Location current;
  final List<Location> destinations;

  Future<void> _choose(BuildContext context, Location to) async {
    final transferred = await showTransferDialog(
      context,
      patient: patient,
      from: current,
      to: to,
    );
    if (transferred == true && context.mounted) context.pop(to.name);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mutedColor = theme.colorScheme.onSurfaceVariant;

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(patient.name, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(
                'Last recorded location: ${current.name}',
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              Semantics(
                header: true,
                child: Text(
                  'Choose the destination',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
        if (destinations.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'There is nowhere else to move this patient to.',
              style: theme.textTheme.bodyMedium?.copyWith(color: mutedColor),
            ),
          )
        else
          for (final location in destinations)
            ListTile(
              leading: const Icon(Icons.place_outlined),
              title: Text(location.name),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _choose(context, location),
            ),
      ],
    );
  }
}
