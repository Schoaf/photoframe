import 'package:flutter_test/flutter_test.dart';
import 'package:ha_display/screens/dashboard/dashboard_screen.dart';
import 'package:ha_display/utils/slide_duration.dart';
import 'package:ha_display/utils/tap_sequence.dart';

void main() {
  group('slideDuration', () {
    const interval = Duration(seconds: 15);

    test('a photo and a short video stay for the interval', () {
      expect(slideDuration(interval), interval);
      expect(
        slideDuration(interval, videoLength: const Duration(seconds: 4)),
        interval,
      );
    });

    test('a longer video plays to its end', () {
      expect(
        slideDuration(interval, videoLength: const Duration(seconds: 40)),
        const Duration(seconds: 40),
      );
    });
  });

  group('TapSequence', () {
    final start = DateTime(2026);

    test('unlocks after five quick taps', () {
      final taps = TapSequence();
      final results = [
        for (var i = 0; i < 5; i++)
          taps.register(start.add(Duration(milliseconds: 300 * i))),
      ];
      expect(results, [false, false, false, false, true]);
    });

    test('starts over when the taps are too slow', () {
      final taps = TapSequence();
      for (var i = 0; i < 4; i++) {
        taps.register(start.add(Duration(seconds: i)));
      }
      expect(taps.register(start.add(const Duration(seconds: 4))), isFalse);
    });
  });

  group('kioskDashboardUri', () {
    test('adds the kiosk parameter', () {
      expect(
        kioskDashboardUri('http://ha:8123/lovelace/0').toString(),
        'http://ha:8123/lovelace/0?kiosk',
      );
      expect(
        kioskDashboardUri('http://ha:8123/dash?edit=0').toString(),
        'http://ha:8123/dash?edit=0&kiosk',
      );
    });

    test('keeps an existing kiosk parameter', () {
      expect(
        kioskDashboardUri('http://ha:8123/dash?kiosk').toString(),
        'http://ha:8123/dash?kiosk',
      );
    });
  });
}
