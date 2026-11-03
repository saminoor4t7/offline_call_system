import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../constants/app_constants.dart';
import '../utils/log.dart';

/// One TCP connection carrying newline-delimited JSON messages.
class SignalingChannel {
  SignalingChannel(this._socket) : remoteIp = _socket.remoteAddress.address {
    try {
      _socket.setOption(SocketOption.tcpNoDelay, true);
    } catch (_) {}
    _sub = _socket.listen(
      _onData,
      onError: (Object e) => close(),
      onDone: close,
      cancelOnError: true,
    );
  }

  static const _maxLine = 64 * 1024;

  final Socket _socket;
  final String remoteIp;
  late final StreamSubscription<List<int>> _sub;
  final _messages = StreamController<Map<String, dynamic>>();
  final List<int> _buf = [];
  bool _closed = false;

  bool get isClosed => _closed;

  /// Single-subscription stream; messages arriving before the first listener
  /// are buffered.
  Stream<Map<String, dynamic>> get messages => _messages.stream;

  void _onData(List<int> chunk) {
    _buf.addAll(chunk);
    while (true) {
      final i = _buf.indexOf(10);
      if (i < 0) break;
      final line = _buf.sublist(0, i);
      _buf.removeRange(0, i + 1);
      if (line.isEmpty) continue;
      try {
        final decoded = jsonDecode(utf8.decode(line));
        if (decoded is Map<String, dynamic> && !_messages.isClosed) {
          _messages.add(decoded);
        }
      } catch (_) {
        logd('signaling', 'ignored malformed message from $remoteIp');
      }
    }
    if (_buf.length > _maxLine) {
      logd('signaling', 'oversized message from $remoteIp – closing');
      close();
    }
  }

  void send(Map<String, dynamic> message) {
    if (_closed) return;
    try {
      _socket.add(utf8.encode('${jsonEncode(message)}\n'));
    } catch (e) {
      loge('signaling', e);
      close();
    }
  }

  void close() {
    if (_closed) return;
    _closed = true;
    _sub.cancel();
    try {
      _socket.destroy();
    } catch (_) {}
    if (!_messages.isClosed) _messages.close();
  }
}

/// Every device runs a small TCP server; whoever starts a call connects to the
/// callee's server. That makes any device a temporary signaling host.
class SignalingService {
  ServerSocket? _server;
  final _incoming = StreamController<SignalingChannel>.broadcast();
  String? lastError;

  Stream<SignalingChannel> get incoming => _incoming.stream;
  bool get isListening => _server != null;

  Future<void> start() async {
    if (_server != null) return;
    try {
      final s = await ServerSocket.bind(
        InternetAddress.anyIPv4,
        AppConstants.signalingPort,
        shared: true,
      );
      s.listen(
        (socket) => _incoming.add(SignalingChannel(socket)),
        onError: (Object e) => loge('signaling', e),
        onDone: () => _server = null,
      );
      _server = s;
      lastError = null;
      logd('signaling', 'listening on TCP ${AppConstants.signalingPort}');
    } catch (e, st) {
      lastError = '$e';
      loge('signaling', e, st);
    }
  }

  Future<SignalingChannel> connect(String ip, int port) async {
    final socket =
        await Socket.connect(ip, port, timeout: const Duration(seconds: 4));
    return SignalingChannel(socket);
  }

  Future<void> stop() async {
    await _server?.close();
    _server = null;
  }
}
