# Hermes Agent Unit Design

> **For agentic workers:** REQUIRED: implement from a separate
> worktree, do not commit without explicit permission, and do not ask
> implementation-time questions. If NixOS VM tests are added later,
> read `.agents/skills/writing-nixos-tests/SKILL.md` first.

**Goal:** Add a `users/_units/hermes-agent` NixOS unit that runs
NousResearch Hermes Agent 24/7 inside a native NixOS container owned
by the unit.

**Architecture:** Keep this Hermes-scoped and avoid the broader
experimental container framework. The host unit declares
`my."unit.hermes-agent"` options, creates a native
`containers.hermes-agent` guest, owns host-visible persistent state
and backups, can declare a sops-nix dotenv secret, bind-mounts host
env files read-only, and enables Hermes inside the guest as a systemd
service. Hermes terminal/tool commands run with the `local` backend
inside the NixOS container, making the container the execution
boundary.

**Tech Stack:** NixOS modules, native `containers.<name>` /
systemd-nspawn, existing `pkgs.llm-agents.hermes-agent`, systemd
services, host NAT for private veth networking, sops-nix env-file
secrets, repo backup item conventions.

---

## Confirmed decisions

- Use the existing `pkgs.llm-agents.hermes-agent` package; do not add
  a new Hermes npins input.
  - Current package source is `numtide/llm-agents.nix`, packaging
    NousResearch Hermes Agent `v2026.4.30`.
- Enable the new unit on `tyrant` as the intended 24/7 server.
- The unit owns its native NixOS container directly. Do not add or
  depend on a repo-wide `my.containers` abstraction for this task.
- Use explicit host state bind mounts and `privateUsers = "identity"`
  for this first implementation.
  - Reason: current NixOS user-defined writable bind mounts are not
    reliably writable with `privateUsers = "pick"` unless using an
    idmapped bind-mount workaround.
- Use private routed veth networking plus host NAT for outbound
  Internet access.
  - Default Hermes container ID: `30`.
  - Default host address: `10.88.30.1`.
  - Default container address: `10.88.30.2`.
  - On `tyrant`, use external interface `enp3s0f1` unless host config
    later overrides it.
- No ingress in the first cut.
  - No `my.vhosts`.
  - No `my.tcp_routes` or `my.udp_routes`.
  - No forwarded ports.
- Secrets are delivered as host env files, with first-class sops-nix
  support for the Hermes dotenv file.
  - The unit exposes `hermes.sops_environment_file` for an encrypted
    multiline dotenv payload, defaulting to
    `${my.secrets.dir}/hermes-agent.yaml` key `env`.
  - The sops secret is auto-enabled only when that default private
    secret file exists; currently it is safe for this repo because the
    file is absent.
  - The unit still exposes `hermes.environment_files` for additional
    externally declared host paths/strings.
  - All env files are bind-mounted read-only into the guest.
  - Env-file contents and API keys must not appear in Nix expressions
    or the Nix store.
- Hermes terminal backend is `local` inside the NixOS container.
- No extra host mounts initially beyond Hermes state/workspace.
- No new tests for this first cut; verification uses targeted Nix
  eval/build checks.

## Non-goals

- Do not implement the broader container composer from
  `docs/wip/isolation_server.md` or
  `docs/wip/nixos_containers_spec.md`.
- Do not migrate other services to containers.
- Do not use MicroVMs.
- Do not use upstream Hermes' OCI/Ubuntu container mode.
- Do not expose host Docker/Podman sockets to Hermes.
- Do not add public DNS or Traefik routes for Hermes in this first
  cut.
- Do not mount arbitrary host directories, home directories, or repo
  checkouts into the guest.
- Do not put API keys, bot tokens, OAuth tokens, or env-file contents
  in Nix expressions.

---

## Research summary

### Hermes upstream

The intended upstream is `NousResearch/hermes-agent` with high
confidence. Official docs describe it as a self-improving AI
agent/gateway designed to live on a server, remember across sessions,
run cron jobs, and interact through messaging platforms.

Relevant facts:

- Long-running entry point: `hermes gateway run` / gateway service.
- Important state root: `HERMES_HOME`.
- Standard state contents include:
  - `config.yaml`;
  - `.env`;
  - `auth.json`;
  - `SOUL.md`;
  - `memories/`;
  - `skills/`;
  - `cron/`;
  - `sessions/`;
  - `logs/`;
  - pairing data;
  - MCP OAuth tokens;
  - terminal/sandbox caches when enabled.
- Secrets are provider/platform environment variables, normally
  delivered through `.env` or environment files.
- Hermes needs outbound HTTPS for LLM providers, tool APIs,
  GitHub/skills, messaging APIs, and configured MCP/remote backends.
- Inbound ports are optional and only needed for webhooks, API, or
  dashboard modes.

### Repo patterns

Current unit conventions:

- Unit modules live under `users/_units/<name>/default.nix`.
- All units are imported from `users/_units/default.nix`.
- Unit options live under `my."unit.<name>"` via `o.module`.
- `o.module` automatically adds `backup.items` options.
- Host-specific enablement is currently in `globals/hosts.nix`.
- `tyrant` is the server host that enables reverse proxy and
  long-running services.

Current container evidence:

- Host support exists: `systems/_bootstrap/host.nix` enables
  `virtualisation.containers.enable = true`.
- No implemented native `containers.<name>` service framework exists
  on this branch.
- The only implemented container-ish helper is Docker Compose
  oriented.
- Therefore the Hermes unit should directly emit
  `containers.hermes-agent` instead of waiting for or creating generic
  container infrastructure.

### User namespace / bind mount constraint

NixOS `containers.<name>.privateUsers = "pick"` is the safer automatic
user-namespace mode, but current user-defined writable bind mounts are
not reliably writable with it. Local nixpkgs code only appends
`:idmap` automatically for built-in `/nix` bind mounts, not for
arbitrary `containers.<name>.bindMounts` entries. For this task, use
`privateUsers = "identity"` to preserve explicit host-owned state bind
mounts without a workaround.

This is a conscious first-cut tradeoff: Hermes is isolated by the
NixOS container's process, mount, and network namespaces, but not by
UID remapping. A later hardening pass can revisit
`privateUsers = "pick"` once the repo chooses an idmapped state-mount
convention.

---

## Target option surface

Add a new unit option tree:

```nix
my."unit.hermes-agent" = {
  enable = true;

  package = pkgs.llm-agents.hermes-agent;

  state_dir = "/var/lib/containers/hermes-agent/state";

  container = {
    name = "hermes-agent";
    id = 30;
    auto_start = true;
    private_users = "identity";
    host_address = "10.88.30.1";
    local_address = "10.88.30.2";
  };

  nat = {
    enable = true;
    external_interface = "enp3s0f1";
  };

  hermes = {
    settings = {
      terminal = {
        backend = "local";
        cwd = "/var/lib/hermes/workspace";
      };
    };
    environment_files = [];
    extra_packages = [];
    extra_args = [];
  };
};
```

Exact option names may be adjusted for repo style during
implementation, but the first cut should preserve these
responsibilities. The implementation must also import `./hermes-agent`
from `users/_units/default.nix`.

## Host responsibilities

When `my."unit.hermes-agent".enable = true`, the host should:

1. Create the host state root with `systemd.tmpfiles.rules`.
2. Declare `containers.${container.name}`.
3. Bind-mount the host state root read-write into the guest at
   `/var/lib/hermes`.
4. Bind-mount each configured host env file read-only into a stable
   guest path under `/run/hermes-agent/env/`.
   - When `hermes.sops_environment_file.enable = true`, also
     bind-mount the decrypted sops env file read-only at
     `${guest_hermes_home}/.env` (`/var/lib/hermes/.hermes/.env`)
     because Hermes reads `~/.hermes/.env` directly for API keys,
     separate from the systemd `EnvironmentFile`.
5. Configure private routed networking:
   - `privateNetwork = true`;
   - `hostAddress = opts.container.host_address`;
   - `localAddress = opts.container.local_address`.
6. Configure host NAT when `nat.enable = true`:
   - `networking.nat.enable = true`;
   - include the exact host veth interface `ve-${opts.container.name}`
     in `networking.nat.internalInterfaces`; for the default name,
     this is `ve-hermes-agent`;
   - set
     `networking.nat.externalInterface = opts.nat.external_interface`.
7. Register a backup item for the host state root under
   `my."unit.hermes-agent".backup.items.state` with policy
   `sensitive_data`.
8. Avoid declaring any vhost/route unless a later task enables
   ingress.

## Guest responsibilities

The container guest should:

1. Set `system.stateVersion = "25.11"`.
2. Use container DNS suitable for private-network containers:
   - `networking.useHostResolvConf = lib.mkForce false`;
   - `services.resolved.enable = true`.
3. Create a `hermes` service user and group inside the guest, with
   `shell = pkgs.bashInteractive;` so `sudo -u hermes -i` works.
4. Add the Hermes package to `environment.systemPackages` so the
   `hermes` CLI is available in the container PATH, not just through
   the service `path`.
5. Create and own:
   - `/var/lib/hermes/.hermes`;
   - `/var/lib/hermes/home`;
   - `/var/lib/hermes/workspace`.
6. Render a non-secret `config.yaml` from `hermes.settings` into
   `/var/lib/hermes/.hermes/config.yaml`.
7. Do not create `/var/lib/hermes/.hermes/.managed` (run unmanaged).
8. Run a systemd service:
   - `ExecStart = "${package}/bin/hermes gateway run"` plus optional
     extra args;
   - `HERMES_HOME = "/var/lib/hermes/.hermes"`;
   - `HOME = "/var/lib/hermes/home"`;
   - `MESSAGING_CWD = "/var/lib/hermes/workspace"`;
   - `EnvironmentFile =` guest env-file mount paths;
   - `Restart = "always"` or equivalent.
9. Make default tool execution local to the guest by setting
   `terminal.backend = "local"` and
   `terminal.cwd = "/var/lib/hermes/workspace"`.

## `tyrant` host config

Add `my."unit.hermes-agent"` to `globals/hosts.nix` under
`tyrant.config.my`:

```nix
"unit.hermes-agent" = {
  enable = true;
  nat.external_interface = "enp3s0f1";
  hermes.environment_files = [];
  # default sops env-file secret auto-enables after
  # mysecrets/secrets/hermes-agent.yaml exists
};
```

The unit provides a sops-nix env-file hook for the default private
secret file `${my.secrets.dir}/hermes-agent.yaml` key `env`. Because
that file is not present yet, the current build keeps the hook
disabled and still evaluates; the service may fail authentication at
runtime until secrets/config are supplied.

## Safety and security expectations

- The container has no public ingress by default.
- Hermes commands run inside the NixOS container, not on the host.
- No host Docker/Podman socket is mounted.
- No host home or repo checkout is mounted.
- The only unit-declared host mounts are the Hermes state bind mount
  and configured read-only env-file mounts. Native NixOS containers
  still get inherent `/nix` bind mounts from the container runtime.
- Secrets are runtime files only, not Nix store values.
- The explicit state directory is the backup/restore boundary.
- `privateUsers = "identity"` is documented as a reliability tradeoff,
  not the final hardening target.

## Verification requirements

Minimum checks after implementation:

1. `nix fmt`.
2. Stage only intended changed files.
3. `prek`.
4. Targeted evals for the Hermes options, container config, and NAT
   wiring, for example:
   - `nix eval .#nixosConfigurations.tyrant.config.my."unit.hermes-agent".enable`;
   - `nix eval .#nixosConfigurations.tyrant.config.containers.hermes-agent.privateNetwork`;
   - `nix eval .#nixosConfigurations.tyrant.config.containers.hermes-agent.localAddress`;
   - `nix eval .#nixosConfigurations.tyrant.config.networking.nat.internalInterfaces`.
5. Targeted host build:
   - `nix build .#nixosConfigurations.tyrant.config.system.build.toplevel`.
6. `nix flake check --all-systems` only if appropriate and feasible
   after targeted checks.

If `npins/`, `inputs.nix`, or `input-overrides.nix` are not changed,
`npins verify` is not required.

## Open risks

- Runtime secrets are not defined by this repo change. The service can
  be declared before the env file exists, but Hermes will not
  authenticate until configured.
- `privateUsers = "identity"` is weaker than `"pick"`; a later
  hardening pass should revisit idmapped writable state.
- Full service startup is not proven by a new VM test in this first
  cut because the user chose targeted eval/build verification only.
- Hermes upstream changes quickly. The existing `llm-agents` pin
  controls the package version; updating Hermes later means updating
  that input, not this unit.
