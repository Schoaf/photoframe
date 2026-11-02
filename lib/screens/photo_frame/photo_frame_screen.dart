import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../../models/photo_item.dart';
import '../../services/synology_photos_client.dart';
import '../../state/display_state.dart';
import '../../state/photos.dart';
import '../../state/settings.dart';
import '../../theme/app_theme.dart';
import '../../utils/slide_duration.dart';
import '../../widgets/ha_overlay.dart';
import 'gallery_screen.dart';
import 'video_slide.dart';

const _overlayDuration = Duration(seconds: 5);
const _pageAnimation = Duration(milliseconds: 900);

/// Full-screen slideshow of the album. A tap shows the controls for a few
/// seconds; swiping changes the photo.
class PhotoFrameScreen extends ConsumerStatefulWidget {
  const PhotoFrameScreen({super.key});

  @override
  ConsumerState<PhotoFrameScreen> createState() => _PhotoFrameScreenState();
}

class _PhotoFrameScreenState extends ConsumerState<PhotoFrameScreen> {
  // No itemCount: the PageView runs endlessly, page % items.length is the
  // item, so swiping past the last photo starts over.
  final _controller = PageController();
  Timer? _slideTimer;
  Timer? _overlayTimer;
  int _page = 0;
  bool _hasStarted = false;
  bool _isGalleryOpen = false;
  bool _isOverlayVisible = false;
  bool _isSoundOn = false;

  @override
  void dispose() {
    _slideTimer?.cancel();
    _overlayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Duration get _interval =>
      Duration(seconds: ref.read(settingsProvider).slideSeconds);

  void _scheduleNext(Duration after) {
    _slideTimer?.cancel();
    if (ref.read(displayProvider).mode != DisplayMode.photos) return;
    _slideTimer = Timer(after, _next);
  }

  void _next() {
    if (!_controller.hasClients) return;
    _controller.nextPage(duration: _pageAnimation, curve: Curves.easeInOut);
  }

  void _onPageChanged(int page, List<PhotoItem> items) {
    setState(() {
      _page = page;
      // Every video starts muted again.
      _isSoundOn = false;
    });
    final item = items[page % items.length];
    // Videos schedule themselves once their length is known.
    if (!item.isVideo) _scheduleNext(_interval);
    _precache(items[(page + 1) % items.length]);
  }

  void _precache(PhotoItem item) {
    if (item.isVideo) return;
    precacheImage(_imageProvider(item, ThumbnailSize.xl), context);
  }

  CachedNetworkImageProvider _imageProvider(
    PhotoItem item,
    ThumbnailSize size,
  ) {
    final client = ref.read(synologyClientProvider);
    return CachedNetworkImageProvider(
      client.thumbnailUrl(item, size: size),
      // The URL carries the session id, which changes on every login.
      cacheKey: '${item.unitId}_${item.cacheKey}_${size.name}',
    );
  }

  void _showOverlay() {
    setState(() => _isOverlayVisible = true);
    _overlayTimer?.cancel();
    _overlayTimer = Timer(_overlayDuration, () {
      if (mounted) setState(() => _isOverlayVisible = false);
    });
  }

  /// A video loops until [_interval] is over, or plays to its end when it's
  /// longer (then [_onVideoEnded] advances).
  void _onVideoLength(int page, Duration? length) {
    if (page != _page) return;
    final duration = slideDuration(_interval, videoLength: length);
    if (duration == _interval) {
      _scheduleNext(_interval);
    } else {
      _slideTimer?.cancel();
    }
  }

  void _onVideoEnded(int page) {
    if (page == _page) _next();
  }

  void _openDashboard([String? view]) {
    ref.read(displayProvider.notifier).openDashboard(view);
  }

  /// The dashboard covers the photos: no slideshow, no video meanwhile.
  void _onShownChanged(bool isShown) {
    if (!isShown) {
      _slideTimer?.cancel();
      setState(() => _isOverlayVisible = false);
      return;
    }
    final items = ref.read(albumItemsProvider).value;
    if (items != null &&
        items.isNotEmpty &&
        !items[_page % items.length].isVideo) {
      _scheduleNext(_interval);
    }
  }

  Future<void> _openGallery(List<PhotoItem> items) async {
    _slideTimer?.cancel();
    // Pauses a playing video; it restarts (and reschedules) on return.
    setState(() => _isGalleryOpen = true);
    final index = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (_) =>
            GalleryScreen(items: items, currentIndex: _page % items.length),
      ),
    );
    if (!mounted) return;
    setState(() => _isGalleryOpen = false);
    final target = index == null ? _page : _page - _page % items.length + index;
    if (target != _page) {
      _controller.jumpToPage(target);
    } else if (!items[_page % items.length].isVideo) {
      _scheduleNext(_interval);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    ref.listen(
      displayProvider.select((display) => display.nextPhotoRequests),
      (_, _) => _next(),
    );
    final isShown = ref.watch(
      displayProvider.select((display) => display.mode == DisplayMode.photos),
    );
    ref.listen(
      displayProvider.select((display) => display.mode == DisplayMode.photos),
      (_, isShown) => _onShownChanged(isShown),
    );
    final hasDashboard = ref.watch(
      settingsProvider.select((settings) => settings.hasDashboard),
    );
    final haOverlay = HaOverlay(
      onOpenDashboard: hasDashboard ? _openDashboard : null,
      isLifted: _isOverlayVisible,
    );
    final items = ref.watch(albumItemsProvider);
    // A refresh keeps showing the previous list instead of a spinner.
    final list = items.value;
    if (list == null || list.isEmpty) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: items.isLoading
                ? const CircularProgressIndicator()
                : Text(
                    items.hasError ? l10n.photosLoadError : l10n.photosEmpty,
                    style: const TextStyle(fontSize: AppSizes.captionFontSize),
                  ),
          ),
          haOverlay,
        ],
      );
    }
    if (!_hasStarted) {
      _hasStarted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _onPageChanged(_page, list);
      });
    }
    final current = list[_page % list.length];
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _showOverlay,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _controller,
            onPageChanged: (page) => _onPageChanged(page, list),
            itemBuilder: (context, page) {
              final item = list[page % list.length];
              if (item.isVideo) {
                return VideoSlide(
                  key: ValueKey('video_$page'),
                  item: item,
                  poster: _imageProvider(item, ThumbnailSize.xl),
                  isActive: page == _page && !_isGalleryOpen && isShown,
                  isSoundOn: page == _page && _isSoundOn,
                  interval: _interval,
                  onLengthKnown: (length) => _onVideoLength(page, length),
                  onEnded: () => _onVideoEnded(page),
                );
              }
              return Image(
                image: _imageProvider(item, ThumbnailSize.xl),
                fit: BoxFit.contain,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              );
            },
          ),
          haOverlay,
          IgnorePointer(
            ignoring: !_isOverlayVisible,
            child: AnimatedOpacity(
              opacity: _isOverlayVisible ? 1 : 0,
              duration: const Duration(milliseconds: 250),
              child: _Overlay(
                item: current,
                isSoundOn: _isSoundOn,
                onToggleSound: () {
                  setState(() => _isSoundOn = !_isSoundOn);
                  _showOverlay();
                },
                onOpenGallery: () => _openGallery(list),
                onOpenDashboard: hasDashboard ? _openDashboard : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Overlay extends StatelessWidget {
  const _Overlay({
    required this.item,
    required this.isSoundOn,
    required this.onToggleSound,
    required this.onOpenGallery,
    required this.onOpenDashboard,
  });

  final PhotoItem item;
  final bool isSoundOn;
  final VoidCallback onToggleSound;
  final VoidCallback onOpenGallery;
  final VoidCallback? onOpenDashboard;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final caption = [
      // Synology stores the local taken time as if it were UTC.
      if (item.takenAt case final takenAt?)
        DateFormat.yMMMMd(locale).format(takenAt),
      ?item.place,
    ].join(' · ');
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0.6, 1],
          colors: [Colors.transparent, Color(0xB3000000)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 24, 24, 24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text(
                caption,
                style: const TextStyle(
                  fontSize: AppSizes.captionFontSize,
                  color: Colors.white,
                ),
              ),
            ),
            if (item.isVideo)
              _OverlayButton(
                icon: isSoundOn ? Icons.volume_up : Icons.volume_off,
                tooltip: isSoundOn ? l10n.soundOff : l10n.soundOn,
                onPressed: onToggleSound,
              ),
            const SizedBox(width: 16),
            _OverlayButton(
              icon: Icons.grid_view,
              tooltip: l10n.gallery,
              onPressed: onOpenGallery,
            ),
            if (onOpenDashboard case final onOpenDashboard?) ...[
              const SizedBox(width: 16),
              _OverlayButton(
                icon: Icons.dashboard,
                tooltip: l10n.showDashboard,
                onPressed: onOpenDashboard,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OverlayButton extends StatelessWidget {
  const _OverlayButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton.filledTonal(
    onPressed: onPressed,
    tooltip: tooltip,
    iconSize: AppSizes.overlayIcon,
    constraints: const BoxConstraints.tightFor(
      width: AppSizes.overlayButton,
      height: AppSizes.overlayButton,
    ),
    icon: Icon(icon),
  );
}
