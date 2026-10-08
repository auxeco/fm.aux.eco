import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import 'audio/radio_audio_handler.dart';
import 'controller/radio_controller.dart';
import 'controller/settings.dart';
import 'ui/home_page.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final player = await AudioService.init(
    builder: RadioAudioHandler.new,
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'eco.aux.fm.playback',
      androidNotificationChannelName: 'Radio playback',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );
  final controller = RadioController(
    player: player,
    settings: await Settings.load(),
  );
  runApp(AuxFmApp(controller: controller));
  await controller.init();
}

class AuxFmApp extends StatelessWidget {
  const AuxFmApp({super.key, required this.controller});
  final RadioController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => MaterialApp(
        title: 'AUX FM',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(controller.darkTheme),
        home: HomePage(controller: controller),
      ),
    );
  }
}
