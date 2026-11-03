import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../data/models/peer.dart';
import '../constants/app_constants.dart';
import '../utils/log.dart';
import 'network_info_service.dart';

/// Finds other AirCall devices on the local network.
///
/// Every device sends a small UDP "announce" packet to the subnet broadcast
/// address every 2 seconds and listens on the same port. A device that hears a
/// new peer answers it directly (unicast), so discovery works even when a
/// router filters one direction of broadcast traffic. A manual refresh also
/// probes every address of the local /24 subnet.
class DiscoveryService {
  DiscoveryService({
    required this.deviceId,
    required this.nameGetter,
    this.signalingPort = AppConstants.signalingPort,
  });

  final String deviceId;
  final String Function() nameGetter;
  final int signalingPort;

  RawDatagramSocket? _socket;
  Timer? _announceTimer;
  Timer? _pruneTimer;
  Timer? _rebindTimer;
  bool _running = false;
  String? lastError;

  final Map<String, Peer> _peers = {};
  final _controller = StreamController<List<Peer>>.broadcast();

  Stream<List<Peer>> get stream => _controller.stream;
  List<Peer> get peers {
    final l = _peers.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return l;
  }

  bool get isBound => _socket != null;
  bool get isRunning => _running;

  Future<void> start() async {
    if (_running) return;
    _running = true;
    await _bind();
    _announceTimer =
        Timer.periodic(AppConstants.announceInterval, (_) => _announce());
    _pruneTimer = Timer.periodic(const Duration(seconds: 2), (_) => _prune());
    _announce();
  }

  Future<void> stop() async {
    _running = false;
    _announceTimer?.cancel();
    _pruneTimer?.cancel();
    _rebindTimer?.cancel();
    _socket?.close();
    _socket = null;
    _peers.clear();
    _emit();
  }

  Future<void> restart() async {
    await stop();
    await start();
  }

  void dispose() {
    stop();
    _controller.close();
  }

  Future<void> _bind() async {
    try {
      final s = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        AppConstants.discoveryPort,
        reuseAddress: true,
      );
      s.broadcastEnabled = true;
      s.listen(
        (e) {
          if (e == RawSocketEvent.read) {
            Datagram? d;
            while ((d = s.receive()) != null) {
              _handle(d!);
            }
          }
        },
        onError: (Object e) {
          lastError = '$e';
          loge('discovery', e);
          _scheduleRebind();
        },
        onDone: _scheduleRebind,
      );
      _socket = s;
      lastError = null;
      logd('discovery', 'listening on UDP ${AppConstants.discoveryPort}');
    } catch (e, st) {
      lastError = 'Could not open discovery port: $e';
      loge('discovery', e, st);
      _scheduleRebind();
    }
  }

  void _scheduleRebind() {
    if (!_running) return;
    _socket = null;
    _rebindTimer?.cancel();
    _rebindTimer = Timer(const Duration(seconds: 2), () {
      if (_running && _socket == null) _bind();
    });
  }

  List<int> _packet(String type) => utf8.encode(jsonEncode({
        'app': AppConstants.protocolTag,
        'v': AppConstants.protocolVersion,
        't': type,
        'id': deviceId,
        'name': nameGetter(),
        'port': signalingPort,
      }));

  Future<void> _announce() async {
    final s = _socket;
    if (s == null) return;
    final data = _packet('announce');
    final targets = <String>{'255.255.255.255'};
    for (final a in await NetworkInfoService.localAddresses()) {
      targets.add(a.broadcast);
    }
    for (final t in targets) {
      try {
        s.send(data, InternetAddress(t), AppConstants.discoveryPort);
      } catch (_) {/* network unreachable – ignore */}
    }
  }

  /// Announce now and probe every address of the local /24 networks.
  Future<void> refresh() async {
    if (_socket == null) await _bind();
    await _announce();
    final data = _packet('announce');
    final addrs = await NetworkInfoService.localAddresses();
    var sent = 0;
    for (final a in addrs) {
      for (var i = 1; i < 255; i++) {
        final ip = '${a.subnetPrefix}.$i';
        if (ip == a.ip) continue;
        try {
          _socket?.send(data, InternetAddress(ip), AppConstants.discoveryPort);
        } catch (_) {}
        if (++sent % 40 == 0) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      }
    }
  }

  void _handle(Datagram d) {
    if (d.data.isEmpty || d.data.length > 1024) return;
    Map<String, dynamic> m;
    try {
      final decoded = jsonDecode(utf8.decode(d.data));
      if (decoded is! Map<String, dynamic>) return;
      m = decoded;
    } catch (_) {
      return;
    }
    if (m['app'] != AppConstants.protocolTag ||
        m['v'] != AppConstants.protocolVersion) {
      return;
    }
    final id = m['id'];
    final name = m['name'];
    final port = m['port'];
    final type = m['t'];
    if (id is! String || id.isEmpty || id.length > 64) return;
    if (name is! String || name.trim().isEmpty || name.length > 40) return;
    if (port is! int || port < 1024 || port > 65535) return;
    if (id == deviceId) return;

    final ip = d.address.address;
    final existing = _peers[id];
    final isNew = existing == null;
    final changed = isNew ||
        existing.name != name ||
        existing.ip != ip ||
        existing.port != port;
    _peers[id] = Peer(
      id: id,
      name: name.trim(),
      ip: ip,
      port: port,
      lastSeen: DateTime.now(),
    );
    if (changed) _emit();

    // Answer newcomers directly so they find us immediately.
    if (type == 'announce' && isNew) {
      try {
        _socket?.send(_packet('reply'), d.address, AppConstants.discoveryPort);
      } catch (_) {}
    }
  }

  void _prune() {
    final cutoff = DateTime.now().subtract(AppConstants.peerTimeout);
    final before = _peers.length;
    _peers.removeWhere((_, p) => p.lastSeen.isBefore(cutoff));
    if (_peers.length != before) _emit();
  }

  void _emit() {
    if (!_controller.isClosed) _controller.add(peers);
  }
}
