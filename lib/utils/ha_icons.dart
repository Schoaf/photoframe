import 'package:flutter/material.dart';

import 'mdi_icons.g.dart';

/// HA weather conditions → the icons HA itself shows for them.
IconData weatherIcon(String condition) =>
    mdiIcons[switch (condition) {
      'clear-night' => 'weather-night',
      'partlycloudy' => 'weather-partly-cloudy',
      'exceptional' => 'alert-circle-outline',
      _ => 'weather-$condition',
    }] ??
    mdiIcons['thermometer']!;

/// The `mdi:` icon set in HA, e.g. `mdi:dishwasher`.
IconData warningIcon(String? mdiIcon) =>
    mdiIcons[mdiIcon?.replaceFirst('mdi:', '')] ?? Icons.notifications_active;
