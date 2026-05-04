---
name: skill-authoring
description: Use when creating, editing, or reviewing repo-local skills under `.agents/skills` in this repo; covers overlap checks, concise skill structure, verification, and skill-specific testing
---

Use this for repo-local skill work in `./.agents/skills/`. It is the repo authority for that scope

## First decisions

- **Scope:** confirm target is a skill in `./.agents/skills/`
- **Overlap:** search repo skills first, extend an existing one when it fits
- **Evidence:** ground claims in files and primary or upstream sources
- **Boundary:**
  - keep `SKILL.md` slim and operational
  - move long examples, checklists, and subject-specific detail into `references/`
- **Paths:** use skill-relative paths like `scripts/foo.py` and `references/bar.md`
- **Scripts:**
  - write helpers with `uv run --script`, not plain `python`
  - run helpers with `uv run ...`, not `python ...`

## Style rules

- **Bullets:**
  - keep to 1-2 short sentences
  - split longer points into sub-bullets
  - use bold lead-ins with the colon inside, then keep the next word lowercase when natural
  - don't end bullets with periods unless code or a quote needs one
- **Language:** cut filler, prefer short words, sacrifice grammar for brevity
- **Repeats:** say each rule once, link to references instead of restating

## Editing skills

- **Context:** check repo reality, then read `SKILL.md` and sources before changing behavior
- **Extract:** move growing sections into `references/` and leave a short pointer

## Creating skills

- **Need:** confirm no existing repo skill already fits
- **Trigger:** start the frontmatter description with `Use when...`
- **Base:** keep the main skill to purpose, rules, workflow, and checks
- **Support:** add `references/` or `scripts/` only when they cut clutter or save time

## Testing

- **Process skills:** use pressure-scenario or TDD testing
  - capture baseline failure
  - add the minimum guidance
  - re-test until the loophole closes
- **Reference skills:** prefer source verification and review
- **Scripts:** run script checks and lints

## References

- **Testing:** `references/testing-process-skills.md` covers behavior-changing skills
