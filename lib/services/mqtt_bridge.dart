import 'dart:async';
import 'dart:convert';

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import '../state/display_state.dart';
import '../state/settings.dart';

/// The tablet's keys Home Assistant can press: key, name, icon.
const _keys = [
  ('back', 'Key back', 'mdi:arrow-left'),
  ('home', 'Key home', 'mdi:home-outline'),
  ('recents', 'Key recent apps', 'mdi:view-sequential-outline'),
];

/// A number in the settings that Home Assistant can set.
class _NumberSetting {
  const _NumberSetting({
    required this.key,
    required this.name,
    required this.icon,
    required this.unit,
    required this.min,
    required this.max,
    required this.step,
    required this.read,
    required this.write,
  });

  final String key;
  final String name;
  final String icon;
  final String unit;
  final int min;
  final int max;
  final int step;
  final int Function(Settings) read;
  final Settings Function(Settings, int) write;
}

/// An on/off in the settings that Home Assistant can set.
class _SwitchSetting {
  const _SwitchSetting({
    required this.key,
    required this.name,
    required this.icon,
    required this.read,
    required this.write,
  });

  final String key;
  final String name;
  final String icon;
  final bool Function(Settings) read;
  final Settings Function(Settings, bool) write;
}

final _numberSettings = [
  _NumberSetting(
    key: 'slide_seconds',
    name: 'Seconds per photo',
    icon: 'mdi:timer-outline',
    unit: 's',
    min: 5,
    max: 120,
    step: 5,
    read: (settings) => settings.slideSeconds,
    write: (settings, value) => settings.copyWith(slideSeconds: value),
  ),
  _NumberSetting(
    key: 'idle_seconds',
    name: 'Back to photos after',
    icon: 'mdi:image-move',
    unit: 's',
    min: 30,
    max: 600,
    step: 30,
    read: (settings) => settings.idleSeconds,
    write: (settings, value) => settings.copyWith(idleSeconds: value),
  ),
  _NumberSetting(
    key: 'motion_screen_off_minutes',
    name: 'Screen off without motion after',
    icon: 'mdi:motion-sensor-off',
    unit: 'min',
    min: 0,
    max: 60,
    step: 1,
    read: (settings) => settings.motionScreenOffMinutes,
    write: (settings, value) =>
        settings.copyWith(motionScreenOffMinutes: value),
  ),
  _NumberSetting(
    key: 'motion_dark_level',
    name: 'Dark below brightness',
    icon: 'mdi:weather-night',
    unit: '',
    min: 0,
    max: 60,
    step: 1,
    read: (settings) => settings.motionDarkLevel,
    write: (settings, value) => settings.copyWith(motionDarkLevel: value),
  ),
  _NumberSetting(
    key: 'finished_speech_volume',
    name: 'Announcement volume',
    icon: 'mdi:account-voice',
    unit: '%',
    min: 0,
    max: 100,
    step: 5,
    read: (settings) => settings.finishedSpeechVolume,
    write: (settings, value) => settings.copyWith(finishedSpeechVolume: value),
  ),
];

final _switchSettings = [
  _SwitchSetting(
    key: 'shuffle',
    name: 'Shuffle photos',
    icon: 'mdi:shuffle',
    read: (settings) => settings.isShuffled,
    write: (settings, value) => settings.copyWith(isShuffled: value),
  ),
  _SwitchSetting(
    key: 'finished_flash',
    name: 'Appliance done: blink',
    icon: 'mdi:flash',
    read: (settings) => settings.isFinishedFlashOn,
    write: (settings, value) => settings.copyWith(isFinishedFlashOn: value),
  ),
  _SwitchSetting(
    key: 'finished_speech',
    name: 'Appliance done: announce',
    icon: 'mdi:account-voice',
    read: (settings) => settings.isFinishedSpeechOn,
    write: (settings, value) => settings.copyWith(isFinishedSpeechOn: value),
  ),
];

/// Topics and Home Assistant MQTT discovery for one tablet. Pure, so it can
/// be tested without a broker.
class MqttTopics {
  const MqttTopics(this.deviceId);

  final String deviceId;

  String get base => 'ha_display/$deviceId';
  String get availability => '$base/availability';
  String state(String entity) => '$base/$entity/state';
  String command(String entity) => '$base/$entity/set';

  /// Retained discovery configs: topic → payload. Entity ids become e.g.
  /// `switch.<device name>_screen`.
  Map<String, String> discoveryConfigs(String deviceName) {
    final device = {
      'identifiers': ['ha_display_$deviceId'],
      'name': deviceName,
      'manufacturer': 'PhotoFrame',
      'model': 'Android Tablet',
    };
    Map<String, Object> entity(String key, String name, String icon) => {
      'name': name,
      'unique_id': 'ha_display_${deviceId}_$key',
      'icon': icon,
      'availability_topic': availability,
      'device': device,
    };
    // Listed under "Configuration" on the device's page in Home Assistant.
    const config = {'entity_category': 'config'};
    String topic(String component, String key) =>
        'homeassistant/$component/ha_display_$deviceId/$key/config';
    return {
      topic('switch', 'screen'): jsonEncode({
        ...entity('screen', 'Screen', 'mdi:tablet'),
        'state_topic': state('screen'),
        'command_topic': command('screen'),
      }),
      topic('switch', 'child_lock'): jsonEncode({
        ...entity('child_lock', 'Child lock', 'mdi:lock-outline'),
        'state_topic': state('child_lock'),
        'command_topic': command('child_lock'),
      }),
      topic('switch', 'private'): jsonEncode({
        ...entity('private', 'Private mode', 'mdi:eye-off-outline'),
        'state_topic': state('private'),
        'command_topic': command('private'),
      }),
      topic('select', 'mode'): jsonEncode({
        ...entity('mode', 'Mode', 'mdi:view-dashboard-variant'),
        'state_topic': state('mode'),
        'command_topic': command('mode'),
        'options': [for (final mode in DisplayMode.values) mode.name],
      }),
      topic('number', 'brightness'): jsonEncode({
        ...entity('brightness', 'Brightness', 'mdi:brightness-6'),
        'state_topic': state('brightness'),
        'command_topic': command('brightness'),
        'min': 0,
        'max': 255,
        'mode': 'slider',
      }),
      topic('switch', 'auto_brightness'): jsonEncode({
        ...entity(
          'auto_brightness',
          'Automatic brightness',
          'mdi:brightness-auto',
        ),
        'state_topic': state('auto_brightness'),
        'command_topic': command('auto_brightness'),
      }),
      topic('number', 'media_volume'): jsonEncode({
        ...entity('media_volume', 'Media volume', 'mdi:volume-high'),
        'state_topic': state('media_volume'),
        'command_topic': command('media_volume'),
        'min': 0,
        'max': 100,
        'mode': 'slider',
        'unit_of_measurement': '%',
      }),
      for (final (key, name, icon) in _keys)
        topic('button', 'key_$key'): jsonEncode({
          ...entity('key_$key', name, icon),
          'command_topic': command('key_$key'),
        }),
      for (final setting in _numberSettings)
        topic('number', setting.key): jsonEncode({
          ...entity(setting.key, setting.name, setting.icon),
          ...config,
          'state_topic': state(setting.key),
          'command_topic': command(setting.key),
          'min': setting.min,
          'max': setting.max,
          'step': setting.step,
          'mode': 'slider',
          if (setting.unit.isNotEmpty) 'unit_of_measurement': setting.unit,
        }),
      for (final setting in _switchSettings)
        topic('switch', setting.key): jsonEncode({
          ...entity(setting.key, setting.name, setting.icon),
          ...config,
          'state_topic': state(setting.key),
          'command_topic': command(setting.key),
        }),
      topic('select', 'start_mode'): jsonEncode({
        ...entity('start_mode', 'Start mode', 'mdi:play-box-outline'),
        ...config,
        'state_topic': state('start_mode'),
        'command_topic': command('start_mode'),
        'options': [for (final mode in DisplayMode.values) mode.name],
      }),
      topic('button', 'speech_test'): jsonEncode({
        ...entity('speech_test', 'Test announcement', 'mdi:account-voice'),
        ...config,
        'command_topic': command('speech_test'),
      }),
      topic('button', 'next_photo'): jsonEncode({
        ...entity('next_photo', 'Next photo', 'mdi:skip-next'),
        'command_topic': command('next_photo'),
      }),
      topic('button', 'reload'): jsonEncode({
        ...entity('reload', 'Reload', 'mdi:reload'),
        'command_topic': command('reload'),
      }),
    };
  }

  /// Retained state topics for [display] and [settings].
  Map<String, String> states(DisplayState display, Settings settings) => {
    for (final setting in _numberSettings)
      state(setting.key): '${setting.read(settings)}',
    for (final setting in _switchSettings)
      state(setting.key): setting.read(settings) ? 'ON' : 'OFF',
    state('start_mode'): settings.startMode.name,
    state('screen'): display.isScreenOn ? 'ON' : 'OFF',
    state('child_lock'): display.isChildLocked ? 'ON' : 'OFF',
    state('private'): display.isPrivate ? 'ON' : 'OFF',
    state('mode'): display.mode.name,
    state('auto_brightness'): display.isAutoBrightness ? 'ON' : 'OFF',
    if (display.brightness case final brightness?)
      state('brightness'): '$brightness',
    if (display.mediaVolume case final volume?)
      state('media_volume'): '$volume',
  };
}

/// Applies one received command to the display or the settings. Returns
/// false for unknown topics/payloads.
bool applyMqttCommand(
  MqttTopics topics,
  String topic,
  String payload,
  DisplayNotifier display,
  SettingsNotifier settings,
) {
  for (final setting in _numberSettings) {
    if (topic != topics.command(setting.key)) continue;
    final value = double.tryParse(payload);
    if (value == null) return false;
    final number = value.round().clamp(setting.min, setting.max);
    settings.change((current) => setting.write(current, number));
    return true;
  }
  for (final setting in _switchSettings) {
    if (topic != topics.command(setting.key)) continue;
    if (payload != 'ON' && payload != 'OFF') return false;
    settings.change((current) => setting.write(current, payload == 'ON'));
    return true;
  }
  if (topic == topics.command('screen')) {
    if (payload != 'ON' && payload != 'OFF') return false;
    display.setScreenOn(payload == 'ON');
  } else if (topic == topics.command('child_lock')) {
    if (payload != 'ON' && payload != 'OFF') return false;
    display.setChildLock(payload == 'ON');
  } else if (topic == topics.command('private')) {
    if (payload != 'ON' && payload != 'OFF') return false;
    display.setPrivate(payload == 'ON');
  } else if (topic == topics.command('mode')) {
    final mode = DisplayMode.values.asNameMap()[payload];
    if (mode == null) return false;
    display.setMode(mode);
  } else if (topic == topics.command('brightness')) {
    final brightness = double.tryParse(payload);
    if (brightness == null) return false;
    display.setBrightness(brightness.round());
  } else if (topic == topics.command('auto_brightness')) {
    if (payload != 'ON' && payload != 'OFF') return false;
    display.setAutoBrightness(payload == 'ON');
  } else if (topic == topics.command('media_volume')) {
    final volume = double.tryParse(payload);
    if (volume == null) return false;
    display.setMediaVolume(volume.round());
  } else if (_keys.any((key) => topic == topics.command('key_${key.$1}'))) {
    display.pressKey(topic.split('/')[2].substring('key_'.length));
  } else if (topic == topics.command('start_mode')) {
    final mode = DisplayMode.values.asNameMap()[payload];
    if (mode == null) return false;
    settings.change((current) => current.copyWith(startMode: mode));
  } else if (topic == topics.command('speech_test')) {
    display.requestSpeechTest();
  } else if (topic == topics.command('next_photo')) {
    display.requestNextPhoto();
  } else if (topic == topics.command('reload')) {
    display.requestReload();
  } else {
    return false;
  }
  return true;
}

/// Keeps the tablet connected to the broker: announces it to Home Assistant,
/// reports the display state and executes commands.
class MqttBridge {
  MqttBridge({
    required this.settings,
    required this.topics,
    required this.display,
    required this.settingsNotifier,
    required this.currentState,
    required this.currentSettings,
  });

  final Settings settings;
  final MqttTopics topics;
  final DisplayNotifier display;
  final SettingsNotifier settingsNotifier;
  final DisplayState Function() currentState;
  final Settings Function() currentSettings;
  MqttServerClient? _client;
  StreamSubscription<List<MqttReceivedMessage<MqttMessage>>>? _updates;
  Map<String, String> _lastStates = const {};

  Future<void> start() async {
    final client =
        MqttServerClient.withPort(
            settings.mqttHost,
            'ha_display_${topics.deviceId}',
            settings.mqttPort,
          )
          ..keepAlivePeriod = 30
          ..autoReconnect = true
          ..logging(on: false)
          ..onConnected = _announce
          ..onAutoReconnected = _announce;
    client.connectionMessage = MqttConnectMessage()
        .withClientIdentifier('ha_display_${topics.deviceId}')
        .withWillTopic(topics.availability)
        .withWillMessage('offline')
        .withWillRetain()
        .withWillQos(MqttQos.atLeastOnce)
        .startClean();
    _client = client;
    await _connect(client);
  }

  Future<void> _connect(MqttServerClient client) async {
    while (_client == client) {
      try {
        await client.connect(
          settings.mqttUser.isEmpty ? null : settings.mqttUser,
          settings.mqttPassword.isEmpty ? null : settings.mqttPassword,
        );
        if (client.connectionStatus?.state == MqttConnectionState.connected) {
          _updates = client.updates?.listen(_onMessages);
          client.subscribe('${topics.base}/+/set', MqttQos.atLeastOnce);
          return;
        }
      } on Exception {
        client.disconnect();
      }
      // Broker not reachable (yet) - e.g. Home Assistant still booting.
      await Future<void>.delayed(const Duration(seconds: 30));
    }
  }

  void _announce() {
    for (final MapEntry(:key, :value)
        in topics.discoveryConfigs(settings.deviceName).entries) {
      _publish(key, value);
    }
    _publish(topics.availability, 'online');
    _lastStates = const {};
    publishState();
  }

  /// Publishes only what changed since the last call.
  void publishState() {
    final states = topics.states(currentState(), currentSettings());
    for (final MapEntry(:key, :value) in states.entries) {
      if (_lastStates[key] != value) _publish(key, value);
    }
    _lastStates = states;
  }

  void _onMessages(List<MqttReceivedMessage<MqttMessage>> messages) {
    for (final message in messages) {
      final publish = message.payload as MqttPublishMessage;
      final payload = MqttPublishPayload.bytesToStringAsString(
        publish.payload.message,
      ).trim();
      applyMqttCommand(
        topics,
        message.topic,
        payload,
        display,
        settingsNotifier,
      );
    }
  }

  void _publish(String topic, String payload) {
    final client = _client;
    if (client?.connectionStatus?.state != MqttConnectionState.connected) {
      return;
    }
    client!.publishMessage(
      topic,
      MqttQos.atLeastOnce,
      (MqttClientPayloadBuilder()..addUTF8String(payload)).payload!,
      retain: true,
    );
  }

  void stop() {
    _publish(topics.availability, 'offline');
    _updates?.cancel();
    final client = _client;
    _client = null;
    client?.disconnect();
  }
}
