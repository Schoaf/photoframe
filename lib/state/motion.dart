import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'display_state.dart';
import 'settings.dart';

/// Switches the screen off after [timeout] without motion, and on again at
/// the next motion - but only when it switched it off itself, so an "off"
/// from Home Assistant or the power button stays off.
class MotionScreenOff {
  MotionScreenOff({
    required this.timeout,
    required this.display,
    required this.currentState,
    required DateTime now,
  }) : _lastMotion = now;

  final Duration timeout;
  final DisplayNotifier display;
  final DisplayState Function() currentState;
  DateTime _lastMotion;
  bool _isOffByMotion = false;

  void onMotion(DateTime now) {
    _lastMotion = now;
    if (!_isOffByMotion) return;
    _isOffByMotion = false;
    display.setScreenOn(true);
  }

  /// Someone else switched the screen on - the countdown starts over.
  void onScreenOn(DateTime now) {
    _lastMotion = now;
    _isOffByMotion = false;
  }

  void check(DateTime now) {
    if (!currentState().isScreenOn) return;
    if (now.difference(_lastMotion) < timeout) return;
    _isOffByMotion = true;
    display.setScreenOn(false);
  }
}

/// Runs while the display exists and the setting is on (watched by the
/// display screen).
final motionScreenOffProvider = Provider<void>((ref) {
  final minutes = ref.watch(
    settingsProvider.select((settings) => settings.motionScreenOffMinutes),
  );
  if (minutes <= 0) return;
  final kiosk = ref.read(kioskProvider);
  final watcher = MotionScreenOff(
    timeout: Duration(minutes: minutes),
    display: ref.read(displayProvider.notifier),
    currentState: () => ref.read(displayProvider),
    now: DateTime.now(),
  );
  ref.listen(displayProvider.select((display) => display.isScreenOn), (
    _,
    isOn,
  ) {
    if (isOn) watcher.onScreenOn(DateTime.now());
  });
  kiosk.startMotion(() => watcher.onMotion(DateTime.now()));
  final timer = Timer.periodic(
    const Duration(seconds: 30),
    (_) => watcher.check(DateTime.now()),
  );
  ref.onDispose(() {
    timer.cancel();
    kiosk.stopMotion();
  });
});
