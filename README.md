# HA Display

Kiosk app for a wall tablet. It combines a photo frame with a Home Assistant dashboard:

- **Photo frame (resting state):** a full-screen slideshow of a Synology Photos album. You can swipe between photos, and a gallery lets you pick one. Videos play muted, and a sound button appears when you touch the screen.
- **Overlay from Home Assistant:** clock, weather (now and tomorrow) and running appliances with remaining time and a progress bar sit in the top right. Notices that anyone in the family can deal with, such as "Waschmaschine ist fertig", appear at the bottom.
- **Dashboard on tap:** tapping the weather or a notice brings the dashboard up, full screen with no header or sidebar. After a while untouched (default 2 min) the photos come back.

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
- **Weather and notices:** token of the "Tablet" user (see below) and the weather entity.
- **MQTT:** broker host, port, user and password.

**Menu:** tap the top-left corner **5 times quickly**, then enter the PIN. The menu offers:

- switch between photos and dashboard
- settings, including the Tablet user's token, the weather entity and the time until the photos come back
- "Kiosk beenden" (the next app start locks again)
- "Device Owner entfernen" (needed before uninstalling)

### 3. Home Assistant user for the tablet

Create a **separate HA user** for the tablet, not your own:

1. Settings → People → Users → add user "Tablet". **No** administrator rights.
2. Sign in as "Tablet" and create a token under Profile → Security → Long-lived access tokens. Put it into the app's settings.
3. Sign in to the dashboard on the tablet as "Tablet" too.

The tablet then only has a restricted account. Note that a normal HA user can still read all states and switch devices; that's a limit of HA.

### 4. Dashboard without header/sidebar

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

## Weather and notices

- **Weather:** the app reads the weather entity from the settings (default `weather.forecast_home`), including its daily forecast for tomorrow.
- **Notices:** you choose in HA which ones appear. The tablet only reads one template sensor, so labels are evaluated in HA and the tablet's token needs no admin rights.

**1. Template sensor** (in `configuration.yaml`). It provides the notices (`warnungen`) and the running appliances (`laufend`). Adjust the entity names to your appliances:

```yaml
template:
  - sensor:
      - name: Tablet Warnungen
        unique_id: tablet_warnungen
        state: >
          {{ label_entities('tablet_warnung') | select('is_state', 'on') | list | count }}
        attributes:
          warnungen: >
            {% set ns = namespace(items=[]) %}
            {% for id in label_entities('tablet_warnung') | select('is_state', 'on') %}
              {% set ns.items = ns.items + [{'id': id, 'name': state_attr(id, 'friendly_name'), 'icon': state_attr(id, 'icon')}] %}
            {% endfor %}
            {{ ns.items }}
          laufend: >
            {% set ns = namespace(items=[]) %}
            {% set geraete = [
              ['Geschirrspüler', 'mdi:dishwasher', 'sensor.geschirrspuler_programm_endzeit', 'sensor.geschirrspuler_programm_fortschritt'],
              ['Waschmaschine', 'mdi:washing-machine', 'sensor.waschmaschine_programm_endzeit', 'sensor.waschmaschine_programm_fortschritt'],
              ['Trockner', 'mdi:tumble-dryer', 'sensor.dryer_expected_end', 'sensor.dryer_progress'],
            ] %}
            {% for name, icon, ende, fortschritt in geraete %}
              {% if has_value(ende) and as_datetime(states(ende)) > now() %}
                {% set ns.items = ns.items + [{'name': name, 'icon': icon, 'ende': states(ende), 'fortschritt': states(fortschritt) | float(none)}] %}
              {% endif %}
            {% endfor %}
            {% if is_state('binary_sensor.roborock_qrevo_s5v_reinigen', 'on') %}
              {% set ns.items = ns.items + [{'name': 'Roborock', 'icon': 'mdi:robot-vacuum',
                'start': (now() - timedelta(minutes=states('sensor.roborock_qrevo_s5v_reinigungszeit') | float(0))).isoformat(),
                'fortschritt': states('sensor.roborock_qrevo_s5v_reinigungsfortschritt') | float(none)}] %}
            {% endif %}
            {{ ns.items }}
```

**Running appliances:**

- They show below the weather with their remaining time and a bar from 0 to 100 %.
- `ende` is the end time. Without it (Roborock), the app estimates the remaining time from `start` and `fortschritt` (0–100).
- An appliance disappears once its end time has passed. The "fertig" notice takes over from there.

**2. Mark notices:**

- Give the entity the label `tablet_warnung` (Settings → Entities → entity → Labels).
- It shows while it is `on`.
- The text is its display name, so name it the way the family should read it.
- Technical things like "Gerät nicht erreichbar" never appear unless you label them.

**3. When the state isn't `on`**, a small template binary sensor helps:

```yaml
template:
  - binary_sensor:
      - name: Waschmaschine ist fertig
        icon: mdi:washing-machine
        state: "{{ is_state('sensor.waschmaschine_status', 'finished') }}"
      - name: "Roborock: Wasser wechseln"
        icon: mdi:water
        state: "{{ is_state('binary_sensor.roborock_water_shortage', 'on') }}"
```

The entity names in these examples depend on your devices.

**On the tablet:**

- Tapping a notice opens the dashboard.
- **Pressing and holding** hides it until the next time it turns on.
- At most three notices show at once.

## Calendar

- **Where it shows:** Today's and tomorrow's events appear in the top left. All-day events come first, today's past events drop off, and at most 6 entries show.
- **Which calendars:** Set them up in HA (Settings → Devices & services: Google Calendar, CalDAV for iCloud/Nextcloud/Synology, Remote Calendar for an ICS address, Local Calendar). Then pick them in the app's settings under "Kalender laden".
- **How it reads them:** The app uses HA's calendar API with the Tablet user's token and re-reads every 5 minutes.

## Music

- **Which players:** Pick them in the app's settings under "Player laden", e.g. the Music Assistant players. Pick only one entity per speaker, since Music Assistant adds its own player next to the speaker's.
- **Where it shows:** While a chosen player plays, a tile below the weather shows cover, title, artist and the time left. A paused player stays for 15 minutes.
- **Controls:** Tapping the tile shows previous, play/pause and next for a few seconds.
- **Phone:** HA only sees what plays on players it knows, e.g. Spotify (via the Spotify integration), Cast, Sonos or Music Assistant.

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
