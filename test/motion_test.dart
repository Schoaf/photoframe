import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ha_display/services/kiosk.dart';
import 'package:ha_display/state/display_state.dart';
import 'package:ha_display/state/motion.dart';
import 'package:ha_display/state/settings.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockKiosk extends Mock implements Kiosk {}

void main() {
  final start = DateTime(2026, 11, 3, 20);
  late _MockKiosk kiosk;
  late ProviderContainer container;
  late MotionScreenOff watcher;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    kiosk = _MockKiosk();
    when(() => kiosk.isAutoBrightness()).thenAnswer((_) async => false);
    when(() => kiosk.screenOff()).thenAnswer((_) async => true);
    when(() => kiosk.screenOn()).thenAnswer((_) async {});
    when(() => kiosk.setBrightness(any())).thenAnswer((_) async {});
    when(() => kiosk.isChildLocked()).thenAnswer((_) async => false);
    container = ProviderContainer(
      overrides: [
        kioskProvider.overrideWithValue(kiosk),
        settingsProvider.overrideWith(
          () => SettingsNotifier(
            const Settings(synologyUrl: 'http://nas', albumId: 1),
          ),
        ),
      ],
    );
    watcher = MotionScreenOff(
      timeout: const Duration(minutes: 10),
      display: container.read(displayProvider.notifier),
      currentState: () => container.read(displayProvider),
      now: start,
    );
  });

  tearDown(() => container.dispose());

  bool isScreenOn() => container.read(displayProvider).isScreenOn;

  test('switches off without motion and on at the next motion', () async {
    watcher.check(start.add(const Duration(minutes: 9)));
    await pumpEventQueue();
    expect(isScreenOn(), isTrue);

    watcher.onMotion(start.add(const Duration(minutes: 5)));
    watcher.check(start.add(const Duration(minutes: 14)));
    await pumpEventQueue();
    expect(isScreenOn(), isTrue);

    watcher.check(start.add(const Duration(minutes: 15)));
    await pumpEventQueue();
    expect(isScreenOn(), isFalse);

    watcher.onMotion(start.add(const Duration(minutes: 20)));
    await pumpEventQueue();
    expect(isScreenOn(), isTrue);
  });

  test("motion doesn't wake a screen someone else switched off", () async {
    await container.read(displayProvider.notifier).setScreenOn(false);
    watcher.onMotion(start.add(const Duration(minutes: 1)));
    await pumpEventQueue();
    expect(isScreenOn(), isFalse);
  });

  test('the countdown starts over when the screen comes on', () async {
    watcher.check(start.add(const Duration(minutes: 10)));
    await pumpEventQueue();
    await container.read(displayProvider.notifier).setScreenOn(true);
    watcher.onScreenOn(start.add(const Duration(minutes: 30)));

    watcher.check(start.add(const Duration(minutes: 35)));
    await pumpEventQueue();
    expect(isScreenOn(), isTrue);
  });
}
