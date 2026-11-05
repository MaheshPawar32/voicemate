import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicemate/features/onboarding/onboarding_screen.dart';

void main() {
  testWidgets('onboarding advances through all current introduction pages',
      (tester) async {
    var completed = false;
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingScreen(onComplete: () => completed = true),
      ),
    );

    expect(find.text('Find your phone with sound'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Use optional offline voice commands'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Your controls stay in your hands'), findsOneWidget);

    await tester.ensureVisible(find.text('Get started'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Get started'));
    expect(completed, isTrue);
  });

  testWidgets('onboarding can be skipped from the first page', (tester) async {
    var completed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingScreen(onComplete: () => completed = true),
      ),
    );

    await tester.tap(find.text('Skip'));
    expect(completed, isTrue);
  });
}
