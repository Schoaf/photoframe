import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/display_state.dart';
import '../state/mqtt.dart';
import '../state/settings.dart';
import '../utils/tap_sequence.dart';
import '../widgets/pin_dialog.dart';
import 'dashboard/dashboard_screen.dart';
import 'menu_screen.dart';
import 'photo_frame/photo_frame_screen.dart';

/// Size of the invisible top-left corner that unlocks the menu.
const _unlockCornerSize = 96.0;

/// The kiosk's root: photos or dashboard, plus the hidden way into the
/// menu. Back does nothing here.
class DisplayScreen extends ConsumerStatefulWidget {
  const DisplayScreen({super.key});

  @override
  ConsumerState<DisplayScreen> createState() => _DisplayScreenState();
}

class _DisplayScreenState extends ConsumerState<DisplayScreen>
    with WidgetsBindingObserver {
  final _unlockTaps = TapSequence();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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

  Future<void> _onCornerTap() async {
    if (!_unlockTaps.register(DateTime.now())) return;
    final pin = ref.read(settingsProvider).pin;
    if (!await showPinDialog(context, pin: pin) || !mounted) return;
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const MenuScreen()));
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  Widget build(BuildContext context) {
    // Keeps the MQTT connection alive as long as the display exists.
    ref.watch(mqttBridgeProvider);
    final display = ref.watch(displayProvider);
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            switch (display.mode) {
              DisplayMode.photos => const PhotoFrameScreen(),
              DisplayMode.dashboard => const DashboardScreen(),
            },
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
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _onCornerTap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
