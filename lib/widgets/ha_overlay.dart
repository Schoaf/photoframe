import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../services/ha_client.dart';
import '../state/ha_info.dart';
import '../theme/app_theme.dart';
import '../utils/ha_icons.dart';

/// Readable on any photo without a box around it.
const _textShadows = [
  Shadow(blurRadius: 8, color: Color(0xCC000000)),
  Shadow(blurRadius: 2, color: Color(0x99000000)),
];

/// Clock + weather (top right) and warnings (bottom centre) over the
/// photos. A tap on either opens the dashboard via [onOpenDashboard].
class HaOverlay extends ConsumerStatefulWidget {
  const HaOverlay({
    super.key,
    required this.onOpenDashboard,
    required this.isLifted,
  });

  /// null when no dashboard is configured.
  final VoidCallback? onOpenDashboard;

  /// The photo controls are visible - the warnings move up above them.
  final bool isLifted;

  @override
  ConsumerState<HaOverlay> createState() => _HaOverlayState();
}

class _HaOverlayState extends ConsumerState<HaOverlay> {
  final _dismissed = DismissedWarnings();
  late DateTime _now;
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _tick();
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  /// Redraws at each full minute.
  void _tick() {
    _now = DateTime.now();
    _clock = Timer(
      Duration(seconds: 60 - _now.second, milliseconds: -_now.millisecond),
      () {
        if (mounted) setState(_tick);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final info = ref.watch(haInfoProvider);
    final warnings = _dismissed.visible(info.warnings);
    return Stack(
      children: [
        Positioned(
          top: 24,
          right: 32,
          child: GestureDetector(
            onTap: widget.onOpenDashboard,
            child: _InfoPanel(now: _now, info: info),
          ),
        ),
        AnimatedPositioned(
          duration: const Duration(milliseconds: 250),
          left: 0,
          right: 0,
          bottom: widget.isLifted ? 112 : 32,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                spacing: 8,
                children: [
                  for (final warning in warnings.take(3))
                    _WarningBanner(
                      warning: warning,
                      onTap: widget.onOpenDashboard,
                      onDismiss: () =>
                          setState(() => _dismissed.dismiss(warning.id)),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({required this.now, required this.info});

  final DateTime now;
  final HaSnapshot info;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    const style = TextStyle(color: Colors.white, shadows: _textShadows);
    final weather = info.weather;
    final tomorrow = info.tomorrow;
    String degrees(num? value) => value == null ? '–' : '${value.round()}°';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          DateFormat.Hm(locale).format(now),
          style: style.copyWith(
            fontSize: AppSizes.clockFontSize,
            fontWeight: FontWeight.w300,
            height: 1,
          ),
        ),
        Text(
          DateFormat.MMMMEEEEd(locale).format(now),
          style: style.copyWith(fontSize: AppSizes.captionFontSize),
        ),
        if (weather != null) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 8,
            children: [
              Icon(
                weatherIcon(weather.condition),
                size: 40,
                color: Colors.white,
                shadows: _textShadows,
              ),
              Text(
                degrees(weather.temperature),
                style: style.copyWith(fontSize: 36),
              ),
            ],
          ),
        ],
        if (tomorrow != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 8,
            children: [
              Text(
                l10n.tomorrow,
                style: style.copyWith(fontSize: AppSizes.captionFontSize),
              ),
              Icon(
                weatherIcon(tomorrow.condition),
                size: 24,
                color: Colors.white,
                shadows: _textShadows,
              ),
              Text(
                '${degrees(tomorrow.low)} / ${degrees(tomorrow.high)}',
                style: style.copyWith(fontSize: AppSizes.captionFontSize),
              ),
            ],
          ),
        for (final device in info.running) ...[
          const SizedBox(height: 12),
          _RunningTile(device: device, now: now),
        ],
      ],
    );
  }
}

/// "Waschmaschine · noch 42 min" with a bar filling up to 100 %.
class _RunningTile extends StatelessWidget {
  const _RunningTile({required this.device, required this.now});

  final RunningDevice device;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final remaining = device.remaining(now);
    final fraction = device.fraction(now);
    final minutes = remaining == null
        ? null
        : (remaining.inSeconds / 60).ceil();
    return Container(
      width: AppSizes.runningTileWidth,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        color: const Color(0x99000000),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          Row(
            spacing: 12,
            children: [
              Icon(warningIcon(device.icon), size: 28, color: Colors.white),
              Expanded(
                child: Text(
                  device.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 20),
                ),
              ),
              if (minutes != null)
                Text(
                  minutes < 60
                      ? l10n.remainingMinutes(minutes)
                      : l10n.remainingHours(
                          '${minutes ~/ 60}:${'${minutes % 60}'.padLeft(2, '0')}',
                        ),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
          if (fraction != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 8,
                backgroundColor: const Color(0x33FFFFFF),
              ),
            ),
        ],
      ),
    );
  }
}

class _WarningBanner extends StatelessWidget {
  const _WarningBanner({
    required this.warning,
    required this.onTap,
    required this.onDismiss,
  });

  final HaWarning warning;
  final VoidCallback? onTap;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xE6FFB300),
    borderRadius: BorderRadius.circular(32),
    elevation: 4,
    child: InkWell(
      borderRadius: BorderRadius.circular(32),
      onTap: onTap,
      // Seen it - hide until it comes back.
      onLongPress: onDismiss,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 16,
          children: [
            Icon(warningIcon(warning.icon), size: 32, color: Colors.black87),
            Flexible(
              child: Text(
                warning.name,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
