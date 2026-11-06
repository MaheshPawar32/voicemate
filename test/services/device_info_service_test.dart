import 'package:flutter_test/flutter_test.dart';
import 'package:vokey/services/device_info_service.dart';

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
      'total_ram_mb': 8192,
      'available_ram_mb': 2730,
      'app_memory_pss_mb': 120,
      'low_memory': false,
    });

    expect(snapshot.levelPercent, 78);
    expect(snapshot.status, 'charging');
    expect(snapshot.pluggedSource, 'usb');
    expect(snapshot.health, 'good');
    expect(snapshot.temperatureC, 31.5);
    expect(snapshot.voltageMv, 4210);
    expect(snapshot.powerSaveMode, isFalse);
    expect(snapshot.batteryOptimizationIgnored, isTrue);
    expect(snapshot.totalRamMb, 8192);
    expect(snapshot.availableRamMb, 2730);
    expect(snapshot.appMemoryPssMb, 120);
    expect(snapshot.lowMemory, isFalse);
  });

  test('uses safe unknown values for missing data', () {
    final snapshot = BatterySnapshot.fromMap({});
    expect(snapshot.levelPercent, -1);
    expect(snapshot.status, 'unknown');
    expect(snapshot.temperatureC, -1);
    expect(snapshot.voltageMv, -1);
    expect(snapshot.powerSaveMode, isFalse);
    expect(snapshot.totalRamMb, -1);
    expect(snapshot.availableRamMb, -1);
    expect(snapshot.appMemoryPssMb, -1);
    expect(snapshot.lowMemory, isFalse);
  });
}
