#!/usr/bin/env bash
#
# inject-fault.sh — temporarily replace calculateFee with a KNOWN-FAULTY version.
#
# This is an injected fault, and it says so. It exists for one reason: a test that has never
# failed has never proven anything. Once you have written a permanent test for the approved
# RTP rule, inject this fault and watch the test go RED. Remove it and watch it go GREEN. That
# is the evidence that your test actually guards the rule.
#
# The fault is a classic one for a percentage-with-minimum rule: it compares the USD 2.00
# minimum against the raw transfer AMOUNT instead of against the computed FEE. It agrees with
# the correct rule for large transfers and disagrees for small ones.
#
# Your own implementation is saved first and restored exactly by `off`. Everything you change
# while the fault is on is discarded by `off` — that is deliberate.
#
# usage: scripts/inject-fault.sh on | off | status
# exit 0 ok · 2 bad usage · 3 wrong state (already on / nothing to restore / file changed)

set -uo pipefail
cd "$(dirname "$0")/.." || exit 3

FILE="src/main/java/com/meridian/payments/PaymentService.java"
BACKUP=".workflow/fault-backup.PaymentService.java"
MARK="INJECTED FAULT (scripts/inject-fault.sh)"

case "${1:-}" in
  status)
    if [ -f "$BACKUP" ]; then echo "fault: ON (your implementation is saved in $BACKUP)"; else echo "fault: off"; fi
    exit 0 ;;
  off)
    [ -f "$BACKUP" ] || { echo "inject-fault: no fault is injected — nothing to restore." >&2; exit 3; }
    cp "$BACKUP" "$FILE" && rm -f "$BACKUP"
    echo "fault removed — your implementation of calculateFee is restored exactly."
    exit 0 ;;
  on) ;;
  *) echo "usage: inject-fault.sh on | off | status" >&2; exit 2 ;;
esac

[ -f "$BACKUP" ] && { echo "inject-fault: a fault is already injected. Run: ./scripts/inject-fault.sh off" >&2; exit 3; }
grep -q 'paymentType.equals("RTP")' "$FILE" || {
  echo "inject-fault: calculateFee has no RTP branch yet — implement the approved rule first." >&2
  exit 3; }

RANGE="$(bash scripts/lib/methods.sh "$FILE" | awk -F'\t' '$1=="calculateFee"{print $2" "$3; exit}')"
[ -n "$RANGE" ] || { echo "inject-fault: could not locate calculateFee in $FILE" >&2; exit 3; }
set -- $RANGE; START="$1"; END="$2"

mkdir -p .workflow
cp "$FILE" "$BACKUP"

{
  head -n $((START - 1)) "$FILE"
  cat <<'JAVA'
    public BigDecimal calculateFee(BigDecimal amount, String paymentType) {
        // INJECTED FAULT (scripts/inject-fault.sh) — remove with: ./scripts/inject-fault.sh off
        if (paymentType.equals("WIRE")) {
            return amount.multiply(BigDecimal.valueOf(0.0025)).setScale(2, RoundingMode.HALF_UP);
        } else if (paymentType.equals("ACH")) {
            return BigDecimal.valueOf(0.25);
        } else if (paymentType.equals("SWIFT")) {
            return amount.multiply(BigDecimal.valueOf(0.005)).add(BigDecimal.valueOf(15.00)).setScale(2, RoundingMode.HALF_UP);
        } else if (paymentType.equals("RTP")) {
            // compares the minimum against the transfer amount, not against the computed fee
            if (amount.compareTo(new BigDecimal("2.00")) >= 0) {
                return amount.multiply(new BigDecimal("0.0035")).setScale(2, RoundingMode.HALF_UP);
            }
            return new BigDecimal("2.00");
        } else {
            return BigDecimal.ZERO;
        }
    }
JAVA
  tail -n +$((END + 1)) "$FILE"
} > "$FILE.tmp" && mv "$FILE.tmp" "$FILE"

echo "fault INJECTED into calculateFee: the RTP minimum is compared against the transfer amount,"
echo "not the computed fee. This is deliberate and temporary. Your implementation is saved;"
echo "restore it with: ./scripts/inject-fault.sh off"
