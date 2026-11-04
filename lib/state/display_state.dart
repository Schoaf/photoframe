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
    this.nextPhotoRequests = 0,
    this.reloadRequests = 0,
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

  /// Private mode: the agenda isn't shown.
  final bool isPrivate;

  /// 0..255, null for the system brightness.
  final int? brightness;

  /// Bumped per "next photo" / "reload" command; screens react to changes.
  final int nextPhotoRequests;
  final int reloadRequests;

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
    int? nextPhotoRequests,
    int? reloadRequests,
    String? Function()? dashboardView,
    int? viewRequests,
  }) => DisplayState(
    mode: mode ?? this.mode,
    isScreenOn: isScreenOn ?? this.isScreenOn,
    isBlackedOut: isBlackedOut ?? this.isBlackedOut,
    isChildLocked: isChildLocked ?? this.isChildLocked,
    isPrivate: isPrivate ?? this.isPrivate,
    brightness: brightness ?? this.brightness,
    nextPhotoRequests: nextPhotoRequests ?? this.nextPhotoRequests,
    reloadRequests: reloadRequests ?? this.reloadRequests,
    dashboardView: dashboardView != null ? dashboardView() : this.dashboardView,
    viewRequests: viewRequests ?? this.viewRequests,
  );
}

final kioskProvider = Provider<Kiosk>((ref) => const Kiosk());

class DisplayNotifier extends Notifier<DisplayState> {
  Kiosk get _kiosk => ref.read(kioskProvider);

  @override
  DisplayState build() {
    final settings = ref.read(settingsProvider);
    // Kept natively, so a reboot doesn't lift it.
    _kiosk.isChildLocked().then((isLocked) {
      if (isLocked) state = state.copyWith(isChildLocked: true);
    });
    SharedPreferences.getInstance().then((prefs) {
      if (prefs.getBool(_privateKey) ?? false) {
        state = state.copyWith(isPrivate: true);
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
      await _kiosk.setBrightness(_brightnessValue(state.brightness));
      await _kiosk.screenOn();
    } else {
      final isReallyOff = await _kiosk.screenOff();
      state = state.copyWith(isScreenOn: false, isBlackedOut: !isReallyOff);
      if (!isReallyOff) await _kiosk.setBrightness(0);
    }
  }

  /// The power button switched the panel on/off by hand - under child lock
  /// the kiosk switches it right back.
  void reportScreenOn(bool isOn) {
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_privateKey, isPrivate);
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

  static const _privateKey = 'private_mode';

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
