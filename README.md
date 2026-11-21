# PhotoFrame

Kiosk app for a wall tablet: a photo frame with a Home Assistant overlay and dashboard. Built for the Samsung Galaxy Tab A 10.1 (2016, SM-T585, Android 8.1) in landscape; needs Android 8.0 or newer.

## Features

- **Photo frame:** a slideshow of a Synology Photos album, with swiping, shuffle and a gallery. Videos play muted, with a sound button on touch.
- **Overlay:** clock, weather now and tomorrow, today's and tomorrow's calendar events, running appliances with remaining time, and music with controls.
- **Notices:** the warnings HA counts under "Wartung", one notice per device. Swipe one away for the rest of the day. Devices labelled `tablet_hide_entity` never show.
- **Dashboard:** a tap on the weather, calendar, a notice or an appliance opens its dashboard view full screen. The photos come back after a while untouched.
- **Control from HA (MQTT):** screen on/off, mode, brightness, next photo, reload, child lock and private mode.
- **Child lock:** hardware keys, swiping and taps do nothing, and only HA switches the screen. A lock icon shows on touch.
- **Private mode:** hides the calendar.
- **Charging:** a device on the charger shows as a big battery in the middle with its name and level. Swipe it away until it next charges.
- **Appliance done (optional):** the whole screen blinks with "X ist fertig", and/or the tablet says it.
- **Screen off without motion:** the front camera turns the screen off after a set time without motion and on again at motion. The brightness below which the room counts as dark is set in the app.
- **Kiosk:** device owner, boots into the app, and the menu is behind a PIN. The settings are split into sections, and the app updates itself from GitHub releases.

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
- "Kiosk beenden": the app goes behind the others and a bar with Back, Home, Recent apps and PhotoFrame appears on screen. PhotoFrame returns to the app, which locks again. Without the accessibility step under [Home Assistant](#home-assistant) there's no bar, and on a tablet with hidden keys no way back: don't use it before that step.
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
| `switch.<name>_child_lock` | Child lock: the power and volume keys do nothing, only HA switches the screen; the photos can't be swiped, weather, agenda, notices, appliances and music don't react to taps - a tap or swipe shows a lock |
| `switch.<name>_private` | Private mode: the agenda isn't shown (the dashboard stays as it is) |
| `select.<name>_mode` | `photos` / `dashboard` |
| `number.<name>_brightness` | 0–255 |
| `switch.<name>_automatic_brightness` | Android's automatic brightness; setting a brightness switches it off. Needs the step below once |
| `number.<name>_media_volume` | Media volume in percent |
| `button.<name>_key_back`, `_key_home`, `_key_recent_apps` | Press these keys, for a tablet whose keys are out of reach. Need the step below once |
| `button.<name>_next_photo` | Next photo |
| `button.<name>_reload` | Reload photos/dashboard |

The device is unavailable while the app is offline (MQTT last will).

**Settings from afar:** Under "Configuration" on the device's page in HA you also find seconds per photo, shuffle, back to photos, screen off without motion, dark level, the appliance-done blinking and announcement, its volume with a test button, and the start mode. They work like entities anywhere in HA and apply right away, and the tablet remembers them. Passwords, tokens, addresses and the PIN stay on the tablet.

Automatic brightness and the keys need these steps, once per installation:

```bash
adb shell appops set at.schoaf.ha_display WRITE_SETTINGS allow
adb shell settings get secure enabled_accessibility_services
adb shell settings put secure enabled_accessibility_services <list from before>:at.schoaf.ha_display/.KeyService
adb shell settings put secure accessibility_enabled 1
```

The `put` replaces the whole list, so keep what `get` shows; with nothing there, leave out the list and the colon. The service reads nothing from other apps.

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

## Screen off without motion

- **Setting:** "Bildschirm aus ohne Bewegung" (general settings), 1–60 minutes; 0 leaves the camera off.
- **How:** the front camera watches the room at two frames per second, evaluated on the tablet only, nothing is stored or sent.
- **Off and on:** after that long without motion the screen goes off; the next motion switches it on again. An "off" from Home Assistant or the power button stays off.
- **Dark room:** below the brightness set in the app (mean camera brightness 0–255, default 12) no motion counts, so the screen goes off. Switching the light on counts as motion. Lower it if dim light should still count.
- The QR scanner in the settings borrows the camera; motion detection resumes about a minute later.

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
            {% set hidden = label_entities('tablet_hide_entity') %}
            {% set hidden_devices = label_devices('tablet_hide_entity') %}
            {% for id in issues + labelled if id not in hidden and device_id(id) not in hidden_devices %}
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
              ['Geschirrspüler', 'mdi:dishwasher', 'sensor.geschirrspuler_programm_endzeit', 'sensor.geschirrspuler_programm_fortschritt', ''],
              ['Waschmaschine', 'mdi:washing-machine', 'sensor.waschmaschine_programm_endzeit', 'sensor.waschmaschine_programm_fortschritt', 'input_select.washer_status'],
              ['Trockner', 'mdi:tumble-dryer', 'sensor.dryer_expected_end', 'sensor.dryer_progress', 'input_select.dryer_status'],
            ] %}
            {% for name, icon, ende, fortschritt, status in geraete %}
              {% if has_value(ende) and (as_datetime(states(ende)) > now() or is_state(status, 'Läuft')) %}
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
- The fifth column of `geraete` is an optional status entity. While it says `Läuft`, an appliance past its end time stays listed, with a full bar and "noch ? min".
- An appliance disappears once its end time has passed. The "fertig" notice takes over from there.

**Appliance done:** Switch these on in the settings under "Wetter und Hinweise". Both only happen while the screen is on, and only when an appliance leaves the list in its last 5 minutes or above 95 %, so a cancelled program stays quiet. The blinking lasts 30 seconds or until a tap. The voice is Android's text to speech, at the volume set below that switch; "Probe" plays a sample. That volume is the media volume while it speaks, so music playing on the tablet changes along with it until the voice ends.

**Charging:** Add the attribute `ladend` to `sensor.tablet_warnungen`. It finds every device with a charging sensor (class `battery_charging`, or the companion app's "Is charging" or "Battery state", which have to be switched on in the app) and a battery sensor. Devices at 100 % (a vacuum resting in its dock) and devices labelled `tablet_hide_entity` are left out.

```yaml
          ladend: >
            {% set ns = namespace(items=[], seen=[]) %}
            {% set hidden = label_devices('tablet_hide_entity') %}
            {% set on = states.binary_sensor | selectattr('state', 'eq', 'on') | list %}
            {% for charging in (on | selectattr('attributes.device_class', 'defined') | selectattr('attributes.device_class', 'eq', 'battery_charging') | list) + (on | selectattr('entity_id', 'search', '_is_charging$') | list) + (states.sensor | selectattr('entity_id', 'search', '_battery_state$') | selectattr('state', 'search', '^[Cc]harging$') | list) %}
              {% set dev = device_id(charging.entity_id) %}
              {% set batteries = (device_entities(dev) | select('search', '^sensor[.]') | select('is_state_attr', 'device_class', 'battery') | select('has_value') | list) if dev and dev not in hidden else [] %}
              {% if batteries and states(batteries[0]) | float(0) < 100 and dev not in ns.seen %}
                {% set ns.seen = ns.seen + [dev] %}
                {% set ns.items = ns.items + [{'name': device_attr(dev, 'name_by_user') or device_attr(dev, 'name'), 'icon': state_attr(batteries[0], 'icon'), 'ladung': states(batteries[0]) | float(none)}] %}
              {% endif %}
            {% endfor %}
            {{ ns.items }}
```

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
- **Never on the tablet:** Give a device or entity the label `tablet_hide_entity`. It still counts under "Wartung" in HA.
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

- **Where it shows:** Today's and tomorrow's events appear in the top left. All-day events come first, today's past events drop off, and at most 6 entries show. With nothing to show it says "Heute und morgen keine Termine", or "Kalender nicht erreichbar" if HA couldn't be read.
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
