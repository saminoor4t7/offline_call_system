import 'package:flutter/material.dart';

extension ColorX on Color {
  /// Returns this colour at the given opacity (0..1).
  Color o(double opacity) =>
      withAlpha((opacity.clamp(0.0, 1.0) * 255).round());
}

String two(int n) => n.toString().padLeft(2, '0');

String formatDuration(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  return h > 0 ? '${two(h)}:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}

String formatWhen(DateTime t) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(t.year, t.month, t.day);
  final time = '${two(t.hour)}:${two(t.minute)}';
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Today, $time';
  if (diff == 1) return 'Yesterday, $time';
  return '${two(t.day)}/${two(t.month)}/${t.year}, $time';
}

String initialOf(String name) {
  final n = name.trim();
  return n.isEmpty ? '?' : n.substring(0, 1).toUpperCase();
}
