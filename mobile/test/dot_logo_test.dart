import 'package:aux_fm/ui/dot_logo.dart';
import 'package:aux_fm/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const c = AuxColors.dark;
  Color at(int row, int col, int ms) =>
      dotColor(row, col, Duration(milliseconds: ms), c);

  test('all dots are plain while not playing', () {
    for (var r = 0; r < 6; r++) {
      for (var col = 0; col < 6; col++) {
        expect(dotColor(r, col, null, c), c.text);
      }
    }
  });

  test('centre pulses first, then each ring one second later', () {
    // Peak (50% of the 3 s cycle) of the inner 2×2 at 1.5 s.
    expect(at(2, 2, 1500), c.primary);
    expect(at(3, 3, 1500), c.primary);
    // Ring 1 (e.g. row 2, col 1) peaks at 2.5 s; ring 2 at 3.5 s.
    expect(at(2, 1, 1500), isNot(c.primary));
    expect(at(2, 1, 2500), c.primary);
    expect(at(0, 2, 3500), c.primary);
    // Before its delay the outer ring keeps its normal colour.
    expect(at(0, 2, 900), c.text);
  });

  test('ring corners never animate', () {
    for (final ms in [0, 700, 1500, 2500, 3500, 5000]) {
      expect(at(0, 0, ms), c.text);
      expect(at(5, 0, ms), c.text);
      expect(at(1, 1, ms), c.text);
      expect(at(4, 1, ms), c.text);
    }
  });

  testWidgets('animates only while playing', (tester) async {
    Widget logo(bool playing) => MaterialApp(
      theme: buildTheme(true),
      home: DotLogo(playing: playing),
    );
    await tester.pumpWidget(logo(true));
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpWidget(logo(false));
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('respects "remove animations"', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(
      MaterialApp(theme: buildTheme(true), home: const DotLogo(playing: true)),
    );
    expect(tester.hasRunningAnimations, isFalse);
  });
}
