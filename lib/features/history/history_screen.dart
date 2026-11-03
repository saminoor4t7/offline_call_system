import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../shared/widgets/common.dart';
import 'call_tile.dart';
import 'history_controller.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Call history'),
        actions: [
          if (history.isNotEmpty)
            IconButton(
              tooltip: 'Clear history',
              icon: const Icon(Icons.delete_sweep_rounded),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Clear call history?'),
                    content: const Text(
                        'All calls will be removed from this phone. This cannot be undone.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: TextButton.styleFrom(
                            foregroundColor: AppColors.error),
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                );
                if (ok == true) ref.read(historyProvider.notifier).clear();
              },
            ),
        ],
      ),
      body: history.isEmpty
          ? const Center(
              child: EmptyState(
                icon: Icons.history_rounded,
                title: 'No calls yet',
                message:
                    'Incoming, outgoing and missed calls will show up here.',
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              itemCount: history.length,
              itemBuilder: (_, i) => CallTile(record: history[i]),
            ),
    );
  }
}
