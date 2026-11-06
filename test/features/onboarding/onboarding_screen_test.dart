import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vokey/features/onboarding/onboarding_screen.dart';

void main() {
  // The hero glow repeats, so advance by fixed durations, not pumpAndSettle.
  Future<void> settlePage(WidgetTester tester) async {
    await tester.pump(); // start the page animation
    await tester.pump(const Duration(milliseconds: 600)); // finish it
    await tester.pump(const Duration(milliseconds: 300)); // button cross-fade
  }

  testWidgets('onboarding advances through its three slides', (tester) async {
    var completed = false;
    await tester.pumpWidget(
      MaterialApp(home: OnboardingScreen(onComplete: () => completed = true)),
    );

    expect(find.text('Find Your Phone\nwith Sound'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await settlePage(tester);
    expect(find.text('Voice Commands\nthat Work Offline'), findsOneWidget);
    expect(find.textContaining('one-time download'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await settlePage(tester);
    expect(find.text('Private & Secure'), findsOneWidget);
    expect(find.text('Skip'), findsNothing);

    expect(completed, isFalse);
    await tester.tap(find.text('Get Started'));
    expect(completed, isTrue);
  });

  testWidgets('swiping also changes slides', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: OnboardingScreen(onComplete: () {})),
    );
    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1200);
    await settlePage(tester);
    expect(find.text('Voice Commands\nthat Work Offline'), findsOneWidget);
  });

  testWidgets('skip completes onboarding immediately', (tester) async {
    var completed = false;
    await tester.pumpWidget(
      MaterialApp(home: OnboardingScreen(onComplete: () => completed = true)),
    );
    await tester.tap(find.text('Skip'));
    expect(completed, isTrue);
  });
}
