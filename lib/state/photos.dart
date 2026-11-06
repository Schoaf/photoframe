import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/photo_item.dart';
import '../services/synology_photos_client.dart';
import 'settings.dart';

const _refreshInterval = Duration(hours: 1);

final synologyClientProvider = Provider<SynologyPhotosClient>((ref) {
  ref.watch(
    settingsProvider.select(
      (settings) => (
        settings.synologyUrl,
        settings.synologyUser,
        settings.synologyPassword,
        settings.albumPassphrase,
      ),
    ),
  );
  final settings = ref.read(settingsProvider);
  return SynologyPhotosClient(
    baseUrl: settings.synologyUrl,
    user: settings.synologyUser,
    password: settings.synologyPassword,
    passphrase: settings.albumPassphrase,
  );
});

/// The album's photos and videos, re-read every hour so pictures added to
/// the album show up on their own.
class AlbumItemsNotifier extends AsyncNotifier<List<PhotoItem>> {
  @override
  Future<List<PhotoItem>> build() async {
    ref.watch(
      settingsProvider.select(
        (settings) =>
            (settings.hasPhotos, settings.albumId, settings.isShuffled),
      ),
    );
    final settings = ref.read(settingsProvider);
    final albumId = settings.albumId;
    if (!settings.hasPhotos || albumId == null) return const [];
    final timer = Timer(_refreshInterval, ref.invalidateSelf);
    ref.onDispose(timer.cancel);
    final items = await ref
        .watch(synologyClientProvider)
        .listAlbumItems(albumId);
    return settings.isShuffled ? (List.of(items)..shuffle(Random())) : items;
  }
}

final albumItemsProvider =
    AsyncNotifierProvider<AlbumItemsNotifier, List<PhotoItem>>(
      AlbumItemsNotifier.new,
    );
