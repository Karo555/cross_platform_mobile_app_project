import 'package:flutter/material.dart';

/// A short message with an icon inside a dialog or form, for example "You
/// are offline" or why a save failed. Used by the confirmation dialogs.
class InlineNotice extends StatelessWidget {
  const InlineNotice({
    super.key,
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
