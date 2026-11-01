import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ha_display/services/kiosk.dart';
import 'package:ha_display/services/mqtt_bridge.dart';
import 'package:ha_display/state/display_state.dart';
import 'package:ha_display/state/settings.dart';
import 'package:mocktail/mocktail.dart';

class _MockKiosk extends Mock implements Kiosk {}

void main() {
  const topics = MqttTopics('abc123');
  late _MockKiosk kiosk;
  late ProviderContainer container;

  setUp(() {
    kiosk = _MockKiosk();
    when(() => kiosk.screenOff()).thenAnswer((_) async => true);
    when(() => kiosk.screenOn()).thenAnswer((_) async {});
    when(() => kiosk.setBrightness(any())).thenAnswer((_) async {});
    container = ProviderContainer(
      overrides: [
        kioskProvider.overrideWithValue(kiosk),
        settingsProvider.overrideWith(
          () => SettingsNotifier(
            const Settings(
              synologyUrl: 'http://nas',
              albumId: 1,
              dashboardUrl: 'http://ha',
            ),
          ),
        ),
      ],
    );
  });

  tearDown(() => container.dispose());

  DisplayNotifier display() => container.read(displayProvider.notifier);

  test('announces all entities with a shared device and availability', () {
    final configs = topics.discoveryConfigs('Wohnzimmer');

    expect(
      configs.keys,
      containsAll([
        'homeassistant/switch/ha_display_abc123/screen/config',
        'homeassistant/select/ha_display_abc123/mode/config',
        'homeassistant/number/ha_display_abc123/brightness/config',
        'homeassistant/button/ha_display_abc123/next_photo/config',
        'homeassistant/button/ha_display_abc123/reload/config',
      ]),
    );
    final mode = jsonDecode(
      configs['homeassistant/select/ha_display_abc123/mode/config']!,
    ) as Map<String, dynamic>;
    expect(mode['options'], ['photos', 'dashboard']);
    expect(mode['command_topic'], 'ha_display/abc123/mode/set');
    expect(mode['availability_topic'], 'ha_display/abc123/availability');
    expect((mode['device'] as Map)['name'], 'Wohnzimmer');
  });

  test('screen OFF/ON commands switch the panel via the kiosk', () async {
    expect(
      applyMqttCommand(topics, topics.command('screen'), 'OFF', display()),
      isTrue,
    );
    await pumpEventQueue();
    expect(container.read(displayProvider).isScreenOn, isFalse);
    verify(() => kiosk.screenOff()).called(1);

    applyMqttCommand(topics, topics.command('screen'), 'ON', display());
    await pumpEventQueue();
    expect(container.read(displayProvider).isScreenOn, isTrue);
    verify(() => kiosk.screenOn()).called(1);
  });

  test('without device owner, screen off blacks out instead', () async {
    when(() => kiosk.screenOff()).thenAnswer((_) async => false);

    applyMqttCommand(topics, topics.command('screen'), 'OFF', display());
    await pumpEventQueue();

    expect(container.read(displayProvider).isBlackedOut, isTrue);
    verify(() => kiosk.setBrightness(0)).called(1);
  });

  test('mode, brightness and buttons update the display state', () async {
    applyMqttCommand(topics, topics.command('mode'), 'dashboard', display());
    applyMqttCommand(topics, topics.command('brightness'), '128.0', display());
    applyMqttCommand(topics, topics.command('next_photo'), 'PRESS', display());
    await pumpEventQueue();

    final state = container.read(displayProvider);
    expect(state.mode, DisplayMode.dashboard);
    expect(state.brightness, 128);
    expect(state.nextPhotoRequests, 1);
    expect(topics.states(state), {
      'ha_display/abc123/screen/state': 'ON',
      'ha_display/abc123/mode/state': 'dashboard',
      'ha_display/abc123/brightness/state': '128',
    });
  });

  test('ignores unknown payloads and topics', () {
    expect(
      applyMqttCommand(topics, topics.command('mode'), 'tv', display()),
      isFalse,
    );
    expect(
      applyMqttCommand(topics, 'ha_display/abc123/x/set', '1', display()),
      isFalse,
    );
  });
}
