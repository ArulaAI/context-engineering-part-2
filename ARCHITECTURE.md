# Architecture — Context Lifecycle Lab

This document explains two things that are easy to conflate: the **Meridian payments
codebase** the lab is set inside, and the **lab tooling** (scripts, agents, skills,
hooks) built on top of it to teach the context lifecycle. Every relationship shown
below was verified directly against source — nothing here is inferred or idealized.

---

## 1. Repository layout

```
context-engineering-part-2/
├── LAB_ACTION_GUIDE.md          participant guide — the 7 stages
├── AGENTS.md                    portable instructions (Copilot + other agent tools)
├── pom.xml                      Java 17, JUnit 5, Mockito, PITest
│
├── src/main/java/com/meridian/payments/     ← the application under study (§2)
├── src/test/java/com/meridian/payments/     ← the one test file, deliberately incomplete
│
├── config/fee-schedule.yaml     authoritative fee rates — the "wins the argument" source
├── docs/adr/ADR-0007-...md      a stale, never-superseded draft rate — the seeded conflict
├── docs/JIRA_TICKETS.md         MFIN-2088 — the lab's one ticket
├── docs/VERIFICATION.md         pre-delivery checklist (automated + manual)
├── docs/TROUBLESHOOTING.md      fallbacks per stage
├── docs/verify.sh               Part A of VERIFICATION.md, automated
│
├── fixtures/sepa-implementation.diff   the seeded bug, as a patch — applied in Stage 4
│
├── scripts/                     ← the lab tooling (§3)
├── .github/agents/               3 restricted-capability Copilot agents (§3)
├── .github/skills/                4 skills, each wrapping one script (§3)
├── .github/hooks/                 SessionStart + PreToolUse enforcement (§3)
├── .github/instructions/java.instructions.md   path-scoped Java rules
│
├── .context/                    the promoted-facts register (Stage 3)
├── .workflow/                    handoff + loop state, on disk not in chat (Stage 4/5)
└── outputs/stage-readings.template.md   participant's own measurements
```

---

## 2. The Meridian payments codebase

This is the application the lab's scripts and agents operate on. It's deliberately a
mix of real dependencies, dead ones, and duplicated logic — the lab's early stages
exist specifically to teach the difference.

```mermaid
graph TB
    subgraph core["core — what PaymentService actually depends on"]
        PS[PaymentService]
        PR["PaymentRepository (interface)"]
        AS["AuditService (interface)"]
        NS["NotificationService (interface)"]
        FDS["FraudDetectionService (interface)"]
        M1[Payment]
        M2[PaymentRequest]
        M3[PaymentResult]
        FCR[FraudCheckResult]

        PS -->|constructor| PR
        PS -->|constructor| AS
        PS -->|constructor| NS
        PS -->|constructor| FDS
        PS --> M1
        PS --> M2
        PS --> M3
        FDS --> FCR
    end

    subgraph deadcode["imported but not called — the Stage 1 trap"]
        LPU["LegacyPaymentUtils<br/>Deprecated since 2014"]
    end
    PS -.->|"import present<br/>0 bytecode refs<br/>confirmed by authority.sh"| LPU

    subgraph unused["exists, correct, but PaymentService doesn't use it"]
        CC["CurrencyConverter<br/>the canonical FX converter"]
        FXP["FxRateProvider (interface)"]
        CC --> FXP
    end
    PS -.->|"duplicates this logic inline instead<br/>tech debt, documented in its own header"| CC

    subgraph noise["account/, auth/, reporting/ — unrelated to this lab's scenario"]
        AC[AccountController]
        AUC[AuthController]
        RG[ReportGenerator]
    end

    classDef real fill:#d4edda,stroke:#28a745,color:#000
    classDef dead fill:#f8d7da,stroke:#dc3545,color:#000
    classDef unused_style fill:#fff3cd,stroke:#ffc107,color:#000
    classDef noise_style fill:#e2e3e5,stroke:#6c757d,color:#000
    class PS,PR,AS,NS,FDS,M1,M2,M3,FCR real
    class LPU dead
    class CC,FXP unused_style
    class AC,AUC,RG noise_style
```

**Reading this diagram is Stage 1's whole lesson.** `grep` finds `LegacyPaymentUtils`
three times in `PaymentService.java` (an import, two comments) and looks like a live
dependency. `jdeps` — reading bytecode, not text — finds zero. The dashed red edge is
that gap made visible: text-tier evidence says one thing, bytecode-tier evidence says
another, and the compiler is right.

The dashed amber edge (`PaymentService` → `CurrencyConverter`) is a different kind of
gap: `CurrencyConverter` is real, correct, and unused — `PaymentService.processPayment()`
duplicates its FX conversion logic inline instead, a real bug pattern (magic numbers
`USD_TO_EUR = 0.92` etc.) that has nothing to do with the compiler being wrong.

---

## 3. The lab tooling: scripts → skills → agents → hooks

Four layers sit on top of the codebase above. Each script does one deterministic thing;
skills wrap a script in a `context: fork` boundary so its output — not its execution —
is what enters the conversation; agents wrap skills behind a restricted tool list; hooks
enforce a couple of the same rules at the tool-call level, independent of any agent.

Every box in the "tools" cluster below is something the JDK, Maven, or git already
provide. Nothing here shells out to Python, or to anything else that isn't already a
prerequisite for building Java with Maven — deliberate, since this lab's actual audience
is Java engineers, not people who happen to have a Python environment set up.

```mermaid
graph LR
    subgraph tools["what gets shelled out to"]
        MVN[mvn]
        JDEPS[jdeps / javap]
        JSHELL[jshell]
        GIT[git]
    end

    subgraph scripts["scripts/ — deterministic, no model involved"]
        VS[verify.sh]
        AS2[authority.sh]
        DS[digest.sh]
        OS[outline.sh]
        TGS[test-gap.sh]
        MS[mutation.sh]
        LS[loop.sh]
        CMS[context-map.sh]
        CRS[context-run.sh]
        CFS[context-for.sh]
        VCS[verify-change.sh]
    end

    VS --> MVN
    AS2 --> GIT
    AS2 --> JDEPS
    DS --> JDEPS
    MS --> MVN
    CRS --> MVN
    CRS --> GIT
    LS -.->|"VERIFY_CMD env var —<br/>defaults to verify.sh,<br/>Stage 5 overrides it"| VS
    LS -.-> VCS
    VCS --> VS
    VCS --> AS2
    VCS --> JSHELL
    VCS --> GIT

    subgraph skills[".github/skills/ — context: fork"]
        SK1[context-map]
        SK2[context-run]
        SK3[context-package]
        SK4[verify-change]
    end
    SK1 --> CMS
    SK2 --> CRS
    SK3 --> CFS
    SK4 --> VCS

    subgraph agents[".github/agents/ — restricted tools"]
        AG1["sepa-investigator<br/>search, read, runCommands<br/>NO edit"]
        AG2["sepa-implementer<br/>search, read, edit, runCommands"]
        AG3["sepa-reviewer<br/>search, read, runCommands<br/>NO edit"]
    end
    AG1 -.->|invokes| SK1
    AG1 -.->|invokes| SK3
    AG2 -->|"edits src/, runs"| LS
    AG3 -.->|invokes| SK4

    subgraph hooks[".github/hooks/ — enforced regardless of agent"]
        H1[session-constraints.sh<br/>SessionStart]
        H2[quiet-build.sh<br/>PreToolUse: denies raw mvn]
        H3[loop-bound.sh<br/>PreToolUse: denies edit past STOP]
    end
    H2 -.->|forces use of| VS
    H3 -.->|reads| LS

    classDef script fill:#d1ecf1,stroke:#0c5460,color:#000
    classDef skill fill:#d4edda,stroke:#28a745,color:#000
    classDef agent fill:#fff3cd,stroke:#856404,color:#000
    classDef hook fill:#f8d7da,stroke:#721c24,color:#000
    class VS,AS2,DS,OS,TGS,MS,LS,CMS,CRS,CFS,VCS script
    class SK1,SK2,SK3,SK4 skill
    class AG1,AG2,AG3 agent
    class H1,H2,H3 hook
```

**Why `sepa-investigator` has no `edit` in its tool list isn't a convention — it's the
whole point of Stage 4.** An instruction not to edit is a request the model could ignore
mid-task. A tool that's absent from the frontmatter is a capability that doesn't exist.
`sepa-reviewer` is restricted the same way, for the same reason, one stage later.

---

## 4. Data flow across the 7 stages

This is the actual sequence of artifacts, not the narrative — what gets written, where,
and what reads it back.

```mermaid
sequenceDiagram
    participant Ticket as docs/JIRA_TICKETS.md<br/>(MFIN-2088)
    participant Map as context-map.sh
    participant Config as config/fee-schedule.yaml
    participant ADR as docs/adr/ADR-0007
    participant Register as .context/<br/>context-register.yaml
    participant Package as context-for.sh<br/>output
    participant Investigator as sepa-investigator
    participant Handoff as .workflow/HANDOFF.md
    participant Human
    participant Implementer as sepa-implementer
    participant Verify as verify-change.sh
    participant RepairLoop as loop.sh
    participant Reviewer as sepa-reviewer<br/>(new chat)

    Ticket->>Map: Stage 1 — "SEPA"
    Map->>Config: finds the rate
    Map->>ADR: finds a DIFFERENT rate
    Map-->>Investigator: routing table, not an answer

    Note over Register: Stage 3 — promote only<br/>verified facts + decisions
    Register->>Package: Stage 3 — filtered by work-unit tag

    Package->>Investigator: Stage 4.1 — search+read only
    Investigator->>Human: CONTEXT CONFLICT — config vs ADR<br/>(cannot resolve itself: no edit tool)
    Human->>ADR: marks Status: Superseded (a real file edit)
    Human->>Investigator: conflict resolved
    Investigator->>Handoff: writes handoff (only after the decision)

    Handoff->>Implementer: Stage 4.4 — handoff only,<br/>NOT the investigation chat
    Implementer->>Implementer: git apply fixtures/sepa-implementation.diff<br/>(the seeded bug)
    Implementer->>Verify: Stage 5.2
    Verify--xImplementer: FAIL — amount compared to 2.00,<br/>not the computed fee
    Implementer->>RepairLoop: Stage 5.3 — VERIFY_CMD=verify-change.sh
    RepairLoop--xImplementer: exit 4 — thrashing (identical verdict)
    Implementer->>Implementer: fix: compare computed fee
    Implementer->>RepairLoop: retry
    RepairLoop->>Implementer: exit 0 — DONE

    Handoff->>Reviewer: Stage 5.1 — diff + ticket + config ONLY,<br/>no inherited reasoning
    Reviewer->>Reviewer: computes calculateFee(100.00,"SEPA")<br/>by hand — catches the same bug
```

**The two verification paths in Stage 5 are deliberately redundant, not sequential.**
`sepa-reviewer` catches the bug by reasoning from a curated package; `verify-change.sh`
catches the identical bug by actually calling the compiled method through `jshell`. The
lab pairs them because a comment can correctly describe a rule while the code next to it
violates it — recall isn't adherence, so neither check substitutes for the other.

---

## 5. `loop.sh`'s state machine

The bound that governs Stage 5.3, independent of which verifier it's wrapping:

```mermaid
stateDiagram-v2
    [*] --> READY: loop.sh reset
    READY --> CONTINUE: check → verifier FAILs,<br/>attempts < max (exit 1)
    CONTINUE --> CONTINUE: check → FAILs again,<br/>new verdict, attempts < max (exit 1)
    CONTINUE --> STOP_THRASHING: check → IDENTICAL verdict hash<br/>as a prior attempt (exit 4)
    CONTINUE --> STOP_BUDGET: check → FAILs,<br/>attempts == max (exit 5)
    CONTINUE --> DONE: check → verifier PASSes (exit 0)
    READY --> DONE: check → verifier PASSes (exit 0)
    STOP_THRASHING --> [*]: escalate to human
    STOP_BUDGET --> [*]: escalate to human
    DONE --> [*]
```

State lives in `.workflow/state.json` — a file, not the model's memory. `loop-bound.sh`
(a hook) reads the same file and denies further edit tool calls once `status` reaches
either `STOP_*` value, which is the difference between *the agent is told to stop* and
*the agent cannot proceed* — the same rule enforced at two different rungs.

---

## Known gaps in this document's subject matter

This architecture is accurate to what's built, not a claim that what's built is bug-free.
See the lab's own `docs/TROUBLESHOOTING.md` and the project history for known issues,
including: `context-run.sh search`'s dedup can silently drop a second genuine hit in the
same file, and `context-map.sh`'s test-file check doesn't strip comments the way
`test-gap.sh` (its sibling script) insists on doing. Both are real, open, and not yet fixed.

---

*Copyright 2026 Arula.AI (InRhythm Arula Labs). All Rights Reserved. | Internal - Confidential*
