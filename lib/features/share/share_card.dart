import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../core/design/tokens.dart';
import '../../domain/score.dart';

/// The image people actually send.
///
/// It has one job: be legible as a thumbnail in a chat list, and make the
/// person looking at it want to know their own number. So it is a number, a
/// word, and a line telling them what to do. Nothing else fits at that size and
/// everything else is noise.
///
/// It is drawn independently of the app's theme, because it will be viewed
/// inside someone else's messaging app on some other phone. A fixed, deliberate
/// palette is the correct choice here in a way it never is inside the app.
class ShareCard extends StatelessWidget {
  const ShareCard({
    super.key,
    required this.score,
    required this.linkLabel,
    this.subtitle,
  });

  final SecurityScore score;
  final String linkLabel;
  final String? subtitle;

  /// 1080 x 1350, the aspect ratio that survives every messaging app's
  /// thumbnail crop without losing the number.
  static const Size pixelSize = Size(1080, 1350);
  static const double logicalWidth = 360;
  static const double logicalHeight = 450;

  static const _ink = Color(0xFFF2F3F5);
  static const _inkDim = Color(0x99F2F3F5);
  static const _backdrop = Color(0xFF16181C);
  static const _track = Color(0x1AFFFFFF);

  Color get _accent => switch (score.band) {
        ScoreBand.solid => const Color(0xFF4ADE80),
        ScoreBand.exposed => const Color(0xFFFBBF24),
        ScoreBand.atRisk => const Color(0xFFF87171),
      };

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: logicalWidth,
      height: logicalHeight,
      child: ColoredBox(
        color: _backdrop,
        child: Padding(
          padding: const EdgeInsets.all(Insets.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const _Mark(),
                  const SizedBox(width: Insets.sm),
                  const Text(
                    'AEGIS',
                    style: TextStyle(
                      color: _ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.4,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Center(
                child: SizedBox(
                  width: 190,
                  height: 190,
                  child: CustomPaint(
                    painter: _CardDial(
                      progress: score.value / 100,
                      color: _accent,
                    ),
                    child: Center(
                      child: Text(
                        '${score.value}',
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 68,
                          height: 1,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -2,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: Insets.xl),
              Center(
                child: Text(
                  subtitle ?? _defaultSubtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _accent,
                    fontSize: 17,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: Insets.lg,
                  vertical: Insets.md,
                ),
                decoration: BoxDecoration(
                  color: _track,
                  borderRadius: BorderRadius.circular(Corners.container),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'What does your phone score?',
                      style: TextStyle(
                        color: _ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      linkLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _inkDim,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _defaultSubtitle => switch (score.band) {
        ScoreBand.solid when score.isPerfect => 'Nothing left open',
        ScoreBand.solid => 'Locked down',
        ScoreBand.exposed => '${score.issueCount} gaps left',
        ScoreBand.atRisk => 'Something is wide open',
      };
}

/// The wordmark. A shield reduced to the two strokes that still read as one at
/// forty pixels wide.
class _Mark extends StatelessWidget {
  const _Mark();

  @override
  Widget build(BuildContext context) =>
      const SizedBox(width: 16, height: 18, child: CustomPaint(painter: _MarkPainter()));
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w / 2, 0)
      ..lineTo(w, h * 0.22)
      ..lineTo(w, h * 0.58)
      ..quadraticBezierTo(w, h * 0.9, w / 2, h)
      ..quadraticBezierTo(0, h * 0.9, 0, h * 0.58)
      ..lineTo(0, h * 0.22)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = ShareCard._ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_MarkPainter oldDelegate) => false;
}

class _CardDial extends CustomPainter {
  const _CardDial({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.05;
    final circle = (Offset.zero & size).deflate(stroke / 2);

    canvas.drawArc(
      circle,
      0,
      math.pi * 2,
      false,
      Paint()
        ..color = ShareCard._track
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );

    if (progress <= 0) return;
    canvas.drawArc(
      circle,
      -math.pi / 2,
      math.pi * 2 * progress.clamp(0.0, 1.0),
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_CardDial old) =>
      old.progress != progress || old.color != color;
}
