import 'dart:async';
import 'package:flutter/services.dart';
import 'monitoring_settings_repository.dart';

class FinderMonitoringEvent {
  const FinderMonitoringEvent({
    required this.type,
    this.eventType,
    this.message,
    this.command,
    this.reason,
    this.quietHours = false,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.clapCount = 0,
    this.whistleCount = 0,
    this.whistleFrequencyHz = 0,
    this.rms = 0,
    this.peak = 0,
    this.timestamp,
    this.raw = const {},
  });

  /// Complete metadata-only payload (schema documented in VoiceMonitoringService).
  final Map<String, dynamic> raw;

  int intField(String key, [int fallback = 0]) {
    final v = raw[key];
    return v is num ? v.toInt() : fallback;
  }

  bool boolField(String key) => raw[key] == true;

  final String type;
  final String? eventType;
  final String? message;
  final String? command;
  final String? reason;
  final bool quietHours;
  final int downloadedBytes;
  final int totalBytes;
  final int clapCount;
  final int whistleCount;
  final int whistleFrequencyHz;
  final double rms;
  final double peak;
  final int? timestamp;

  factory FinderMonitoringEvent.fromMap(Map<dynamic, dynamic> map) =>
      FinderMonitoringEvent(
        type: map['type'] as String? ?? 'unknown',
        eventType: map['event_type'] as String?,
        message: map['message'] as String?,
        command: map['command'] as String?,
        reason: map['reason'] as String?,
        quietHours: map['quiet_hours'] == true,
        downloadedBytes: (map['downloaded_bytes'] as num?)?.toInt() ?? 0,
        totalBytes: (map['total_bytes'] as num?)?.toInt() ?? 0,
        clapCount: (map['clap_count'] as num?)?.toInt() ?? 0,
        whistleCount: (map['whistle_count'] as num?)?.toInt() ?? 0,
        whistleFrequencyHz: (map['whistle_frequency_hz'] as num?)?.toInt() ?? 0,
        rms: (map['rms'] as num?)?.toDouble() ?? 0,
        peak: (map['peak'] as num?)?.toDouble() ?? 0,
        timestamp: (map['timestamp'] as num?)?.toInt(),
        raw: Map<String, dynamic>.from(map),
      );
}

class FinderMonitoringService {
  static const MethodChannel _methods =
      MethodChannel('com.dev.vokey/monitoring/methods');
  static const MethodChannel _permissionMethods =
      MethodChannel('com.dev.vokey/audio_test/methods');
  static const EventChannel _events =
      EventChannel('com.dev.vokey/monitoring/events');

  static final Stream<FinderMonitoringEvent> _sharedEvents = _events
      .receiveBroadcastStream()
      .map((value) =>
          FinderMonitoringEvent.fromMap(value as Map<dynamic, dynamic>))
      .asBroadcastStream();

  Stream<FinderMonitoringEvent> get events => _sharedEvents;

  Future<bool> requestMicrophonePermission() async {
    try {
      return await _permissionMethods
              .invokeMethod<bool>('requestMicrophonePermission') ??
          false;
    } on PlatformException catch (error) {
      throw FinderMonitoringException(
          error.message ?? 'Could not request microphone permission.');
    } on MissingPluginException {
      throw const FinderMonitoringException(
          'Android microphone integration is not available.');
    }
  }

  Future<bool> requestCameraPermission() async {
    try {
      return await _methods.invokeMethod<bool>('requestCameraPermission') ??
          false;
    } on PlatformException catch (error) {
      throw FinderMonitoringException(
          error.message ?? 'Could not request camera permission.');
    } on MissingPluginException {
      throw const FinderMonitoringException(
          'Android flashlight permission integration is not available.');
    }
  }

  Future<bool> requestNotificationPermission() async {
    try {
      return await _methods
              .invokeMethod<bool>('requestNotificationPermission') ??
          false;
    } on PlatformException catch (error) {
      throw FinderMonitoringException(
          error.message ?? 'Could not request notification permission.');
    } on MissingPluginException {
      throw const FinderMonitoringException(
          'Android notification permission integration is not available.');
    }
  }

  Future<bool> isVoiceModelInstalled() async {
    try {
      return await _methods.invokeMethod<bool>('isVoiceModelInstalled') ??
          false;
    } on PlatformException catch (error) {
      throw FinderMonitoringException(
          error.message ?? 'Could not check the offline voice model.');
    } on MissingPluginException {
      throw const FinderMonitoringException(
          'Android voice model integration is not available.');
    }
  }

  Future<void> installVoiceModel() async {
    try {
      await _methods.invokeMethod<String>('installVoiceModel');
    } on PlatformException catch (error) {
      throw FinderMonitoringException(
          error.message ?? 'Could not install the offline voice model.');
    } on MissingPluginException {
      throw const FinderMonitoringException(
          'Android voice model integration is not available.');
    }
  }

  Future<void> start({
    Map<String, Object?> alertSettings = const {},
    bool voiceEnabled = false,
    bool voiceLockCommandEnabled = false,
    MonitoringPreferences monitoringSettings = const MonitoringPreferences(),
    Map<String, Object?> finderSettings = const {},
  }) async {
    try {
      await _methods.invokeMethod<void>('startMonitoring', {
        'schema_version': 1,
        ...alertSettings,
        'voice_enabled': voiceEnabled,
        'voice_lock_command_enabled': voiceLockCommandEnabled,
        ...monitoringSettings.toPlatformMap(),
        ...finderSettings,
      });
    } on PlatformException catch (error) {
      throw FinderMonitoringException(
          error.message ?? 'Could not start phone finder monitoring.');
    } on MissingPluginException {
      throw const FinderMonitoringException(
          'Android monitoring service is not available.');
    }
  }

  Future<void> stop() async {
    try {
      await _methods.invokeMethod<void>('stopMonitoring');
    } on PlatformException catch (error) {
      throw FinderMonitoringException(
          error.message ?? 'Could not stop phone finder monitoring.');
    } on MissingPluginException {
      throw const FinderMonitoringException(
          'Android monitoring service is not available.');
    }
  }

  Future<void> _invoke(String method, String failure) async {
    try {
      await _methods.invokeMethod<void>(method);
    } on PlatformException catch (error) {
      throw FinderMonitoringException(error.message ?? failure);
    } on MissingPluginException {
      throw const FinderMonitoringException(
          'Android monitoring service is not available.');
    }
  }

  /// Stops the ringing alert but keeps listening.
  Future<void> stopAlert() => _invoke('stopAlert', 'Could not stop the alert.');

  /// Stops the alert and ignores detections for 30 seconds.
  Future<void> snoozeAlert() =>
      _invoke('snoozeAlert', 'Could not snooze the alert.');

  /// Stop All: microphone, monitoring, alert, flashlight, vibration, tests.
  Future<void> emergencyStop() =>
      _invoke('emergencyStop', 'Could not stop Vokey.');

  Future<Map<String, dynamic>> capabilities() async {
    try {
      final raw = await _methods.invokeMethod<Object?>('getCapabilities');
      return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    } on PlatformException {
      return <String, dynamic>{};
    } on MissingPluginException {
      return <String, dynamic>{};
    }
  }

  /// Full native status snapshot (schema_version 1). Older builds returned a
  /// bare bool, which is still accepted.
  Future<Map<String, dynamic>> status() async {
    try {
      final raw = await _methods.invokeMethod<Object?>('getMonitoringStatus');
      if (raw is Map) return Map<String, dynamic>.from(raw);
      return {'active': raw == true};
    } on PlatformException catch (error) {
      throw FinderMonitoringException(
          error.message ?? 'Could not read monitoring status.');
    } on MissingPluginException {
      throw const FinderMonitoringException(
          'Android monitoring service is not available.');
    }
  }

  Future<bool> isActive() async => (await status())['active'] == true;
}

class FinderMonitoringException implements Exception {
  const FinderMonitoringException(this.message);
  final String message;
  @override
  String toString() => message;
}
