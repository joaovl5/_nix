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

Use `./docs/logs` for debugging logs, research notes, incident notes, and other situation-specific knowledge that is worth keeping but not yet canonical.

Bootstrap the log with the CLI helper:

```bash
scripts/add_log.py --short-title "..." --report-brief "..."
```

The helper:

- fills `timestamp` and `date_slug`, then slugifies `short_title` into `short_title_slug`
- validates CLI input: `short_title` must be 10-96 chars, `report_brief` 30-280 chars, both single-line with no control chars, and the title must slugify to a non-empty lowercase ASCII slug
- uses raw placeholder replacement after Pydantic validation, then creates `./docs/logs/<timestamp>_<short_title_slug>.md`

After generation, fill the remaining body placeholders in `_Situation_` (`root`, `method`, `etc`, `scope`, `impact`), `_Process_` (`process`), `_Findings_` (`findings`), `_Conclusion_` (`conclusion`), and `_Next Steps_` (`next_steps`).

Keep logs detailed enough to help future correlation, but avoid filler.
