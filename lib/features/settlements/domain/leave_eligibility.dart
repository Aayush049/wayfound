import '../../../core/money.dart';
import '../domain/settlement.dart';

class LeaveEligibilityResult {
  final bool allowed;
  final String? reason;

  const LeaveEligibilityResult({required this.allowed, this.reason});

  const LeaveEligibilityResult.allowed() : allowed = true, reason = null;
  const LeaveEligibilityResult.denied(this.reason) : allowed = false;
}

LeaveEligibilityResult checkLeaveEligibility({
  required String uid,
  required String organizerId,
  required Map<String, int> balances,
  required List<Settlement> settlements,
  required String currencyCode,
}) {
  if (uid == organizerId) {
    return const LeaveEligibilityResult.denied(
      "Organizers can't leave a trip in this version.",
    );
  }

  final balance = balances[uid] ?? 0;
  if (balance != 0) {
    final formattedAmount = formatMinorUnits(balance.abs(), currencyCode);
    final detail = balance < 0
        ? 'you owe $formattedAmount'
        : 'you are owed $formattedAmount';
    return LeaveEligibilityResult.denied(
      'Cannot leave while you have a nonzero balance ($detail). Please settle up or confirm pending payments first.',
    );
  }

  // Check pending settlements where uid is fromUid or toUid
  for (final s in settlements) {
    if (s.status == SettlementStatus.pending) {
      if (s.fromUid == uid || s.toUid == uid) {
        return const LeaveEligibilityResult.denied(
          'Cannot leave while you have pending settlements. Please resolve or cancel them first.',
        );
      }
    }
  }

  return const LeaveEligibilityResult.allowed();
}
