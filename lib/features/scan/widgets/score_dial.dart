import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../../core/design/semantic_colors.dart';
import '../../../core/design/tokens.dart';
import '../../../domain/score.dart';

/// The one hero element in the app.
///
/// A single thin arc and a number. No gradient, no glow, no shadow: the arc is
/// a measurement, and dressing a measurement up is how you stop people
/// believing it. The number counts up from wherever it was, so a fix worth six
/// points is visibly six points.
///
/// The determinate value is driven by [TweenAnimationBuilder] rather than a
/// hand-managed controller. Retargeting a controller from `didUpdateWidget`
/// means reassigning the animation the builder is listening to, which survives
/// a test harness that pumps to settle and then quietly fails to tick on a real
/// frame schedule. Declaring the target and letting the framework animate to it
/// removes the whole class of bug.
class ScoreDial extends StatefulWidget {
  const ScoreDial({
    super.key,
    required this.score,
    this.diameter = 220,
    this.scanning = false,
    this.caption,
  });

  final SecurityScore score;
  final double diameter;

  /// Sweeps the arc as an indeterminate progress ring while a scan runs.
  final bool scanning;

  final String? caption;

  @override
  State<ScoreDial> createState() => _ScoreDialState();
}

class _ScoreDialState extends State<ScoreDial>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sweep;

  @override
  void initState() {
    super.initState();
    _sweep = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (widget.scanning) _sweep.repeat();
  }

  @override
  void didUpdateWidget(ScoreDial old) {
    super.didUpdateWidget(old);
    if (widget.scanning == old.scanning) return;
    if (widget.scanning) {
      _sweep.repeat();
    } else {
      _sweep.stop();
    }
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final band = widget.score.band;
    final arcColor = switch (band) {
      ScoreBand.solid => colors.secure,
      ScoreBand.exposed => colors.caution,
      ScoreBand.atRisk => colors.critical,
    };

    // While scanning the ring shows the sweep, so the value is held where it
    // is rather than animated towards a number that is still being computed.
    final target = widget.scanning ? 0.0 : widget.score.value / 100;

    return SizedBox(
      width: widget.diameter,
      height: widget.diameter,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: target),
        duration: widget.scanning ? Duration.zero : Motion.dial,
        curve: Motion.emphasized,
        builder: (context, progress, _) {
          return AnimatedBuilder(
            animation: _sweep,
            builder: (context, _) => CustomPaint(
              painter: _DialPainter(
                progress: progress,
                sweep: widget.scanning ? _sweep.value : null,
                track: colors.fill,
                arc: widget.scanning ? colors.accent : arcColor,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Numeral(
                      value: widget.scanning ? null : (progress * 100).round(),
                      size: widget.diameter * 0.31,
                      color: colors.label,
                    ),
                    const SizedBox(height: Insets.xs),
                    Text(
                      widget.caption ??
                          (widget.scanning ? 'Checking' : band.label),
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.2,
                        fontWeight: FontWeight.w600,
                        letterSpacing: isApple ? -0.1 : 0.1,
                        color:
                            widget.scanning ? colors.secondaryLabel : arcColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The score itself. Tabular figures, so the digits do not shuffle sideways
/// while the number counts up.
class _Numeral extends StatelessWidget {
  const _Numeral({required this.value, required this.size, required this.color});

  final int? value;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      value?.toString() ?? '—',
      style: TextStyle(
        fontSize: size,
        height: 1.0,
        color: color,
        fontWeight: FontWeight.w600,
        letterSpacing: -size * 0.03,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

class _DialPainter extends CustomPainter {
  _DialPainter({
    required this.progress,
    required this.sweep,
    required this.track,
    required this.arc,
  });

  /// 0 to 1. Ignored while [sweep] is non-null.
  final double progress;

  /// 0 to 1 phase of the indeterminate sweep, or null when idle.
  final double? sweep;

  final Color track;
  final Color arc;

  static const double _startAngle = -math.pi / 2;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.045;
    final rect = Offset.zero & size;
    final circle = rect.deflate(stroke / 2 + size.width * 0.06);

    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    final arcPaint = Paint()
      ..color = arc
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(circle, 0, math.pi * 2, false, trackPaint);

    if (sweep != null) {
      // A short arc travelling the ring, with the head easing ahead of the
      // tail so the segment breathes rather than sliding rigidly.
      final phase = sweep! * math.pi * 2;
      final length = math.pi * (0.35 + 0.25 * math.sin(sweep! * math.pi * 2));
      canvas.drawArc(circle, _startAngle + phase, length, false, arcPaint);
      return;
    }

    if (progress <= 0) return;
    canvas.drawArc(
      circle,
      _startAngle,
      math.pi * 2 * progress.clamp(0.0, 1.0),
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(_DialPainter old) =>
      old.progress != progress ||
      old.sweep != sweep ||
      old.arc != arc ||
      old.track != track;
}
