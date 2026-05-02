# Isolation / Declarative Containers Research

Date: 2026-04-16

## Goal

Research container-oriented approaches for this NixOS repo that can support:

1. Desktop isolation for AI-agent work
   - imperative entry from the current working directory
   - same project directory visible inside the container
   - minimal access to unrelated host paths
   - ability to reuse existing AI config/modules where practical
2. Desktop ephemeral cross-distro testing
3. Server-side declarative service isolation
   - declare a container with a NixOS config
   - declare mounts, ports, and related helpers in a clean repo API

This document is a research snapshot only. No implementation decisions are locked in yet.

## Current repo state

### What already exists

- Host-level virtualization/container capability is enabled in `systems/_bootstrap/host.nix`:
  - `virtualisation.containers.enable = true`
  - rootless Docker is enabled
  - `docker` and `docker-compose` are installed
- The repo already has a helper for Docker Compose-backed user services in `_lib/units/default.nix` via `make_docker_unit`.
- There is a concrete example of that pattern in `users/_units/fxsync/default.nix`.
- There is already a separate isolation/confinement pattern in `users/_units/wireguard/default.nix` using a VPN namespace approach.
- The repo already carries MicroVM support:
  - `outputs/hosts/default.nix` imports the MicroVM host module
  - `_modules/vm.nix` defines a VM variant
  - `microvms/postgres/default.nix` is a sample guest
- NVIDIA hosts already have Docker-oriented GPU container support in `hardware/_modules/nvidia.nix` via `nvidia-container-toolkit` and rootless Docker CDI.

### What does not exist yet

Repo search found no existing declarative framework using:

- `containers.<name>` native NixOS containers
- `virtualisation.oci-containers`

There is capability and precedent, but not a unified abstraction yet.

### AI module reuse caveat

Reusing the existing AI setup inside a container or guest looks plausible, but `users/_modules/ai` is not standalone today. It depends on:

- Home Manager wiring from `systems/_modules/home-manager.nix`
- user imports from `users/lav.nix`
- the `llm-agents` overlay from `outputs/channels/default.nix`
- `home/_modules/hybrid-links/default.nix`, which assumes a real repo checkout path via `hybrid-links.source_root` and `hybrid-links.source_path`

So the repo can likely reuse the same modules inside a NixOS guest, but only if the guest is wired similarly to the current user environment and can see the expected checkout path.

## Option summary

## 1. Built-in NixOS containers (`containers.<name>`)

### What they are

This is NixOS' native system-container mechanism. The guest configuration is itself a NixOS configuration/module, declared directly on the host.

### Relevant features

- `containers.<name>.config`
- `containers.<name>.bindMounts`
- `containers.<name>.forwardPorts`
- `containers.<name>.privateUsers`
- `containers.<name>.ephemeral`
- `containers.<name>.flake`

### Strengths

- Best match for "declare a container with a real NixOS config".
- Cleanest fit for server-side NixOS-in-NixOS service isolation.
- Nice declarative story for mounts, ports, networking, and guest modules.
- Good basis for a repo helper layer that exposes a higher-level API.

### Weaknesses / limits

- NixOS-only guest model; not suitable for cross-distro testing.
- Shared-kernel container isolation, not VM isolation.
- More natural for long-lived system containers than ad hoc developer shells.

### Fit for this repo

**Best server-side fit** when the guest should be a real NixOS system with declarative service configuration.

## 2. OCI containers on NixOS (`virtualisation.oci-containers`)

### What they are

NixOS module support for OCI containers, typically via Podman or Docker, managed as systemd services.

### Relevant features

- `virtualisation.oci-containers.backend`
- `virtualisation.oci-containers.containers.<name>.image`
- `virtualisation.oci-containers.containers.<name>.volumes`
- `virtualisation.oci-containers.containers.<name>.ports`
- `virtualisation.oci-containers.containers.<name>.workdir`
- `virtualisation.oci-containers.containers.<name>.extraOptions`
- Podman-specific option surface such as `virtualisation.oci-containers.containers.<name>.podman.user`

### Strengths

- Declarative host-side management for OCI workloads.
- Good fit when the service is already naturally packaged as an OCI container.
- Easier than full NixOS guest containers when only one app/container is needed.
- Can form the base for server-side service isolation helpers.

### Weaknesses / limits

- Not a full guest NixOS system.
- Less aligned with the goal of "declare a container using NixOS config directly".
- Better for app containers than for a full NixOS guest environment.

### Fit for this repo

**Good secondary server-side fit** for OCI-native workloads. Less ideal than built-in NixOS containers for "NixOS config inside the container".

## 3. Rootless Podman for desktop shells

### What it is

Direct OCI container execution, used imperatively, but installable/configurable from NixOS/Home Manager.

### Why it matters here

This is the strongest container-native option for the desktop AI-agent isolation requirement:

- mount only the current project directory
- mount only specific AI config paths
- set the working directory inside the container
- make the container ephemeral with `--rm`
- preserve access to bind mounts for the current user with `--userns=keep-id` when needed

### Strengths

- Best control over which host paths are visible.
- Good imperative UX for "from this directory, open a shell in a container".
- Easy to wrap in repo-installed helper commands.
- Better isolation default than Distrobox.

### Weaknesses / limits

- Not itself a declarative guest-NixOS system.
- Reusing the current AI environment requires deliberate mount/layout design.
- Current repo baseline is Docker-oriented, not Podman-oriented.
- Existing GPU-container support in this repo is Docker-rootless oriented (`hardware/_modules/nvidia.nix`), so Podman adoption may need extra GPU work if agent containers later need GPU access.

### Fit for this repo

**Best desktop fit** for isolated AI-agent shells with minimal host exposure.

## 4. Distrobox

### What it is

A convenience layer over Podman/Docker/lilipod for interactive desktop/dev containers, including cross-distro environments.

### Features relevant here

- `distrobox enter` defaults to entering the box and only switches to container home when `--no-workdir` is used
- `distrobox create` supports custom home directories, extra volumes, and additional engine flags
- `distrobox ephemeral` creates a temporary box destroyed on exit
- `distrobox assemble` provides manifest-driven batch creation via `distrobox.ini`
- unshare flags exist, including `unshare_all`

### Strengths

- Best UX for quick disposable distro environments.
- Strong fit for cross-distro testing on desktop.
- Easier than hand-writing raw container commands when the goal is "give me an Ubuntu/Fedora/Arch shell now".

### Weaknesses / limits

- Host integration is a feature, not a bug; that is convenient but weaker for least-access isolation.
- Manifest support (`distrobox assemble`) is useful, but it is still not the same as native NixOS declarative state.
- Better for convenience than for strict separation between AI agents.

### Fit for this repo

**Best desktop cross-distro fit**, but **not** the best primary isolation mechanism for sensitive/local agent compartmentalization.

## 5. systemd-nspawn / machinectl

### What they are

Native systemd tools for OS/process containers and shell access into them.

### Relevant features

- `systemd-nspawn --ephemeral`
- `machinectl shell`
- `machinectl bind`

### Strengths

- Good systemd-native model.
- Supports ephemeral snapshots and bind mounts.
- Reasonable if the workflow is close to "small system container managed like a machine".

### Weaknesses / limits

- Less ergonomic than Podman/Distrobox for casual desktop dev shells.
- Full functionality is more natural with privileges.
- Does not appear to beat built-in NixOS containers for server-side NixOS-in-NixOS use.

### Fit for this repo

Worth knowing, but not the leading choice for either of the main target workflows.

## 6. Arion

### What it is

A Nix front-end around Docker Compose-style multi-container applications, with NixOS-module integration.

### Strengths

- Declarative Nix instead of YAML Compose files.
- Useful for multi-service OCI stacks.
- Can be deployed as part of a NixOS configuration via `virtualisation.arion`.

### Weaknesses / limits

- Compose/OCI oriented, not a first-class native NixOS container framework.
- Best when the problem is fundamentally "a Compose stack".
- Less aligned with the goal of "declare a NixOS container guest with NixOS config directly".

### Fit for this repo

Useful if the repo later wants to standardize OCI/Compose-like app stacks declaratively. Not my first pick for the core framework.

## 7. compose2nix

### What it is

A conversion tool that turns existing Docker Compose definitions into `virtualisation.oci-containers` configuration.

### Fit for this repo

Helpful as a migration/import tool if existing Compose stacks need to be pulled into NixOS declarative OCI config. Not a standalone runtime model.

## Current direction for the next step

This document started with a broad survey. For the **next implementation/research step**, the direction is now narrower:

- focus on **desktop-side** agent containers
- use **rootless Docker**, not rootless Podman, for now
- keep server-side container design for a future session

That means the earlier Podman recommendation is no longer the immediate path, even though it was a good fit in the broader comparison.

## Desktop runtime pattern to aim for

The most promising Docker runtime pattern is:

- start a **new ephemeral container** per session with `docker run --rm -it`
- make the image/root filesystem **read-only** with `--read-only`
- provide explicit writable scratch locations with `--tmpfs` such as `/tmp` and `/run`
- bind-mount the current project directory and set `--workdir` to it
- bind-mount shared prompts/skills/config fragments as **read-only**
- mount exactly one **profile-scoped writable state root** as read-write
- keep durable state outside the image and outside the container writable layer

In Docker terms, the important building blocks are:

- `--rm` for ephemeral container lifecycle
- `--read-only` for an immutable root filesystem
- `--mount type=tmpfs,...` for scratch paths that disappear on exit
- `--mount type=bind,...,readonly` for shared read-only assets
- `--mount type=volume,...` or a writable bind mount for profile state
- `-w` / `--workdir` for "enter in this project directory" behavior

Unlike Distrobox, Docker does **not** have a first-class "enter current host cwd" concept. The practical solution is a small wrapper that expands `$PWD`, mounts it, and sets `--workdir` accordingly.

A skeleton command shape looks like:

```bash
docker run --rm -it \
  --read-only \
  --tmpfs /tmp:rw,noexec,nosuid,size=512m \
  --tmpfs /run:rw,nosuid,size=64m \
  --mount type=bind,src="$PWD",dst=/workspace \
  --workdir /workspace \
  --mount type=bind,src="$SHARED_SKILLS",dst=/home/agent/.agents/skills,readonly \
  --mount type=bind,src="$PROFILE_ROOT",dst=/state \
  IMAGE bash
```

The exact writable paths will depend on how the final image lays out `HOME` and tool-specific config/state locations.

## Agent path mapping candidates from the current repo

The repo already tells us which directories look like shared prompts/skills/config versus likely writable tool state.

### Strong read-only candidates

These are good candidates for **shared read-only mounts**, because the repo currently generates them declaratively from tracked files:

- `~/.agents/skills` and `~/.config/agents/skills` from `users/_modules/ai/_prompts/default.nix`
- `~/.code/agents`, `~/.code/skills`, and `~/.code/AGENTS.md` from `users/_modules/ai/agents/code/default.nix`
- `~/.omp/agent/agents`, `~/.omp/agent/skills`, and `~/.omp/agent/SYSTEM.md` from `users/_modules/ai/agents/omp/default.nix`
- `~/.config/opencode/superpowers`, `~/.config/opencode/plugins/superpowers.js`, and `~/.config/opencode/skill/...` from `users/_modules/ai/agents/opencode/default.nix`

### Likely writable or profile-sensitive candidates

These are the places that are most likely to need **profile-scoped writable state** or profile-specific overrides:

- `CODEX_HOME=~/.codex` from `users/_modules/ai/agents/opencode/default.nix`
- `~/.code/config.toml` from `users/_modules/ai/agents/code/default.nix`
- `~/.omp/agent/mcp.json` from `users/_modules/ai/agents/omp/default.nix`
- `~/.agent-browser/config.json` from `users/_modules/ai/agents/agent-browser/default.nix`
- `~/.config/opencode/...` if opencode writes runtime/plugin/provider state there in practice

The important design consequence is: **the container should not blindly mount the whole host home directory**. It should mount only the project directory, shared read-only agent assets, and one profile state root.

## Profile/state approaches

The core requirement is: multiple profiles should share the same read-only skills/prompts/base config, while keeping different writable state such as provider credentials, notes, or agent-specific memory.

### Approach 1: Host bind-mounted profile roots

Example shape:

- `~/.local/share/agent-containers/profiles/work/...`
- `~/.local/share/agent-containers/profiles/personal/...`

Mount the chosen profile root read-write into the container, and keep all shared prompts/skills mounted read-only from the repo-managed locations.

**Pros**

- easiest to inspect with normal host tools
- easiest to back up with ordinary filesystem backups
- simplest to reason about during development
- easiest to migrate between runtimes later

**Cons**

- tied to host path layout
- the wrapper must create/manage directories cleanly
- host filesystem ownership/permissions need to stay sensible for the chosen container user model

### Approach 2: One named Docker volume per profile

Example shape:

- `agent-profile-work`
- `agent-profile-personal`

Mount the chosen named volume into a fixed writable path such as `/state` or the container home.

**Pros**

- state survives container deletion cleanly
- Docker manages lifecycle separately from the ephemeral container
- good separation between image/container lifecycle and profile lifecycle
- volumes are explicitly described by Docker as easier to back up or migrate than bind mounts

**Cons**

- less transparent to inspect from normal desktop tools
- backups and ad hoc edits are more Docker-centric
- hidden state under Docker's data root is less pleasant for day-to-day debugging

### Approach 3: Hybrid split (recommended overall shape)

Use:

- bind mount for the current workspace
- read-only bind mounts for shared prompts/skills/config fragments
- **either** a host profile directory **or** a named volume for the writable profile root

This keeps the separation clean: the image is immutable, the workspace is explicit, shared assets are read-only, and all durable mutable state is profile-scoped.

This is the strongest overall model for your stated goals.

### Approach 4: Seeded profile state on first run

Docker volumes have an important behavior: when an **empty** volume is mounted into a non-empty path in the container, Docker copies the container's existing files into that volume by default. `volume-nocopy` disables that behavior.

That gives two useful variants:

- **seed defaults once**: bake default config into the image and let Docker copy it into an empty profile volume on first run
- **strict empty profile**: mount with `volume-nocopy` and create/init state explicitly from the wrapper or entrypoint

**Pros**

- convenient if profiles need a default starting config
- lets the image carry a baseline while state still lives outside the container lifecycle

**Cons**

- profile drift becomes a real thing once a volume has been initialized
- updating the image later does not automatically migrate existing profile state
- debugging becomes less obvious because some "defaults" live in old profile volumes, not in the current image

## Modularity / extendability direction

A clean modular split would be:

1. **image composition**
   - common shell/runtime tools
   - agent binaries
   - optional feature bundles later (language tooling, browsers, GPU helpers, etc.)
2. **shared read-only assets**
   - prompts
   - skills
   - checked-in config fragments
3. **runtime mounts**
   - workspace bind mount
   - profile state mount
   - tmpfs scratch mounts

That keeps the system extendable without forcing every new tool to become permanent mutable state inside the image.

## How nixpkgs-built Docker images help

Yes: building the image with `dockerTools` looks useful here.

### Why it helps

- the image can be built reproducibly from Nix instead of an imperative Dockerfile
- agent binaries, shell tools, and baseline config can be composed from nixpkgs packages directly
- state does **not** need to be baked into the image; the runtime mount model stays clean
- image updates become declarative and reviewable in the repo

### Builder choices

#### `dockerTools.buildLayeredImage`

This looks like the best default builder for the desktop agent-container image.

Why:

- it is designed for Docker images where many store paths can live on separate layers for better sharing
- it supports `contents`, `config`, `extraCommands`, `fakeRootCommands`, and `maxLayers`
- it does not rely on Docker itself to build the image

This is a good fit if the image will contain multiple tools/packages and may evolve over time.

#### `dockerTools.buildImage`

This is the simpler single-image tarball builder.

Why you might still use it:

- very simple image shape
- `copyToRoot` maps well to "put these packages/files into the image"
- `config` cleanly sets `Cmd`, `Env`, `WorkingDir`, `Volumes`, etc.

Important caveat: `runAsRoot` requires KVM. Also, nixpkgs documents that `buildImage` and `buildLayeredImage` work differently and are not interchangeable.

#### `dockerTools.streamLayeredImage`

This is attractive if image size grows or if you want to avoid realizing large tarballs into the Nix store. It produces a script that streams the image to stdout, so you can pipe it straight into `docker load`.

That makes it a good operational companion to `buildLayeredImage` for larger images.

### Practical recommendation

For this use case, the most sensible default appears to be:

- **use `dockerTools.buildLayeredImage` for the main image definition**
- optionally use **`streamLayeredImage`** as the load/distribution path if store size or IO becomes annoying
- use **`buildImage`** only when its simpler model is enough or when you specifically want its style of image construction

### User / home layout inside the image

If the image should feel like a normal interactive shell, the image needs a coherent user/home layout.

Relevant nixpkgs evidence: the dockerTools examples show creating passwd/group/shadow files for a non-root user and building images that way. That suggests two viable directions later:

- bake a simple non-root user/home layout into the image
- or run the container with Docker's `-u` option and keep the image relatively minimal

Either way, the key rule stays the same: **tool state belongs in the mounted profile root, not in the image**.

## Desktop-specific caveats to keep in mind

- Rootless Docker uses the user socket at `$XDG_RUNTIME_DIR/docker.sock`; NixOS can set `DOCKER_HOST` automatically with `virtualisation.docker.rootless.setSocketVariable`.
- Rootless Docker stores daemon data under `~/.local/share/docker` by default and Docker docs say this data-root should not be on NFS.
- In rootless mode, `--net=host` and container IPs from `docker inspect` do not behave like rootful Docker because RootlessKit namespaces networking.
- Rootless resource flags like `--cpus`, `--memory`, and `--pids-limit` are ignored unless cgroup v2 plus systemd delegation are in place.
- `--read-only` is not enough by itself for interactive tools; writable scratch/state mounts still need to be explicit.

## Repo-native placement for `frag` and Nix-managed images

The repo scout still points to `packages/` as the natural home for the underlying Nix derivations, but the current design preference is **not** to expose this work as public flake `packages`/`apps` outputs unless that later proves necessary.

The cleaner desktop-oriented shape is:

- define the underlying image builders and related derivations privately under `packages/`
- install the `frag` CLI through the normal host/user package path (`environment.systemPackages` or Home Manager packages)
- keep image metadata/load helpers in a canonical directory shipped with the installed `frag` package, rather than publishing them as public flake outputs

Why this fits the repo:

- `packages/default.nix` is already the private home for repo-local derivations built with `pkgs.callPackage`
- user/system package installation is already a normal repo pattern for host tools
- this avoids adding flake-output surface area for a desktop-local tool that may not need external consumption

A practical future shape would be something like:

```text
packages/
  frag/
    default.nix
    images.nix
    wrapper.nix
    image_catalog.nix
```

Where:

- `images.nix` defines the Nix-managed Docker image derivations
- `wrapper.nix` packages the `frag` CLI
- `image_catalog.nix` provides a small machine-readable list of available image keys/metadata for prompts and validation
- the installed `frag` package exposes those runtime assets under its own share/libexec tree, which becomes reachable via the active Nix profile
- the `frag` application source itself should live under `_scripts/frag` for future reuse/possible extraction, while the Nix derivations that package it can stay under `packages/frag`

That means the wrapper can discover its bundled image catalog and image-loading artifacts from its own installed package closure instead of from flake outputs or ad hoc local conventions.

There is currently **no** existing `dockerTools` usage in the repo, so this would still be a new package family, but it can remain private to the host/user package wiring if that stays sufficient.

## Current design choices and remaining open questions

### Chosen so far

1. **Profile storage backend**
   - one named Docker volume per profile
2. **Config seeding strategy**
   - strict-empty profiles; bootstrap creates only the required structure explicitly
3. **Profile/workspace coupling**
   - one profile = one trusted workspace root
4. **Wrapper/runtime model**
   - reusable running container per profile; later `frag enter` calls use `docker exec` into it
5. **Package/output exposure**
   - prefer private `packages/` derivations plus installed host packages over public flake `packages`/`apps` outputs

### Still open

1. **Image user model**
   - bake a non-root user into the image
   - or run with a host-matching UID/GID via Docker flags
2. **Optional bundles**
   - decide whether non-agent tools belong in one base image or in optional image variants/modules
3. **Installed asset layout**
   - finalize where the bundled image catalog and loader artifacts live under the installed `frag` package (for example `share/frag` vs `libexec/frag`)

## Source index

### Repo evidence

- `systems/_bootstrap/host.nix`
- `_lib/units/default.nix`
- `users/_units/fxsync/default.nix`
- `users/_units/wireguard/default.nix`
- `outputs/hosts/default.nix`
- `_modules/vm.nix`
- `microvms/postgres/default.nix`
- `hardware/_modules/nvidia.nix`
- `users/_modules/ai/default.nix`
- `users/_modules/ai/_prompts/default.nix`
- `users/_modules/ai/agents/code/default.nix`
- `users/_modules/ai/agents/opencode/default.nix`
- `users/_modules/ai/agents/omp/default.nix`
- `users/_modules/ai/agents/agent-browser/default.nix`
- `users/lav.nix`
- `systems/_modules/home-manager.nix`
- `outputs/channels/default.nix`
- `outputs/default.nix`
- `outputs/packages/default.nix`
- `packages/default.nix`
- `outputs/apps/default.nix`
- `users/_modules/cli/nix-tools.nix`
- `home/_modules/hybrid-links/default.nix`

### External references

#### Native NixOS containers

- NixOS manual, containers chapter: https://nixos.org/nixos/manual/#ch-containers
- NixOS wiki: https://wiki.nixos.org/wiki/NixOS_Containers
- `containers.<name>.config`: https://search.nixos.org/options?show=containers.%3Cname%3E.config
- `containers.<name>.bindMounts`: https://search.nixos.org/options?show=containers.%3Cname%3E.bindMounts
- `containers.<name>.forwardPorts`: https://search.nixos.org/options?show=containers.%3Cname%3E.forwardPorts
- `containers.<name>.privateUsers`: https://search.nixos.org/options?show=containers.%3Cname%3E.privateUsers
- `containers.<name>.ephemeral`: https://search.nixos.org/options?show=containers.%3Cname%3E.ephemeral
- `containers.<name>.flake`: https://search.nixos.org/options?show=containers.%3Cname%3E.flake

#### Docker rootless + runtime

- Docker rootless mode: https://docs.docker.com/engine/security/rootless/
- Docker rootless tips: https://docs.docker.com/engine/security/rootless/tips/
- Docker rootless troubleshooting: https://docs.docker.com/engine/security/rootless/troubleshoot/
- `docker run`: https://docs.docker.com/reference/cli/docker/container/run/
- Docker bind mounts: https://docs.docker.com/engine/storage/bind-mounts/
- Docker tmpfs mounts: https://docs.docker.com/engine/storage/tmpfs/
- Docker volumes: https://docs.docker.com/storage/volumes/
- `virtualisation.docker.rootless.enable`: https://search.nixos.org/options?show=virtualisation.docker.rootless.enable
- `virtualisation.docker.rootless.setSocketVariable`: https://search.nixos.org/options?show=virtualisation.docker.rootless.setSocketVariable

#### Nix-built Docker images

- nix.dev tutorial: https://nix.dev/tutorials/nixos/building-and-running-docker-images
- nixpkgs dockerTools docs: https://ryantm.github.io/nixpkgs/builders/images/dockertools/
- NixOS wiki Docker page: https://nixos.wiki/wiki/Docker
- nixpkgs docker examples: https://github.com/NixOS/nixpkgs/blob/master/pkgs/build-support/docker/examples.nix

#### Distrobox

- `distrobox create`: https://distrobox.it/usage/distrobox-create/
- `distrobox enter`: https://distrobox.it/usage/distrobox-enter/
- `distrobox ephemeral`: https://distrobox.it/usage/distrobox-ephemeral/
- `distrobox assemble`: https://distrobox.it/usage/distrobox-assemble/

#### systemd-nspawn / machinectl

- `systemd-nspawn(1)`: https://man7.org/linux/man-pages/man1/systemd-nspawn.1.html
- `machinectl(1)`: https://man7.org/linux/man-pages/man1/machinectl.1.html

#### Arion / compose2nix

- Arion overview: https://docs.hercules-ci.com/arion/
- Arion deployment on NixOS: https://docs.hercules-ci.com/arion/deployment/
- compose2nix: https://github.com/aksiksi/compose2nix
