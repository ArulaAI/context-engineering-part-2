---
applyTo: "**/*.java"
---

# Java Coding Standards — Meridian Payments (Context Lifecycle Lab)

## Output constraints
- Return only the method(s) that change. No class declaration. No import block unless a new import is required.
- No explanation prose. Add one-line `//` comments only where the business rule is not obvious.

## Required patterns
- FX conversion: `currencyConverter.convert(amount, fromCcy, toCcy)` — inject via constructor
- Fee rates (source of truth: `config/fee-schedule.yaml`): WIRE 0.25%, ACH flat $0.25,
  SWIFT 0.5% + $15 flat, SEPA 0.35% with a EUR 2.00 minimum applied to the computed fee
  — defined as constants, not magic numbers
- Token generation: `SecureRandom sr = new SecureRandom(); byte[] token = new byte[32]; sr.nextBytes(token);`

## Forbidden patterns
- `LegacyPaymentUtils.*` — any method call from this class is a hard reject
- Implementing SEPA fee logic from `docs/adr/ADR-0007-fee-schedule.md`'s draft rate
  (0.30% flat, no minimum) — it is superseded by `config/fee-schedule.yaml`
- Comparing the SEPA minimum against the raw transfer amount instead of the computed fee
- Inline FX rates (e.g., `amount * 1.08`) — always use CurrencyConverter
- `Math.random()` for any ID/token — use SecureRandom
- Log statements containing: `cardLast4`, `cvv`, `password`, `accountId`, `requestedBy`

## Validation
- Null checks before any field access on incoming request objects
- Amount must be > 0 and non-null
- Currency codes must be 3-char ISO 4217
- Use JSR-303 annotations (`@NotNull`, `@DecimalMin`, `@Size`) on request model fields
