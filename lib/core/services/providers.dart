import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/peer.dart';
import '../../features/settings/settings_controller.dart';
import 'discovery_service.dart';
import 'network_info_service.dart';
import 'signaling_service.dart';

final networkProvider = StreamProvider<LocalNetwork>((ref) {
  Stream<LocalNetwork> gen() async* {
    yield await NetworkInfoService.snapshot();
    yield* Stream<void>.periodic(const Duration(seconds: 3))
        .asyncMap((_) => NetworkInfoService.snapshot());
  }

  return gen().distinct((a, b) => a.signature == b.signature);
});

final discoveryServiceProvider = Provider<DiscoveryService>((ref) {
  final settings = ref.read(settingsProvider);
  final service = DiscoveryService(
    deviceId: settings.deviceId,
    nameGetter: () => ref.read(settingsProvider).deviceName,
  );
  ref.onDispose(service.dispose);
  return service;
});

final peersProvider = StreamProvider<List<Peer>>((ref) async* {
  final d = ref.watch(discoveryServiceProvider);
  final aliases = ref.watch(peerAliasesProvider);
  List<Peer> withAliases(List<Peer> peers) => peers
      .map((peer) => peer.copyWith(name: aliases[peer.ip] ?? peer.name))
      .toList(growable: false);
  yield withAliases(d.peers);
  yield* d.stream.map(withAliases);
});

final signalingServiceProvider = Provider<SignalingService>((ref) {
  final s = SignalingService();
  ref.onDispose(s.stop);
  return s;
});
