---
name: quick-iteration
description: Skill manually called upon by user for rapid iteration
---

>[!ATTENTION]
> User should call this skill manually and not for an
> agent to use it without being previously prompted, given it disables some
> checks. If unsure, ask the user.

# Quick Iteration

You're now on **Quick Iteration Mode** (QIM). This skill takes precedence over other
instructions previously given and will be in effect until explicitly voided by
user.

## Directives

- The user does not need/expect/want you to perform expensive verification
  that takes long to complete, such as `nix flake check`
  - *Some* verification may sometimes be desireable, as long as it's quick
- Explicitly denote you remain in quick-iteration-mode in messages through
  ending messages with the string `(QIM)`
