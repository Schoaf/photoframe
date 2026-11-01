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
    return 'Login failed (error $code). Use a user without 2-factor sign-in.';
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
}
