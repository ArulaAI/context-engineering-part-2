# JIRA Tickets — Meridian payments-core

> *Scenario note:* "MFIN" is the Jira project key for **Meridian Financial**, a fictional
> payments platform used for this exercise. People and rates are fictional.

---

## MFIN-2088 — Add US Real-Time Payment (RTP) fee support

| Field | Value |
|---|---|
| **Priority** | High |
| **Type** | New Feature |
| **Reporter** | Product — Payments (R. Fontaine) |
| **Component** | payments-core |
| **Labels** | rtp, fee-schedule |

### Description

Meridian is adding US Real-Time Payment (RTP) as a supported payment type for US-domiciled
accounts. `PaymentService.calculateFee()` currently handles `WIRE`, `ACH`, and `SWIFT`
only — any other `paymentType` falls through to a zero fee, which is incorrect for RTP.

RTP pricing is owned by the Pricing Committee, and the pricing discussion moved during
scoping. Confirm the approved pricing reference before implementing.

### Acceptance Criteria

- [ ] `calculateFee(amount, "RTP")` returns the fee defined by the approved RTP pricing
- [ ] WIRE (0.25%), ACH ($0.25 flat), and SWIFT (0.5% + $15) are unchanged
- [ ] No new call is added to `LegacyPaymentUtils`
- [ ] The implementation traces to an approved pricing reference. If sources in the
      repository disagree about RTP pricing, the disagreement is resolved by pricing
      authority and recorded before implementation — not silently picked

### Testing — Definition of Done

- [ ] `./scripts/verify-change.sh` reports every check green
- [ ] Permanent tests cover the approved RTP pricing rule, including any point where the
      rule changes behavior

---

*Copyright 2026 Arula.AI (InRhythm Arula Labs). All Rights Reserved. Classification: Internal — Confidential*
