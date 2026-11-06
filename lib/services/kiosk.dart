import 'package:flutter/services.dart';

/// Dart side of the native kiosk (android/.../Kiosk.kt).
class Kiosk {
  const Kiosk([this._channel = const MethodChannel('ha_display/kiosk')]);

  final MethodChannel _channel;

  Future<void> startLock() => _channel.invokeMethod('startLock');

  Future<void> stopLock() => _channel.invokeMethod('stopLock');

  /// false when the screen can't really be switched off (not device owner).
  Future<bool> screenOff() async =>
      await _channel.invokeMethod<bool>('screenOff') ?? false;

  Future<void> screenOn() => _channel.invokeMethod('screenOn');

  /// Hardware keys do nothing, only Home Assistant switches the screen.
  Future<void> setChildLock(bool isLocked) =>
      _channel.invokeMethod('setChildLock', {'value': isLocked});

  Future<bool> isChildLocked() async =>
      await _channel.invokeMethod<bool>('isChildLocked') ?? false;

  /// Says [text] at [volume] (0..1) of the media volume's maximum, which
  /// goes back afterwards; [languageTag] e.g. `de`.
  Future<void> speak(String text, String languageTag, double volume) =>
      _channel.invokeMethod('speak', {
        'text': text,
        'languageTag': languageTag,
        'volume': volume,
      });

  /// Watches the room through the front camera; [onMotion] runs per motion
  /// (at most every 2 s), also while the screen is off. Below [darkLevel]
  /// (mean brightness 0-255) the room counts as dark and nothing counts.
  Future<void> startMotion(void Function() onMotion, {required int darkLevel}) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'motion') onMotion();
    });
    return _channel.invokeMethod('startMotion', {'darkLevel': darkLevel});
  }

  Future<void> stopMotion() {
    _channel.setMethodCallHandler(null);
    return _channel.invokeMethod('stopMotion');
  }

  /// [value] in 0..1, null for the system brightness.
  Future<void> setBrightness(double? value) =>
      _channel.invokeMethod('setBrightness', {'value': value});

  /// Android's own automatic brightness, set by the light sensor.
  Future<bool> isAutoBrightness() async =>
      await _channel.invokeMethod<bool>('isAutoBrightness') ?? false;

  /// false when the app may not change it (README: adb step).
  Future<bool> setAutoBrightness(bool isOn) async =>
      await _channel.invokeMethod<bool>('setAutoBrightness', {'value': isOn}) ??
      false;

  Future<bool> isDeviceOwner() async =>
      await _channel.invokeMethod<bool>('isDeviceOwner') ?? false;

  Future<void> removeDeviceOwner() =>
      _channel.invokeMethod('removeDeviceOwner');

  /// versionCode of the installed app (the `+N` in pubspec.yaml).
  Future<int> versionCode() async =>
      await _channel.invokeMethod<int>('versionCode') ?? 0;

  /// Installs the APK at [path] over this app - silently as device owner.
  Future<void> installUpdate(String path) =>
      _channel.invokeMethod('installUpdate', {'path': path});
}
