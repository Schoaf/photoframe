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
- **Notices:** the same ones HA counts under "Wartung", plus your own. The tablet only reads one template sensor, so everything is evaluated in HA and the tablet's token needs no admin rights.

**1. Template sensor** (in `configuration.yaml`). It provides the notices (`warnungen`) and the running appliances (`laufend`). Adjust the entity names to your appliances:

```yaml
template:
  - sensor:
      - name: Tablet Warnungen
        unique_id: tablet_warnungen
        state: "{{ this.attributes.get('warnungen', []) | count }}"
        attributes:
          warnungen: >
            {% set ns = namespace(items=[], groups=[]) %}
            {% set issues = state_attr('sensor.maintenance_issues', 'issues') or [] %}
            {% set labelled = label_entities('tablet_warnung') | select('is_state', 'on') | reject('in', issues) | list %}
            {% for id in issues + labelled %}
              {% set dev = device_id(id) %}
              {% set geraet = (device_attr(dev, 'name_by_user') or device_attr(dev, 'name')) if dev else none %}
              {% set name = state_attr(id, 'friendly_name') or id %}
              {% set kurz = (name[geraet | length:] | trim if name.startswith(geraet) else name) if geraet else '' %}
              {% if is_state(id, 'unavailable') %}
                {% set text = (kurz ~ ' nicht erreichbar') | trim %}
                {% set icon = 'mdi:battery-unknown' %}
              {% elif id.startswith('sensor.') and id not in labelled %}
                {% set text = (kurz or 'Batterie') ~ ' ' ~ states(id) ~ ' %' %}
                {% set icon = 'mdi:battery-alert' %}
              {% else %}
                {% set text = kurz %}
                {% set icon = state_attr(id, 'icon') or 'mdi:alert-circle-outline' %}
              {% endif %}
              {% set ns.items = ns.items + [{'key': dev or id, 'id': id, 'title': geraet or name, 'text': text, 'icon': icon}] %}
            {% endfor %}
            {% for key in ns.items | map(attribute='key') | unique %}
              {% set group = ns.items | selectattr('key', 'eq', key) | list %}
              {% set ns.groups = ns.groups + [{
                'id': group | map(attribute='id') | sort | join(','),
                'name': group[0].title,
                'details': group | map(attribute='text') | select | unique | list,
                'icon': group[0].icon}] %}
            {% endfor %}
            {{ ns.groups }}
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

**2. Notices from "Wartung"** come from `sensor.maintenance_issues`, a trigger template sensor that applies the rules of HA's counter (its `issues` attribute lists the entity ids):

```yaml
template:
  - triggers:
      - trigger: homeassistant
        event: start
      - trigger: event
        event_type: event_template_reloaded
      - trigger: time_pattern
        minutes: /1
    sensor:
      - name: Wartung offene Punkte
        unique_id: maintenance_issues
        default_entity_id: sensor.maintenance_issues
        icon: mdi:wrench
        state: "{{ this.attributes.get('issues', []) | count }}"
        attributes:
          issues: >
            {% set excluded = [] %}
            {% set ns = namespace(l=[]) %}
            {% for s in states.sensor | selectattr('attributes.device_class', 'defined')
                  | selectattr('attributes.device_class', 'eq', 'battery') %}
              {% if s.state == 'unavailable' %}
                {% set ns.l = ns.l + [s.entity_id] %}
              {% elif s.state | is_number and s.state | float <= 20 %}
                {% set d = device_id(s.entity_id) %}
                {% set ch = (device_entities(d) if d else [])
                      | select('is_state_attr', 'device_class', 'battery_charging') | first | default('') %}
                {% if not is_state(ch, 'on') %}
                  {% set ns.l = ns.l + [s.entity_id] %}
                {% endif %}
              {% endif %}
            {% endfor %}
            {% for s in states.binary_sensor | selectattr('attributes.device_class', 'defined')
                  | selectattr('attributes.device_class', 'in', ['battery', 'problem']) %}
              {% if s.state in ['on', 'unavailable'] %}
                {% set ns.l = ns.l + [s.entity_id] %}
              {% endif %}
            {% endfor %}
            {{ ns.l | reject('in', excluded) | list }}
```

- It counts a battery at 20 % or less (unless its device is charging), a battery or `problem` binary sensor that is `on`, and an unavailable battery or problem entity.
- Put entities that shouldn't warn into `excluded`.
- Notices of the same device show as one: the device name in bold, below it one line per issue (e.g. "Batterie nicht erreichbar"). This includes labelled ones.
- It re-checks once a minute.

**Own notices:**

- Give the entity the label `tablet_warnung` (Settings → Entities → entity → Labels).
- It shows while it is `on`.
- The text is its display name, so name it the way the family should read it.

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
- **Swiping it away** hides it for the rest of the day; it shows again from midnight. A new issue of the same device shows at once.
- At most three notices show at once.

## Detail views

A tap on the overlay opens a view of the dashboard:

| Tap on | View (default) |
|---|---|
| Clock / weather | `wetter` |
| Agenda | `kalender` |
| Warning | `warnungen` |
| Running appliance | `geraete`, or the appliance's own `ansicht` |

- **Set up in HA:** Add these views to the tablet's dashboard (Edit dashboard → Add view → URL path), e.g. a weather forecast card with hourly and daily forecast, a calendar card with initial view "List (7 days)", an entities card per appliance.
- **Other paths:** Change them in the app's settings under Dashboard. Empty opens the main view.
- **Own view per appliance:** Add `'ansicht': 'geschirrspueler'` to its entry in `laufend`.
- The dashboard button and the idle timeout work as before: the button opens the main view.

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
