---
name: self-improvement
description: Use when a non-trivial task yields reusable wisdom, a post-mortem, or other notable lessons. MUST use after critical incidents and hard-won resolutions.
---

# Self Improvement

Use this after a non-trivial task yields either:

- **Reusable wisdom:** update canonical knowledge
  - **Existing skill:** update `./.agents/skills`
  - **Existing docs:** update `./docs/wip`
  - **New skill:** create one only if no current skill fits
  - **New docs:** create them only if no current page can absorb the change
- **Ephemeral knowledge:** store situation-specific context in `./docs/logs`

Use the guide below; more than one action may apply:

```text
if (useful but situation-specific) or (critical environment incident) -> (E)
if (non-trivial reusable wisdom) ->
    if (fits existing skill) -> (A)
    elif (reusable for future agents) and (not situation-specific) -> (C)

    if (fits existing docs) -> (B)
    elif (reusable for agents/users) and (not situation-specific) -> (D)
```

## Shared principles

- **Scope:** prefer the smallest structural update that fits the new knowledge
- **Concision:** keep skill and doc updates short, logs may stay detailed when detail helps
- **Skill support:** use supporting skills when relevant

## Procedures

- **(A) Updating skills:** when new wisdom fits a skill, extend it instead of creating a near-duplicate
- **(B) Updating docs:** use when an existing doc is the best long-term home
- **(C) Adding skills:** only when
  - **Gap:** no current skill covers the subject
  - **Reuse:** it will be reusable later, not situation-specific
- **(D) Adding docs:** only when
  - **No fit:** no current page can absorb it, even after restructuring
  - **Shared value:** it matters to agents and developers
- **(E) Logging ephemeral knowledge:** use for debugging logs, research notes, incident reports, and other situation-specific material worth keeping
  - **Location:** `./docs/logs`
  - **Adding a log:** bootstrap it with the helper
    - **Command:** `uv run scripts/add_log.py --short-title "..." --report-brief "..."`
    - **Auto-filled:** `timestamp`, `date_slug`, and slugified `short_title_slug`
    - **Validated:**
      - `short_title` must be 10-96 chars and single-line
      - `report_brief` must be 30-280 chars and single-line
    - **Output:** generated log path
    - **After running:**
      - use template comments as the basis for filling placeholders
      - remove the comments after filling every placeholder
      - keep logs detailed enough for future correlation, but cut filler
