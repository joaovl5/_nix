---
name: developing-with-den
description: Use when editing, reviewing, or designing Den configuration in this repo, including aspects, hosts, namespaces, schema, quirks, policies, classes, or Den-backed flake outputs
---

# Developing with Den

## First moves

- **Ground in repo state:** read the exact files you will touch before
  assuming a pattern
- **Check Den source when behavior matters:** resolve
  `(import ./inputs.nix).den.outPath` and read the pinned docs/source
- **Keep migrations small:** change one Den concern at a time and
  preserve host behavior
- **Avoid legacy roots:** do not reintroduce removed trees such as
  `_modules/`, `_lib/`, `systems/`, `users/`, `hardware/`,
  `packages/`, `outputs/`, `overlays/`, or `microvms/`

## Concept map

- **Aspects:** behavior units with class configs, includes, child
  aspects, `provides`, and `._`; see `references/aspects.md`
- **Entities/schema:** host/user/home data and typed metadata; see
  `references/entities-schema.md`
- **Namespaces:** aspect libraries under `den.ful.<name>` with
  module-arg aliases; see `references/namespaces.md`
- **Quirks/policies:** structured data pipes and topology/routing
  effects; see `references/quirks-policies.md`
- **Classes:** Nix module evaluation domains like `nixos` and
  `homeManager`; see `references/classes.md`

## Editing rules

- **Context vs module args:** `{ host, user, ... }` are Den context
  args; `{ config, pkgs, lib, ... }` inside `nixos`/`homeManager` are
  Nix module args
- **Prefer references over memory:** Den has active behavior that may
  be underdocumented upstream, especially child-aspect `._`
- **Keep options intentional:** use schema for entity metadata, quirks
  for internal data flow, and NixOS/HM options for final module
  interfaces
- **Verify narrowly:** run targeted host/check evals that cover the
  touched concern; avoid broad gates in quick-iteration mode
