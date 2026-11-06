import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:vokey/app/vokey_app.dart';
import 'package:vokey/services/alert_settings_repository.dart';
import 'package:vokey/services/monitoring_settings_repository.dart';

void main() {
  late Directory dir;

  Future<void> initTempHive() async => Hive.init(dir.path);

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('vokey_startup_');
  });

  tearDown(() async {
    await Hive.close();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  group('AppStartupState.initialize', () {
    test('fresh install opens an empty settings box', () async {
      final state = await AppStartupState.initialize(initHive: initTempHive);
      expect(state.isReady, isTrue);
      expect(state.hasError, isFalse);
      expect(state.settingsBox!.get('onboarding_complete'), isNull);
    });

    test('second launch / upgrade preserves existing settings', () async {
      Hive.init(dir.path);
      final box = await Hive.openBox<dynamic>(AppStartupState.settingsBoxName);
      await box.put('onboarding_complete', true);
      await box.put('alert_volume', 42);
      await Hive.close();

      final state = await AppStartupState.initialize(initHive: initTempHive);
      expect(state.isReady, isTrue);
      expect(state.settingsBox!.get('onboarding_complete'), isTrue);
      expect(AlertSettingsRepository(state.settingsBox!).read().volume, 42);
    });

    test('corrupt box file does not throw; app starts with safe defaults',
        () async {
      File('${dir.path}/${AppStartupState.settingsBoxName}.hive')
          .writeAsBytesSync(List<int>.generate(512, (i) => (i * 37) & 0xff));

      final state = await AppStartupState.initialize(initHive: initTempHive);
      expect(state.isReady, isTrue,
          reason: 'Hive crash recovery should drop unreadable frames');
      final alerts = AlertSettingsRepository(state.settingsBox!).read();
      expect(alerts.volume, 80);
      expect(alerts.soundId, 'classic_beep');
    });

    test('wrongly typed stored values fall back to defaults', () async {
      final state = await AppStartupState.initialize(initHive: initTempHive);
      final box = state.settingsBox!;
      await box.put('alert_volume', 'loud');
      await box.put('alert_sound_id', 12);
      await box.put('onboarding_complete', 'yes');
      final alerts = AlertSettingsRepository(box).read();
      expect(alerts.volume, 80);
      expect(alerts.soundId, 'classic_beep');
      expect(box.get('onboarding_complete') == true, isFalse);
      await box.put('monitoring_preferences', {
        'auto_stop_minutes': 'forever',
        'clap_sensitivity': 3,
        'quiet_start': 99,
      });
      final monitoring = MonitoringSettingsRepository(box).read();
      expect(monitoring.autoStopMinutes, 0);
      expect(monitoring.clapSensitivity, 'normal');
      expect(monitoring.quietStart, '22:00');
      await box.put('monitoring_preferences', 'not a map');
      expect(MonitoringSettingsRepository(box).read().clapEnabled, isTrue);
    });

    test('storage init failure returns a recoverable error state', () async {
      final state = await AppStartupState.initialize(
        initHive: () async => throw const FileSystemException('denied'),
      );
      expect(state.hasError, isTrue);
      expect(state.isReady, isFalse);
    });

    test('resetSettingsStorage deletes the box even when it is not open',
        () async {
      Hive.init(dir.path);
      final box = await Hive.openBox<dynamic>(AppStartupState.settingsBoxName);
      await box.put('onboarding_complete', true);
      await box.close();

      await AppStartupState.resetSettingsStorage();
      final state = await AppStartupState.initialize(initHive: initTempHive);
      expect(state.settingsBox!.get('onboarding_complete'), isNull);
    });
  });

  group('VokeyApp launch', () {
    testWidgets('fresh install shows onboarding, not a crash', (tester) async {
      final state = await tester.runAsync(
        () => AppStartupState.initialize(initHive: initTempHive),
      );
      await tester.pumpWidget(VokeyApp(startupOverride: state));
      await tester.pump();
      expect(find.text('Find Your Phone\nwith Sound'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
    });

    testWidgets('loading state renders a branded splash', (tester) async {
      await tester.pumpWidget(
        VokeyApp(startupOverride: AppStartupState.loading()),
      );
      expect(find.text('Vokey'), findsOneWidget);
      expect(find.text('Preparing your local settings…'), findsOneWidget);
    });

    testWidgets('failed storage shows retry and reset actions', (tester) async {
      await tester.pumpWidget(
        VokeyApp(
          startupOverride: AppStartupState.failed('Storage unavailable.'),
        ),
      );
      expect(find.text('Vokey needs a quick recovery'), findsOneWidget);
      expect(find.text('Storage unavailable.'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      expect(find.text('Reset local data'), findsOneWidget);
    });
  });
}
