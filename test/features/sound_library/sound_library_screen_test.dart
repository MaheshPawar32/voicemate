import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:vokey/app/vokey_app.dart';
import 'package:vokey/core/theme/vokey_theme.dart';
import 'package:vokey/features/sound_library/sound_library_screen.dart';
import 'package:vokey/services/custom_sounds_repository.dart';

void main() {
  late Directory dir;
  late Box<dynamic> box;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('vokey_library_ui_');
    Hive.init(dir.path);
    box = await Hive.openBox<dynamic>(AppStartupState.settingsBoxName);
    await CustomSoundsRepository(box).add(const CustomSound(
      id: 'custom:abc.mp3',
      name: 'Doorbell',
      fileName: 'abc.mp3',
      durationMs: 2500,
      sizeBytes: 1000,
      importedAt: 1,
    ));
  });

  tearDown(() async {
    await box.close();
    await Hive.deleteFromDisk();
    await dir.delete(recursive: true);
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(theme: VokeyTheme.dark(), home: const SoundLibraryScreen()),
    );
  }

  testWidgets('lists built-in and imported sounds; filters and searches',
      (tester) async {
    await pump(tester);
    expect(find.text('Classic beep'), findsOneWidget);
    expect(find.text('Doorbell'), findsOneWidget);

    await tester.tap(find.text('My sounds'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Classic beep'), findsNothing);
    expect(find.text('Doorbell'), findsOneWidget);

    await tester.tap(find.text('All'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(find.byType(TextField), 'chime');
    await tester.pump();
    expect(find.text('Soft chime'), findsOneWidget);
    expect(find.text('Doorbell'), findsNothing);
  });

  testWidgets('selecting an imported sound saves it', (tester) async {
    await pump(tester);
    await tester.runAsync(() async {
      await tester.tap(find.text('Doorbell'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    expect(box.get('alert_sound_id'), 'custom:abc.mp3');
    expect(find.text('Selected for alerts'), findsOneWidget);
  });
}
