import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../core/utils/format.dart';

/// Gradient avatar with optional expanding pulse rings.
class PulsingAvatar extends StatefulWidget {
  const PulsingAvatar({
    super.key,
    required this.name,
    this.size = 120,
    this.pulsing = true,
  });
  final String name;
  final double size;
  final bool pulsing;

  @override
  State<PulsingAvatar> createState() => _PulsingAvatarState();
}

class _PulsingAvatarState extends State<PulsingAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  @override
  void initState() {
    super.initState();
    if (widget.pulsing) _c.repeat();
  }

  @override
  void didUpdateWidget(covariant PulsingAvatar old) {
    super.didUpdateWidget(old);
    if (widget.pulsing && !_c.isAnimating) _c.repeat();
    if (!widget.pulsing && _c.isAnimating) _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return SizedBox(
      width: s * 2,
      height: s * 2,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Stack(
          alignment: Alignment.center,
          children: [
            if (widget.pulsing)
              for (var i = 0; i < 3; i++) _ring((_c.value + i / 3) % 1.0, s),
            Container(
              width: s,
              height: s,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.brandGradient,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.cyan.o(0.35),
                    blurRadius: 40,
                    spreadRadius: 2,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                initialOf(widget.name),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: s * 0.42,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ring(double t, double s) {
    final d = s * (1 + 0.9 * t);
    return Container(
      width: d,
      height: d,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.cyan.o((1 - t) * 0.45), width: 2),
      ),
    );
  }
}

/// Small avatar for list rows.
class MiniAvatar extends StatelessWidget {
  const MiniAvatar({super.key, required this.name, this.size = 48});
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppColors.brandGradient,
        ),
        child: Text(
          initialOf(name),
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.42,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
}

/// Radar-style scanning animation for the discovery screen.
class RadarScanner extends StatefulWidget {
  const RadarScanner({
    super.key,
    required this.active,
    this.size = 240,
    this.icon = Icons.wifi_tethering_rounded,
  });
  final bool active;
  final double size;
  final IconData icon;

  @override
  State<RadarScanner> createState() => _RadarScannerState();
}

class _RadarScannerState extends State<RadarScanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) _c.repeat();
  }

  @override
  void didUpdateWidget(covariant RadarScanner old) {
    super.didUpdateWidget(old);
    if (widget.active && !_c.isAnimating) _c.repeat();
    if (!widget.active && _c.isAnimating) _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _c,
            builder: (context, _) => CustomPaint(
              size: Size.square(widget.size),
              painter: _RadarPainter(_c.value, widget.active),
            ),
          ),
          Container(
            width: widget.size * 0.28,
            height: widget.size * 0.28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.brandGradient,
              boxShadow: [
                BoxShadow(color: AppColors.blue.o(0.4), blurRadius: 24),
              ],
            ),
            child: Icon(widget.icon, color: Colors.white, size: widget.size * 0.13),
          ),
        ],
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter(this.t, this.active);
  final double t;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = AppColors.blue.o(0.18);
    for (var i = 1; i <= 3; i++) {
      canvas.drawCircle(c, r * i / 3, ring);
    }
    if (!active) return;
    for (var i = 0; i < 2; i++) {
      final p = (t + i * 0.5) % 1.0;
      canvas.drawCircle(
        c,
        r * p,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = AppColors.cyan.o((1 - p) * 0.55),
      );
    }
    final sweep = SweepGradient(
      colors: [AppColors.cyan.o(0), AppColors.cyan.o(0.35)],
      transform: GradientRotation(t * 2 * math.pi),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()..shader = sweep.createShader(Rect.fromCircle(center: c, radius: r)),
    );
  }

  @override
  bool shouldRepaint(covariant _RadarPainter old) =>
      old.t != t || old.active != active;
}
