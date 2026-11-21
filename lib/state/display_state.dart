import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/kiosk.dart';
import 'settings.dart';

/// What the tablet shows right now - changed by the menu and by Home
/// Assistant (MQTT) alike.
class DisplayState {
  const DisplayState({
    required this.mode,
    this.isScreenOn = true,
    this.isBlackedOut = false,
    this.isChildLocked = false,
    this.isPrivate = false,
    this.brightness,
    this.isAutoBrightness = false,
    this.mediaVolume,
    this.isKioskEnded = false,
    this.nextPhotoRequests = 0,
    this.reloadRequests = 0,
    this.speechTestRequests = 0,
    this.dashboardView,
    this.viewRequests = 0,
  });

  final DisplayMode mode;
  final bool isScreenOn;

  /// Screen "off" without device owner: a black overlay at minimum
  /// brightness instead of the panel really switching off.
  final bool isBlackedOut;

  /// The power and volume keys do nothing and the photos can't be swiped -
  /// only Home Assistant switches the screen.
  final bool isChildLocked;

  /// Private mode: the agenda isn't shown. Ends at midnight, in case it's
  /// forgotten.
  final bool isPrivate;

  /// 0..255, null for the system brightness.
  final int? brightness;

  /// Android's light sensor sets the brightness; [brightness] doesn't apply.
  final bool isAutoBrightness;

  /// In percent, null until read.
  final int? mediaVolume;

  /// "Kiosk beenden": the app runs behind the others until it's opened again.
  final bool isKioskEnded;

  /// Bumped per "next photo" / "reload" / "test announcement" command; screens react to changes.
  final int nextPhotoRequests;
  final int reloadRequests;
  final int speechTestRequests;

  /// Dashboard view to show (e.g. `wetter`), null for the main view; the
  /// dashboard switches to it whenever [viewRequests] changes.
  final String? dashboardView;
  final int viewRequests;

  DisplayState copyWith({
    DisplayMode? mode,
    bool? isScreenOn,
    bool? isBlackedOut,
    bool? isChildLocked,
    bool? isPrivate,
    int? brightness,
    bool? isAutoBrightness,
    int? mediaVolume,
    bool? isKioskEnded,
    int? nextPhotoRequests,
    int? reloadRequests,
    int? speechTestRequests,
    String? Function()? dashboardView,
    int? viewRequests,
  }) => DisplayState(
    mode: mode ?? this.mode,
    isScreenOn: isScreenOn ?? this.isScreenOn,
    isBlackedOut: isBlackedOut ?? this.isBlackedOut,
    isChildLocked: isChildLocked ?? this.isChildLocked,
    isPrivate: isPrivate ?? this.isPrivate,
    brightness: brightness ?? this.brightness,
    isAutoBrightness: isAutoBrightness ?? this.isAutoBrightness,
    mediaVolume: mediaVolume ?? this.mediaVolume,
    isKioskEnded: isKioskEnded ?? this.isKioskEnded,
    nextPhotoRequests: nextPhotoRequests ?? this.nextPhotoRequests,
    reloadRequests: reloadRequests ?? this.reloadRequests,
    speechTestRequests: speechTestRequests ?? this.speechTestRequests,
    dashboardView: dashboardView != null ? dashboardView() : this.dashboardView,
    viewRequests: viewRequests ?? this.viewRequests,
  );
}

final kioskProvider = Provider<Kiosk>((ref) => const Kiosk());

class DisplayNotifier extends Notifier<DisplayState> {
  Kiosk get _kiosk => ref.read(kioskProvider);
  Timer? _privateEnd;

  @override
  DisplayState build() {
    final settings = ref.read(settingsProvider);
    // Kept natively, so a reboot doesn't lift it.
    _kiosk.isChildLocked().then((isLocked) {
      if (isLocked) state = state.copyWith(isChildLocked: true);
    });
    _kiosk.mediaVolume().then((volume) {
      state = state.copyWith(mediaVolume: volume);
    });
    // Android keeps it across restarts.
    _kiosk.isAutoBrightness().then((isAuto) {
      if (isAuto) state = state.copyWith(isAutoBrightness: true);
    });
    ref.onDispose(() => _privateEnd?.cancel());
    SharedPreferences.getInstance().then((prefs) {
      if (!(prefs.getBool(_privateKey) ?? false)) return;
      final since = prefs.getInt(_privateSinceKey);
      if (since != null &&
          _isBeforeToday(DateTime.fromMillisecondsSinceEpoch(since))) {
        setPrivate(false);
      } else {
        state = state.copyWith(isPrivate: true);
        _endPrivateAtMidnight();
      }
    });
    return DisplayState(mode: _availableMode(settings, settings.startMode));
  }

  void setMode(DisplayMode mode) => state = state.copyWith(
    mode: _availableMode(ref.read(settingsProvider), mode),
  );

  /// Shows the dashboard at [view] (a view path like `wetter`), or at its
  /// main view.
  void openDashboard([String? view]) => state = state.copyWith(
    mode: _availableMode(ref.read(settingsProvider), DisplayMode.dashboard),
    dashboardView: () => view == null || view.isEmpty ? null : view,
    viewRequests: state.viewRequests + 1,
  );

  Future<void> setScreenOn(bool isOn) async {
    if (isOn == state.isScreenOn) return;
    if (isOn) {
      state = state.copyWith(isScreenOn: true, isBlackedOut: false);
      await _kiosk.setBrightness(_windowBrightness);
      await _kiosk.screenOn();
    } else {
      final isReallyOff = await _kiosk.screenOff();
      state = state.copyWith(isScreenOn: false, isBlackedOut: !isReallyOff);
      if (!isReallyOff) await _kiosk.setBrightness(0);
    }
  }

  Future<void> endKiosk() async {
    state = state.copyWith(isKioskEnded: true);
    await _kiosk.stopLock();
  }

  void reportResumed() {
    state = state.copyWith(isKioskEnded: false);
    reportScreenOn(true);
  }

  /// The power button switched the panel on/off by hand - under child lock
  /// the kiosk switches it right back. Going behind other apps isn't "off".
  void reportScreenOn(bool isOn) {
    if (state.isKioskEnded) return;
    if (isOn == state.isScreenOn || state.isBlackedOut) return;
    if (state.isChildLocked) return;
    state = state.copyWith(isScreenOn: isOn);
  }

  Future<void> setChildLock(bool isLocked) async {
    state = state.copyWith(isChildLocked: isLocked);
    await _kiosk.setChildLock(isLocked);
  }

  Future<void> setPrivate(bool isPrivate) async {
    state = state.copyWith(isPrivate: isPrivate);
    _privateEnd?.cancel();
    if (isPrivate) _endPrivateAtMidnight();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_privateKey, isPrivate);
    await prefs.setInt(_privateSinceKey, DateTime.now().millisecondsSinceEpoch);
  }

  void _endPrivateAtMidnight() {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    _privateEnd = Timer(midnight.difference(now), () => setPrivate(false));
  }

  static bool _isBeforeToday(DateTime time) {
    final now = DateTime.now();
    return time.isBefore(DateTime(now.year, now.month, now.day));
  }

  Future<void> setBrightness(int brightness) async {
    state = state.copyWith(
      brightness: brightness.clamp(0, 255),
      isAutoBrightness: false,
    );
    await _kiosk.setAutoBrightness(false);
    if (state.isScreenOn) await _kiosk.setBrightness(_windowBrightness);
  }

  /// Stays off when the app may not change it - Home Assistant then shows
  /// the switch off.
  Future<void> setAutoBrightness(bool isOn) async {
    if (!await _kiosk.setAutoBrightness(isOn)) return;
    state = state.copyWith(isAutoBrightness: isOn);
    if (state.isScreenOn) await _kiosk.setBrightness(_windowBrightness);
  }

  Future<void> setMediaVolume(int percent) async {
    state = state.copyWith(mediaVolume: percent.clamp(0, 100));
    await _kiosk.setMediaVolume(state.mediaVolume!);
  }

  Future<void> pressKey(String key) => _kiosk.pressKey(key);

  void requestNextPhoto() =>
      state = state.copyWith(nextPhotoRequests: state.nextPhotoRequests + 1);

  void requestReload() =>
      state = state.copyWith(reloadRequests: state.reloadRequests + 1);

  void requestSpeechTest() =>
      state = state.copyWith(speechTestRequests: state.speechTestRequests + 1);

  static const _privateKey = 'private_mode';
  static const _privateSinceKey = 'private_mode_since';

  /// null leaves the brightness to Android.
  double? get _windowBrightness => switch (state) {
    DisplayState(isAutoBrightness: true) => null,
    DisplayState(:final brightness?) => brightness / 255,
    _ => null,
  };

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
