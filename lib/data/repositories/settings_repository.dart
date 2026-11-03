import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/call_record.dart';

/// Overridden in main() with the real instance.
final sharedPrefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPrefsProvider not overridden'),
);

final settingsRepoProvider =
    Provider<SettingsRepository>((ref) => SettingsRepository(ref.watch(sharedPrefsProvider)));

class SettingsRepository {
  SettingsRepository(this._p);
  final SharedPreferences _p;

  String get deviceId {
    var id = _p.getString('device_id');
    if (id == null) {
      final r = Random.secure();
      id = List.generate(16, (_) => r.nextInt(16).toRadixString(16)).join();
      _p.setString('device_id', id);
    }
    return id;
  }

  String get deviceName =>
      _p.getString('device_name') ??
      'AirCall-${deviceId.substring(0, 4).toUpperCase()}';
  Future<void> setDeviceName(String v) => _p.setString('device_name', v);

  bool get onboardingDone => _p.getBool('onboarding_done') ?? false;
  Future<void> setOnboardingDone() => _p.setBool('onboarding_done', true);

  ThemeMode get themeMode {
    switch (_p.getString('theme')) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode m) => _p.setString('theme', m.name);

  List<CallRecord> loadHistory() => CallRecord.decodeList(_p.getString('history'));
  Future<void> saveHistory(List<CallRecord> l) =>
      _p.setString('history', CallRecord.encodeList(l));

  Map<String, String> get peerAliases {
    final raw = _p.getString('peer_aliases');
    if (raw == null) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return const {};
      return decoded.map((ip, value) => MapEntry(ip, value is String ? value : ''))
        ..removeWhere((_, name) => name.trim().isEmpty);
    } catch (_) {
      return const {};
    }
  }

  Future<void> savePeerAliases(Map<String, String> aliases) =>
      _p.setString('peer_aliases', jsonEncode(aliases));
}
