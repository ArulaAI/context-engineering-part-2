---
applyTo: "**/*.java"
---

# Java Coding Standards — Meridian Payments (Context Lifecycle Lab)

## Output constraints
- Return only the method(s) that change. No class declaration. No import block unless a new import is required.
- No explanation prose. Add one-line `//` comments only where the business rule is not obvious.

## Required patterns
- FX conversion: `currencyConverter.convert(amount, fromCcy, toCcy)` — inject via constructor
- Fee rates: constants must be traceable to the verified committed fee schedule
  (`config/fee-schedule.yaml`) — do not invent or copy rates from stale sources
- Token generation: `SecureRandom sr = new SecureRandom(); byte[] token = new byte[32]; sr.nextBytes(token);`

## Forbidden patterns
- `LegacyPaymentUtils.*` — any method call from this class is a hard reject
- Implementing fee logic from an ADR or doc marked `Proposed`/draft status without
  first checking whether it has been superseded
- Inline FX rates (e.g., `amount * 1.08`) — always use CurrencyConverter
- `Math.random()` for any ID/token — use SecureRandom
- Log statements containing: `cardLast4`, `cvv`, `password`, `accountId`, `requestedBy`

## Validation
- Null checks before any field access on incoming request objects
- Amount must be > 0 and non-null
- Currency codes must be 3-char ISO 4217
- Use JSR-303 annotations (`@NotNull`, `@DecimalMin`, `@Size`) on request model fields
