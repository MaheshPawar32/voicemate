import 'package:hive/hive.dart';

import '../core/storage/safe_read.dart';

/// Persists event metadata only; never accepts or stores microphone audio or
/// voice transcripts.
class HistoryRepository {
  HistoryRepository(this._box);

  static const storageKey = 'history_events';
  static const retentionKey = 'history_retention_days';
  static const maxEvents = 500;

  /// 0 = keep until the event cap is reached.
  static const retentionOptions = <int, String>{
    7: '7 days',
    30: '30 days',
    90: '90 days',
    0: 'Keep (last $maxEvents)',
  };

  /// Event types written by the app.
  static const clapDetected = 'clap_monitor_detected';
  static const whistleDetected = 'whistle_monitor_detected';
  static const voiceFindPhone = 'voice_find_phone';
  static const voiceLockPhone = 'voice_lock_phone';
  static const monitoringSession = 'monitoring_session';
  static const clapTest = 'clap_test_detected';
  static const whistleTest = 'whistle_test_detected';

  static const detectionTypes = {clapDetected, whistleDetected, voiceFindPhone};

  /// user_feedback values.
  static const feedbackFalseAlarm = 'false_alarm';
  static const feedbackFound = 'found';

  final Box<dynamic> _box;

  int get retentionDays => readInt(_box.get(retentionKey), 30);

  Future<void> setRetentionDays(int days) async {
    await _box.put(
        retentionKey, retentionOptions.containsKey(days) ? days : 30);
    await _save(_load());
  }

  List<Map<String, dynamic>> _load() {
    final raw = _box.get(storageKey, defaultValue: <dynamic>[]);
    if (raw is! List) return <Map<String, dynamic>>[];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .where((e) => e['event_type'] is String && e['timestamp'] is int)
        .toList();
  }

  Future<void> _save(List<Map<String, dynamic>> events, {DateTime? now}) {
    final days = retentionDays;
    if (days > 0) {
      final cutoff = (now ?? DateTime.now())
          .subtract(Duration(days: days))
          .millisecondsSinceEpoch;
      events.removeWhere((e) => (e['timestamp'] as int) < cutoff);
    }
    if (events.length > maxEvents) {
      events.removeRange(0, events.length - maxEvents);
    }
    return _box.put(storageKey, events);
  }

  /// Returns the new event id.
  Future<String> record({
    required String eventType,
    Map<String, Object?> metadata = const {},
    DateTime? at,
  }) async {
    final events = _load();
    final now = at ?? DateTime.now();
    final id = '${now.microsecondsSinceEpoch}_${events.length}';
    events.add({
      'id': id,
      'event_type': eventType,
      'timestamp': now.millisecondsSinceEpoch,
      'metadata': Map<String, Object?>.from(metadata),
    });
    events.sort(
        (a, b) => (a['timestamp'] as int).compareTo(b['timestamp'] as int));
    await _save(events);
    return id;
  }

  /// Marks a detection as a real find or a false alarm.
  Future<void> setFeedback(String id, String feedback) async {
    final events = _load();
    for (final e in events) {
      if (e['id'] == id) {
        final meta = e['metadata'] is Map
            ? Map<String, dynamic>.from(e['metadata'] as Map)
            : <String, dynamic>{};
        meta['user_feedback'] = feedback;
        e['metadata'] = meta;
      }
    }
    await _save(events);
  }

  /// Newest first.
  List<Map<String, dynamic>> readAll() {
    final events = _load();
    for (final e in events) {
      e['metadata'] = e['metadata'] is Map
          ? Map<String, dynamic>.from(e['metadata'] as Map)
          : <String, dynamic>{};
    }
    events.sort(
        (a, b) => (b['timestamp'] as int).compareTo(a['timestamp'] as int));
    return events;
  }

  Future<void> clear() => _box.delete(storageKey);
}
