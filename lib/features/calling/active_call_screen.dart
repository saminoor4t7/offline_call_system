import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../core/utils/format.dart';
import '../../shared/widgets/animated_widgets.dart';
import '../../shared/widgets/common.dart';
import 'call_controller.dart';
import 'call_widgets.dart';

class ActiveCallScreen extends ConsumerWidget {
  const ActiveCallScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final call = ref.watch(callProvider);
    final ctl = ref.read(callProvider.notifier);
    final connected = call.phase == CallPhase.connected;
    final ended = call.phase == CallPhase.ended;

    final status = switch (call.phase) {
      CallPhase.connected => formatDuration(call.seconds),
      CallPhase.ended => call.message,
      _ => call.message.isEmpty ? 'Connecting…' : call.message,
    };
    final qualityLabel = switch (call.quality) {
      3 => 'Excellent',
      2 => 'Good',
      1 => 'Poor',
      _ => 'Checking…',
    };

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          decoration: const BoxDecoration(gradient: AppColors.callGradient),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxHeight < 680;
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: compact ? 16 : 28,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(children: [
                            const CallChip(
                              icon: Icons.lock_rounded,
                              label: 'Local network call',
                            ),
                            SizedBox(height: compact ? 8 : 14),
                            AnimatedOpacity(
                              opacity: connected ? 1 : 0,
                              duration: const Duration(milliseconds: 300),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SignalBars(level: call.quality),
                                  const SizedBox(width: 8),
                                  Text(
                                    qualityLabel,
                                    style: TextStyle(
                                      color: Colors.white.o(0.8),
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ]),
                          Column(children: [
                            PulsingAvatar(
                              name: call.peerName,
                              size: compact ? 104 : 132,
                              pulsing:
                                  connected || call.phase == CallPhase.calling,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              call.peerName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: compact ? 27 : 32,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.6,
                              ),
                            ),
                            SizedBox(height: compact ? 4 : 8),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 220),
                              child: Text(
                                status,
                                key: ValueKey(status),
                                style: TextStyle(
                                  color: connected
                                      ? AppColors.cyan
                                      : Colors.white.o(0.75),
                                  fontSize: connected ? 22 : 17,
                                  fontWeight: FontWeight.w600,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ),
                            if (connected &&
                                call.message == 'Reconnecting…')
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  'Reconnecting…',
                                  style: TextStyle(
                                    color: AppColors.warning.o(0.95),
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                          ]),
                          Column(children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                ToggleCallButton(
                                  icon: call.muted
                                      ? Icons.mic_off_rounded
                                      : Icons.mic_rounded,
                                  label: call.muted ? 'Unmute' : 'Mute',
                                  active: call.muted,
                                  onTap: ended ? () {} : ctl.toggleMute,
                                ),
                                ToggleCallButton(
                                  icon: call.speaker
                                      ? Icons.volume_up_rounded
                                      : Icons.volume_down_rounded,
                                  label: 'Speaker',
                                  active: call.speaker,
                                  onTap: ended ? () {} : ctl.toggleSpeaker,
                                ),
                              ],
                            ),
                            SizedBox(height: compact ? 18 : 36),
                            RoundCallButton(
                              icon: Icons.call_end_rounded,
                              label: ended ? 'Call ended' : 'End call',
                              color: AppColors.error,
                              size: compact ? 68 : 78,
                              onTap: ended ? () {} : ctl.hangup,
                            ),
                          ]),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
