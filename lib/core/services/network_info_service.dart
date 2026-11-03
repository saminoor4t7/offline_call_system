import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';

class LocalAddress {
  const LocalAddress(this.interfaceName, this.ip);
  final String interfaceName;
  final String ip;

  /// Assumes a /24 network (typical for routers and Android hotspots).
  String get broadcast {
    final p = ip.split('.');
    return '${p[0]}.${p[1]}.${p[2]}.255';
  }

  String get subnetPrefix {
    final p = ip.split('.');
    return '${p[0]}.${p[1]}.${p[2]}';
  }
}

enum NetworkKind { offline, wifi, hotspot }

class LocalNetwork {
  const LocalNetwork(this.kind, this.addresses);
  final NetworkKind kind;
  final List<LocalAddress> addresses;

  bool get isOnline => kind != NetworkKind.offline;
  String get primaryIp => addresses.isEmpty ? '—' : addresses.first.ip;
  String get signature =>
      '${kind.name}|${addresses.map((a) => '${a.interfaceName}:${a.ip}').join(',')}';
}

class NetworkInfoService {
  static const _ignoredPrefixes = [
    'rmnet', 'ccmni', 'tun', 'dummy', 'v4-', 'clat', 'lo', 'p2p-dev',
  ];

  static bool _isPrivate(String ip) {
    final p = ip.split('.').map(int.tryParse).toList();
    if (p.length != 4 || p.contains(null)) return false;
    final a = p[0]!, b = p[1]!;
    return a == 10 || (a == 172 && b >= 16 && b <= 31) || (a == 192 && b == 168);
  }

  static Future<List<LocalAddress>> localAddresses() async {
    try {
      final ifaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
        includeLinkLocal: false,
      );
      final out = <LocalAddress>[];
      for (final i in ifaces) {
        final n = i.name.toLowerCase();
        if (_ignoredPrefixes.any(n.startsWith)) continue;
        for (final a in i.addresses) {
          if (_isPrivate(a.address)) out.add(LocalAddress(i.name, a.address));
        }
      }
      return out;
    } catch (_) {
      return [];
    }
  }

  static Future<LocalNetwork> snapshot() async {
    final addrs = await localAddresses();
    if (addrs.isEmpty) return const LocalNetwork(NetworkKind.offline, []);
    var onWifi = false;
    try {
      final c = await Connectivity().checkConnectivity();
      onWifi = c.contains(ConnectivityResult.wifi);
    } catch (_) {}
    // A private LAN address without a Wi-Fi connection means this phone is
    // most likely the hotspot host (Android reports no Wi-Fi in that case).
    return LocalNetwork(onWifi ? NetworkKind.wifi : NetworkKind.hotspot, addrs);
  }
}
