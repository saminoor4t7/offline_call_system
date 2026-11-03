import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/network_info_service.dart';
import '../../core/services/providers.dart';
import '../../data/models/peer.dart';
import '../../shared/widgets/common.dart';

class DiagnosticsScreen extends ConsumerStatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  ConsumerState<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends ConsumerState<DiagnosticsScreen> {
  bool _busy = false;

  Future<void> _restart() async {
    setState(() => _busy = true);
    await ref.read(discoveryServiceProvider).restart();
    await ref.read(signalingServiceProvider).stop();
    await ref.read(signalingServiceProvider).start();
    await ref.read(discoveryServiceProvider).refresh();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final net = ref.watch(networkProvider).value;
    final peers = ref.watch(peersProvider).value ?? const <Peer>[];
    final disc = ref.read(discoveryServiceProvider);
    final sig = ref.read(signalingServiceProvider);

    Widget row(String k, String v, {Color? color}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              width: 128,
              child: Text(k,
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14)),
            ),
            Expanded(
              child: Text(v,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: color)),
            ),
          ]),
        );

    String ok(bool b) => b ? 'Running' : 'Stopped';
    Color? c(bool b) => b ? AppColors.success : AppColors.error;

    return Scaffold(
      appBar: AppBar(title: const Text('Network diagnostics')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          AppCard(
            child: Column(children: [
              row(
                'Network',
                switch (net?.kind) {
                  NetworkKind.wifi => 'Wi-Fi',
                  NetworkKind.hotspot => 'Hotspot / local network',
                  _ => 'Not connected',
                },
                color: c(net?.isOnline ?? false),
              ),
              row(
                'Local address',
                (net == null || net.addresses.isEmpty)
                    ? '—'
                    : net.addresses
                        .map((a) => '${a.ip} (${a.interfaceName})')
                        .join('\n'),
              ),
              const Divider(),
              row('Discovery (UDP ${AppConstants.discoveryPort})',
                  ok(disc.isBound),
                  color: c(disc.isBound)),
              row('Signaling (TCP ${AppConstants.signalingPort})',
                  ok(sig.isListening),
                  color: c(sig.isListening)),
              if (disc.lastError != null)
                row('Discovery error', disc.lastError!, color: AppColors.error),
              if (sig.lastError != null)
                row('Signaling error', sig.lastError!, color: AppColors.error),
              const Divider(),
              row('Audio', 'WebRTC · no STUN/TURN (host candidates only)'),
            ]),
          ),
          SectionHeader('Devices seen (${peers.length})'),
          if (peers.isEmpty)
            AppCard(
              child: Text('No AirCall devices have been heard yet.',
                  style: TextStyle(color: cs.onSurfaceVariant)),
            )
          else
            AppCard(
              child: Column(children: [
                for (final p in peers) row(p.name, '${p.ip}:${p.port}'),
              ]),
            ),
          const SizedBox(height: 20),
          GradientButton(
            label: _busy ? 'Restarting…' : 'Restart network services',
            icon: Icons.restart_alt_rounded,
            onPressed: _busy ? null : _restart,
          ),
        ],
      ),
    );
  }
}
