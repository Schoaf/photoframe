import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/mqtt_bridge.dart';
import 'display_state.dart';
import 'settings.dart';

const _kDeviceIdKey = 'device_id';

/// A random id generated on first launch - keeps the Home Assistant
/// entities stable even when the device is renamed.
Future<String> loadDeviceId() async {
  final prefs = await SharedPreferences.getInstance();
  final existing = prefs.getString(_kDeviceIdKey);
  if (existing != null) return existing;
  final random = Random.secure();
  final id = List.generate(
    6,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
  await prefs.setString(_kDeviceIdKey, id);
  return id;
}

/// Overridden in `main()` with [loadDeviceId]'s result.
final deviceIdProvider = Provider<String>((ref) => throw UnimplementedError());

/// Runs while the app runs (watched by the display screen); reconnects with
/// new settings when they change.
final mqttBridgeProvider = Provider<MqttBridge?>((ref) {
  final settings = ref.watch(settingsProvider);
  if (!settings.hasMqtt) return null;
  final bridge = MqttBridge(
    settings: settings,
    topics: MqttTopics(ref.watch(deviceIdProvider)),
    display: ref.read(displayProvider.notifier),
    currentState: () => ref.read(displayProvider),
  );
  ref.listen(displayProvider, (_, state) => bridge.publishState(state));
  bridge.start();
  ref.onDispose(bridge.stop);
  return bridge;
});
