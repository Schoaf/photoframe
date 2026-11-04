import 'dart:async';
import 'dart:convert';

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import '../state/display_state.dart';
import '../state/settings.dart';

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
      'manufacturer': 'HA Display',
      'model': 'Android Tablet',
    };
    Map<String, Object> entity(String key, String name, String icon) => {
      'name': name,
      'unique_id': 'ha_display_${deviceId}_$key',
      'icon': icon,
      'availability_topic': availability,
      'device': device,
    };
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

  /// Retained state topics for [display].
  Map<String, String> states(DisplayState display) => {
    state('screen'): display.isScreenOn ? 'ON' : 'OFF',
    state('child_lock'): display.isChildLocked ? 'ON' : 'OFF',
    state('private'): display.isPrivate ? 'ON' : 'OFF',
    state('mode'): display.mode.name,
    if (display.brightness case final brightness?)
      state('brightness'): '$brightness',
  };
}

/// Applies one received command to the display. Returns false for unknown
/// topics/payloads.
bool applyMqttCommand(
  MqttTopics topics,
  String topic,
  String payload,
  DisplayNotifier display,
) {
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
    required this.currentState,
  });

  final Settings settings;
  final MqttTopics topics;
  final DisplayNotifier display;
  final DisplayState Function() currentState;
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
    publishState(currentState());
  }

  /// Publishes only what changed since the last call.
  void publishState(DisplayState state) {
    final states = topics.states(state);
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
      applyMqttCommand(topics, message.topic, payload, display);
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
