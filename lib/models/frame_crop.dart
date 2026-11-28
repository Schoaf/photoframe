import 'dart:ui';

/// The frame's panel: 1920 x 1200.
const frameAspect = 16 / 10;

/// How a photo is to be shown, set with the photoframe-client app and kept
/// in the photo's description on the NAS: a 16:10 part of it ([rect],
/// fractions of the upright photo) or the whole photo ([isWhole]). Zoomed
/// out further than the photo covers, [rect] reaches past 0 or 1.
///
/// The marker format is shared with photoframe-client - change both.
class FrameCrop {
  const FrameCrop(this.rect) : isWhole = false;

  const FrameCrop.whole()
    : rect = const Rect.fromLTRB(0, 0, 1, 1),
      isWhole = true;

  final Rect rect;
  final bool isWhole;

  static final _marker = RegExp(
    r'\[rahmen(?: ganz| (-?[\d.]+) (-?[\d.]+) (-?[\d.]+) (-?[\d.]+))\]',
  );

  /// The crop in [description], or null when it has none.
  static FrameCrop? parse(String? description) {
    final match = _marker.firstMatch(description ?? '');
    if (match == null) return null;
    if (match.group(1) == null) return const FrameCrop.whole();
    final values = [
      for (var i = 1; i <= 4; i++) double.tryParse(match.group(i)!),
    ];
    if (values.contains(null)) return null;
    final [left!, top!, right!, bottom!] = values;
    // Some of the photo must be in it.
    if (left >= 1 || top >= 1 || right <= 0 || bottom <= 0) return null;
    if (left >= right || top >= bottom) return null;
    return FrameCrop(Rect.fromLTRB(left, top, right, bottom));
  }
}
