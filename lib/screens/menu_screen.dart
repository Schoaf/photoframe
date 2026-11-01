import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../state/display_state.dart';
import '../state/mqtt.dart';
import '../state/settings.dart';
import '../theme/app_theme.dart';
import 'settings_form.dart';

/// Reached via the hidden corner taps + PIN. Actions left, details right.
class MenuScreen extends ConsumerStatefulWidget {
  const MenuScreen({super.key});

  @override
  ConsumerState<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends ConsumerState<MenuScreen> {
  bool? _isDeviceOwner;

  @override
  void initState() {
    super.initState();
    ref.read(kioskProvider).isDeviceOwner().then((isDeviceOwner) {
      if (mounted) setState(() => _isDeviceOwner = isDeviceOwner);
    });
  }

  void _show(DisplayMode mode) {
    ref.read(displayProvider.notifier).setMode(mode);
    Navigator.of(context).pop();
  }

  Future<void> _endKiosk() async {
    await ref.read(kioskProvider).stopLock();
    // Starting the app again locks it again (main → startLock).
    await SystemNavigator.pop();
  }

  Future<void> _removeDeviceOwner() async {
    final l10n = AppLocalizations.of(context);
    final isConfirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.removeDeviceOwner),
        content: Text(l10n.removeDeviceOwnerConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.remove),
          ),
        ],
      ),
    );
    if (isConfirmed != true) return;
    await ref.read(kioskProvider).removeDeviceOwner();
    await SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(settingsProvider);
    final mode = ref.watch(displayProvider.select((display) => display.mode));
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Row(
          children: [
            SizedBox(
              width: AppSizes.menuPaneWidth,
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 16),
                children: [
                  ListTile(
                    leading: const Icon(Icons.arrow_back),
                    title: Text(l10n.backToDisplay),
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.photo),
                    title: Text(l10n.showPhotos),
                    selected: mode == DisplayMode.photos,
                    enabled: settings.hasPhotos,
                    onTap: () => _show(DisplayMode.photos),
                  ),
                  ListTile(
                    leading: const Icon(Icons.dashboard),
                    title: Text(l10n.showDashboard),
                    selected: mode == DisplayMode.dashboard,
                    enabled: settings.hasDashboard,
                    onTap: () => _show(DisplayMode.dashboard),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.lock_open),
                    title: Text(l10n.endKiosk),
                    subtitle: Text(l10n.endKioskHint),
                    onTap: _endKiosk,
                  ),
                  if (_isDeviceOwner == true)
                    ListTile(
                      leading: const Icon(Icons.admin_panel_settings),
                      title: Text(l10n.removeDeviceOwner),
                      onTap: _removeDeviceOwner,
                    ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: Text(
                      _isDeviceOwner == false
                          ? l10n.deviceOwnerMissing
                          : l10n.deviceOwnerActive,
                    ),
                    subtitle: Text(
                      'MQTT: ha_display/${ref.watch(deviceIdProvider)}',
                    ),
                  ),
                ],
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: SettingsForm(onSaved: () => Navigator.of(context).pop()),
            ),
          ],
        ),
      ),
    );
  }
}
