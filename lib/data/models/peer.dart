class Peer {
  const Peer({
    required this.id,
    required this.name,
    required this.ip,
    required this.port,
    required this.lastSeen,
  });

  final String id;
  final String name;
  final String ip;
  final int port;
  final DateTime lastSeen;

  Peer copyWith({String? name, String? ip, int? port, DateTime? lastSeen}) =>
      Peer(
        id: id,
        name: name ?? this.name,
        ip: ip ?? this.ip,
        port: port ?? this.port,
        lastSeen: lastSeen ?? this.lastSeen,
      );
}
