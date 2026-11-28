import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../models/frame_crop.dart';

/// One photo as set in photoframe-client: the chosen 16:10 part filling
/// the screen, or the whole photo on a blurred copy of itself. A part
/// zoomed out past the photo has the blurred copy around it too. Without a
/// setting the whole photo with black bars, as always.
class PhotoSlide extends StatelessWidget {
  const PhotoSlide({super.key, required this.image, this.crop});

  final ImageProvider image;
  final FrameCrop? crop;

  Widget _photo(BoxFit fit) => Image(
    image: image,
    fit: fit,
    gaplessPlayback: true,
    errorBuilder: (_, _, _) => const SizedBox.shrink(),
  );

  List<Widget> _blurred() => [
    ClipRect(
      child: ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: _photo(BoxFit.cover),
      ),
    ),
    const ColoredBox(color: Color(0x33000000)),
  ];

  @override
  Widget build(BuildContext context) {
    final crop = this.crop;
    if (crop == null) return _photo(BoxFit.contain);
    if (crop.isWhole) {
      return Stack(
        fit: StackFit.expand,
        children: [..._blurred(), _photo(BoxFit.contain)],
      );
    }
    final rect = crop.rect;
    final isPastPhoto =
        rect.left < 0 || rect.top < 0 || rect.right > 1 || rect.bottom > 1;
    return Center(
      child: AspectRatio(
        aspectRatio: frameAspect,
        child: ClipRect(
          child: LayoutBuilder(
            builder: (context, box) {
              final width = box.maxWidth / rect.width;
              final height = box.maxHeight / rect.height;
              return Stack(
                children: [
                  if (isPastPhoto) ...[
                    for (final layer in _blurred())
                      Positioned.fill(child: layer),
                  ],
                  Positioned(
                    left: -rect.left * width,
                    top: -rect.top * height,
                    width: width,
                    height: height,
                    child: _photo(BoxFit.fill),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
