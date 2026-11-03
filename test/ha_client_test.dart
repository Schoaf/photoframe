import 'package:flutter_test/flutter_test.dart';
import 'package:ha_display/services/ha_client.dart';
import 'package:ha_display/state/ha_info.dart';

void main() {
  group('EntityStore', () {
    test('applies added, changed and removed entities', () {
      final store = EntityStore()
        ..apply({
          'a': {
            'weather.home': {
              's': 'sunny',
              'a': {'temperature': 12, 'humidity': 80},
            },
          },
        })
        ..apply({
          'c': {
            'weather.home': {
              '+': {
                's': 'rainy',
                'a': {'temperature': 9},
              },
              '-': {
                'a': ['humidity'],
              },
            },
          },
        });

      final weather = store.entities['weather.home']!;
      expect(weather.state, 'rainy');
      expect(weather.attributes, {'temperature': 9});

      store.apply({
        'r': ['weather.home'],
      });
      expect(store.entities, isEmpty);
    });
  });

  test('parses the current weather', () {
    final weather = parseWeather(
      const HaEntity('partlycloudy', {
        'temperature': 12.4,
        'temperature_unit': '°C',
      }),
    )!;
    expect(weather.condition, 'partlycloudy');
    expect(weather.temperature, 12.4);
    expect(parseWeather(const HaEntity('unavailable', {})), isNull);
  });

  test("picks tomorrow's daily forecast", () {
    final now = DateTime(2026, 11, 1, 14);
    final tomorrow = parseTomorrow([
      {
        'datetime': DateTime(2026, 11, 1, 12).toUtc().toIso8601String(),
        'condition': 'cloudy',
        'temperature': 10,
      },
      {
        'datetime': DateTime(2026, 11, 2, 12).toUtc().toIso8601String(),
        'condition': 'sunny',
        'temperature': 15,
        'templow': 4,
      },
    ], now)!;
    expect(tomorrow.condition, 'sunny');
    expect(tomorrow.high, 15);
    expect(tomorrow.low, 4);
    expect(parseTomorrow(null, now), isNull);
  });

  test('reads the warnings list of the template sensor', () {
    final warnings = parseWarnings(
      const HaEntity('2', {
        'warnungen': [
          {
            'id': 'binary_sensor.waschmaschine_fertig',
            'name': 'Waschmaschine ist fertig',
            'icon': 'mdi:washing-machine',
          },
          {'id': 'binary_sensor.roborock_wasser', 'name': null},
          {
            'id': 'lock.tuer,sensor.tuer_battery',
            'name': 'Türschloss',
            'details': ['Batterie nicht erreichbar', '', 3, 'Problem'],
          },
          {'name': 'ohne id'},
        ],
      }),
    );
    expect(warnings.map((warning) => warning.name), [
      'Waschmaschine ist fertig',
      'binary_sensor.roborock_wasser',
      'Türschloss',
    ]);
    expect(warnings.first.details, isEmpty);
    expect(warnings.last.details, ['Batterie nicht erreichbar', 'Problem']);
    expect(parseWarnings(null), isEmpty);
  });

  test('builds the websocket URL from the dashboard URL', () {
    expect(
      HaClient.websocketUri('http://ha.local:8123/lovelace/0?x').toString(),
      'ws://ha.local:8123/api/websocket',
    );
    expect(
      HaClient.websocketUri('https://ha.example.com/dash').toString(),
      'wss://ha.example.com/api/websocket',
    );
  });

  test('a dismissed warning returns at midnight', () {
    const washer = HaWarning(id: 'washer', name: 'Waschmaschine');
    const robot = HaWarning(id: 'robot', name: 'Roborock');
    final evening = DateTime(2026, 11, 3, 22);
    final dismissed = DismissedWarnings()..dismiss('washer', evening);

    expect(dismissed.visible([washer, robot], evening), [robot]);
    expect(dismissed.visible([robot], evening), [robot]);
    expect(dismissed.visible([washer, robot], DateTime(2026, 11, 3, 23, 59)), [
      robot,
    ]);
    expect(dismissed.visible([washer, robot], DateTime(2026, 11, 4)), [
      washer,
      robot,
    ]);
  });

  group('running devices', () {
    final now = DateTime(2026, 11, 1, 12);

    test('reads the laufend attribute', () {
      final running = parseRunning(
        HaEntity('0', {
          'laufend': [
            {
              'name': 'Waschmaschine',
              'icon': 'mdi:washing-machine',
              'ende': now
                  .add(const Duration(minutes: 42))
                  .toUtc()
                  .toIso8601String(),
              'fortschritt': '58',
              'ansicht': 'waschmaschine',
            },
            {'name': 'Roborock', 'start': null, 'fortschritt': 40},
            {'ende': 'ohne Namen'},
          ],
        }),
      );
      expect(running.map((device) => device.name), [
        'Waschmaschine',
        'Roborock',
      ]);
      expect(running.first.remaining(now), const Duration(minutes: 42));
      expect(running.first.fraction(now), closeTo(0.58, 0.001));
      expect(running.first.view, 'waschmaschine');
      expect(running.last.view, isNull);
      expect(parseRunning(null), isEmpty);
    });

    test('estimates the remaining time from start and progress', () {
      final roborock = RunningDevice(
        name: 'Roborock',
        start: now.subtract(const Duration(minutes: 20)),
        progress: 40,
      );
      expect(roborock.remaining(now), const Duration(minutes: 30));
    });

    test('derives the bar from start and end without progress', () {
      final dryer = RunningDevice(
        name: 'Trockner',
        start: now.subtract(const Duration(minutes: 30)),
        end: now.add(const Duration(minutes: 90)),
      );
      expect(dryer.fraction(now), closeTo(0.25, 0.001));
    });
  });
}
