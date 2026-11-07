import 'history_repository.dart';

/// Local-only aggregates computed from history metadata. No audio, no
/// transcripts, nothing leaves the device.
class AnalyticsSummary {
  const AnalyticsSummary({
    required this.claps,
    required this.whistles,
    required this.voice,
    required this.falseAlarms,
    required this.found,
    required this.monitoringTime,
    required this.sessions,
    required this.perDay,
  });

  final int claps;
  final int whistles;
  final int voice;
  final int falseAlarms;
  final int found;
  final Duration monitoringTime;
  final int sessions;

  /// Oldest → newest, one entry per day in the window (detections only).
  final List<DayCount> perDay;

  int get total => claps + whistles + voice;
}

class DayCount {
  const DayCount(this.day, this.count);
  final DateTime day;
  final int count;
}

class DetectionAnalytics {
  /// [days] = window length ending today (1 = today, 7 = this week).
  /// Use 0 for all retained history.
  static AnalyticsSummary summarize(
    List<Map<String, dynamic>> events, {
    int days = 0,
    DateTime? now,
  }) {
    final today = _dayOf(now ?? DateTime.now());
    final start = days > 0 ? _minusDays(today, days - 1) : null;
    var claps = 0,
        whistles = 0,
        voice = 0,
        falseAlarms = 0,
        found = 0,
        sessions = 0;
    var monitoringMs = 0;
    final buckets = <DateTime, int>{};
    for (final e in events) {
      final ts = e['timestamp'];
      final type = e['event_type'];
      if (ts is! int || type is! String) continue;
      final at = DateTime.fromMillisecondsSinceEpoch(ts);
      if (start != null && at.isBefore(start)) continue;
      final meta = e['metadata'] is Map ? e['metadata'] as Map : const {};
      if (type == HistoryRepository.monitoringSession) {
        sessions++;
        final d = meta['duration_ms'];
        if (d is num && d > 0) monitoringMs += d.toInt();
        continue;
      }
      if (!HistoryRepository.detectionTypes.contains(type)) continue;
      switch (type) {
        case HistoryRepository.clapDetected:
          claps++;
        case HistoryRepository.whistleDetected:
          whistles++;
        default:
          voice++;
      }
      final fb = meta['user_feedback'];
      if (fb == HistoryRepository.feedbackFalseAlarm) falseAlarms++;
      if (fb == HistoryRepository.feedbackFound) found++;
      final day = _dayOf(at);
      buckets[day] = (buckets[day] ?? 0) + 1;
    }
    final windowDays = days > 0 ? days : 7;
    final perDay = [
      for (var i = windowDays - 1; i >= 0; i--)
        DayCount(_minusDays(today, i), buckets[_minusDays(today, i)] ?? 0),
    ];
    return AnalyticsSummary(
      claps: claps,
      whistles: whistles,
      voice: voice,
      falseAlarms: falseAlarms,
      found: found,
      monitoringTime: Duration(milliseconds: monitoringMs),
      sessions: sessions,
      perDay: perDay,
    );
  }

  static DateTime _dayOf(DateTime t) => DateTime(t.year, t.month, t.day);

  /// Calendar arithmetic (DST-safe; Duration(days:) is 24h and is not).
  static DateTime _minusDays(DateTime day, int n) =>
      DateTime(day.year, day.month, day.day - n);
}
