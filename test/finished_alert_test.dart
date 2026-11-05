import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ha_display/l10n/app_localizations.dart';
import 'package:ha_display/services/ha_client.dart';
import 'package:ha_display/services/kiosk.dart';
import 'package:ha_display/state/display_state.dart';
import 'package:ha_display/state/ha_info.dart';
import 'package:ha_display/state/settings.dart';
import 'package:ha_display/widgets/finished_alert.dart';
import 'package:ha_display/widgets/ha_overlay.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockKiosk extends Mock implements Kiosk {}

class _FakeHaInfo extends HaInfoNotifier {
  _FakeHaInfo(this.snapshot);

  final HaSnapshot snapshot;

  @override
  HaSnapshot build() => snapshot;

  void show(HaSnapshot snapshot) => state = snapshot;
}

void main() {
  late _MockKiosk kiosk;
  late _FakeHaInfo info;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    kiosk = _MockKiosk();
    when(() => kiosk.isChildLocked()).thenAnswer((_) async => false);
    when(() => kiosk.speak(any(), any())).thenAnswer((_) async {});
  });

  Future<void> pump(
    WidgetTester tester,
    Widget child,
    HaSnapshot start,
    Settings settings,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    info = _FakeHaInfo(start);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          kioskProvider.overrideWithValue(kiosk),
          haInfoProvider.overrideWith(() => info),
          settingsProvider.overrideWith(() => SettingsNotifier(settings)),
        ],
        child: MaterialApp(
          locale: const Locale('de'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: child),
        ),
      ),
    );
    await tester.pump();
  }

  final running = HaSnapshot(
    running: [
      RunningDevice(
        name: 'Waschmaschine',
        end: DateTime.now().add(const Duration(minutes: 1)),
      ),
    ],
  );

  testWidgets('blinks and speaks when an appliance finishes', (tester) async {
    await pump(
      tester,
      const FinishedAlert(),
      const HaSnapshot(),
      const Settings(isFinishedFlashOn: true, isFinishedSpeechOn: true),
    );
    info.show(running);
    await tester.pump();
    info.show(const HaSnapshot());
    await tester.pump();

    expect(find.text('Waschmaschine ist fertig'), findsOneWidget);
    verify(() => kiosk.speak('Waschmaschine ist fertig', 'de')).called(1);

    await tester.tap(find.text('Waschmaschine ist fertig'));
    await tester.pump();
    expect(find.text('Waschmaschine ist fertig'), findsNothing);
  });

  testWidgets('stays quiet with both options off', (tester) async {
    await pump(
      tester,
      const FinishedAlert(),
      const HaSnapshot(),
      const Settings(),
    );
    info.show(running);
    await tester.pump();
    info.show(const HaSnapshot());
    await tester.pump();

    expect(find.text('Waschmaschine ist fertig'), findsNothing);
    verifyNever(() => kiosk.speak(any(), any()));
  });

  testWidgets('shows a charging device until it is swiped away', (
    tester,
  ) async {
    await pump(
      tester,
      const HaOverlay(onOpenDashboard: null, isLifted: false),
      const HaSnapshot(charging: [ChargingDevice(name: 'Telefon', level: 73)]),
      const Settings(),
    );
    expect(find.text('Telefon'), findsOneWidget);
    expect(find.text('73 %'), findsOneWidget);

    await tester.drag(find.text('73 %'), const Offset(800, 0));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Telefon'), findsNothing);
  });
}
