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
      home: settings.isConfigured
          ? const DisplayScreen()
          : const _SetupScreen(),
    );
  }
}

/// First start: nothing to show yet.
class _SetupScreen extends StatefulWidget {
  const _SetupScreen();

  @override
  State<_SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<_SetupScreen> {
  var _section = SettingsSection.general;

  void _show(SettingsSection section) => setState(() => _section = section);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(title: Text(l10n.setupTitle)),
      body: Row(
        children: [
          SizedBox(
            width: AppSizes.menuPaneWidth,
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: settingsSectionTiles(
                l10n,
                selected: _section,
                onSelect: _show,
              ),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: SettingsForm(section: _section, onShowSection: _show),
          ),
        ],
      ),
    );
  }
}
