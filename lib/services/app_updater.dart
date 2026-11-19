import 'dart:io';

import 'package:dio/dio.dart';

import 'kiosk.dart';

const _releaseAssetName = 'PhotoFrame.apk';

/// The latest GitHub release: tag `v1.1.0+2` (pubspec version), asset
/// `PhotoFrame.apk` - as tool/publish_release.sh creates it.
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

enum UpdateProblem {
  repoNotFound,
  noRelease,
  invalidRelease,
  tokenInvalid,
  noAccess,
  rateLimited,
  offline,
  unknown,
}

/// A failed update check, with a reason the menu can show in words.
class UpdateException implements Exception {
  const UpdateException(this.problem, [this.detail = '']);

  final UpdateProblem problem;
  final String detail;

  @override
  String toString() =>
      'UpdateException($problem${detail.isEmpty ? '' : ': $detail'})';
}

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

  String get _repoUrl => 'https://api.github.com/repos/${repo.trim()}';

  Future<ReleaseInfo> latestRelease() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_repoUrl/releases/latest',
        options: Options(headers: _headers),
      );
      final release = ReleaseInfo.fromJson(response.data!);
      if (release == null) {
        throw UpdateException(
          UpdateProblem.invalidRelease,
          '${response.data!['tag_name']}',
        );
      }
      return release;
    } on DioException catch (e) {
      // GitHub answers 404 both for a missing repo and for one without
      // releases - ask for the repo to tell them apart.
      if (e.response?.statusCode == 404) {
        throw UpdateException(
          await _repoExists()
              ? UpdateProblem.noRelease
              : UpdateProblem.repoNotFound,
        );
      }
      throw _problemOf(e);
    }
  }

  Future<bool> _repoExists() async {
    try {
      await _dio.get<void>(_repoUrl, options: Options(headers: _headers));
      return true;
    } on DioException {
      return false;
    }
  }

  static UpdateException _problemOf(DioException e) {
    final response = e.response;
    if (response == null) {
      return UpdateException(UpdateProblem.offline, '${e.message ?? e.type}');
    }
    final status = response.statusCode;
    if (status == 401) return const UpdateException(UpdateProblem.tokenInvalid);
    if (status == 403 || status == 429) {
      return response.headers.value('x-ratelimit-remaining') == '0'
          ? const UpdateException(UpdateProblem.rateLimited)
          : const UpdateException(UpdateProblem.noAccess);
    }
    return UpdateException(UpdateProblem.unknown, 'HTTP $status');
  }

  Future<UpdateResult> checkAndInstall() async {
    final release = await latestRelease();
    if (release.versionCode <= await kiosk.versionCode()) {
      return UpdateResult.upToDate;
    }
    final apk = File('${Directory.systemTemp.path}/PhotoFrame-update.apk');
    try {
      await _download(release.apkAssetUrl, apk.path);
    } on DioException catch (e) {
      throw _problemOf(e);
    }
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
