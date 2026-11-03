import 'package:flutter/material.dart';
import '../../core/utils/format.dart';

class CallChip extends StatelessWidget {
  const CallChip({super.key, required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.o(0.10),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: Colors.white.o(0.85)),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: Colors.white.o(0.85),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600)),
        ]),
      );
}

/// Large round button with a caption (accept / decline / end).
class RoundCallButton extends StatefulWidget {
  const RoundCallButton({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.pulse = false,
    this.size = 74,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool pulse;
  final double size;

  @override
  State<RoundCallButton> createState() => _RoundCallButtonState();
}

class _RoundCallButtonState extends State<RoundCallButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
    lowerBound: 0.0,
    upperBound: 1.0,
  );

  @override
  void initState() {
    super.initState();
    if (widget.pulse) _c.repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      AnimatedBuilder(
        animation: _c,
        builder: (context, child) => Transform.scale(
          scale: widget.pulse ? 1 + 0.07 * _c.value : 1,
          child: child,
        ),
        child: Material(
          color: widget.color,
          shape: const CircleBorder(),
          elevation: 6,
          shadowColor: widget.color.o(0.6),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: widget.onTap,
            child: SizedBox(
              width: widget.size,
              height: widget.size,
              child: Icon(widget.icon, color: Colors.white, size: widget.size * 0.42),
            ),
          ),
        ),
      ),
      const SizedBox(height: 10),
      Text(widget.label,
          style: TextStyle(color: Colors.white.o(0.85), fontSize: 14)),
    ]);
  }
}

/// Secondary toggle (mute / speaker).
class ToggleCallButton extends StatelessWidget {
  const ToggleCallButton({
    super.key,
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 66,
        height: 66,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active ? Colors.white : Colors.white.o(0.12),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Icon(icon,
                size: 28,
                color: active ? const Color(0xFF0B1220) : Colors.white),
          ),
        ),
      ),
      const SizedBox(height: 8),
      Text(label,
          style: TextStyle(color: Colors.white.o(0.8), fontSize: 13)),
    ]);
  }
}
