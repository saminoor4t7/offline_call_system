import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/format.dart';
import '../../shared/widgets/app_logo.dart';
import '../settings/settings_controller.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..forward();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 2300), () {
      if (mounted) ref.read(splashDoneProvider.notifier).finish();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logoScale = CurvedAnimation(
      parent: _c,
      curve: const Interval(0, 0.6, curve: Curves.easeOutBack),
    );
    final textFade = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.45, 1, curve: Curves.easeOut),
    );
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.callGradient),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              top: -120,
              right: -100,
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.blue.o(0.14),
                ),
              ),
            ),
            Positioned(
              bottom: -140,
              left: -110,
              child: Container(
                width: 340,
                height: 340,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.cyan.o(0.10),
                ),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScaleTransition(
                  scale: Tween(begin: 0.6, end: 1.0).animate(logoScale),
                  child: FadeTransition(
                    opacity: logoScale.drive(Tween(begin: 0.0, end: 1.0)),
                    child: const AppLogoBadge(size: 124),
                  ),
                ),
                const SizedBox(height: 28),
                FadeTransition(
                  opacity: textFade,
                  child: SlideTransition(
                    position: textFade.drive(
                      Tween(begin: const Offset(0, 0.25), end: Offset.zero),
                    ),
                    child: Column(children: [
                      const Text(
                        AppConstants.appName,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 38,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        AppConstants.tagline,
                        style: TextStyle(
                          color: Colors.white.o(0.7),
                          fontSize: 15,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ]),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
