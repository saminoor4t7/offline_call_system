import 'dart:convert';

enum CallDirection { incoming, outgoing, missed }

class CallRecord {
  const CallRecord({
    required this.id,
    required this.peerId,
    required this.peerName,
    required this.direction,
    required this.startedAt,
    required this.durationSeconds,
  });

  final String id;
  final String peerId;
  final String peerName;
  final CallDirection direction;
  final DateTime startedAt;
  final int durationSeconds;

  Map<String, dynamic> toJson() => {
        'id': id,
        'peerId': peerId,
        'peerName': peerName,
        'direction': direction.name,
        'startedAt': startedAt.millisecondsSinceEpoch,
        'duration': durationSeconds,
      };

  static CallRecord? fromJson(Object? raw) {
    if (raw is! Map) return null;
    try {
      return CallRecord(
        id: raw['id'] as String,
        peerId: raw['peerId'] as String,
        peerName: raw['peerName'] as String,
        direction: CallDirection.values.byName(raw['direction'] as String),
        startedAt:
            DateTime.fromMillisecondsSinceEpoch(raw['startedAt'] as int),
        durationSeconds: raw['duration'] as int,
      );
    } catch (_) {
      return null;
    }
  }

  static String encodeList(List<CallRecord> list) =>
      jsonEncode(list.map((e) => e.toJson()).toList());

  static List<CallRecord> decodeList(String? s) {
    if (s == null || s.isEmpty) return [];
    try {
      final data = jsonDecode(s);
      if (data is! List) return [];
      return data.map(CallRecord.fromJson).whereType<CallRecord>().toList();
    } catch (_) {
      return [];
    }
  }
}
