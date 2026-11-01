import 'package:dio/dio.dart';

const _maxAgendaEntries = 6;

class HaCalendar {
  const HaCalendar({required this.entityId, required this.name});

  final String entityId;
  final String name;
}

class CalendarEvent {
  const CalendarEvent({
    required this.title,
    required this.start,
    required this.end,
    required this.isAllDay,
  });

  final String title;
  final DateTime start;

  /// Exclusive - for all-day events the day after the last day.
  final DateTime end;
  final bool isAllDay;

  /// `{"summary", "start": {"dateTime"|"date"}, "end": {...}}` from
  /// `GET /api/calendars/<entity>`.
  static CalendarEvent? fromJson(Map<String, dynamic> json) {
    final start = json['start'] as Map<String, dynamic>? ?? const {};
    final end = json['end'] as Map<String, dynamic>? ?? const {};
    final isAllDay = start['date'] != null;
    DateTime? time(Map<String, dynamic> value) => isAllDay
        ? DateTime.tryParse('${value['date']}')
        : DateTime.tryParse('${value['dateTime']}')?.toLocal();
    final startTime = time(start);
    final endTime = time(end);
    if (startTime == null || endTime == null) return null;
    return CalendarEvent(
      title: '${json['summary'] ?? ''}',
      start: startTime,
      end: endTime,
      isAllDay: isAllDay,
    );
  }
}

class AgendaDay {
  const AgendaDay({required this.isToday, required this.events});

  final bool isToday;
  final List<CalendarEvent> events;
}

/// Today's events that aren't over yet and tomorrow's - all-day first, at
/// most [_maxAgendaEntries] in total.
List<AgendaDay> buildAgenda(List<CalendarEvent> events, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final tomorrow = DateTime(now.year, now.month, now.day + 1);
  final dayAfter = DateTime(now.year, now.month, now.day + 2);
  List<CalendarEvent> on(DateTime day, DateTime next) {
    final list = [
      for (final event in events)
        if (event.start.isBefore(next) &&
            event.end.isAfter(day) &&
            (event.isAllDay || event.end.isAfter(now)))
          event,
    ];
    list.sort((a, b) {
      if (a.isAllDay != b.isAllDay) return a.isAllDay ? -1 : 1;
      return a.start.compareTo(b.start);
    });
    return list;
  }

  var left = _maxAgendaEntries;
  final days = <AgendaDay>[];
  for (final (isToday, day, next) in [
    (true, today, tomorrow),
    (false, tomorrow, dayAfter),
  ]) {
    final dayEvents = on(day, next).take(left).toList();
    left -= dayEvents.length;
    if (dayEvents.isNotEmpty) {
      days.add(AgendaDay(isToday: isToday, events: dayEvents));
    }
  }
  return days;
}

/// Reads calendars via HA's REST API - works with a non-admin token.
class HaCalendarClient {
  HaCalendarClient({required String baseUrl, required String token, Dio? dio})
    : _dio = dio ?? Dio(),
      _base = Uri.parse(baseUrl.trim()).replace(path: '/', query: ''),
      _headers = {'Authorization': 'Bearer $token'};

  final Dio _dio;
  final Uri _base;
  final Map<String, String> _headers;

  Future<List<HaCalendar>> listCalendars() async {
    final response = await _dio.getUri<List<dynamic>>(
      _base.resolve('/api/calendars'),
      options: Options(headers: _headers),
    );
    return [
      for (final entry in response.data!.cast<Map<String, dynamic>>())
        HaCalendar(
          entityId: entry['entity_id'] as String,
          name: '${entry['name'] ?? entry['entity_id']}',
        ),
    ];
  }

  Future<List<CalendarEvent>> events(
    String entityId,
    DateTime start,
    DateTime end,
  ) async {
    final response = await _dio.getUri<List<dynamic>>(
      _base
          .resolve('/api/calendars/$entityId')
          .replace(
            queryParameters: {
              'start': start.toUtc().toIso8601String(),
              'end': end.toUtc().toIso8601String(),
            },
          ),
      options: Options(headers: _headers),
    );
    return [
      for (final entry in response.data!.cast<Map<String, dynamic>>())
        ?CalendarEvent.fromJson(entry),
    ];
  }
}
