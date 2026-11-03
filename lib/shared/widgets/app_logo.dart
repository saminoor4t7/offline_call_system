import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../core/utils/format.dart';

/// Microphone with wireless signal waves – same geometry as the launcher icon.
class AppLogoPainter extends CustomPainter {
  AppLogoPainter({this.scale = 1.0});
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    Offset p(double u, double v) => Offset(
          (0.5 + (u - 0.5) * scale) * s,
          (0.5 + (v + 0.02 - 0.5) * scale) * s,
        );
    final w = 0.035 * scale * s;
    final shader = const LinearGradient(
      colors: [AppColors.blue, AppColors.cyan],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ).createShader(Rect.fromLTWH(0, 0, s, s));

    Paint stroke([double a = 1]) => Paint()
      ..shader = LinearGradient(
        colors: [AppColors.blue.o(a), AppColors.cyan.o(a)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, s, s))
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round;

    final fill = Paint()..shader = shader;

    // Capsule
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromPoints(p(0.42, 0.26), p(0.58, 0.54)),
        Radius.circular(0.08 * scale * s),
      ),
      fill,
    );

    // Holder (lower half circle)
    final c = p(0.5, 0.45);
    final rr = 0.15 * scale * s;
    canvas.drawArc(Rect.fromCircle(center: c, radius: rr), 0, math.pi, false, stroke());
    // Stem + base
    canvas.drawLine(p(0.5, 0.60), p(0.5, 0.70), stroke());
    canvas.drawLine(p(0.42, 0.70), p(0.58, 0.70), stroke());

    // Waves
    const sweep = 80 * math.pi / 180;
    void waves(double radius, double alpha) {
      final r = radius * scale * s;
      final rect = Rect.fromCircle(center: c, radius: r);
      canvas.drawArc(rect, -sweep / 2, sweep, false, stroke(alpha));
      canvas.drawArc(rect, math.pi - sweep / 2, sweep, false, stroke(alpha));
    }

    waves(0.26, 1);
    waves(0.36, 0.65);
  }

  @override
  bool shouldRepaint(covariant AppLogoPainter old) => old.scale != scale;
}

class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 96});
  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size.square(size),
        painter: AppLogoPainter(),
      );
}

/// Logo on a navy rounded tile – used in headers.
class AppLogoBadge extends StatelessWidget {
  const AppLogoBadge({super.key, this.size = 48});
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.3),
          gradient: const LinearGradient(
            colors: [Color(0xFF16213A), AppColors.darkBg],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.blue.o(0.28),
              blurRadius: size * 0.35,
              offset: Offset(0, size * 0.12),
            ),
          ],
        ),
        child: Center(child: AppLogo(size: size * 0.92)),
      );
}
