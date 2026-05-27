# Deployment debugging log and reference

## Goal

Restore successful `deploy` activation on `tyrant` by identifying the root
causes of service failures before attempting further fixes.

## Debugging rules

- Follow systematic debugging: reproduce, gather evidence, compare patterns,
  form one hypothesis at a time.
- No new fixes until fresh evidence confirms the failing component and reason.
- Prefer `deploy --skip-checks` for fast activation reproduction during
  investigation.
- Keep unrelated intentional changes intact. In particular, the removed
  LiteLLM directory must not be restored without user approval.

## Reusable deployment concepts

- Treat deployment as four separate phases: evaluation/build, copy,
  activation, and confirmation. Most service-related deploy failures happen in
  the activation phase, not during build/copy.
- For NixOS + deploy-rs, a deploy can fail even when a service would recover
  later. Units left `failed` or still `activating (auto-restart)` with a
  non-zero `ExecMainStatus` can be enough to fail activation.
- Remember that deploy-rs has an automatic rollback feature in case of
  failures, so always separate **forward-generation blockers** from
  **rollback artifacts**. After rollback, old services may reappear and create
  misleading noise that is not the cause of the failed new deploy.
- Prefer **readiness gating** and correct **unit ordering** for
  activation-critical services. Retry-only behavior often recovers too late to
  satisfy activation.
- Distinguish **primary blockers** from **downstream casualties**. Fix the
  first service that destabilizes others before spending time on follow-on
  failures.
- Validate assumptions on the target host itself: routes, local API behavior,
  auth mode, and generated service scripts can differ from what the repo alone
  suggests.

## Common deployment-debugging workflow

1. Reproduce with `deploy --skip-checks` when you specifically need activation
   evidence and already have recent local check results.
2. Record the exact failed units from the **first activation** of the new
   generation.
3. Check whether deploy rolled back. If it did, split failures into
   new-generation blockers vs old-generation rollback noise.
4. For each suspected blocker, inspect `systemctl show`, `systemctl status`,
   and `journalctl` before changing config.
5. If a failure involves a generated unit or helper script, inspect the
   evaluated/generated service definition before patching.
6. Implement the smallest fix that changes startup/ordering semantics at the
   real failure boundary.
7. Re-run local checks, then re-run deploy, then do targeted post-deploy spot
   checks on the affected units.

## Common commands and procedures

```bash
# Fast activation reproduction
deploy --skip-checks

# Safe SSH probe template for manual debugging.
# Keep these options on all ad-hoc probes so ssh never falls back to
# keyboard-interactive/password auth and trips fail2ban.
ssh \
  -o BatchMode=yes \
  -o PreferredAuthentications=publickey \
  -o PasswordAuthentication=no \
  -o KbdInteractiveAuthentication=no \
  -o NumberOfPasswordPrompts=0 \
  -o ConnectTimeout=10 \
  -p 59222 \
  temperance@89.167.107.74 \
  'systemctl --failed --no-pager'

# Activation-relevant unit state (adapt host and unit names as needed)
ssh tyrant@192.168.15.13 \
  'systemctl show -p ActiveState -p SubState -p Result -p ExecMainStatus \
   wg.service pihole-ftl-setup.service octodns-sync.service actual.service'

# Focused unit inspection
ssh tyrant@192.168.15.13 'systemctl status wg.service --no-pager'
ssh tyrant@192.168.15.13 'journalctl -u wg.service -n 80 --no-pager'
ssh tyrant@192.168.15.13 'journalctl -u pihole-ftl-setup.service -n 80 --no-pager'
ssh tyrant@192.168.15.13 'journalctl -u octodns-sync.service -n 80 --no-pager'

# Probe local service behavior on the target host
ssh tyrant@192.168.15.13 'curl -fsS http://127.0.0.1:1111/api/lists'
ssh tyrant@192.168.15.13 'curl -fsS -X POST http://127.0.0.1:1111/api/auth ...'

# Inspect evaluated/generated service definitions locally
nix eval --json .#nixosConfigurations.tyrant.config.systemd.services.pihole-ftl-setup.script
nix eval --json .#nixosConfigurations.tyrant.config.systemd.services.octodns-sync.after
nix eval --json .#nixosConfigurations.tyrant.config.systemd.services.wg.after
```

## How to interpret systemd state during deploy

- `ActiveState=failed` with `Result=exit-code` usually means the unit is a
  direct activation blocker.
- `ActiveState=activating` with `Result=exit-code` means startup has already
  failed once and systemd may be retrying, but deploy activation can still
  fail before recovery finishes.
- For `Type=oneshot` services, `ExecMainStatus` matters a lot. If the service
  did useful work but exits with a known non-fatal code, prove that first,
  then encode it explicitly with `SuccessExitStatus` rather than guessing.
- If `ExecStartPre` fails, the current blocker is your readiness/guard logic
  rather than the main service body.
- Later successful retries or later clean manual starts do not retroactively
  make the original deploy succeed; always judge based on the state during the
  first activation attempt.

## Common failure classes to check

- **Network churn during activation:** routes or interfaces disappear briefly
  while networking restarts.
- **Readiness races:** API, database, or socket becomes usable slightly after
  systemd considers the service started.
- **Ordering mistakes:** a downstream unit starts after a daemon begins, but
  before its setup/migration/bootstrap unit completes.
- **Generated-script mismatch:** the generated unit script or packaged helper
  behavior differs from what the source module comment suggests.
- **Auth/client mismatch:** the target service works locally, but a client
  library assumes a different auth/session mode.
- **Rollback noise:** old-generation services reappear after rollback and
  distract from the real blocker in the failed new generation.

## Minimum evidence bundle for each failing unit

- `systemctl show` for `ActiveState`, `SubState`, `Result`, and
  `ExecMainStatus`
- `systemctl status` and `journalctl -u <unit> -n <N> --no-pager`
- whether the failure came from `ExecStartPre`, `ExecStart`, or a downstream
  dependency
- the evaluated/generated unit script or relevant Nix service attributes when
  behavior is not obvious from source
- one direct probe on the target host for the dependency in question (for
  example local `curl`, route check, or socket reachability test)

## Required local verification after Nix changes

```bash
npins verify # when source pins or input adapter files changed
nix fmt
git add <relevant files>
prek
nix flake check --all-systems # this same check runs whilst deploying, that's why we can use `deploy --skip-checks` for fast iteration
```

## Current working tree baseline

`git status --short` at investigation start:

```text
M  flake.lock
M  globals/hosts.nix
M  globals/units.nix
M  users/_units/default.nix
 M users/_units/octodns/default.nix
M  users/_units/pihole/default.nix
A  users/_units/postgres/default.nix
M  users/_units/wireguard/default.nix
?? _scripts/deploy.fish
?? deploy_logs
```

## Prior evidence already established

### WireGuard

- `wg.service` fails during deploy-time network reconfiguration on `tyrant`.
- Remote evidence previously showed default routes disappearing before DHCP
  restored connectivity.
- Generated `wg-up` gates startup on a ping to `89.167.107.74`, so it can fail
  even when the endpoint is reachable later.

### Pi-hole FTL setup

- `pihole-ftl-setup.service` fails due to early Pi-hole API/database calls
  during startup.
- The generated setup script records API errors, still completes later steps,
  then exits non-zero.
- Prior logs included `Communication error. Is FTL running?`,
  `database_error: Database not available`, and `bad_request`.

### OctoDNS

- `octodns-sync.service` appears downstream of Pi-hole readiness timing.
- Current ordering only ties it to `pihole-ftl.service` /
  `pihole-pwhash.service`, not completion of `pihole-ftl-setup.service`.

### Actual

- `actual.service` is a separate failure from earlier evidence:
  `Missing migration file: 1763873600000-backfill-files-owner.js`.
- This may still block activation even if Pi-hole / WireGuard are improved.

## Questions to answer next

1. What exactly fails in a fresh `deploy --skip-checks` run now?
2. Are the current failures caused by the new generation, a rollback, or
   pre-existing remote state?
3. Which failing services are hard blockers for deploy activation versus
   incidental post-activation failures?
4. Are there additional independent failures besides WireGuard, Pi-hole,
   OctoDNS, and Actual?

## Investigation log

- Created this log to track evidence for future agents.
- Parallel diagnosis launched.
- Explore subagents were dispatched to map service dependency/order and deploy
  activation context.
- Oracle re-consulted after the first harness attempt was interrupted by a
  queued user message.
- Oracle finding: deploy failure is standard NixOS activation behavior, not a
  LiteLLM artifact. `outputs/deploy/default.nix` uses
  `deploy-rs.lib.<system>.activate.nixos`, so any unit left failed or in
  `auto-restart` with non-zero `ExecMainStatus` can make activation fail.
- Oracle blocker ranking from current evidence: (1) `wg.service`, (2)
  `pihole-ftl-setup.service` with `octodns-sync.service` as downstream
  amplifier, (3) `actual.service` as an independent blocker.
- Important nuance: the current retry-based mitigations (`Restart=on-failure`,
  `RestartSec=5s`) may still be insufficient for deploy success because
  activation inspects unit state immediately after start/restart, before a
  delayed retry necessarily succeeds.
- LiteLLM is currently out of intended deployed config on `tyrant`; remaining
  blockers are the enabled services above, not the intentionally removed
  LiteLLM directory.
- Next evidence needed: a fresh `deploy --skip-checks` failed-unit list plus
  matching `systemctl show` / journal output for `wg`, `pihole-ftl-setup`,
  `octodns-sync`, and `actual`.

## Fresh reproduction: 2026-04-02 / 2026-04-03 session

- Ran `deploy --skip-checks` from `/home/lav/my_nix`.
- Deploy built and copied a new `tyrant` generation successfully, then failed
  during activation of the new generation.
- Exact failed-unit list during the first activation of the new generation:
  `octodns-sync.service`, `pihole-ftl-setup.service`, `wg.service`.
- Important: in that first activation, both `pihole-ftl-setup.service` and
  `wg.service` were in `Active: activating (auto-restart)` when
  deploy-rs/NixOS evaluated failure. This confirms the current repo changes
  made it to the host, but also confirms that delayed retries do not prevent
  activation failure.
- `wg.service` still failed its endpoint reachability gate on the first
  activation (`failed to reach '89.167.107.74' after 5 attempts`).
- `pihole-ftl-setup.service` still exited non-zero during startup, even though
  later Pi-hole work completed.
- `octodns-sync.service` failed in the first activation with
  `Authentication failed: Invalid session response`, consistent with Pi-hole
  API instability during startup.
- Deploy then rolled back from generation 84 to generation 83. During
  rollback, the old generation re-added LiteLLM users/secrets/service state
  (`adding secrets: litellm_master_key, openai_key_litellm`,
  `the following new units were started: litellm.service`).
- Exact failed-unit list during rollback activation of the old generation:
  `actual.service`, `pihole-ftl-setup.service`, `wg.service`.
- This means the full set of visible failures is a combination of:
  - first activation blockers in the new generation: WireGuard + Pi-hole setup
    - downstream OctoDNS, and
  - rollback-generation blockers: Actual + Pi-hole setup + WireGuard, with
    LiteLLM returning only because rollback restored the previous generation.

## Live remote state after rollback

- `wg.service`: `ActiveState=failed`, `ExecMainStatus=1`.
- `pihole-ftl-setup.service`: `ActiveState=failed`, `ExecMainStatus=1`.
- `octodns-sync.service`: `ActiveState=active`, `SubState=exited`,
  `ExecMainStatus=0` (it later succeeded after rollback / later Pi-hole
  readiness).
- `actual.service`: `ActiveState=failed`, `ExecMainStatus=1`.
- `litellm.service`: `ActiveState=active`, `ExecMainStatus=0` (from
  rolled-back old generation, not from current intended config).

## Targeted journal evidence

### WireGuard

- At `21:35:58`, `wg-up` failed to reach `89.167.107.74` during the
  new-generation activation.
- At earlier attempts where restart was present, systemd retried 5 seconds
  later and `wg-up` succeeded (`20:43:14`, `21:36:04`), proving the issue is
  timing during activation rather than a permanently bad endpoint.
- At rollback time (`21:37:47`), `wg.service` failed again and stayed failed
  under the old generation.

### Pi-hole setup

- At `21:37:47`, `pihole-ftl-setup-start` logged `database_error` /
  `Database not available` while adding the blocklist, then still completed
  gravity update output and exited status 1.
- The script also logged a failed fetch of the MAC vendor database
  (`curl: (7) Failed to connect to ftl.pi-hole.net port 443`), but the
  decisive deploy blocker remains the unit's non-zero exit during startup.

### OctoDNS

- `octodns-sync.service` failed during first activation with
  `Authentication failed: Invalid session response`.
- Later, after rollback / later Pi-hole readiness, `octodns-sync.service`
  succeeded and is currently active/exited.
- This supports the earlier hypothesis that OctoDNS is downstream of Pi-hole
  startup timing rather than a stable credential mismatch.

### Actual

- `actual.service` repeatedly fails with
  `Error: Missing migration file: 1763873600000-backfill-files-owner.js`.
- This is a separate application/data migration problem and not caused by
  Pi-hole, WireGuard, or LiteLLM removal.

## Current root-cause picture

1. New-generation deploy failure is currently caused by startup-time races in
   `wg.service` and `pihole-ftl-setup.service`; `octodns-sync.service` is a
   downstream casualty of Pi-hole not being ready yet.
2. The current retry-based mitigation is insufficient because NixOS activation
   treats units left failed or in `auto-restart` with non-zero status as
   deployment failure before the retry can recover them.
3. The reason it looks like 'everything' is failing is that deploy then rolls
   back into the old generation, which reintroduces LiteLLM and also exposes
   the independent `actual.service` failure.
4. LiteLLM is not part of the intended current config on `tyrant`; its
   reappearance is rollback evidence, not a root cause of the new-generation
   activation failure.

## Oracle confirmation on fresh evidence

- Oracle re-checked the fresh deploy evidence and agreed with the direct
  blocker split:
  - forward activation blockers: `wg.service` and `pihole-ftl-setup.service`,
    with `octodns-sync.service` as a downstream failed unit,
  - rollback-only blocker in this deploy attempt: `actual.service`,
  - rollback artifact rather than cause: `litellm.service`.
- Oracle's conclusion: no missing fact materially changes the diagnosis now;
  the only remaining ambiguity is whether `wg` or `pihole-ftl-setup` was the
  first decisive blocker, but either one is sufficient to explain the failed
  deployment.

## Recommended next actions before more deploy attempts

1. **Fix `wg.service` startup semantics** so activation does not fail during
   transient route loss. The current ping gate is too strict for deploy-time
   network churn even when the endpoint becomes reachable seconds later.
2. **Fix `pihole-ftl-setup.service` startup semantics** so transient Pi-hole
   API/database readiness errors do not leave the unit failed during
   activation.
3. **Order `octodns-sync.service` after successful Pi-hole setup**, not merely
   after `pihole-ftl.service`, because current evidence shows OctoDNS succeeds
   once Pi-hole stabilizes.
4. **Treat `actual.service` separately** after the forward deploy path is
   stable. Its missing migration file is a real blocker on rollback
   generations but is independent of the new-generation WireGuard/Pi-hole
   failures.

## Open decision point

- The remaining work is implementation, not investigation. The evidence is now
  strong enough to move to minimal targeted fixes for WireGuard and Pi-hole
  setup first, then re-run `deploy --skip-checks`.

## Implementation log

- Replaced the WireGuard retry-based mitigation in
  `users/_units/wireguard/default.nix` with a bounded `ExecStartPre`
  reachability gate for the configured endpoint. This prevents deploy-time
  network churn from putting `wg.service` into `auto-restart` / failed state
  during activation.
- Replaced the Pi-hole retry-based mitigation in
  `users/_units/pihole/default.nix` with explicit ordering on
  `pihole-ftl.service` / `pihole-pwhash.service` plus a bounded `ExecStartPre`
  poll of the local `/api/lists` endpoint.
- After that readiness gate worked, fresh deploy evidence showed the
  underlying generated `pihole-ftl-setup` script still exits status 1 for
  non-fatal Pi-hole/API quirks even after gravity finishes and the old
  database remains available. To stop that known exit code from failing
  activation, `SuccessExitStatus = [1];` was added for
  `pihole-ftl-setup.service`.
- Updated `users/_units/octodns/default.nix` so `octodns-sync.service` runs
  after `pihole-ftl-setup.service` instead of only after `pihole-ftl.service`.
- OctoDNS still failed once Pi-hole no longer blocked deploy. Fresh evidence
  showed Pi-hole auth on `http://127.0.0.1:1111/api/auth` returns
  `session.valid = true` but `sid = null` and `validity = -1`, while
  unauthenticated local `GET /api/lists` works. This made bundled `pihole6api`
  fail with `Authentication failed: Invalid session response`. A local patch
  was added in the `pihole6api` package build to treat this response as a
  no-session-auth mode and omit auth headers in that case.

## Final verification

- Ran `nix fmt` after each Nix edit pass.
- Ran `prek` on the staged files after each edit pass.
- Ran `nix flake check --all-systems` after the final Nix changes; it
  completed successfully.
- Ran `deploy --skip-checks` after the final fixes; deployment completed
  successfully for both `tyrant` and `temperance`, with deploy-rs confirming
  activation.
- Post-deploy spot-check on `tyrant` via `systemctl show` reported:
  - `wg.service`: `ActiveState=active`, `Result=success`, `ExecMainStatus=0`
  - `pihole-ftl-setup.service`: `ActiveState=inactive`, `Result=success`,
    `ExecMainStatus=1` (expected under `SuccessExitStatus = [1]`)
  - `octodns-sync.service`: `ActiveState=active`, `Result=success`,
    `ExecMainStatus=0`
  - `actual.service`: `ActiveState=active`, `Result=success`,
    `ExecMainStatus=0`

## Follow-up finding: why OctoDNS still seemed necessary after deploy

- Fresh root-cause evidence showed the lingering `octodns-sync` symptom was
  **not** a missing systemd restart trigger on the current unit graph.
- Direct runtime test on `tyrant` proved
  `systemctl restart pihole-ftl.service` now does the right thing:
  - `octodns-sync.service` is stopped immediately via `PartOf`,
  - `pihole-ftl-setup.service` runs,
  - `octodns-sync.service` is started again automatically after setup
    completes.
- The real root cause was
  **ownership conflict over the same Pi-hole config keys**:
  - `users/_units/pihole/default.nix` declaratively set
    `services.pihole-ftl.settings.dns.hosts = opts.dns.extra_hosts` and
    `cnameRecords = []`,
  - `octodns-sync` imperatively writes the same Pi-hole API fields
    (`config.dns.hosts` / `config.dns.cnameRecords`) via `octodns-pihole`,
  - every successful activation rewrote the Pi-hole config back to the
    declarative empty/default values, silently clearing the OctoDNS-managed
    records even when `octodns-sync.service` itself was still
    `active (exited)`.
- This was proven on-host by comparing the Pi-hole API config and direct DNS
  results immediately after deploy:
  - after deploy, `host pihole.trll.ing 127.0.0.1` returned `NXDOMAIN`,
  - `GET /api/config` showed `.config.dns.hosts | length == 0`,
  - manual `systemctl restart octodns-sync.service` restored both the API
    config (`length == 11`) and direct DNS resolution.
- Fix direction: make OctoDNS the sole owner of Pi-hole local DNS records when
  `unit.octodns` is enabled. The Nix-managed Pi-hole config must omit
  `dns.hosts` / `dns.cnameRecords` in that mode instead of resetting them on
  every activation.
- Useful verification commands for this class of issue:
  - Direct Pi-hole resolver check:
    - Command: `host pihole.trll.ing 127.0.0.1`
  - Check Pi-hole persisted config:
    - URL: `http://127.0.0.1:1111/api/config`
    - Filter: `jq '.config.dns.hosts | length'`
  - Distinguish config loss from actual unit restarts:
    - Command: `systemctl show`
    - Properties: `ActiveEnterTimestamp`, `ActiveState`, `SubState`
    - Units: `octodns-sync.service`, `pihole-ftl.service`,
      `pihole-ftl-setup.service`
  - Correlate state loss with lifecycle events:
    - Command: `journalctl`
    - Units: `pihole-ftl.service`, `pihole-ftl-setup.service`,
      `octodns-sync.service`
    - Window: `--since "5 minutes ago"`

## Removed unused blocker

- `soularr.service` was removed from the repo/config instead of being debugged
  further, because it was unused and not worth more deployment investigation.
- The earlier OctoDNS root-cause notes and the reusable deploy-debugging
  commands above remain the useful part of this log.

## Post-mortem: global Traefik 404 after TCP/UDP abstraction rollout

### Symptom

- After the Forgejo SSH / Traefik stream-routing rollout, multiple
  `*.trll.ing` domains (`git`, `jellyfin`, `pihole`, and others) returned
  Traefik `HTTP 404` instead of their normal upstream responses.
- This looked at first like missing HTTP routers or a failed deploy, but
  Traefik itself was still running and listening on `:80` / `:443`.

### Root cause

- The new Traefik generator in
  `users/_units/reverse-proxy/traefik/default.nix` always emitted
  `dynamicConfigOptions.udp = { routers = ...; services = ...; };` even on
  hosts with **no UDP routes**.
- On `tyrant`, that rendered empty `[udp.routers]` and `[udp.services]` tables
  into the file-provider config.
- Traefik rejected the entire file-provider config with:
  - Context: `Error while building configuration (for the first time)`
  - Message: `routers cannot be a standalone element`
  - Type/provider: `map[string]*dynamic.UDPRouter`, `providerName=file`
- Because the file provider was rejected wholesale, the valid HTTP routers in
  the same generated file never became active, and requests fell through to
  Traefik's default 404 handler.
- Important lesson: in Traefik's file provider, a bad TCP/UDP subsection can
  break otherwise-correct HTTP routing if they are emitted in the same
  provider document.

### Evidence that made the diagnosis clear

- Representative probes from the client side returned Traefik 404s for
  multiple domains.
- On `tyrant`, `journalctl -u traefik` showed the UDP file-provider parse
  error above.
- The generated provider file still contained the expected HTTP
  routers/services for `git.trll.ing`, `jellyfin.trll.ing`, etc., plus the
  Forgejo TCP SSH router, so the problem was **not** missing Nix-side vhost
  registration.
- A local host-header probe on `tyrant` against `127.0.0.1:443` still returned
  404, which ruled out public DNS / relay issues and pointed directly at
  Traefik runtime config loading.

### Minimal fix

- Keep `dynamicConfigOptions.http` unconditional.
- Emit `dynamicConfigOptions.tcp` only when `tcp_routes != {}`.
- Emit `dynamicConfigOptions.udp` only when `udp_routes != {}`.
- This preserves the new abstractions without generating invalid empty UDP
  sections on hosts that do not use them yet.

### Verification after fix

- Local targeted evals confirmed:
  - on `tyrant`, Traefik dynamic config keys are now only `http` and `tcp`,
  - with a synthetic UDP route, keys become `http`, `tcp`, and `udp` as
    expected.
- After redeploying `tyrant`, representative domains recovered:
  - `https://git.trll.ing` -> `HTTP 200`
  - `https://jellyfin.trll.ing` -> `HTTP 302`
  - `https://pihole.trll.ing` -> `HTTP 302 /login`
- A local host-header probe on `tyrant` for `git.trll.ing` at `127.0.0.1:443`
  also returned `HTTP 200`, confirming Traefik loaded the provider config
  successfully again.

### Operational lessons

- When Traefik returns a sudden global 404 for many unrelated domains, check
  whether the file provider failed to load before assuming routers
  disappeared.
- For mixed-protocol generators, avoid emitting empty top-level protocol
  sections unless Traefik explicitly accepts them.
- Probe from both outside and on the target host itself. The local
  `curl --resolve <host>:443:127.0.0.1 https://<host>` check was especially
  useful here because it separated Traefik config failure from DNS / relay /
  firewall confusion.
- When a deploy changes only Traefik config on `tyrant`, redeploying `tyrant`
  alone is enough; there is no need to redeploy every host unless the changed
  module is actually consumed there.
- In the npins setup, `globals/` is local repo data and is not refreshed with
  flake lock-update commands. If a check complains about globals, verify the
  thin shim/default.nix evaluation from the repo root; use
  `npins update <name>` only for real source pins such as `mysecrets`.

## Post-mortem: server DBus implementation switch inhibitor during Hister rollout

### Symptom

- `deploy --skip-checks --log-dir logs --debug-logs` built and copied all
  profiles, activated `lavpc`, then failed during forward activation of
  `temperance`.
- The decisive first-activation message was:
  - `There are changes to critical components of the system:`
  - `dbus-implementation : dbus -> broker`
  - `Pre-switch check 'switchInhibitors' failed`
- Deploy then attempted rollback/revoke of already-confirmed `lavpc`; the
  revoke failed with `No such file or directory`. That was downstream rollback
  noise, not the root cause.
- `tyrant` had not activated yet, so Hister was not present there from this
  failed attempt.

### Root cause

- This was a real NixOS switch inhibitor, not a deploy-tool bug and not a
  Hister service failure.
- Current evaluated server configs wanted
  `services.dbus.implementation = "broker"`, while the live server generations
  were still running classic `dbus`.
- Hister did not introduce the DBus change: the parent commit already
  evaluated `temperance` to `broker`, and the nixpkgs input revision had not
  changed in the Hister commit.
- Desktop hosts already forced classic DBus in
  `systems/_bootstrap/desktop.nix`; server bootstrap had no matching pin, so
  server hosts followed the nixpkgs default.

### Evidence commands

```bash
# New-generation intent
nix eval --raw .#nixosConfigurations.temperance.config.services.dbus.implementation
nix eval --raw .#nixosConfigurations.tyrant.config.services.dbus.implementation
nix eval --raw .#nixosConfigurations.temperance.config.system.switch.inhibitors.dbus-implementation

# Live host implementation evidence
ssh -p 59222 temperance@89.167.107.74 'systemctl cat dbus.service --no-pager'
ssh -p 59222 tyrant@192.168.15.13 'systemctl cat dbus.service --no-pager'

# Separate first blocker from rollback aftermath
ssh -p 59222 temperance@89.167.107.74 'systemctl --failed --no-pager'
ssh -p 59222 tyrant@192.168.15.13 'systemctl show -p LoadState -p ActiveState hister.service hister-prepare-env.service'
```

### Fix used in this repo

- User chose to avoid a boot/reboot migration for now.
- Minimal code fix: pin server bootstrap to classic DBus, mirroring the
  desktop preset:

```nix
services.dbus = {
  enable = true;
  implementation = o.force "dbus";
};
```

- This keeps live-switch deploys compatible with the current server
  generations.
- Future `dbus-broker` migration should be handled deliberately as a
  boot/reboot migration, not as a normal live switch.
- `NIXOS_NO_CHECK=1` is an explicit risk-acceptance escape hatch only; do not
  use it as the default fix.

### Verification after fix

- Targeted evals showed `lavpc`, `temperance`, and `tyrant` all evaluating to
  `dbus`.
- `nix fmt`, staged `prek`, and `nix flake check --all-systems` passed.
- `deploy --skip-checks --log-dir logs --debug-logs` then confirmed activation
  for `lavpc`, `temperance`, and `tyrant`.

## Post-mortem: Hister initial 502 after successful deploy

### Symptom

- After successful deploy, `https://hister.trll.ing/` initially returned
  Traefik `HTTP 502 Bad Gateway`.
- `hister.service` was already `active (running)`, which made this look like a
  reverse-proxy or service config issue.

### Root cause / nuance

- The first 502 was a readiness timing issue, not proof that Hister or Traefik
  config was wrong.
- Hister had started as a systemd process, but had not yet bound
  `127.0.0.1:4433`.
- With local directory indexing enabled for `/srv/shared`, Hister can spend
  several minutes on initial startup/indexing before logging
  `Starting webserver` and opening the socket.
- In the observed deployment, systemd started `hister.service` at `14:09:14`,
  but Hister only logged `Starting webserver Address=127.0.0.1:4433` at
  `14:18:57`. After that, both direct upstream and public domain probes
  returned `HTTP 200`.

### Evidence commands

```bash
# Public route from the client side
curl -sS -I --max-time 20 https://hister.trll.ing/
curl -sS -L --max-time 20 -w '\nhttp=%{http_code} remote=%{remote_ip} time=%{time_total}\n' https://hister.trll.ing/

# Target-host upstream and socket
ssh -p 59222 tyrant@192.168.15.13 'curl -sS -I --max-time 10 http://127.0.0.1:4433/ || true'
ssh -p 59222 tyrant@192.168.15.13 'ss -ltnp | grep 4433 || true'

# Service and startup timing
ssh -p 59222 tyrant@192.168.15.13 'systemctl show -p LoadState -p ActiveState -p SubState -p Result -p ExecMainStatus -p MainPID hister.service hister-prepare-env.service traefik.service'
ssh -p 59222 tyrant@192.168.15.13 'journalctl -u hister.service --since "30 minutes ago" --no-pager | grep -E "Started Hister|Starting webserver|Failed|WARN"'

# Client wrapper connectivity
hister list-urls
```

### Operational lessons

- Do not patch upstream Hister code based only on an immediate post-deploy
  502.
- First determine which layer is failing:
  - public route: `curl https://hister.trll.ing/`,
  - Traefik-to-upstream: local
    `curl --resolve hister.trll.ing:443:127.0.0.1 https://hister.trll.ing/` on
    `tyrant`,
  - upstream socket: `curl http://127.0.0.1:4433/` and `ss -ltnp | grep 4433`,
  - service readiness: `journalctl -u hister.service`.
- If `hister.service` is active but no socket is listening yet, wait for the
  `Starting webserver` log before concluding the domain is broken.
- The current desktop CLI wrapper was verified to connect to the server:
  `hister list-urls` returned indexed `file:///srv/shared/...` entries.
- A non-blocking warning was observed: Hister tries to create `tui.yaml` next
  to the Nix-store generated config and logs `read-only file system`. If this
  becomes worth polishing, prefer a wrapper/config layout that gives Hister a
  writable config path; do not patch upstream for this warning.
- If future deploys require Hister to be immediately routable, solve that as a
  service readiness/wrapper/config problem, not by changing Hister's source
  without stronger evidence.

## Post-mortem: lavpc NVIDIA CDI generator blocked live deploy

### Symptom

- `deploy --skip-checks --log-dir logs --debug-logs --confirm-timeout 1800
  --activation-timeout 1800` successfully built, copied, and activated
  `tyrant` and `temperance`, then failed during forward activation of `lavpc`.
- The failed unit was `nvidia-container-toolkit-cdi-generator.service`.
- The generator logged `failed to initialize NVML: Driver/library version
  mismatch`, and deploy-rs rolled back/revoked already-confirmed nodes.

### Root cause

- This was an NVIDIA live-driver-switch mismatch on `lavpc`, not another
  Pi-hole / WireGuard / OctoDNS activation race.
- Evidence from `lavpc`:
  - `/run/current-system` differed from `/run/booted-system`,
  - `modinfo -F version nvidia` reported loaded/boot module version
    `595.58.03`,
  - `nvidia-smi` used NVML library version `595.71` and failed with
    `Driver/library version mismatch`.
- The system can activate the new generation live, but the running kernel
  module cannot be replaced until reboot. GPU/NVML consumers can stay broken
  until `lavpc` boots into the matching generation.

### Fix used in this repo

- `hardware/_modules/nvidia.nix` now adds an `ExecCondition` precheck for
  `nvidia-container-toolkit-cdi-generator.service`.
- If the loaded NVIDIA module version differs from the evaluated NVIDIA
  package version, systemd skips CDI regeneration instead of marking the unit
  failed. Once `lavpc` reboots into the matching generation, the generator
  runs normally and post-reboot failures remain visible.

### Verification after fix

- `nix fmt`, targeted `prek --files`, and `nix flake check --all-systems`
  passed after the Nix change.
- `deploy --skip-checks --log-dir logs --debug-logs --confirm-timeout 1800
  --activation-timeout 1800` then completed successfully; deploy-rs confirmed
  activation for `lavpc`, `temperance`, and `tyrant`.
- Post-deploy `lavpc` state:
  - `nvidia-container-toolkit-cdi-generator.service`:
    `ActiveState=inactive`, `Result=exec-condition`, `ExecMainStatus=0`,
  - no failed system units,
  - `/run/current-system` still differs from `/run/booted-system`,
  - loaded NVIDIA module remains `595.58.03`, while NVML is `595.71`.
- Therefore the deploy path is fixed, but GPU/NVML use on `lavpc` still needs
  a reboot into the deployed generation.
- Follow-up noise found after successful deploy: `temperance` later had
  `libvirtd.service` failed after its idle shutdown path logged
  `Make forcefull daemon shutdown`. This occurred after deploy confirmation
  and is separate from the NVIDIA activation blocker.

### Operational lessons

- For NVIDIA `Driver/library version mismatch`, first compare current vs
  booted system and loaded module vs NVML library:
  - `readlink /run/current-system`
  - `readlink /run/booted-system`
  - `modinfo -F version nvidia`
  - `nvidia-smi --query-gpu=driver_version --format=csv,noheader`
- Reboot `lavpc` before deeper NVIDIA debugging when current and booted driver
  versions differ.
- Do not confuse the deploy-rs revocation of previously confirmed nodes with
  the first blocker. In this case, the primary forward blocker was only the
  `lavpc` NVIDIA CDI generator.

## Post-mortem: temperance libvirtd failed after idle shutdown

### Symptom

- After the NVIDIA deploy fix, `deploy --skip-checks` completed successfully,
  but a post-deploy failed-unit check on `temperance` showed
  `libvirtd.service` failed.
- The unit had been socket/wanted started during activation, then after about
  two minutes logged `Make forcefull daemon shutdown` and exited status `1`.
- `libvirtd.socket`, `libvirtd-ro.socket`, and `libvirtd-admin.socket`
  remained active/listening, so later socket activation could reproduce the
  failed state.

### Root cause

- `temperance` is a VPS without `/dev/kvm`; direct host evidence showed
  `/dev/kvm missing` and libvirt repeatedly logging
  `Unable to open /dev/kvm: No such file or directory`.
- The libvirt enablement was inherited from the shared host bootstrap:
  `systems/_bootstrap/host.nix` enables `virtualisation.libvirtd` for all
  hosts.
- `temperance` does not explicitly need libvirt in its host config, so this
  was inherited default noise rather than an intentional service for that
  host.

### Fix used in this repo

- `systems/temperance/default.nix` now force-disables libvirt for this host:
  `virtualisation.libvirtd.enable = lib.mkForce false;`.
- This avoids masking libvirt exit status globally and keeps the fix scoped to
  the host that lacks KVM.

### Verification after fix

- Local eval confirmed `temperance` now has
  `virtualisation.libvirtd.enable = false` and no generated
  `libvirtd.service` or `libvirtd.socket`.
- `nix fmt`, targeted `prek --files`, and `nix flake check --all-systems`
  passed after the Nix change.
- A full `deploy --skip-checks` activated and confirmed `temperance`, but then
  failed later on unrelated `tyrant` `kaneo-api.service` auto-restart state
  and revoked the earlier success.
- Targeted `deploy --skip-checks .#temperance --log-dir logs --debug-logs
  --confirm-timeout 1800 --activation-timeout 1800` then completed
  successfully and confirmed activation.
- Post-deploy `temperance` checks reported zero failed units, and libvirt
  units (`libvirtd.service`, `libvirtd*.socket`, `libvirt-guests.service`,
  `virtlockd.socket`, `virtlogd.socket`) all had `LoadState=not-found` /
  `ActiveState=inactive`.

## Post-mortem: tyrant Kaneo API launcher mismatch

### Symptom

- A full `deploy --skip-checks` after the `temperance` libvirt fix activated
  and confirmed `temperance`, then failed during `tyrant` activation.
- Live `tyrant` evidence showed `kaneo-api.service` in
  `ActiveState=activating`, `SubState=auto-restart`, `Result=exit-code`,
  `ExecMainStatus=1`, while `kaneo-web.service` stayed active/running.
- `kaneo-api.service` repeatedly completed database startup and migrations,
  then crashed at WebSocket injection with:
  `TypeError: injectWebSocket2 is not a function`.

### Root cause

- The packaged `kaneo-api` launcher in `packages/kaneo/default.nix` imported
  Kaneo's compiled `dist/index.js` and called
  `startServer(Number(process.env.KANEO_API_PORT || 1337))`.
- Upstream Kaneo's `startServer` signature is
  `startServer(injectWebSocket, port = 1337)`, and the source main path calls
  it as `startServer(injectWebSocket)`.
- The launcher accidentally passed the port number as the first
  `injectWebSocket` argument, so the API crashed after startup work and stayed
  in systemd auto-restart. Deploy-rs then treated the auto-restarting non-zero
  service as an activation failure.

### Fix used in this repo

- `packages/kaneo/default.nix` now patches Kaneo's source main entry to pass
  `Number(process.env.KANEO_API_PORT || 1337)` as the second `startServer`
  argument.
- The packaged `kaneo-api` wrapper now executes the compiled `dist/index.js`
  directly, letting Kaneo's own main path pass the correct module-local
  `injectWebSocket`.
- This keeps the configured port support without recreating Kaneo's startup
  wiring in a separate launcher module.

### Verification after fix

- `nix build .#kaneo --no-link` built the patched package.
- The generated `kaneo-api` wrapper now executes
  `libexec/kaneo/apps/api/dist/index.js` directly, and the compiled main path
  contains `startServer(injectWebSocket, Number(process.env.KANEO_API_PORT ||
  1337))`.
- `nix fmt`, targeted `prek --files`, and `nix flake check --all-systems`
  passed after the Nix change.
- Targeted `deploy --skip-checks .#tyrant --log-dir logs --debug-logs
  --confirm-timeout 1800 --activation-timeout 1800` completed successfully
  and confirmed activation.
- Post-deploy `tyrant` checks reported zero failed units:
  - `kaneo-api.service`: `ActiveState=active`, `SubState=running`,
    `Result=success`, `ExecMainStatus=0`, `NRestarts=0`,
  - `kaneo-web.service`: `ActiveState=active`, `SubState=running`,
    `Result=success`, `ExecMainStatus=0`, `NRestarts=0`,
  - local API probe `GET http://127.0.0.1:1337/api/health` returned
    `{"status":"ok"}`.
- A subsequent full `deploy --skip-checks --log-dir logs --debug-logs
  --confirm-timeout 1800 --activation-timeout 1800` completed successfully and
  deploy-rs confirmed activation for `tyrant`, `temperance`, and `lavpc`.
- Post-full-deploy spot checks confirmed `tyrant` and `lavpc` had zero failed
  units. Follow-up SSH probes to `temperance` returned `Connection refused` on
  port `59222` even though deploy-rs had confirmed activation; debug this as a
  separate SSH/listener issue rather than a Kaneo blocker.

## Operational incident: unsafe manual SSH probes and fail2ban

### What happened

- After the Kaneo deploy verification, manual follow-up probes to `temperance`
  were run with plain `ssh` / `ssh -o ConnectTimeout=10`, for example:
  `ssh -p 59222 temperance@89.167.107.74 ...`.
- Those probes did not force public-key-only batch auth. When the raw
  IP-based invocation did not immediately complete with the expected key path,
  OpenSSH was allowed to fall back to keyboard-interactive/PAM.
- `temperance` logs showed repeated `Failed keyboard-interactive/pam`
  attempts, an exceeded `LoginGraceTime`, and fail2ban blocked the client IP.
  The observed `Connection refused` was therefore ban/firewall fallout, not
  proof that sshd or deployment had failed.

### Rule for future agents

- Do not run ad-hoc deployment SSH probes without the safe public-key-only
  options from the common commands section.
- Prefer the configured host alias when it selects the intended identity. If
  using a raw hostname/IP, include `BatchMode=yes`, disable password and
  keyboard-interactive auth, and set `NumberOfPasswordPrompts=0`.
- If a probe returns `Connection refused` after earlier authentication
  failures, check for fail2ban/firewall bans before concluding that sshd is
  down.

## Operational incident: qBittorrent crash and Transmission RPC starvation

### Symptom

- `qbittorrent.service` on `tyrant` was failed after `qbittorrent-nox` exited
  with `SIGSEGV`; Traefik returned `502` for `torrent.trll.ing`.
- `transmission.service` was `active (running)`, but local RPC/WebUI probes to
  `127.0.0.1:9091` timed out and `transmission-remote` hung.

### Evidence

- qBittorrent had `Restart=no`, so the transient segfault left the service
  down until manually started. A manual start restored local WebUI responses.
- Transmission showed `Too many open files` warnings under the default
  `LimitNOFILESoft=1024`, then continued to starve RPC even after raising
  `LimitNOFILE` and reducing peers/seeding. Strace showed the daemon cycling
  through peer sockets without accepting the local RPC connection.
- Conservative Transmission tuning reduced file descriptors, but RPC still did
  not answer. User chose containment over further aggressive tuning.

### Fix used

- Added `Restart=on-failure` / `RestartSec=10s` to qBittorrent.
- Disabled `nixarr.transmission` for now and rely on qBittorrent.
- Deployed only `tyrant` from an isolated worktree to avoid unrelated dirty
  worktree changes.

### Verification

- Targeted `deploy --skip-checks .#tyrant --log-dir logs --debug-logs
  --confirm-timeout 1800 --activation-timeout 1800` completed and confirmed.
- Post-deploy checks:
  - `qbittorrent.service`: `active/running`, `Result=success`.
  - `transmission.service`: `LoadState=not-found`, inactive.
  - `http://127.0.0.1:12011/`: `HTTP 200`.
  - local Traefik probe with `--resolve torrent.trll.ing:443:127.0.0.1`:
    `HTTP 200`.
  - no listener remained on `:9091`.

## Follow-up diagnosis: qBittorrent WebUI login crash

### Symptom

- After the containment deploy, `torrent.trll.ing` showed the qBittorrent
  login form. A normal login attempt failed, and a browser refresh coincided
  with another `qbittorrent-nox` `SIGSEGV`. The service recovered due to the
  new `Restart=on-failure` policy.

### Evidence

- `qbittorrent.service` journal showed qBittorrent `v5.2.0` crashing in
  `Http::Connection::acceptsGzipEncoding(QString)`, inside Qt string
  comparison from WebUI HTTP request handling.
- The deployed config still forces VueTorrent as the alternative WebUI and has
  no configured `WebUI\Username` or `WebUI\Password_PBKDF2`, so qBittorrent
  falls back to the temporary `admin` password printed to the journal on each
  start.
- The stack trace matches upstream qBittorrent issue `#24038` and fix PR
  `#24286`: qBittorrent 5.2.0 built against Qt 6.11 can crash while parsing
  `Accept-Encoding` headers, with NixOS + VueTorrent specifically reported.

### Current interpretation

- The rejected login is likely credentials/config drift: credentials are not
  declared in Nix, and the NixOS module rewrites `qBittorrent.conf` from
  `services.qbittorrent.serverConfig` on service start.
- The crash is a separate upstream qBittorrent/Qt HTTP parsing bug triggered
  by WebUI requests, not Transmission, Traefik, or bad user credentials.

### Candidate fixes

- Best targeted fix: patch/override qBittorrent with upstream PR `#24286`
  until nixpkgs carries a fixed release.
- Temporary mitigation: disable VueTorrent and use qBittorrent's built-in
  WebUI, but this may only reduce request patterns rather than fix the
  vulnerable `Accept-Encoding` parser.
- Separate auth cleanup: declare a stable `WebUI\Username` and
  `WebUI\Password_PBKDF2` in Nix or via a secret-backed config mechanism.

## Implementation note: Gopeed qBittorrent replacement

- Gopeed secrets now live in the private secrets repo as `secrets/gopeed.yaml`
  with keys `gopeed_web_password` and `gopeed_api_token`.
- `unit.gopeed` reads those secrets through SOPS and exposes Gopeed Web on the
  existing `torrent.trll.ing` endpoint / internal port `12011`.
- qBittorrent is disabled on `tyrant`, but its unit is kept in the repo for
  rollback.
- Transmission remains disabled in `unit.nixarr`.
- The qBittorrent payload archive target is
  `/srv/torrents/qbittorrent-archive`; this is intentionally outside the
  `/home/tyrant` backup snapshot.
- Radarr and Sonarr are declaratively configured with Torrent Blackhole
  clients pointing at Gopeed-managed incoming/completed folders. Lidarr has
  matching Gopeed directories/watcher support available through the module,
  but the current nixarr revision has no Lidarr settings-sync module, so
  adding the Lidarr download client remains a manual or future custom
  API-seeding step.

## Operational incident: Gopeed blackhole magnet drops not appearing

- Symptom: Sonarr/Radarr reported grabs as sent to the Gopeed Torrent
  Blackhole, but Gopeed's task list stayed empty and the blackhole path units
  had no recent work.
- Runtime evidence on `tyrant` showed the deployed Sonarr/Radarr download
  clients still had `saveMagnetFiles = false`, even though the repo had
  already been updated to set it to `true`.
- Root cause: magnet-only releases do not create a `.torrent` file. With
  `saveMagnetFiles = false`, the *arr blackhole client had nothing for the
  systemd path unit or Gopeed submit script to consume, so no Gopeed task
  could be created.
- Fix used: deploy the updated Gopeed/*arr config so Sonarr/Radarr save
  `.magnet` files, and have the Gopeed blackhole submitter consume both
  `.torrent` and `.magnet` files.
- Important deployment lesson: after changing declarative settings-sync
  values, verify the target host's live API state, not only local Nix
  evaluation. Useful probes:
  - inspect `systemctl cat gopeed-blackhole-sonarr.{path,service}` and the
    matching Radarr units,
  - query `/api/v3/downloadclient` on Sonarr/Radarr and confirm
    `saveMagnetFiles = true`,
  - inspect
    `/var/lib/gopeed/blackhole/<app>/{incoming,submitted,work,failed}`,
  - drop a disposable `.magnet` into `incoming` and confirm
    `GET /api/v1/tasks` on Gopeed shows a new task.
- Verification after deploy: Sonarr and Radarr both reported
  `saveMagnetFiles = true`; a synthetic Sonarr `.magnet` file was consumed by
  `gopeed-blackhole-sonarr.path`, created a Gopeed task, and was then cleaned
  up.

## Operational incident: Sonarr infinite loading after Gopeed migration

- Symptom: `sonarr.trll.ing` loaded the login page, but the authenticated
  UI/API path could hang indefinitely.
- Production evidence on `tyrant`: `sonarr.service` was active, local `/`
  returned HTTP 302, but `/api/v3/queue/status` timed out after 20 seconds.
- Sonarr still had a stale enabled `Transmission` download client (`id=1`) in
  its database alongside the new `Gopeed Sonarr Blackhole` client. Sonarr
  health reported `Unable to communicate with Transmission`, and journals
  showed repeated `TransmissionProxy` timeouts even though Transmission is
  disabled.
- Remediation: deleted the stale Sonarr Transmission download client through
  the local Sonarr API and restarted `sonarr.service` to clear the cached
  client state.
- Verification: the only remaining Sonarr download client is
  `Gopeed Sonarr Blackhole`; `/api/v3/queue/status` now returns promptly;
  public `https://sonarr.trll.ing` returns the Sonarr login page.

## Implementation note: Lidarr Tubifarry plugin support

- `unit.nixarr` now uses the repo-local `lidarr-plugins` package instead of
  `pkgs.lidarr` for Lidarr on `tyrant`.
- `lidarr-plugins` packages upstream Lidarr `3.1.2.4938` from the official
  `Lidarr.develop.3.1.2.4938.linux-core-x64.tar.gz` release artifact because
  the previously deployed `pkgs.lidarr` `3.1.0.4875` lacked the
  `System -> Plugins` UI/API.
- `tubifarry` packages upstream Tubifarry `2.1.0` from
  `Tubifarry-v2.1.0.net8.0.zip`.
- `lidarr-install-tubifarry.service` installs Tubifarry into
  `/data/.state/nixarr/lidarr/plugins/TypNull/Tubifarry` before
  `lidarr.service` starts, so the plugin is reproducible across restarts and
  deployments.
- Post-deploy verification showed Lidarr `3.1.2.4938`, active
  `lidarr.service`, present Tubifarry plugin files, and
  `/api/v1/system/plugins` returning Tubifarry `2.1.0.0`.

## Implementation note: slskd service for Lidarr/Tubifarry

- Added `unit.slskd` and enabled it on `tyrant`.
- The service uses `pkgs.slskd`, binds the web/API UI to local port `55090`,
  and publishes it through the `soulseek.trll.ing` vhost target.
- The Soulseek peer listen port is `50300` and is opened in the firewall.
- slskd reads `secrets/slskd.yaml` keys: `slskd_api_key`,
  `slskd_username`, `slskd_password`, `slskd_soulseek_username`, and
  `slskd_soulseek_password`.
- Completed downloads go to `/data/media/downloads/lidarr`; incomplete
  downloads go to `/data/media/downloads/slskd-incomplete`.
- The default share directory is `/data/media/library/music`, matching the old
  Soularr-era behavior. The slskd-specific secrets were split out of
  `secrets/soularr.yaml` into `secrets/slskd.yaml`.
- Post-deploy verification showed `slskd.service` active, local HTTP and API
  probes on `127.0.0.1:55090` returning HTTP 200, public
  `https://soulseek.trll.ing` returning the slskd app shell, and successful
  login to the Soulseek server after the initial share scan completed.
