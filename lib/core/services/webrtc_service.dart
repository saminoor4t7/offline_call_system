import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../utils/log.dart';

/// Wraps one audio-only RTCPeerConnection.
///
/// No STUN/TURN servers are configured: both phones are on the same LAN, so
/// host candidates are enough and nothing leaves the local network.
class WebRtcService {
  RTCPeerConnection? _pc;
  MediaStream? _local;
  bool _remoteSet = false;
  bool _disposed = false;
  final List<RTCIceCandidate> _pending = [];

  void Function(Map<String, dynamic> candidate)? onCandidate;
  void Function(RTCPeerConnectionState state)? onConnectionState;

  Future<void> init() async {
    _local = await navigator.mediaDevices.getUserMedia({
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
      },
      'video': false,
    });
    if (_disposed) {
      for (final t in _local!.getTracks()) {
        await t.stop();
      }
      return;
    }

    final pc = await createPeerConnection({
      'iceServers': <Map<String, dynamic>>[],
      'sdpSemantics': 'unified-plan',
      'bundlePolicy': 'max-bundle',
      'iceTransportPolicy': 'all',
    });
    _pc = pc;
    if (_disposed) {
      await pc.close();
      return;
    }

    pc.onIceCandidate = (RTCIceCandidate c) {
      final cand = c.candidate;
      if (cand == null || cand.isEmpty) return;
      onCandidate?.call({
        'candidate': cand,
        'sdpMid': c.sdpMid,
        'sdpMLineIndex': c.sdpMLineIndex,
      });
    };
    pc.onConnectionState = (RTCPeerConnectionState s) {
      logd('webrtc', 'connection state: $s');
      if (!_disposed) onConnectionState?.call(s);
    };
    // Remote audio plays automatically through the platform audio device.

    for (final t in _local!.getAudioTracks()) {
      await pc.addTrack(t, _local!);
    }
  }

  Future<Map<String, dynamic>> createOffer() async {
    final pc = _pc!;
    final offer = await pc.createOffer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': false,
    });
    await pc.setLocalDescription(offer);
    return {'sdp': offer.sdp, 'type': offer.type};
  }

  Future<Map<String, dynamic>> acceptOffer(Map<String, dynamic> offer) async {
    final pc = _pc!;
    await pc.setRemoteDescription(
        RTCSessionDescription(offer['sdp'] as String, offer['type'] as String));
    await _markRemoteSet();
    final answer = await pc.createAnswer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': false,
    });
    await pc.setLocalDescription(answer);
    return {'sdp': answer.sdp, 'type': answer.type};
  }

  Future<void> acceptAnswer(Map<String, dynamic> answer) async {
    await _pc!.setRemoteDescription(RTCSessionDescription(
        answer['sdp'] as String, answer['type'] as String));
    await _markRemoteSet();
  }

  Future<void> _markRemoteSet() async {
    _remoteSet = true;
    for (final c in _pending) {
      try {
        await _pc?.addCandidate(c);
      } catch (e) {
        loge('webrtc', e);
      }
    }
    _pending.clear();
  }

  Future<void> addCandidate(Map<String, dynamic> m) async {
    final cand = m['candidate'];
    if (cand is! String || cand.isEmpty || cand.length > 2048) return;
    final mid = m['sdpMid'];
    final idx = m['sdpMLineIndex'];
    final c = RTCIceCandidate(
      cand,
      mid is String ? mid : null,
      idx is int ? idx : null,
    );
    if (!_remoteSet) {
      _pending.add(c);
      return;
    }
    try {
      await _pc?.addCandidate(c);
    } catch (e) {
      loge('webrtc', e);
    }
  }

  void setMuted(bool muted) {
    for (final t in _local?.getAudioTracks() ?? <MediaStreamTrack>[]) {
      t.enabled = !muted;
    }
  }

  Future<void> setSpeaker(bool on) async {
    try {
      await Helper.setSpeakerphoneOn(on);
    } catch (e) {
      loge('webrtc', e);
    }
  }

  /// Round-trip time in milliseconds, or null if not available yet.
  Future<double?> roundTripMs() async {
    try {
      final reports = await _pc?.getStats();
      if (reports == null) return null;
      for (final r in reports) {
        if (r.type == 'candidate-pair') {
          final v = r.values;
          final ok = v['state'] == 'succeeded' || v['nominated'] == true;
          final rtt = v['currentRoundTripTime'];
          if (ok && rtt is num) return rtt * 1000.0;
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    onCandidate = null;
    onConnectionState = null;
    try {
      for (final t in _local?.getTracks() ?? <MediaStreamTrack>[]) {
        await t.stop();
      }
      await _local?.dispose();
    } catch (_) {}
    try {
      await _pc?.close();
    } catch (_) {}
    _pc = null;
    _local = null;
    _pending.clear();
    try {
      await Helper.setSpeakerphoneOn(false);
    } catch (_) {}
  }
}
