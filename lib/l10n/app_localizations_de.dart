// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'HA Display';

  @override
  String get setupTitle => 'HA Display einrichten';

  @override
  String get photosLoadError =>
      'Fotos konnten nicht geladen werden – neuer Versuch läuft.';

  @override
  String get photosEmpty => 'Das Album ist leer.';

  @override
  String get soundOn => 'Ton ein';

  @override
  String get soundOff => 'Ton aus';

  @override
  String get gallery => 'Galerie';

  @override
  String get backToSlideshow => 'Zurück zur Diashow';

  @override
  String galleryTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Bilder',
      one: '1 Bild',
    );
    return '$_temp0';
  }

  @override
  String get pinEnter => 'PIN eingeben';

  @override
  String get pinWrong => 'Falsche PIN';

  @override
  String get removeDeviceOwner => 'Device Owner entfernen';

  @override
  String get removeDeviceOwnerConfirm =>
      'Danach ist der Kiosk-Modus aus und die App lässt sich deinstallieren. Zum Wiederherstellen ist erneut der adb-Befehl nötig.';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get remove => 'Entfernen';

  @override
  String get backToDisplay => 'Zurück zur Anzeige';

  @override
  String get showPhotos => 'Fotos anzeigen';

  @override
  String get showDashboard => 'Dashboard anzeigen';

  @override
  String get endKiosk => 'Kiosk beenden';

  @override
  String get endKioskHint => 'Bis zum nächsten Start der App';

  @override
  String get deviceOwnerMissing => 'Kein Device Owner – eingeschränkter Kiosk';

  @override
  String get deviceOwnerActive => 'Kiosk-Modus aktiv';

  @override
  String synologyLoginFailed(int code) {
    return 'Anmeldung fehlgeschlagen (Fehler $code). Benutzer ohne 2-Faktor-Anmeldung verwenden.';
  }

  @override
  String synologyError(int code) {
    return 'Synology-Fehler $code';
  }

  @override
  String connectionFailed(String message) {
    return 'Verbindung fehlgeschlagen: $message';
  }

  @override
  String get settingsSaved => 'Einstellungen gespeichert';

  @override
  String get sectionGeneral => 'Allgemein';

  @override
  String get language => 'Sprache';

  @override
  String get languageSystem => 'System';

  @override
  String get startMode => 'Startansicht';

  @override
  String get modePhotos => 'Fotos';

  @override
  String get modeDashboard => 'Dashboard';

  @override
  String get pin => 'PIN für das Menü (4–8 Ziffern)';

  @override
  String get pinInvalid => '4–8 Ziffern';

  @override
  String get sectionPhotos => 'Fotos (Synology Photos)';

  @override
  String get synologyUrl => 'NAS-Adresse';

  @override
  String get user => 'Benutzer';

  @override
  String get password => 'Passwort';

  @override
  String get loadAlbums => 'Alben laden';

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
    return 'Anzeigedauer: $seconds s';
  }

  @override
  String get shuffle => 'Zufällige Reihenfolge';

  @override
  String get sectionDashboard => 'Home Assistant Dashboard';

  @override
  String get dashboardUrl => 'Dashboard-Adresse';

  @override
  String get dashboardHint =>
      'Kopf- und Seitenleiste blendet das HACS-Plugin „kiosk-mode“ aus. Beim ersten Öffnen im Dashboard anmelden und „Angemeldet bleiben“ wählen.';

  @override
  String get sectionMqtt => 'Home Assistant Steuerung (MQTT)';

  @override
  String get mqttHost => 'MQTT-Broker';

  @override
  String get mqttPort => 'Port';

  @override
  String get deviceName => 'Gerätename in Home Assistant';

  @override
  String get mqttHint =>
      'Das Tablet erscheint in Home Assistant als Gerät mit Bildschirm-Schalter, Modus-Auswahl, Helligkeit und Tasten für „Nächstes Foto“ und „Neu laden“.';

  @override
  String get save => 'Speichern';

  @override
  String get tomorrow => 'Morgen';

  @override
  String idleSeconds(int seconds) {
    return 'Zurück zu den Fotos nach: $seconds s';
  }

  @override
  String get sectionHaInfo => 'Wetter und Hinweise aus Home Assistant';

  @override
  String get haToken => 'Token des Tablet-Benutzers';

  @override
  String get weatherEntity => 'Wetter-Entität';

  @override
  String get haInfoHint =>
      'Einen eigenen HA-Benutzer „Tablet“ ohne Administrator-Rechte anlegen, dort unter Profil → Sicherheit ein langlebiges Token erstellen und mit diesem Benutzer auch im Dashboard anmelden. Hinweise kommen aus dem Sensor sensor.tablet_warnungen (siehe README).';
}
