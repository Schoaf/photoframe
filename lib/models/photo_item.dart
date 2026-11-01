/// One photo or video of the Synology Photos album.
class PhotoItem {
  const PhotoItem({
    required this.id,
    required this.unitId,
    required this.cacheKey,
    required this.filename,
    required this.isVideo,
    this.takenAt,
    this.place,
    this.hasConvertedVideo = false,
  });

  /// Item id (download/streaming).
  final int id;

  /// Thumbnail unit id - differs from [id] for some items.
  final int unitId;
  final String cacheKey;
  final String filename;
  final bool isVideo;
  final DateTime? takenAt;

  /// "Wien, Österreich" from Synology's reverse geocoding, if any.
  final String? place;

  /// Synology transcoded the video into a smaller H.264 version, which the
  /// tablet decodes far better than e.g. 4K/HEVC originals.
  final bool hasConvertedVideo;

  /// Reads one entry of `SYNO.Foto.Browse.Item list`.
  factory PhotoItem.fromJson(Map<String, dynamic> json) {
    final additional = json['additional'] as Map<String, dynamic>? ?? const {};
    final thumbnail =
        additional['thumbnail'] as Map<String, dynamic>? ?? const {};
    final address = additional['address'] as Map<String, dynamic>? ?? const {};
    final converted = additional['video_convert'];
    final time = json['time'];
    final placeParts = [
      address['city'] ?? address['town'] ?? address['village'],
      address['country'],
    ].whereType<String>().where((part) => part.isNotEmpty);
    return PhotoItem(
      id: json['id'] as int,
      unitId: thumbnail['unit_id'] as int? ?? json['id'] as int,
      cacheKey: thumbnail['cache_key'] as String? ?? '',
      filename: json['filename'] as String? ?? '',
      isVideo: json['type'] == 'video',
      takenAt: time is int
          ? DateTime.fromMillisecondsSinceEpoch(time * 1000, isUtc: true)
          : null,
      place: placeParts.isEmpty ? null : placeParts.join(', '),
      hasConvertedVideo: converted is List && converted.isNotEmpty,
    );
  }
}

/// One album for the album picker.
class PhotoAlbum {
  const PhotoAlbum({
    required this.id,
    required this.name,
    required this.itemCount,
    this.passphrase = '',
  });

  final int id;
  final String name;
  final int itemCount;

  /// Set when someone else shared the album with the user.
  final String passphrase;

  factory PhotoAlbum.fromJson(Map<String, dynamic> json) => PhotoAlbum(
    id: json['id'] as int,
    name: json['name'] as String? ?? '',
    itemCount: json['item_count'] as int? ?? 0,
    passphrase: json['passphrase'] as String? ?? '',
  );
}
