# Frag NixOS Runtime Redesign

## Goal

Redesign `frag` so desktop profile containers run on a real NixOS-derived Docker image instead of the current package-closure image, while fixing the current state/home/runtime model that breaks tools like OMP.

## Why redesign

The current model has two structural problems:

1. The runtime image is built from `dockerTools.buildLayeredImage` as a package closure, not as a NixOS system image.
2. `frag` currently makes `/home/agent` tmpfs-backed, which causes executable runtime state like `~/.omp` native addons to be loaded from a noexec location in practice.

This leads to weak system reproducibility and real runtime failures.

## Chosen direction

Keep `frag` as the host-side Docker orchestrator, but replace its runtime image with a dedicated NixOS-derived Docker image.

The split becomes:

- `frag` Python app: profile selection, UX, validation, Docker orchestration
- dedicated NixOS config: runtime system definition
- Docker: execution substrate only
- profile volume: mutable identity/config/state

## Rejected alternatives

### Keep the current package-closure image

This is acceptable only as a short-term patch path. It does not provide the desired NixOS-level guarantees and is likely to keep producing system-layout edge cases.

### Switch away from Docker entirely right now

Native NixOS containers or VMs may still be relevant later, but they change the desktop workflow more than desired for the current direction.

## Architecture

### Runtime image

`frag` should use one main Docker image for v1, but that image should come from a real NixOS configuration/rootfs artifact rather than `dockerTools.buildLayeredImage` alone.

Expected properties:

- real NixOS users/groups/system layout
- coherent `/etc`
- explicit runtime packages/services configured from NixOS modules
- reproducible root filesystem artifact that `frag` imports into Docker

### Host wrapper

`frag` remains responsible for:

- profile management
- workspace-root validation
- image import / freshness checks
- container create/reuse/stop
- Rich-based status output
- user-facing error reporting

### Packaged runtime artifact contract

The redesign keeps the current installed-package discovery shape, but changes what the image loader imports.

The installed `packages/frag` output must continue to expose:

- `share/frag/catalog.json`
- `share/frag/helpers/<loader>`
- `share/frag/shared-assets/...`

The difference is that each loader helper now imports a NixOS-derived Docker/rootfs artifact instead of the current package-closure tarball. The host wrapper continues to resolve the runtime strictly through this packaged contract.

### Bootstrap

Bootstrap remains a small runtime initializer, but it should no longer simulate an entire home via tmpfs and heavy symlink projection. Its job should be limited to:

- ensuring profile state structure exists
- ensuring permissions/ownership are correct
- wiring shared read-only assets where needed
- finalizing runtime readiness

## State model

### Persistent state

The profile volume becomes the real writable state root.

This redesign defines a new incompatible profile/container schema: `frag.schema_version = "2"`. Existing schema `1` profiles and containers must be treated as legacy and refused by default in v1 of the redesign; automatic migration is out of scope for the first implementation pass.

Schema `2` profile metadata must persist enough information for discovery and reuse checks. The contracts split into stable profile metadata and mutable runtime metadata.

Stable profile metadata must live in the volume labels and in `meta/profile.json`:

- profile name
- logical image key (for example `main`)
- workspace root
- schema version (`2`)

Mutable runtime metadata such as the exact current `image_ref` and packaged shared-assets identity must not live in Docker volume labels. Those belong in `meta/profile.json` and on the running container labels, where they can change across runtime updates without forcing volume replacement.

Recommended canonical layout:

```text
/state/profile/
  meta/
    profile.json
    bootstrap-token
    bootstrap-status.json
  home/
    .code/
    .omp/
    .agent-browser/
    .config/opencode/
  notes/
  data/
```

### Home model

The canonical persistent home data lives under `/state/profile/home`. `/home/agent` is not a second independent writable mount. Instead, the image itself must bake `/home/agent` as a symlink to `/state/profile/home`, so the read-only root filesystem remains compatible with the runtime mount model and bootstrap does not need to mutate `/home` at startup.

Recommended runtime mounts:

- profile volume -> `/state/profile`
- trusted workspace root bind -> `/workspace-root`
- tmpfs only for `/tmp` and `/run`

For v1, `~/.cache` is explicitly **not** persistent even though `/home/agent` points at the persistent profile home. Bootstrap must redirect `~/.cache` to an ephemeral tmpfs-backed location (for example under `/run/frag-cache` or `/tmp/frag-cache`) so normal config/state lives in the profile volume while caches remain disposable by default.

### Read-only shared assets

Declarative shared assets should still be mounted read-only from packaged/shared locations, but only for the assets that are truly shared:

- prompts
- skills
- system prompt files
- packaged shared config payloads

These should be mounted into stable internal paths and linked/configured into the runtime only where needed.

### Key rule

Executable writable state such as `~/.omp` must not live on tmpfs.

## Identity model

The container must have a real user identity, not only a numeric uid.

Chosen contract:

- the NixOS image defines a real `agent` user and group
- home is `/home/agent`
- passwd/group entries exist inside the image
- the root filesystem remains read-only
- bootstrap starts as `root` on first container start
- bootstrap generates a writable identity overlay under `/run/frag-identity` (or an equivalent tmpfs-backed runtime location) rather than mutating `/etc/passwd` in place
- that overlay must represent the `agent` account with the caller uid/gid for the current profile session
- later interactive and command execs run with the caller uid/gid plus that identity overlay, so user-facing tools resolve the session as `agent` while workspace writes still land with host-compatible ownership

Desired outcomes:

- `whoami` works
- workspace bind writes remain owned correctly on the host
- shell tools and prompts behave like a normal user environment

## Execution flow

### `frag enter`

Expected flow:

1. resolve or prompt for profile
2. validate cwd is under that profile's trusted workspace root
3. resolve the packaged runtime artifact from `share/frag/catalog.json`, `share/frag/helpers`, and `share/frag/shared-assets`
4. ensure the Docker image identified by the packaged catalog is imported and current
5. inspect whether the profile container is already running and valid
6. if not running:
   - import image if needed
   - start container
   - wait for bootstrap/readiness
7. exec into the running container

### Reuse behavior

If the profile container is already running and matches the expected metadata, `frag` should reuse it with `docker exec`. Reuse validation must include at least:

- profile name
- schema version (`2`)
- exact packaged `image_ref` from the catalog
- workspace-root bind/mount identity
- packaged shared-assets identity

Legacy schema `1` volumes or containers are not eligible for automatic recreation; they are a hard error and must be refused with an actionable message. Automatic recreation only applies to schema `2` containers that drift from the current packaged metadata (for example a newer `image_ref` or shared-assets identity).

### Startup UX

Use Rich for phase output. Minimum statuses:

- `Loading image…`
- `Starting container…`
- `Waiting for bootstrap…`
- `Reusing running container…`

### Image freshness contract

The packaged catalog must expose an exact `image_ref` for each image key, and that ref must be content-addressed or otherwise immutable for a specific runtime artifact build. The loader helper imports that exact image ref. The packaged runtime must also expose a stable shared-assets identity. Container labels must record both the exact `image_ref` and the shared-assets identity, and any mismatch against the current packaged catalog/runtime artifact must force schema-2 container recreation rather than reuse.

## Error handling

Errors must be visible and categorized.

At minimum:

- usage errors
- profile errors
- image import/build errors
- runtime/container errors
- bootstrap errors

Rules:

- actionable error text goes to stderr
- no blank nonzero exits
- no raw tracebacks for normal user-facing failures

### Bootstrap failure behavior

Do not collapse all bootstrap problems into a generic timeout.

Bootstrap must communicate readiness and failure explicitly through profile metadata:

- on success: write the current bootstrap token
- on failure: write `/state/profile/meta/bootstrap-status.json` with at least `status`, `phase`, `message`, and the current bootstrap token

Bootstrap must clear or reset any previous `bootstrap-status.json` record at the start of a new startup attempt so stale failures cannot poison the next run.

If readiness fails, `frag` should inspect container state in this order:

1. if the container exited, surface recent logs and bootstrap status if present
2. if `bootstrap-status.json` reports error for the current bootstrap token while the container is still running, surface that message directly
3. only then fall back to a timeout-style message if no stronger signal exists

## Testing expectations

The redesign should be verified at four levels.

### Unit tests

For:

- profile selection
- path validation
- runtime command construction
- bootstrap initialization
- error rendering

### Packaging tests

For:

- NixOS-derived image artifact exists
- packaged shared assets exist
- image import helper/path works

### Integration tests

Using a built local wrapper:

- create profile
- list profile
- enter profile
- run `whoami`
- run `pwd`
- verify workspace writes
- verify a real runtime tool like `omp` starts correctly
- write state under a real home path such as `~/.omp` or `~/.config/opencode`, stop the container, restart it, and confirm that state persists
- verify shared packaged assets remain external/read-only and were not copied into the profile volume

### Regression tests

Specifically preserve fixes for:

- installed-vs-inner-wrapper asset lookup
- empty-state/profile UX
- workspace mismatch messages
- missing-profile messages
- container reuse and stale-container recovery
- legacy schema `1` profile/container refusal under the new runtime

## Implementation notes

The current `frag` source location should remain:

- `_scripts/frag`

Nix derivations can remain under:

- `packages/frag`

But the runtime image definition should move away from the current package-bundle image model and be driven by a dedicated NixOS runtime configuration.

## Open questions

1. Exact repo placement of the dedicated frag NixOS runtime configuration
2. Whether additional tool bundles belong in the v1 image or in later variants

## Recommended next step

Write an implementation plan for migrating `frag` from the current package-closure runtime to a NixOS-derived Docker runtime, including the new home/state model and the Rich startup UX.
