import 'package:flutter_test/flutter_test.dart';
import 'package:ha_display/services/ha_client.dart';
import 'package:ha_display/services/ha_media.dart';

void main() {
  final updatedAt = DateTime.utc(2026, 11, 1, 12);

  HaEntity player(String state, {String title = 'Song', DateTime? at}) =>
      HaEntity(state, {
        'media_title': title,
        'media_artist': 'Band',
        'media_duration': 200,
        'media_position': 50.5,
        'media_position_updated_at': (at ?? updatedAt).toIso8601String(),
        'entity_picture': '/api/media_player_proxy/media_player.kitchen',
      });

  test('moves the position on while playing', () {
    final music = parseNowPlaying(
      {'media_player.kitchen': player('playing')},
      ['media_player.kitchen'],
    )!;
    final now = updatedAt.add(const Duration(seconds: 10));
    expect(music.title, 'Song');
    expect(music.artist, 'Band');
    expect(music.positionAt(now), const Duration(milliseconds: 60500));
    expect(music.remaining(now), const Duration(milliseconds: 139500));
    expect(music.fraction(now), closeTo(0.3025, 0.0001));
    expect(
      music.positionAt(updatedAt.add(const Duration(hours: 1))),
      const Duration(seconds: 200),
    );
  });

  test('keeps the position while paused, and drops it after a while', () {
    final music = parseNowPlaying(
      {'media_player.kitchen': player('paused')},
      ['media_player.kitchen'],
    )!;
    final later = updatedAt.add(const Duration(minutes: 5));
    expect(music.positionAt(later), const Duration(milliseconds: 50500));
    expect(music.isStale(later), isFalse);
    expect(music.isStale(updatedAt.add(const Duration(hours: 1))), isTrue);
  });

  test('prefers a playing player, then the latest paused one', () {
    final entities = {
      'media_player.a': player('paused', title: 'A'),
      'media_player.b': player(
        'paused',
        title: 'B',
        at: updatedAt.add(const Duration(minutes: 1)),
      ),
      'media_player.c': player('playing', title: 'C'),
      'media_player.d': const HaEntity('idle', {}),
      'media_player.other': player('playing', title: 'Not chosen'),
    };
    expect(
      parseNowPlaying(entities, ['media_player.a', 'media_player.c'])!.title,
      'C',
    );
    expect(
      parseNowPlaying(entities, ['media_player.a', 'media_player.b'])!.title,
      'B',
    );
    expect(parseNowPlaying(entities, ['media_player.d']), isNull);
    expect(parseNowPlaying(entities, const []), isNull);
  });
}
