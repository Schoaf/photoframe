import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../models/photo_item.dart';
import '../../services/synology_photos_client.dart';
import '../../state/photos.dart';
import '../../theme/app_theme.dart';

/// Back to the slideshow when nobody touches the gallery for this long.
const _idleTimeout = Duration(minutes: 2);

/// All album items as a grid; a tap returns the item's index.
class GalleryScreen extends ConsumerStatefulWidget {
  const GalleryScreen({
    super.key,
    required this.items,
    required this.currentIndex,
  });

  final List<PhotoItem> items;
  final int currentIndex;

  @override
  ConsumerState<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends ConsumerState<GalleryScreen> {
  late final ScrollController _scroll;
  Timer? _idleTimer;

  @override
  void initState() {
    super.initState();
    // Opens around the photo that was just on screen.
    _scroll = ScrollController(
      initialScrollOffset: _rowOffset(widget.currentIndex),
    );
    _resetIdleTimer();
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  double _rowOffset(int index) {
    // Square tiles: 1280 dp / 6 columns ≈ 213 dp per row on the SM-T585.
    const approxRowHeight = 213.0;
    final row = index ~/ AppSizes.galleryColumns;
    return (row - 1).clamp(0, 1 << 20) * approxRowHeight;
  }

  void _resetIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(_idleTimeout, () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final client = ref.watch(synologyClientProvider);
    return Listener(
      onPointerDown: (_) => _resetIdleTimer(),
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 72,
          backgroundColor: Colors.black,
          leading: IconButton(
            iconSize: 32,
            icon: const Icon(Icons.arrow_back),
            tooltip: l10n.backToSlideshow,
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(l10n.galleryTitle(widget.items.length)),
        ),
        body: GridView.builder(
          controller: _scroll,
          padding: const EdgeInsets.all(4),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: AppSizes.galleryColumns,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
          ),
          itemCount: widget.items.length,
          itemBuilder: (context, index) {
            final item = widget.items[index];
            return GestureDetector(
              onTap: () => Navigator.of(context).pop(index),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: client.thumbnailUrl(item, size: ThumbnailSize.sm),
                    cacheKey: '${item.unitId}_${item.cacheKey}_sm',
                    fit: BoxFit.cover,
                    // Decoded at tile size, not at the thumbnail's.
                    memCacheWidth: 300,
                    fadeInDuration: const Duration(milliseconds: 150),
                    errorWidget: (_, _, _) =>
                        const ColoredBox(color: Color(0xFF202020)),
                  ),
                  if (item.isVideo)
                    const Align(
                      alignment: Alignment.bottomRight,
                      child: Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(Icons.play_circle, size: 32),
                      ),
                    ),
                  if (index == widget.currentIndex)
                    DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(context).colorScheme.primary,
                          width: 4,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
