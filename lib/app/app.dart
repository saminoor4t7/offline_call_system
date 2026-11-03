import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/providers.dart';
import '../features/calling/active_call_screen.dart';
import '../features/calling/call_controller.dart';
import '../features/calling/incoming_call_screen.dart';
import '../features/home/home_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/onboarding/splash_screen.dart';
import '../features/settings/settings_controller.dart';
import 'theme/app_theme.dart';

final navigatorKey = GlobalKey<NavigatorState>();

class AirCallApp extends ConsumerWidget {
  const AirCallApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(settingsProvider.select((s) => s.themeMode));
    return MaterialApp(
      title: 'AirCall',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      home: const RootGate(),
      builder: (context, child) => CallRouter(child: child ?? const SizedBox()),
    );
  }
}

/// Chooses splash → onboarding → home without navigation, so an incoming call
/// can never be interrupted by startup transitions.
class RootGate extends ConsumerStatefulWidget {
  const RootGate({super.key});

  @override
  ConsumerState<RootGate> createState() => _RootGateState();
}

class _RootGateState extends ConsumerState<RootGate>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _startServices());
  }

  Future<void> _startServices() async {
    ref.read(callProvider); // subscribes to incoming signaling
    await ref.read(signalingServiceProvider).start();
    await ref.read(discoveryServiceProvider).start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Sockets can be reclaimed by Android while in the background.
      ref.read(signalingServiceProvider).start();
      ref.read(discoveryServiceProvider).restart();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Re-announce when the network changes (Wi-Fi switch, hotspot on/off).
    ref.listen(networkProvider, (prev, next) {
      final a = prev?.value?.signature;
      final b = next.value?.signature;
      if (b != null && a != b) {
        ref.read(discoveryServiceProvider).restart();
      }
    });

    final splashDone = ref.watch(splashDoneProvider);
    final onboarded = ref.watch(settingsProvider.select((s) => s.onboardingDone));
    final Widget page = !splashDone
        ? const SplashScreen(key: ValueKey('splash'))
        : onboarded
            ? const HomeScreen(key: ValueKey('home'))
            : const OnboardingScreen(key: ValueKey('onboarding'));

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      switchInCurve: Curves.easeOut,
      child: page,
    );
  }
}

/// Opens / closes the call screens as the call state changes.
class CallRouter extends ConsumerStatefulWidget {
  const CallRouter({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<CallRouter> createState() => _CallRouterState();
}

class _CallRouterState extends ConsumerState<CallRouter> {
  String? _open; // 'incoming' | 'active'

  PageRoute<void> _route(Widget w) => PageRouteBuilder<void>(
        pageBuilder: (_, __, ___) => w,
        transitionDuration: const Duration(milliseconds: 320),
        transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
      );

  void _sync(CallPhase phase) {
    final nav = navigatorKey.currentState;
    if (nav == null) return;
    switch (phase) {
      case CallPhase.ringing:
        if (_open == null) {
          _open = 'incoming';
          nav.push(_route(const IncomingCallScreen()));
        }
      case CallPhase.calling:
        if (_open == null) {
          _open = 'active';
          nav.push(_route(const ActiveCallScreen()));
        }
      case CallPhase.connecting:
        if (_open == 'incoming') {
          _open = 'active';
          nav.pushReplacement(_route(const ActiveCallScreen()));
        } else if (_open == null) {
          _open = 'active';
          nav.push(_route(const ActiveCallScreen()));
        }
      case CallPhase.idle:
        if (_open != null) {
          _open = null;
          nav.popUntil((r) => r.isFirst);
        }
      case CallPhase.connected:
      case CallPhase.ended:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<CallState>(callProvider, (prev, next) => _sync(next.phase));
    return widget.child;
  }
}
