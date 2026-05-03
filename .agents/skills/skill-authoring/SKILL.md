---
name: skill-authoring
description: Use when creating, editing, or reviewing repo-local skills under `.agents/skills` in this repo; covers overlap checks, concise skill structure, verification, and skill-specific testing.
---

Use this for repo-local skill work in `./.agents/skills/`. It is the repo authority for that scope.

## First decisions

- Confirm the target is a repo-local skill in `./.agents/skills/`.
- Search existing repo-local skills before creating a new one. If the need fits an existing skill, extend that skill instead of creating a near-duplicate.
- Ground every factual claim in current repo files and primary or upstream sources when external behavior is involved. If something is uncertain, say so.
- Keep `SKILL.md` operational. Push long examples, detailed checklists, and deeper background into `references/`.
- Skill docs may refer to local files as `scripts/foo.py` and `references/bar.md`; the harness resolves skill-relative paths.
- Executable helper scripts in skills should prefer `uv run --script` and PEP 723-style metadata when practical, matching existing skill-local helpers.

## Editing an existing skill

- Read the current `SKILL.md` and any referenced files before changing behavior or guidance.
- Verify the skill still matches current repo reality, scripts, and workflows.
- Fix focused high-confidence or medium-confidence issues directly.
- If a section is becoming long, move the detail into `references/` and leave a short pointer.
- Preserve valid frontmatter with only `name` and `description`.

## Creating a new skill

- Confirm no existing repo-local skill already covers the job.
- Write a trigger-focused description that starts with `Use when...` and makes the activation boundary obvious.
- Keep the base skill short: what it is for, the core rules, the main workflow, and the required checks.
- Add `references/` or `scripts/` only when they reduce clutter or carry real operational weight.
- Do not rely on same-name shadowing of external skills.

## Testing and verification

- Treat discipline or process skills as behavior-changing artifacts: run pressure-scenario/TDD testing. Capture baseline behavior without the skill, add the minimum guidance that closes the failure, then re-test with the skill.
- For pure reference skills, source verification and review are the primary quality gates; pressure-scenario testing is optional.
- Syntax-check every script added to a skill.
- After changes, run repo checks in this order: `nix fmt`, `git add .`, `prek`.
- Run `nix flake check --all-systems` only when Nix files changed.
- Do not commit unless the user or task explicitly permits it.

## Common mistakes

- Guessing instead of checking current files or upstream docs.
- Turning `SKILL.md` into a long manual instead of a quick operational guide.
- Creating a new skill when a targeted update to an existing one would do.
- Leaving skill-specific scripts unchecked.
- Editing low-confidence issues without either verifying them or asking the user.

## References

- `references/testing-process-skills.md`: compact workflow for pressure-scenario/TDD testing of behavior-changing skills.
