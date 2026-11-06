import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ha_display/l10n/app_localizations.dart';
import 'package:ha_display/services/ha_client.dart';
import 'package:ha_display/services/ha_calendar.dart';
import 'package:ha_display/state/calendar.dart';
import 'package:ha_display/state/ha_info.dart';
import 'package:ha_display/theme/app_theme.dart';
import 'package:ha_display/widgets/ha_overlay.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeHaInfo extends HaInfoNotifier {
  _FakeHaInfo(this.snapshot);

  final HaSnapshot snapshot;

  @override
  HaSnapshot build() => snapshot;
}

class _FakeCalendar extends CalendarNotifier {
  _FakeCalendar(this.calendar);

  final CalendarState calendar;

  @override
  CalendarState build() => calendar;
}

Future<void> _pumpOverlay(
  WidgetTester tester,
  List<RunningDevice> running, {
  CalendarState calendar = const CalendarState(),
}) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      // A fresh scope, so a second pump gets the new appliances.
      key: UniqueKey(),
      overrides: [
        haInfoProvider.overrideWith(
          () => _FakeHaInfo(HaSnapshot(running: running)),
        ),
        calendarProvider.overrideWith(() => _FakeCalendar(calendar)),
      ],
      child: const MaterialApp(
        locale: Locale('de'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: HaOverlay(onOpenDashboard: null, isLifted: false),
      ),
    ),
  );
  // Past the slide-in; pumpAndSettle would wait forever for the pulse.
  await tester.pump(const Duration(seconds: 1));
}

/// The tile's background colour.
Color? _tileColor(WidgetTester tester) =>
    (tester.widget<AnimatedContainer>(find.byType(AnimatedContainer)).decoration
            as BoxDecoration?)
        ?.color;

/// The fade right around the whole tile (the slide-in fades too).
bool _isPulsing(WidgetTester tester) =>
    tester
        .widget<FadeTransition>(
          find
              .ancestor(
                of: find.byType(AnimatedContainer),
                matching: find.byType(FadeTransition),
              )
              .first,
        )
        .opacity !=
    kAlwaysCompleteAnimation;

void main() {
  const noEvents = 'Heute und morgen keine Termine';
  const unavailable = 'Kalender nicht erreichbar';

  testWidgets('says so when the calendars have no events', (tester) async {
    await _pumpOverlay(
      tester,
      const [],
      calendar: const CalendarState(status: CalendarStatus.loaded),
    );
    expect(find.text(noEvents), findsOneWidget);
    expect(find.text(unavailable), findsNothing);
  });

  testWidgets('tells a failed read from a free day', (tester) async {
    await _pumpOverlay(
      tester,
      const [],
      calendar: const CalendarState(status: CalendarStatus.failed),
    );
    expect(find.text(unavailable), findsOneWidget);
    expect(find.text(noEvents), findsNothing);
  });

  testWidgets('shows no note while loading or without calendars', (
    tester,
  ) async {
    await _pumpOverlay(tester, const []);
    expect(find.text(noEvents), findsNothing);
    expect(find.text(unavailable), findsNothing);
  });

  testWidgets('private mode hides the note too', (tester) async {
    SharedPreferences.setMockInitialValues({'private_mode': true});
    addTearDown(() => SharedPreferences.setMockInitialValues({}));
    await _pumpOverlay(
      tester,
      const [],
      calendar: const CalendarState(status: CalendarStatus.loaded),
    );
    expect(find.text(noEvents), findsNothing);
  });

  testWidgets('keeps the last events after a failed read', (tester) async {
    final now = DateTime.now();
    await _pumpOverlay(
      tester,
      const [],
      calendar: CalendarState(
        status: CalendarStatus.failed,
        events: [
          CalendarEvent(
            title: 'Zahnarzt',
            start: now.add(const Duration(hours: 1)),
            end: now.add(const Duration(hours: 2)),
            isAllDay: false,
          ),
        ],
      ),
    );
    expect(find.text('Zahnarzt'), findsOneWidget);
    expect(find.text(unavailable), findsNothing);
  });

  testWidgets('an appliance past its end shows an unknown time, no pulse', (
    tester,
  ) async {
    final now = DateTime.now();
    await _pumpOverlay(tester, [
      RunningDevice(
        name: 'Trockner',
        end: now.subtract(const Duration(minutes: 5)),
        progress: 90,
      ),
    ]);
    expect(find.text('noch ? min'), findsOneWidget);
    expect(_tileColor(tester), const Color(0xE6FB8C00));
    expect(_isPulsing(tester), isFalse);
    final bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.value, 1);
  });

  testWidgets('appliance tiles are at least the minimum width', (tester) async {
    final now = DateTime.now();
    await _pumpOverlay(tester, [
      RunningDevice(
        name: 'Geschirrspüler',
        icon: 'mdi:dishwasher',
        end: now.add(const Duration(minutes: 42)),
        progress: 30,
      ),
      RunningDevice(
        name: 'Trockner',
        icon: 'mdi:tumble-dryer',
        end: now.add(const Duration(hours: 2, minutes: 5)),
        progress: 10,
      ),
    ]);

    final bars = find.byType(LinearProgressIndicator);
    expect(bars, findsNWidgets(2));
    for (final bar in bars.evaluate()) {
      final tile = find.ancestor(
        of: find.byWidget(bar.widget),
        matching: find.byType(IntrinsicWidth),
      );
      expect(
        tester.getSize(tile).width,
        greaterThanOrEqualTo(AppSizes.deviceTileMinWidth - 28),
      );
    }
    expect(find.text('noch 42 min'), findsOneWidget);
  });

  testWidgets('turns orange 3 minutes before the end, pulses in the last', (
    tester,
  ) async {
    final now = DateTime.now();
    await _pumpOverlay(tester, [
      RunningDevice(
        name: 'Trockner',
        end: now.add(const Duration(minutes: 10)),
      ),
    ]);
    expect(_tileColor(tester), const Color(0x99000000));
    expect(_isPulsing(tester), isFalse);

    await _pumpOverlay(tester, [
      RunningDevice(name: 'Trockner', end: now.add(const Duration(minutes: 2))),
    ]);
    await tester.pump(const Duration(seconds: 1));
    expect(_tileColor(tester), const Color(0xE6FB8C00));
    expect(_isPulsing(tester), isFalse);

    await _pumpOverlay(tester, [
      RunningDevice(
        name: 'Trockner',
        end: now.add(const Duration(seconds: 40)),
      ),
    ]);
    expect(_isPulsing(tester), isTrue);
  });
}
