import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/settings_repository.dart';

class SettingsState {
  const SettingsState({
    required this.deviceId,
    required this.deviceName,
    required this.themeMode,
    required this.onboardingDone,
  });
  final String deviceId;
  final String deviceName;
  final ThemeMode themeMode;
  final bool onboardingDone;

  SettingsState copyWith({
    String? deviceName,
    ThemeMode? themeMode,
    bool? onboardingDone,
  }) =>
      SettingsState(
        deviceId: deviceId,
        deviceName: deviceName ?? this.deviceName,
        themeMode: themeMode ?? this.themeMode,
        onboardingDone: onboardingDone ?? this.onboardingDone,
      );
}

class SettingsController extends Notifier<SettingsState> {
  @override
  SettingsState build() {
    final r = ref.read(settingsRepoProvider);
    return SettingsState(
      deviceId: r.deviceId,
      deviceName: r.deviceName,
      themeMode: r.themeMode,
      onboardingDone: r.onboardingDone,
    );
  }

  Future<void> setDeviceName(String name) async {
    final n = name.trim();
    if (n.isEmpty) return;
    state = state.copyWith(deviceName: n);
    await ref.read(settingsRepoProvider).setDeviceName(n);
  }

  Future<void> setThemeMode(ThemeMode m) async {
    state = state.copyWith(themeMode: m);
    await ref.read(settingsRepoProvider).setThemeMode(m);
  }

  Future<void> completeOnboarding() async {
    state = state.copyWith(onboardingDone: true);
    await ref.read(settingsRepoProvider).setOnboardingDone();
  }
}

final settingsProvider =
    NotifierProvider<SettingsController, SettingsState>(SettingsController.new);

/// User-assigned names for discovered devices, keyed by their local IP.
class PeerAliasesController extends Notifier<Map<String, String>> {
  @override
  Map<String, String> build() =>
      Map<String, String>.from(ref.read(settingsRepoProvider).peerAliases);

  Future<void> setAlias(String ip, String? alias) async {
    final updated = Map<String, String>.from(state);
    final name = alias?.trim() ?? '';
    if (name.isEmpty) {
      updated.remove(ip);
    } else {
      updated[ip] = name;
    }
    await ref.read(settingsRepoProvider).savePeerAliases(updated);
    state = updated;
  }
}

final peerAliasesProvider =
    NotifierProvider<PeerAliasesController, Map<String, String>>(
  PeerAliasesController.new,
);

/// True once the splash animation has finished.
class SplashDone extends Notifier<bool> {
  @override
  bool build() => false;
  void finish() => state = true;
}

final splashDoneProvider =
    NotifierProvider<SplashDone, bool>(SplashDone.new);
