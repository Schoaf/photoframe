import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../state/display_state.dart';
import '../state/motion.dart';
import '../state/mqtt.dart';
import '../state/settings.dart';
import '../state/updates.dart';
import '../utils/tap_sequence.dart';
import '../widgets/pin_dialog.dart';
import 'dashboard/dashboard_screen.dart';
import 'menu_screen.dart';
import 'photo_frame/photo_frame_screen.dart';

/// Size of the invisible top-left corner that unlocks the menu.
const _unlockCornerSize = 96.0;

/// The kiosk's root: the photos are the resting state, the dashboard lies
/// below them and keeps rendering (so it appears at once - the tablet is
/// slow to redraw a hidden one) and gives way to the photos again when
/// nobody touches it. Plus the hidden way into the menu. Back
/// does nothing here.
class DisplayScreen extends ConsumerStatefulWidget {
  const DisplayScreen({super.key});

  @override
  ConsumerState<DisplayScreen> createState() => _DisplayScreenState();
}

class _DisplayScreenState extends ConsumerState<DisplayScreen>
    with WidgetsBindingObserver {
  final _unlockTaps = TapSequence();
  Timer? _idleTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _idleTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The power button (or lockNow) pauses the app; tell Home Assistant.
    final display = ref.read(displayProvider.notifier);
    if (state == AppLifecycleState.resumed) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      display.reportScreenOn(true);
    } else if (state == AppLifecycleState.paused) {
      display.reportScreenOn(false);
    }
  }

  /// Any touch restarts the countdown back to the photos.
  void _resetIdleTimer() {
    _idleTimer?.cancel();
    final settings = ref.read(settingsProvider);
    if (!settings.hasPhotos ||
        ref.read(displayProvider).mode != DisplayMode.dashboard) {
      return;
    }
    _idleTimer = Timer(Duration(seconds: settings.idleSeconds), _showPhotos);
  }

  void _showPhotos() =>
      ref.read(displayProvider.notifier).setMode(DisplayMode.photos);

  Future<void> _onCornerTap() async {
    if (!_unlockTaps.register(DateTime.now())) return;
    final pin = ref.read(settingsProvider).pin;
    if (!await showPinDialog(context, pin: pin) || !mounted) return;
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const MenuScreen()));
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  Widget build(BuildContext context) {
    // Keeps the MQTT connection alive as long as the display exists.
    ref.watch(mqttBridgeProvider);
    ref.watch(motionScreenOffProvider);
    ref.watch(autoUpdateProvider);
    ref.listen(
      displayProvider.select((display) => display.mode),
      (_, _) => _resetIdleTimer(),
    );
    final display = ref.watch(displayProvider);
    final settings = ref.watch(settingsProvider);
    final isDashboardShown = display.mode == DisplayMode.dashboard;
    return PopScope(
      canPop: false,
      child: Listener(
        onPointerDown: (_) => _resetIdleTimer(),
        child: Scaffold(
          body: Stack(
            fit: StackFit.expand,
            children: [
              if (settings.hasDashboard)
                IgnorePointer(
                  ignoring: !isDashboardShown,
                  child: const DashboardScreen(),
                ),
              if (settings.hasPhotos)
                Offstage(
                  offstage: isDashboardShown,
                  // Opaque, so the dashboard doesn't show around the photos.
                  child: const ColoredBox(
                    color: Colors.black,
                    child: PhotoFrameScreen(),
                  ),
                ),
              if (isDashboardShown && settings.hasPhotos)
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: Opacity(
                    opacity: 0.7,
                    child: FloatingActionButton(
                      onPressed: _showPhotos,
                      tooltip: AppLocalizations.of(context).showPhotos,
                      child: const Icon(Icons.photo),
                    ),
                  ),
                ),
              if (display.isBlackedOut)
                GestureDetector(
                  // A touch wakes it, like the power button would.
                  onTap: () =>
                      ref.read(displayProvider.notifier).setScreenOn(true),
                  child: const ColoredBox(color: Colors.black),
                ),
              Positioned(
                left: 0,
                top: 0,
                width: _unlockCornerSize,
                height: _unlockCornerSize,
                // Only counts touches - the agenda below still gets its tap.
                child: Listener(
                  behavior: HitTestBehavior.translucent,
                  onPointerDown: (_) => _onCornerTap(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
