import 'package:aux_fm/arylic/arylic_client.dart';
import 'package:aux_fm/cast/cast_discovery.dart';
import 'package:aux_fm/controller/radio_controller.dart';
import 'package:aux_fm/controller/settings.dart';
import 'package:aux_fm/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes/fakes.dart';
import 'fakes/ui_helpers.dart';

void main() {
  testWidgets('home screen, speaker picker and amp control', (tester) async {
    await loadFonts();
    tester.view
      ..physicalSize = const Size(1080, 2340)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final amp = FakeAmp();
    final player = FakePlayer();
    final discovery = FakeCastDiscovery();
    final c = RadioController(
      player: player,
      settings: await Settings.load(),
      ampFactory: (h) => ArylicClient(h, httpGet: amp.get),
      castDiscovery: discovery,
      locateAmps: () async => [],
      pollInterval: const Duration(hours: 1),
    );
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('screen'),
        child: AuxFmApp(controller: c),
      ),
    );
    await tester.runAsync(c.init);
    discovery.announce(const [
      CastDevice(
        id: 'a',
        name: 'Kitchen speaker',
        host: '10.0.0.5',
        model: 'Google Nest Mini',
      ),
      CastDevice(id: 'b', name: 'Living Room TV', host: '10.0.0.6'),
    ]);
    await tester.pump();

    expect(find.text('NTS 1'), findsWidgets);
    expect(find.text('PHONE'), findsOneWidget);

    await tester.tap(find.text('KEXP'));
    await tester.pump();
    expect(player.played, ['kexp']);
    await screenshot(tester, 'phone');

    await tester.runAsync(() => c.connectAmp('192.168.1.20'));
    await tester.pump();
    expect(find.text('UP2STREAM AMP'), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);
    await screenshot(tester, 'amp');

    await tester.tap(find.text('UP2STREAM AMP'));
    await settle(tester);
    expect(find.text('This phone'), findsOneWidget);
    expect(find.text('Up2Stream Amp'), findsOneWidget);
    expect(find.text('Kitchen speaker'), findsOneWidget);
    expect(find.text('Google Cast · Google Nest Mini'), findsOneWidget);
    expect(find.text('ARYLIC AMP SETTINGS'), findsOneWidget);
    await screenshot(tester, 'speakers');

    await tester.tap(find.text('This phone'));
    await settle(tester);
    expect(find.text('PHONE'), findsOneWidget);
    expect(player.played, ['kexp', 'kexp']);

    // The version is at the end of the station list.
    await tester.scrollUntilVisible(find.text('AUX FM dev'), 200);
    expect(find.text('AUX FM dev'), findsOneWidget);
    c.dispose();
  });
}
