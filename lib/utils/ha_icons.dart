import 'package:flutter/material.dart';

/// HA weather conditions → Material icons.
IconData weatherIcon(String condition) => switch (condition) {
  'sunny' => Icons.wb_sunny,
  'clear-night' => Icons.nightlight,
  'partlycloudy' => Icons.wb_cloudy,
  'cloudy' => Icons.cloud,
  'fog' => Icons.foggy,
  'rainy' || 'pouring' => Icons.umbrella,
  'lightning' || 'lightning-rainy' => Icons.thunderstorm,
  'snowy' || 'snowy-rainy' || 'hail' => Icons.ac_unit,
  'windy' || 'windy-variant' => Icons.air,
  _ => Icons.thermostat,
};

/// The Material icon closest to a warning's `mdi:` icon.
IconData warningIcon(String? mdiIcon) {
  final icon = mdiIcon ?? '';
  return switch (icon) {
    _ when icon.contains('washing') => Icons.local_laundry_service,
    _ when icon.contains('dryer') => Icons.dry_cleaning,
    _ when icon.contains('dishwasher') => Icons.countertops,
    _ when icon.contains('vacuum') || icon.contains('robot') =>
      Icons.cleaning_services,
    _ when icon.contains('water') => Icons.water_drop,
    _ when icon.contains('trash') || icon.contains('delete') => Icons.delete,
    _ when icon.contains('window') => Icons.window,
    _ when icon.contains('door') => Icons.door_front_door,
    _ when icon.contains('battery') => Icons.battery_alert,
    _ when icon.contains('mail') || icon.contains('package') =>
      Icons.markunread_mailbox,
    _ when icon.contains('plant') || icon.contains('flower') =>
      Icons.local_florist,
    _ => Icons.notifications_active,
  };
}
