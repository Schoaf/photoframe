import 'package:flutter_test/flutter_test.dart';
import 'package:ha_display/services/app_updater.dart';

void main() {
  Map<String, dynamic> release(String tag, {String asset = 'ha-display.apk'}) =>
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
}
