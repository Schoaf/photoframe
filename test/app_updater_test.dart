import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ha_display/services/app_updater.dart';

void main() {
  Map<String, dynamic> release(String tag, {String asset = 'PhotoFrame.apk'}) =>
      {
        'tag_name': tag,
        'assets': [
          {
            'name': asset,
            'url': 'https://api.github.com/repos/o/r/releases/assets/1',
          },
        ],
      };

  test('reads version and APK from the release', () {
    final info = ReleaseInfo.fromJson(release('v1.1.0+2'))!;
    expect(info.versionName, '1.1.0');
    expect(info.versionCode, 2);
    expect(
      info.apkAssetUrl,
      'https://api.github.com/repos/o/r/releases/assets/1',
    );
  });

  test('ignores releases without version code or APK', () {
    expect(ReleaseInfo.fromJson(release('v1.1.0')), isNull);
    expect(
      ReleaseInfo.fromJson(release('v1.1.0+2', asset: 'notes.txt')),
      isNull,
    );
  });

  group('latestRelease', () {
    Future<UpdateProblem?> problemFor(
      Map<String, (int, Object?)> routes,
    ) async {
      final dio = Dio()..httpClientAdapter = _FakeAdapter(routes);
      try {
        await AppUpdater(repo: 'o/r', dio: dio).latestRelease();
        return null;
      } on UpdateException catch (e) {
        return e.problem;
      }
    }

    const latest = 'https://api.github.com/repos/o/r/releases/latest';
    const repo = 'https://api.github.com/repos/o/r';

    test('repo without release', () async {
      expect(
        await problemFor({latest: (404, null), repo: (200, {})}),
        UpdateProblem.noRelease,
      );
    });

    test('missing repo', () async {
      expect(
        await problemFor({latest: (404, null), repo: (404, null)}),
        UpdateProblem.repoNotFound,
      );
    });

    test('release without APK', () async {
      expect(
        await problemFor({latest: (200, release('v1.0.0+1', asset: 'x'))}),
        UpdateProblem.invalidRelease,
      );
    });

    test('bad token', () async {
      expect(
        await problemFor({latest: (401, null)}),
        UpdateProblem.tokenInvalid,
      );
    });

    test('valid release', () async {
      expect(await problemFor({latest: (200, release('v1.0.0+1'))}), isNull);
    });
  });
}

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.routes);

  final Map<String, (int, Object?)> routes;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final (status, body) = routes['${options.uri}'] ?? (500, null);
    return ResponseBody.fromString(
      jsonEncode(body ?? {}),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
