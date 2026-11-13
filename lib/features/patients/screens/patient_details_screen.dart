import 'package:flutter/material.dart';

import '../../../core/widgets/state_views.dart';

/// Temporary until the details screen is built (#16). It only shows which
/// patient was opened, so the list's navigation can already be used and
/// tested.
class PatientDetailsScreen extends StatelessWidget {
  const PatientDetailsScreen({super.key, required this.patientId});

  final String patientId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(patientId)),
      body: const SafeArea(
        child: EmptyState(
          title: 'Patient details',
          message: 'Details for this patient are not available yet.',
          icon: Icons.person_outline,
        ),
      ),
    );
  }
}
