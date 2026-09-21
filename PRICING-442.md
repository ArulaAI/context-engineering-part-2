# PRICING-442 — RTP transfer pricing

| Field | Value |
|---|---|
| **Status** | Approved |
| **Approved by** | Pricing Committee (chair: D. Okafor) |
| **Approval date** | 2026-08-14 |
| **Requested for** | MFIN-2088 |

## Approved pricing

RTP transfers are charged **0.35% of the transfer amount**, with a **minimum fee of
USD 2.00 per transfer**. The fee charged is whichever of those two is larger.

## Supersession scope

- **Supersedes:** ADR-0007, Decision 2 ("The RTP rate": 0.30% flat, no minimum).
- **Does not supersede:** ADR-0007, Decision 1 ("Where rates live"). Rates continue to
  be recorded in `config/fee-schedule.yaml`.

## Machine-readable

```
approved_pricing:
  record: PRICING-442
  payment_type: RTP
  percent: 0.0035
  minimum_usd: 2.00
```
