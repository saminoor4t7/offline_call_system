import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/call_record.dart';
import '../../data/repositories/settings_repository.dart';

class HistoryController extends Notifier<List<CallRecord>> {
  static const _max = 200;

  @override
  List<CallRecord> build() => ref.read(settingsRepoProvider).loadHistory();

  Future<void> add(CallRecord r) async {
    final next = [r, ...state];
    state = next.length > _max ? next.sublist(0, _max) : next;
    await ref.read(settingsRepoProvider).saveHistory(state);
  }

  Future<void> clear() async {
    state = [];
    await ref.read(settingsRepoProvider).saveHistory(state);
  }
}

final historyProvider =
    NotifierProvider<HistoryController, List<CallRecord>>(HistoryController.new);
