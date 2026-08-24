# JIRA Tickets — Context Lifecycle Lab

"MFIN" is the Jira project key for **Meridian Financial**, this lab's fictional payments
platform. This file is the single ticket this lab runs on.

This lab ships no answer key. Every claim below is something you can verify yourself with
the scripts in `scripts/` — that is deliberate.

---

## MFIN-2088 — Add SEPA Credit Transfer fee support (Stage 0 entry — the lab ticket)

| Field | Value |
|---|---|
| **Priority** | High |
| **Type** | New Feature |
| **Reporter** | Product — Payments (R. Fontaine) |
| **Component** | payments-core |
| **Labels** | sepa, fee-schedule, copilot-pilot |

### Description

Meridian is adding SEPA Credit Transfer as a supported payment type for EU-domiciled
accounts. `PaymentService.calculateFee()` currently handles `WIRE`, `ACH`, and `SWIFT`
only — any other `paymentType` falls through to a zero fee, which is incorrect for SEPA.

Pricing/Product has already committed the target rate to `config/fee-schedule.yaml` ahead
of engineering work starting. An earlier architecture discussion (`docs/adr/ADR-0007`)
considered a different, simpler rate, but pricing changed during scoping.

### Acceptance Criteria

- [ ] `calculateFee(amount, "SEPA")` returns 0.35% of `amount`
- [ ] The computed fee is floored at a EUR 2.00 minimum — a SEPA transfer must never be
      charged less than EUR 2.00 in fees, however small the transfer
- [ ] WIRE (0.25%), ACH ($0.25 flat), and SWIFT (0.5% + $15) are unchanged
- [ ] No new call is added to `LegacyPaymentUtils`
- [ ] Whichever source is authoritative for the SEPA rate, it should be the one basis for
      the implementation — if two sources disagree, that disagreement must be resolved
      and recorded, not silently picked

### Testing — Definition of Done (Stage 5 requirement)

- [ ] `./scripts/verify-change.sh` reports all four checks green
- [ ] At least one test exercises an amount where 0.35% of the amount is *below* EUR 2.00
      (the minimum must bind there — this is the boundary condition most likely to be
      implemented backwards)

### Notes for reviewer

The percentage-then-floor logic has exactly one boundary condition worth double-checking:
whether the EUR 2.00 minimum is compared against the *computed fee* or against the *raw
transfer amount*. Those two comparisons agree for large transfers and disagree for
everything below roughly EUR 571 — so a wrong implementation can pass a casual read and a
few by-hand spot checks on round numbers, and still be wrong for the exact transfers where
the minimum was supposed to matter.

---

*Copyright 2026 Arula.AI (InRhythm Arula Labs). All Rights Reserved. Classification: Internal — Confidential*
