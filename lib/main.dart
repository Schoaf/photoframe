import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'l10n/app_localizations.dart';
import 'screens/display_screen.dart';
import 'screens/settings_form.dart';
import 'services/kiosk.dart';
import 'state/mqtt.dart';
import 'state/settings.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await loadSettings();
  final deviceId = await loadDeviceId();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  // Also after "Kiosk beenden": starting the app again means kiosk again.
  try {
    await const Kiosk().startLock();
  } on PlatformException {
    // Not lockable yet - stays a normal full-screen app.
  }
  runApp(
    ProviderScope(
      overrides: [
        settingsProvider.overrideWith(() => SettingsNotifier(settings)),
        deviceIdProvider.overrideWithValue(deviceId),
      ],
      child: const HaDisplayApp(),
    ),
  );
}

class HaDisplayApp extends ConsumerWidget {
  const HaDisplayApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      locale: switch (settings.languageCode) {
        final code? => Locale(code),
        null => null,
      },
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: settings.isConfigured ? const DisplayScreen() : const _SetupScreen(),
    );
  }
}

/// First start: nothing to show yet.
class _SetupScreen extends StatelessWidget {
  const _SetupScreen();

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Theme.of(context).colorScheme.surface,
    appBar: AppBar(title: Text(AppLocalizations.of(context).setupTitle)),
    body: const SettingsForm(),
  );
}
