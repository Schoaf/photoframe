import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/ha_client.dart';
import 'settings.dart';

/// Weather, warnings and music from Home Assistant, live while the app
/// runs.
class HaInfoNotifier extends Notifier<HaSnapshot> {
  HaClient? _client;

  @override
  HaSnapshot build() {
    final settings = ref.watch(settingsProvider);
    if (!settings.hasHaInfo) return const HaSnapshot();
    final client = HaClient(
      baseUrl: settings.dashboardUrl,
      token: settings.haToken,
      weatherEntityId: settings.weatherEntityId.trim(),
      playerEntityIds: settings.mediaPlayerEntityIds,
      onUpdate: (snapshot) => state = snapshot,
    )..start();
    _client = client;
    ref.onDispose(client.stop);
    return const HaSnapshot();
  }

  /// `media_previous_track`, `media_play_pause` or `media_next_track`.
  void mediaCommand(String entityId, String service) =>
      _client?.callService('media_player', service, entityId);
}

final haInfoProvider = NotifierProvider<HaInfoNotifier, HaSnapshot>(
  HaInfoNotifier.new,
);

/// Warnings swiped away stay hidden for the rest of the day and show again
/// from midnight.
class DismissedWarnings {
  /// Warning id → the midnight it shows again.
  final _until = <String, DateTime>{};

  void dismiss(String id, DateTime now) =>
      _until[id] = DateTime(now.year, now.month, now.day + 1);

  List<HaWarning> visible(List<HaWarning> active, DateTime now) {
    _until.removeWhere((_, until) => !now.isBefore(until));
    return [
      for (final warning in active)
        if (!_until.containsKey(warning.id)) warning,
    ];
  }
}
