import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicemate/features/onboarding/onboarding_screen.dart';

void main() {
  testWidgets('onboarding advances through its introduction', (tester) async {
    var completed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingScreen(onComplete: () => completed = true),
      ),
    );

    expect(find.text('Test clap detection'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Simple, offline-first'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Microphone privacy'), findsOneWidget);

    await tester.tap(find.text('Get started'));
    expect(completed, isTrue);
  });
}
