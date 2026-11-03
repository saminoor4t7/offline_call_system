import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../core/permissions/permission_service.dart';
import '../../core/utils/format.dart';
import '../../shared/widgets/animated_widgets.dart';
import 'call_controller.dart';
import 'call_widgets.dart';

class IncomingCallScreen extends ConsumerStatefulWidget {
  const IncomingCallScreen({super.key});

  @override
  ConsumerState<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends ConsumerState<IncomingCallScreen> {
  Timer? _buzz;

  @override
  void initState() {
    super.initState();
    HapticFeedback.heavyImpact();
    _buzz = Timer.periodic(const Duration(milliseconds: 1400), (_) {
      if (ref.read(callProvider).phase == CallPhase.ringing) {
        HapticFeedback.heavyImpact();
      }
    });
  }

  @override
  void dispose() {
    _buzz?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final call = ref.watch(callProvider);
    final ringing = call.phase == CallPhase.ringing;
    final ctl = ref.read(callProvider.notifier);

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          decoration: const BoxDecoration(gradient: AppColors.callGradient),
          child: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 36),
                const CallChip(icon: Icons.lock_rounded, label: 'Local network call'),
                const SizedBox(height: 10),
                Text(
                  ringing ? 'Incoming call' : call.message,
                  style: TextStyle(color: Colors.white.o(0.75), fontSize: 16),
                ),
                const Spacer(),
                PulsingAvatar(name: call.peerName, size: 128, pulsing: ringing),
                const SizedBox(height: 4),
                Text(
                  call.peerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 6),
                Text(call.peerIp,
                    style: TextStyle(color: Colors.white.o(0.55), fontSize: 14)),
                const Spacer(),
                if (ringing)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(48, 0, 48, 56),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        RoundCallButton(
                          icon: Icons.call_end_rounded,
                          label: 'Decline',
                          color: AppColors.error,
                          onTap: ctl.reject,
                        ),
                        RoundCallButton(
                          icon: Icons.call_rounded,
                          label: 'Accept',
                          color: AppColors.success,
                          onTap: () async {
                            final accepted = await ctl.accept();
                            if (!accepted && context.mounted) {
                              final permanentlyDenied = await PermissionService
                                  .microphonePermanentlyDenied();
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(permanentlyDenied
                                      ? 'Microphone access is blocked. Allow it in Settings to answer calls.'
                                      : 'Microphone access is required to answer calls.'),
                                  action: permanentlyDenied
                                      ? SnackBarAction(
                                          label: 'Settings',
                                          onPressed: PermissionService.openAppSettings,
                                        )
                                      : null,
                                ),
                              );
                            }
                          },
                          pulse: true,
                        ),
                      ],
                    ),
                  )
                else
                  const SizedBox(height: 120),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
