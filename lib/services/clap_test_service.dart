import 'dart:async';
import 'package:flutter/services.dart';

class ClapTestException implements Exception {
  const ClapTestException(this.message);
  final String message;
  @override
  String toString() => message;
}

class ClapTestEvent {
  const ClapTestEvent({
    required this.rms,
    required this.peak,
    required this.noiseFloor,
    required this.clapCount,
    required this.isClap,
    this.isWhistle = false,
    this.whistleCount = 0,
    this.whistleFrequencyHz = 0,
    this.error,
    this.stopped = false,
  });
  final double rms;
  final double peak;
  final double noiseFloor;
  final int clapCount;
  final bool isClap;
  final bool isWhistle;
  final int whistleCount;
  final int whistleFrequencyHz;
  final String? error;
  final bool stopped;

  factory ClapTestEvent.fromMap(Map<dynamic, dynamic> map) {
    final type = map['type'] as String? ?? 'metrics';
    return ClapTestEvent(
      rms: (map['rms'] as num?)?.toDouble() ?? 0,
      peak: (map['peak'] as num?)?.toDouble() ?? 0,
      noiseFloor: (map['noise_floor'] as num?)?.toDouble() ?? 0,
      clapCount: (map['clap_count'] as num?)?.toInt() ?? 0,
      isClap: map['is_clap'] == true || type == 'clap',
      isWhistle: map['is_whistle'] == true,
      whistleCount: (map['whistle_count'] as num?)?.toInt() ?? 0,
      whistleFrequencyHz: (map['whistle_frequency_hz'] as num?)?.toInt() ?? 0,
      error: type == 'error' ? map['message'] as String? : null,
      stopped: type == 'stopped',
    );
  }
}

class ClapTestService {
  static const MethodChannel _methods =
      MethodChannel('com.dev.vokey/audio_test/methods');
  static const EventChannel _events =
      EventChannel('com.dev.vokey/audio_test/events');

  Stream<ClapTestEvent> get events => _events
      .receiveBroadcastStream()
      .map((event) => ClapTestEvent.fromMap(event as Map<dynamic, dynamic>));

  Future<bool> requestMicrophonePermission() async {
    try {
      return await _methods.invokeMethod<bool>('requestMicrophonePermission') ??
          false;
    } on PlatformException catch (error) {
      throw ClapTestException(
          error.message ?? 'Could not request microphone permission.');
    } on MissingPluginException {
      throw const ClapTestException(
          'Android native audio is not connected yet. Generate the Android platform folder first.');
    }
  }

  /// [settings] are the saved finder preferences (sensitivity, whistle band
  /// and duration) so the test matches background monitoring.
  Future<void> start({Map<String, Object> settings = const {}}) async {
    try {
      await _methods.invokeMethod<void>('startClapTest', settings);
    } on PlatformException catch (error) {
      throw ClapTestException(
          error.message ?? 'Could not start the clap test.');
    } on MissingPluginException {
      throw const ClapTestException(
          'Android native audio is not connected yet. Generate the Android platform folder first.');
    }
  }

  Future<void> stop() async {
    try {
      await _methods.invokeMethod<void>('stopClapTest');
    } on PlatformException {
      // The native Activity may already have been destroyed.
    } on MissingPluginException {
      // The Android platform folder has not been generated yet.
    }
  }
}
