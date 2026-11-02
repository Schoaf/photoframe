import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../services/ha_calendar.dart';
import '../services/ha_client.dart';
import '../services/ha_media.dart';
import '../state/calendar.dart';
import '../state/ha_info.dart';
import '../state/settings.dart';
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
    final agenda = buildAgenda(ref.watch(calendarProvider), _now);
    return Stack(
      children: [
        if (agenda.isNotEmpty)
          Positioned(
            top: 24,
            left: 32,
            child: GestureDetector(
              onTap: widget.onOpenDashboard,
              child: _AgendaPanel(days: agenda),
            ),
          ),
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
        if (info.nowPlaying case final music? when !music.isStale(now)) ...[
          const SizedBox(height: 12),
          _NowPlayingTile(music: music),
        ],
      ],
    );
  }
}

/// Heute / Morgen with time and title per event.
class _AgendaPanel extends StatelessWidget {
  const _AgendaPanel({required this.days});

  final List<AgendaDay> days;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    const style = TextStyle(
      color: Colors.white,
      fontSize: AppSizes.captionFontSize,
      shadows: _textShadows,
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: AppSizes.agendaWidth),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final day in days) ...[
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Text(
                day.isToday ? l10n.today : l10n.tomorrow,
                style: style.copyWith(
                  fontSize: 26,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            for (final event in day.events)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 110,
                      child: Text(
                        event.isAllDay
                            ? l10n.allDay
                            : DateFormat.Hm(locale).format(event.start),
                        style: style.copyWith(color: Colors.white70),
                      ),
                    ),
                    Flexible(
                      child: Text(
                        event.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: style,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
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

/// Cover, title, artist and a bar with the time left. A tap shows
/// previous / play-pause / next for a few seconds.
class _NowPlayingTile extends ConsumerStatefulWidget {
  const _NowPlayingTile({required this.music});

  final NowPlaying music;

  @override
  ConsumerState<_NowPlayingTile> createState() => _NowPlayingTileState();
}

class _NowPlayingTileState extends ConsumerState<_NowPlayingTile> {
  static const _controlsTimeout = Duration(seconds: 8);

  late final Timer _ticker;
  Timer? _hideControls;
  bool _isShowingControls = false;

  @override
  void initState() {
    super.initState();
    // The position moves on between HA updates.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (widget.music.isPlaying) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker.cancel();
    _hideControls?.cancel();
    super.dispose();
  }

  void _showControls() {
    _hideControls?.cancel();
    setState(() => _isShowingControls = true);
    _hideControls = Timer(
      _controlsTimeout,
      () => mounted ? setState(() => _isShowingControls = false) : null,
    );
  }

  void _command(String service) {
    ref
        .read(haInfoProvider.notifier)
        .mediaCommand(widget.music.entityId, service);
    _showControls();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final music = widget.music;
    final now = DateTime.now();
    final remaining = music.remaining(now);
    final fraction = music.fraction(now);
    final picture = music.pictureUrl;
    final baseUrl = ref.watch(settingsProvider.select((s) => s.dashboardUrl));
    const icon = Icon(Icons.music_note, size: 36, color: Colors.white70);
    Widget button(IconData iconData, String tooltip, String service) =>
        IconButton(
          iconSize: 44,
          tooltip: tooltip,
          color: Colors.white,
          icon: Icon(iconData),
          onPressed: () => _command(service),
        );
    return GestureDetector(
      onTap: _showControls,
      child: Container(
        width: AppSizes.runningTileWidth,
        padding: const EdgeInsets.fromLTRB(12, 12, 16, 14),
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
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox.square(
                    dimension: 56,
                    child: picture == null
                        ? icon
                        : Image.network(
                            Uri.parse(baseUrl.trim())
                                .resolve(picture)
                                .toString(),
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => icon,
                          ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        music.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (music.artist case final artist?)
                        Text(
                          artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 18,
                          ),
                        ),
                    ],
                  ),
                ),
                if (!music.isPlaying)
                  const Icon(Icons.pause, size: 28, color: Colors.white70)
                else if (remaining != null)
                  Text(
                    '-${remaining.inMinutes}:${'${remaining.inSeconds % 60}'.padLeft(2, '0')}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
              ],
            ),
            if (fraction != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: fraction,
                  minHeight: 6,
                  backgroundColor: const Color(0x33FFFFFF),
                ),
              ),
            if (_isShowingControls)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  button(
                    Icons.skip_previous,
                    l10n.previousTrack,
                    'media_previous_track',
                  ),
                  button(
                    music.isPlaying ? Icons.pause : Icons.play_arrow,
                    l10n.playPause,
                    'media_play_pause',
                  ),
                  button(Icons.skip_next, l10n.nextTrack, 'media_next_track'),
                ],
              ),
          ],
        ),
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
