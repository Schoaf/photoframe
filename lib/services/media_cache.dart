import 'dart:async';
import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Photos and videos of the album, each downloaded once and then taken from
/// the tablet. Album pictures don't change - the key carries Synology's
/// cache key, so a changed picture gets a new entry. Entries not shown for
/// [_unusedFor] are deleted, which also clears what was removed on the NAS.
final mediaCache = CacheManager(
  Config(
    'photoframe_media',
    stalePeriod: _unusedFor,
    maxNrOfCacheObjects: 10000,
    fileService: _KeepForeverFileService(),
  ),
);

const _unusedFor = Duration(days: 30);

/// Never asks the NAS again for a file it already has.
class _KeepForeverFileService extends HttpFileService {
  @override
  Future<FileServiceResponse> get(
    String url, {
    Map<String, String>? headers,
  }) async => _KeptForever(await super.get(url, headers: headers));
}

class _KeptForever implements FileServiceResponse {
  _KeptForever(this._response);

  final FileServiceResponse _response;

  @override
  Stream<List<int>> get content => _response.content;

  @override
  int? get contentLength => _response.contentLength;

  @override
  int get statusCode => _response.statusCode;

  @override
  String? get eTag => _response.eTag;

  @override
  String get fileExtension => _response.fileExtension;

  @override
  DateTime get validTill => DateTime.now().add(const Duration(days: 3650));
}

/// Downloads videos completely before they are shown - streaming them
/// stalls on the tablets' Wi-Fi. One at a time, so the next video isn't
/// slowed down by the ones after it.
class VideoDownloads {
  VideoDownloads([CacheManager? cache]) : _cache = cache ?? mediaCache;

  final CacheManager _cache;
  final _queue = <String, List<String> Function()>{};
  bool _isRunning = false;

  /// The downloaded video, or null while it isn't there yet.
  Future<File?> file(String key) async =>
      (await _cache.getFileFromCache(key))?.file;

  /// Queues the video; [urls] are tried in order (built when the download
  /// starts, as they carry the current session).
  Future<void> request(String key, List<String> Function() urls) async {
    if (_queue.containsKey(key) || await file(key) != null) return;
    _queue[key] = urls;
    if (!_isRunning) unawaited(_run());
  }

  Future<void> _run() async {
    _isRunning = true;
    while (_queue.isNotEmpty) {
      final key = _queue.keys.first;
      for (final url in _queue[key]!()) {
        try {
          await _cache.downloadFile(url, key: key);
          break;
        } on Exception {
          // Not converted on the NAS (404) or Wi-Fi gone - try the next URL;
          // a failed video is queued again when it comes up next time.
        }
      }
      _queue.remove(key);
    }
    _isRunning = false;
  }
}
