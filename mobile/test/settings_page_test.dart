import 'package:aux_fm/audio/stream_probe.dart';
import 'package:aux_fm/controller/radio_controller.dart';
import 'package:aux_fm/controller/settings.dart';
import 'package:aux_fm/main.dart';
import 'package:aux_fm/models/station.dart';
import 'package:aux_fm/ui/settings_page.dart';
import 'package:aux_fm/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes/fakes.dart';
import 'fakes/ui_helpers.dart';

const extra = Station(
  id: 'fip',
  name: 'FIP',
  url: 'https://fip.example/stream',
  description: 'Eclectic music from Paris.',
);

/// Builds and scrolls [finder] fully into view in the settings list.
Future<void> reveal(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 200);
  await tester.ensureVisible(finder);
  await tester.pump();
}

void main() {
  late RadioController c;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    c = RadioController(
      player: FakePlayer(),
      settings: await Settings.load(),
      moreStations: const [extra],
      locateAmps: () async => [],
      pollInterval: const Duration(hours: 1),
    );
  });

  void bigScreen(WidgetTester tester) {
    tester.view
      ..physicalSize = const Size(1080, 2340)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  testWidgets('footer has Settings, not Contribute', (tester) async {
    bigScreen(tester);
    await loadFonts();
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('screen'),
        child: AuxFmApp(controller: c),
      ),
    );
    expect(find.text('Contribute'), findsNothing);
    await tester.tap(find.text('Settings'));
    await settle(tester);
    expect(find.text('SETTINGS'), findsOneWidget);
    expect(find.text('AUX FM SELECTION'), findsOneWidget);
    await screenshot(tester, 'settings');
  });

  Future<void> openSettings(WidgetTester tester, {StreamChecker? check}) async {
    bigScreen(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(true),
        home: SettingsPage(
          controller: c,
          checkStream:
              check ??
              (url) async => StreamProbe(200, 'audio/mpeg', 32768, 'mp3'),
        ),
      ),
    );
  }

  testWidgets('ticking an extra station adds it to the list', (tester) async {
    await openSettings(tester);
    expect(c.stations.any((s) => s.id == 'fip'), isFalse);
    await reveal(tester, find.text('FIP'));
    await tester.tap(find.text('FIP'));
    await tester.pump();
    expect(c.stations.last.id, 'fip');
  });

  testWidgets('adds a station the user types in', (tester) async {
    await openSettings(tester);
    await reveal(tester, find.text('Add station'));
    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'My Radio');
    await tester.enterText(
      find.widgetWithText(TextField, 'Stream URL'),
      'https://my.example/live.mp3',
    );
    await tester.tap(find.text('Add station'));
    await tester.pump();
    await tester.pump();
    expect(c.stations.last.name, 'My Radio');
    expect(find.text('Added My Radio to your list.'), findsOneWidget);
    expect(find.text('My Radio'), findsOneWidget); // under YOUR STATIONS
  });

  testWidgets('explains bad input and playlist files', (tester) async {
    await openSettings(
      tester,
      check: (url) async => StreamProbe(200, 'audio/x-scpls', 120, 'playlist'),
    );
    await reveal(tester, find.text('Add station'));
    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'X');
    await tester.enterText(
      find.widgetWithText(TextField, 'Stream URL'),
      'radio.example',
    );
    await tester.tap(find.text('Add station'));
    await tester.pump();
    expect(find.textContaining('starting with https://'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Stream URL'),
      'https://radio.example/listen.pls',
    );
    await tester.tap(find.text('Add station'));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('playlist file'), findsOneWidget);
    expect(c.library.custom, isEmpty);
  });

  testWidgets('deletes a station the user added', (tester) async {
    final mine = c.addStation(name: 'My Radio', url: 'https://my/s');
    await openSettings(tester);
    await reveal(tester, find.byTooltip('Delete My Radio'));
    await tester.tap(find.byTooltip('Delete My Radio'));
    await tester.pump();
    expect(c.library.byId(mine.id), isNull);
  });
}
