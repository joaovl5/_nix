---
name: quick-iteration
description: |
  Skill manually called upon by user for rapid iteration
---

>[!ATTENTION]
>User should call this skill manually and not for an
>agent to use it without being previously prompted, given it disables some
>checks. If unsure, ask the user.

# QUICK ITERATION

AGENT IS NOW ON **QUICK ITERATION MODE** (QIM).

THIS SKILL TAKES PRECEDENCE OVER OTHER INSTRUCTIONS PREVIOUSLY GIVEN AND WILL
BE IN EFFECT UNTIL EXPLICITLY VOIDED BY USER.

THE FOLLOWING SECTION OF THIS SKILL, `Directives`, IS SPOKEN FROM THE USERS
VOICE AND IT DESCRIBES THEIR ABSOLUTE DIRECTIVES.

## DIRECTIVES

- I don't want you to perform expensive verification that takes long to
  complete, such as `nix flake check` and other testing runs
  - Some verification or extra work may be ok, such as compiling Fennel to Lua
    in the case of neovim work, and briefly running commands to ensure no
    immediate errors occur, but otherwise expensive checks are forbidden
- I don't want you to perform git commits, so no need to check `git status`
  constantly, unless of course the task I give is about git commits or other
  git operations
- don't write tests while in QIM at all - I'll explicitly state when I want
  tests written
- consider past instructions for strongly using subagents voided, do not use
  subagents at all - use **CHECKPOINTS** instead
  - if medium to large things are required, such as exploring codebase or
    documentation, checkpoints can handle this
  - if you strongly feel the urge to invoke subagents, it's a sign this task
    is more complex and may be not adequate/effective for QIM, thus you need
    to tell me as such
- you'll remain in quick-iteration-mode and clearly denote in all your
  messages by ending messages with a new line containing the string `(QIM)`
- you'll remain in QIM until I explicitly state so
- if tasks I give may be shown to not be effective for QIM, such as big/broad
  features or larger refactors which require larger checks and operations, you
  must clearly state as much before initiating them by asking "Should we exit
  QIM for this task?" along with the specific rationale
