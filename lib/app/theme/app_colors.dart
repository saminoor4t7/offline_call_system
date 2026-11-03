import 'package:flutter/material.dart';

class AppColors {
  static const navy = Color(0xFF101828);
  static const blue = Color(0xFF386BFF);
  static const cyan = Color(0xFF20D9D2);
  static const lightBg = Color(0xFFF7F9FC);
  static const darkBg = Color(0xFF0B1220);
  static const darkSurface = Color(0xFF131C2E);
  static const success = Color(0xFF20B981);
  static const error = Color(0xFFEF4444);
  static const warning = Color(0xFFF59E0B);

  static const brandGradient = LinearGradient(
    colors: [blue, cyan],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const heroGradient = LinearGradient(
    colors: [Color(0xFF1B2A55), Color(0xFF2A55E8), Color(0xFF1AA7C9)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const callGradient = LinearGradient(
    colors: [Color(0xFF0B1220), Color(0xFF101F44), Color(0xFF0D3A58)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
