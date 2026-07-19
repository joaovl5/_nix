# NixOS Containers Draft Implementation Plan

> **For agentic workers:** REQUIRED: Use
> superpowers:subagent-driven-development (if subagents available) or
> superpowers:executing-plans to implement this plan. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a first draft of the native NixOS container framework
described in `docs/wip/nixos_containers_spec_v2.md`.

**Architecture:** Add a small `c` helper namespace, an `o.unit`
metadata wrapper, a host-side `my.containers` lowering module, and
split Actual Budget into a guest-safe unit plus existing host wrapper.
The first implementation is intentionally draft-grade: the schema
exists for multi-unit, host-provider, and cross-container edges, while
enforcement can land in later iterations.

**Tech Stack:** NixOS modules, native `containers.<name>`, existing
repo `mylib` helpers, eval-style flake checks.

---

## File map

Create:

- `_lib/containers/default.nix` — `c` helper namespace, including
  `c.unit`.
- `users/_units/_containers/default.nix` — `my.containers` NixOS
  module and lowering logic.
- `users/_units/actual-budget/unit.nix` — guest-safe Actual Budget
  unit.
- `outputs/checks/containers.nix` — eval checks for the container
  contract.

Modify:

- `_lib/with_config.nix` — expose `containers` helper namespace.
- `_lib/options/default.nix` — add `o.unit` with read-only metadata.
- `users/_units/default.nix` — import `./_containers`.
- `users/_units/actual-budget/default.nix` — keep host wrapper
  behavior while reusing `unit.nix`.
- `outputs/checks/default.nix` — include `containers.nix` checks.

Do not modify in the first draft:

- `globals/hosts.nix` — do not move tyrant Actual Budget into a real
  container yet.
- MicroVM files.
- Existing reverse-proxy schemas.

## Chunk 1: Foundation checks

### Task 1: Add failing container contract check

**Files:**

- Create: `outputs/checks/containers.nix`
- Modify: `outputs/checks/default.nix`
- [ ] **Step 1: Create the failing check file**

Add `outputs/checks/containers.nix` with a synthetic NixOS host that
imports only the modules needed for this proof:

```nix
{
  self,
  globals,
  pkgs,
  ...
}: let
  inherit (pkgs) lib;
  extra_args = self._utils.hosts.mk_extra_args {inherit pkgs;};

  synthetic = lib.nixosSystem {
    system = pkgs.system;
    specialArgs = extra_args;
    modules = [
      ../../_modules/options.nix
      ../../users/_units/backup
      ../../users/_units/_containers
      ../../users/_units/actual-budget
      ({lib, ...}: {
        options.my.vhosts = lib.mkOption {
          type = lib.types.attrsOf (lib.types.submodule {
            options = {
              target = lib.mkOption {type = lib.types.str;};
              sources = lib.mkOption {type = lib.types.listOf lib.types.str;};
            };
          });
          default = {};
        };
      })
      {
        my.nix = {
          hostname = "container-test";
          username = "lav";
          email = "lav@example.invalid";
          name = "Lav";
        };

        users.users.lav = {
          isNormalUser = true;
          home = "/home/lav";
        };

        system.stateVersion = "25.11";
      }

      ({config, ...}: let
        c = (extra_args.mylib.use config).containers;
      in {
        my.containers.actual-budget = c.unit "unit.actual-budget" {
          id = 11;
          target = "actual";
        };
      })
    ];
  };

  cfg = synthetic.config;
in {
  containers_contract =
    assert cfg.my.containers.actual-budget.enable;
    assert cfg.containers.actual-budget.privateNetwork;
    assert cfg.containers.actual-budget.hostAddress == "10.88.11.1";
    assert cfg.containers.actual-budget.localAddress == "10.88.11.2";
    assert cfg.containers.actual-budget.privateUsers == "no";
    assert cfg.containers.actual-budget.bindMounts."/var/lib/actual".hostPath == "/var/lib/containers/actual-budget/actual-budget/data";
    assert cfg.containers.actual-budget.bindMounts."/var/lib/actual".isReadOnly == false;
    assert cfg.my.vhosts.actual-budget.target == "actual";
    assert cfg.my.vhosts.actual-budget.sources == ["http://actual-budget.containers:5006"];
    assert cfg.my."unit.backup".host_items.actual_budget_state.path.paths == ["/var/lib/containers/actual-budget/actual-budget/data"];
      pkgs.runCommand "containers-contract" {} "touch $out";
}
```

- [ ] **Step 2: Wire the check into `outputs/checks/default.nix`**

Add:

```nix
container_checks = import ./containers.nix {
  inherit globals self pkgs;
};
```

and include `// container_checks` in the returned checks.

- [ ] **Step 3: Run the check and confirm it fails**

Run:

```bash
nix build .#checks.x86_64-linux.containers_contract
```

Expected: fails because `users/_units/_containers`, `my.containers`,
`c.unit`, and/or `o.unit` do not exist yet.

- [ ] **Step 4: Commit the failing check**

```bash
git add outputs/checks/default.nix outputs/checks/containers.nix
git commit -m "test: add nixos container contract check"
```

## Chunk 2: Helper and metadata foundations

### Task 2: Add `c` helper namespace

**Files:**

- Create: `_lib/containers/default.nix`
- Modify: `_lib/with_config.nix`
- [ ] **Step 1: Create `_lib/containers/default.nix`**

Implement a small helper namespace:

```nix
{
  lib,
  ...
}: let
  inherit (lib) recursiveUpdate;
in rec {
  unit = unit_key: args:
    recursiveUpdate
    {
      enable = true;
      inherit (args) id;
      units.main = {
        unit = unit_key;
        options = recursiveUpdate {
          enable = true;
        } (args.options or {});
      };
      expose =
        if args ? target
        then [
          {
            unit = "main";
            endpoint = "web";
            inherit (args) target;
          }
        ]
        else [];
      consumes = args.consumes or {};
    }
    (removeAttrs args ["id" "target" "consumes" "options"]);
}
```

Keep this intentionally small. The host module performs
validation/lowering.

- [ ] **Step 2: Expose the namespace in `_lib/with_config.nix`**

Add:

```nix
containers = import ./containers args;
```

Modules should then use:

```nix
c = (mylib.use config).containers;
```

- [ ] **Step 3: Run the contract check**

```bash
nix build .#checks.x86_64-linux.containers_contract
```

Expected: still fails because `my.containers` and `o.unit` are not
implemented.

- [ ] **Step 4: Commit**

```bash
git add _lib/containers/default.nix _lib/with_config.nix
git commit -m "feat: add container helper namespace"
```

### Task 3: Add `o.unit` metadata support

**Files:**

- Modify: `_lib/options/default.nix`
- [ ] **Step 1: Add `o.unit` without changing `o.module`**

Add a helper beside `module`:

```nix
unit = name: options: metadata: module_config: let
  opts = get_config_opts name;
in {
  options = {
    my.${name} = options;
    my._unit_metadata.${name} = mkOption {
      description = "Read-only metadata for ${name}";
      type = t.anything;
      readOnly = true;
      default = metadata;
    };
  };

  config = module_config opts;
};
```

Do not wrap `o.unit` with `with_backup_items`. Containerized backups
are host-owned and come from metadata/lowering.

- [ ] **Step 2: Run the contract check**

```bash
nix build .#checks.x86_64-linux.containers_contract
```

Expected: still fails until Actual Budget exposes metadata and
`my.containers` lowers it.

- [ ] **Step 3: Commit**

```bash
git add _lib/options/default.nix
git commit -m "feat: add unit metadata helper"
```

## Chunk 3: Actual Budget split

### Task 4: Create guest-safe Actual Budget unit

**Files:**

- Create: `users/_units/actual-budget/unit.nix`
- Modify: `users/_units/actual-budget/default.nix`
- [ ] **Step 1: Create `unit.nix`**

Add a guest-safe module:

```nix
{
  mylib,
  config,
  pkgs,
  ...
}: let
  my = mylib.use config;
  o = my.options;
  opts = config.my."unit.actual-budget";
in
  o.unit "unit.actual-budget" (with o; {
    enable = toggle "Enable Actual Budget" false;
    endpoint = {
      port = opt "Port for Actual Budget" t.port 5006;
      bind = opt "Bind address for Actual Budget" t.str "0.0.0.0";
    };
    state.data.path = opt "Actual Budget data directory" t.path "/var/lib/actual";
  }) {
    endpoints.web = {
      protocol = "http";
      port = 5006;
    };
    state.data = {
      guest_path = "/var/lib/actual";
      backup.policy = "sensitive_data";
    };
  } (opts: o.when opts.enable {
    services.actual = {
      enable = true;
      package = pkgs.actual-server;
      settings = {
        dataDir = opts.state.data.path;
        inherit (opts.endpoint) port;
      };
    };

    networking.firewall.allowedTCPPorts = [opts.endpoint.port];
  })
```

- [ ] **Step 2: Rewrite `default.nix` as host wrapper**

Keep current host-run behavior while importing `unit.nix`:

```nix
{
  mylib,
  config,
  ...
}: let
  my = mylib.use config;
  o = my.options;
  u = my.units;
  opts = config.my."unit.actual-budget";

  computed_data_dir =
    if opts.data_dir != null
    then opts.data_dir
    else "${u.data_dir}/actual-budget";
in {
  imports = [./unit.nix];

  options.my."unit.actual-budget" = o.with_backup_items (with o; {
    data_dir = optional "Directory for Actual Budget state data" t.str {};
    endpoint = {
      target = opt "Subdomain prefix for host-run Actual Budget" t.str "actual";
      sources = opt "Host reverse-proxy upstreams for host-run Actual Budget" (t.listOf t.str) ["http://localhost:5006"];
    };
  });

  config = o.when opts.enable {
    my.vhosts.actual-budget = {
      inherit (opts.endpoint) target sources;
    };

    my."unit.actual-budget".backup.items.state = {
      kind = "path";
      policy = "sensitive_data";
      path.paths = [opts.state.data.path];
    };

    system.activationScripts.ensure_data_directory_actual_budget = ''
      echo "[!] Ensuring Actual Budget directories and symlinks"
      ln -sfn ${opts.state.data.path} ${computed_data_dir}
    '';
  };
}
```

This keeps host-only vhost and backup options in the host wrapper.
`unit.nix` remains guest-safe and does not declare host backup
ownership.

- [ ] **Step 3: Run current backup check**

```bash
nix build .#checks.x86_64-linux.backups-eval
```

Expected: pass, preserving existing `tyrant_actual_budget_state_to_a`
while Actual Budget is still host-run.

- [ ] **Step 4: Run the container contract check**

```bash
nix build .#checks.x86_64-linux.containers_contract
```

Expected: still fails until the container lowering module exists.

- [ ] **Step 5: Commit**

```bash
git add users/_units/actual-budget/default.nix users/_units/actual-budget/unit.nix
git commit -m "refactor: split actual budget unit"
```

## Chunk 4: Container lowering module

### Task 5: Implement `my.containers` lowering

**Files:**

- Create: `users/_units/_containers/default.nix`
- Modify: `users/_units/default.nix`
- [ ] **Step 1: Import the module from `users/_units/default.nix`**

Add `./_containers` near the top of the import list, after `./backup`.

- [ ] **Step 2: Create `users/_units/_containers/default.nix`**

Implement:

- `options.my.containers` as an attrset of container declarations.
- Required fields: `enable`, `id`, `units`, `expose`, `consumes`.
- Address derivation:
  - host: `10.88.<id>.1`
  - guest: `10.88.<id>.2`
- A minimal unit registry:
  - `"unit.actual-budget" = ../actual-budget/unit.nix;`
- Lower enabled declarations into:
  - `containers.<name>`
  - `my.vhosts` for HTTP exposure
  - `my."unit.backup".host_items` for metadata state entries

Important lowering details:

```nix
privateNetwork = true;
privateUsers = "no";
restartIfChanged = true;
hostAddress = "10.88.${toString cfg.id}.1";
localAddress = "10.88.${toString cfg.id}.2";
specialArgs = {inherit mylib globals inputs system;};
```

Guest baseline:

```nix
{
  networking.hosts."${host_address}" = ["host.containers"];
  networking.useHostResolvConf = lib.mkForce false;
  services.resolved.enable = true;
  system.stateVersion = host_state_version;
}
```

State mount derivation:

```text
/var/lib/containers/<container>/<unit-slug>/<state-name>
```

For `unit.actual-budget`, state `data`, container `actual-budget`:

```text
/var/lib/containers/actual-budget/actual-budget/data
```

Backup item name for the same state:

```text
actual_budget_state
```

- [ ] **Step 3: Add assertions**

Add assertions for:

- duplicate container IDs;
- invalid container names containing `_`;
- unknown unit keys;
- exposure referencing a missing unit alias;
- exposure referencing a missing endpoint;
- duplicate HTTP targets introduced by containers.
- [ ] **Step 4: Run the contract check**

```bash
nix build .#checks.x86_64-linux.containers_contract
```

Expected: pass.

- [ ] **Step 5: Commit**

```bash
git add users/_units/default.nix users/_units/_containers/default.nix
git commit -m "feat: lower my containers to nixos containers"
```

## Chunk 5: Provider and peer schemas

### Task 6: Add draft schemas for providers and peer communication

**Files:**

- Modify: `users/_units/_containers/default.nix`
- Modify: `outputs/checks/containers.nix`
- [ ] **Step 1: Extend option types**

Add schema-only support for:

```nix
consumes.host.postgres = {
  database = "kaneo";
  env = "DATABASE_URL";
};

consumes.containers.redis = {
  endpoint = "redis";
};
```

Implementation may only validate and preserve these declarations in
`config.my.containers` for now.

- [ ] **Step 2: Add check assertions**

Extend `containers_contract` with a synthetic app/redis pair and a
host Postgres edge. Assert the declarations survive normalization and
known target containers/endpoints validate.

- [ ] **Step 3: Run the contract check**

```bash
nix build .#checks.x86_64-linux.containers_contract
```

Expected: pass.

- [ ] **Step 4: Commit**

```bash
git add users/_units/_containers/default.nix outputs/checks/containers.nix
git commit -m "feat: add container communication schemas"
```

## Chunk 6: Final verification

### Task 7: Run repo checks for the draft

**Files:**

- No new files unless fixes are needed.
- [ ] **Step 1: Format**

```bash
nix fmt
```

Expected: pass.

- [ ] **Step 2: Stage intended files**

```bash
git add _lib/containers/default.nix _lib/options/default.nix _lib/with_config.nix users/_units/_containers/default.nix users/_units/default.nix users/_units/actual-budget/default.nix users/_units/actual-budget/unit.nix outputs/checks/default.nix outputs/checks/containers.nix docs/wip/nixos_containers_spec_v2.md docs/wip/nixos_containers_spec_v2_digest.md docs/wip/nixos_containers_spec_v2_plan.md
```

- [ ] **Step 3: Run pre-commit**

```bash
prek
```

Expected: pass.

- [ ] **Step 4: Run targeted checks**

```bash
nix build .#checks.x86_64-linux.containers_contract
nix build .#checks.x86_64-linux.backups-eval
nix eval .#nixosConfigurations.tyrant.config.system.build.toplevel.drvPath
```

Expected: all pass.

- [ ] **Step 5: Commit verification fixes if any**

If formatting or checks changed files:

```bash
git add <changed-files>
git commit -m "fix: satisfy container draft checks"
```

- [ ] **Step 6: Summarize final branch state**

Record:

- worktree path;
- branch name;
- commit SHAs created;
- checks run and results;
- known draft limitations.
