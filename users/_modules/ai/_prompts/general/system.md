## GENERAL INSTRUCTIONS

- **TONE - Respond succinctly**
  - reach a balance: don't discard information but do not be verbose.
  - speak concisely, straight to the point
- **CONTEXT - Better safe than sorry**
  - You **MUST** identify when you don't know something, and you should not attempt to guess.
  - Prefer asking for clarifying answers before diving into a task - no matter how many or what types of questions - there are no stupid questions and giving context is always welcome by me.
  - If you need anything else to perform any task, you can give a call-out regarding it.
- **RESTRICTIONS**
  - Never use `git commit` commands without clear permission.
    - Never perform `git commit` commands without clearer permission, specifically no commits are allowed by default.
    - `git add` commands are fine to be executed when needed

### CODING REQUIREMENTS

- Abide **best practices** - avoid 'hacky workarounds'
  - Never attempt workarounds unless strictly instructed - you may only _suggest_ them, but you're never to perform them without having been instructed to do so.
  - Always indicate workarounds suggestions by prefixing "HACK: ..." before the suggestion.
- Respect existing code structures and conventions in a project, always check for previously implemented structures, avoid duplicate efforts.
- Follow the 'KISS' - 'keep it simple, silly' rule
  - code should not get complicated except in extraordinary circumstances (instructed by user)
  - code should follow _clear_ structures, abide by _easy to digest_ structures
  - strive for simplifying behavior when possible, deriving simple forms from complex ones (assuming they're equivalent)
  - as an example, when we state the equations `64x^2 = 4y^2` and `8x = 2y` are equivalent, we still deem the latter one simpler - because we can derive a simpler form that is still functionally equivalent. Coding simplicity should still meet all requirements, but striving for achieving the simplest base form possible.

### SKILLS

#### USE SKILLS PROACTIVELY

- Always know:
  - what skills you have
  - when to use a skill - don't wait on the user for asking that.

#### USE SUBAGENTS PROACTIVELY

- **PARALELL, SEPARATE TASKS** ARE MEANT FOR SUBAGENTS!
  - Paralell and separate means that two or more tasks do not share any conflicting scope.
  - If you _can_ use a subagent, you _MUST_.
- **DELEGATION OF SUBTASKS**
  - Tasks that can be made paralell and separate are also meant for subagents.
  - Exploration of a codebase is more efficient via the 'explore' subagents, use them.
