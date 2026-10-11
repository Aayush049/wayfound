import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/settlement.dart';
import 'settlement_repository.dart';

final settlementsStreamProvider =
    StreamProvider.family<List<Settlement>, String>((ref, tripId) {
  final repo = ref.watch(settlementRepositoryProvider);
  return repo.watchSettlements(tripId);
});

final confirmedSettlementsProvider =
    Provider.family<List<Settlement>, String>((ref, tripId) {
  final settlementsAsync = ref.watch(settlementsStreamProvider(tripId));
  return settlementsAsync.maybeWhen(
    data: (settlements) => settlements
        .where((s) => s.status == SettlementStatus.confirmed)
        .toList(),
    orElse: () => [],
  );
});

final pendingSettlementsProvider =
    Provider.family<List<Settlement>, String>((ref, tripId) {
  final settlementsAsync = ref.watch(settlementsStreamProvider(tripId));
  return settlementsAsync.maybeWhen(
    data: (settlements) => settlements
        .where((s) => s.status == SettlementStatus.pending)
        .toList(),
    orElse: () => [],
  );
});
