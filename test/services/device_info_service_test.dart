import 'package:flutter_test/flutter_test.dart';
import 'package:voicemate/services/device_info_service.dart';

void main() {
  test('parses a complete battery snapshot', () {
    final snapshot = BatterySnapshot.fromMap({
      'level_percent': 78,
      'status': 'charging',
      'plugged_source': 'usb',
      'health': 'good',
      'temperature_c': 31.5,
      'voltage_mv': 4210,
      'power_save_mode': false,
      'battery_optimization_ignored': true,
    });

    expect(snapshot.levelPercent, 78);
    expect(snapshot.status, 'charging');
    expect(snapshot.pluggedSource, 'usb');
    expect(snapshot.health, 'good');
    expect(snapshot.temperatureC, 31.5);
    expect(snapshot.voltageMv, 4210);
    expect(snapshot.powerSaveMode, isFalse);
    expect(snapshot.batteryOptimizationIgnored, isTrue);
  });

  test('uses safe unknown values for missing data', () {
    final snapshot = BatterySnapshot.fromMap({});
    expect(snapshot.levelPercent, -1);
    expect(snapshot.status, 'unknown');
    expect(snapshot.temperatureC, -1);
    expect(snapshot.voltageMv, -1);
    expect(snapshot.powerSaveMode, isFalse);
  });
}
