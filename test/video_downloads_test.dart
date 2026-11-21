import 'package:file/memory.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ha_display/services/media_cache.dart';
import 'package:mocktail/mocktail.dart';

class _Cache extends Mock implements CacheManager {}

void main() {
  late _Cache cache;
  late List<String> downloaded;
  final fs = MemoryFileSystem();

  setUp(() {
    cache = _Cache();
    downloaded = [];
    when(() => cache.getFileFromCache(any())).thenAnswer((_) async => null);
    when(
      () => cache.getFileStream(
        any(),
        key: any(named: 'key'),
        withProgress: any(named: 'withProgress'),
      ),
    ).thenAnswer((invocation) {
      final url = invocation.positionalArguments.first as String;
      downloaded.add(url);
      if (url.contains('fail')) return Stream.error(Exception('404'));
      return Stream.fromIterable([
        DownloadProgress(url, 100, 50),
        FileInfo(fs.file(url), FileSource.Online, DateTime(2100), url),
      ]);
    });
  });

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('falls back to the next URL', () async {
    await VideoDownloads(cache).request('a', () => ['fail', 'original']);
    await settle();
    await settle();
    expect(downloaded, ['fail', 'original']);
  });

  test('reports the progress up to done', () async {
    final downloads = VideoDownloads(cache);
    final seen = <double?>[];
    downloads
        .progress('a')
        .addListener(() => seen.add(downloads.progress('a').value));
    await downloads.request('a', () => ['a1']);
    for (var i = 0; i < 5; i++) {
      await settle();
    }
    expect(seen, [0.5, 1]);
  });

  test('downloads one video after the other, each once', () async {
    final downloads = VideoDownloads(cache);
    await downloads.request('a', () => ['a1']);
    await downloads.request('a', () => ['a1']);
    await downloads.request('b', () => ['b1']);
    for (var i = 0; i < 5; i++) {
      await settle();
    }
    expect(downloaded, ['a1', 'b1']);
  });

  test('skips videos already on the tablet', () async {
    when(() => cache.getFileFromCache('a')).thenAnswer(
      (_) async =>
          FileInfo(fs.file('a'), FileSource.Cache, DateTime(2100), 'a'),
    );
    await VideoDownloads(cache).request('a', () => ['a1']);
    await settle();
    expect(downloaded, isEmpty);
  });
}
