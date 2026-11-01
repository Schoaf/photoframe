import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/kiosk.dart';
import 'settings.dart';

/// What the tablet shows right now - changed by the menu and by Home
/// Assistant (MQTT) alike.
class DisplayState {
  const DisplayState({
    required this.mode,
    this.isScreenOn = true,
    this.isBlackedOut = false,
    this.brightness,
    this.nextPhotoRequests = 0,
    this.reloadRequests = 0,
  });

  final DisplayMode mode;
  final bool isScreenOn;

  /// Screen "off" without device owner: a black overlay at minimum
  /// brightness instead of the panel really switching off.
  final bool isBlackedOut;

  /// 0..255, null for the system brightness.
  final int? brightness;

  /// Bumped per "next photo" / "reload" command; screens react to changes.
  final int nextPhotoRequests;
  final int reloadRequests;

  DisplayState copyWith({
    DisplayMode? mode,
    bool? isScreenOn,
    bool? isBlackedOut,
    int? brightness,
    int? nextPhotoRequests,
    int? reloadRequests,
  }) => DisplayState(
    mode: mode ?? this.mode,
    isScreenOn: isScreenOn ?? this.isScreenOn,
    isBlackedOut: isBlackedOut ?? this.isBlackedOut,
    brightness: brightness ?? this.brightness,
    nextPhotoRequests: nextPhotoRequests ?? this.nextPhotoRequests,
    reloadRequests: reloadRequests ?? this.reloadRequests,
  );
}

final kioskProvider = Provider<Kiosk>((ref) => const Kiosk());

class DisplayNotifier extends Notifier<DisplayState> {
  Kiosk get _kiosk => ref.read(kioskProvider);

  @override
  DisplayState build() {
    final settings = ref.read(settingsProvider);
    return DisplayState(mode: _availableMode(settings, settings.startMode));
  }

  void setMode(DisplayMode mode) => state = state.copyWith(
    mode: _availableMode(ref.read(settingsProvider), mode),
  );

  Future<void> setScreenOn(bool isOn) async {
    if (isOn == state.isScreenOn) return;
    if (isOn) {
      state = state.copyWith(isScreenOn: true, isBlackedOut: false);
      await _kiosk.setBrightness(_brightnessValue(state.brightness));
      await _kiosk.screenOn();
    } else {
      final isReallyOff = await _kiosk.screenOff();
      state = state.copyWith(isScreenOn: false, isBlackedOut: !isReallyOff);
      if (!isReallyOff) await _kiosk.setBrightness(0);
    }
  }

  /// The power button switched the panel on/off by hand.
  void reportScreenOn(bool isOn) {
    if (isOn == state.isScreenOn || state.isBlackedOut) return;
    state = state.copyWith(isScreenOn: isOn);
  }

  Future<void> setBrightness(int brightness) async {
    state = state.copyWith(brightness: brightness.clamp(0, 255));
    if (state.isScreenOn) {
      await _kiosk.setBrightness(_brightnessValue(state.brightness));
    }
  }

  void requestNextPhoto() =>
      state = state.copyWith(nextPhotoRequests: state.nextPhotoRequests + 1);

  void requestReload() =>
      state = state.copyWith(reloadRequests: state.reloadRequests + 1);

  static double? _brightnessValue(int? brightness) =>
      brightness == null ? null : brightness / 255;

  /// Falls back to the other mode when the wanted one isn't configured.
  static DisplayMode _availableMode(Settings settings, DisplayMode wanted) =>
      switch (wanted) {
        DisplayMode.photos when !settings.hasPhotos && settings.hasDashboard =>
          DisplayMode.dashboard,
        DisplayMode.dashboard
            when !settings.hasDashboard && settings.hasPhotos =>
          DisplayMode.photos,
        _ => wanted,
      };
}

final displayProvider = NotifierProvider<DisplayNotifier, DisplayState>(
  DisplayNotifier.new,
);
