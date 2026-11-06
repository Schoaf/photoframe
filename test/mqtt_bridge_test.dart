import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ha_display/services/kiosk.dart';
import 'package:ha_display/services/mqtt_bridge.dart';
import 'package:ha_display/state/display_state.dart';
import 'package:ha_display/state/settings.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockKiosk extends Mock implements Kiosk {}

void main() {
  const topics = MqttTopics('abc123');
  late _MockKiosk kiosk;
  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    kiosk = _MockKiosk();
    when(() => kiosk.screenOff()).thenAnswer((_) async => true);
    when(() => kiosk.screenOn()).thenAnswer((_) async {});
    when(() => kiosk.setBrightness(any())).thenAnswer((_) async {});
    when(() => kiosk.isChildLocked()).thenAnswer((_) async => false);
    when(() => kiosk.setChildLock(any())).thenAnswer((_) async {});
    when(() => kiosk.isAutoBrightness()).thenAnswer((_) async => false);
    when(() => kiosk.mediaVolume()).thenAnswer((_) async => 40);
    when(() => kiosk.setAutoBrightness(any())).thenAnswer((_) async => true);
    when(() => kiosk.pressKey(any())).thenAnswer((_) async => true);
    when(() => kiosk.stopLock()).thenAnswer((_) async {});
    when(() => kiosk.setMediaVolume(any())).thenAnswer((_) async {});
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
        'homeassistant/switch/ha_display_abc123/child_lock/config',
        'homeassistant/switch/ha_display_abc123/private/config',
        'homeassistant/select/ha_display_abc123/mode/config',
        'homeassistant/number/ha_display_abc123/brightness/config',
        'homeassistant/switch/ha_display_abc123/auto_brightness/config',
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

  test('Home Assistant presses the keys and sets the volume', () async {
    for (final key in ['back', 'home', 'recents']) {
      expect(
        applyMqttCommand(
          topics,
          topics.command('key_$key'),
          'PRESS',
          display(),
        ),
        isTrue,
      );
      verify(() => kiosk.pressKey(key)).called(1);
    }
    applyMqttCommand(topics, topics.command('media_volume'), '130', display());
    await pumpEventQueue();
    verify(() => kiosk.setMediaVolume(100)).called(1);
  });

  test(
    'an ended kiosk behind other apps does not count as screen off',
    () async {
      await display().endKiosk();
      display().reportScreenOn(false);
      expect(container.read(displayProvider).isScreenOn, isTrue);

      display().reportResumed();
      expect(container.read(displayProvider).isKioskEnded, isFalse);
      display().reportScreenOn(false);
      expect(container.read(displayProvider).isScreenOn, isFalse);
    },
  );

  test('automatic brightness leaves the brightness to Android', () async {
    applyMqttCommand(topics, topics.command('brightness'), '128', display());
    await pumpEventQueue();
    applyMqttCommand(
      topics,
      topics.command('auto_brightness'),
      'ON',
      display(),
    );
    await pumpEventQueue();
    expect(container.read(displayProvider).isAutoBrightness, isTrue);
    verify(() => kiosk.setAutoBrightness(true)).called(1);
    verify(() => kiosk.setBrightness(null)).called(1);
  });

  test('a set brightness ends automatic brightness', () async {
    applyMqttCommand(
      topics,
      topics.command('auto_brightness'),
      'ON',
      display(),
    );
    await pumpEventQueue();
    applyMqttCommand(topics, topics.command('brightness'), '51', display());
    await pumpEventQueue();
    expect(container.read(displayProvider).isAutoBrightness, isFalse);
    verify(() => kiosk.setAutoBrightness(false)).called(1);
    verify(() => kiosk.setBrightness(0.2)).called(1);
  });

  test('automatic brightness stays off without the permission', () async {
    when(() => kiosk.setAutoBrightness(any())).thenAnswer((_) async => false);
    applyMqttCommand(
      topics,
      topics.command('auto_brightness'),
      'ON',
      display(),
    );
    await pumpEventQueue();
    expect(container.read(displayProvider).isAutoBrightness, isFalse);
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
      'ha_display/abc123/child_lock/state': 'OFF',
      'ha_display/abc123/private/state': 'OFF',
      'ha_display/abc123/mode/state': 'dashboard',
      'ha_display/abc123/auto_brightness/state': 'OFF',
      'ha_display/abc123/media_volume/state': '40',
      'ha_display/abc123/brightness/state': '128',
    });
  });

  test('child lock keeps the screen as Home Assistant set it', () async {
    applyMqttCommand(topics, topics.command('child_lock'), 'ON', display());
    applyMqttCommand(topics, topics.command('screen'), 'OFF', display());
    await pumpEventQueue();
    verify(() => kiosk.setChildLock(true)).called(1);

    // The power button switched it on - the kiosk turns it off again.
    display().reportScreenOn(true);
    final state = container.read(displayProvider);
    expect(state.isChildLocked, isTrue);
    expect(state.isScreenOn, isFalse);
    expect(topics.states(state)['ha_display/abc123/child_lock/state'], 'ON');
  });

  test('private mode survives a restart', () async {
    applyMqttCommand(topics, topics.command('private'), 'ON', display());
    await pumpEventQueue();
    expect(container.read(displayProvider).isPrivate, isTrue);

    container.invalidate(displayProvider);
    container.read(displayProvider);
    await pumpEventQueue();
    final state = container.read(displayProvider);
    expect(state.isPrivate, isTrue);
    expect(topics.states(state)['ha_display/abc123/private/state'], 'ON');
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
