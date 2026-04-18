# Frag NixOS Runtime Redesign Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate `frag` from the current package-closure Docker runtime to a NixOS-derived Docker runtime with a persistent real home, executable profile state, Rich startup feedback, and explicit failure reporting.

**Architecture:** Keep `_scripts/frag` as the host-side Python orchestrator and `packages/frag` as the packaging home, but replace the current `dockerTools.buildLayeredImage` package-bundle runtime with a dedicated NixOS runtime artifact and import helper. Persist schema-2 profile state under `/state/profile`, expose `/home/agent` as an image-baked symlink to `/state/profile/home`, and make runtime/container reuse depend on exact packaged image/shared-asset identities instead of the current looser contract.

**Tech Stack:** Python (`cyclopts`, `questionary`, `rich`, `pytest`), NixOS module evaluation, Docker import/load helpers, rootless Docker runtime, Nix packaging under `packages/frag`.

**Repo policy note:** Do **not** include `git commit` steps during execution. The user does not want commits by default.

---

## File Structure

### Create

- `packages/frag/runtime-system.nix` — dedicated NixOS runtime definition for the frag container image/rootfs
- `_scripts/frag/src/frag/ui.py` — Rich status/error rendering helpers for startup phases and actionable failures
- `_scripts/frag/tests/test_image_assets.py` — package/runtime artifact contract tests separated from CLI behavior

### Modify

- `packages/frag/images.nix` — switch from package-closure image to NixOS-derived runtime artifact + import helper contract
- `packages/frag/default.nix` — bundle the new catalog/helpers/shared-assets contract and keep the installed package layout stable
- `packages/frag/image_catalog.nix` — carry schema-2 runtime metadata such as exact `image_ref` and shared-assets identity
- `_scripts/frag/src/frag/cli.py` — Rich startup UX, visible failure rendering, and orchestration updates
- `_scripts/frag/src/frag/image_assets.py` — resolve the packaged runtime artifact contract and expose exact runtime metadata
- `_scripts/frag/src/frag/docker_runtime.py` — container reuse checks, startup/import flow, schema-2 labels, bootstrap-state inspection
- `_scripts/frag/src/frag/bootstrap.py` — real home handling, cache redirection, bootstrap-status signaling, schema-2 metadata writes, identity overlay preparation
- `_scripts/frag/pyproject.toml` — add `rich` to the Python project dependencies used by `uv run --project _scripts/frag ...`
- `_scripts/frag/src/frag/profiles.py` — schema-2 stable profile metadata contract and legacy schema refusal behavior
- `_scripts/frag/tests/test_cli.py`
- `_scripts/frag/tests/test_docker_runtime.py`
- `_scripts/frag/tests/test_bootstrap.py`
- `packages/default.nix` only if the local attrset shape needs a small adjustment; otherwise keep unchanged
- `users/lav.nix` only if the existing private package wiring actually needs adjustment; otherwise keep unchanged

### Expected non-changes

- No public flake `outputs/apps` / `outputs/packages` exposure for frag/images
- No relocation of frag source out of `_scripts/frag`

## Chunk 1: NixOS runtime artifact and packaged contract

### Task 1: Replace the current package-closure runtime image with a NixOS-derived artifact

**Files:**

- Create: `packages/frag/runtime-system.nix`
- Modify: `packages/frag/images.nix`
- Modify: `packages/frag/image_catalog.nix`
- Test: `_scripts/frag/tests/test_image_assets.py`

- [ ] **Step 1: Write failing contract tests for the packaged runtime artifact**

Add tests that assert the packaged contract exposes enough information for the host wrapper to operate:

- `catalog.json` contains the logical image key (`main`)
- `catalog.json` contains the exact immutable `image_ref`
- `catalog.json` contains a stable shared-assets identity
- the packaged helper name/path contract still resolves from `share/frag/helpers/...`

Run:

```bash
uv run --project _scripts/frag --with pytest python -m pytest _scripts/frag/tests/test_image_assets.py -q
```

Expected: FAIL because the current package contract does not yet describe the NixOS-derived runtime artifact.

- [ ] **Step 2: Define the frag runtime as a dedicated NixOS system**

In `packages/frag/runtime-system.nix`, define the runtime system with at least:

- a real `agent` user and group
- `/home/agent` baked in the image as a symlink to `/state/profile/home`
- runtime packages needed by the container workflow (`bash`, `git`, `code`, `omp`, `agent-browser`, `opencode`, `mcp-nixos`, and any minimal supporting system packages)
- a read-only-rootfs-compatible bootstrap entrypoint path

Keep the system focused on runtime behavior only; no unrelated desktop/service modules.

- [ ] **Step 3: Replace `packages/frag/images.nix` with the NixOS-derived artifact path**

Modify `packages/frag/images.nix` so it no longer builds the current package-only runtime image directly. Instead, it should:

- evaluate the NixOS runtime config
- expose the rootfs/tarball artifact used for Docker import
- define an immutable `image_ref`
- provide a helper contract that imports that artifact into Docker and prints the exact `image_ref`

- [ ] **Step 4: Update `image_catalog.nix` to describe schema-2 runtime metadata**

The catalog entry for `main` must include at least:

- logical image key
- immutable `image_ref`
- loader helper name
- shared-assets identity

- [ ] **Step 5: Run targeted packaging-contract tests**

Run:

```bash
uv run --project _scripts/frag --with pytest python -m pytest _scripts/frag/tests/test_image_assets.py -q
```

Expected: PASS.

## Chunk 2: Host-side artifact resolution and Rich UX

### Task 2: Add Rich startup UX and make the wrapper consume the new packaged runtime contract

**Files:**

- Create: `_scripts/frag/src/frag/ui.py`
- Modify: `_scripts/frag/src/frag/cli.py`
- Modify: `_scripts/frag/src/frag/image_assets.py`
- Modify: `_scripts/frag/pyproject.toml`
- Modify: `packages/frag/default.nix`
- Modify: `_scripts/frag/tests/test_cli.py`
- Modify: `_scripts/frag/tests/test_image_assets.py`

- [ ] **Step 1: Write failing tests for the new UX and runtime metadata flow**

Cover:

- `frag enter` renders phase messages with Rich for cold starts
- `frag enter` renders `Reusing running container…` for hot path reuse
- package asset resolution returns immutable `image_ref` + shared-assets identity
- user-facing parse/runtime/profile failures are still printed to stderr

Run:

```bash
uv run --project _scripts/frag --with pytest python -m pytest _scripts/frag/tests/test_cli.py _scripts/frag/tests/test_image_assets.py -q
```

Expected: FAIL.

- [ ] **Step 2: Add Rich to both frag dependency manifests**

Update both:

- `_scripts/frag/pyproject.toml`
- `packages/frag/default.nix`

so the redesign can import and package `rich` consistently in both local `uv` test runs and the installed wrapper package.

- [ ] **Step 3: Implement a small UI layer in `_scripts/frag/src/frag/ui.py`**

Add focused helpers for:

- status rendering
- warning/error rendering
- no-profile / no-workspace / legacy-schema refusal messages

Do not bury business logic in the UI module.

- [ ] **Step 4: Update `image_assets.py` for the schema-2 packaged contract**

The host wrapper must resolve from the installed package contract and expose:

- logical image key list for prompting
- exact immutable `image_ref`
- shared-assets identity
- loader helper path

Preserve the current package-owned anchor behavior; do not reintroduce ad hoc home-directory fallbacks.

- [ ] **Step 5: Update `cli.py` to use Rich phases during `enter`**

Cold start path should report:

- loading/importing image
- starting container
- waiting for bootstrap

Hot path should report reuse clearly.

- [ ] **Step 6: Re-run the CLI/image-asset tests**

Run:

```bash
uv run --project _scripts/frag --with pytest python -m pytest _scripts/frag/tests/test_cli.py _scripts/frag/tests/test_image_assets.py -q
```

Expected: PASS.

Run:

```bash
uv run --project _scripts/frag --with pytest python -m pytest _scripts/frag/tests/test_cli.py _scripts/frag/tests/test_image_assets.py -q
```

Expected: PASS.

## Chunk 3: Schema-2 state model, identity overlay, and bootstrap signaling

### Task 3: Replace the current tmpfs-home projection model with schema-2 persistent-home behavior

**Files:**

- Modify: `_scripts/frag/src/frag/bootstrap.py`
- Modify: `_scripts/frag/src/frag/profiles.py`
- Modify: `_scripts/frag/src/frag/docker_runtime.py`
- Modify: `_scripts/frag/tests/test_bootstrap.py`
- Modify: `_scripts/frag/tests/test_profiles.py`
- Modify: `_scripts/frag/tests/test_docker_runtime.py`

- [ ] **Step 1: Write failing tests for schema-2 metadata and home behavior**

Cover:

- schema-2 stable profile metadata fields in labels/profile.json
- legacy schema-1 refusal behavior
- `/home/agent` expectation aligns with `/state/profile/home`
- `docker run` no longer mounts tmpfs on `/home/agent`
- `~/.cache` is redirected to an ephemeral location
- mutable home state persists across restarts
- shared assets remain external/read-only

Run:

```bash
uv run --project _scripts/frag --with pytest python -m pytest _scripts/frag/tests/test_bootstrap.py _scripts/frag/tests/test_profiles.py -q
```

Expected: FAIL.

- [ ] **Step 2: Rework bootstrap for schema 2**

Bootstrap must:

- initialize `/state/profile/home`
- write schema-2 `meta/profile.json`
- maintain `bootstrap-token`
- clear/reset stale `bootstrap-status.json` at startup
- write token-scoped bootstrap failures to `bootstrap-status.json` with at least `status`, `phase`, `message`, and the current bootstrap token
- redirect `~/.cache` to tmpfs-backed runtime storage
- update `docker_runtime.py` so container startup mounts tmpfs only on `/tmp` and `/run`, while `/home/agent` comes from the image-baked symlink into `/state/profile/home`
- [ ] **Step 3: Implement the identity overlay contract**

Without mutating a read-only `/etc` in place, bootstrap/runtime must provide a runtime identity view where:

- the session resolves as `agent`
- the effective uid/gid matches the caller for workspace writes
- `whoami` and similar tools behave normally

Keep this implementation isolated behind a small helper boundary so it is testable and replaceable if the exact mechanism evolves.

- [ ] **Step 4: Implement runtime-side identity overlay consumption**

Update `docker_runtime.py` so both bootstrap readiness checks and normal `docker exec` paths consume the identity-overlay contract instead of relying only on bare `--user <uid>:<gid>` semantics. Add tests that cover at least:

- `whoami` resolving correctly inside the session
- host-compatible write ownership through the workspace bind

- [ ] **Step 5: Update profile discovery/validation for schema 2**

`profiles.py` should distinguish:

- stable profile metadata (labels + profile.json)
- mutable runtime metadata (exact `image_ref`, shared-assets identity)
- hard refusal of legacy schema-1 profiles/containers

- [ ] **Step 6: Re-run bootstrap/profile/runtime tests**

Run:

```bash
uv run --project _scripts/frag --with pytest python -m pytest _scripts/frag/tests/test_bootstrap.py _scripts/frag/tests/test_profiles.py _scripts/frag/tests/test_docker_runtime.py -q
```

Expected: PASS.

## Chunk 4: Runtime reuse, failure inspection, and integration verification

### Task 4: Update runtime orchestration for schema-2 reuse and bootstrap diagnostics

**Files:**

- Modify: `_scripts/frag/src/frag/docker_runtime.py`
- Modify: `_scripts/frag/src/frag/cli.py`
- Modify: `_scripts/frag/tests/test_docker_runtime.py`
- Modify: `_scripts/frag/tests/test_cli.py`

- [ ] **Step 1: Write failing runtime tests for schema-2 reuse/failure handling**

Cover:

- running-container reuse requires matching profile name, schema version, immutable `image_ref`, shared-assets identity, and workspace-root bind
- schema-1 containers are refused, not auto-recreated
- schema-2 stale containers are recreated when runtime metadata drifts
- bootstrap failure inspection reads current-token `bootstrap-status.json` before generic timeout fallback

Run:

```bash
uv run --project _scripts/frag --with pytest python -m pytest _scripts/frag/tests/test_docker_runtime.py _scripts/frag/tests/test_cli.py -q
```

Expected: FAIL.

- [ ] **Step 2: Implement schema-2 runtime reuse checks**

Update `docker_runtime.py` so reuse logic depends on the new runtime metadata contract.

- [ ] **Step 3: Implement structured bootstrap failure inspection**

If bootstrap fails, `frag` should prefer:

1. exited-container logs + status artifact
2. running-container bootstrap-status for the current token
3. timeout fallback only when no better signal exists

- [ ] **Step 4: Re-run runtime tests**

Run:

```bash
uv run --project _scripts/frag --with pytest python -m pytest _scripts/frag/tests/test_docker_runtime.py _scripts/frag/tests/test_cli.py -q
```

Expected: PASS.

### Task 5: End-to-end redesign verification and host packaging confirmation

**Files:**

- Modify only if needed based on previous tasks:
  - `packages/frag/default.nix`
  - `packages/default.nix`
  - `users/lav.nix`

- [ ] **Step 1: Confirm private package wiring still holds**

Verify that the redesign still installs through the existing private package model and does not require new public flake outputs.

- [ ] **Step 2: Run frag unit/integration suite**

Run:

```bash
uv run --project _scripts/frag --with pytest python -m pytest _scripts/frag/tests -q
```

Expected: PASS.

- [ ] **Step 3: Build the private frag wrapper and run an integration smoke test**

Build the wrapper via the repo's private package path, for example:

```bash
nix build --impure --expr 'let flake = builtins.getFlake (toString ./.); pkgs = import flake.inputs.nixpkgs { system = "x86_64-linux"; overlays = flake._channels.overlays; config.allowUnfree = true; }; in (import ./packages { inherit pkgs; inputs = flake.inputs; }).frag'
```

Using the resulting local `result/bin/frag`, verify at minimum:

- `profile new`
- `profile list`
- `enter --profile <fresh> -- whoami`
- `enter --profile <fresh> -- pwd`
- write a file through the workspace bind and confirm the host sees the expected ownership
- a real tool startup such as `omp`
- restart persistence of writable home state
- shared packaged assets remain external/read-only and are not copied into the profile volume

- [ ] **Step 4: Run repo-required verification**

Run, in this order:

```bash
nix fmt
```

Then stage only intended files for `prek`:

```bash
git add _scripts/frag packages/frag docs/superpowers/specs/2026-04-17-frag-nixos-runtime-design.md docs/superpowers/plans/2026-04-17-frag-nixos-runtime-redesign.md
```

Adjust the staged file list if execution touched additional intended files such as `packages/default.nix` or `users/lav.nix`.

Then run:

```bash
prek
```

Then run:

```bash
nix flake check
```

Expected: pass, allowing the repo's known warnings about unknown custom flake outputs and omitted incompatible systems.

## Plan review notes

- Keep `frag` source in `_scripts/frag`; do not move the application code into `packages/frag`.
- Keep private package wiring; do not introduce public flake app/package exports for frag.
- Treat schema `1` profile/container state as legacy and refuse it rather than silently mutating or reusing it.
- Keep shared assets packaged and read-only.
- Keep executable writable state off tmpfs.
- Keep `~/.cache` ephemeral for v1 even though `/home/agent` points to the persistent profile home.
