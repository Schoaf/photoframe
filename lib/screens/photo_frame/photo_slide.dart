import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../models/frame_crop.dart';

/// One photo as set in photoframe-client: the chosen 16:10 part filling
/// the screen, or the whole photo on a blurred copy of itself. Without a
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

  @override
  Widget build(BuildContext context) {
    final crop = this.crop;
    if (crop == null) return _photo(BoxFit.contain);
    if (crop.isWhole) {
      return Stack(
        fit: StackFit.expand,
        children: [
          ClipRect(
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: _photo(BoxFit.cover),
            ),
          ),
          const ColoredBox(color: Color(0x33000000)),
          _photo(BoxFit.contain),
        ],
      );
    }
    final rect = crop.rect;
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
