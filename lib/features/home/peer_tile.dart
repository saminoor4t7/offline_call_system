import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/theme/app_colors.dart';
import '../../data/models/peer.dart';
import '../settings/settings_controller.dart';
import '../../shared/widgets/animated_widgets.dart';
import '../../shared/widgets/common.dart';

Future<void> editPeerName(BuildContext context, WidgetRef ref, Peer peer) async {
  final savedAlias = ref.read(peerAliasesProvider)[peer.ip];
  await showDialog<void>(
    context: context,
    builder: (_) => _EditPeerNameDialog(
      peer: peer,
      initialName: savedAlias ?? peer.name,
      hasSavedAlias: savedAlias != null,
    ),
  );
}

class _EditPeerNameDialog extends ConsumerStatefulWidget {
  const _EditPeerNameDialog({
    required this.peer,
    required this.initialName,
    required this.hasSavedAlias,
  });

  final Peer peer;
  final String initialName;
  final bool hasSavedAlias;

  @override
  ConsumerState<_EditPeerNameDialog> createState() =>
      _EditPeerNameDialogState();
}

class _EditPeerNameDialogState extends ConsumerState<_EditPeerNameDialog> {
  late final TextEditingController _nameController =
      TextEditingController(text: widget.initialName);
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save(String? name) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(peerAliasesProvider.notifier)
          .setAlias(widget.peer.ip, name);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save this name. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        scrollable: true,
        title: const Text('Name this device'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.peer.ip, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              enabled: !_saving,
              autofocus: true,
              maxLength: 32,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Device name',
                hintText: 'e.g. Mom’s phone',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          if (widget.hasSavedAlias)
            TextButton(
              onPressed: _saving ? null : () => _save(''),
              child: const Text('Use device name'),
            ),
          FilledButton(
            onPressed: _saving ? null : () => _save(_nameController.text),
            child: Text(_saving ? 'Saving…' : 'Save'),
          ),
        ],
      );
  }


class PeerTile extends StatelessWidget {
  const PeerTile({
    super.key,
    required this.peer,
    required this.onCall,
    required this.onEdit,
  });
  final Peer peer;
  final VoidCallback onCall;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      onTap: onCall,
      child: Row(children: [
        Stack(children: [
          MiniAvatar(name: peer.name),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: AppColors.success,
                shape: BoxShape.circle,
                border: Border.all(color: cs.surface, width: 2.5),
              ),
            ),
          ),
        ]),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(peer.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 3),
              Row(children: [
                const StatusPill(label: 'Online', color: AppColors.success),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(peer.ip,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12.5, color: cs.onSurfaceVariant)),
                ),
              ]),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Edit device name',
          onPressed: onEdit,
          icon: const Icon(Icons.edit_rounded),
        ),
        Container(
          width: 46,
          height: 46,
          decoration: const BoxDecoration(
            color: AppColors.success,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            tooltip: 'Call ${peer.name}',
            onPressed: onCall,
            icon: const Icon(Icons.call_rounded, color: Colors.white, size: 22),
          ),
        ),
      ]),
    );
  }
}
