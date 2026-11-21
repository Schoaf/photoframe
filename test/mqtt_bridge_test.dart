import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
    FlutterSecureStorage.setMockInitialValues({});
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

  bool command(String entity, String payload) => applyMqttCommand(
    topics,
    topics.command(entity),
    payload,
    display(),
    container.read(settingsProvider.notifier),
  );

  Map<String, String> states() => topics.states(
    container.read(displayProvider),
    container.read(settingsProvider),
  );

  test('Home Assistant changes settings and sees them', () async {
    expect(command('slide_seconds', '30'), isTrue);
    expect(command('finished_speech', 'ON'), isTrue);
    expect(command('start_mode', 'dashboard'), isTrue);
    await pumpEventQueue();

    final settings = container.read(settingsProvider);
    expect(settings.slideSeconds, 30);
    expect(settings.isFinishedSpeechOn, isTrue);
    expect(settings.startMode, DisplayMode.dashboard);
    expect(states()['ha_display/abc123/slide_seconds/state'], '30');
    expect(states()['ha_display/abc123/finished_speech/state'], 'ON');
    expect(states()['ha_display/abc123/start_mode/state'], 'dashboard');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('slide_seconds'), 30);
  });

  test('settings from Home Assistant stay in range', () async {
    command('slide_seconds', '1');
    command('finished_speech_volume', '500');
    await pumpEventQueue();
    final settings = container.read(settingsProvider);
    expect(settings.slideSeconds, 5);
    expect(settings.finishedSpeechVolume, 100);
    expect(command('slide_seconds', 'many'), isFalse);
    expect(command('shuffle', 'maybe'), isFalse);
    expect(command('start_mode', 'nothing'), isFalse);
  });

  test('settings entities are listed as configuration', () {
    final config = jsonDecode(
      topics.discoveryConfigs(
        'Wohnzimmer',
      )['homeassistant/number/ha_display_abc123/finished_speech_volume/config']!,
    ) as Map<String, dynamic>;
    expect(config['entity_category'], 'config');
    expect(config['max'], 100);
    expect(config['unit_of_measurement'], '%');
  });

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
      expect(command('key_$key', 'PRESS'), isTrue);
      verify(() => kiosk.pressKey(key)).called(1);
    }
    command('media_volume', '130');
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
    command('brightness', '128');
    await pumpEventQueue();
    command('auto_brightness', 'ON');
    await pumpEventQueue();
    expect(container.read(displayProvider).isAutoBrightness, isTrue);
    verify(() => kiosk.setAutoBrightness(true)).called(1);
    verify(() => kiosk.setBrightness(null)).called(1);
  });

  test('a set brightness ends automatic brightness', () async {
    command('auto_brightness', 'ON');
    await pumpEventQueue();
    command('brightness', '51');
    await pumpEventQueue();
    expect(container.read(displayProvider).isAutoBrightness, isFalse);
    verify(() => kiosk.setAutoBrightness(false)).called(1);
    verify(() => kiosk.setBrightness(0.2)).called(1);
  });

  test('automatic brightness stays off without the permission', () async {
    when(() => kiosk.setAutoBrightness(any())).thenAnswer((_) async => false);
    command('auto_brightness', 'ON');
    await pumpEventQueue();
    expect(container.read(displayProvider).isAutoBrightness, isFalse);
  });

  test('screen OFF/ON commands switch the panel via the kiosk', () async {
    expect(command('screen', 'OFF'), isTrue);
    await pumpEventQueue();
    expect(container.read(displayProvider).isScreenOn, isFalse);
    verify(() => kiosk.screenOff()).called(1);

    command('screen', 'ON');
    await pumpEventQueue();
    expect(container.read(displayProvider).isScreenOn, isTrue);
    verify(() => kiosk.screenOn()).called(1);
  });

  test('without device owner, screen off blacks out instead', () async {
    when(() => kiosk.screenOff()).thenAnswer((_) async => false);

    command('screen', 'OFF');
    await pumpEventQueue();

    expect(container.read(displayProvider).isBlackedOut, isTrue);
    verify(() => kiosk.setBrightness(0)).called(1);
  });

  test('mode, brightness and buttons update the display state', () async {
    command('mode', 'dashboard');
    command('brightness', '128.0');
    command('next_photo', 'PRESS');
    await pumpEventQueue();

    final state = container.read(displayProvider);
    expect(state.mode, DisplayMode.dashboard);
    expect(state.brightness, 128);
    expect(state.nextPhotoRequests, 1);
    expect(
      topics.states(state, const Settings()),
      allOf(
        containsPair('ha_display/abc123/screen/state', 'ON'),
        containsPair('ha_display/abc123/child_lock/state', 'OFF'),
        containsPair('ha_display/abc123/private/state', 'OFF'),
        containsPair('ha_display/abc123/mode/state', 'dashboard'),
        containsPair('ha_display/abc123/auto_brightness/state', 'OFF'),
        containsPair('ha_display/abc123/media_volume/state', '40'),
        containsPair('ha_display/abc123/brightness/state', '128'),
      ),
    );
  });

  test('child lock keeps the screen as Home Assistant set it', () async {
    command('child_lock', 'ON');
    command('screen', 'OFF');
    await pumpEventQueue();
    verify(() => kiosk.setChildLock(true)).called(1);

    // The power button switched it on - the kiosk turns it off again.
    display().reportScreenOn(true);
    final state = container.read(displayProvider);
    expect(state.isChildLocked, isTrue);
    expect(state.isScreenOn, isFalse);
    expect(
      topics.states(
        state,
        const Settings(),
      )['ha_display/abc123/child_lock/state'],
      'ON',
    );
  });

  test('private mode survives a restart', () async {
    command('private', 'ON');
    await pumpEventQueue();
    expect(container.read(displayProvider).isPrivate, isTrue);

    container.invalidate(displayProvider);
    container.read(displayProvider);
    await pumpEventQueue();
    final state = container.read(displayProvider);
    expect(state.isPrivate, isTrue);
    expect(
      topics.states(state, const Settings())['ha_display/abc123/private/state'],
      'ON',
    );
  });

  test('private mode from yesterday is off after a restart', () async {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    SharedPreferences.setMockInitialValues({
      'private_mode': true,
      'private_mode_since': yesterday.millisecondsSinceEpoch,
    });
    container.invalidate(displayProvider);
    container.read(displayProvider);
    await pumpEventQueue();
    expect(container.read(displayProvider).isPrivate, isFalse);
  });

  test('ignores unknown payloads and topics', () {
    expect(command('mode', 'tv'), isFalse);
    expect(command('x', '1'), isFalse);
  });
}
