import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import 'alert_settings_repository.dart';
import 'finder_monitoring_service.dart';
import 'finder_preferences_repository.dart';
import 'history_repository.dart';
import 'telemetry_service.dart';
import 'monitoring_settings_repository.dart';
import 'voice_settings_repository.dart';

/// User-facing reason when the alert sound could not play.
String soundUnavailableMessage(String? reason) => switch (reason) {
      'no_headphones' =>
        'Sound skipped: output is set to Headphones only and none are connected. Vibration and flashlight still work.',
      'custom_sound_missing' =>
        'Your custom sound is missing, so the default tone was used. Choose a sound again in Sound Library.',
      'audio_focus_denied' =>
        'Android did not allow the alert sound right now (for example during a call).',
      _ => 'The alert sound could not play on this phone.',
    };

/// Latest detection shown on the "Phone found" screen.
class DetectionInfo {
  const DetectionInfo({
    required this.eventType,
    required this.at,
    required this.alertPlayed,
    this.suppressedReason,
    this.historyId,
  });

  /// clap | whistle | voice
  final String eventType;
  final DateTime at;
  final bool alertPlayed;
  final String? suppressedReason;
  final String? historyId;

  String get label => switch (eventType) {
        'clap' => 'Clap detected',
        'whistle' => 'Whistle detected',
        _ => 'Voice command detected',
      };
}

/// Single app-wide view of the native monitoring service.
///
/// The native service is authoritative; this mirrors its status snapshot and
/// events so every tab shows the same state. Plain ChangeNotifier (Flutter SDK)
/// — no third-party state-management package.
class MonitoringController extends ChangeNotifier {
  MonitoringController(this._box, {FinderMonitoringService? service})
      : _service = service ?? FinderMonitoringService(),
        history = HistoryRepository(_box);

  static MonitoringController? _instance;

  /// App-wide instance, created once storage is open.
  static MonitoringController get instance {
    final i = _instance;
    if (i == null) {
      throw StateError('MonitoringController.init() was not called.');
    }
    return i;
  }

  static MonitoringController init(Box<dynamic> box) =>
      _instance ??= MonitoringController(box)..attach();

  @visibleForTesting
  static void resetForTest([MonitoringController? controller]) {
    _instance?.dispose();
    _instance = controller;
  }

  final Box<dynamic> _box;
  final FinderMonitoringService _service;
  final HistoryRepository history;
  TelemetryService get _t => TelemetryService.instance;
  StreamSubscription<FinderMonitoringEvent>? _sub;

  bool active = false;
  bool busy = false;
  DateTime? startedAt;
  bool clapActive = false;
  bool whistleActive = false;
  bool voiceActive = false;
  int clapPattern = 1;
  int clapProgress = 0;
  bool pocketCovered = false;
  bool alertActive = false;
  DateTime? snoozedUntil;
  DetectionInfo? lastDetection;

  /// One-off message for the UI (auto-stop reason, errors, warnings).
  String? notice;

  /// Normalised 0..1 microphone level while monitoring (updated ~10 Hz).
  final ValueNotifier<double> level = ValueNotifier(0);

  /// Fires once per new detection so the shell can open "Phone found".
  final StreamController<DetectionInfo> _detections =
      StreamController<DetectionInfo>.broadcast();
  Stream<DetectionInfo> get detections => _detections.stream;

  AlertSettingsRepository get alertSettings => AlertSettingsRepository(_box);
  VoiceSettingsRepository get voiceSettings => VoiceSettingsRepository(_box);
  MonitoringSettingsRepository get monitoringSettings =>
      MonitoringSettingsRepository(_box);
  FinderPreferencesRepository get finderPreferences =>
      FinderPreferencesRepository(_box);
  FinderMonitoringService get service => _service;
  Box<dynamic> get box => _box;

  Duration get elapsed =>
      startedAt == null ? Duration.zero : DateTime.now().difference(startedAt!);

  void attach() {
    _sub ??= _service.events.listen(
      handleEvent,
      onError: (Object error) {
        notice = error.toString();
        notifyListeners();
      },
    );
    unawaited(refresh());
  }

  /// Re-reads the native snapshot (app resume, process recreation).
  Future<void> refresh() async {
    try {
      applyStatus(await _service.status());
    } catch (error) {
      notice = error.toString();
      notifyListeners();
    }
  }

  @visibleForTesting
  void applyStatus(Map<String, dynamic> s) {
    active = s['active'] == true;
    final started = s['started_at_ms'];
    startedAt = active && started is num
        ? DateTime.fromMillisecondsSinceEpoch(started.toInt())
        : null;
    clapActive = s['clap_enabled'] == true;
    whistleActive = s['whistle_enabled'] == true;
    voiceActive = s['voice_enabled'] == true;
    final pattern = s['clap_pattern'];
    clapPattern = pattern is num ? pattern.toInt() : 1;
    pocketCovered = s['pocket_covered'] == true;
    alertActive = s['alert_active'] == true;
    final snooze = s['snoozed_until_ms'];
    snoozedUntil = snooze is num
        ? DateTime.fromMillisecondsSinceEpoch(snooze.toInt())
        : null;
    if (!active) {
      level.value = 0;
      clapProgress = 0;
    }
    notifyListeners();
  }

  @visibleForTesting
  Future<void> handleEvent(FinderMonitoringEvent e) async {
    switch (e.type) {
      case 'level':
        // RMS of 16-bit PCM; ~6000 is a loud room. Log-ish scale for display.
        final rms = (e.raw['rms'] as num?)?.toDouble() ?? 0;
        level.value = (rms / 6000).clamp(0.0, 1.0);
        return; // no rebuild of listeners for level ticks
      case 'service_started':
        busy = false;
        notice = null;
        await refresh();
        final prefs = finderPreferences.read();
        _t.log('monitoring_started', {
          'clap': clapActive,
          'whistle': whistleActive,
          'voice': voiceActive,
          'clap_pattern': clapPattern,
          'pocket_mode': prefs.pocketModeEnabled,
          'battery_auto_stop': prefs.batteryStopPercent > 0,
        });
        _t.setCrashKey('monitoring_active', true);
        return;
      case 'service_stopped':
      case 'service_auto_stopped':
        await _recordSession(e);
        _t.log('monitoring_stopped', {
          'reason': e.reason ?? 'unknown',
          'auto': e.type == 'service_auto_stopped',
          'duration': TelemetryService.durationBucket(
            Duration(
                milliseconds:
                    e.intField('duration_ms', elapsed.inMilliseconds)),
          ),
        });
        _t.setCrashKey('monitoring_active', false);
        if (e.type == 'service_auto_stopped') {
          notice = switch (e.reason) {
            'battery_low' =>
              'Monitoring stopped automatically: battery reached your auto-stop level.',
            'duration_limit' =>
              'Monitoring stopped automatically after the selected time limit.',
            _ => 'Monitoring stopped automatically.',
          };
        }
        _markStopped();
        return;
      case 'service_error':
        // Non-fatal report: app-generated message only, no user data.
        _t.recordError(
          StateError(e.message ?? 'service_error'),
          StackTrace.current,
          reason: 'monitoring_service_error',
        );
        _t.setCrashKey('monitoring_active', false);
        busy = false;
        active = false;
        startedAt = null;
        notice = e.message ?? 'Monitoring stopped unexpectedly.';
        level.value = 0;
        notifyListeners();
        return;
      case 'clap_progress':
        clapProgress = e.intField('count');
        notifyListeners();
        return;
      case 'detection':
        await _onDetection(e);
        return;
      case 'alert_stopped':
        alertActive = false;
        notifyListeners();
        return;
      case 'alert_snoozed':
        alertActive = false;
        final until = e.raw['snoozed_until_ms'];
        snoozedUntil = until is num
            ? DateTime.fromMillisecondsSinceEpoch(until.toInt())
            : null;
        notifyListeners();
        return;
      case 'pocket_state':
        pocketCovered = e.boolField('covered');
        notifyListeners();
        return;
      case 'pocket_mode_unavailable':
        notice =
            'Pocket mode is unavailable: this phone has no proximity sensor.';
        notifyListeners();
        return;
      case 'battery_low_warning':
        notice =
            'Battery is at ${e.intField('battery_percent')}%. Monitoring keeps running; charge soon or stop it to save power.';
        notifyListeners();
        return;
      case 'alert_sound_unavailable':
        notice = soundUnavailableMessage(e.reason);
        notifyListeners();
        return;
      case 'flashlight_unavailable':
        notice = e.message ??
            'The flashlight is unavailable. Sound and vibration alerts still work.';
        notifyListeners();
        return;
      case 'voice_command':
        if (e.command == 'lock_phone') {
          await history.record(eventType: HistoryRepository.voiceLockPhone);
        }
        return;
      case 'voice_command_ignored':
        notice = e.reason == 'device_admin_not_active'
            ? 'Activate the lock-only Device Admin permission before using “Lock my phone”.'
            : 'That voice action is disabled in Offline Voice Commands.';
        notifyListeners();
        return;
    }
  }

  Future<void> _onDetection(FinderMonitoringEvent e) async {
    final type = e.eventType ?? 'clap';
    final alertPlayed = e.raw['alert_played'] != false;
    final reason = e.raw['suppressed_reason'] as String?;
    final historyType = switch (type) {
      'clap' => HistoryRepository.clapDetected,
      'whistle' => HistoryRepository.whistleDetected,
      _ => HistoryRepository.voiceFindPhone,
    };
    // Metadata only: no audio, no transcript.
    final id = await history.record(
      eventType: historyType,
      metadata: {
        'detection_method': type,
        'alert_played': alertPlayed,
        if (reason != null && reason.isNotEmpty) 'suppressed_reason': reason,
        if (type == 'clap') 'clap_pattern': e.intField('clap_pattern', 1),
        if (type == 'whistle')
          'whistle_frequency_hz': e.intField('whistle_frequency_hz'),
      },
    );
    final info = DetectionInfo(
      eventType: type,
      at: e.timestamp == null
          ? DateTime.now()
          : DateTime.fromMillisecondsSinceEpoch(e.timestamp!),
      alertPlayed: alertPlayed,
      suppressedReason: (reason?.isEmpty ?? true) ? null : reason,
      historyId: id,
    );
    lastDetection = info;
    alertActive = alertPlayed;
    _t.log('phone_found', {
      'method': type,
      'alert_played': alertPlayed,
      'suppressed': (reason == null || reason.isEmpty) ? 'none' : reason,
    });
    clapProgress = 0;
    notifyListeners();
    _detections.add(info);
  }

  Future<void> _recordSession(FinderMonitoringEvent e) async {
    final durationMs = e.intField('duration_ms', -1) >= 0
        ? e.intField('duration_ms')
        : elapsed.inMilliseconds;
    if (durationMs <= 0) return;
    await history.record(
      eventType: HistoryRepository.monitoringSession,
      metadata: {
        'duration_ms': durationMs,
        'stop_reason': e.reason ?? 'unknown',
      },
    );
  }

  void _markStopped() {
    active = false;
    busy = false;
    startedAt = null;
    alertActive = false;
    clapProgress = 0;
    pocketCovered = false;
    level.value = 0;
    notifyListeners();
  }

  /// Starts monitoring with every saved setting. Permission prompts and the
  /// microphone disclosure are handled by the UI before calling this.
  Future<void> start() async {
    if (busy || active) return;
    busy = true;
    notice = null;
    notifyListeners();
    try {
      final voice = voiceSettings.read();
      final monitoring = monitoringSettings.read();
      if (!monitoring.clapEnabled &&
          !monitoring.whistleEnabled &&
          !voice.enabled) {
        throw const FinderMonitoringException(
          'Turn on clap, whistle or voice detection before starting.',
        );
      }
      await _service.start(
        alertSettings: alertSettings.read().toPlatformMap(),
        voiceEnabled: voice.enabled,
        voiceLockCommandEnabled: voice.lockCommandEnabled,
        monitoringSettings: monitoring,
        finderSettings: finderPreferences.read().toPlatformMap(),
      );
      // service_started arrives asynchronously; refresh as a fallback.
      await refresh();
    } catch (error) {
      notice = error.toString();
      _t.log('monitoring_start_failed', {
        'error': error is FinderMonitoringException ? 'rejected' : 'unexpected',
      });
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> stop() => _guard(_service.stop);

  /// Stop All — also used by the in-app emergency control.
  Future<void> emergencyStop() {
    _t.log('emergency_stop');
    return _guard(_service.emergencyStop);
  }

  Future<void> stopAlert() async {
    _t.log('alert_stopped');
    alertActive = false;
    notifyListeners();
    await _guard(_service.stopAlert, refreshAfter: false);
  }

  Future<void> snooze() async {
    _t.log('alert_snoozed');
    alertActive = false;
    notifyListeners();
    await _guard(_service.snoozeAlert, refreshAfter: false);
  }

  Future<void> _guard(Future<void> Function() action,
      {bool refreshAfter = true}) async {
    try {
      await action();
      if (refreshAfter) await refresh();
    } catch (error) {
      notice = error.toString();
      notifyListeners();
    }
  }

  void showNotice(String message) {
    notice = message;
    notifyListeners();
  }

  void clearNotice() {
    if (notice == null) return;
    notice = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _detections.close();
    level.dispose();
    super.dispose();
  }
}
