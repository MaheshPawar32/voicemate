import 'dart:async';
import 'package:flutter/services.dart';

class FinderMonitoringEvent {
  const FinderMonitoringEvent({
    required this.type,
    this.eventType,
    this.message,
    this.clapCount = 0,
    this.whistleCount = 0,
    this.whistleFrequencyHz = 0,
    this.rms = 0,
    this.peak = 0,
    this.timestamp,
  });

  final String type;
  final String? eventType;
  final String? message;
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
        clapCount: (map['clap_count'] as num?)?.toInt() ?? 0,
        whistleCount: (map['whistle_count'] as num?)?.toInt() ?? 0,
        whistleFrequencyHz:
            (map['whistle_frequency_hz'] as num?)?.toInt() ?? 0,
        rms: (map['rms'] as num?)?.toDouble() ?? 0,
        peak: (map['peak'] as num?)?.toDouble() ?? 0,
        timestamp: (map['timestamp'] as num?)?.toInt(),
      );
}

/// Bridge to the explicit, notification-backed Android microphone service.
class FinderMonitoringService {
  static const MethodChannel _methods =
      MethodChannel('com.dev.voicemate/monitoring/methods');
  static const MethodChannel _permissionMethods =
      MethodChannel('com.dev.voicemate/audio_test/methods');
  static const EventChannel _events =
      EventChannel('com.dev.voicemate/monitoring/events');

  Stream<FinderMonitoringEvent> get events => _events
      .receiveBroadcastStream()
      .map((value) => FinderMonitoringEvent.fromMap(
          value as Map<dynamic, dynamic>));

  Future<bool> requestMicrophonePermission() async {
    try {
      return await _permissionMethods.invokeMethod<bool>(
            'requestMicrophonePermission') ??
          false;
    } on PlatformException catch (error) {
      throw FinderMonitoringException(
        error.message ?? 'Could not request microphone permission.');
    } on MissingPluginException {
      throw const FinderMonitoringException(
        'Android microphone integration is not available.');
    }
  }

  Future<bool> requestNotificationPermission() async {
    try {
      return await _methods.invokeMethod<bool>(
            'requestNotificationPermission') ??
          false;
    } on PlatformException catch (error) {
      throw FinderMonitoringException(
        error.message ?? 'Could not request notification permission.');
    } on MissingPluginException {
      throw const FinderMonitoringException(
        'Android notification permission integration is not available.');
    }
  }

  Future<void> start({Map<String, Object?> alertSettings = const {}}) async {
    try {
      await _methods.invokeMethod<void>('startMonitoring', alertSettings);
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

  Future<bool> isActive() async {
    try {
      return await _methods.invokeMethod<bool>('getMonitoringStatus') ?? false;
    } on PlatformException catch (error) {
      throw FinderMonitoringException(
        error.message ?? 'Could not read monitoring status.');
    } on MissingPluginException {
      throw const FinderMonitoringException(
        'Android monitoring service is not available.');
    }
  }
}

class FinderMonitoringException implements Exception {
  const FinderMonitoringException(this.message);
  final String message;
  @override
  String toString() => message;
}
