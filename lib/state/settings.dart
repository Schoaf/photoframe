import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum DisplayMode { photos, dashboard }

/// Everything configured in the settings screen. Passwords and the PIN are
/// kept in secure storage, the rest in shared preferences ([saveSettings]).
class Settings {
  const Settings({
    this.synologyUrl = '',
    this.synologyUser = '',
    this.synologyPassword = '',
    this.albumId,
    this.albumName = '',
    this.albumPassphrase = '',
    this.mqttHost = '',
    this.mqttPort = 1883,
    this.mqttUser = '',
    this.mqttPassword = '',
    this.deviceName = 'HA Display',
    this.dashboardUrl = '',
    this.haToken = '',
    this.weatherEntityId = 'weather.forecast_home',
    this.calendarEntityIds = const [],
    this.mediaPlayerEntityIds = const [],
    this.idleSeconds = 120,
    this.motionScreenOffMinutes = 0,
    this.motionDarkLevel = 12,
    this.weatherView = 'wetter',
    this.calendarView = 'kalender',
    this.warningsView = 'warnungen',
    this.devicesView = 'geraete',
    this.updateRepo = 'Schoaf/ha-display',
    this.githubToken = '',
    this.slideSeconds = 15,
    this.isShuffled = true,
    this.isFinishedFlashOn = false,
    this.isFinishedSpeechOn = false,
    this.finishedSpeechVolume = 50,
    this.startMode = DisplayMode.photos,
    this.pin = '',
    this.languageCode,
  });

  final String synologyUrl;
  final String synologyUser;
  final String synologyPassword;
  final int? albumId;
  final String albumName;

  /// Set when the album was shared with the user by someone else.
  final String albumPassphrase;
  final String mqttHost;
  final int mqttPort;
  final String mqttUser;
  final String mqttPassword;

  /// Name of the device in Home Assistant.
  final String deviceName;

  /// Full dashboard URL, e.g. `http://homeassistant.local:8123/lovelace/0`.
  final String dashboardUrl;

  /// Long-lived token of a dedicated non-admin "Tablet" user - for the
  /// weather and warnings overlay.
  final String haToken;
  final String weatherEntityId;

  /// HA calendars shown as today/tomorrow agenda.
  final List<String> calendarEntityIds;

  /// HA media players whose music shows on the photos.
  final List<String> mediaPlayerEntityIds;

  /// Back from the dashboard to the photos after this long untouched.
  final int idleSeconds;

  /// Screen off after this long without motion in front of the camera; 0
  /// leaves the camera off.
  final int motionScreenOffMinutes;

  /// Mean camera brightness (0-255) below which the room counts as dark
  /// and no motion counts.
  final int motionDarkLevel;

  /// Dashboard views (paths) a tap on the weather, the agenda, a warning or
  /// an appliance opens; empty for the main view. An appliance can name
  /// its own view in the template (`ansicht`).
  final String weatherView;
  final String calendarView;
  final String warningsView;
  final String devicesView;

  /// GitHub repo (`owner/name`) whose releases carry app updates.
  final String updateRepo;

  /// Read-only token for [updateRepo] while it is private.
  final String githubToken;
  final int slideSeconds;
  final bool isShuffled;

  /// An appliance finished: the whole screen blinks with a message.
  final bool isFinishedFlashOn;

  /// An appliance finished: the tablet says so.
  final bool isFinishedSpeechOn;

  /// Volume of what the tablet says, in percent of the maximum.
  final int finishedSpeechVolume;
  final DisplayMode startMode;

  /// Unlocks the menu; empty until set in the settings screen.
  final String pin;

  /// null follows the system language.
  final String? languageCode;

  bool get hasPhotos => synologyUrl.isNotEmpty && albumId != null;
  bool get hasDashboard => dashboardUrl.isNotEmpty;
  bool get hasMqtt => mqttHost.isNotEmpty;

  /// Home Assistant is reached at the dashboard URL's host.
  bool get hasHaInfo => hasDashboard && haToken.isNotEmpty;
  bool get isConfigured => (hasPhotos || hasDashboard) && pin.isNotEmpty;

  Settings copyWith({
    String? synologyUrl,
    String? synologyUser,
    String? synologyPassword,
    int? albumId,
    String? albumName,
    String? albumPassphrase,
    String? mqttHost,
    int? mqttPort,
    String? mqttUser,
    String? mqttPassword,
    String? deviceName,
    String? dashboardUrl,
    String? haToken,
    String? weatherEntityId,
    List<String>? calendarEntityIds,
    List<String>? mediaPlayerEntityIds,
    int? idleSeconds,
    int? motionScreenOffMinutes,
    int? motionDarkLevel,
    String? weatherView,
    String? calendarView,
    String? warningsView,
    String? devicesView,
    String? updateRepo,
    String? githubToken,
    int? slideSeconds,
    bool? isShuffled,
    bool? isFinishedFlashOn,
    bool? isFinishedSpeechOn,
    int? finishedSpeechVolume,
    DisplayMode? startMode,
    String? pin,
    String? Function()? languageCode,
  }) => Settings(
    synologyUrl: synologyUrl ?? this.synologyUrl,
    synologyUser: synologyUser ?? this.synologyUser,
    synologyPassword: synologyPassword ?? this.synologyPassword,
    albumId: albumId ?? this.albumId,
    albumName: albumName ?? this.albumName,
    albumPassphrase: albumPassphrase ?? this.albumPassphrase,
    mqttHost: mqttHost ?? this.mqttHost,
    mqttPort: mqttPort ?? this.mqttPort,
    mqttUser: mqttUser ?? this.mqttUser,
    mqttPassword: mqttPassword ?? this.mqttPassword,
    deviceName: deviceName ?? this.deviceName,
    dashboardUrl: dashboardUrl ?? this.dashboardUrl,
    haToken: haToken ?? this.haToken,
    weatherEntityId: weatherEntityId ?? this.weatherEntityId,
    calendarEntityIds: calendarEntityIds ?? this.calendarEntityIds,
    mediaPlayerEntityIds: mediaPlayerEntityIds ?? this.mediaPlayerEntityIds,
    idleSeconds: idleSeconds ?? this.idleSeconds,
    motionScreenOffMinutes:
        motionScreenOffMinutes ?? this.motionScreenOffMinutes,
    motionDarkLevel: motionDarkLevel ?? this.motionDarkLevel,
    weatherView: weatherView ?? this.weatherView,
    calendarView: calendarView ?? this.calendarView,
    warningsView: warningsView ?? this.warningsView,
    devicesView: devicesView ?? this.devicesView,
    updateRepo: updateRepo ?? this.updateRepo,
    githubToken: githubToken ?? this.githubToken,
    slideSeconds: slideSeconds ?? this.slideSeconds,
    isShuffled: isShuffled ?? this.isShuffled,
    isFinishedFlashOn: isFinishedFlashOn ?? this.isFinishedFlashOn,
    isFinishedSpeechOn: isFinishedSpeechOn ?? this.isFinishedSpeechOn,
    finishedSpeechVolume: finishedSpeechVolume ?? this.finishedSpeechVolume,
    startMode: startMode ?? this.startMode,
    pin: pin ?? this.pin,
    languageCode: languageCode != null ? languageCode() : this.languageCode,
  );
}

const _secureStorage = FlutterSecureStorage();

const _kSynologyPassword = 'synology_password';
const _kMqttPassword = 'mqtt_password';
const _kPin = 'pin';
const _kHaToken = 'ha_token';
const _kGithubToken = 'github_token';

Future<Settings> loadSettings() async {
  final prefs = await SharedPreferences.getInstance();
  final secrets = await _secureStorage.readAll();
  return Settings(
    synologyUrl: prefs.getString('synology_url') ?? '',
    synologyUser: prefs.getString('synology_user') ?? '',
    synologyPassword: secrets[_kSynologyPassword] ?? '',
    albumId: prefs.getInt('album_id'),
    albumName: prefs.getString('album_name') ?? '',
    albumPassphrase: prefs.getString('album_passphrase') ?? '',
    mqttHost: prefs.getString('mqtt_host') ?? '',
    mqttPort: prefs.getInt('mqtt_port') ?? 1883,
    mqttUser: prefs.getString('mqtt_user') ?? '',
    mqttPassword: secrets[_kMqttPassword] ?? '',
    deviceName: prefs.getString('device_name') ?? 'HA Display',
    dashboardUrl: prefs.getString('dashboard_url') ?? '',
    haToken: secrets[_kHaToken] ?? '',
    weatherEntityId:
        prefs.getString('weather_entity_id') ?? 'weather.forecast_home',
    calendarEntityIds: prefs.getStringList('calendar_entity_ids') ?? const [],
    mediaPlayerEntityIds:
        prefs.getStringList('media_player_entity_ids') ?? const [],
    idleSeconds: prefs.getInt('idle_seconds') ?? 120,
    motionScreenOffMinutes: prefs.getInt('motion_screen_off_minutes') ?? 0,
    motionDarkLevel: prefs.getInt('motion_dark_level') ?? 12,
    weatherView: prefs.getString('weather_view') ?? 'wetter',
    calendarView: prefs.getString('calendar_view') ?? 'kalender',
    warningsView: prefs.getString('warnings_view') ?? 'warnungen',
    devicesView: prefs.getString('devices_view') ?? 'geraete',
    updateRepo: prefs.getString('update_repo') ?? 'Schoaf/ha-display',
    githubToken: secrets[_kGithubToken] ?? '',
    slideSeconds: prefs.getInt('slide_seconds') ?? 15,
    isShuffled: prefs.getBool('is_shuffled') ?? true,
    isFinishedFlashOn: prefs.getBool('finished_flash') ?? false,
    isFinishedSpeechOn: prefs.getBool('finished_speech') ?? false,
    finishedSpeechVolume: prefs.getInt('finished_speech_volume') ?? 50,
    startMode:
        DisplayMode.values.asNameMap()[prefs.getString('start_mode')] ??
        DisplayMode.photos,
    pin: secrets[_kPin] ?? '',
    languageCode: prefs.getString('language_code'),
  );
}

Future<void> saveSettings(Settings settings) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('synology_url', settings.synologyUrl);
  await prefs.setString('synology_user', settings.synologyUser);
  if (settings.albumId case final albumId?) {
    await prefs.setInt('album_id', albumId);
  }
  await prefs.setString('album_name', settings.albumName);
  await prefs.setString('album_passphrase', settings.albumPassphrase);
  await prefs.setString('mqtt_host', settings.mqttHost);
  await prefs.setInt('mqtt_port', settings.mqttPort);
  await prefs.setString('mqtt_user', settings.mqttUser);
  await prefs.setString('device_name', settings.deviceName);
  await prefs.setString('dashboard_url', settings.dashboardUrl);
  await prefs.setString('weather_entity_id', settings.weatherEntityId);
  await prefs.setStringList('calendar_entity_ids', settings.calendarEntityIds);
  await prefs.setStringList(
    'media_player_entity_ids',
    settings.mediaPlayerEntityIds,
  );
  await prefs.setInt('idle_seconds', settings.idleSeconds);
  await prefs.setInt(
    'motion_screen_off_minutes',
    settings.motionScreenOffMinutes,
  );
  await prefs.setInt('motion_dark_level', settings.motionDarkLevel);
  await prefs.setString('weather_view', settings.weatherView);
  await prefs.setString('calendar_view', settings.calendarView);
  await prefs.setString('warnings_view', settings.warningsView);
  await prefs.setString('devices_view', settings.devicesView);
  await prefs.setString('update_repo', settings.updateRepo);
  await prefs.setInt('slide_seconds', settings.slideSeconds);
  await prefs.setBool('is_shuffled', settings.isShuffled);
  await prefs.setBool('finished_flash', settings.isFinishedFlashOn);
  await prefs.setBool('finished_speech', settings.isFinishedSpeechOn);
  await prefs.setInt('finished_speech_volume', settings.finishedSpeechVolume);
  await prefs.setString('start_mode', settings.startMode.name);
  if (settings.languageCode case final code?) {
    await prefs.setString('language_code', code);
  } else {
    await prefs.remove('language_code');
  }
  await _secureStorage.write(
    key: _kSynologyPassword,
    value: settings.synologyPassword,
  );
  await _secureStorage.write(key: _kMqttPassword, value: settings.mqttPassword);
  await _secureStorage.write(key: _kPin, value: settings.pin);
  await _secureStorage.write(key: _kHaToken, value: settings.haToken);
  await _secureStorage.write(key: _kGithubToken, value: settings.githubToken);
}

/// Loaded once in `main()` (Notifier.build() can't be async) and injected
/// via `overrideWith`.
class SettingsNotifier extends Notifier<Settings> {
  SettingsNotifier([this._initial = const Settings()]);

  final Settings _initial;

  @override
  Settings build() => _initial;

  Future<void> save(Settings settings) async {
    await saveSettings(settings);
    state = settings;
  }

  /// Applies right away - Home Assistant may set several in a row, and each
  /// has to build on the one before.
  Future<void> change(Settings Function(Settings) apply) async {
    state = apply(state);
    await saveSettings(state);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, Settings>(
  SettingsNotifier.new,
);
