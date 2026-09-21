# ADR-0007 — RTP Transfer Fee Schedule

**Status:** Accepted
**Date:** 2026-03-11
**Deciders:** Payments Platform working group

## Context

Meridian is adding US Real-Time Payment (RTP) as a supported payment type for
US-domiciled accounts. Fee rates for every payment type need one home that the service
reads at build time, and RTP needs an initial rate.

## Decision

1. **Where rates live.** Every payment-type fee rate, including RTP, is recorded in
   `config/fee-schedule.yaml`. Fee logic must not hardcode a rate that is not in that
   file.
2. **The RTP rate.** RTP transfers are charged **0.30% flat**, with **no minimum fee**,
   to keep the pricing model easy to explain to relationship managers.

## Consequences

- One file to audit for every rate the service applies.
- Small RTP transfers generate very little fee revenue; the working group judged this
  acceptable for the initial launch.

---

*Copyright 2026 Arula.AI (InRhythm Arula Labs). All Rights Reserved. | Internal - Confidential*
