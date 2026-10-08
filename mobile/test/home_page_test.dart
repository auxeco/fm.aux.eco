import 'dart:io';
import 'dart:ui' as ui;

import 'package:aux_fm/arylic/arylic_client.dart';
import 'package:aux_fm/controller/radio_controller.dart';
import 'package:aux_fm/controller/settings.dart';
import 'package:aux_fm/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'radio_controller_test.dart' show FakeAmp, FakePlayer;

Future<void> loadFonts() async {
  final loader = FontLoader('IBMPlexMono')
    ..addFont(rootBundle.load('assets/fonts/IBMPlexMono-Regular.ttf'))
    ..addFont(rootBundle.load('assets/fonts/IBMPlexMono-Bold.ttf'));
  await loader.load();
  // Material icons are not bundled in widget tests; load them from the SDK
  // so screenshots show real icons.
  final sdk = Platform.environment['FLUTTER_ROOT'];
  final icons = File(
    '$sdk/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (sdk != null && icons.existsSync()) {
    final bytes = icons.readAsBytesSync();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
  }
}

/// Set SCREENSHOT_DIR to write PNGs of the rendered screens.
Future<void> screenshot(WidgetTester tester, String name) async {
  final dir = Platform.environment['SCREENSHOT_DIR'];
  if (dir == null) return;
  await tester.pump(const Duration(milliseconds: 300));
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('screen')),
    );
    final image = await boundary.toImage(
      pixelRatio: tester.view.devicePixelRatio,
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$dir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  testWidgets('home screen renders and controls the amp', (tester) async {
    await loadFonts();
    tester.view
      ..physicalSize = const Size(1080, 2340)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final amp = FakeAmp();
    final player = FakePlayer();
    final c = RadioController(
      player: player,
      settings: await Settings.load(),
      ampFactory: (h) => ArylicClient(h, httpGet: amp.get),
      pollInterval: const Duration(hours: 1),
    );
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('screen'),
        child: AuxFmApp(controller: c),
      ),
    );

    expect(find.text('NTS 1'), findsWidgets);
    expect(find.text('+ CONNECT AMP'), findsOneWidget);

    await tester.tap(find.text('KEXP'));
    await tester.pump();
    expect(player.played, ['kexp']);
    await screenshot(tester, 'phone');

    await tester.runAsync(() => c.connectAmp('192.168.1.20'));
    await tester.pump();
    expect(find.text('UP2STREAM AMP'), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);
    await screenshot(tester, 'amp');

    await tester.tap(find.byTooltip('Amp settings'));
    await tester.pumpAndSettle();
    expect(find.text('ARYLIC AMP'), findsOneWidget);
    await screenshot(tester, 'amp_sheet');
    c.dispose();
  });
}
