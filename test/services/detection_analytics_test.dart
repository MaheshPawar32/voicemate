import 'package:flutter_test/flutter_test.dart';
import 'package:vokey/services/detection_analytics.dart';
import 'package:vokey/services/history_repository.dart';

Map<String, dynamic> ev(String type, DateTime at,
        [Map<String, dynamic>? meta]) =>
    {
      'id': '${at.microsecondsSinceEpoch}',
      'event_type': type,
      'timestamp': at.millisecondsSinceEpoch,
      'metadata': meta ?? <String, dynamic>{},
    };

void main() {
  final now = DateTime(2026, 11, 7, 15);

  final events = [
    ev(HistoryRepository.clapDetected, DateTime(2026, 11, 7, 9)),
    ev(HistoryRepository.clapDetected, DateTime(2026, 11, 7, 10),
        {'user_feedback': HistoryRepository.feedbackFalseAlarm}),
    ev(HistoryRepository.whistleDetected, DateTime(2026, 11, 5, 8)),
    ev(HistoryRepository.voiceFindPhone, DateTime(2026, 10, 1, 8)),
    ev(HistoryRepository.monitoringSession, DateTime(2026, 11, 7, 11),
        {'duration_ms': 90 * 60 * 1000}),
    ev(HistoryRepository.voiceLockPhone, DateTime(2026, 11, 7, 12)),
    {'event_type': 'broken'},
  ];

  test('overview counts every detection type and session time', () {
    final s = DetectionAnalytics.summarize(events, now: now);
    expect(s.claps, 2);
    expect(s.whistles, 1);
    expect(s.voice, 1, reason: 'lock commands are not find detections');
    expect(s.total, 4);
    expect(s.falseAlarms, 1);
    expect(s.sessions, 1);
    expect(s.monitoringTime, const Duration(minutes: 90));
  });

  test('daily window only counts today', () {
    final s = DetectionAnalytics.summarize(events, days: 1, now: now);
    expect(s.total, 2);
    expect(s.perDay, hasLength(1));
    expect(s.perDay.single.count, 2);
  });

  test('weekly window buckets per calendar day, oldest first', () {
    final s = DetectionAnalytics.summarize(events, days: 7, now: now);
    expect(s.total, 3);
    expect(s.perDay, hasLength(7));
    expect(s.perDay.last.day, DateTime(2026, 11, 7));
    expect(s.perDay.last.count, 2);
    expect(s.perDay[4].day, DateTime(2026, 11, 5));
    expect(s.perDay[4].count, 1);
  });

  test('day buckets stay on midnight across a DST change', () {
    // Europe/US DST shifts happen in late Oct / early Nov; calendar maths
    // must never produce 23:00 buckets.
    final s = DetectionAnalytics.summarize(const [], days: 14, now: now);
    for (final d in s.perDay) {
      expect(d.day.hour, 0);
    }
  });

  test('empty history is all zeros', () {
    final s = DetectionAnalytics.summarize(const [], now: now);
    expect(s.total, 0);
    expect(s.monitoringTime, Duration.zero);
  });
}
