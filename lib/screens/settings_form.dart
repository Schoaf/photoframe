import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../models/photo_item.dart';
import '../services/synology_photos_client.dart';
import '../state/settings.dart';

const _defaultAlbumName = 'FotoFrame';

/// All settings on one scrolling page - used on first start and in the
/// menu.
class SettingsForm extends ConsumerStatefulWidget {
  const SettingsForm({super.key, this.onSaved});

  final VoidCallback? onSaved;

  @override
  ConsumerState<SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends ConsumerState<SettingsForm> {
  final _formKey = GlobalKey<FormState>();
  late Settings _settings;
  late final Map<String, TextEditingController> _text;
  List<PhotoAlbum>? _albums;
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
      'mqttHost': TextEditingController(text: _settings.mqttHost),
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
          final preferred = albums
              .where((album) => album.name == _defaultAlbumName)
              .firstOrNull;
          if (preferred != null) {
            _settings = _settings.copyWith(
              albumId: preferred.id,
              albumName: preferred.name,
            );
          }
        }
      });
    } on SynologyException catch (e) {
      setState(
        () => _albumError = e.isLoginError
            ? l10n.synologyLoginFailed(e.code)
            : l10n.synologyError(e.code),
      );
    } on Exception catch (e) {
      setState(() => _albumError = l10n.connectionFailed('$e'));
    } finally {
      if (mounted) setState(() => _isLoadingAlbums = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final settings = _settings.copyWith(
      synologyUrl: _value('synologyUrl'),
      synologyUser: _value('synologyUser'),
      synologyPassword: _text['synologyPassword']!.text,
      dashboardUrl: _value('dashboardUrl'),
      mqttHost: _value('mqttHost'),
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
    }) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: _text[key],
        obscureText: isSecret,
        keyboardType: keyboardType,
        validator: validator,
        decoration: InputDecoration(labelText: label, hintText: hint),
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
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
        children: [
          section(l10n.sectionGeneral),
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
                  RegExp(r'^\d{4,8}$').hasMatch(value?.trim() ?? '')
                  ? null
                  : l10n.pinInvalid,
            ),
          ),
          section(l10n.sectionPhotos),
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
                      () => _settings = _settings.copyWith(
                        albumId: id,
                        albumName: albums
                            .firstWhere((album) => album.id == id)
                            .name,
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
          section(l10n.sectionDashboard),
          field(
            'dashboardUrl',
            l10n.dashboardUrl,
            hint: 'http://homeassistant.local:8123/lovelace/0',
            keyboardType: TextInputType.url,
          ),
          Text(l10n.dashboardHint, style: theme.textTheme.bodyMedium),
          section(l10n.sectionMqtt),
          pair(
            field('mqttHost', l10n.mqttHost, hint: 'homeassistant.local'),
            field(
              'mqttPort',
              l10n.mqttPort,
              keyboardType: TextInputType.number,
            ),
          ),
          pair(
            field('mqttUser', l10n.user),
            field('mqttPassword', l10n.password, isSecret: true),
          ),
          field('deviceName', l10n.deviceName),
          Text(l10n.mqttHint, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 32),
          Align(
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
        ],
      ),
    );
  }
}
