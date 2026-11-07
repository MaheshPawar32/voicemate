import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../firebase_options.dart';

/// Firebase Analytics + Crashlytics behind one safe, privacy-limited API.
///
/// Rules (see docs/PRIVACY_AND_PLAY_COMPLIANCE.md):
/// - Never send audio, recordings, transcripts, sound names, file names or
///   any free text the user typed. Only the allow-listed events below with
///   small enum/number parameters.
/// - Every call is a no-op until Firebase is ready, and never throws: a
///   telemetry failure must not affect the finder (or app startup).
/// - Users can turn analytics and crash reports off in Settings.
class TelemetryService {
  TelemetryService._();
  static final TelemetryService instance = TelemetryService._();

  static const analyticsKey = 'telemetry_analytics_enabled';
  static const crashReportsKey = 'telemetry_crash_reports_enabled';

  bool _ready = false;
  Box<dynamic>? _box;
  FirebaseAnalytics? _analytics;

  bool get isReady => _ready;

  bool get analyticsEnabled =>
      _box?.get(analyticsKey, defaultValue: true) != false;
  bool get crashReportsEnabled =>
      _box?.get(crashReportsKey, defaultValue: true) != false;

  /// Called from the protected startup path. Swallows every failure.
  Future<void> initialize(Box<dynamic> box) async {
    _box = box;
    if (_ready) return;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        ).timeout(const Duration(seconds: 8));
      }
      _analytics = FirebaseAnalytics.instance;
      _ready = true;
      await _applyCollectionSettings();
    } catch (error) {
      _ready = false;
      debugPrint('Vokey telemetry disabled: ${error.runtimeType}');
    }
  }

  Future<void> _applyCollectionSettings() async {
    if (!_ready) return;
    try {
      await _analytics?.setAnalyticsCollectionEnabled(analyticsEnabled);
      // Debug/profile builds never upload crashes.
      await FirebaseCrashlytics.instance
          .setCrashlyticsCollectionEnabled(kReleaseMode && crashReportsEnabled);
    } catch (_) {}
  }

  Future<void> setAnalyticsEnabled(bool value) async {
    await _box?.put(analyticsKey, value);
    await _applyCollectionSettings();
  }

  Future<void> setCrashReportsEnabled(bool value) async {
    await _box?.put(crashReportsKey, value);
    await _applyCollectionSettings();
  }

  // --- Crash reporting ----------------------------------------------------

  void recordFlutterError(FlutterErrorDetails details) {
    if (!_ready || !crashReportsEnabled) return;
    try {
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    } catch (_) {}
  }

  void recordError(Object error, StackTrace? stack,
      {bool fatal = false, String? reason}) {
    if (!_ready || !crashReportsEnabled) return;
    try {
      unawaited(FirebaseCrashlytics.instance
          .recordError(error, stack, fatal: fatal, reason: reason));
    } catch (_) {}
  }

  /// Context attached to later crash reports (state only, no user data).
  void setCrashKey(String key, Object value) {
    if (!_ready) return;
    try {
      unawaited(FirebaseCrashlytics.instance.setCustomKey(key, value));
    } catch (_) {}
  }

  // --- Analytics ----------------------------------------------------------

  /// Event names that may be sent. Anything else is dropped.
  static const allowedEvents = <String>{
    'onboarding_completed',
    'onboarding_skipped',
    'permission_setup_completed',
    'monitoring_started',
    'monitoring_start_failed',
    'monitoring_stopped',
    'phone_found',
    'alert_stopped',
    'alert_snoozed',
    'false_alarm_reported',
    'finder_test_started',
    'alert_previewed',
    'custom_sound_imported',
    'custom_sound_import_failed',
    'detection_settings_saved',
    'emergency_stop',
  };

  static const _maxStringParam = 40;

  /// Keeps only bool/int/double and short enum-like strings.
  @visibleForTesting
  static Map<String, Object> sanitize(Map<String, Object?> params) {
    final out = <String, Object>{};
    params.forEach((key, value) {
      if (!RegExp(r'^[a-z][a-z0-9_]{0,39}$').hasMatch(key)) return;
      switch (value) {
        case final bool b:
          out[key] = b ? 1 : 0; // Analytics has no bool type
        case final int i:
          out[key] = i;
        case final double d:
          out[key] = d;
        case final String s
            when s.length <= _maxStringParam &&
                RegExp(r'^[a-z0-9_.-]*$').hasMatch(s):
          out[key] = s;
        default:
          break; // free text or unsupported type: dropped
      }
    });
    return out;
  }

  void log(String name, [Map<String, Object?> params = const {}]) {
    if (!allowedEvents.contains(name)) {
      assert(false, 'Telemetry event "$name" is not allow-listed');
      return;
    }
    if (!_ready || !analyticsEnabled) return;
    try {
      unawaited(_analytics!.logEvent(name: name, parameters: sanitize(params)));
    } catch (_) {}
  }

  void screen(String name) {
    if (!_ready || !analyticsEnabled) return;
    try {
      unawaited(_analytics!.logScreenView(screenName: name));
    } catch (_) {}
  }

  /// Coarse duration buckets — never exact timings.
  static String durationBucket(Duration d) {
    final m = d.inMinutes;
    if (m < 1) return 'lt_1m';
    if (m < 10) return '1_10m';
    if (m < 30) return '10_30m';
    if (m < 60) return '30_60m';
    if (m < 180) return '1_3h';
    return 'gt_3h';
  }
}
