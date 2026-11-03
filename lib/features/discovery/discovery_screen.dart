import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../core/services/providers.dart';
import '../../data/models/peer.dart';
import '../../shared/widgets/animated_widgets.dart';
import '../../shared/widgets/common.dart';
import '../home/home_screen.dart';
import '../home/peer_tile.dart';

class DiscoveryScreen extends ConsumerStatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  ConsumerState<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends ConsumerState<DiscoveryScreen> {
  bool _scanning = false;
  Timer? _stop;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scan());
  }

  @override
  void dispose() {
    _stop?.cancel();
    super.dispose();
  }

  Future<void> _scan() async {
    setState(() => _scanning = true);
    _stop?.cancel();
    _stop = Timer(const Duration(seconds: 6), () {
      if (mounted) setState(() => _scanning = false);
    });
    await ref.read(discoveryServiceProvider).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final net = ref.watch(networkProvider).value;
    final peers = ref.watch(peersProvider).value ?? const <Peer>[];
    final discovery = ref.read(discoveryServiceProvider);
    final offline = net != null && !net.isOnline;
    final error = discovery.lastError;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover devices'),
        actions: [
          IconButton(
            tooltip: 'Scan again',
            onPressed: _scan,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Center(child: RadarScanner(active: _scanning && !offline)),
          const SizedBox(height: 8),
          Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Text(
                offline
                    ? 'No network'
                    : _scanning
                        ? 'Scanning your network…'
                        : peers.isEmpty
                            ? 'No devices found'
                            : '${peers.length} device${peers.length == 1 ? '' : 's'} found',
                key: ValueKey('$offline$_scanning${peers.length}'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              'Both phones need AirCall open on the same Wi-Fi or hotspot.',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13.5),
            ),
          ),
          const SizedBox(height: 24),
          if (offline)
            AppCard(
              child: EmptyState(
                icon: Icons.wifi_off_rounded,
                color: AppColors.error,
                title: 'Not connected to a local network',
                message:
                    'Join a Wi-Fi network, or turn on your phone\'s hotspot and connect the other phone to it.',
                action: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size(160, 46)),
                  onPressed: _scan,
                  child: const Text('Try again'),
                ),
              ),
            )
          else if (error != null)
            AppCard(
              child: EmptyState(
                icon: Icons.error_outline_rounded,
                color: AppColors.error,
                title: 'Discovery problem',
                message: error,
                action: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size(160, 46)),
                  onPressed: () async {
                    await ref.read(discoveryServiceProvider).restart();
                    _scan();
                  },
                  child: const Text('Restart discovery'),
                ),
              ),
            )
          else if (peers.isEmpty && !_scanning)
            AppCard(
              child: EmptyState(
                icon: Icons.search_off_rounded,
                title: 'No devices found',
                message:
                    'Make sure AirCall is open on the other phone and that it is on the same network. Some routers block device-to-device traffic (client isolation) – a phone hotspot always works.',
                action: GradientButton(label: 'Scan again', onPressed: _scan),
              ),
            )
          else
            for (final p in peers)
              PeerTile(
                peer: p,
                onCall: () => placeCall(context, ref, p),
                onEdit: () => editPeerName(context, ref, p),
              ),
        ],
      ),
    );
  }
}
