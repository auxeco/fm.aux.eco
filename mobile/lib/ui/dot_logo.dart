import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'theme.dart';

/// The AUX FM logo from the web app (`Logo.svelte`): a 6×6 grid of dots.
/// While a station plays, the rings pulse outwards from the centre.
class DotLogo extends StatefulWidget {
  const DotLogo({super.key, required this.playing, this.size = 64});

  final bool playing;
  final double size;

  @override
  State<DotLogo> createState() => _DotLogoState();
}

class _DotLogoState extends State<DotLogo> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(
    (elapsed) => setState(() => _elapsed = elapsed),
  );
  Duration? _elapsed;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(DotLogo old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final animate = widget.playing && !MediaQuery.disableAnimationsOf(context);
    if (animate && !_ticker.isActive) {
      _ticker.start();
    } else if (!animate && _ticker.isActive) {
      _ticker.stop();
      _elapsed = null;
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'AUX FM',
      image: true,
      child: CustomPaint(
        size: Size.square(widget.size),
        painter: _DotLogoPainter(AuxColors.of(context), _elapsed),
      ),
    );
  }
}

class _DotLogoPainter extends CustomPainter {
  _DotLogoPainter(this.colors, this.elapsed);

  final AuxColors colors;
  final Duration? elapsed;

  @override
  void paint(Canvas canvas, Size size) {
    // Same proportions as the SVG: 85 units wide, dots r=4.25 every 15.3.
    final unit = size.width / 85;
    final paint = Paint();
    for (var row = 0; row < 6; row++) {
      for (var col = 0; col < 6; col++) {
        paint.color = dotColor(row, col, elapsed, colors);
        canvas.drawCircle(
          Offset((4.25 + col * 15.3) * unit, (4.25 + row * 15.3) * unit),
          4.25 * unit,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_DotLogoPainter old) =>
      old.elapsed != elapsed || old.colors != colors;
}

const _period = 3000; // ms, as in the CSS animation

/// Colour of the dot at [row], [col] (0–5) after playing for [elapsed]
/// (null when not playing).
///
/// Mirrors the CSS: rings around the centre (0 = inner 2×2, 1, 2 = edge)
/// run a 3 s `levels` animation delayed by 0 s, 1 s and 2 s. The corners of
/// rings 1 and 2 stay still.
Color dotColor(int row, int col, Duration? elapsed, AuxColors colors) {
  if (elapsed == null) return colors.text;
  final dy = (row - 2.5).abs();
  final dx = (col - 2.5).abs();
  final ring = (dx > dy ? dx : dy).floor(); // 0, 1, 2
  if (ring > 0 && dx == dy) return colors.text; // ring corner
  final t = elapsed.inMilliseconds - ring * 1000;
  if (t < 0) return colors.text; // before the animation delay
  final phase = (t % _period) / _period;
  // @keyframes levels { 0%, 10% { decorative } 50% { primary } }, then back
  // to the dot's own colour at 100%; ease-in-out on each segment.
  if (phase < 0.1) return colors.decorative;
  if (phase < 0.5) {
    final p = Curves.easeInOut.transform((phase - 0.1) / 0.4);
    return Color.lerp(colors.decorative, colors.primary, p)!;
  }
  final p = Curves.easeInOut.transform((phase - 0.5) / 0.5);
  return Color.lerp(colors.primary, colors.text, p)!;
}
