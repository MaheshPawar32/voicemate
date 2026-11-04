import 'package:flutter/services.dart';

class BatterySnapshot {
  const BatterySnapshot({
    required this.levelPercent,
    required this.status,
    required this.pluggedSource,
    required this.health,
    required this.temperatureC,
    required this.voltageMv,
    required this.powerSaveMode,
    required this.batteryOptimizationIgnored,
  });

  final int levelPercent;
  final String status;
  final String pluggedSource;
  final String health;
  final double temperatureC;
  final int voltageMv;
  final bool powerSaveMode;
  final bool batteryOptimizationIgnored;

  factory BatterySnapshot.fromMap(Map<dynamic, dynamic> map) =>
      BatterySnapshot(
        levelPercent: (map['level_percent'] as num?)?.toInt() ?? -1,
        status: map['status'] as String? ?? 'unknown',
        pluggedSource: map['plugged_source'] as String? ?? 'none',
        health: map['health'] as String? ?? 'unknown',
        temperatureC: (map['temperature_c'] as num?)?.toDouble() ?? -1,
        voltageMv: (map['voltage_mv'] as num?)?.toInt() ?? -1,
        powerSaveMode: map['power_save_mode'] == true,
        batteryOptimizationIgnored:
            map['battery_optimization_ignored'] == true,
      );
}

class DeviceInfoService {
  static const MethodChannel _channel =
      MethodChannel('com.dev.voicemate/device/methods');

  Future<BatterySnapshot> getBatterySnapshot() async {
    try {
      final result =
          await _channel.invokeMapMethod<dynamic, dynamic>('getBatteryInfo');
      if (result == null) {
        throw const DeviceInfoException('Android returned no battery information.');
      }
      return BatterySnapshot.fromMap(result);
    } on PlatformException catch (error) {
      throw DeviceInfoException(
        error.message ?? 'Could not read battery information.');
    } on MissingPluginException {
      throw const DeviceInfoException(
        'Battery information is available only on Android.');
    }
  }
}

class DeviceInfoException implements Exception {
  const DeviceInfoException(this.message);
  final String message;
  @override
  String toString() => message;
}
