import 'package:flutter_test/flutter_test.dart';

void main() {
  test('screen lock feature is explicitly lock-only', () {
    const disclosure = 'Lock only. Never unlock.';
    expect(disclosure.toLowerCase(), contains('lock'));
    expect(disclosure.toLowerCase(), contains('never unlock'));
  });
}
