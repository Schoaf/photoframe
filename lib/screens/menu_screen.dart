import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../services/app_updater.dart';
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
  int? _versionCode;
  String? _updateStatus;
  bool _isCheckingUpdate = false;
  var _section = SettingsSection.general;

  @override
  void initState() {
    super.initState();
    ref.read(kioskProvider).isDeviceOwner().then((isDeviceOwner) {
      if (mounted) setState(() => _isDeviceOwner = isDeviceOwner);
    });
    ref.read(kioskProvider).versionCode().then((versionCode) {
      if (mounted) setState(() => _versionCode = versionCode);
    });
  }

  void _show(DisplayMode mode) {
    ref.read(displayProvider.notifier).setMode(mode);
    Navigator.of(context).pop();
  }

  Future<void> _checkUpdate() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _isCheckingUpdate = true;
      _updateStatus = null;
    });
    String status;
    try {
      final settings = ref.read(settingsProvider);
      final result = await AppUpdater(
        repo: settings.updateRepo,
        token: settings.githubToken,
        kiosk: ref.read(kioskProvider),
      ).checkAndInstall();
      status = switch (result) {
        UpdateResult.upToDate => l10n.updateUpToDate,
        UpdateResult.installing => l10n.updateInstalling,
      };
    } on UpdateException catch (e) {
      status = l10n.updateFailed(switch (e.problem) {
        UpdateProblem.repoNotFound => l10n.updateRepoNotFound(
          ref.read(settingsProvider).updateRepo.trim(),
        ),
        UpdateProblem.noRelease => l10n.updateNoRelease,
        UpdateProblem.invalidRelease => l10n.updateInvalidRelease(e.detail),
        UpdateProblem.tokenInvalid => l10n.updateTokenInvalid,
        UpdateProblem.noAccess => l10n.updateNoAccess,
        UpdateProblem.rateLimited => l10n.updateRateLimited,
        UpdateProblem.offline => l10n.updateOffline,
        UpdateProblem.unknown => e.detail,
      });
    } on Exception catch (e) {
      status = l10n.updateFailed('$e');
    }
    if (!mounted) return;
    setState(() {
      _isCheckingUpdate = false;
      _updateStatus = status;
    });
  }

  Future<void> _endKiosk() async {
    final display = ref.read(displayProvider.notifier);
    // Coming back locks again - not into the open menu.
    Navigator.of(context).popUntil((route) => route.isFirst);
    await display.endKiosk();
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
                  ...settingsSectionTiles(
                    l10n,
                    selected: _section,
                    onSelect: (section) => setState(() => _section = section),
                  ),
                  const Divider(),
                  ListTile(
                    leading: _isCheckingUpdate
                        ? const SizedBox.square(
                            dimension: 24,
                            child: CircularProgressIndicator(strokeWidth: 3),
                          )
                        : const Icon(Icons.system_update),
                    title: Text(l10n.checkForUpdates),
                    subtitle: Text(
                      _updateStatus ?? l10n.installedVersion(_versionCode ?? 0),
                    ),
                    enabled:
                        settings.updateRepo.isNotEmpty && !_isCheckingUpdate,
                    onTap: _checkUpdate,
                  ),
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
              child: SettingsForm(
                section: _section,
                onShowSection: (section) => setState(() => _section = section),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
