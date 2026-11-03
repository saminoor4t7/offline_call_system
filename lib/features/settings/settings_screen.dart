import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../app/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/permissions/permission_service.dart';
import '../../shared/widgets/app_logo.dart';
import '../../shared/widgets/common.dart';
import 'diagnostics_screen.dart';
import 'settings_controller.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with WidgetsBindingObserver {
  PermissionStatus? _mic;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadMic();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadMic();
  }

  Future<void> _loadMic() async {
    final s = await PermissionService.microphoneStatus();
    if (mounted) setState(() => _mic = s);
  }

  Future<void> _editName() async {
    final current = ref.read(settingsProvider).deviceName;
    final c = TextEditingController(text: current);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Device name'),
        content: TextField(
          controller: c,
          autofocus: true,
          maxLength: AppConstants.maxNameLength,
          decoration: const InputDecoration(hintText: 'e.g. Sami\'s phone'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, c.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    c.dispose();
    if (result != null && result.isNotEmpty) {
      ref.read(settingsProvider.notifier).setDeviceName(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = ref.watch(settingsProvider);
    final micOk = _mic?.isGranted ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          const _Label('This device'),
          AppCard(
            padding: EdgeInsets.zero,
            child: _Row(
              icon: Icons.phone_android_rounded,
              title: 'Device name',
              subtitle: s.deviceName,
              trailing: const Icon(Icons.edit_rounded, size: 20),
              onTap: _editName,
            ),
          ),
          const _Label('Appearance'),
          AppCard(
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<ThemeMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                      value: ThemeMode.system,
                      icon: Icon(Icons.brightness_auto_rounded),
                      label: Text('System')),
                  ButtonSegment(
                      value: ThemeMode.light,
                      icon: Icon(Icons.light_mode_rounded),
                      label: Text('Light')),
                  ButtonSegment(
                      value: ThemeMode.dark,
                      icon: Icon(Icons.dark_mode_rounded),
                      label: Text('Dark')),
                ],
                selected: {s.themeMode},
                onSelectionChanged: (v) =>
                    ref.read(settingsProvider.notifier).setThemeMode(v.first),
              ),
            ),
          ),
          const _Label('Permissions & network'),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(children: [
              _Row(
                icon: micOk ? Icons.mic_rounded : Icons.mic_off_rounded,
                iconColor: micOk ? AppColors.success : AppColors.error,
                title: 'Microphone',
                subtitle: micOk
                    ? 'Allowed'
                    : (_mic?.isPermanentlyDenied ?? false)
                        ? 'Blocked – open system settings to allow'
                        : 'Needed to make and answer calls',
                trailing: micOk
                    ? null
                    : FilledButton.tonal(
                        style: FilledButton.styleFrom(
                            minimumSize: const Size(84, 38)),
                        onPressed: () async {
                          if (_mic?.isPermanentlyDenied ?? false) {
                            await openAppSettings();
                          } else {
                            await PermissionService.ensureMicrophone();
                            _loadMic();
                          }
                        },
                        child: Text((_mic?.isPermanentlyDenied ?? false)
                            ? 'Settings'
                            : 'Allow'),
                      ),
              ),
              const Divider(indent: 68),
              _Row(
                icon: Icons.network_check_rounded,
                title: 'Local network diagnostics',
                subtitle: 'IP address, ports and nearby devices',
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => const DiagnosticsScreen())),
              ),
            ]),
          ),
          const _Label('About'),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(children: [
              _Row(
                icon: Icons.info_outline_rounded,
                title: 'About AirCall',
                subtitle: 'Version ${AppConstants.version}',
                onTap: () => _sheet(
                  context,
                  'About AirCall',
                  'AirCall makes real-time voice calls between phones on the same Wi-Fi network or hotspot, with no internet connection.\n\n'
                      'Devices find each other with UDP broadcasts, call setup is exchanged over a local TCP connection, and audio is carried peer-to-peer with WebRTC.',
                  showLogo: true,
                ),
              ),
              const Divider(indent: 68),
              _Row(
                icon: Icons.shield_outlined,
                title: 'Privacy',
                subtitle: 'Nothing leaves your network',
                onTap: () => _sheet(
                  context,
                  'Privacy',
                  'AirCall has no accounts, no cloud services, no analytics and no ads.\n\n'
                      '• Calls and signaling stay on your local network.\n'
                      '• No STUN/TURN servers or other internet services are contacted.\n'
                      '• Your device name is visible to other AirCall phones on the same network.\n'
                      '• Call history is stored only on this phone and can be cleared at any time.\n'
                      '• The microphone is used only during a call.',
                ),
              ),
            ]),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(AppConstants.tagline,
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  void _sheet(BuildContext context, String title, String body,
      {bool showLogo = false}) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showLogo) ...[
              const AppLogoBadge(size: 64),
              const SizedBox(height: 16),
            ],
            Text(title,
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Text(body,
                style: TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
        child: Text(text,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
    this.iconColor,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = iconColor ?? AppColors.blue;
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: c.withAlpha(30),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: c, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 15.5, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ]),
      ),
    );
  }
}
