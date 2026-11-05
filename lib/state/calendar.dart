import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/ha_calendar.dart';
import 'settings.dart';

const _refreshInterval = Duration(minutes: 5);

enum CalendarStatus { loading, loaded, failed }

class CalendarState {
  const CalendarState({
    this.events = const [],
    this.status = CalendarStatus.loading,
  });

  /// After a failed read still the last events.
  final List<CalendarEvent> events;

  /// Tells "no events" from "couldn't read them".
  final CalendarStatus status;
}

/// Today's and tomorrow's events of the chosen calendars, re-read every
/// few minutes.
class CalendarNotifier extends Notifier<CalendarState> {
  @override
  CalendarState build() {
    final settings = ref.watch(settingsProvider);
    if (!settings.hasHaInfo || settings.calendarEntityIds.isEmpty) {
      return const CalendarState();
    }
    final client = HaCalendarClient(
      baseUrl: settings.dashboardUrl,
      token: settings.haToken,
    );
    Future<void> load() async {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day);
      final end = DateTime(now.year, now.month, now.day + 2);
      try {
        final events = [
          for (final entityId in settings.calendarEntityIds)
            ...await client.events(entityId, start, end),
        ];
        state = CalendarState(events: events, status: CalendarStatus.loaded);
      } on Exception {
        // HA unreachable - keep the last events, try again later.
        state = CalendarState(
          events: state.events,
          status: CalendarStatus.failed,
        );
      }
    }

    load();
    final timer = Timer.periodic(_refreshInterval, (_) => load());
    ref.onDispose(timer.cancel);
    return const CalendarState();
  }
}

final calendarProvider = NotifierProvider<CalendarNotifier, CalendarState>(
  CalendarNotifier.new,
);
