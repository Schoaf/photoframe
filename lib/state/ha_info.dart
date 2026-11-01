import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/ha_client.dart';
import 'settings.dart';

/// Weather and warnings from Home Assistant, live while the app runs.
class HaInfoNotifier extends Notifier<HaSnapshot> {
  @override
  HaSnapshot build() {
    final settings = ref.watch(settingsProvider);
    if (!settings.hasHaInfo) return const HaSnapshot();
    final client = HaClient(
      baseUrl: settings.dashboardUrl,
      token: settings.haToken,
      weatherEntityId: settings.weatherEntityId.trim(),
      onUpdate: (snapshot) => state = snapshot,
    )..start();
    ref.onDispose(client.stop);
    return const HaSnapshot();
  }
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
