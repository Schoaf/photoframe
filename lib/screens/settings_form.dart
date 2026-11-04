import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../models/photo_item.dart';
import '../services/ha_calendar.dart';
import '../services/ha_media.dart';
import '../services/synology_photos_client.dart';
import '../state/settings.dart';
import 'qr_scan_screen.dart';

/// Preselected when found (or when there is just one album).
const _defaultAlbumNames = {'fotoframe', 'fotorahmen', 'photo frame'};

/// The parts of the settings, picked in the menu on the left.
enum SettingsSection {
  general(Icons.tune),
  photos(Icons.photo_library),
  dashboard(Icons.dashboard),
  haInfo(Icons.wb_sunny_outlined),
  mqtt(Icons.hub),
  updates(Icons.system_update_alt);

  const SettingsSection(this.icon);

  final IconData icon;

  String title(AppLocalizations l10n) => switch (this) {
    general => l10n.sectionGeneral,
    photos => l10n.sectionPhotos,
    dashboard => l10n.sectionDashboard,
    haInfo => l10n.sectionHaInfo,
    mqtt => l10n.sectionMqtt,
    updates => l10n.sectionUpdates,
  };
}

/// One menu entry per settings section.
List<Widget> settingsSectionTiles(
  AppLocalizations l10n, {
  required SettingsSection selected,
  required ValueChanged<SettingsSection> onSelect,
}) => [
  for (final section in SettingsSection.values)
    ListTile(
      leading: Icon(section.icon),
      title: Text(section.title(l10n)),
      selected: section == selected,
      onTap: () => onSelect(section),
    ),
];

/// The settings of one [section] with the save button below - used on
/// first start and in the menu. Entries of the other sections are kept
/// while switching.
class SettingsForm extends ConsumerStatefulWidget {
  const SettingsForm({
    super.key,
    required this.section,
    required this.onShowSection,
    this.onSaved,
  });

  final SettingsSection section;

  /// Shows a section, e.g. the one with an invalid entry.
  final ValueChanged<SettingsSection> onShowSection;
  final VoidCallback? onSaved;

  @override
  ConsumerState<SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends ConsumerState<SettingsForm> {
  final _formKey = GlobalKey<FormState>();
  late Settings _settings;
  late final Map<String, TextEditingController> _text;
  List<PhotoAlbum>? _albums;
  List<HaCalendar>? _calendars;
  String? _calendarError;
  bool _isLoadingCalendars = false;
  List<HaMediaPlayer>? _players;
  String? _playerError;
  bool _isLoadingPlayers = false;
  String? _albumError;
  bool _isLoadingAlbums = false;

  @override
  void initState() {
    super.initState();
    _settings = ref.read(settingsProvider);
    _text = {
      'synologyUrl': TextEditingController(text: _settings.synologyUrl),
      'synologyUser': TextEditingController(text: _settings.synologyUser),
      'synologyPassword': TextEditingController(
        text: _settings.synologyPassword,
      ),
      'dashboardUrl': TextEditingController(text: _settings.dashboardUrl),
      'haToken': TextEditingController(text: _settings.haToken),
      'weatherEntityId': TextEditingController(text: _settings.weatherEntityId),
      'weatherView': TextEditingController(text: _settings.weatherView),
      'calendarView': TextEditingController(text: _settings.calendarView),
      'warningsView': TextEditingController(text: _settings.warningsView),
      'devicesView': TextEditingController(text: _settings.devicesView),
      'mqttHost': TextEditingController(text: _settings.mqttHost),
      'updateRepo': TextEditingController(text: _settings.updateRepo),
      'githubToken': TextEditingController(text: _settings.githubToken),
      'mqttPort': TextEditingController(text: '${_settings.mqttPort}'),
      'mqttUser': TextEditingController(text: _settings.mqttUser),
      'mqttPassword': TextEditingController(text: _settings.mqttPassword),
      'deviceName': TextEditingController(text: _settings.deviceName),
      'pin': TextEditingController(text: _settings.pin),
    };
  }

  @override
  void dispose() {
    for (final controller in _text.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String _value(String key) => _text[key]!.text.trim();

  Future<void> _loadAlbums() async {
    setState(() {
      _isLoadingAlbums = true;
      _albumError = null;
    });
    final l10n = AppLocalizations.of(context);
    try {
      final client = SynologyPhotosClient(
        baseUrl: _value('synologyUrl'),
        user: _value('synologyUser'),
        password: _text['synologyPassword']!.text,
      );
      final albums = await client.listAlbums();
      if (!mounted) return;
      setState(() {
        _albums = albums;
        if (_settings.albumId == null ||
            !albums.any((album) => album.id == _settings.albumId)) {
          final preferred = albums.length == 1
              ? albums.single
              : albums
                    .where(
                      (album) =>
                          _defaultAlbumNames.contains(album.name.toLowerCase()),
                    )
                    .firstOrNull;
          if (preferred != null) _selectAlbum(preferred);
        }
      });
    } on SynologyException catch (e) {
      setState(
        () => _albumError = switch (e) {
          _ when e.isWrongPassword => l10n.synologyWrongPassword,
          _ when e.isPermissionDenied => l10n.synologyNoPermission,
          _ when e.isTwoFactorRequired => l10n.synologyTwoFactor,
          _ when e.isLoginError => l10n.synologyLoginFailed(e.code),
          _ => l10n.synologyError(e.code),
        },
      );
    } on Exception catch (e) {
      setState(() => _albumError = l10n.connectionFailed('$e'));
    } finally {
      if (mounted) setState(() => _isLoadingAlbums = false);
    }
  }

  Future<void> _loadCalendars() async {
    setState(() {
      _isLoadingCalendars = true;
      _calendarError = null;
    });
    final l10n = AppLocalizations.of(context);
    try {
      final calendars = await HaCalendarClient(
        baseUrl: _value('dashboardUrl'),
        token: _value('haToken'),
      ).listCalendars();
      if (!mounted) return;
      setState(() {
        _calendars = calendars;
        if (calendars.isEmpty) _calendarError = l10n.noCalendars;
      });
    } on Exception catch (e) {
      setState(() => _calendarError = l10n.connectionFailed('$e'));
    } finally {
      if (mounted) setState(() => _isLoadingCalendars = false);
    }
  }

  Future<void> _loadPlayers() async {
    setState(() {
      _isLoadingPlayers = true;
      _playerError = null;
    });
    final l10n = AppLocalizations.of(context);
    try {
      final players = await listMediaPlayers(
        baseUrl: _value('dashboardUrl'),
        token: _value('haToken'),
      );
      if (!mounted) return;
      setState(() {
        _players = players;
        if (players.isEmpty) _playerError = l10n.noPlayers;
      });
    } on Exception catch (e) {
      setState(() => _playerError = l10n.connectionFailed('$e'));
    } finally {
      if (mounted) setState(() => _isLoadingPlayers = false);
    }
  }

  void _togglePlayer(String entityId, bool isSelected) => setState(() {
    final ids = [..._settings.mediaPlayerEntityIds]..remove(entityId);
    if (isSelected) ids.add(entityId);
    _settings = _settings.copyWith(mediaPlayerEntityIds: ids);
  });

  void _toggleCalendar(String entityId, bool isSelected) => setState(() {
    final ids = [..._settings.calendarEntityIds]..remove(entityId);
    if (isSelected) ids.add(entityId);
    _settings = _settings.copyWith(calendarEntityIds: ids);
  });

  static bool _isPinValid(String pin) =>
      RegExp(r'^\d{4,8}$').hasMatch(pin.trim());

  void _selectAlbum(PhotoAlbum album) => _settings = _settings.copyWith(
    albumId: album.id,
    albumName: album.name,
    albumPassphrase: album.passphrase,
  );

  Future<void> _scanInto(String key) async {
    final value = await Navigator.of(context)
        .push<String>(MaterialPageRoute(builder: (_) => const QrScanScreen()));
    if (value != null && mounted) setState(() => _text[key]!.text = value);
  }

  Future<void> _save() async {
    // Only the open section is on screen - the PIN lives in the general one.
    if (!_isPinValid(_text['pin']!.text)) {
      widget.onShowSection(SettingsSection.general);
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _formKey.currentState?.validate(),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    final settings = _settings.copyWith(
      synologyUrl: _value('synologyUrl'),
      synologyUser: _value('synologyUser'),
      synologyPassword: _text['synologyPassword']!.text,
      dashboardUrl: _value('dashboardUrl'),
      haToken: _value('haToken'),
      weatherEntityId: _value('weatherEntityId'),
      weatherView: _value('weatherView'),
      calendarView: _value('calendarView'),
      warningsView: _value('warningsView'),
      devicesView: _value('devicesView'),
      mqttHost: _value('mqttHost'),
      updateRepo: _value('updateRepo'),
      githubToken: _value('githubToken'),
      mqttPort: int.tryParse(_value('mqttPort')) ?? 1883,
      mqttUser: _value('mqttUser'),
      mqttPassword: _text['mqttPassword']!.text,
      deviceName: _value('deviceName').isEmpty
          ? 'HA Display'
          : _value('deviceName'),
      pin: _value('pin'),
    );
    await ref.read(settingsProvider.notifier).save(settings);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).settingsSaved)),
    );
    widget.onSaved?.call();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    Widget section(String title) => Padding(
      padding: const EdgeInsets.only(top: 32, bottom: 12),
      child: Text(title, style: theme.textTheme.titleLarge),
    );
    Widget field(
      String key,
      String label, {
      bool isSecret = false,
      String? hint,
      TextInputType? keyboardType,
      String? Function(String?)? validator,
      Widget? suffix,
    }) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: _text[key],
        obscureText: isSecret,
        keyboardType: keyboardType,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          suffixIcon: suffix,
        ),
      ),
    );
    // Two fields side by side - the SM-T585's 1280 dp width has room.
    Widget pair(Widget left, Widget right) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 16,
      children: [
        Expanded(child: left),
        Expanded(child: right),
      ],
    );
    final albums = _albums;
    final children = switch (widget.section) {
      SettingsSection.general => [
        Wrap(
          spacing: 24,
          runSpacing: 16,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(l10n.language),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(value: '', label: Text(l10n.languageSystem)),
                const ButtonSegment(value: 'de', label: Text('Deutsch')),
                const ButtonSegment(value: 'en', label: Text('English')),
              ],
              selected: {_settings.languageCode ?? ''},
              onSelectionChanged: (selection) => setState(
                () => _settings = _settings.copyWith(
                  languageCode: () =>
                      selection.first.isEmpty ? null : selection.first,
                ),
              ),
            ),
            Text(l10n.startMode),
            SegmentedButton<DisplayMode>(
              segments: [
                ButtonSegment(
                  value: DisplayMode.photos,
                  label: Text(l10n.modePhotos),
                  icon: const Icon(Icons.photo),
                ),
                ButtonSegment(
                  value: DisplayMode.dashboard,
                  label: Text(l10n.modeDashboard),
                  icon: const Icon(Icons.dashboard),
                ),
              ],
              selected: {_settings.startMode},
              onSelectionChanged: (selection) => setState(
                () =>
                    _settings = _settings.copyWith(startMode: selection.first),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: 300,
          child: field(
            'pin',
            l10n.pin,
            isSecret: true,
            keyboardType: TextInputType.number,
            validator: (value) =>
                _isPinValid(value ?? '') ? null : l10n.pinInvalid,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Text(
              _settings.motionScreenOffMinutes == 0
                  ? l10n.motionScreenOffNever
                  : l10n.motionScreenOff(_settings.motionScreenOffMinutes),
            ),
            Expanded(
              child: Slider(
                max: 60,
                divisions: 60,
                value: _settings.motionScreenOffMinutes.toDouble().clamp(0, 60),
                label: '${_settings.motionScreenOffMinutes} min',
                onChanged: (value) => setState(
                  () => _settings = _settings.copyWith(
                    motionScreenOffMinutes: value.round(),
                  ),
                ),
              ),
            ),
          ],
        ),
        Row(
          children: [
            Text(l10n.motionDarkLevel(_settings.motionDarkLevel)),
            Expanded(
              child: Slider(
                max: 60,
                divisions: 60,
                value: _settings.motionDarkLevel.toDouble().clamp(0, 60),
                label: '${_settings.motionDarkLevel}',
                onChanged: (value) => setState(
                  () => _settings = _settings.copyWith(
                    motionDarkLevel: value.round(),
                  ),
                ),
              ),
            ),
          ],
        ),
        Text(l10n.motionHint, style: theme.textTheme.bodyMedium),
      ],
      SettingsSection.photos => [
        field(
          'synologyUrl',
          l10n.synologyUrl,
          hint: 'http://192.168.1.10:5000',
          keyboardType: TextInputType.url,
        ),
        pair(
          field('synologyUser', l10n.user),
          field('synologyPassword', l10n.password, isSecret: true),
        ),
        Row(
          spacing: 16,
          children: [
            FilledButton.tonalIcon(
              onPressed: _isLoadingAlbums ? null : _loadAlbums,
              icon: const Icon(Icons.photo_album),
              label: Text(l10n.loadAlbums),
            ),
            if (albums != null)
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue:
                      albums.any((album) => album.id == _settings.albumId)
                      ? _settings.albumId
                      : null,
                  decoration: InputDecoration(labelText: l10n.album),
                  items: [
                    for (final album in albums)
                      DropdownMenuItem(
                        value: album.id,
                        child: Text(
                          l10n.albumEntry(album.name, album.itemCount),
                        ),
                      ),
                  ],
                  onChanged: (id) => setState(
                    () => _selectAlbum(
                      albums.firstWhere((album) => album.id == id),
                    ),
                  ),
                ),
              )
            else if (_settings.albumName.isNotEmpty)
              Text(l10n.currentAlbum(_settings.albumName)),
          ],
        ),
        if (_albumError case final error?)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              error,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        const SizedBox(height: 16),
        Row(
          children: [
            Text(l10n.slideSeconds(_settings.slideSeconds)),
            Expanded(
              child: Slider(
                min: 5,
                max: 120,
                divisions: 23,
                value: _settings.slideSeconds.toDouble().clamp(5, 120),
                label: '${_settings.slideSeconds} s',
                onChanged: (value) => setState(
                  () => _settings = _settings.copyWith(
                    slideSeconds: value.round(),
                  ),
                ),
              ),
            ),
          ],
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.shuffle),
          value: _settings.isShuffled,
          onChanged: (value) =>
              setState(() => _settings = _settings.copyWith(isShuffled: value)),
        ),
      ],
      SettingsSection.dashboard => [
        field(
          'dashboardUrl',
          l10n.dashboardUrl,
          hint: 'http://homeassistant.local:8123/lovelace/0',
          keyboardType: TextInputType.url,
        ),
        Text(l10n.dashboardHint, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 16),
        pair(
          field('weatherView', l10n.weatherView),
          field('calendarView', l10n.calendarView),
        ),
        pair(
          field('warningsView', l10n.warningsView),
          field('devicesView', l10n.devicesView),
        ),
        Text(l10n.dashboardViewsHint, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 16),
        Row(
          children: [
            Text(l10n.idleSeconds(_settings.idleSeconds)),
            Expanded(
              child: Slider(
                min: 30,
                max: 600,
                divisions: 19,
                value: _settings.idleSeconds.toDouble().clamp(30, 600),
                label: '${_settings.idleSeconds} s',
                onChanged: (value) => setState(
                  () => _settings = _settings.copyWith(
                    idleSeconds: value.round(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
      SettingsSection.haInfo => [
        field(
          'haToken',
          l10n.haToken,
          isSecret: true,
          // Far too long to type on the tablet - HA shows it as QR code.
          suffix: IconButton(
            iconSize: 32,
            tooltip: l10n.scanQr,
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () => _scanInto('haToken'),
          ),
        ),
        field(
          'weatherEntityId',
          l10n.weatherEntity,
          hint: 'weather.forecast_home',
        ),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton.tonalIcon(
              onPressed: _isLoadingCalendars ? null : _loadCalendars,
              icon: const Icon(Icons.calendar_month),
              label: Text(l10n.loadCalendars),
            ),
            for (final calendar
                in _calendars ??
                    [
                      for (final id in _settings.calendarEntityIds)
                        HaCalendar(entityId: id, name: id),
                    ])
              FilterChip(
                label: Text(calendar.name),
                selected: _settings.calendarEntityIds.contains(
                  calendar.entityId,
                ),
                onSelected: (isSelected) =>
                    _toggleCalendar(calendar.entityId, isSelected),
              ),
          ],
        ),
        if (_calendarError case final error?)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              error,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton.tonalIcon(
              onPressed: _isLoadingPlayers ? null : _loadPlayers,
              icon: const Icon(Icons.music_note),
              label: Text(l10n.loadPlayers),
            ),
            for (final player
                in _players ??
                    [
                      for (final id in _settings.mediaPlayerEntityIds)
                        HaMediaPlayer(entityId: id, name: id),
                    ])
              FilterChip(
                label: Text(player.name),
                selected: _settings.mediaPlayerEntityIds.contains(
                  player.entityId,
                ),
                onSelected: (isSelected) =>
                    _togglePlayer(player.entityId, isSelected),
              ),
          ],
        ),
        if (_playerError case final error?)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              error,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        const SizedBox(height: 16),
        Text(l10n.haInfoHint, style: theme.textTheme.bodyMedium),
      ],
      SettingsSection.mqtt => [
        pair(
          field('mqttHost', l10n.mqttHost, hint: 'homeassistant.local'),
          field('mqttPort', l10n.mqttPort, keyboardType: TextInputType.number),
        ),
        pair(
          field('mqttUser', l10n.user),
          field('mqttPassword', l10n.password, isSecret: true),
        ),
        field('deviceName', l10n.deviceName),
        Text(l10n.mqttHint, style: theme.textTheme.bodyMedium),
      ],
      SettingsSection.updates => [
        pair(
          field('updateRepo', l10n.updateRepo, hint: 'Schoaf/ha-display'),
          field(
            'githubToken',
            l10n.githubToken,
            isSecret: true,
            suffix: IconButton(
              iconSize: 32,
              tooltip: l10n.scanQr,
              icon: const Icon(Icons.qr_code_scanner),
              onPressed: () => _scanInto('githubToken'),
            ),
          ),
        ),
        Text(l10n.updateHint, style: theme.textTheme.bodyMedium),
      ],
    };
    return Form(
      key: _formKey,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
              children: [section(widget.section.title(l10n)), ...children],
            ),
          ),
          const Divider(height: 1),
          // Always in reach, whichever section is open.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            child: Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save),
                label: Text(l10n.save),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(200, 56),
                  textStyle: const TextStyle(fontSize: 18),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
