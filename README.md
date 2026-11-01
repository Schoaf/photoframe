# HA Display

Kiosk app for a wall tablet. It has two modes:

- **Photo frame:** a full-screen slideshow of a Synology Photos album. You can swipe between photos, and a gallery lets you pick one. Videos play muted, and a sound button appears when you touch the screen.
- **Home Assistant dashboard:** shown full screen, with no header or sidebar.

Home Assistant controls the tablet over MQTT: screen on/off, mode, brightness, next photo and reload.

Built for the Samsung Galaxy Tab A 10.1 (2016, SM-T585, Android 8.1) in landscape. It needs Android 8.0 or newer.

## Set up the tablet

### 1. Make the app device owner (one time)

Device owner gives the app a real kiosk mode. Home, Recents and the notification shade are blocked. The tablet boots straight into the app, and Home Assistant can really switch the screen off.

Android only allows this while **no accounts** are on the device. You don't need a factory reset:

1. Settings → Konten und Sicherung → Konten: remove **all** accounts (Google, Samsung, …). Apps and files stay on the tablet.
2. Turn on USB debugging (Settings → Entwickleroptionen) and connect the tablet.
3. Install the app and make it device owner:
   ```sh
   flutter build apk --release
   adb install build/app/outputs/flutter-apk/app-release.apk
   adb shell dpm set-device-owner at.schoaf.ha_display/.KioskAdminReceiver
   ```
4. Add the accounts back.
5. In the Play Store, update **Android System WebView**. The Home Assistant frontend needs a current WebView.

Android 8.1 has two limits that the app can't change:

- The long-press power menu still appears.
- A short press of the power button turns the screen off. The next press goes straight back to the app, because the lock screen is disabled.

Without device owner the app still runs. Android then shows a screen pinning prompt, and "screen off" only blacks the screen out at minimum brightness.

### 2. First start

The settings screen opens on first start:

- **PIN:** 4–8 digits. You need it to open the menu.
- **Synology Photos:**
  - NAS address, e.g. `http://192.168.1.10:5000`.
  - A user, ideally a dedicated one with **no 2-factor sign-in** and read access to the album.
  - Tap "Alben laden" and pick the album. An album named `FotoFrame` is preselected.
- **Dashboard:** the full URL, e.g. `http://homeassistant.local:8123/lovelace/0`.
- **MQTT:** broker host, port, user and password.

**Menu:** tap the top-left corner **5 times quickly**, then enter the PIN. The menu offers:

- switch between photos and dashboard
- settings
- "Kiosk beenden" (the next app start locks again)
- "Device Owner entfernen" (needed before uninstalling)

### 3. Dashboard without header/sidebar

1. Install [kiosk-mode](https://github.com/NemesisRE/kiosk-mode) via HACS. The app adds `?kiosk` to the dashboard URL by itself.
2. Switch to the dashboard once and sign in there with "Angemeldet bleiben". The login stays saved in the app.

## Home Assistant

The tablet announces itself via MQTT discovery as a device (name from the settings). It has these entities:

| Entity | Purpose |
|---|---|
| `switch.<name>_screen` | Screen on/off |
| `select.<name>_mode` | `photos` / `dashboard` |
| `number.<name>_brightness` | 0–255 |
| `button.<name>_next_photo` | Next photo |
| `button.<name>_reload` | Reload photos/dashboard |

The device is unavailable while the app is offline (MQTT last will).

Example: screen off when nobody is home, on again when someone arrives:

```yaml
automation:
  - alias: Tablet aus, wenn niemand zuhause
    triggers:
      - trigger: state
        entity_id: zone.home
        to: "0"
    actions:
      - action: switch.turn_off
        target:
          entity_id: switch.ha_display_screen
  - alias: Tablet an, wenn jemand heimkommt
    triggers:
      - trigger: numeric_state
        entity_id: zone.home
        above: 0
    actions:
      - action: switch.turn_on
        target:
          entity_id: switch.ha_display_screen
      - action: select.select_option
        target:
          entity_id: select.ha_display_mode
        data:
          option: dashboard
```

## Slideshow

- Each photo stays for the configured time (default 15 s), and the slides advance by themselves.
- A video shorter than that **loops** until the time is up. A longer video plays **once to its end**.
- Every video starts muted.
- The album is reloaded every hour, so new photos show up by themselves.
- Photos load as the NAS's ready-made previews (about 1280 px), not as originals. Videos load as Synology's converted version when the NAS has made one, and as the original otherwise.

## Development

```sh
flutter test
flutter analyze
flutter run
```

The Synology Photos API isn't officially documented. All its calls are in `lib/services/synology_photos_client.dart`.
