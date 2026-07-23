---
name: using-tmp-docs
description: |
  ALWAYS load when working with folders named 'tmp-docs', or when the
  user specifies 'tmp-docs'
---

# `tmp-docs` Strategies

## What it is

`tmp-docs` are intentionally git-ignored folders for working with
draft notes and files otherwise not meant for general repository
availability. They serve as a rough knowledge-base and documentation
hub for self-organizing, but they're not notes "ready" and reviewed
for being made public.

- **Location:** at `./tmp-docs/` from the root of the repository
  - If it does not already exist, create it along with a file in
    `./tmp-docs/.gitignore` with the contents of `*`
  - If in a worktree (that isn't the main one), don't create
    a worktree-specific folder - instead, symlink it to the main
    worktree's `tmp-docs` (create it if non-existing) and add it to
    `.git/info/exclude`
