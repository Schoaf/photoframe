import 'package:flutter_test/flutter_test.dart';
import 'package:ha_display/services/ha_client.dart';
import 'package:ha_display/widgets/device_card.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  final now = DateTime(2026, 11, 22, 10);

  setUpAll(() => initializeDateFormatting('de'));

  String format(String value, [String? unit]) => formatPropertyValue(
    DeviceProperty(name: 'x', value: value, unit: unit),
    'de',
    now,
  );

  test('numbers get their unit and at most one decimal', () {
    expect(format('40', '°C'), '40 °C');
    expect(format('0.456', 'kWh'), '0,5 kWh');
    expect(format('Baumwolle'), 'Baumwolle');
  });

  test('times show the clock, with the date when not today', () {
    expect(
      format(DateTime(2026, 11, 22, 14, 30).toUtc().toIso8601String()),
      '14:30',
    );
    expect(
      format(DateTime(2026, 11, 23, 8, 5).toUtc().toIso8601String()),
      '23. Nov. 08:05',
    );
  });
}
