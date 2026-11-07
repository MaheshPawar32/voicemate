import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:vokey/core/theme/vokey_theme.dart';
import 'package:vokey/features/permissions/permission_setup_screen.dart';
import 'package:vokey/services/monitoring_controller.dart';

void main() {
  group('permissionStateFor', () {
    test('maps every Android answer', () {
      expect(permissionStateFor(granted: true, asked: true, rationale: false),
          PermissionState.granted);
      expect(permissionStateFor(granted: false, asked: false, rationale: false),
          PermissionState.notAsked);
      expect(permissionStateFor(granted: false, asked: true, rationale: true),
          PermissionState.denied);
      expect(permissionStateFor(granted: false, asked: true, rationale: false),
          PermissionState.blocked);
      expect(
          permissionStateFor(
              granted: false, asked: false, rationale: false, supported: false),
          PermissionState.unsupported);
    });
  });

  group('screen', () {
    late Directory dir;
    late Box<dynamic> box;
    Map<String, Object> status = {};
    const channel = MethodChannel('com.dev.vokey/monitoring/methods');

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('vokey_perm_ui_');
      Hive.init(dir.path);
      box = await Hive.openBox<dynamic>('perm_ui');
      MonitoringController.resetForTest(MonitoringController(box));
    });

    tearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      MonitoringController.resetForTest();
      await box.close();
      await Hive.deleteFromDisk();
      await dir.delete(recursive: true);
    });

    Future<void> pump(WidgetTester tester, {VoidCallback? onDone}) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'getPermissionStatus') return status;
        return null;
      });
      await tester.pumpWidget(MaterialApp(
        theme: VokeyTheme.dark(),
        home: PermissionSetupScreen(onDone: onDone ?? () {}),
      ));
      await tester.pump();
      await tester.pump();
    }

    testWidgets('shows what is missing and lets the user skip', (tester) async {
      status = {
        'microphone_granted': false,
        'notification_permission_granted': false,
        'notifications_enabled': false,
        'camera_granted': false,
        'has_flash': true,
      };
      var done = false;
      await pump(tester, onDone: () => done = true);
      expect(find.text('Set Up Vokey'), findsOneWidget);
      expect(find.text('Allow & Continue'), findsOneWidget);
      expect(find.text('Allow'), findsNWidgets(3));
      // Hive writes need real async (not the widget-test fake clock).
      await tester.runAsync(() async {
        await tester.tap(find.text('Skip for now'));
        for (var i = 0; i < 40 && !done; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 25));
        }
      });
      await tester.pump();
      expect(done, isTrue);
      expect(box.get(PermissionSetupScreen.doneKey), isTrue);
    });

    testWidgets('blocked permission points to Android Settings',
        (tester) async {
      await tester.runAsync(() => box.put('permission_asked_microphone', true));
      status = {
        'microphone_granted': false,
        'microphone_rationale': false,
        'notification_permission_granted': true,
        'notifications_enabled': true,
        'has_flash': false,
      };
      await pump(tester);
      expect(find.text('Open settings'), findsOneWidget);
      expect(find.text('Not available'), findsOneWidget, reason: 'no flash');
      expect(find.textContaining('will not ask again'), findsOneWidget);
    });

    testWidgets('all required granted offers plain Continue', (tester) async {
      status = {
        'microphone_granted': true,
        'notification_permission_granted': true,
        'notifications_enabled': true,
        'camera_granted': true,
      };
      await pump(tester);
      expect(find.text('Continue'), findsOneWidget);
      expect(find.text('Skip for now'), findsNothing);
    });
  });
}
