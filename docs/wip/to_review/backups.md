# Backups: Overview, Runbook, and Implementation Notes

## Basic Overview

### What this system is

This repository implements a declarative, Restic-based backup framework pipeline driven from Nix configuration.

At a high level:

1. backup items are declared in Nix
2. items are resolved through backup policies
3. every enabled item backs up first to repository role `A`
4. promotion and maintenance units are rendered from that resolved state
5. systemd services and timers execute the resulting backup flow

Promotion is modeled as `A -> B,C`, not as direct writes from the original source item to every destination.

### Current verification status

At the time of writing:

- `nix build .#checks.x86_64-linux.backups_eval --no-link` passes
- `nix build .#checks.x86_64-linux.backup_local --no-link` passes
- `nix build .#checks.x86_64-linux.backup_promotion --no-link` passes
- `nix fmt` passes
- `git add . && prek` passes
- `nix flake check` passes on the current host
- `nix flake check --all-systems` is still blocked here by missing `aarch64-linux` builder/binfmt support

### Separate eval proof from runtime proof

These are different kinds of verification.

**Eval coverage (`backups_eval`) proves generated structure, including:**

- expected local backup jobs exist
- excluded jobs do not exist
- promotion / forget / prune / check units render as expected
- network / SSH-related unit wiring is present where required
- `postgres_dump` currently renders as a split model where the generated Restic service stays `root` while the payload command drops to the requested non-root user

**Runtime VM coverage proves live execution, including:**

- local path backup and restore
- custom stdin backup and restore
- PostgreSQL dump backup and restore
- retention (`forget`) and maintenance (`prune` / `check`) on repository role `A`
- promotion from repository role `A` to repository role `B` over SFTP
- restore from promoted repository role `B`
- SSH key-based authentication for SFTP promotion

### What the VM tests currently prove

**`backup_local` proves:**

- path backup execution
- path restore content equality
- custom/stdin backup execution
- custom/stdin restore content equality
- PostgreSQL dump execution
- PostgreSQL dump restore correctness by importing the restored SQL dump into a disposable database and checking a known row value
- `forget`, `prune`, and `check` service execution on role `A`

**`backup_promotion` proves:**

- local backup into role `A`
- promotion from role `A` to role `B`
- SFTP / SSH authentication for role `B`
- restore from role `B`
- `prune` and `check` execution on role `B`

### What is still only proven by real-host drills

The VM tests are strong happy-path evidence, but they do not replace live drills.

Still unproven on real hosts:

- real filesystem state, disk pressure, and real network conditions
- Btrfs snapshot runtime behavior on production filesystems
- MariaDB dump backup and restore on production-like data
- true first-run remote path bootstrap for role `B` when the destination repo path does not already exist

### Declarative operating contract

This system is intended to be declarative.

**Backup intent must be declarative:**

- which items are backed up
- which policy they use
- which destinations exist
- which host is the promotion coordinator
- which secrets are required

**Destination-side storage prerequisites must also be declarative:**

- local repository roots such as `/var/lib/backups/repos`
- remote repository trees addressed by SFTP repository templates
- ownership and writeability for the SSH account or local service user that must access the repo

**Restores remain imperative by nature:**

- choosing which snapshot to restore
- choosing a scratch target directory
- importing restored SQL into a disposable database or container
- validating the restored content

That split is intentional.

### Important distinction: Restic repo init vs filesystem provisioning

Promotion units can:

- probe a repo path with `restic cat config`
- run `restic init` if the repository is empty
- run `restic copy`

Promotion units do **not**:

- `mkdir -p` a missing remote filesystem path
- `chown` / `chmod` the remote filesystem path
- bootstrap storage-side permissions over SFTP

That means role `B` storage hosts must declaratively provision the repo path that the `repository_template` points to.

If backups only work after a human manually SSHs into the remote host and creates directories, that is a design failure for this system.

### Current real topology

#### `tyrant`

`tyrant` is currently:

- the backup coordinator host
- the storage location for repository role `A`
- a source host with local backup items

Configured repo templates:

- role `A`: `/var/lib/backups/repos/{host}`
- role `B`: `sftp:temperance@89.167.107.74:/var/lib/backups/repos/{host}`

Declared local items include:

- `home_snapshot` (`path`, promoted to `B`) for `/home/tyrant` with explicit excludes for Soularr data and Docker state
- Pi-hole state (`/var/lib/pihole` only; logs are not backed up)
- Traefik ACME state (`critical_infra` policy; every 6 hours)
- Actual Budget state
- Fxsync MariaDB dumps for both databases
- Soularr state

#### `lavpc`

`lavpc` is currently a source host that writes local backups into repository role `A` on `tyrant`.

Configured repo template:

- role `A`: `sftp:tyrant@192.168.15.13:/var/lib/backups/repos/{host}`

Declared local host item:

- `shared_sync` for `/home/lav/.sensitive`

#### `temperance`

`temperance` does not currently originate local backup items in this setup.

It participates as the remote storage host for repository role `B` over SFTP.

That means `temperance` must declaratively guarantee:

- the repo tree addressed by the `B` repo template exists
- the SSH account in the repo URL can write to it
- disk space and permissions are appropriate for Restic repositories

---

## Operator-Focused Runbook and Instructions

### Operator prerequisites

Before drills or normal service use, confirm all of the following are true on the relevant hosts:

- the desired backup configuration has been applied
- generated backup-related units exist on the live system
- required secret files exist under `/run/secrets`
- SSH authentication works non-interactively for SFTP-backed destinations
- destination-side repo paths are already provisioned declaratively and are writable by the service/SSH account that must use them

### Secrets and access requirements

#### Required SOPS keys in `backups.yaml`

The current backup configuration requires:

- `restic_a_password`
- `restic_b_password`
- `restic_b_env`

These map to generated service secrets:

- role `A` password -> `backup_restic_password_A`
- role `B` password -> `backup_restic_password_B`
- role `B` environment file -> `backup_restic_env_B`

#### Optional only if role `C` is enabled later

- `restic_c_password`
- `restic_c_env`

#### Existing application secret reused by backups

The backup system also depends on the Fxsync MariaDB password secret:

- `fxsync.yaml` -> `mariadb_password`

This is reused by generated `mysqldump` jobs.

#### Secret format guidance

**Restic repository passwords** (`restic_a_password`, `restic_b_password`, `restic_c_password`):

- format: plain text string
- recommendation: long, random, high-entropy password
- practical guidance: at least 24-32+ random characters
- `A`, `B`, and `C` are logically separate repo roles and do not need to share the same password

Example:

```yaml
restic_a_password: "<long-random-password>"
restic_b_password: "<long-random-password>"
```

**Environment-file secrets** (`restic_b_env`, `restic_c_env`):

- format: shell-style `KEY=value` lines
- purpose: backend-specific environment variables for Restic
- for the current SFTP-based role `B`, this may be empty if SSH access works through normal key configuration and no extra environment variables are needed
- for a future cloud/rclone-style role `C`, this is the expected place for backend env vars

Comment-only `restic_b_env` is fine when unused:

```dotenv
# currently unused for sftp backend B
```

#### Non-SOPS operational material

Promotion to role `B` also depends on SSH connectivity from the coordinator host to the remote host in the SFTP repository URL.

That includes:

- private key material for the SSH account in the repo URL
- corresponding authorized key on the remote host
- host trust / known_hosts strategy compatible with non-interactive service execution

If the SOPS secrets exist but SSH credentials or trust do not, promotion to `B` will still fail.

### Setting up backups for a new host

When adding a new source host to this system, treat the following as the minimum checklist.

#### 1. Enable the backup module on the host

Declare `my."unit.backup"` for that host and decide:

- whether the host is itself the coordinator or points at an existing `coordinator_host`
- which destinations it should use
- what local host-owned items it should declare under `host_items`
- which unit-owned items come from enabled units' `backup.items`

#### 2. Choose the repository role `A` target

Every enabled item always backs up first to role `A`.

For a new host, decide whether role `A` is:

- local filesystem-backed on the same host
- or remote SFTP-backed to another host such as `tyrant`

That decision determines both the `repository_template` and the operational/storage prerequisites.

#### 3. Make destination paths declarative

If the host backs up to a filesystem path or an SFTP destination, the relevant destination host must already guarantee:

- the repo root exists declaratively
- the leaf repo path under `/var/lib/backups/repos/{host}` exists if your operational model requires it
- the service or SSH account can write there

Do not rely on ad-hoc shell setup.

#### 4. Provide secrets

Ensure the host has access to:

- `backup_restic_password_A` for role `A`
- `backup_restic_password_B` and `backup_restic_env_B` for role `B`, if enabled
- any per-item secrets such as MariaDB credentials

#### 5. Set all five timer families deliberately

Policies drive five timer families:

- backup timer
- promotion timer
- forget timer
- prune timer
- check timer

When adding a new policy or changing an existing one, make all five deliberate rather than letting some remain implicit accidentally.

#### 6. Run verification and at least one live drill

At minimum:

```bash
nix build .#checks.x86_64-linux.backups_eval
```

Then apply the config and run a manual backup + restore drill on the live host.

### Tweaking backup setup on an existing host

When changing an existing host, be especially careful with:

- `repository_template`
- `coordinator_host`
- destination backend type
- item names / tags
- repository passwords
- `run_as_user` semantics for dump jobs

Practical warnings:

- changing repo paths may effectively create a new repository location
- rotating an existing Restic password is not a casual change; it requires intentional repository password migration handling
- host identity and item naming feed into stable tags and service names, so renames can change maintenance and restore behavior

### Routine operator inspection

On source and coordinator hosts:

```bash
systemctl list-unit-files 'restic-backups-*' 'backup_*'
systemctl list-timers 'restic-backups-*' 'backup_*'
```

For read-only repo inspection commands such as `snapshots` and `ls --json`, prefer `--no-lock`.

This matches the tested verification flow and avoids unnecessary lock contention from operator checks.

### Generic drill procedure

The safest order is:

1. evaluate first
2. deploy/apply second
3. run manual backup / promotion / maintenance drills third
4. restore into scratch locations rather than restoring in place

#### Step 1: Evaluation check

```bash
nix build .#checks.x86_64-linux.backups_eval
```

This confirms the generated jobs, rendered units, and eval-time assertions still pass.

#### Step 2: Apply configuration on the participating hosts

At minimum this usually means:

- `tyrant`
- `lavpc`
- `temperance`

#### Step 3: Inspect generated units and timers

On backup source/coordinator hosts:

```bash
systemctl list-unit-files 'restic-backups-*' 'backup_*'
systemctl list-timers 'restic-backups-*' 'backup_*'
```

#### Step 4: Smoke-test one local backup to role `A`

Suggested first candidate on `tyrant`:

```bash
sudo systemctl start restic-backups-tyrant_home_snapshot_to_a.service
sudo journalctl -u restic-backups-tyrant_home_snapshot_to_a.service -n 200 --no-pager
```

Then verify the repo:

```bash
sudo restic \
  --repo /var/lib/backups/repos/tyrant \
  --password-file /run/secrets/backup_restic_password_A \
  --no-lock \
  snapshots
```

Expected outcome:

- service exits successfully
- snapshot appears in repo `A`
- tags identify the item correctly

#### Step 5: Smoke-test one dump-backed backup

Suggested current real-host candidate on `tyrant`:

```bash
sudo systemctl start restic-backups-tyrant_fxsync_syncstorage_db_to_a.service
sudo journalctl -u restic-backups-tyrant_fxsync_syncstorage_db_to_a.service -n 200 --no-pager
```

Then inspect snapshots again:

```bash
sudo restic \
  --repo /var/lib/backups/repos/tyrant \
  --password-file /run/secrets/backup_restic_password_A \
  --no-lock \
  snapshots
```

Confirm tags such as:

- `host:tyrant`
- `unit:fxsync`
- `item:syncstorage_db`

#### Step 6: Smoke-test promotion from `A` to `B`

Run the promotion unit manually:

```bash
sudo systemctl start backup_promote_tyrant_home_snapshot_to_b.service
sudo journalctl -u backup_promote_tyrant_home_snapshot_to_b.service -n 200 --no-pager
```

Then verify the remote repo:

```bash
sudo restic \
  --repo 'sftp:temperance@89.167.107.74:/var/lib/backups/repos/tyrant' \
  --password-file /run/secrets/backup_restic_password_B \
  --no-lock \
  snapshots
```

Expected outcome:

- the remote repo path already exists because the destination host declaratively provisioned it
- if the repo is empty, the promotion unit initializes Restic metadata there
- `restic copy` completes successfully
- the remote repo contains the promoted snapshot

#### Step 7: Smoke-test maintenance units

For role `A`:

```bash
sudo systemctl start backup_forget_tyrant_home_snapshot_on_a.service
sudo systemctl start backup_prune_tyrant_a.service
sudo systemctl start backup_check_tyrant_a.service
```

For role `B`:

```bash
sudo systemctl start backup_forget_tyrant_home_snapshot_on_b.service
sudo systemctl start backup_prune_tyrant_b.service
sudo systemctl start backup_check_tyrant_b.service
```

Expected outcome:

- all services exit successfully
- `forget` respects item identity tags
- `prune` completes without repo errors
- `check` completes without corruption or auth issues

#### Step 8: Perform at least one restore drill

Do not restore in place first. Restore into a scratch directory.

Example for local repo `A`:

```bash
sudo rm -rf /tmp/restore-test
sudo mkdir -p /tmp/restore-test
sudo restic \
  --repo /var/lib/backups/repos/tyrant \
  --password-file /run/secrets/backup_restic_password_A \
  restore latest --target /tmp/restore-test
```

What to verify:

- restored files are actually present
- restored contents match expected data
- permissions and ownership are at least sensible enough for recovery purposes

#### Required rule for dump-backed restores

Do **not** stop at “the SQL file exists”.

For SQL-backed backups, the drill should:

1. identify the dump artifact in the snapshot
2. extract it
3. import it into a disposable database or container
4. verify specific restored content

That is now the tested standard for PostgreSQL in `backup_local`, and it should be the expected operator standard for real-host dump drills too.

### Suggested coverage for a real drill

At minimum, prove one example from each class:

- path or snapshot backup
- command/stdin backup (for example a database dump)
- remote promotion path to role `B`

### Success criteria

A drill is successful only if all of the following are true:

- backup service exits with code `0`
- snapshot is visible in the expected repository
- promotion to `B` works against the real remote
- maintenance services complete successfully
- at least one restore completes and yields usable data
- for dump-backed jobs, restored SQL has been imported and validated, not just inspected as a file

### Host-specific operator notes

#### `tyrant`

Pre-flight checks:

```bash
sudo ls -l /run/secrets/backup_restic_password_A
sudo ls -l /run/secrets/backup_restic_password_B
sudo ls -l /run/secrets/backup_restic_env_B
sudo ssh temperance@89.167.107.74 true
systemctl list-unit-files 'restic-backups-*' 'backup_*'
systemctl list-timers 'restic-backups-*' 'backup_*'
```

Operator expectations:

- `tyrant` is both the role `A` storage host and the promotion coordinator
- the remote repo path for `tyrant` on `temperance` must already be declaratively provisioned and writable
- drills should include one snapshot-style item and one dump-backed item

#### `lavpc`

Pre-flight checks:

```bash
sudo ls -l /run/secrets/backup_restic_password_A
sudo ssh tyrant@192.168.15.13 true
systemctl list-unit-files 'restic-backups-*'
systemctl list-timers 'restic-backups-*'
```

Operator expectations:

- `lavpc` is a source host only in the current topology
- the repo path for `lavpc` on `tyrant` must be provisioned and writable if the backend behavior you rely on requires it
- restore drills should verify the expected contents from `/home/lav/.sensitive`

#### `temperance`

Remote destination checks:

```bash
sudo ls -ld /var/lib/backups /var/lib/backups/repos /var/lib/backups/repos/tyrant
sudo -u temperance test -w /var/lib/backups/repos/tyrant
df -h /var/lib/backups/repos
```

Operator expectations:

- `temperance` does not currently originate local items
- it must provide a declaratively managed, writable storage tree for role `B`
- promotion drills depend on `temperance` being ready before the job starts

### Example secret templates

These are example shapes only. Replace placeholders with real values.

#### Example `backups.yaml`

```yaml
restic_a_password: "replace-with-long-random-password-a"
restic_b_password: "replace-with-long-random-password-b"
restic_b_env: |
  # Optional for current sftp-based B destination.
  # Leave empty if no backend env vars are required.

# Optional, only if role C is enabled later:
# restic_c_password: "replace-with-long-random-password-c"
# restic_c_env: |
#   RCLONE_CONFIG=/run/secrets/rclone.conf
```

#### Example `fxsync.yaml`

```yaml
mariadb_password: "replace-with-the-actual-fxsync-mariadb-password"
sync_master_secret: "existing-or-generated-secret"
metrics_hash_secret: "existing-or-generated-secret"
```

#### Generating password values

Examples:

```bash
openssl rand -base64 32
```

or:

```bash
tr -dc 'A-Za-z0-9!@#$%^&*()_+=-' </dev/urandom | head -c 32
```

Practical guidance:

- use different random passwords for `A` and `B`
- avoid reusing service passwords as repository passwords
- do not rotate an existing Restic repo password casually unless you also handle repository password migration intentionally

---

## Technical Implementation Docs

### Declaration model

The source of truth is the Nix module tree.

- host-owned items live under `my."unit.backup".host_items`
- unit-owned items live under each unit's `backup.items`
- destinations and policies live under `my."unit.backup"`

This keeps backup intent close to the owning host or service.

### Supported item kinds

Currently supported item kinds are:

- `path`
- `btrfs_snapshot`
- `postgres_dump`
- `mysql_dump`
- `custom`

### Item resolution and rendering

Resolution computes:

- effective schedule
- effective retention arguments
- promotion targets
- repository paths
- tags
- generated job names
- payload commands for dump/custom items

Each enabled item always gets a local job to repository role `A`.

Local-to-`A` jobs are rendered into `services.restic.backups` entries.

Promotion and maintenance are rendered as custom `systemd.services` / `systemd.timers`.

### Current privilege model for dump jobs

This is an important maintenance invariant.

**For `postgres_dump` with a non-root `run_as_user`:**

- the Restic service itself stays `root`
- repository init, locking, and secret access stay under `root`
- only the payload command is wrapped with `runuser -u <payload_user> -- ...`

This is deliberate and production-like. It avoids the earlier failure mode where the whole Restic service ran as `postgres` and then could not manage the repository correctly.

**For `mysql_dump`, `custom`, and other kinds:**

- current semantics still follow the existing service-user model
- they do **not** automatically get the same `service_user` / `payload_user` split

If future work needs the same split for another item kind, implement it explicitly rather than assuming it already applies.

### Promotion behavior and remote-path contract

Promotion units:

- run only on the configured coordinator host
- initialize empty destination repositories when the repo path already exists and is writable
- add stable tags for host/unit/item identity and promotion role
- gain network/SSH runtime dependencies when needed by the backend

This means the remote-path contract is explicit:

- promotion handles Restic metadata init and copy
- destination hosts handle repo-path existence, ownership, and writeability declaratively

### Secret rendering

The module renders secret declarations from destination definitions and item definitions.

That includes:

- destination password secrets
- destination environment secrets
- per-item MariaDB password secrets

### Verification model

The eval layer currently asserts, among other things:

- expected jobs exist
- excluded jobs do not exist
- promotion/maintenance units render as expected
- command-backed jobs are typed correctly
- network/SSH unit wiring is present where required
- `postgres_dump` currently renders as `service_user = root` plus `payload_user = postgres` when `run_as_user = "postgres"`
- the rendered local backup command contains the expected `runuser -u postgres -- ...` wrapper

The VM tests currently prove:

- local path/custom/PostgreSQL backup + restore behavior
- promotion from `A` to `B`
- SSH-based auth for `B`
- maintenance happy paths

### Realism gap to remember

`backup_promotion` currently proves the happy path only after the destination repo tree has already been provisioned by host config.

It does **not** prove live storage-host bootstrap or remote directory creation on a missing path.

That is acceptable only because the intended system contract is declarative destination provisioning.

### Maintenance invariants for future changes

Future maintainers should preserve these unless intentionally redesigning the system.

#### Keep destination provisioning declarative

For remote destinations, the repo path must be managed by host configuration, not by ad-hoc shell commands.

If future work wants a more explicitly declarative expression than activation scripts, prefer storage-side mechanisms such as:

- module-managed directories
- `systemd.tmpfiles.rules`
- other host config that converges the directory tree automatically

#### Keep eval and VM tests in sync with behavior changes

If you change:

- destination behavior
- `run_as_user` semantics
- dump command rendering
- promotion initialization behavior
- tag behavior

then update both:

- `outputs/checks/backups.nix`
- the VM integration tests

#### Preserve the tested read-only query pattern

For read-only repo inspection commands such as:

- `snapshots`
- `ls --json`
- other repo queries used only for verification

prefer `--no-lock`.

#### Preserve the current PostgreSQL privilege model

The current proven model for non-root PostgreSQL dumps is:

- Restic service runs as `root`
- payload command drops to `postgres`

Do not casually revert to running the whole Restic service as `postgres` unless you intentionally redesign repository ownership and locking semantics.

#### Remember that MariaDB runtime restore is still a real-host concern

VM coverage currently proves PostgreSQL dump restore correctness. The real declared host database dumps today are MariaDB-backed Fxsync jobs.

That means live drills should continue to verify restored MariaDB dump content on real hosts even though the module pattern is already validated with PostgreSQL in the VM test.

#### Set all five policy timer configs deliberately

Policies drive:

- backup timer
- promotion timer
- forget timer
- prune timer
- check timer

When adding or changing policies, keep all five timer families deliberate and explicit.

#### Host identity matters

Promotion and repository addressing are sensitive to host identity and coordinator behavior.

Keep host naming and backup identity stable when changing host config or tests.
