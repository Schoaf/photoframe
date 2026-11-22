import 'package:flutter/widgets.dart';

/// Page physics where a short swipe already turns the page: Flutter's own
/// only does so past half the width or on a fast fling, so a calm swipe
/// often springs back.
class ShortSwipePhysics extends PageScrollPhysics {
  const ShortSwipePhysics({required this.startPage, super.parent});

  /// The page the current swipe started on.
  final ValueGetter<int> startPage;

  /// Share of the width a swipe has to cover.
  static const threshold = 0.15;

  @override
  ShortSwipePhysics applyTo(ScrollPhysics? ancestor) =>
      ShortSwipePhysics(startPage: startPage, parent: buildParent(ancestor));

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    if (position.outOfRange) {
      return super.createBallisticSimulation(position, velocity);
    }
    final tolerance = toleranceFor(position);
    final width = position.viewportDimension;
    final page = position.pixels / width;
    final moved = page - startPage();
    final target = switch (velocity) {
      > 0 when velocity > tolerance.velocity => page.ceilToDouble(),
      < 0 when -velocity > tolerance.velocity => page.floorToDouble(),
      _ when moved >= threshold => page.ceilToDouble(),
      _ when moved <= -threshold => page.floorToDouble(),
      _ => page.roundToDouble(),
    };
    final pixels = (target * width).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((pixels - position.pixels).abs() < tolerance.distance) return null;
    return ScrollSpringSimulation(
      spring,
      position.pixels,
      pixels,
      velocity,
      tolerance: tolerance,
    );
  }
}
