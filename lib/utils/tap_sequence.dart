/// The hidden unlock gesture: [requiredTaps] taps, each within [window] of
/// the first one.
class TapSequence {
  TapSequence({this.requiredTaps = 5, this.window = const Duration(seconds: 3)});

  final int requiredTaps;
  final Duration window;
  final _taps = <DateTime>[];

  /// true when this tap completes the sequence (which then starts over).
  bool register(DateTime now) {
    if (_taps.isNotEmpty && now.difference(_taps.first) > window) {
      _taps.clear();
    }
    _taps.add(now);
    if (_taps.length < requiredTaps) return false;
    _taps.clear();
    return true;
  }
}
