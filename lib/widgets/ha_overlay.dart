import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../services/ha_calendar.dart';
import '../services/ha_client.dart';
import '../services/ha_media.dart';
import '../state/calendar.dart';
import '../state/display_state.dart';
import '../state/ha_info.dart';
import '../state/settings.dart';
import '../theme/app_theme.dart';
import '../utils/ha_icons.dart';

/// Readable on any photo without a box around it.
const _textShadows = [
  Shadow(blurRadius: 8, color: Color(0xCC000000)),
  Shadow(blurRadius: 2, color: Color(0x99000000)),
];

/// Agenda (top left), clock + weather (top right), warnings (bottom
/// centre) and running appliances (bottom right) over the photos. A tap
/// opens the matching dashboard view via [onOpenDashboard]. A tap on either opens the dashboard via [onOpenDashboard].
class HaOverlay extends ConsumerStatefulWidget {
  const HaOverlay({
    super.key,
    required this.onOpenDashboard,
    required this.isLifted,
  });

  /// Gets the view path (null: main view); null when no dashboard is
  /// configured.
  final void Function(String? view)? onOpenDashboard;

  /// The photo controls are visible - the warnings move up above them.
  final bool isLifted;

  @override
  ConsumerState<HaOverlay> createState() => _HaOverlayState();
}

class _HaOverlayState extends ConsumerState<HaOverlay> {
  final _dismissed = DismissedWarnings();
  final _dismissedCharging = DismissedCharging();
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
    final warnings = _dismissed.visible(info.warnings, _now);
    final isPrivate = ref.watch(
      displayProvider.select((display) => display.isPrivate),
    );
    final calendar = isPrivate
        ? const CalendarState()
        : ref.watch(calendarProvider);
    final agenda = buildAgenda(calendar.events, _now);
    final charging = _dismissedCharging.visible(info.charging);
    final bottom = widget.isLifted ? 112.0 : 32.0;
    final settings = ref.watch(settingsProvider);
    final isChildLocked = ref.watch(
      displayProvider.select((display) => display.isChildLocked),
    );
    // Under child lock taps fall through to the photo frame's lock.
    final open = isChildLocked ? null : widget.onOpenDashboard;
    VoidCallback? opener(String view) => open == null ? null : () => open(view);
    return Stack(
      children: [
        if (agenda.isNotEmpty)
          Positioned(
            top: 24 - _tapMargin,
            left: 32 - _tapMargin,
            child: _TapArea(
              onTap: opener(settings.calendarView),
              child: _AgendaPanel(days: agenda),
            ),
          )
        else if (calendar.status != CalendarStatus.loading)
          Positioned(
            top: 24 - _tapMargin,
            left: 32 - _tapMargin,
            child: _TapArea(
              onTap: opener(settings.calendarView),
              child: _AgendaNote(status: calendar.status),
            ),
          ),
        Positioned(
          top: 24 - _tapMargin,
          right: 32 - _tapMargin,
          child: _TapArea(
            onTap: opener(settings.weatherView),
            child: _InfoPanel(now: _now, info: info),
          ),
        ),
        Positioned.fill(
          child: Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 24,
              runSpacing: 24,
              children: [
                for (final device in charging)
                  Dismissible(
                    key: ValueKey(device.name),
                    direction: isChildLocked
                        ? DismissDirection.none
                        : DismissDirection.horizontal,
                    onDismissed: (_) =>
                        setState(() => _dismissedCharging.dismiss(device.name)),
                    child: _ChargingBattery(device: device),
                  ),
              ],
            ),
          ),
        ),
        AnimatedPositioned(
          duration: const Duration(milliseconds: 250),
          left: 0,
          right: 0,
          // Above the appliance tiles, which may reach the middle.
          bottom: info.running.isEmpty
              ? bottom
              : bottom + AppSizes.deviceTileHeight + 16,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                spacing: 8,
                children: [
                  for (final warning in warnings.take(3))
                    // Seen it - swiped away until midnight.
                    Dismissible(
                      key: ValueKey(warning.id),
                      direction: isChildLocked
                          ? DismissDirection.none
                          : DismissDirection.horizontal,
                      onDismissed: (_) => setState(
                        () => _dismissed.dismiss(warning.id, DateTime.now()),
                      ),
                      child: _WarningBanner(
                        warning: warning,
                        onTap: opener(settings.warningsView),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        AnimatedPositioned(
          duration: const Duration(milliseconds: 250),
          right: 32,
          bottom: bottom,
          child: _RunningRow(
            devices: info.running,
            onOpen: (device) => opener(device.view ?? settings.devicesView),
          ),
        ),
      ],
    );
  }
}

/// A big battery in the middle of the screen, filled to the charge level.
class _ChargingBattery extends StatelessWidget {
  const _ChargingBattery({required this.device});

  final ChargingDevice device;

  @override
  Widget build(BuildContext context) {
    final fill = switch (device.level) {
      < 20 => const Color(0xFFD32F2F),
      < 50 => const Color(0xFFEF6C00),
      _ => const Color(0xFF2E7D32),
    };
    return Container(
      width: AppSizes.batteryWidth,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xCC000000),
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 16,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 12,
            children: [
              Icon(warningIcon(device.icon), size: 32, color: Colors.white),
              Flexible(
                child: Text(
                  device.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 130,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: device.level / 100,
                        child: ColoredBox(color: fill),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        spacing: 4,
                        children: [
                          const Icon(
                            Icons.bolt,
                            size: 56,
                            color: Colors.white,
                            shadows: _textShadows,
                          ),
                          Text(
                            '${device.level.round()} %',
                            style: const TextStyle(
                              fontSize: 64,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              shadows: _textShadows,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                width: 14,
                height: 56,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.horizontal(
                    right: Radius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Extra room around the agenda and the weather that still counts as a
/// tap on them.
const _tapMargin = 16.0;

/// The whole box around [child] takes the tap, not only its text - the
/// gaps would otherwise reach the photo below.
class _TapArea extends StatelessWidget {
  const _TapArea({required this.onTap, required this.child});

  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Padding(padding: const EdgeInsets.all(_tapMargin), child: child),
  );
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

/// Stands in for an empty agenda, so that it can't be taken for a fault - and
/// a fault can't be taken for a free day.
class _AgendaNote extends StatelessWidget {
  const _AgendaNote({required this.status});

  final CalendarStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        status == CalendarStatus.failed
            ? l10n.calendarUnavailable
            : l10n.noEvents,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: AppSizes.captionFontSize,
          shadows: _textShadows,
        ),
      ),
    );
  }
}

/// Running appliances along the bottom edge, right-aligned: one that starts
/// comes in at the far right and pushes the others to the left.
class _RunningRow extends StatefulWidget {
  const _RunningRow({required this.devices, required this.onOpen});

  final List<RunningDevice> devices;
  final VoidCallback? Function(RunningDevice device) onOpen;

  @override
  State<_RunningRow> createState() => _RunningRowState();
}

class _RunningRowState extends State<_RunningRow> {
  /// Names in the order they started - the template lists them in a
  /// fixed order.
  final _order = <String>[];

  @override
  Widget build(BuildContext context) {
    final byName = {for (final device in widget.devices) device.name: device};
    _order
      ..retainWhere(byName.containsKey)
      ..addAll(byName.keys.where((name) => !_order.contains(name)));
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final name in _order)
          _SlideIn(
            key: ValueKey(name),
            child: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onOpen(byName[name]!),
                child: _RunningTile(device: byName[name]!),
              ),
            ),
          ),
      ],
    );
  }
}

/// Grows from nothing while sliding in from the bottom right, so the tiles
/// to its left move over smoothly.
class _SlideIn extends StatefulWidget {
  const _SlideIn({super.key, required this.child});

  final Widget child;

  @override
  State<_SlideIn> createState() => _SlideInState();
}

class _SlideInState extends State<_SlideIn>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  )..forward();
  late final _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizeTransition(
    sizeFactor: _curve,
    axis: Axis.horizontal,
    alignment: Alignment.centerLeft,
    child: SlideTransition(
      position: Tween(
        begin: const Offset(1, 1),
        end: Offset.zero,
      ).animate(_curve),
      child: FadeTransition(opacity: _curve, child: widget.child),
    ),
  );
}

/// From here on an appliance's tile turns orange ...
const _almostDone = Duration(minutes: 3);

/// ... and from here on its icon pulses.
const _nearlyDone = Duration(minutes: 1);

/// Big appliance icon, "noch 42 min" and a bar filling up to 100 %. Turns
/// orange shortly before the end, and its icon pulses in the last minute.
class _RunningTile extends StatefulWidget {
  const _RunningTile({required this.device});

  final RunningDevice device;

  @override
  State<_RunningTile> createState() => _RunningTileState();
}

class _RunningTileState extends State<_RunningTile>
    with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    lowerBound: 0.15,
  );
  Timer? _nextStep;

  @override
  void dispose() {
    _nextStep?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  /// Redraws right when the next highlight starts - the overlay itself only
  /// redraws once a minute.
  void _scheduleNextStep(Duration? remaining) {
    _nextStep?.cancel();
    if (remaining == null) return;
    final next = [
      remaining - _almostDone,
      remaining - _nearlyDone,
    ].where((left) => left > Duration.zero).firstOrNull;
    if (next != null) {
      _nextStep = Timer(next, () => mounted ? setState(() {}) : null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final now = DateTime.now();
    final device = widget.device;
    final remaining = device.remaining(now);
    final fraction = device.fraction(now);
    final minutes = remaining == null
        ? null
        : (remaining.inSeconds / 60).ceil();
    final isAlmostDone = remaining != null && remaining <= _almostDone;
    final isNearlyDone = remaining != null && remaining <= _nearlyDone;
    _scheduleNextStep(remaining);
    if (isNearlyDone && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!isNearlyDone && _pulse.isAnimating) {
      _pulse.value = 1;
    }
    final foreground = isAlmostDone ? Colors.black87 : Colors.white;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      // Wider when the text needs it.
      constraints: const BoxConstraints(minWidth: AppSizes.deviceTileMinWidth),
      height: AppSizes.deviceTileHeight,
      padding: const EdgeInsets.fromLTRB(8, 8, 20, 8),
      decoration: BoxDecoration(
        color: isAlmostDone ? const Color(0xE6FB8C00) : const Color(0x99000000),
        borderRadius: BorderRadius.circular(16),
      ),
      child: IntrinsicWidth(
        child: Row(
          spacing: 12,
          children: [
            FadeTransition(
              opacity: isNearlyDone ? _pulse : kAlwaysCompleteAnimation,
              child: Icon(
                warningIcon(device.icon),
                size: AppSizes.deviceTileHeight - 16,
                color: foreground,
              ),
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 10,
                children: [
                  if (minutes != null)
                    // Away from the icon; the bar below still starts there.
                    Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Text(
                        minutes < 60
                            ? l10n.remainingMinutes(minutes)
                            : l10n.remainingHours(
                                '${minutes ~/ 60}:${'${minutes % 60}'.padLeft(2, '0')}',
                              ),
                        style: TextStyle(
                          color: foreground,
                          fontSize: 22,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  if (fraction != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: fraction,
                        minHeight: 8,
                        color: isAlmostDone ? Colors.black87 : null,
                        backgroundColor: isAlmostDone
                            ? const Color(0x33000000)
                            : const Color(0x33FFFFFF),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
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
    final isChildLocked = ref.watch(
      displayProvider.select((display) => display.isChildLocked),
    );
    return GestureDetector(
      onTap: isChildLocked ? null : _showControls,
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
  const _WarningBanner({required this.warning, required this.onTap});

  final HaWarning warning;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xE6FFB300),
    borderRadius: BorderRadius.circular(32),
    elevation: 4,
    child: InkWell(
      borderRadius: BorderRadius.circular(32),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 16,
          children: [
            Icon(warningIcon(warning.icon), size: 32, color: Colors.black87),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    warning.name,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: warning.details.isEmpty
                          ? FontWeight.w500
                          : FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  for (final detail in warning.details)
                    Text(
                      detail,
                      style: const TextStyle(
                        fontSize: 20,
                        color: Colors.black87,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
