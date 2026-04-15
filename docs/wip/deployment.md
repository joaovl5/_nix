# Deployment debugging log and reference

## Goal

Restore successful `deploy` activation on `tyrant` by identifying the root causes of service failures before attempting further fixes.

## Debugging rules

- Follow systematic debugging: reproduce, gather evidence, compare patterns, form one hypothesis at a time.
- No new fixes until fresh evidence confirms the failing component and reason.
- Prefer `deploy --skip-checks` for fast activation reproduction during investigation.
- Keep unrelated intentional changes intact. In particular, the removed LiteLLM directory must not be restored without user approval.

## Reusable deployment concepts

- Treat deployment as four separate phases: evaluation/build, copy, activation, and confirmation. Most service-related deploy failures happen in the activation phase, not during build/copy.
- For NixOS + deploy-rs, a deploy can fail even when a service would recover later. Units left `failed` or still `activating (auto-restart)` with a non-zero `ExecMainStatus` can be enough to fail activation.
- Remember that deploy-rs has an automatic rollback feature in case of failures, so always separate **forward-generation blockers** from **rollback artifacts**. After rollback, old services may reappear and create misleading noise that is not the cause of the failed new deploy.
- Prefer **readiness gating** and correct **unit ordering** for activation-critical services. Retry-only behavior often recovers too late to satisfy activation.
- Distinguish **primary blockers** from **downstream casualties**. Fix the first service that destabilizes others before spending time on follow-on failures.
- Validate assumptions on the target host itself: routes, local API behavior, auth mode, and generated service scripts can differ from what the repo alone suggests.

## Common deployment-debugging workflow

1. Reproduce with `deploy --skip-checks` when you specifically need activation evidence and already have recent local check results.
2. Record the exact failed units from the **first activation** of the new generation.
3. Check whether deploy rolled back. If it did, split failures into new-generation blockers vs old-generation rollback noise.
4. For each suspected blocker, inspect `systemctl show`, `systemctl status`, and `journalctl` before changing config.
5. If a failure involves a generated unit or helper script, inspect the evaluated/generated service definition before patching.
6. Implement the smallest fix that changes startup/ordering semantics at the real failure boundary.
7. Re-run local checks, then re-run deploy, then do targeted post-deploy spot checks on the affected units.

## Common commands and procedures

```bash
# Fast activation reproduction
deploy --skip-checks

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

- `ActiveState=failed` with `Result=exit-code` usually means the unit is a direct activation blocker.
- `ActiveState=activating` with `Result=exit-code` means startup has already failed once and systemd may be retrying, but deploy activation can still fail before recovery finishes.
- For `Type=oneshot` services, `ExecMainStatus` matters a lot. If the service did useful work but exits with a known non-fatal code, prove that first, then encode it explicitly with `SuccessExitStatus` rather than guessing.
- If `ExecStartPre` fails, the current blocker is your readiness/guard logic rather than the main service body.
- Later successful retries or later clean manual starts do not retroactively make the original deploy succeed; always judge based on the state during the first activation attempt.

## Common failure classes to check

- **Network churn during activation:** routes or interfaces disappear briefly while networking restarts.
- **Readiness races:** API, database, or socket becomes usable slightly after systemd considers the service started.
- **Ordering mistakes:** a downstream unit starts after a daemon begins, but before its setup/migration/bootstrap unit completes.
- **Generated-script mismatch:** the generated unit script or packaged helper behavior differs from what the source module comment suggests.
- **Auth/client mismatch:** the target service works locally, but a client library assumes a different auth/session mode.
- **Rollback noise:** old-generation services reappear after rollback and distract from the real blocker in the failed new generation.

## Minimum evidence bundle for each failing unit

- `systemctl show` for `ActiveState`, `SubState`, `Result`, and `ExecMainStatus`
- `systemctl status` and `journalctl -u <unit> -n <N> --no-pager`
- whether the failure came from `ExecStartPre`, `ExecStart`, or a downstream dependency
- the evaluated/generated unit script or relevant Nix service attributes when behavior is not obvious from source
- one direct probe on the target host for the dependency in question (for example local `curl`, route check, or socket reachability test)

## Required local verification after Nix changes

```bash
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
- Remote evidence previously showed default routes disappearing before DHCP restored connectivity.
- Generated `wg-up` gates startup on a ping to `89.167.107.74`, so it can fail even when the endpoint is reachable later.

### Pi-hole FTL setup

- `pihole-ftl-setup.service` fails due to early Pi-hole API/database calls during startup.
- The generated setup script records API errors, still completes later steps, then exits non-zero.
- Prior logs included `Communication error. Is FTL running?`, `database_error: Database not available`, and `bad_request`.

### OctoDNS

- `octodns-sync.service` appears downstream of Pi-hole readiness timing.
- Current ordering only ties it to `pihole-ftl.service` / `pihole-pwhash.service`, not completion of `pihole-ftl-setup.service`.

### Actual

- `actual.service` is a separate failure from earlier evidence: `Missing migration file: 1763873600000-backfill-files-owner.js`.
- This may still block activation even if Pi-hole / WireGuard are improved.

## Questions to answer next

1. What exactly fails in a fresh `deploy --skip-checks` run now?
2. Are the current failures caused by the new generation, a rollback, or pre-existing remote state?
3. Which failing services are hard blockers for deploy activation versus incidental post-activation failures?
4. Are there additional independent failures besides WireGuard, Pi-hole, OctoDNS, and Actual?

## Investigation log

- Created this log to track evidence for future agents.

- Parallel diagnosis launched.
- Explore subagents were dispatched to map service dependency/order and deploy activation context.
- Oracle re-consulted after the first harness attempt was interrupted by a queued user message.
- Oracle finding: deploy failure is standard NixOS activation behavior, not a LiteLLM artifact. `outputs/deploy/default.nix` uses `deploy-rs.lib.<system>.activate.nixos`, so any unit left failed or in `auto-restart` with non-zero `ExecMainStatus` can make activation fail.
- Oracle blocker ranking from current evidence: (1) `wg.service`, (2) `pihole-ftl-setup.service` with `octodns-sync.service` as downstream amplifier, (3) `actual.service` as an independent blocker.
- Important nuance: the current retry-based mitigations (`Restart=on-failure`, `RestartSec=5s`) may still be insufficient for deploy success because activation inspects unit state immediately after start/restart, before a delayed retry necessarily succeeds.
- LiteLLM is currently out of intended deployed config on `tyrant`; remaining blockers are the enabled services above, not the intentionally removed LiteLLM directory.
- Next evidence needed: a fresh `deploy --skip-checks` failed-unit list plus matching `systemctl show` / journal output for `wg`, `pihole-ftl-setup`, `octodns-sync`, and `actual`.

## Fresh reproduction: 2026-04-02 / 2026-04-03 session

- Ran `deploy --skip-checks` from `/home/lav/my_nix`.
- Deploy built and copied a new `tyrant` generation successfully, then failed during activation of the new generation.
- Exact failed-unit list during the first activation of the new generation: `octodns-sync.service`, `pihole-ftl-setup.service`, `wg.service`.
- Important: in that first activation, both `pihole-ftl-setup.service` and `wg.service` were in `Active: activating (auto-restart)` when deploy-rs/NixOS evaluated failure. This confirms the current repo changes made it to the host, but also confirms that delayed retries do not prevent activation failure.
- `wg.service` still failed its endpoint reachability gate on the first activation (`failed to reach '89.167.107.74' after 5 attempts`).
- `pihole-ftl-setup.service` still exited non-zero during startup, even though later Pi-hole work completed.
- `octodns-sync.service` failed in the first activation with `Authentication failed: Invalid session response`, consistent with Pi-hole API instability during startup.
- Deploy then rolled back from generation 84 to generation 83. During rollback, the old generation re-added LiteLLM users/secrets/service state (`adding secrets: litellm_master_key, openai_key_litellm`, `the following new units were started: litellm.service`).
- Exact failed-unit list during rollback activation of the old generation: `actual.service`, `pihole-ftl-setup.service`, `wg.service`.
- This means the full set of visible failures is a combination of:
  - first activation blockers in the new generation: WireGuard + Pi-hole setup + downstream OctoDNS, and
  - rollback-generation blockers: Actual + Pi-hole setup + WireGuard, with LiteLLM returning only because rollback restored the previous generation.

## Live remote state after rollback

- `wg.service`: `ActiveState=failed`, `ExecMainStatus=1`.
- `pihole-ftl-setup.service`: `ActiveState=failed`, `ExecMainStatus=1`.
- `octodns-sync.service`: `ActiveState=active`, `SubState=exited`, `ExecMainStatus=0` (it later succeeded after rollback / later Pi-hole readiness).
- `actual.service`: `ActiveState=failed`, `ExecMainStatus=1`.
- `litellm.service`: `ActiveState=active`, `ExecMainStatus=0` (from rolled-back old generation, not from current intended config).

## Targeted journal evidence

### WireGuard

- At `21:35:58`, `wg-up` failed to reach `89.167.107.74` during the new-generation activation.
- At earlier attempts where restart was present, systemd retried 5 seconds later and `wg-up` succeeded (`20:43:14`, `21:36:04`), proving the issue is timing during activation rather than a permanently bad endpoint.
- At rollback time (`21:37:47`), `wg.service` failed again and stayed failed under the old generation.

### Pi-hole setup

- At `21:37:47`, `pihole-ftl-setup-start` logged `database_error` / `Database not available` while adding the blocklist, then still completed gravity update output and exited status 1.
- The script also logged a failed fetch of the MAC vendor database (`curl: (7) Failed to connect to ftl.pi-hole.net port 443`), but the decisive deploy blocker remains the unit's non-zero exit during startup.

### OctoDNS

- `octodns-sync.service` failed during first activation with `Authentication failed: Invalid session response`.
- Later, after rollback / later Pi-hole readiness, `octodns-sync.service` succeeded and is currently active/exited.
- This supports the earlier hypothesis that OctoDNS is downstream of Pi-hole startup timing rather than a stable credential mismatch.

### Actual

- `actual.service` repeatedly fails with `Error: Missing migration file: 1763873600000-backfill-files-owner.js`.
- This is a separate application/data migration problem and not caused by Pi-hole, WireGuard, or LiteLLM removal.

## Current root-cause picture

1. New-generation deploy failure is currently caused by startup-time races in `wg.service` and `pihole-ftl-setup.service`; `octodns-sync.service` is a downstream casualty of Pi-hole not being ready yet.
2. The current retry-based mitigation is insufficient because NixOS activation treats units left failed or in `auto-restart` with non-zero status as deployment failure before the retry can recover them.
3. The reason it looks like 'everything' is failing is that deploy then rolls back into the old generation, which reintroduces LiteLLM and also exposes the independent `actual.service` failure.
4. LiteLLM is not part of the intended current config on `tyrant`; its reappearance is rollback evidence, not a root cause of the new-generation activation failure.

## Oracle confirmation on fresh evidence

- Oracle re-checked the fresh deploy evidence and agreed with the direct blocker split:
  - forward activation blockers: `wg.service` and `pihole-ftl-setup.service`, with `octodns-sync.service` as a downstream failed unit,
  - rollback-only blocker in this deploy attempt: `actual.service`,
  - rollback artifact rather than cause: `litellm.service`.
- Oracle's conclusion: no missing fact materially changes the diagnosis now; the only remaining ambiguity is whether `wg` or `pihole-ftl-setup` was the first decisive blocker, but either one is sufficient to explain the failed deployment.

## Recommended next actions before more deploy attempts

1. **Fix `wg.service` startup semantics** so activation does not fail during transient route loss. The current ping gate is too strict for deploy-time network churn even when the endpoint becomes reachable seconds later.
2. **Fix `pihole-ftl-setup.service` startup semantics** so transient Pi-hole API/database readiness errors do not leave the unit failed during activation.
3. **Order `octodns-sync.service` after successful Pi-hole setup**, not merely after `pihole-ftl.service`, because current evidence shows OctoDNS succeeds once Pi-hole stabilizes.
4. **Treat `actual.service` separately** after the forward deploy path is stable. Its missing migration file is a real blocker on rollback generations but is independent of the new-generation WireGuard/Pi-hole failures.

## Open decision point

- The remaining work is implementation, not investigation. The evidence is now strong enough to move to minimal targeted fixes for WireGuard and Pi-hole setup first, then re-run `deploy --skip-checks`.

## Implementation log

- Replaced the WireGuard retry-based mitigation in `users/_units/wireguard/default.nix` with a bounded `ExecStartPre` reachability gate for the configured endpoint. This prevents deploy-time network churn from putting `wg.service` into `auto-restart` / failed state during activation.
- Replaced the Pi-hole retry-based mitigation in `users/_units/pihole/default.nix` with explicit ordering on `pihole-ftl.service` / `pihole-pwhash.service` plus a bounded `ExecStartPre` poll of the local `/api/lists` endpoint.
- After that readiness gate worked, fresh deploy evidence showed the underlying generated `pihole-ftl-setup` script still exits status 1 for non-fatal Pi-hole/API quirks even after gravity finishes and the old database remains available. To stop that known exit code from failing activation, `SuccessExitStatus = [1];` was added for `pihole-ftl-setup.service`.
- Updated `users/_units/octodns/default.nix` so `octodns-sync.service` runs after `pihole-ftl-setup.service` instead of only after `pihole-ftl.service`.
- OctoDNS still failed once Pi-hole no longer blocked deploy. Fresh evidence showed Pi-hole auth on `http://127.0.0.1:1111/api/auth` returns `session.valid = true` but `sid = null` and `validity = -1`, while unauthenticated local `GET /api/lists` works. This made bundled `pihole6api` fail with `Authentication failed: Invalid session response`. A local patch was added in the `pihole6api` package build to treat this response as a no-session-auth mode and omit auth headers in that case.

## Final verification

- Ran `nix fmt` after each Nix edit pass.
- Ran `prek` on the staged files after each edit pass.
- Ran `nix flake check --all-systems` after the final Nix changes; it completed successfully.
- Ran `deploy --skip-checks` after the final fixes; deployment completed successfully for both `tyrant` and `temperance`, with deploy-rs confirming activation.
- Post-deploy spot-check on `tyrant` via `systemctl show` reported:
  - `wg.service`: `ActiveState=active`, `Result=success`, `ExecMainStatus=0`
  - `pihole-ftl-setup.service`: `ActiveState=inactive`, `Result=success`, `ExecMainStatus=1` (expected under `SuccessExitStatus = [1]`)
  - `octodns-sync.service`: `ActiveState=active`, `Result=success`, `ExecMainStatus=0`
  - `actual.service`: `ActiveState=active`, `Result=success`, `ExecMainStatus=0`

## Follow-up finding: why OctoDNS still seemed necessary after deploy

- Fresh root-cause evidence showed the lingering `octodns-sync` symptom was **not** a missing systemd restart trigger on the current unit graph.
- Direct runtime test on `tyrant` proved `systemctl restart pihole-ftl.service` now does the right thing:
  - `octodns-sync.service` is stopped immediately via `PartOf`,
  - `pihole-ftl-setup.service` runs,
  - `octodns-sync.service` is started again automatically after setup completes.
- The real root cause was **ownership conflict over the same Pi-hole config keys**:
  - `users/_units/pihole/default.nix` declaratively set `services.pihole-ftl.settings.dns.hosts = opts.dns.extra_hosts` and `cnameRecords = []`,
  - `octodns-sync` imperatively writes the same Pi-hole API fields (`config.dns.hosts` / `config.dns.cnameRecords`) via `octodns-pihole`,
  - every successful activation rewrote the Pi-hole config back to the declarative empty/default values, silently clearing the OctoDNS-managed records even when `octodns-sync.service` itself was still `active (exited)`.
- This was proven on-host by comparing the Pi-hole API config and direct DNS results immediately after deploy:
  - after deploy, `host pihole.trll.ing 127.0.0.1` returned `NXDOMAIN`,
  - `GET /api/config` showed `.config.dns.hosts | length == 0`,
  - manual `systemctl restart octodns-sync.service` restored both the API config (`length == 11`) and direct DNS resolution.
- Fix direction: make OctoDNS the sole owner of Pi-hole local DNS records when `unit.octodns` is enabled. The Nix-managed Pi-hole config must omit `dns.hosts` / `dns.cnameRecords` in that mode instead of resetting them on every activation.
- Useful verification commands for this class of issue:
  - `host pihole.trll.ing 127.0.0.1` — direct Pi-hole resolver check
  - authenticated `curl http://127.0.0.1:1111/api/config | jq '.config.dns.hosts | length'` — check Pi-hole persisted config
  - `systemctl show -p ActiveEnterTimestamp -p ActiveState -p SubState octodns-sync.service pihole-ftl.service pihole-ftl-setup.service` — distinguish config loss from actual unit restarts
  - `journalctl -u pihole-ftl.service -u pihole-ftl-setup.service -u octodns-sync.service --since "5 minutes ago"` — correlate state loss with lifecycle events

## Removed unused blocker

- `soularr.service` was removed from the repo/config instead of being debugged further, because it was unused and not worth more deployment investigation.
- The earlier OctoDNS root-cause notes and the reusable deploy-debugging commands above remain the useful part of this log.

## Post-mortem: global Traefik 404 after TCP/UDP abstraction rollout

### Symptom

- After the Forgejo SSH / Traefik stream-routing rollout, multiple `*.trll.ing` domains (`git`, `jellyfin`, `pihole`, and others) returned Traefik `HTTP 404` instead of their normal upstream responses.
- This looked at first like missing HTTP routers or a failed deploy, but Traefik itself was still running and listening on `:80` / `:443`.

### Root cause

- The new Traefik generator in `users/_units/reverse-proxy/traefik/default.nix` always emitted `dynamicConfigOptions.udp = { routers = ...; services = ...; };` even on hosts with **no UDP routes**.
- On `tyrant`, that rendered empty `[udp.routers]` and `[udp.services]` tables into the file-provider config.
- Traefik rejected the entire file-provider config with:
  - `Error while building configuration (for the first time) error="routers cannot be a standalone element (type map[string]*dynamic.UDPRouter)" providerName=file`
- Because the file provider was rejected wholesale, the valid HTTP routers in the same generated file never became active, and requests fell through to Traefik's default 404 handler.
- Important lesson: in Traefik's file provider, a bad TCP/UDP subsection can break otherwise-correct HTTP routing if they are emitted in the same provider document.

### Evidence that made the diagnosis clear

- Representative probes from the client side returned Traefik 404s for multiple domains.
- On `tyrant`, `journalctl -u traefik` showed the UDP file-provider parse error above.
- The generated provider file still contained the expected HTTP routers/services for `git.trll.ing`, `jellyfin.trll.ing`, etc., plus the Forgejo TCP SSH router, so the problem was **not** missing Nix-side vhost registration.
- A local host-header probe on `tyrant` against `127.0.0.1:443` still returned 404, which ruled out public DNS / relay issues and pointed directly at Traefik runtime config loading.

### Minimal fix

- Keep `dynamicConfigOptions.http` unconditional.
- Emit `dynamicConfigOptions.tcp` only when `tcp_routes != {}`.
- Emit `dynamicConfigOptions.udp` only when `udp_routes != {}`.
- This preserves the new abstractions without generating invalid empty UDP sections on hosts that do not use them yet.

### Verification after fix

- Local targeted evals confirmed:
  - on `tyrant`, Traefik dynamic config keys are now only `http` and `tcp`,
  - with a synthetic UDP route, keys become `http`, `tcp`, and `udp` as expected.
- After redeploying `tyrant`, representative domains recovered:
  - `https://git.trll.ing` -> `HTTP 200`
  - `https://jellyfin.trll.ing` -> `HTTP 302`
  - `https://pihole.trll.ing` -> `HTTP 302 /login`
- A local host-header probe on `tyrant` for `git.trll.ing` at `127.0.0.1:443` also returned `HTTP 200`, confirming Traefik loaded the provider config successfully again.

### Operational lessons

- When Traefik returns a sudden global 404 for many unrelated domains, check whether the file provider failed to load before assuming routers disappeared.
- For mixed-protocol generators, avoid emitting empty top-level protocol sections unless Traefik explicitly accepts them.
- Probe from both outside and on the target host itself. The local `curl --resolve <host>:443:127.0.0.1 https://<host>` check was especially useful here because it separated Traefik config failure from DNS / relay / firewall confusion.
- When a deploy changes only Traefik config on `tyrant`, redeploying `tyrant` alone is enough; there is no need to redeploy every host unless the changed module is actually consumed there.
- If local `nix flake check --all-systems` in the current checkout complains about the relative `globals` path input, refresh it in that checkout with `nix flake update globals` before retrying the check.
