---
name: self-improvement
description: Use when a non-trivial task yields reusable wisdom, a post-mortem, or other notable lessons. MUST use after critical incidents and hard-won resolutions.
---

# Self Improvement

Use this after a non-trivial task yields either:

- **REUSABLE WISDOM:** update canonical knowledge
  - **A:** update an existing skill at `./.agents/skills`
  - **B:** update existing documentation at `./docs/wip`
  - **C:** create a new skill
  - **D:** create new documentation
- **EPHEMERAL KNOWLEDGE:** store situation-specific but useful context
  - **E:** add a log at `./docs/logs`

Use the decision guide below, and remember multiple actions may apply:

```text
IF <critical environment incident>:
    (E)

IF <non-trivial reusable wisdom>:
    IF <fits existing skill>:
        (A)
    ELIF <reusable for future agents and not situation-specific>:
        (C)

    IF <fits existing docs>:
        (B)
    ELIF <reusable for agents/users and not situation-specific>:
        (D)

IF <useful but situation-specific>:
    (E)
```

## Shared Principles

- **STRUCTURE:** prefer the smallest structural update that fits the new knowledge.
- **CONCISENESS:** keep the skill/doc update short; only logs should expand when detail is useful.
- **SKILLS:** use supporting skills when relevant (for example `superpowers:writing-skills`).

## A) Updating existing skills

Update an existing skill when the new wisdom already fits there. Prefer extending the current skill over creating a near-duplicate.

## B) Updating existing documentation

Update existing documentation when it is the best long-term home for the new knowledge.

## C) Creating new skills

Only create a new skill when:

- [ ] No existing skill already covers the subject.
- [ ] The skill is reusable for future agents and is not situation-specific.

## D) Creating new documentation

Only create new documentation when:

- [ ] No existing documentation page can absorb it, even with restructuring.
- [ ] The documentation is reusable and relevant to both agents and users.

## E) Logging ephemeral knowledge

Use `./docs/logs` for incident reports, debugging logs, research notes, and other situation-specific knowledge that is worth keeping but not yet canonical.

Bootstrap the log with the CLI helper:

```bash
scripts/add_log.py --short-title "..." --report-brief "..."
```

The helper:

- fills `timestamp` and `date_slug`
- validates the provided inputs
- sanitizes `short_title` into `short_title_slug`
- creates `./docs/logs/<timestamp>_<short_title_slug>.md`

After generation, fill the remaining body placeholders:

- _Situation_
  - `(root)` — 1-50 chars — trigger/root cause. Example: `stale secret`, `bad deploy`, `N/A` when unknown or not applicable.
  - `(method)` — 1-50 chars — how it surfaced. Example: `user report`, `automatic alert`, `manual check`.
  - `(etc)` — 1-100 chars — extra trigger context when useful.
  - `(scope)` — 1-100 chars — affected area. Example: `CI deploy pipeline`, `postgres backups`, `N/A`.
  - `(impact)` — 1-100 chars — severity/effect. Example: `prod deploys blocked`, `minor dev-only regression`, `N/A`.
- _Process_
  - `(process)` — any length — key commands, investigation steps, iteration notes, and other useful context.
- _Findings_
  - `(findings)` — any length — evidence-backed findings; this is usually the core output of the log.
- _Conclusion_
  - `(conclusion)` — any length — what was done, current status, blockers, and immediate outcome.
- _Next Steps_
  - `(next_steps)` — any length — remediation, follow-up, prevention, or recommendations.

Keep logs detailed enough to help future correlation, but avoid filler.
