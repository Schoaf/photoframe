import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In de, this message translates to:
  /// **'HA Display'**
  String get appTitle;

  /// No description provided for @setupTitle.
  ///
  /// In de, this message translates to:
  /// **'HA Display einrichten'**
  String get setupTitle;

  /// No description provided for @photosLoadError.
  ///
  /// In de, this message translates to:
  /// **'Fotos konnten nicht geladen werden – neuer Versuch läuft.'**
  String get photosLoadError;

  /// No description provided for @photosEmpty.
  ///
  /// In de, this message translates to:
  /// **'Das Album ist leer.'**
  String get photosEmpty;

  /// No description provided for @soundOn.
  ///
  /// In de, this message translates to:
  /// **'Ton ein'**
  String get soundOn;

  /// No description provided for @soundOff.
  ///
  /// In de, this message translates to:
  /// **'Ton aus'**
  String get soundOff;

  /// No description provided for @gallery.
  ///
  /// In de, this message translates to:
  /// **'Galerie'**
  String get gallery;

  /// No description provided for @backToSlideshow.
  ///
  /// In de, this message translates to:
  /// **'Zurück zur Diashow'**
  String get backToSlideshow;

  /// No description provided for @galleryTitle.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =1{1 Bild} other{{count} Bilder}}'**
  String galleryTitle(int count);

  /// No description provided for @pinEnter.
  ///
  /// In de, this message translates to:
  /// **'PIN eingeben'**
  String get pinEnter;

  /// No description provided for @pinWrong.
  ///
  /// In de, this message translates to:
  /// **'Falsche PIN'**
  String get pinWrong;

  /// No description provided for @removeDeviceOwner.
  ///
  /// In de, this message translates to:
  /// **'Device Owner entfernen'**
  String get removeDeviceOwner;

  /// No description provided for @removeDeviceOwnerConfirm.
  ///
  /// In de, this message translates to:
  /// **'Danach ist der Kiosk-Modus aus und die App lässt sich deinstallieren. Zum Wiederherstellen ist erneut der adb-Befehl nötig.'**
  String get removeDeviceOwnerConfirm;

  /// No description provided for @cancel.
  ///
  /// In de, this message translates to:
  /// **'Abbrechen'**
  String get cancel;

  /// No description provided for @remove.
  ///
  /// In de, this message translates to:
  /// **'Entfernen'**
  String get remove;

  /// No description provided for @backToDisplay.
  ///
  /// In de, this message translates to:
  /// **'Zurück zur Anzeige'**
  String get backToDisplay;

  /// No description provided for @showPhotos.
  ///
  /// In de, this message translates to:
  /// **'Fotos anzeigen'**
  String get showPhotos;

  /// No description provided for @showDashboard.
  ///
  /// In de, this message translates to:
  /// **'Dashboard anzeigen'**
  String get showDashboard;

  /// No description provided for @endKiosk.
  ///
  /// In de, this message translates to:
  /// **'Kiosk beenden'**
  String get endKiosk;

  /// No description provided for @endKioskHint.
  ///
  /// In de, this message translates to:
  /// **'Bis zum nächsten Start der App'**
  String get endKioskHint;

  /// No description provided for @deviceOwnerMissing.
  ///
  /// In de, this message translates to:
  /// **'Kein Device Owner – eingeschränkter Kiosk'**
  String get deviceOwnerMissing;

  /// No description provided for @deviceOwnerActive.
  ///
  /// In de, this message translates to:
  /// **'Kiosk-Modus aktiv'**
  String get deviceOwnerActive;

  /// No description provided for @synologyLoginFailed.
  ///
  /// In de, this message translates to:
  /// **'Anmeldung fehlgeschlagen (Fehler {code}).'**
  String synologyLoginFailed(int code);

  /// No description provided for @synologyError.
  ///
  /// In de, this message translates to:
  /// **'Synology-Fehler {code}'**
  String synologyError(int code);

  /// No description provided for @connectionFailed.
  ///
  /// In de, this message translates to:
  /// **'Verbindung fehlgeschlagen: {message}'**
  String connectionFailed(String message);

  /// No description provided for @settingsSaved.
  ///
  /// In de, this message translates to:
  /// **'Einstellungen gespeichert'**
  String get settingsSaved;

  /// No description provided for @sectionGeneral.
  ///
  /// In de, this message translates to:
  /// **'Allgemein'**
  String get sectionGeneral;

  /// No description provided for @language.
  ///
  /// In de, this message translates to:
  /// **'Sprache'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In de, this message translates to:
  /// **'System'**
  String get languageSystem;

  /// No description provided for @startMode.
  ///
  /// In de, this message translates to:
  /// **'Startansicht'**
  String get startMode;

  /// No description provided for @modePhotos.
  ///
  /// In de, this message translates to:
  /// **'Fotos'**
  String get modePhotos;

  /// No description provided for @modeDashboard.
  ///
  /// In de, this message translates to:
  /// **'Dashboard'**
  String get modeDashboard;

  /// No description provided for @pin.
  ///
  /// In de, this message translates to:
  /// **'PIN für das Menü (4–8 Ziffern)'**
  String get pin;

  /// No description provided for @pinInvalid.
  ///
  /// In de, this message translates to:
  /// **'4–8 Ziffern'**
  String get pinInvalid;

  /// No description provided for @sectionPhotos.
  ///
  /// In de, this message translates to:
  /// **'Fotos (Synology Photos)'**
  String get sectionPhotos;

  /// No description provided for @synologyUrl.
  ///
  /// In de, this message translates to:
  /// **'NAS-Adresse'**
  String get synologyUrl;

  /// No description provided for @user.
  ///
  /// In de, this message translates to:
  /// **'Benutzer'**
  String get user;

  /// No description provided for @password.
  ///
  /// In de, this message translates to:
  /// **'Passwort'**
  String get password;

  /// No description provided for @loadAlbums.
  ///
  /// In de, this message translates to:
  /// **'Alben laden'**
  String get loadAlbums;

  /// No description provided for @album.
  ///
  /// In de, this message translates to:
  /// **'Album'**
  String get album;

  /// No description provided for @albumEntry.
  ///
  /// In de, this message translates to:
  /// **'{name} ({count})'**
  String albumEntry(String name, int count);

  /// No description provided for @currentAlbum.
  ///
  /// In de, this message translates to:
  /// **'Album: {name}'**
  String currentAlbum(String name);

  /// No description provided for @slideSeconds.
  ///
  /// In de, this message translates to:
  /// **'Anzeigedauer: {seconds} s'**
  String slideSeconds(int seconds);

  /// No description provided for @shuffle.
  ///
  /// In de, this message translates to:
  /// **'Zufällige Reihenfolge'**
  String get shuffle;

  /// No description provided for @sectionDashboard.
  ///
  /// In de, this message translates to:
  /// **'Home Assistant Dashboard'**
  String get sectionDashboard;

  /// No description provided for @dashboardUrl.
  ///
  /// In de, this message translates to:
  /// **'Dashboard-Adresse'**
  String get dashboardUrl;

  /// No description provided for @dashboardHint.
  ///
  /// In de, this message translates to:
  /// **'Kopf- und Seitenleiste blendet das HACS-Plugin „kiosk-mode“ aus. Beim ersten Öffnen im Dashboard anmelden und „Angemeldet bleiben“ wählen.'**
  String get dashboardHint;

  /// No description provided for @sectionMqtt.
  ///
  /// In de, this message translates to:
  /// **'Home Assistant Steuerung (MQTT)'**
  String get sectionMqtt;

  /// No description provided for @mqttHost.
  ///
  /// In de, this message translates to:
  /// **'MQTT-Broker'**
  String get mqttHost;

  /// No description provided for @mqttPort.
  ///
  /// In de, this message translates to:
  /// **'Port'**
  String get mqttPort;

  /// No description provided for @deviceName.
  ///
  /// In de, this message translates to:
  /// **'Gerätename in Home Assistant'**
  String get deviceName;

  /// No description provided for @mqttHint.
  ///
  /// In de, this message translates to:
  /// **'Das Tablet erscheint in Home Assistant als Gerät mit Bildschirm-Schalter, Modus-Auswahl, Helligkeit und Tasten für „Nächstes Foto“ und „Neu laden“.'**
  String get mqttHint;

  /// No description provided for @save.
  ///
  /// In de, this message translates to:
  /// **'Speichern'**
  String get save;

  /// No description provided for @tomorrow.
  ///
  /// In de, this message translates to:
  /// **'Morgen'**
  String get tomorrow;

  /// No description provided for @idleSeconds.
  ///
  /// In de, this message translates to:
  /// **'Zurück zu den Fotos nach: {seconds} s'**
  String idleSeconds(int seconds);

  /// No description provided for @sectionHaInfo.
  ///
  /// In de, this message translates to:
  /// **'Wetter und Hinweise aus Home Assistant'**
  String get sectionHaInfo;

  /// No description provided for @haToken.
  ///
  /// In de, this message translates to:
  /// **'Langlebiger Home-Assistant-Token des Tablet-Benutzers'**
  String get haToken;

  /// No description provided for @weatherEntity.
  ///
  /// In de, this message translates to:
  /// **'Wetter-Entität'**
  String get weatherEntity;

  /// No description provided for @haInfoHint.
  ///
  /// In de, this message translates to:
  /// **'Einen eigenen HA-Benutzer „Tablet“ ohne Administrator-Rechte anlegen, dort unter Profil → Sicherheit ein langlebiges Token erstellen und mit diesem Benutzer auch im Dashboard anmelden. Hinweise kommen aus dem Sensor sensor.tablet_warnungen (siehe README).'**
  String get haInfoHint;

  /// No description provided for @synologyWrongPassword.
  ///
  /// In de, this message translates to:
  /// **'Benutzer oder Passwort falsch.'**
  String get synologyWrongPassword;

  /// No description provided for @synologyNoPermission.
  ///
  /// In de, this message translates to:
  /// **'Keine Berechtigung (Fehler 402). Der Benutzer braucht Zugriff auf Synology Photos.'**
  String get synologyNoPermission;

  /// No description provided for @synologyTwoFactor.
  ///
  /// In de, this message translates to:
  /// **'Der Benutzer verlangt eine 2-Faktor-Anmeldung. Einen Benutzer ohne 2-Faktor verwenden.'**
  String get synologyTwoFactor;

  /// No description provided for @scanQr.
  ///
  /// In de, this message translates to:
  /// **'QR-Code scannen'**
  String get scanQr;

  /// No description provided for @scanQrHint.
  ///
  /// In de, this message translates to:
  /// **'QR-Code vor die Kamera halten'**
  String get scanQrHint;

  /// No description provided for @switchCamera.
  ///
  /// In de, this message translates to:
  /// **'Kamera wechseln'**
  String get switchCamera;

  /// No description provided for @sectionUpdates.
  ///
  /// In de, this message translates to:
  /// **'App-Updates'**
  String get sectionUpdates;

  /// No description provided for @updateHint.
  ///
  /// In de, this message translates to:
  /// **'Die App sucht beim Start und einmal täglich nach einem neueren GitHub-Release und installiert es selbst. Für ein privates Repository ein Fine-grained Token mit Lesezugriff nur auf dieses Repository verwenden (Contents: Read).'**
  String get updateHint;

  /// No description provided for @checkForUpdates.
  ///
  /// In de, this message translates to:
  /// **'Nach Updates suchen'**
  String get checkForUpdates;

  /// No description provided for @installedVersion.
  ///
  /// In de, this message translates to:
  /// **'Installiert: Version {code}'**
  String installedVersion(int code);

  /// No description provided for @updateUpToDate.
  ///
  /// In de, this message translates to:
  /// **'Die App ist aktuell.'**
  String get updateUpToDate;

  /// No description provided for @updateInstalling.
  ///
  /// In de, this message translates to:
  /// **'Update wird installiert – die App startet gleich neu.'**
  String get updateInstalling;

  /// No description provided for @updateFailed.
  ///
  /// In de, this message translates to:
  /// **'Update fehlgeschlagen. {message}'**
  String updateFailed(String message);

  /// No description provided for @updateRepoNotFound.
  ///
  /// In de, this message translates to:
  /// **'Repository „{repo}“ nicht gefunden. Name prüfen (Besitzer/Name) – bei einem privaten Repository ist ein Token nötig.'**
  String updateRepoNotFound(String repo);

  /// No description provided for @updateNoRelease.
  ///
  /// In de, this message translates to:
  /// **'Das Repository hat noch kein Release. Mit tool/publish_release.sh eines erstellen.'**
  String get updateNoRelease;

  /// No description provided for @updateInvalidRelease.
  ///
  /// In de, this message translates to:
  /// **'Das neueste Release „{tag}“ passt nicht: Es braucht einen Tag wie v1.1.0+2 und die Datei PhotoFrame.apk.'**
  String updateInvalidRelease(String tag);

  /// No description provided for @updateTokenInvalid.
  ///
  /// In de, this message translates to:
  /// **'Das GitHub-Token ist ungültig oder abgelaufen.'**
  String get updateTokenInvalid;

  /// No description provided for @updateNoAccess.
  ///
  /// In de, this message translates to:
  /// **'Kein Zugriff auf das Repository. Das Token braucht Lesezugriff (Contents: Read).'**
  String get updateNoAccess;

  /// No description provided for @updateRateLimited.
  ///
  /// In de, this message translates to:
  /// **'GitHub hat zu viele Anfragen gezählt. Später erneut versuchen.'**
  String get updateRateLimited;

  /// No description provided for @updateOffline.
  ///
  /// In de, this message translates to:
  /// **'GitHub ist nicht erreichbar. Internetverbindung prüfen.'**
  String get updateOffline;

  /// No description provided for @updateRepo.
  ///
  /// In de, this message translates to:
  /// **'GitHub-Repository'**
  String get updateRepo;

  /// No description provided for @githubToken.
  ///
  /// In de, this message translates to:
  /// **'GitHub-Token (nur bei privatem Repository)'**
  String get githubToken;

  /// No description provided for @remainingMinutes.
  ///
  /// In de, this message translates to:
  /// **'noch {minutes} min'**
  String remainingMinutes(int minutes);

  /// No description provided for @remainingHours.
  ///
  /// In de, this message translates to:
  /// **'noch {time} h'**
  String remainingHours(String time);

  /// No description provided for @remainingUnknown.
  ///
  /// In de, this message translates to:
  /// **'noch ? min'**
  String get remainingUnknown;

  /// No description provided for @today.
  ///
  /// In de, this message translates to:
  /// **'Heute'**
  String get today;

  /// No description provided for @allDay.
  ///
  /// In de, this message translates to:
  /// **'ganztägig'**
  String get allDay;

  /// No description provided for @noEvents.
  ///
  /// In de, this message translates to:
  /// **'Heute und morgen keine Termine'**
  String get noEvents;

  /// No description provided for @calendarUnavailable.
  ///
  /// In de, this message translates to:
  /// **'Kalender nicht erreichbar'**
  String get calendarUnavailable;

  /// No description provided for @calendars.
  ///
  /// In de, this message translates to:
  /// **'Kalender'**
  String get calendars;

  /// No description provided for @loadCalendars.
  ///
  /// In de, this message translates to:
  /// **'Kalender laden'**
  String get loadCalendars;

  /// No description provided for @noCalendars.
  ///
  /// In de, this message translates to:
  /// **'Keine Kalender gefunden. Kalender werden in HA unter Geräte & Dienste eingerichtet.'**
  String get noCalendars;

  /// No description provided for @loadPlayers.
  ///
  /// In de, this message translates to:
  /// **'Player laden'**
  String get loadPlayers;

  /// No description provided for @noPlayers.
  ///
  /// In de, this message translates to:
  /// **'Keine Media-Player gefunden.'**
  String get noPlayers;

  /// No description provided for @previousTrack.
  ///
  /// In de, this message translates to:
  /// **'Vorheriges Lied'**
  String get previousTrack;

  /// No description provided for @playPause.
  ///
  /// In de, this message translates to:
  /// **'Wiedergabe/Pause'**
  String get playPause;

  /// No description provided for @nextTrack.
  ///
  /// In de, this message translates to:
  /// **'Nächstes Lied'**
  String get nextTrack;

  /// No description provided for @weatherView.
  ///
  /// In de, this message translates to:
  /// **'Ansicht Wetter'**
  String get weatherView;

  /// No description provided for @calendarView.
  ///
  /// In de, this message translates to:
  /// **'Ansicht Kalender'**
  String get calendarView;

  /// No description provided for @warningsView.
  ///
  /// In de, this message translates to:
  /// **'Ansicht Warnungen'**
  String get warningsView;

  /// No description provided for @devicesView.
  ///
  /// In de, this message translates to:
  /// **'Ansicht Geräte'**
  String get devicesView;

  /// No description provided for @dashboardViewsHint.
  ///
  /// In de, this message translates to:
  /// **'Diese Dashboard-Ansicht (URL-Pfad der Ansicht in HA) öffnet sich beim Antippen von Wetter, Kalender, Warnung bzw. laufendem Gerät. Leer = Hauptansicht. Ein Gerät kann im Template mit „ansicht“ eine eigene Ansicht haben.'**
  String get dashboardViewsHint;

  /// No description provided for @motionScreenOff.
  ///
  /// In de, this message translates to:
  /// **'Bildschirm aus ohne Bewegung nach: {minutes} min'**
  String motionScreenOff(int minutes);

  /// No description provided for @motionDarkLevel.
  ///
  /// In de, this message translates to:
  /// **'Dunkel unter Helligkeit: {level}'**
  String motionDarkLevel(int level);

  /// No description provided for @deviceFinished.
  ///
  /// In de, this message translates to:
  /// **'{name} ist fertig'**
  String deviceFinished(String name);

  /// No description provided for @finishedFlash.
  ///
  /// In de, this message translates to:
  /// **'Gerät fertig: Bildschirm blinkt mit Meldung'**
  String get finishedFlash;

  /// No description provided for @finishedSpeech.
  ///
  /// In de, this message translates to:
  /// **'Gerät fertig: Tablet sagt es an'**
  String get finishedSpeech;

  /// No description provided for @finishedSpeechVolume.
  ///
  /// In de, this message translates to:
  /// **'Lautstärke der Ansage: {percent} %'**
  String finishedSpeechVolume(int percent);

  /// No description provided for @speechTest.
  ///
  /// In de, this message translates to:
  /// **'Probe'**
  String get speechTest;

  /// No description provided for @speechSample.
  ///
  /// In de, this message translates to:
  /// **'So laut ist die Ansage'**
  String get speechSample;

  /// No description provided for @motionScreenOffNever.
  ///
  /// In de, this message translates to:
  /// **'Bildschirm aus ohne Bewegung: nie'**
  String get motionScreenOffNever;

  /// No description provided for @motionHint.
  ///
  /// In de, this message translates to:
  /// **'Die Frontkamera erkennt Bewegung – ausgewertet nur am Tablet, nichts wird gespeichert oder gesendet. Bei Bewegung geht der Bildschirm wieder an, außer Home Assistant hat ihn ausgeschaltet. Ist der Raum dunkler als die eingestellte Helligkeit (0–255), zählt keine Bewegung – kleiner = empfindlicher bei wenig Licht.'**
  String get motionHint;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
