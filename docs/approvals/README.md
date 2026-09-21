# `docs/approvals/`

Approved business records live with the organization that owns them, not in this repository.

When a decision needs one, retrieve it at that point:

```
./scripts/request-approval.sh <WORK-ITEM>
```

The record is written here for the rest of your run and is gitignored — committing it would
place the owner's decision in every clone before anyone had asked for it.
