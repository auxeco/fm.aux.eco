import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../controller/radio_controller.dart';
import '../models/station.dart';
import '../speakers/remote_speaker.dart';
import 'dot_logo.dart';
import 'speaker_sheet.dart';
import 'theme.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.controller});
  final RadioController controller;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  late final StreamSubscription<String> _errors;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _errors = widget.controller.errors.listen(_showMessage);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _errors.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    widget.controller.setForeground(state == AppLifecycleState.resumed);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _Header(controller: c),
            _NowPlaying(controller: c),
            _OutputBar(controller: c),
            Expanded(
              child: _StationList(controller: c, onMessage: _showMessage),
            ),
            _Footer(controller: c),
          ],
        ),
      ),
    );
  }
}

BorderSide _border(BuildContext context) =>
    BorderSide(color: AuxColors.of(context).decorative);

class _Header extends StatelessWidget {
  const _Header({required this.controller});
  final RadioController controller;

  @override
  Widget build(BuildContext context) {
    final colors = AuxColors.of(context);
    return SizedBox(
      height: 96,
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(
                border: Border(right: _border(context)),
              ),
              child: ListenableBuilder(
                listenable: controller,
                builder: (context, _) => DotLogo(playing: controller.isPlaying),
              ),
            ),
          ),
          SizedBox(
            width: 120,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
              child: Align(
                alignment: Alignment.bottomRight,
                child: Text(
                  'AUX\nFM',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.2,
                    letterSpacing: 8.5,
                    color: colors.text,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The EU emblem from the web footer (`Europe.svelte`): twelve
/// four-pointed stars in a circle.
class _EuropePainter extends CustomPainter {
  _EuropePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final r = size.shortestSide / 2;
    canvas.translate(size.width / 2, size.height / 2);
    for (var i = 0; i < 12; i++) {
      canvas.save();
      canvas.rotate(i * math.pi / 6);
      // Proportions of the web SVG: stars ~27% of the radius across, on a
      // ring at 85% of the radius, so they stay separate.
      canvas.translate(0, -r * 0.85);
      final s = r * 0.15;
      final path = Path()
        ..moveTo(0, -s)
        ..quadraticBezierTo(s * 0.15, -s * 0.15, s * 0.95, 0)
        ..quadraticBezierTo(s * 0.15, s * 0.15, 0, s)
        ..quadraticBezierTo(-s * 0.15, s * 0.15, -s * 0.95, 0)
        ..quadraticBezierTo(-s * 0.15, -s * 0.15, 0, -s)
        ..close();
      canvas.drawPath(path, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_EuropePainter old) => old.color != color;
}

class _NowPlaying extends StatelessWidget {
  const _NowPlaying({required this.controller});
  final RadioController controller;

  @override
  Widget build(BuildContext context) {
    final colors = AuxColors.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final station = controller.current;
        final nowPlaying = controller.nowPlaying;
        return Container(
          height: 120,
          decoration: BoxDecoration(
            border: Border(top: _border(context), bottom: _border(context)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(right: _border(context)),
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Semantics(
                          button: true,
                          label: controller.isPlaying
                              ? 'Stop ${station.name}'
                              : 'Play ${station.name}',
                          excludeSemantics: true,
                          child: InkWell(
                            onTap: controller.togglePlay,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      controller.isLoading
                                          ? 'AWAITING SIGNAL ...'
                                          : station.name.toUpperCase(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 22,
                                        color: colors.text,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  _PlayIcon(
                                    playing: controller.isPlaying,
                                    color: colors.primary,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Container(
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        decoration: BoxDecoration(
                          border: Border(top: _border(context)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                nowPlaying ?? station.description,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: nowPlaying != null
                                      ? colors.primary
                                      : colors.text,
                                ),
                              ),
                            ),
                            if (station.link != null)
                              TextButton(
                                onPressed: () => launchUrl(
                                  Uri.parse(station.link!),
                                  mode: LaunchMode.externalApplication,
                                ),
                                style: TextButton.styleFrom(
                                  foregroundColor: colors.primary,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                  ),
                                  minimumSize: const Size(0, 32),
                                ),
                                child: const Text(r'$Donate$'),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: 120,
                child: Center(
                  child: Text(
                    station.name.substring(0, 1).toUpperCase(),
                    style: TextStyle(
                      fontSize: 60,
                      fontWeight: FontWeight.bold,
                      color: colors.text,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PlayIcon extends StatelessWidget {
  const _PlayIcon({required this.playing, required this.color});
  final bool playing;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 100),
      child: playing
          ? Container(
              key: const ValueKey('stop'),
              width: 20,
              height: 20,
              color: color,
            )
          : CustomPaint(
              key: const ValueKey('play'),
              size: const Size(22, 24),
              painter: _TrianglePainter(color),
            ),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  _TrianglePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(size.width, size.height / 2)
        ..lineTo(0, size.height)
        ..close(),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_TrianglePainter old) => old.color != color;
}

/// Shows where the radio plays; tap to pick a speaker.
class _OutputBar extends StatelessWidget {
  const _OutputBar({required this.controller});
  final RadioController controller;

  @override
  Widget build(BuildContext context) {
    final colors = AuxColors.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final remote = controller.isRemote;
        final icon = switch (controller.target?.kind) {
          null => Icons.smartphone,
          SpeakerKind.arylic => Icons.speaker,
          SpeakerKind.cast => Icons.cast_connected,
        };
        return Container(
          decoration: BoxDecoration(border: Border(bottom: _border(context))),
          child: Column(
            children: [
              Semantics(
                button: true,
                label: 'Playing on ${controller.targetName}. Choose speaker',
                excludeSemantics: true,
                child: InkWell(
                  onTap: () => showSpeakerSheet(context, controller),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
                    child: Row(
                      children: [
                        Text(
                          'PLAY ON',
                          style: TextStyle(
                            fontSize: 11,
                            color: colors.decorative,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          icon,
                          size: 18,
                          color: remote ? colors.primary : colors.text,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${remote && !controller.remoteReachable ? '⚠ ' : ''}'
                            '${controller.targetName.toUpperCase()}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: remote ? colors.primary : colors.text,
                              fontWeight: remote
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                        Icon(Icons.expand_more, color: colors.text, size: 20),
                      ],
                    ),
                  ),
                ),
              ),
              if (remote && controller.remoteStatus != null)
                RemoteVolumeSlider(controller: controller),
            ],
          ),
        );
      },
    );
  }
}

class _StationList extends StatelessWidget {
  const _StationList({required this.controller, required this.onMessage});
  final RadioController controller;
  final void Function(String) onMessage;

  @override
  Widget build(BuildContext context) {
    final colors = AuxColors.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 10),
        itemCount: controller.stations.length,
        itemBuilder: (context, i) {
          final Station station = controller.stations[i];
          final selected = station.id == controller.current.id;
          return InkWell(
            onTap: () => controller.selectStation(station),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      station.name.toUpperCase(),
                      style: TextStyle(
                        fontSize: 21,
                        color: selected ? colors.primary : colors.text,
                      ),
                    ),
                  ),
                  if (station.shareUrl != null)
                    InkWell(
                      onTap: () async {
                        await Clipboard.setData(
                          ClipboardData(text: station.shareUrl!),
                        );
                        onMessage('link copied to clipboard');
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Text(
                          '#${station.hashtag!.toUpperCase()}',
                          style: TextStyle(
                            fontSize: 14,
                            color: colors.text.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.controller});
  final RadioController controller;

  @override
  Widget build(BuildContext context) {
    final colors = AuxColors.of(context);
    final style = TextStyle(color: colors.text, fontSize: 14);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(border: Border(top: _border(context))),
      child: Row(
        children: [
          TextButton(
            onPressed: () => controller.toggleTheme(true),
            child: Text('Dark', style: style),
          ),
          Text('|', style: style),
          TextButton(
            onPressed: () => controller.toggleTheme(false),
            child: Text('Light', style: style),
          ),
          const Spacer(),
          Semantics(
            label: 'European Union',
            image: true,
            child: CustomPaint(
              size: const Size.square(32),
              painter: _EuropePainter(colors.text),
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: () => launchUrl(
              Uri.parse('https://github.com/auxeco/fm.aux.eco'),
              mode: LaunchMode.externalApplication,
            ),
            child: Text('Contribute', style: style),
          ),
        ],
      ),
    );
  }
}
