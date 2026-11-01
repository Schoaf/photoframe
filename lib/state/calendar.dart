import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/ha_calendar.dart';
import 'settings.dart';

const _refreshInterval = Duration(minutes: 5);

/// Today's and tomorrow's events of the chosen calendars, re-read every
/// few minutes.
class CalendarNotifier extends Notifier<List<CalendarEvent>> {
  @override
  List<CalendarEvent> build() {
    final settings = ref.watch(settingsProvider);
    if (!settings.hasHaInfo || settings.calendarEntityIds.isEmpty) {
      return const [];
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
        state = events;
      } on Exception {
        // HA unreachable - keep the last events, try again later.
      }
    }

    load();
    final timer = Timer.periodic(_refreshInterval, (_) => load());
    ref.onDispose(timer.cancel);
    return const [];
  }
}

final calendarProvider =
    NotifierProvider<CalendarNotifier, List<CalendarEvent>>(
      CalendarNotifier.new,
    );
