import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ha_display/state/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('round-trips settings, secrets in secure storage', () async {
    const settings = Settings(
      synologyUrl: 'http://nas:5000',
      synologyUser: 'frame',
      synologyPassword: 'pw',
      albumId: 4,
      albumName: 'FotoFrame',
      mqttHost: 'ha.local',
      mqttPassword: 'mq',
      slideSeconds: 30,
      isShuffled: false,
      startMode: DisplayMode.dashboard,
      dashboardUrl: 'http://ha:8123/lovelace/0',
      pin: '1234',
      languageCode: 'en',
    );

    await saveSettings(settings);
    final prefs = await SharedPreferences.getInstance();
    final loaded = await loadSettings();

    expect(prefs.getKeys().any((key) => key.contains('password')), isFalse);
    expect(prefs.getKeys().contains('pin'), isFalse);
    expect(loaded.synologyPassword, 'pw');
    expect(loaded.mqttPassword, 'mq');
    expect(loaded.pin, '1234');
    expect(loaded.albumId, 4);
    expect(loaded.slideSeconds, 30);
    expect(loaded.isShuffled, isFalse);
    expect(loaded.startMode, DisplayMode.dashboard);
    expect(loaded.languageCode, 'en');
    expect(loaded.isConfigured, isTrue);
  });

  test('needs a PIN and something to show before it is configured', () {
    expect(const Settings(dashboardUrl: 'http://ha').isConfigured, isFalse);
    expect(const Settings(pin: '1234').isConfigured, isFalse);
    expect(
      const Settings(dashboardUrl: 'http://ha', pin: '1234').isConfigured,
      isTrue,
    );
  });
}
