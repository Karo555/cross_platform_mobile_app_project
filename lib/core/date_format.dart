import 'package:flutter/material.dart';

/// Short text for when something was recorded, in the device's 12- or
/// 24-hour format:
///
/// - today: `14:05`
/// - yesterday: `Yesterday, 14:05`
/// - earlier: `Nov 3, 14:05`
///
/// The time is absolute on purpose. A relative time such as "5 min ago" would
/// be wrong a few minutes later unless the screen kept rebuilding.
///
/// [now] is only for tests.
String formatRecordedTime(
  BuildContext context,
  DateTime time, {
  DateTime? now,
}) {
  final localizations = MaterialLocalizations.of(context);
  final local = time.toLocal();
  final timeText = localizations.formatTimeOfDay(
    TimeOfDay.fromDateTime(local),
    alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
  );

  final daysAgo = _calendarDay((now ?? DateTime.now()).toLocal())
      .difference(_calendarDay(local))
      .inDays;
  // A time slightly in the future (clock differences) also counts as today.
  if (daysAgo <= 0) return timeText;
  if (daysAgo == 1) return 'Yesterday, $timeText';
  return '${localizations.formatShortMonthDay(local)}, $timeText';
}

/// The calendar date as midnight UTC, so the difference between two dates is
/// whole days even across a daylight saving change.
DateTime _calendarDay(DateTime local) =>
    DateTime.utc(local.year, local.month, local.day);
