import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../core/services/providers.dart';
import '../../core/utils/format.dart';
import '../../data/models/call_record.dart';
import '../../shared/widgets/animated_widgets.dart';
import '../../shared/widgets/common.dart';
import '../home/home_screen.dart';

class CallTile extends ConsumerWidget {
  const CallTile({super.key, required this.record, this.compact = false});
  final CallRecord record;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final (icon, color, label) = switch (record.direction) {
      CallDirection.incoming =>
        (Icons.call_received_rounded, AppColors.success, 'Incoming'),
      CallDirection.outgoing =>
        (Icons.call_made_rounded, AppColors.blue, 'Outgoing'),
      CallDirection.missed =>
        (Icons.call_missed_rounded, AppColors.error, 'Missed'),
    };
    final dur = record.durationSeconds > 0
        ? formatDuration(record.durationSeconds)
        : null;

    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      onTap: () {
        final peers = ref.read(discoveryServiceProvider).peers;
        final match = peers.where((p) => p.id == record.peerId);
        if (match.isEmpty) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(
                content: Text('${record.peerName} is not nearby right now.')));
        } else {
          placeCall(context, ref, match.first);
        }
      },
      child: Row(children: [
        MiniAvatar(name: record.peerName, size: compact ? 44 : 48),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(record.peerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: record.direction == CallDirection.missed
                        ? AppColors.error
                        : null,
                  )),
              const SizedBox(height: 3),
              Row(children: [
                Icon(icon, size: 15, color: color),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    dur == null ? label : '$label · $dur',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                  ),
                ),
              ]),
            ],
          ),
        ),
        Text(formatWhen(record.startedAt),
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
      ]),
    );
  }
}
