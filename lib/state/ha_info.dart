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

/// Warnings hidden by a long press stay hidden until they're gone from HA -
/// the next time they turn on, they show again.
class DismissedWarnings {
  final _ids = <String>{};

  void dismiss(String id) => _ids.add(id);

  List<HaWarning> visible(List<HaWarning> active) {
    _ids.retainWhere((id) => active.any((warning) => warning.id == id));
    return [
      for (final warning in active)
        if (!_ids.contains(warning.id)) warning,
    ];
  }
}
