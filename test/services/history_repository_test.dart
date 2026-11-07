import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:vokey/services/history_repository.dart';

void main() {
  late Directory tempDirectory;
  late Box<dynamic> box;
  late HistoryRepository repository;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('vokey_history_');
    Hive.init(tempDirectory.path);
    box = await Hive.openBox<dynamic>('history_test');
    repository = HistoryRepository(box);
  });

  tearDown(() async {
    await box.close();
    await Hive.deleteFromDisk();
    await tempDirectory.delete(recursive: true);
  });

  test('stores event metadata without audio or transcript data', () async {
    await repository.record(
      eventType: 'clap_test_detected',
      metadata: {'clap_count': 2, 'rms': 2450.5},
    );
    final events = repository.readAll();
    expect(events, hasLength(1));
    expect(events.single['event_type'], 'clap_test_detected');
    expect(events.single['metadata'], {'clap_count': 2, 'rms': 2450.5});
    expect(events.single.containsKey('audio'), isFalse);
    expect(events.single.containsKey('transcript'), isFalse);
  });

  test('caps event history at the configured maximum', () async {
    for (var i = 0; i < HistoryRepository.maxEvents + 3; i++) {
      await repository.record(
        eventType: 'clap_test_detected',
        metadata: {'clap_count': i + 1},
      );
    }
    final events = repository.readAll();
    expect(events, hasLength(HistoryRepository.maxEvents));
    expect(events.first['metadata']['clap_count'],
        HistoryRepository.maxEvents + 3);
    expect(events.last['metadata']['clap_count'], 4);
  });

  test('clear removes all saved events', () async {
    await repository.record(eventType: 'clap_test_detected');
    await repository.clear();
    expect(repository.readAll(), isEmpty);
  });

  test('feedback is stored on the matching event only', () async {
    final a =
        await repository.record(eventType: HistoryRepository.clapDetected);
    await repository.record(eventType: HistoryRepository.whistleDetected);
    await repository.setFeedback(a, HistoryRepository.feedbackFalseAlarm);
    final events = repository.readAll();
    final marked = events.where((e) =>
        (e['metadata'] as Map)['user_feedback'] ==
        HistoryRepository.feedbackFalseAlarm);
    expect(marked, hasLength(1));
    expect(marked.single['id'], a);
  });

  test('retention removes events older than the chosen window', () async {
    final old = DateTime.now().subtract(const Duration(days: 10));
    await repository.record(eventType: HistoryRepository.clapDetected, at: old);
    await repository.record(eventType: HistoryRepository.whistleDetected);
    expect(repository.readAll(), hasLength(2), reason: 'default keeps 30 days');
    await repository.setRetentionDays(7);
    final events = repository.readAll();
    expect(events, hasLength(1));
    expect(events.single['event_type'], HistoryRepository.whistleDetected);
  });

  test('unknown retention values fall back to 30 days', () async {
    await repository.setRetentionDays(12345);
    expect(repository.retentionDays, 30);
  });
}
