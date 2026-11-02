import 'package:dio/dio.dart';

import 'ha_client.dart';

/// A paused player stays on screen this long, then it's taken as stopped -
/// Music Assistant players stay `paused` for hours.
const _pausedTimeout = Duration(minutes: 15);

class HaMediaPlayer {
  const HaMediaPlayer({required this.entityId, required this.name});

  final String entityId;
  final String name;
}

/// What a media player plays, from its `media_*` attributes.
class NowPlaying {
  const NowPlaying({
    required this.entityId,
    required this.title,
    required this.isPlaying,
    this.artist,
    this.pictureUrl,
    this.duration,
    this.position,
    this.positionUpdatedAt,
  });

  final String entityId;
  final String title;
  final String? artist;
  final bool isPlaying;

  /// Cover art, relative to HA (`/api/media_player_proxy/...`) or absolute.
  final String? pictureUrl;
  final Duration? duration;

  /// [position] was read at [positionUpdatedAt]; HA doesn't send updates
  /// while a track simply plays on.
  final Duration? position;
  final DateTime? positionUpdatedAt;

  Duration? positionAt(DateTime now) {
    final position = this.position;
    if (position == null) return null;
    final updatedAt = positionUpdatedAt;
    var current = position;
    if (isPlaying && updatedAt != null && now.isAfter(updatedAt)) {
      current += now.difference(updatedAt);
    }
    final duration = this.duration;
    return duration != null && current > duration ? duration : current;
  }

  Duration? remaining(DateTime now) {
    final position = positionAt(now);
    final duration = this.duration;
    if (position == null || duration == null) return null;
    return duration - position;
  }

  double? fraction(DateTime now) {
    final position = positionAt(now);
    final duration = this.duration;
    if (position == null || duration == null || duration <= Duration.zero) {
      return null;
    }
    return (position.inMilliseconds / duration.inMilliseconds).clamp(0, 1);
  }

  bool isStale(DateTime now) {
    if (isPlaying) return false;
    final updatedAt = positionUpdatedAt;
    return updatedAt == null || now.difference(updatedAt) > _pausedTimeout;
  }
}

NowPlaying? _parse(String entityId, HaEntity entity) {
  if (entity.state != 'playing' && entity.state != 'paused') return null;
  final attributes = entity.attributes;
  final title = attributes['media_title'];
  if (title is! String || title.isEmpty) return null;
  Duration? seconds(Object? value) =>
      value is num ? Duration(milliseconds: (value * 1000).round()) : null;
  final updatedAt = attributes['media_position_updated_at'];
  final artist = attributes['media_artist'];
  final picture = attributes['entity_picture'];
  return NowPlaying(
    entityId: entityId,
    title: title,
    artist: artist is String && artist.isNotEmpty ? artist : null,
    isPlaying: entity.state == 'playing',
    pictureUrl: picture is String && picture.isNotEmpty ? picture : null,
    duration: seconds(attributes['media_duration']),
    position: seconds(attributes['media_position']),
    positionUpdatedAt: updatedAt is String
        ? DateTime.tryParse(updatedAt)?.toLocal()
        : null,
  );
}

/// The chosen player that is playing - or, if none is, the one paused
/// most recently.
NowPlaying? parseNowPlaying(
  Map<String, HaEntity> entities,
  List<String> playerEntityIds,
) {
  final candidates = [
    for (final id in playerEntityIds)
      if (entities[id] case final entity?) ?_parse(id, entity),
  ];
  for (final player in candidates) {
    if (player.isPlaying) return player;
  }
  candidates.sort(
    (a, b) => (b.positionUpdatedAt ?? DateTime(0)).compareTo(
      a.positionUpdatedAt ?? DateTime(0),
    ),
  );
  return candidates.firstOrNull;
}

/// All `media_player.*` entities via HA's REST API - for the picker.
Future<List<HaMediaPlayer>> listMediaPlayers({
  required String baseUrl,
  required String token,
  Dio? dio,
}) async {
  final response = await (dio ?? Dio()).getUri<List<dynamic>>(
    Uri.parse(baseUrl.trim()).replace(path: '/api/states', query: ''),
    options: Options(headers: {'Authorization': 'Bearer $token'}),
  );
  final players = [
    for (final entry in response.data!.cast<Map<String, dynamic>>())
      if ('${entry['entity_id']}'.startsWith('media_player.'))
        HaMediaPlayer(
          entityId: entry['entity_id'] as String,
          name:
              '${(entry['attributes'] as Map<String, dynamic>?)?['friendly_name'] ?? entry['entity_id']}',
        ),
  ];
  players.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return players;
}
