import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ha_display/l10n/app_localizations.dart';
import 'package:ha_display/services/ha_client.dart';
import 'package:ha_display/state/ha_info.dart';
import 'package:ha_display/theme/app_theme.dart';
import 'package:ha_display/widgets/ha_overlay.dart';

class _FakeHaInfo extends HaInfoNotifier {
  _FakeHaInfo(this.snapshot);

  final HaSnapshot snapshot;

  @override
  HaSnapshot build() => snapshot;
}

void main() {
  testWidgets('appliance tiles are at least the minimum width', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final now = DateTime.now();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          haInfoProvider.overrideWith(
            () => _FakeHaInfo(
              HaSnapshot(
                running: [
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
                ],
              ),
            ),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('de'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: HaOverlay(onOpenDashboard: null, isLifted: false),
        ),
      ),
    );
    await tester.pumpAndSettle();

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
}
