import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TrustScoreGauge extends StatelessWidget {
  final int score;
  const TrustScoreGauge({super.key, required this.score});

  Color get _color {
    if (score > 70) return Colors.white;
    if (score > 40) return const Color(0xFFFFFF00);
    return const Color(0xFFFF0000);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: CustomPaint(
        painter: _GaugePainter(score: score, color: _color),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 20),
              Text(
                '$score%',
                style: GoogleFonts.spaceMono(
                  color: _color,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'INTEGRITY',
                style: GoogleFonts.spaceMono(
                  color: Colors.white54,
                  fontSize: 10,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final int score;
  final Color color;

  _GaugePainter({required this.score, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.7);
    final radius = size.width * 0.38;

    // Background arc
    final bgPaint = Paint()
      ..color = Colors.white12
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.butt;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      pi,
      pi,
      false,
      bgPaint,
    );

    // Score arc
    final scorePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.butt;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      pi,
      pi * (score / 100),
      false,
      scorePaint,
    );

    // Tick marks
    final tickPaint = Paint()
      ..color = Colors.white30
      ..strokeWidth = 1;

    for (int i = 0; i <= 10; i++) {
      final angle = pi + (pi * i / 10);
      final outerR = radius + 10;
      final innerR = radius + 4;
      canvas.drawLine(
        Offset(center.dx + cos(angle) * innerR, center.dy + sin(angle) * innerR),
        Offset(center.dx + cos(angle) * outerR, center.dy + sin(angle) * outerR),
        tickPaint,
      );
    }

    // Needle
    final needleAngle = pi + (pi * score / 100);
    final needlePaint = Paint()
      ..color = color
      ..strokeWidth = 2;
    canvas.drawLine(
      center,
      Offset(
        center.dx + cos(needleAngle) * (radius - 8),
        center.dy + sin(needleAngle) * (radius - 8),
      ),
      needlePaint,
    );

    // Center dot
    canvas.drawRect(
      Rect.fromCenter(center: center, width: 8, height: 8),
      Paint()..color = color,
    );

    // V-chevron below
    final chevronPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final cx = center.dx;
    final cy = center.dy + radius * 0.35;
    final path = Path()
      ..moveTo(cx - 24, cy - 10)
      ..lineTo(cx, cy + 6)
      ..lineTo(cx + 24, cy - 10);
    canvas.drawPath(path, chevronPaint);
  }

  @override
  bool shouldRepaint(_GaugePainter old) => old.score != score;
}
