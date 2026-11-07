import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:vokey/core/theme/vokey_theme.dart';
import 'package:vokey/features/history/history_screen.dart';
import 'package:vokey/services/history_repository.dart';
import 'package:vokey/services/monitoring_controller.dart';

void main() {
  late Directory dir;
  late Box<dynamic> box;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('vokey_history_ui_');
    Hive.init(dir.path);
    box = await Hive.openBox<dynamic>('history_ui');
    MonitoringController.resetForTest(MonitoringController(box));
  });

  tearDown(() async {
    MonitoringController.resetForTest();
    await box.close();
    await Hive.deleteFromDisk();
    await dir.delete(recursive: true);
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: VokeyTheme.dark(), home: const HistoryScreen()),
    );
    await tester.pump();
  }

  testWidgets('empty history explains that no audio is saved', (tester) async {
    await pump(tester);
    expect(find.text('No history yet'), findsOneWidget);
    expect(find.textContaining('never saves audio'), findsOneWidget);
  });

  testWidgets('groups by day and filters by method', (tester) async {
    final repo = MonitoringController.instance.history;
    await tester.runAsync(() async {
      await repo.record(
          eventType: HistoryRepository.clapDetected,
          metadata: {'clap_pattern': 2});
      await repo.record(
          eventType: HistoryRepository.whistleDetected,
          metadata: {'whistle_frequency_hz': 2200});
      await repo.record(
        eventType: HistoryRepository.clapDetected,
        at: DateTime.now().subtract(const Duration(days: 1)),
      );
    });
    await pump(tester);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Yesterday'), findsOneWidget);
    expect(find.text('Double clap detected'), findsOneWidget);
    expect(find.text('Whistle detected'), findsOneWidget);

    await tester.tap(find.text('Whistle').first);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Whistle detected'), findsOneWidget);
    expect(find.text('Double clap detected'), findsNothing);
    expect(find.text('Yesterday'), findsNothing);
  });
}
