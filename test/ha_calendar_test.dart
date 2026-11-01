import 'package:flutter_test/flutter_test.dart';
import 'package:ha_display/services/ha_calendar.dart';

void main() {
  final now = DateTime(2026, 11, 1, 14);

  CalendarEvent at(String title, int day, int hour, {int hours = 1}) =>
      CalendarEvent(
        title: title,
        start: DateTime(2026, 11, day, hour),
        end: DateTime(2026, 11, day, hour + hours),
        isAllDay: false,
      );

  CalendarEvent allDay(String title, int day) => CalendarEvent(
    title: title,
    start: DateTime(2026, 11, day),
    end: DateTime(2026, 11, day + 1),
    isAllDay: true,
  );

  test('parses timed and all-day events', () {
    final timed = CalendarEvent.fromJson({
      'summary': 'Zahnarzt',
      'start': {'dateTime': '2026-11-01T15:30:00+01:00'},
      'end': {'dateTime': '2026-11-01T16:00:00+01:00'},
    })!;
    expect(timed.isAllDay, isFalse);
    expect(timed.start, DateTime.parse('2026-11-01T14:30:00Z').toLocal());

    final day = CalendarEvent.fromJson({
      'summary': 'Müll',
      'start': {'date': '2026-11-02'},
      'end': {'date': '2026-11-03'},
    })!;
    expect(day.isAllDay, isTrue);
    expect(day.start, DateTime(2026, 11, 2));
  });

  test('today without past events, all-day first, then tomorrow', () {
    final agenda = buildAgenda([
      at('Vorbei', 1, 9),
      at('Zahnarzt', 1, 15),
      allDay('Papier', 1),
      at('Elternsprechtag', 2, 8),
      at('Übermorgen', 3, 8),
    ], now);

    expect(agenda.map((day) => day.isToday), [true, false]);
    expect(agenda[0].events.map((event) => event.title), [
      'Papier',
      'Zahnarzt',
    ]);
    expect(agenda[1].events.map((event) => event.title), ['Elternsprechtag']);
  });

  test('shows at most six entries', () {
    final agenda = buildAgenda([
      for (var hour = 15; hour < 20; hour++) at('Heute $hour', 1, hour),
      for (var hour = 8; hour < 12; hour++) at('Morgen $hour', 2, hour),
    ], now);

    expect(agenda[0].events, hasLength(5));
    expect(agenda[1].events, hasLength(1));
  });
}
