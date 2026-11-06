import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../services/ha_client.dart';
import '../state/display_state.dart';
import '../state/ha_info.dart';
import '../state/settings.dart';

const _flashDuration = Duration(seconds: 30);

/// An appliance finished: the whole screen blinks with a message and/or the
/// tablet says it, as set in the settings. Stays silent while the screen is
/// off - at night, or with nobody around. A tap ends the blinking.
class FinishedAlert extends ConsumerStatefulWidget {
  const FinishedAlert({super.key});

  @override
  ConsumerState<FinishedAlert> createState() => _FinishedAlertState();
}

class _FinishedAlertState extends ConsumerState<FinishedAlert>
    with SingleTickerProviderStateMixin {
  final _finished = FinishedDevices();
  late final _blink = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );
  var _names = <String>[];
  Timer? _end;

  @override
  void dispose() {
    _end?.cancel();
    _blink.dispose();
    super.dispose();
  }

  void _onRunning(List<RunningDevice> running) {
    final names = _finished.update(running, DateTime.now());
    if (names.isEmpty || !ref.read(displayProvider).isScreenOn) return;
    final settings = ref.read(settingsProvider);
    if (settings.isFinishedSpeechOn) {
      final l10n = AppLocalizations.of(context);
      final language = Localizations.localeOf(context).toLanguageTag();
      for (final name in names) {
        ref
            .read(kioskProvider)
            .speak(
              l10n.deviceFinished(name),
              language,
              settings.finishedSpeechVolume / 100,
            );
      }
    }
    if (!settings.isFinishedFlashOn) return;
    setState(() => _names = [..._names, ...names]);
    _blink.repeat(reverse: true);
    _end?.cancel();
    _end = Timer(_flashDuration, _stop);
  }

  void _stop() {
    _end?.cancel();
    _blink.stop();
    if (mounted) setState(() => _names = []);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      haInfoProvider.select((info) => info.running),
      (_, running) => _onRunning(running),
    );
    if (_names.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final isChildLocked = ref.watch(
      displayProvider.select((display) => display.isChildLocked),
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: isChildLocked ? null : _stop,
      child: AnimatedBuilder(
        animation: _blink,
        builder: (context, child) => ColoredBox(
          color: Color.lerp(
            Colors.black,
            const Color(0xFF2E7D32),
            _blink.value,
          )!,
          child: child,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 24,
            children: [
              const Icon(Icons.check_circle, size: 120, color: Colors.white),
              for (final name in _names)
                Text(
                  l10n.deviceFinished(name),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
