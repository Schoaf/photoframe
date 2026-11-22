import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'ha_media.dart';

/// The template sensor (set up in Home Assistant, see README) that lists
/// the active warnings - so labels are evaluated in HA, and the tablet's
/// token needs no admin rights.
const warningsEntityId = 'sensor.tablet_warnungen';

const _reconnectDelay = Duration(seconds: 30);
const _entitiesRequestId = 1;
const _forecastRequestId = 2;
const _firstCommandId = 3;

class HaEntity {
  const HaEntity(this.state, this.attributes);

  final String state;
  final Map<String, dynamic> attributes;
}

/// Keeps the entities of a `subscribe_entities` subscription up to date.
/// Its events are compressed: `a` added, `c` changed (`+` new values,
/// `-` removed attributes), `r` removed; `s` state, `a` attributes.
class EntityStore {
  final entities = <String, HaEntity>{};

  void apply(Map<String, dynamic> event) {
    final added = event['a'] as Map<String, dynamic>? ?? const {};
    for (final MapEntry(:key, :value) in added.entries) {
      final entity = value as Map<String, dynamic>;
      entities[key] = HaEntity(
        '${entity['s']}',
        Map.of(entity['a'] as Map<String, dynamic>? ?? const {}),
      );
    }
    final changed = event['c'] as Map<String, dynamic>? ?? const {};
    for (final MapEntry(:key, :value) in changed.entries) {
      final current = entities[key];
      if (current == null) continue;
      final diff = value as Map<String, dynamic>;
      final plus = diff['+'] as Map<String, dynamic>? ?? const {};
      final minus = diff['-'] as Map<String, dynamic>? ?? const {};
      final attributes = Map.of(current.attributes)
        ..addAll(plus['a'] as Map<String, dynamic>? ?? const {});
      for (final removed in minus['a'] as List? ?? const []) {
        attributes.remove(removed);
      }
      entities[key] = HaEntity(
        plus['s'] == null ? current.state : '${plus['s']}',
        attributes,
      );
    }
    for (final removed in event['r'] as List? ?? const []) {
      entities.remove(removed);
    }
  }
}

class WeatherNow {
  const WeatherNow({required this.condition, this.temperature, this.unit});

  /// HA condition, e.g. `sunny`, `partlycloudy`, `rainy`.
  final String condition;
  final num? temperature;
  final String? unit;
}

class WeatherDay {
  const WeatherDay({required this.condition, this.high, this.low});

  final String condition;
  final num? high;
  final num? low;
}

class HaWarning {
  const HaWarning({
    required this.id,
    required this.name,
    this.details = const [],
    this.icon,
  });

  final String id;
  final String name;

  /// The issues of the device [name], one line each.
  final List<String> details;

  /// e.g. `mdi:washing-machine`, if one is set in HA.
  final String? icon;
}

/// A running appliance (dishwasher, washer, dryer, vacuum) from the
/// `laufend` attribute of [warningsEntityId].
class RunningDevice {
  const RunningDevice({
    required this.name,
    this.icon,
    this.end,
    this.start,
    this.progress,
    this.view,
    this.properties = const [],
  });

  final String name;
  final String? icon;
  final DateTime? end;
  final DateTime? start;

  /// 0..100 as the device reports it.
  final double? progress;

  /// Dashboard view for this appliance, if the template names one.
  final String? view;

  /// What the device reports (program, temperature, ...), for its card.
  final List<DeviceProperty> properties;

  /// Past its [end] and still running - how much longer is anyone's guess.
  bool isOverdue(DateTime now) {
    final end = this.end;
    return end != null && !end.isAfter(now);
  }

  /// From [end], or estimated from [start] and [progress] - e.g. the
  /// Roborock only reports how far it is. null when unknown.
  Duration? remaining(DateTime now) {
    if (end case final end?) {
      return isOverdue(now) ? null : end.difference(now);
    }
    final progress = this.progress;
    final start = this.start;
    if (progress == null || start == null || progress <= 0) return null;
    final elapsed = now.difference(start);
    return elapsed * ((100 - progress.clamp(0, 100)) / progress);
  }

  /// So close to the end that it going away means it finished - not that
  /// it was cancelled or went offline.
  bool isNearlyDone(DateTime now) {
    final left = remaining(now);
    if (left != null && left <= const Duration(minutes: 5)) return true;
    final fraction = this.fraction(now);
    return fraction != null && fraction >= 0.95;
  }

  /// 0..1 for the bar: as reported, or from [start] and [end].
  double? fraction(DateTime now) {
    if (isOverdue(now)) return 1;
    if (progress case final progress?) return (progress / 100).clamp(0, 1);
    final start = this.start;
    final end = this.end;
    if (start == null || end == null || !end.isAfter(start)) return null;
    return (now.difference(start).inSeconds / end.difference(start).inSeconds)
        .clamp(0, 1);
  }
}

/// One entity of a running appliance, as the template lists it under
/// `eigenschaften`.
class DeviceProperty {
  const DeviceProperty({required this.name, required this.value, this.unit});

  final String name;

  /// HA's translated state, e.g. `Baumwolle`, `40`, an ISO time.
  final String value;
  final String? unit;
}

/// A device on the charger, from the `ladend` attribute of
/// [warningsEntityId].
class ChargingDevice {
  const ChargingDevice({required this.name, required this.level, this.icon});

  final String name;

  /// 0..100.
  final double level;
  final String? icon;
}

/// What the overlay shows.
class HaSnapshot {
  const HaSnapshot({
    this.weather,
    this.tomorrow,
    this.warnings = const [],
    this.running = const [],
    this.charging = const [],
    this.nowPlaying,
    this.isTokenInvalid = false,
  });

  final WeatherNow? weather;
  final WeatherDay? tomorrow;
  final List<HaWarning> warnings;
  final List<RunningDevice> running;
  final List<ChargingDevice> charging;
  final NowPlaying? nowPlaying;
  final bool isTokenInvalid;
}

double? _number(Object? value) => switch (value) {
  final num value => value.toDouble(),
  final String value => double.tryParse(value),
  _ => null,
};

/// Reads the `ladend` attribute of [warningsEntityId].
List<ChargingDevice> parseCharging(HaEntity? entity) {
  final list = entity?.attributes['ladend'];
  if (list is! List) return const [];
  return [
    for (final entry in list.whereType<Map<String, dynamic>>())
      if ((entry['name'], _number(entry['ladung'])) case (
        final String name,
        final double level,
      ))
        ChargingDevice(
          name: name,
          level: level.clamp(0, 100),
          icon: entry['icon'] as String?,
        ),
  ];
}

/// Reads the `laufend` attribute of [warningsEntityId].
List<RunningDevice> parseRunning(HaEntity? entity) {
  final list = entity?.attributes['laufend'];
  if (list is! List) return const [];
  DateTime? time(Object? value) =>
      value is String ? DateTime.tryParse(value)?.toLocal() : null;
  return [
    for (final entry in list.whereType<Map<String, dynamic>>())
      if (entry['name'] is String)
        RunningDevice(
          name: entry['name'] as String,
          icon: entry['icon'] as String?,
          end: time(entry['ende']),
          start: time(entry['start']),
          progress: _number(entry['fortschritt']),
          view: entry['ansicht'] as String?,
          properties: [
            if (entry['eigenschaften'] case final List<dynamic> properties)
              for (final property
                  in properties.whereType<Map<String, dynamic>>())
                if (property['name'] is String && property['wert'] != null)
                  DeviceProperty(
                    name: property['name'] as String,
                    value: '${property['wert']}',
                    unit: property['einheit'] as String?,
                  ),
          ],
        ),
  ];
}

WeatherNow? parseWeather(HaEntity? entity) {
  if (entity == null || entity.state == 'unavailable') return null;
  return WeatherNow(
    condition: entity.state,
    temperature: entity.attributes['temperature'] as num?,
    unit: entity.attributes['temperature_unit'] as String?,
  );
}

/// The daily forecast entry for the day after [now].
WeatherDay? parseTomorrow(List<dynamic>? forecast, DateTime now) {
  if (forecast == null) return null;
  final tomorrow = DateTime(now.year, now.month, now.day + 1);
  for (final entry in forecast.cast<Map<String, dynamic>>()) {
    final date = DateTime.tryParse('${entry['datetime']}')?.toLocal();
    if (date == null ||
        date.year != tomorrow.year ||
        date.month != tomorrow.month ||
        date.day != tomorrow.day) {
      continue;
    }
    return WeatherDay(
      condition: '${entry['condition']}',
      high: entry['temperature'] as num?,
      low: entry['templow'] as num?,
    );
  }
  return null;
}

/// Reads the `warnungen` attribute of [warningsEntityId].
List<HaWarning> parseWarnings(HaEntity? entity) {
  final list = entity?.attributes['warnungen'];
  if (list is! List) return const [];
  return [
    for (final entry in list.whereType<Map<String, dynamic>>())
      if (entry['id'] is String)
        HaWarning(
          id: entry['id'] as String,
          name: '${entry['name'] ?? entry['id']}',
          details: [
            if (entry['details'] case final List<dynamic> details)
              for (final detail in details)
                if (detail is String && detail.isNotEmpty) detail,
          ],
          icon: entry['icon'] as String?,
        ),
  ];
}

/// Websocket connection to Home Assistant (token of a non-admin user):
/// follows the weather entity, its daily forecast, the warnings sensor and
/// the chosen media players, and sends player commands. Reconnects on its own, e.g. while HA restarts.
class HaClient {
  HaClient({
    required String baseUrl,
    required this.token,
    required this.weatherEntityId,
    this.playerEntityIds = const [],
    required this.onUpdate,
  }) : _uri = websocketUri(baseUrl);

  final String token;
  final String weatherEntityId;
  final List<String> playerEntityIds;
  final ValueChanged<HaSnapshot> onUpdate;
  final Uri _uri;
  WebSocket? _socket;
  bool _isRunning = false;
  final _store = EntityStore();
  List<dynamic>? _forecast;
  var _nextId = _firstCommandId;

  /// `http://ha:8123/lovelace/0` → `ws://ha:8123/api/websocket`.
  static Uri websocketUri(String baseUrl) {
    final uri = Uri.parse(baseUrl.trim());
    return Uri(
      scheme: uri.scheme == 'https' ? 'wss' : 'ws',
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      path: '/api/websocket',
    );
  }

  void start() {
    _isRunning = true;
    _run();
  }

  void stop() {
    _isRunning = false;
    _socket?.close();
  }

  Future<void> _run() async {
    while (_isRunning) {
      try {
        final socket = await WebSocket.connect(_uri.toString());
        socket.pingInterval = const Duration(seconds: 30);
        _socket = socket;
        if (!_isRunning) await socket.close();
        await for (final message in socket) {
          if (!_handle(jsonDecode(message as String) as Map<String, dynamic>)) {
            await socket.close();
            return;
          }
        }
      } on Exception {
        // HA unreachable - try again below.
      }
      if (_isRunning) await Future<void>.delayed(_reconnectDelay);
    }
  }

  /// false when the token was rejected (no point in reconnecting).
  bool _handle(Map<String, dynamic> message) {
    switch (message['type']) {
      case 'auth_required':
        _send({'type': 'auth', 'access_token': token});
      case 'auth_invalid':
        onUpdate(const HaSnapshot(isTokenInvalid: true));
        return false;
      case 'auth_ok':
        _store.entities.clear();
        _send({
          'id': _entitiesRequestId,
          'type': 'subscribe_entities',
          'entity_ids': [
            if (weatherEntityId.isNotEmpty) weatherEntityId,
            warningsEntityId,
            ...playerEntityIds,
          ],
        });
        if (weatherEntityId.isEmpty) break;
        _send({
          'id': _forecastRequestId,
          'type': 'weather/subscribe_forecast',
          'entity_id': weatherEntityId,
          'forecast_type': 'daily',
        });
      case 'event':
        final event = message['event'] as Map<String, dynamic>;
        if (message['id'] == _entitiesRequestId) {
          _store.apply(event);
        } else if (message['id'] == _forecastRequestId) {
          _forecast = event['forecast'] as List<dynamic>?;
        }
        onUpdate(_snapshot());
    }
    return true;
  }

  HaSnapshot _snapshot() => HaSnapshot(
    weather: parseWeather(_store.entities[weatherEntityId]),
    tomorrow: parseTomorrow(_forecast, DateTime.now()),
    warnings: parseWarnings(_store.entities[warningsEntityId]),
    running: parseRunning(_store.entities[warningsEntityId]),
    charging: parseCharging(_store.entities[warningsEntityId]),
    nowPlaying: parseNowPlaying(_store.entities, playerEntityIds),
  );

  /// e.g. `media_play_pause` on a media player.
  void callService(String domain, String service, String entityId) => _send({
    'id': _nextId++,
    'type': 'call_service',
    'domain': domain,
    'service': service,
    'target': {'entity_id': entityId},
  });

  void _send(Map<String, Object> message) => _socket?.add(jsonEncode(message));
}

typedef ValueChanged<T> = void Function(T value);
