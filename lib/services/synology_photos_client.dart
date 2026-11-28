import 'dart:convert';

import 'package:dio/dio.dart';

import '../models/photo_item.dart';

/// Synology error codes that mean "the session is gone, log in again".
const _sessionErrorCodes = {106, 107, 119};

class SynologyException implements Exception {
  SynologyException(this.code);

  final int code;

  /// No such user or wrong password.
  bool get isWrongPassword => code == 400;

  /// The user may not use this login - e.g. no DSM permission on the
  /// general web API.
  bool get isPermissionDenied => code == 402;

  /// 2-factor sign-in required (403, 406) or failed (404).
  bool get isTwoFactorRequired => code == 403 || code == 404 || code == 406;

  /// Disabled account, blocked IP, expired password, ...
  bool get isLoginError => code >= 400 && code < 411;

  @override
  String toString() => 'Synology error $code';
}

/// Talks to Synology Photos (DSM 7) via its web API, the same one the
/// Photos web UI uses. Not officially documented, so all API names live in
/// this one file.
class SynologyPhotosClient {
  SynologyPhotosClient({
    required String baseUrl,
    required this.user,
    required this.password,
    this.passphrase = '',
    Dio? dio,
  }) : baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), ''),
       _dio = dio ?? Dio();

  /// e.g. `http://192.168.1.10:5000`
  final String baseUrl;
  final String user;
  final String password;

  /// Set for an album someone else shared with [user]: its items and
  /// thumbnails are only reachable with the album's passphrase.
  final String passphrase;
  final Dio _dio;
  String? _sid;

  String get _endpoint => '$baseUrl/webapi/entry.cgi';

  Future<void> login() async {
    final data = await _call({
      'api': 'SYNO.API.Auth',
      'version': '6',
      'method': 'login',
      'account': user,
      'passwd': password,
      // DSM checks the permission of the app the session is named after:
      // "webui" only needs the DSM permission, other names (e.g.
      // "SynologyPhotos") fail with 402 for users that aren't admins.
      'session': 'webui',
      'format': 'sid',
    }, isAuthenticated: false);
    _sid = data['sid'] as String;
  }

  /// The user's own albums and the ones shared with them.
  Future<List<PhotoAlbum>> listAlbums() async {
    final albums = <PhotoAlbum>[];
    await _paginate({
      'api': 'SYNO.Foto.Browse.Album',
      'version': '2',
      'method': 'list',
      // An own album may carry a passphrase too (shared by link), but
      // doesn't need it.
    }, (json) => albums.add(PhotoAlbum.fromJson({...json, 'passphrase': ''})));
    await _paginate({
      'api': 'SYNO.Foto.Sharing.Misc',
      'version': '1',
      'method': 'list_shared_with_me_album',
    }, (json) => albums.add(PhotoAlbum.fromJson(json)));
    return albums;
  }

  Future<List<PhotoItem>> listAlbumItems(int albumId) async {
    final items = <PhotoItem>[];
    await _paginate({
      'api': 'SYNO.Foto.Browse.Item',
      'version': '1',
      'method': 'list',
      // A shared album answers 609 to its id - only the passphrase works.
      if (passphrase.isEmpty) 'album_id': '$albumId',
      if (passphrase.isNotEmpty) 'passphrase': passphrase,
      'sort_by': 'takentime',
      'sort_direction': 'asc',
      'additional': jsonEncode([
        'thumbnail',
        'resolution',
        'address',
        'video_convert',
        'description',
      ]),
    }, (json) => items.add(PhotoItem.fromJson(json)));
    return items;
  }

  /// `sm` (~240 px) for the gallery, `xl` (~1280 px) for full screen -
  /// already rendered by the NAS, so the tablet never decodes originals.
  String thumbnailUrl(PhotoItem item, {required ThumbnailSize size}) => _url({
    'api': 'SYNO.Foto.Thumbnail',
    'version': '2',
    'method': 'get',
    'mode': 'download',
    'id': '${item.unitId}',
    'type': 'unit',
    'size': size.name,
    'cache_key': item.cacheKey,
  });

  /// Synology's H.264 transcode of the video - only in the quality it
  /// made (404 otherwise).
  String convertedVideoUrl(PhotoItem item) => _url({
    'api': 'SYNO.Foto.Streaming',
    'version': '1',
    'method': 'streaming',
    'id': '${item.id}',
    'quality': item.convertedQuality ?? 'medium',
  });

  String originalVideoUrl(PhotoItem item) => _url({
    'api': 'SYNO.Foto.Download',
    'version': '2',
    'method': 'download',
    'download_type': 'source',
    'unit_id': '[${item.id}]',
  });

  String _url(Map<String, String> params) => Uri.parse(_endpoint)
      .replace(
        queryParameters: {
          ...params,
          if (passphrase.isNotEmpty) 'passphrase': passphrase,
          '_sid': ?_sid,
        },
      )
      .toString();

  Future<void> _paginate(
    Map<String, String> params,
    void Function(Map<String, dynamic>) onEntry,
  ) async {
    const limit = 500;
    for (var offset = 0; ; offset += limit) {
      final data = await _call({
        ...params,
        'offset': '$offset',
        'limit': '$limit',
      });
      final list = (data['list'] as List).cast<Map<String, dynamic>>();
      list.forEach(onEntry);
      if (list.length < limit) return;
    }
  }

  Future<Map<String, dynamic>> _call(
    Map<String, String> params, {
    bool isAuthenticated = true,
  }) async {
    if (isAuthenticated && _sid == null) await login();
    try {
      return await _request(params, isAuthenticated: isAuthenticated);
    } on SynologyException catch (e) {
      if (!isAuthenticated || !_sessionErrorCodes.contains(e.code)) rethrow;
      await login();
      return _request(params, isAuthenticated: true);
    }
  }

  Future<Map<String, dynamic>> _request(
    Map<String, String> params, {
    required bool isAuthenticated,
  }) async {
    final response = await _dio.get<dynamic>(
      _endpoint,
      queryParameters: {...params, if (isAuthenticated) '_sid': _sid},
    );
    final body = response.data is String
        ? jsonDecode(response.data as String) as Map<String, dynamic>
        : response.data as Map<String, dynamic>;
    if (body['success'] != true) {
      final error = body['error'] as Map<String, dynamic>? ?? const {};
      throw SynologyException(error['code'] as int? ?? -1);
    }
    return body['data'] as Map<String, dynamic>? ?? const {};
  }
}

enum ThumbnailSize { sm, m, xl }
