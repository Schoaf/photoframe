import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../models/photo_item.dart';
import '../../state/photos.dart';

/// One video of the slideshow: muted by default, looping when shorter than
/// [interval]. Shows [poster] until the video plays.
class VideoSlide extends ConsumerStatefulWidget {
  const VideoSlide({
    super.key,
    required this.item,
    required this.poster,
    required this.isActive,
    required this.isSoundOn,
    required this.interval,
    required this.onLengthKnown,
    required this.onEnded,
  });

  final PhotoItem item;
  final ImageProvider poster;

  /// Only the visible slide plays (and only one controller decodes at a
  /// time - the Exynos 7870 handles one stream well).
  final bool isActive;
  final bool isSoundOn;
  final Duration interval;

  /// Called whenever the video (re)starts; null when it can't be played.
  final ValueChanged<Duration?> onLengthKnown;

  /// A video longer than [interval] finished.
  final VoidCallback onEnded;

  @override
  ConsumerState<VideoSlide> createState() => _VideoSlideState();
}

class _VideoSlideState extends ConsumerState<VideoSlide> {
  VideoPlayerController? _controller;
  bool _hasEnded = false;
  ValueListenable<double?>? _download;

  @override
  void initState() {
    super.initState();
    if (widget.isActive) _load();
  }

  @override
  void didUpdateWidget(VideoSlide oldWidget) {
    super.didUpdateWidget(oldWidget);
    final controller = _controller;
    if (widget.isActive != oldWidget.isActive) {
      if (!widget.isActive) {
        controller?.pause();
      } else if (controller == null) {
        _load();
      } else {
        _restart(controller);
      }
    }
    if (widget.isSoundOn != oldWidget.isSoundOn) {
      controller?.setVolume(widget.isSoundOn ? 1 : 0);
    }
  }

  @override
  void dispose() {
    _download?.removeListener(_onDownload);
    _controller?.dispose();
    super.dispose();
  }

  /// Plays the downloaded file; until the download is there the slide
  /// shows the poster like a photo.
  Future<void> _load() async {
    final downloads = ref.read(videoDownloadsProvider);
    final key = videoCacheKey(widget.item);
    final file = await downloads.file(key);
    if (!mounted) return;
    if (file == null) {
      final client = ref.read(synologyClientProvider);
      unawaited(downloads.request(key, () => videoUrls(client, widget.item)));
      if (_download == null) {
        final download = downloads.progress(key);
        download.addListener(_onDownload);
        setState(() => _download = download);
      }
      widget.onLengthKnown(null);
      return;
    }
    _download?.removeListener(_onDownload);
    _download = null;
    // Platform view: the frames go straight to the screen like in VLC,
    // instead of being copied into Flutter's picture - too slow on the
    // tablets' Mali GPU.
    final controller = VideoPlayerController.file(
      file,
      viewType: VideoViewType.platformView,
    );
    try {
      await controller.initialize();
    } on Exception {
      await controller.dispose();
      if (mounted) widget.onLengthKnown(null);
      return;
    }
    if (!mounted) {
      await controller.dispose();
      return;
    }
    controller.addListener(_onTick);
    setState(() => _controller = controller);
    if (widget.isActive) await _restart(controller);
  }

  Future<void> _restart(VideoPlayerController controller) async {
    final length = controller.value.duration;
    _hasEnded = false;
    await controller.setLooping(length <= widget.interval);
    await controller.setVolume(widget.isSoundOn ? 1 : 0);
    await controller.seekTo(Duration.zero);
    await controller.play();
    widget.onLengthKnown(length);
  }

  /// Plays as soon as the download is there, if the slide is still shown.
  void _onDownload() {
    if (_download?.value == 1 && widget.isActive && _controller == null) {
      _load();
    }
  }

  void _onTick() {
    final value = _controller?.value;
    if (value == null || value.isLooping || _hasEnded) return;
    if (value.isCompleted) {
      _hasEnded = true;
      widget.onEnded();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final isPlaying = controller != null && controller.value.isInitialized;
    return Stack(
      fit: StackFit.expand,
      children: [
        Image(
          image: widget.poster,
          fit: BoxFit.contain,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
        if (isPlaying)
          Center(
            child: AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              child: VideoPlayer(controller),
            ),
          ),
        if (_download case final download? when !isPlaying)
          // Thin white bar at the bottom while the video downloads.
          Align(
            alignment: Alignment.bottomCenter,
            child: ValueListenableBuilder(
              valueListenable: download,
              builder: (context, progress, _) => LinearProgressIndicator(
                value: progress,
                minHeight: 3,
                color: Colors.white,
                backgroundColor: Colors.white24,
              ),
            ),
          ),
      ],
    );
  }
}
