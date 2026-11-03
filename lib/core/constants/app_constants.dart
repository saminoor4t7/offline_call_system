class AppConstants {
  static const appName = 'AirCall';
  static const tagline = 'Your Voice. Your Network.';
  static const version = '1.0.0';

  /// UDP port used to announce / find AirCall devices on the LAN.
  static const discoveryPort = 45454;

  /// TCP port every device listens on for call signaling.
  static const signalingPort = 45455;

  static const protocolVersion = 1;
  static const protocolTag = 'aircall';

  static const peerTimeout = Duration(seconds: 9);
  static const announceInterval = Duration(seconds: 2);
  static const ringTimeout = Duration(seconds: 45);
  static const handshakeTimeout = Duration(seconds: 8);
  static const maxNameLength = 24;
}
