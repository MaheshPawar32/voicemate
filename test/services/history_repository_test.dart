import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:voicemate/services/history_repository.dart';

void main() {
  late Directory tempDirectory;
  late Box<dynamic> box;
  late HistoryRepository repository;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('voicemate_history_');
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
}
