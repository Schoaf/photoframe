// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'HA Display';

  @override
  String get setupTitle => 'Set up HA Display';

  @override
  String get photosLoadError => 'Couldn\'t load the photos – retrying.';

  @override
  String get photosEmpty => 'The album is empty.';

  @override
  String get soundOn => 'Sound on';

  @override
  String get soundOff => 'Sound off';

  @override
  String get gallery => 'Gallery';

  @override
  String get backToSlideshow => 'Back to the slideshow';

  @override
  String galleryTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pictures',
      one: '1 picture',
    );
    return '$_temp0';
  }

  @override
  String get pinEnter => 'Enter PIN';

  @override
  String get pinWrong => 'Wrong PIN';

  @override
  String get removeDeviceOwner => 'Remove device owner';

  @override
  String get removeDeviceOwnerConfirm =>
      'This turns kiosk mode off and lets you uninstall the app. Restoring it needs the adb command again.';

  @override
  String get cancel => 'Cancel';

  @override
  String get remove => 'Remove';

  @override
  String get backToDisplay => 'Back to the display';

  @override
  String get showPhotos => 'Show photos';

  @override
  String get showDashboard => 'Show dashboard';

  @override
  String get endKiosk => 'End kiosk';

  @override
  String get endKioskHint => 'Until the app starts again';

  @override
  String get deviceOwnerMissing => 'Not device owner – limited kiosk';

  @override
  String get deviceOwnerActive => 'Kiosk mode active';

  @override
  String synologyLoginFailed(int code) {
    return 'Login failed (error $code).';
  }

  @override
  String synologyError(int code) {
    return 'Synology error $code';
  }

  @override
  String connectionFailed(String message) {
    return 'Connection failed: $message';
  }

  @override
  String get settingsSaved => 'Settings saved';

  @override
  String get sectionGeneral => 'General';

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'System';

  @override
  String get startMode => 'Start with';

  @override
  String get modePhotos => 'Photos';

  @override
  String get modeDashboard => 'Dashboard';

  @override
  String get pin => 'Menu PIN (4–8 digits)';

  @override
  String get pinInvalid => '4–8 digits';

  @override
  String get sectionPhotos => 'Photos (Synology Photos)';

  @override
  String get synologyUrl => 'NAS address';

  @override
  String get user => 'User';

  @override
  String get password => 'Password';

  @override
  String get loadAlbums => 'Load albums';

  @override
  String get album => 'Album';

  @override
  String albumEntry(String name, int count) {
    return '$name ($count)';
  }

  @override
  String currentAlbum(String name) {
    return 'Album: $name';
  }

  @override
  String slideSeconds(int seconds) {
    return 'Show each for: $seconds s';
  }

  @override
  String get shuffle => 'Shuffle';

  @override
  String get sectionDashboard => 'Home Assistant dashboard';

  @override
  String get dashboardUrl => 'Dashboard address';

  @override
  String get dashboardHint =>
      'The HACS plugin \"kiosk-mode\" hides the header and sidebar. Sign in to the dashboard the first time it opens and choose \"Keep me logged in\".';

  @override
  String get sectionMqtt => 'Home Assistant control (MQTT)';

  @override
  String get mqttHost => 'MQTT broker';

  @override
  String get mqttPort => 'Port';

  @override
  String get deviceName => 'Device name in Home Assistant';

  @override
  String get mqttHint =>
      'The tablet appears in Home Assistant as a device with a screen switch, mode select, brightness and buttons for \"Next photo\" and \"Reload\".';

  @override
  String get save => 'Save';

  @override
  String get tomorrow => 'Tomorrow';

  @override
  String idleSeconds(int seconds) {
    return 'Back to the photos after: $seconds s';
  }

  @override
  String get sectionHaInfo => 'Weather and notices from Home Assistant';

  @override
  String get haToken => 'Long-lived Home Assistant token of the tablet user';

  @override
  String get weatherEntity => 'Weather entity';

  @override
  String get haInfoHint =>
      'Create a separate HA user \"Tablet\" without admin rights, create a long-lived token under Profile → Security, and sign in to the dashboard with this user too. Notices come from the sensor sensor.tablet_warnungen (see README).';

  @override
  String get synologyWrongPassword => 'Wrong user or password.';

  @override
  String get synologyNoPermission =>
      'No permission (error 402). The user needs access to Synology Photos.';

  @override
  String get synologyTwoFactor =>
      'The user requires 2-factor sign-in. Use a user without 2-factor.';

  @override
  String get scanQr => 'Scan QR code';

  @override
  String get scanQrHint => 'Hold the QR code in front of the camera';

  @override
  String get switchCamera => 'Switch camera';

  @override
  String get sectionUpdates => 'App updates';

  @override
  String get updateHint =>
      'The app looks for a newer GitHub release at start and once a day and installs it itself. For a private repository use a fine-grained token with read access to this repository only (Contents: Read).';

  @override
  String get checkForUpdates => 'Check for updates';

  @override
  String installedVersion(int code) {
    return 'Installed: version $code';
  }

  @override
  String get updateUpToDate => 'The app is up to date.';

  @override
  String get updateInstalling =>
      'Installing the update – the app restarts in a moment.';

  @override
  String updateFailed(String message) {
    return 'Update failed. $message';
  }

  @override
  String updateRepoNotFound(String repo) {
    return 'Repository \"$repo\" not found. Check the name (owner/name) – a private repository needs a token.';
  }

  @override
  String get updateNoRelease =>
      'The repository has no release yet. Create one with tool/publish_release.sh.';

  @override
  String updateInvalidRelease(String tag) {
    return 'The latest release \"$tag\" doesn\'t fit: it needs a tag like v1.1.0+2 and the file PhotoFrame.apk.';
  }

  @override
  String get updateTokenInvalid => 'The GitHub token is invalid or expired.';

  @override
  String get updateNoAccess =>
      'No access to the repository. The token needs read access (Contents: Read).';

  @override
  String get updateRateLimited =>
      'GitHub counted too many requests. Try again later.';

  @override
  String get updateOffline =>
      'GitHub can\'t be reached. Check the internet connection.';

  @override
  String get updateRepo => 'GitHub repository';

  @override
  String get githubToken => 'GitHub token (private repository only)';

  @override
  String remainingMinutes(int minutes) {
    return '$minutes min left';
  }

  @override
  String remainingHours(String time) {
    return '$time h left';
  }

  @override
  String get remainingUnknown => '? min left';

  @override
  String get today => 'Today';

  @override
  String get allDay => 'all day';

  @override
  String get noEvents => 'No events today or tomorrow';

  @override
  String get calendarUnavailable => 'Calendar unavailable';

  @override
  String get calendars => 'Calendars';

  @override
  String get loadCalendars => 'Load calendars';

  @override
  String get noCalendars =>
      'No calendars found. Calendars are set up in HA under Devices & services.';

  @override
  String get loadPlayers => 'Load players';

  @override
  String get noPlayers => 'No media players found.';

  @override
  String get previousTrack => 'Previous track';

  @override
  String get playPause => 'Play/pause';

  @override
  String get nextTrack => 'Next track';

  @override
  String get weatherView => 'Weather view';

  @override
  String get calendarView => 'Calendar view';

  @override
  String get warningsView => 'Warnings view';

  @override
  String get devicesView => 'Appliances view';

  @override
  String get dashboardViewsHint =>
      'This dashboard view (the view\'s URL path in HA) opens when you tap the weather, the agenda, a warning or a running appliance. Empty = main view. An appliance can name its own view in the template with \"ansicht\".';

  @override
  String motionScreenOff(int minutes) {
    return 'Screen off without motion after: $minutes min';
  }

  @override
  String motionDarkLevel(int level) {
    return 'Dark below brightness: $level';
  }

  @override
  String deviceFinished(String name) {
    return '$name is done';
  }

  @override
  String get finishedFlash => 'Appliance done: screen blinks with a message';

  @override
  String get finishedSpeech => 'Appliance done: the tablet says it';

  @override
  String finishedSpeechVolume(int percent) {
    return 'Announcement volume: $percent %';
  }

  @override
  String get speechTest => 'Test';

  @override
  String get speechSample => 'This is how loud announcements are';

  @override
  String get motionScreenOffNever => 'Screen off without motion: never';

  @override
  String get motionHint =>
      'The front camera detects motion – evaluated on the tablet only, nothing is stored or sent. Motion switches the screen back on, unless Home Assistant switched it off. When the room is darker than the set brightness (0–255), no motion counts – lower = more sensitive in little light.';
}
