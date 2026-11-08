import 'package:flutter/material.dart';

/// The app's look, in light and dark mode.
///
/// Every colour comes from one seed. Screens should use the scheme's colour
/// pairs (for example `primaryContainer` with `onPrimaryContainer`) instead of
/// fixed colours: the pairs keep enough contrast in both modes (#39).
ThemeData buildAppTheme(Brightness brightness) {
  final colors = ColorScheme.fromSeed(
    seedColor: Colors.teal,
    brightness: brightness,
  );
  return ThemeData(
    colorScheme: colors,
    // At least 48x48 tap targets on every platform, also for staff wearing
    // gloves. Without these, desktop and web builds use smaller ones.
    materialTapTargetSize: MaterialTapTargetSize.padded,
    visualDensity: VisualDensity.standard,
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
    ),
  );
}
