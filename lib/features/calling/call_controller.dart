import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../core/constants/app_constants.dart';
import '../../core/permissions/permission_service.dart';
import '../../core/services/providers.dart';
import '../../core/services/signaling_service.dart';
import '../../core/services/webrtc_service.dart';
import '../../core/utils/log.dart';
import '../../data/models/call_record.dart';
import '../../data/models/peer.dart';
import '../history/history_controller.dart';
import '../settings/settings_controller.dart';

enum CallPhase { idle, calling, ringing, connecting, connected, ended }

class CallState {
  const CallState({
    this.phase = CallPhase.idle,
    this.peerName = '',
    this.peerIp = '',
    this.incoming = false,
    this.muted = false,
    this.speaker = false,
    this.seconds = 0,
    this.quality = 0, // 0 = unknown, 1 poor, 2 good, 3 excellent
    this.message = '',
  });

  final CallPhase phase;
  final String peerName;
  final String peerIp;
  final bool incoming;
  final bool muted;
  final bool speaker;
  final int seconds;
  final int quality;
  final String message;

  CallState copyWith({
    CallPhase? phase,
    String? peerName,
    String? peerIp,
    bool? incoming,
    bool? muted,
    bool? speaker,
    int? seconds,
    int? quality,
    String? message,
  }) =>
      CallState(
        phase: phase ?? this.phase,
        peerName: peerName ?? this.peerName,
        peerIp: peerIp ?? this.peerIp,
        incoming: incoming ?? this.incoming,
        muted: muted ?? this.muted,
        speaker: speaker ?? this.speaker,
        seconds: seconds ?? this.seconds,
        quality: quality ?? this.quality,
        message: message ?? this.message,
      );
}

class CallController extends Notifier<CallState> {
  SignalingChannel? _ch;
  WebRtcService? _rtc;
  StreamSubscription<Map<String, dynamic>>? _msgSub;
  Timer? _handshakeTimer;
  Timer? _ringTimer;
  Timer? _tick;
  Timer? _statsTimer;
  Timer? _dropTimer;

  String _peerId = '';
  DateTime _startedAt = DateTime.now();
  DateTime? _connectedAt;
  bool _alive = true;
  bool _ending = false;

  bool get _busy => _ch != null || state.phase != CallPhase.idle;

  @override
  CallState build() {
    _alive = true;
    final sub = ref
        .read(signalingServiceProvider)
        .incoming
        .listen(_onIncomingChannel);
    ref.onDispose(() {
      _alive = false;
      sub.cancel();
      _cancelTimers();
      _msgSub?.cancel();
      _ch?.close();
      _rtc?.dispose();
    });
    return const CallState();
  }

  void _set(CallState s) {
    if (_alive) state = s;
  }

  // ───────────────────────── outgoing ─────────────────────────

  /// Returns an error message, or null when the call was started.
  Future<String?> startCall(Peer peer) async {
    if (_busy) return 'Another call is in progress.';
    if (!await PermissionService.ensureMicrophone()) {
      return 'Microphone permission is required to make calls.';
    }
    final settings = ref.read(settingsProvider);
    _peerId = peer.id;
    _startedAt = DateTime.now();
    _connectedAt = null;
    _ending = false;
    _set(CallState(
      phase: CallPhase.calling,
      peerName: peer.name,
      peerIp: peer.ip,
      incoming: false,
      message: 'Calling…',
    ));

    try {
      final ch =
          await ref.read(signalingServiceProvider).connect(peer.ip, peer.port);
      _attach(ch);
      ch.send({
        'type': 'invite',
        'v': AppConstants.protocolVersion,
        'id': settings.deviceId,
        'name': settings.deviceName,
      });
      _ringTimer = Timer(AppConstants.ringTimeout, () {
        if (state.phase == CallPhase.calling) {
          _ch?.send({'type': 'hangup'});
          _end('No answer');
        }
      });
    } catch (e) {
      loge('call', e);
      _end('Could not reach ${peer.name}');
    }
    return null;
  }

  // ───────────────────────── incoming ─────────────────────────

  void _onIncomingChannel(SignalingChannel ch) {
    if (_busy) {
      ch.send({'type': 'busy'});
      Timer(const Duration(milliseconds: 300), ch.close);
      return;
    }
    _attach(ch);
    // The remote must identify itself quickly or the connection is dropped.
    _handshakeTimer = Timer(AppConstants.handshakeTimeout, () {
      if (state.phase == CallPhase.idle) _teardownChannel();
    });
  }

  void _handleInvite(SignalingChannel ch, Map<String, dynamic> m) {
    final id = m['id'];
    final name = m['name'];
    if (state.phase != CallPhase.idle ||
        id is! String ||
        id.isEmpty ||
        id.length > 64 ||
        name is! String ||
        name.trim().isEmpty ||
        name.length > 40 ||
        m['v'] != AppConstants.protocolVersion) {
      ch.close();
      return;
    }
    _handshakeTimer?.cancel();
    _peerId = id;
    _startedAt = DateTime.now();
    _connectedAt = null;
    _ending = false;
    _set(CallState(
      phase: CallPhase.ringing,
      peerName: name.trim(),
      peerIp: ch.remoteIp,
      incoming: true,
      message: 'Incoming call',
    ));
    ch.send({'type': 'ringing'});
    _ringTimer = Timer(AppConstants.ringTimeout, () {
      if (state.phase == CallPhase.ringing) {
        _ch?.send({'type': 'reject'});
        _end('Missed call');
      }
    });
  }

  Future<bool> accept() async {
    if (state.phase != CallPhase.ringing) return true;
    if (!await PermissionService.ensureMicrophone()) {
      _ch?.send({'type': 'reject'});
      _end('Microphone permission denied', dir: CallDirection.incoming);
      return false;
    }
    if (state.phase != CallPhase.ringing) return true; // caller hung up meanwhile
    _ringTimer?.cancel();
    try {
      await _initRtc();
      if (state.phase != CallPhase.ringing) {
        return true; // call ended meanwhile
      }
      _set(state.copyWith(phase: CallPhase.connecting, message: 'Connecting…'));
      _ch?.send({'type': 'accept'});
      return true;
    } catch (e) {
      loge('call', e);
      _ch?.send({'type': 'hangup'});
      _end('Could not start audio', dir: CallDirection.incoming);
      return true;
    }
  }

  void reject() {
    if (state.phase != CallPhase.ringing) return;
    _ch?.send({'type': 'reject'});
    _end('Call declined', dir: CallDirection.incoming);
  }

  void hangup() {
    if (state.phase == CallPhase.idle || state.phase == CallPhase.ended) return;
    _ch?.send({'type': 'hangup'});
    _end('Call ended');
  }

  // ───────────────────────── controls ─────────────────────────

  void toggleMute() {
    final m = !state.muted;
    _rtc?.setMuted(m);
    _set(state.copyWith(muted: m));
  }

  void toggleSpeaker() {
    final s = !state.speaker;
    _rtc?.setSpeaker(s);
    _set(state.copyWith(speaker: s));
  }

  // ───────────────────────── signaling ─────────────────────────

  void _attach(SignalingChannel ch) {
    _ch = ch;
    _msgSub = ch.messages.listen(
      (m) => _onMessage(ch, m),
      onDone: () {
        if (ch != _ch) return;
        final p = state.phase;
        if (p == CallPhase.idle) {
          _teardownChannel();
        } else if (p != CallPhase.ended) {
          _end(p == CallPhase.ringing ? 'Missed call' : 'Connection lost');
        }
      },
    );
  }

  Future<void> _onMessage(SignalingChannel ch, Map<String, dynamic> m) async {
    if (ch != _ch) return;
    final type = m['type'];
    try {
      switch (type) {
        case 'invite':
          _handleInvite(ch, m);
        case 'ringing':
          if (state.phase == CallPhase.calling) {
            _set(state.copyWith(message: 'Ringing…'));
          }
        case 'accept':
          if (state.phase == CallPhase.calling) await _onAccepted();
        case 'offer':
          if (state.phase == CallPhase.connecting && _rtc != null) {
            final data = m['data'];
            if (data is Map<String, dynamic>) {
              final answer = await _rtc!.acceptOffer(data);
              ch.send({'type': 'answer', 'data': answer});
            }
          }
        case 'answer':
          final data = m['data'];
          if (state.phase == CallPhase.connecting &&
              data is Map<String, dynamic>) {
            await _rtc?.acceptAnswer(data);
          }
        case 'candidate':
          final data = m['data'];
          if (data is Map<String, dynamic>) await _rtc?.addCandidate(data);
        case 'reject':
          if (state.phase == CallPhase.calling) _end('Call declined');
        case 'busy':
          if (state.phase == CallPhase.calling) _end('Device is busy');
        case 'hangup':
          if (state.phase == CallPhase.idle) {
            _teardownChannel();
          } else if (state.phase != CallPhase.ended) {
            _end(state.phase == CallPhase.ringing ? 'Missed call' : 'Call ended');
          }
        default:
          break; // unknown messages are ignored
      }
    } catch (e, st) {
      loge('call', e, st);
      if (state.phase != CallPhase.idle && state.phase != CallPhase.ended) {
        _ch?.send({'type': 'hangup'});
        _end('Call failed');
      }
    }
  }

  Future<void> _onAccepted() async {
    _ringTimer?.cancel();
    _set(state.copyWith(phase: CallPhase.connecting, message: 'Connecting…'));
    await _initRtc();
    if (state.phase != CallPhase.connecting || _rtc == null) return;
    final offer = await _rtc!.createOffer();
    _ch?.send({'type': 'offer', 'data': offer});
  }

  // ───────────────────────── WebRTC ─────────────────────────

  Future<void> _initRtc() async {
    final rtc = WebRtcService();
    _rtc = rtc;
    rtc.onCandidate = (c) => _ch?.send({'type': 'candidate', 'data': c});
    rtc.onConnectionState = _onRtcState;
    await rtc.init();
    rtc.setMuted(state.muted);
  }

  void _onRtcState(RTCPeerConnectionState s) {
    if (!_alive) return;
    switch (s) {
      case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
        _dropTimer?.cancel();
        if (state.phase == CallPhase.connecting ||
            state.phase == CallPhase.connected) {
          _onConnected();
        }
      case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
        if (state.phase == CallPhase.connected) {
          _set(state.copyWith(quality: 1, message: 'Reconnecting…'));
          _dropTimer?.cancel();
          _dropTimer = Timer(const Duration(seconds: 8), () {
            if (state.phase == CallPhase.connected) {
              _ch?.send({'type': 'hangup'});
              _end('Connection lost');
            }
          });
        }
      case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
        if (state.phase == CallPhase.connecting ||
            state.phase == CallPhase.connected) {
          _ch?.send({'type': 'hangup'});
          _end('Connection failed');
        }
      default:
        break;
    }
  }

  void _onConnected() {
    _connectedAt ??= DateTime.now();
    _rtc?.setSpeaker(state.speaker);
    _set(state.copyWith(
      phase: CallPhase.connected,
      message: 'Connected',
      quality: state.quality == 0 || state.quality == 1 ? 2 : state.quality,
    ));
    _tick ??= Timer.periodic(const Duration(seconds: 1), (_) {
      final c = _connectedAt;
      if (c != null && state.phase == CallPhase.connected) {
        _set(state.copyWith(seconds: DateTime.now().difference(c).inSeconds));
      }
    });
    _statsTimer ??= Timer.periodic(const Duration(seconds: 3), (_) async {
      final rtt = await _rtc?.roundTripMs();
      if (rtt == null || state.phase != CallPhase.connected) return;
      final q = rtt < 60 ? 3 : (rtt < 150 ? 2 : 1);
      _set(state.copyWith(quality: q, message: 'Connected'));
    });
  }

  // ───────────────────────── teardown ─────────────────────────

  void _cancelTimers() {
    _handshakeTimer?.cancel();
    _ringTimer?.cancel();
    _tick?.cancel();
    _statsTimer?.cancel();
    _dropTimer?.cancel();
    _tick = null;
    _statsTimer = null;
  }

  void _teardownChannel() {
    _handshakeTimer?.cancel();
    _msgSub?.cancel();
    _msgSub = null;
    _ch?.close();
    _ch = null;
  }

  void _end(String message, {CallDirection? dir}) {
    if (_ending) return;
    final phase = state.phase;
    if (phase == CallPhase.idle || phase == CallPhase.ended) {
      _teardownChannel();
      return;
    }
    _ending = true;
    _cancelTimers();

    final wasConnected = _connectedAt != null;
    final seconds =
        wasConnected ? DateTime.now().difference(_connectedAt!).inSeconds : 0;
    final direction = dir ??
        (!state.incoming
            ? CallDirection.outgoing
            : (wasConnected ? CallDirection.incoming : CallDirection.missed));

    if (_alive) {
      ref.read(historyProvider.notifier).add(CallRecord(
            id: '${DateTime.now().microsecondsSinceEpoch}',
            peerId: _peerId,
            peerName: state.peerName,
            direction: direction,
            startedAt: _startedAt,
            durationSeconds: seconds,
          ));
    }

    final rtc = _rtc;
    _rtc = null;
    rtc?.dispose();
    _teardownChannel();

    _set(state.copyWith(
      phase: CallPhase.ended,
      message: message,
      seconds: seconds,
    ));

    Timer(const Duration(milliseconds: 1600), () {
      if (_alive && state.phase == CallPhase.ended) {
        _ending = false;
        state = const CallState();
      }
    });
  }
}

final callProvider =
    NotifierProvider<CallController, CallState>(CallController.new);
