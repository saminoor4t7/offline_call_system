import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/permissions/permission_service.dart';
import '../../core/services/network_info_service.dart';
import '../../core/services/providers.dart';
import '../../core/utils/format.dart';
import '../../data/models/peer.dart';
import '../../shared/widgets/app_logo.dart';
import '../../shared/widgets/common.dart';
import '../calling/call_controller.dart';
import '../discovery/discovery_screen.dart';
import '../history/call_tile.dart';
import '../history/history_controller.dart';
import '../history/history_screen.dart';
import '../settings/settings_controller.dart';
import '../settings/settings_screen.dart';
import 'peer_tile.dart';

Future<void> placeCall(BuildContext context, WidgetRef ref, Peer peer) async {
  final err = await ref.read(callProvider.notifier).startCall(peer);
  if (err != null && context.mounted) {
    final permanentlyDenied =
        await PermissionService.microphonePermanentlyDenied();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(err),
        action: permanentlyDenied
            ? SnackBarAction(
                label: 'Settings',
                onPressed: PermissionService.openAppSettings,
              )
            : null,
      ));
  }
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final net = ref.watch(networkProvider).value;
    final peers = ref.watch(peersProvider).value ?? const <Peer>[];
    final history = ref.watch(historyProvider);
    final name = ref.watch(settingsProvider.select((s) => s.deviceName));

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Row(children: [
              const AppLogoBadge(size: 46),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(AppConstants.appName,
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5)),
                    Text(AppConstants.tagline,
                        style: TextStyle(
                            fontSize: 12.5, color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'Settings',
                onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const SettingsScreen())),
                icon: const Icon(Icons.settings_rounded),
              ),
            ]),
            const SizedBox(height: 20),
            _NetworkCard(net: net, peerCount: peers.length, deviceName: name),
            const SizedBox(height: 16),
            GradientButton(
              label: 'Discover devices',
              icon: Icons.radar_rounded,
              onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const DiscoveryScreen())),
            ),
            SectionHeader(
              'Nearby devices',
              trailing: peers.isEmpty
                  ? null
                  : StatusPill(
                      label: '${peers.length} online',
                      color: AppColors.success),
            ),
            if (peers.isEmpty)
              AppCard(
                child: EmptyState(
                  icon: Icons.devices_other_rounded,
                  title: 'No devices nearby yet',
                  message: net != null && net.isOnline
                      ? 'Open AirCall on another phone connected to the same Wi-Fi or hotspot.'
                      : 'Connect to a Wi-Fi network or turn on your hotspot to find devices.',
                ),
              )
            else
              for (final p in peers)
                PeerTile(
                  peer: p,
                  onCall: () => placeCall(context, ref, p),
                  onEdit: () => editPeerName(context, ref, p),
                ),
            SectionHeader(
              'Recent calls',
              trailing: history.isEmpty
                  ? null
                  : TextButton(
                      onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                              builder: (_) => const HistoryScreen())),
                      child: const Text('See all'),
                    ),
            ),
            if (history.isEmpty)
              AppCard(
                child: Row(children: [
                  Icon(Icons.history_rounded, color: cs.onSurfaceVariant),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Your calls will appear here.',
                        style: TextStyle(color: cs.onSurfaceVariant)),
                  ),
                ]),
              )
            else
              for (final r in history.take(3)) CallTile(record: r, compact: true),
          ],
        ),
      ),
    );
  }
}

class _NetworkCard extends StatelessWidget {
  const _NetworkCard({
    required this.net,
    required this.peerCount,
    required this.deviceName,
  });
  final LocalNetwork? net;
  final int peerCount;
  final String deviceName;

  @override
  Widget build(BuildContext context) {
    final kind = net?.kind ?? NetworkKind.offline;
    final (icon, title) = switch (kind) {
      NetworkKind.wifi => (Icons.wifi_rounded, 'Connected to Wi-Fi'),
      NetworkKind.hotspot => (Icons.wifi_tethering_rounded, 'Hotspot network'),
      NetworkKind.offline => (Icons.wifi_off_rounded, 'No local network'),
    };
    final online = kind != NetworkKind.offline;
    return AppCard(
      gradient: online
          ? AppColors.heroGradient
          : const LinearGradient(
              colors: [Color(0xFF3B4457), Color(0xFF232B3B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white.o(0.16),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(
                    online ? 'Local IP  ${net!.primaryIp}' : 'Internet not required',
                    style: TextStyle(color: Colors.white.o(0.75), fontSize: 13),
                  ),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 18),
          Row(children: [
            _chip(Icons.phone_android_rounded, deviceName),
            const SizedBox(width: 8),
            _chip(Icons.people_alt_rounded,
                '$peerCount nearby'),
          ]),
        ],
      ),
    );
  }

  Widget _chip(IconData i, String t) => Flexible(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.o(0.14),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(i, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Flexible(
              child: Text(t,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
      );
}
