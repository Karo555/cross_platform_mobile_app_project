import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart';

/// Keeps track of today's date and rebuilds the widgets that show times
/// relative to it, such as "Yesterday, 14:05" (`formatRecordedTime`), when
/// the date changes.
///
/// Without it, a patient list left open overnight would keep showing
/// yesterday's "14:05" as if it were today (#26).
///
/// Placed once around the whole app in `MaterialApp.builder`.
class Today extends StatefulWidget {
  const Today({super.key, required this.child});

  final Widget child;

  /// Today's date at local midnight, or null without a [Today] above
  /// [context]. Widgets that call this rebuild when the date changes.
  static DateTime? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_TodayScope>()?.date;

  @override
  State<Today> createState() => _TodayState();
}

class _TodayState extends State<Today> with WidgetsBindingObserver {
  late DateTime _date = _today();
  Timer? _timer;

  static DateTime _today() {
    final now = clock.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleNextCheck();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Checks again just after the next local midnight. Computed from the
  /// date rather than as 24 hours, so a daylight saving change is handled.
  void _scheduleNextCheck() {
    _timer?.cancel();
    final nextMidnight = DateTime(_date.year, _date.month, _date.day + 1);
    _timer = Timer(nextMidnight.difference(clock.now()), _check);
  }

  void _check() {
    final today = _today();
    if (today != _date) setState(() => _date = today);
    _scheduleNextCheck();
  }

  // A phone that sleeps overnight may run the timer late, so check again
  // whenever the app comes back to the foreground.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  @override
  Widget build(BuildContext context) =>
      _TodayScope(date: _date, child: widget.child);
}

class _TodayScope extends InheritedWidget {
  const _TodayScope({required this.date, required super.child});

  final DateTime date;

  @override
  bool updateShouldNotify(_TodayScope oldWidget) => date != oldWidget.date;
}
