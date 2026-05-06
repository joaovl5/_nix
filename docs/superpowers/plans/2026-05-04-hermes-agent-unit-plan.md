# Hermes Agent Unit Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking. Do not create git commits; the repository instructions prohibit commits without explicit permission.

**Goal:** Add and enable a Hermes Agent NixOS unit on `tyrant`, running 24/7 inside a unit-owned native NixOS container.

**Architecture:** Implement a Hermes-scoped `my."unit.hermes-agent"` module that directly emits `containers.hermes-agent`, host NAT, host-visible state backup, a sops-nix dotenv secret hook, and a guest systemd service running `${pkgs.llm-agents.hermes-agent}/bin/hermes gateway run`. Use explicit host state bind mounts with `privateUsers = "identity"`, no ingress, read-only env-file mounts, and local terminal execution inside the container.

**Tech Stack:** NixOS module system, repo `o.module` helpers, native `containers.<name>`, systemd, existing `pkgs.llm-agents.hermes-agent`, host NAT, sops-nix secret env files, restic backup item conventions.

**Spec:** `docs/superpowers/specs/2026-05-04-hermes-agent-unit-design.md`

---

## File structure

- Create `users/_units/hermes-agent/default.nix`
  - Defines `my."unit.hermes-agent"` options.
  - Emits host tmpfiles, NAT, `containers.hermes-agent`, backup item, and assertions.
  - Defines the guest NixOS config inline in `containers.${name}.config`.
- Modify `users/_units/default.nix`
  - Import `./hermes-agent`.
- Modify `globals/hosts.nix`
  - Enable `my."unit.hermes-agent"` on `tyrant`.
  - Set `nat.external_interface = "enp3s0f1"`.
  - Leave `hermes.environment_files = []`; the unit auto-enables its default sops env-file secret only after `${my.secrets.dir}/hermes-agent.yaml` exists.
- Create this plan document and the design spec under `docs/superpowers/`.

No `npins/`, `inputs.nix`, or `input-overrides.nix` changes are planned.

---

## Chunk 1: Hermes unit module

### Task 1: Create `users/_units/hermes-agent/default.nix`

**Files:**

- Create: `users/_units/hermes-agent/default.nix`

- [ ] **Step 1: Add module header and option types**

Use the existing unit style:

```nix
{
  mylib,
  config,
  pkgs,
  lib,
  ...
}: let
  my = mylib.use config;
  o = my.options;
  s = my.secrets;
  u = my.units;
  t = lib.types;

  inherit (lib) optionalAttrs;

  ContainerPrivateUsers = t.oneOf [
    t.int
    (t.enum [
      "no"
      "identity"
      "pick"
    ])
  ];

  default_sops_environment_file = "${s.dir}/hermes-agent.yaml";
  default_container_id = 30;
in
  o.module "unit.hermes-agent" (with o; {
    enable = toggle "Enable Hermes Agent native-container service" false;
    package = opt "Hermes Agent package." t.package pkgs.llm-agents.hermes-agent;
    state_dir = opt "Host directory for Hermes Agent container state." t.str "/var/lib/containers/hermes-agent/state";

    container = {
      name = opt "NixOS container name." t.str "hermes-agent";
      id = opt "Numeric ID used to derive default routed container addresses." t.int default_container_id;
      auto_start = toggle "Start the Hermes container at boot." true;
      private_users = opt "NixOS container privateUsers mode." ContainerPrivateUsers "identity";
      host_address = optional "Host-side veth IPv4 address." t.str {};
      local_address = optional "Container-side veth IPv4 address." t.str {};
    };

    nat = {
      enable = toggle "Enable host NAT for Hermes container outbound access." true;
      external_interface = optional "Host interface used for outbound NAT." t.str {};
    };

    hermes = {
      settings = opt "Non-secret Hermes config rendered to config.yaml." t.attrs {};
      environment_files = opt "Host env files bind-mounted read-only into the guest." (t.listOf t.str) [];
      sops_environment_file = {
        enable = toggle "Declare a sops-nix Hermes environment file secret and inject it into the guest." (builtins.pathExists default_sops_environment_file);
        name = opt "sops-nix secret name for the Hermes environment file." t.str "hermes_agent_env";
        file = opt "SOPS file containing the Hermes dotenv content." t.str default_sops_environment_file;
        key = opt "SOPS key containing the Hermes dotenv content." t.str "env";
      };
      extra_packages = opt "Extra packages added to the Hermes service PATH inside the guest." (t.listOf t.package) [];
      extra_args = opt "Extra arguments appended to `hermes gateway run`." (t.listOf t.str) [];
    };
  }) {} (opts: ...)
```

- [ ] **Step 2: Define computed paths and settings inside the enabled config**

Inside `(opts: o.when opts.enable (let ... in { ... }))`, define:

```nix
container_name = opts.container.name;
container_veth = "ve-${container_name}";
container_id = opts.container.id;
host_address =
  if opts.container.host_address != null
  then opts.container.host_address
  else "10.88.${toString container_id}.1";
local_address =
  if opts.container.local_address != null
  then opts.container.local_address
  else "10.88.${toString container_id}.2";

guest_state_dir = "/var/lib/hermes";
guest_hermes_home = "${guest_state_dir}/.hermes";
guest_home_dir = "${guest_state_dir}/home";
guest_workspace = "${guest_state_dir}/workspace";

default_settings = {
  terminal = {
    backend = "local";
    cwd = guest_workspace;
  };
};
hermes_settings = lib.recursiveUpdate default_settings opts.hermes.settings;
config_yaml = u.write_yaml_from_attrset "hermes-agent-config.yaml" hermes_settings;

guest_env_dir = "/run/hermes-agent/env";
inherit (opts.hermes) sops_environment_file;
sops_environment_files = lib.optional sops_environment_file.enable (s.secret_path sops_environment_file.name);
host_environment_files = opts.hermes.environment_files ++ sops_environment_files;
guest_environment_files = lib.imap0 (index: _host_path: "${guest_env_dir}/${toString index}") host_environment_files;
env_mounts = lib.listToAttrs (lib.imap0 (index: host_path: {
  name = "${guest_env_dir}/${toString index}";
  value = {
    hostPath = host_path;
    isReadOnly = true;
  };
}) host_environment_files);
```

Keep `guest_environment_files` as the ordered list derived directly from `host_environment_files`; do not derive it from `lib.attrNames env_mounts`, because attr names are sorted and can reorder env-file precedence.

- [ ] **Step 3: Add host assertions and state/backup declarations**

Add:

```nix
assertions = [
  {
    assertion = !(lib.hasInfix "_" container_name);
    message = "my.unit.hermes-agent.container.name must not contain underscores; NixOS containers reject underscores.";
  }
  {
    assertion = !opts.nat.enable || opts.nat.external_interface != null;
    message = "my.unit.hermes-agent.nat.external_interface must be set when NAT is enabled.";
  }
];

sops.secrets = optionalAttrs sops_environment_file.enable {
  ${sops_environment_file.name} = s.mk_secret sops_environment_file.file sops_environment_file.key {};
};

systemd.tmpfiles.rules = [
  "d ${opts.state_dir} 0750 root root - -"
];

my."unit.hermes-agent".backup.items.state = {
  kind = "path";
  policy = "sensitive_data";
  path.paths = [opts.state_dir];
};
```

- [ ] **Step 4: Add host NAT config**

Use `optionalAttrs opts.nat.enable` to set:

````nix
networking.nat = optionalAttrs opts.nat.enable ({
    enable = true;
    internalInterfaces = lib.mkAfter [container_veth];
  } // optionalAttrs (opts.nat.external_interface != null) {
    externalInterface = lib.mkDefault opts.nat.external_interface;
  });

- [ ] **Step 5: Add `containers.${container_name}` host config**

Inside `config`, add the guest PATH package, the `hermes` login shell, and the optional `.env` bind mount:

```nix
containers.${container_name} = {
  autoStart = opts.container.auto_start;
  privateNetwork = true;
  privateUsers = opts.container.private_users;
  restartIfChanged = true;

  hostAddress = host_address;
  localAddress = local_address;

  bindMounts = {
    "${guest_state_dir}" = {
      hostPath = opts.state_dir;
      isReadOnly = false;
    };
  } // optionalAttrs sops_environment_file.enable {
    "${guest_hermes_home}/.env" = {
      hostPath = s.secret_path sops_environment_file.name;
      isReadOnly = true;
    };
  } // env_mounts;

  config = { lib, pkgs, ... }: {
    environment.systemPackages = [opts.package];

    system.stateVersion = "25.11";

    networking = {
      useHostResolvConf = lib.mkForce false;
      firewall.enable = true;
    };
    services.resolved.enable = true;

    users.groups.hermes = {};
    users.users.hermes = {
      isSystemUser = true;
      group = "hermes";
      home = guest_home_dir;
      shell = pkgs.bashInteractive;
    };

    systemd.tmpfiles.rules = [
      "d ${guest_state_dir} 0750 hermes hermes - -"
      "d ${guest_hermes_home} 0750 hermes hermes - -"
      "d ${guest_home_dir} 0750 hermes hermes - -"
      "d ${guest_workspace} 2770 hermes hermes - -"
      "d ${guest_env_dir} 0750 root root - -"
    ];

    system.activationScripts.hermes_agent_setup = lib.stringAfter ["users"] ''
      install -d -o hermes -g hermes -m 0750 ${guest_state_dir}
      install -d -o hermes -g hermes -m 0750 ${guest_hermes_home}
      install -d -o hermes -g hermes -m 0750 ${guest_home_dir}
      install -d -o hermes -g hermes -m 2770 ${guest_workspace}
      install -o hermes -g hermes -m 0640 ${config_yaml} ${guest_hermes_home}/config.yaml
      rm -f ${guest_hermes_home}/.managed
    '';

    systemd.services.hermes-agent = {
      description = "Hermes Agent Gateway";
      wantedBy = ["multi-user.target"];
      after = ["network-online.target"];
      wants = ["network-online.target"];
      path = [
        opts.package
        pkgs.bash
        pkgs.coreutils
        pkgs.git
        pkgs.curl
        pkgs.ripgrep
        pkgs.fd
        pkgs.jq
      ] ++ opts.hermes.extra_packages;
      environment = {
        HOME = guest_home_dir;
        HERMES_HOME = guest_hermes_home;
        MESSAGING_CWD = guest_workspace;
      };
      serviceConfig = {
        User = "hermes";
        Group = "hermes";
        WorkingDirectory = guest_workspace;
        ExecStart = pkgs.writeShellScript "hermes-agent-start" ''
          exec ${lib.escapeShellArgs (["${opts.package}/bin/hermes" "gateway" "run"] ++ opts.hermes.extra_args)}
        '';
        Restart = "always";
        RestartSec = "10s";
        UMask = "0007";
        NoNewPrivileges = true;
        PrivateTmp = true;
      } // optionalAttrs (guest_environment_files != []) {
        EnvironmentFile = guest_environment_files;
      };
    };
  };
};
```


- [ ] **Step 6: Run a syntax/eval probe for the new module file**

Run:

```bash
nix eval .#nixosConfigurations.tyrant.config.my."unit.hermes-agent".enable
```

Expected before registration/host enablement may fail if the unit is not imported yet; after Task 2 it should print `true`.

---

## Chunk 2: Registry and host enablement

### Task 2: Import the unit and enable on `tyrant`

**Files:**

- Modify: `users/_units/default.nix`
- Modify: `globals/hosts.nix`

- [ ] **Step 1: Import the unit**

In `users/_units/default.nix`, add `./hermes-agent` to the imports list near other service units.

- [ ] **Step 2: Enable on `tyrant`**

In `globals/hosts.nix`, under `tyrant.config.my`, add:

```nix
"unit.hermes-agent" = {
  enable = true;
  nat.external_interface = interface_name;
  hermes.environment_files = [];
};
```

Use the existing `interface_name = "enp3s0f1";` binding already in the `tyrant` let-block. The default sops env-file hook points at `${my.secrets.dir}/hermes-agent.yaml` key `env` and remains disabled until that private secret file exists.

- [ ] **Step 3: Run targeted evals**

Run:

```bash
nix eval .#nixosConfigurations.tyrant.config.my."unit.hermes-agent".enable
nix eval .#nixosConfigurations.tyrant.config.containers.hermes-agent.privateNetwork
nix eval .#nixosConfigurations.tyrant.config.containers.hermes-agent.localAddress
nix eval .#nixosConfigurations.tyrant.config.networking.nat.internalInterfaces
```

Expected:

- first two: `true`;
- local address includes/equals `"10.88.30.2"`;
- NAT internal interfaces include `"ve-hermes-agent"`.

---

## Chunk 3: Formatting and verification

### Task 3: Format, stage, run hooks, and build

**Files:**

- All changed files from previous tasks.

- [ ] **Step 1: Run formatter**

Run:

```bash
nix fmt
```

Expected: exits 0. Review any resulting formatting changes.

- [ ] **Step 2: Check changed files**

Run:

```bash
git status --short
```

Expected: only intended files changed:

- `docs/superpowers/specs/2026-05-04-hermes-agent-unit-design.md`
- `docs/superpowers/plans/2026-05-04-hermes-agent-unit-plan.md`
- `users/_units/hermes-agent/default.nix`
- `users/_units/default.nix`
- `globals/hosts.nix`

- [ ] **Step 3: Stage intended files only**

Run:

```bash
git add docs/superpowers/specs/2026-05-04-hermes-agent-unit-design.md \
  docs/superpowers/plans/2026-05-04-hermes-agent-unit-plan.md \
  users/_units/hermes-agent/default.nix \
  users/_units/default.nix \
  globals/hosts.nix
```

Do not commit.

- [ ] **Step 4: Run pre-commit hooks**

Run:

```bash
prek
```

Expected: exits 0. If hooks modify files, review changes, re-stage intended files, and rerun `prek`.

- [ ] **Step 5: Run targeted evals again**

Run the four evals from Task 2 again after formatting/hooks.

Expected: same as before.

- [ ] **Step 6: Build `tyrant` toplevel**

Run:

```bash
nix build .#nixosConfigurations.tyrant.config.system.build.toplevel
```

Expected: exits 0.

- [ ] **Step 7: Decide broader check feasibility**

Because Nix code changed, run `nix flake check --all-systems` only if appropriate and feasible. If blocked by builder/binfmt/time constraints, document the blocker and the targeted checks already run. Expected warnings about unknown flake outputs `deploy` and `pkgs` are normal.

---

## Execution notes

- Do not use `git commit`.
- Do not add a new Hermes input/pin.
- Do not create a generic container helper/framework.
- Do not add ingress/vhosts/routes.
- Do not add tests; the user selected targeted eval/build verification only.
- Runtime secret material can be supplied by creating `${my.secrets.dir}/hermes-agent.yaml` with key `env` containing dotenv content; when the sops environment file is enabled, the unit creates the matching sops secret, bind-mounts it read-only at `${guest_hermes_home}/.env`, and injects it after any extra `hermes.environment_files`.
````
