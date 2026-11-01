import 'dart:io';

import 'package:dio/dio.dart';

import 'kiosk.dart';

const _releaseAssetName = 'ha-display.apk';

/// The latest GitHub release: tag `v1.1.0+2` (pubspec version), asset
/// `ha-display.apk` - as tool/publish_release.sh creates it.
class ReleaseInfo {
  const ReleaseInfo({
    required this.versionName,
    required this.versionCode,
    required this.apkAssetUrl,
  });

  final String versionName;
  final int versionCode;

  /// API URL of the APK asset (works for private repos with a token).
  final String apkAssetUrl;

  /// null when the release has no version code in its tag or no APK.
  static ReleaseInfo? fromJson(Map<String, dynamic> json) {
    final tag = '${json['tag_name']}';
    final match = RegExp(r'^v?(.+)\+(\d+)$').firstMatch(tag);
    final asset = (json['assets'] as List? ?? const [])
        .cast<Map<String, dynamic>>()
        .where((asset) => asset['name'] == _releaseAssetName)
        .firstOrNull;
    if (match == null || asset == null) return null;
    return ReleaseInfo(
      versionName: match.group(1)!,
      versionCode: int.parse(match.group(2)!),
      apkAssetUrl: asset['url'] as String,
    );
  }
}

enum UpdateResult { upToDate, installing }

/// Checks the GitHub releases of [repo] and installs a newer APK.
class AppUpdater {
  AppUpdater({
    required this.repo,
    this.token = '',
    this.kiosk = const Kiosk(),
    Dio? dio,
  }) : _dio = dio ?? Dio();

  /// `owner/name`, e.g. `Schoaf/ha-display`.
  final String repo;

  /// Fine-grained token with read access to [repo] - only needed while the
  /// repo is private.
  final String token;
  final Kiosk kiosk;
  final Dio _dio;

  Map<String, String> get _headers => {
    'Accept': 'application/vnd.github+json',
    if (token.isNotEmpty) 'Authorization': 'Bearer $token',
  };

  Future<ReleaseInfo?> latestRelease() async {
    final response = await _dio.get<Map<String, dynamic>>(
      'https://api.github.com/repos/${repo.trim()}/releases/latest',
      options: Options(headers: _headers),
    );
    return ReleaseInfo.fromJson(response.data!);
  }

  Future<UpdateResult> checkAndInstall() async {
    final release = await latestRelease();
    if (release == null || release.versionCode <= await kiosk.versionCode()) {
      return UpdateResult.upToDate;
    }
    final apk = File('${Directory.systemTemp.path}/ha-display-update.apk');
    await _download(release.apkAssetUrl, apk.path);
    await kiosk.installUpdate(apk.path);
    return UpdateResult.installing;
  }

  /// GitHub answers with a redirect to a signed storage URL, which refuses
  /// requests that still carry the token - so follow it by hand.
  Future<void> _download(String assetUrl, String path) async {
    final response = await _dio.get<void>(
      assetUrl,
      options: Options(
        headers: {..._headers, 'Accept': 'application/octet-stream'},
        followRedirects: false,
        validateStatus: (status) => status != null && status < 400,
      ),
    );
    final location = response.headers.value('location');
    await _dio.download(location ?? assetUrl, path);
  }
}
