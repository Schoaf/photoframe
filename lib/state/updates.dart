import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/app_updater.dart';
import 'settings.dart';

const _checkInterval = Duration(hours: 24);

/// Checks for updates at start and once a day (watched by the display
/// screen); errors are ignored - the next check tries again.
final autoUpdateProvider = Provider<void>((ref) {
  final settings = ref.watch(settingsProvider);
  if (settings.updateRepo.trim().isEmpty) return;
  final updater = AppUpdater(
    repo: settings.updateRepo,
    token: settings.githubToken,
  );
  Future<void> check() async {
    try {
      await updater.checkAndInstall();
    } on Exception {
      // Offline or no release yet - try again tomorrow.
    }
  }

  check();
  final timer = Timer.periodic(_checkInterval, (_) => check());
  ref.onDispose(timer.cancel);
});
