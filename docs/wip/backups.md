# Backups: Status, Secrets, and Drill Guide

## 1) Unknowns Remaining

The Nix evaluation layer is in place and we have assertions covering the generated backup jobs and maintenance units. Integration tests now cover most runtime properties in isolated VM environments.

**Proven by integration tests:**

- Local backup execution is proven by `backup_local` test (path, custom, postgres_dump items)
- Promotion from repository role `A` to repository role `B` is proven by `backup_promotion` test (SFTP)
- Remote authentication is proven by `backup_promotion` test (SSH key-based auth)
- Retention and maintenance are proven by `backup_local` test (forget/prune/check services)
- Restore procedures are proven by both tests (local restore and remote restore)

**Still unproven on real hosts:**

- Production conditions with real filesystem state and real network conditions
- Btrfs snapshot backup paths (tested with path backups)
- MariaDB dump backups (tested with PostgreSQL instead)

Some repository-wide verification remains noisy due to unrelated pre-existing failures elsewhere in the repository. At the time of writing, `prek` and `nix flake check --all-systems` are not a clean signal for this branch alone.

**Integration test architecture:**

- `backup_local` test uses a single-node VM named `machine` to test local backup flows
- `backup_promotion` test uses two-node VMs named `coordinator` (source) and `storage` (destination) to test SFTP promotion
- Test hosts are stand-ins for real hosts (`tyrant`/`temperance`) and use generated SSH keys instead of production credentials

### Required by the current backup configuration

The current implementation expects the following secrets in the secrets repository.

#### `backups.yaml`

- `restic_a_password`
- `restic_b_password`
- `restic_b_env`

These are consumed by the generated secret declarations for backup destinations:

- repository role `A` uses `restic_a_password`
- repository role `B` uses `restic_b_password`
- repository role `B` also uses `restic_b_env`

### Not currently required because role `C` is disabled

These do not need to be present unless repository role `C` is enabled later:

- `restic_c_password`
- `restic_c_env`

#### Existing service secret now also used by backups

The backup system also reuses an existing application secret for Fxsync MariaDB dumps:

- `fxsync.yaml` -> `mariadb_password`

This is not a new secret if Fxsync is already configured, but the backup flow now depends on it for `mysqldump` jobs.

### Secret format guidance

#### `restic_a_password`, `restic_b_password`, `restic_c_password`

These are Restic repository passwords.

- Format: plain text string
- Recommended content: long, random, high-entropy password
- Safe to generate as: random characters from a password generator
- Recommendation: at least 24-32+ random characters
- Important: `A`, `B`, and `C` are logically separate repository roles, so they may use different passwords; they do not need to match unless you explicitly want that

Example shape:

```yaml
restic_a_password: "<long-random-password>"
restic_b_password: "<long-random-password>"
```

#### `restic_b_env`, `restic_c_env`

These are environment-file payloads passed to generated systemd services as `EnvironmentFile=` values.

- Format: shell-style `KEY=value` lines
- Purpose: provide backend-specific environment variables required by Restic
- For the current `sftp`-based `B` destination, this may be empty if SSH access works entirely through host keys / agent / default key placement and no extra environment variables are needed
- For an eventual `rclone`/cloud-style `C` destination, this is the place for backend environment variables if needed

Example shape:

```dotenv
SOME_BACKEND_VAR=value
ANOTHER_VAR=value
```

If no environment variables are required for `B`, you can usually store an empty file or a harmless placeholder comment-only file, provided the surrounding secret tooling accepts it.

#### `fxsync.yaml` -> `mariadb_password`

This is the MariaDB password used both by the service and by backup dump jobs.

- Format: plain text string
- It can be random characters
- It should match the actual password used by the Fxsync MariaDB deployment

### Important non-SOPS operational secret/material

Promotion to repository role `B` also depends on SSH credentials from `tyrant` to the remote host used by the SFTP repository path.

- This may already exist outside the secrets repo
- If it does not exist, backup promotion to `B` will fail even if the SOPS secrets above are present
- This usually means ensuring the correct SSH private key, authorized keys, and host trust are already set up for the account used by the generated Restic commands

## 3) Test Drill Procedure

The safest order is: evaluate first, deploy/apply second, run manual service drills third, and restore into scratch paths rather than restoring in place.

### Step 1: Evaluation check

Run the backup-specific evaluation check:

```bash
nix build .#checks.x86_64-linux.backups_eval
```

This confirms the generated jobs, rendered units, and eval-time assertions still pass.

### Step 2: Apply configuration on the real host(s)

Apply the configuration to the real machines that own backup jobs, especially `tyrant` and `lavpc`.

This step must happen before the manual drill because the services and timers need to exist on the live system.

### Step 3: Inspect generated units and timers

On `tyrant`, inspect the generated backup-related units:

```bash
systemctl list-unit-files 'restic-backups-*' 'backup_*'
systemctl list-timers 'restic-backups-*' 'backup_*'
```

This confirms the expected backup jobs, promotion units, and maintenance timers are present on the actual machine.

### Step 4: Smoke-test one local backup to repository role `A`

Suggested first candidate:

```bash
sudo systemctl start restic-backups-tyrant_home_snapshot_to_a.service
sudo journalctl -u restic-backups-tyrant_home_snapshot_to_a.service -n 200 --no-pager
```

Then verify the repository contains snapshots:

```bash
sudo restic --repo /var/lib/backups/repos/tyrant --password-file /run/secrets/backup_restic_password_A snapshots
```

Expected outcome:

- service exits successfully
- snapshot appears in repo `A`
- tags identify the item correctly

### Step 5: Smoke-test one dump-based backup

Suggested candidate:

```bash
sudo systemctl start restic-backups-tyrant_fxsync_syncstorage_db_to_a.service
sudo journalctl -u restic-backups-tyrant_fxsync_syncstorage_db_to_a.service -n 200 --no-pager
```

Then inspect snapshots again and confirm tags such as:

- `host:tyrant`
- `unit:fxsync`
- `item:syncstorage_db`

This is important because dump jobs exercise the command/stdin backup path instead of normal filesystem path backups.

### Step 6: Smoke-test promotion from `A` to `B`

Run the promotion unit manually:

```bash
sudo systemctl start backup_promote_tyrant_home_snapshot_to_b.service
sudo journalctl -u backup_promote_tyrant_home_snapshot_to_b.service -n 200 --no-pager
```

Expected outcome:

- if the destination repo is empty, the service initializes it first
- `restic copy` completes successfully
- the remote repo for role `B` contains promoted snapshots

This is the key drill for proving remote promotion and remote credentials.

### Step 7: Smoke-test maintenance units

Run the generated maintenance services manually:

```bash
sudo systemctl start backup_forget_tyrant_home_snapshot_on_a.service
sudo systemctl start backup_prune_tyrant_a.service
sudo systemctl start backup_check_tyrant_a.service
```

And for role `B` as well:

```bash
sudo systemctl start backup_forget_tyrant_home_snapshot_on_b.service
sudo systemctl start backup_prune_tyrant_b.service
sudo systemctl start backup_check_tyrant_b.service
```

Expected outcome:

- all services exit successfully
- `forget` respects tagged item identity
- `prune` completes without repository errors
- `check` completes without corruption or auth issues

### Step 8: Perform at least one restore drill

Do not restore in place first. Restore into a scratch directory.

Example:

```bash
sudo mkdir -p /tmp/restore-test
sudo restic --repo /var/lib/backups/repos/tyrant --password-file /run/secrets/backup_restic_password_A restore latest --target /tmp/restore-test
```

What to verify:

- restored files are actually present
- permissions and ownership are sensible enough for recovery purposes
- the restored contents are the expected item/data

For dump-based backups, the drill should additionally verify the SQL artifact can be read and is structurally valid. Ideally, import it into a disposable database/container rather than trusting file presence alone.

### Suggested restore drill coverage

At minimum, prove one example from each class:

- path or snapshot backup
- command/stdin backup (for example a database dump)
- remote promotion path to role `B`

### Success criteria

The drill should be considered successful only if all of the following are true:

- backup service exits with code `0`
- snapshot is visible in the expected repository
- promotion to `B` works against the real remote
- maintenance services complete successfully
- at least one restore completes and yields usable data

## 4) High-Level Summary of Backup Flow

The implemented design is a declarative Restic-based backup pipeline driven from Nix configuration.

- Backup items are declared in Nix, either as host-owned items or unit-owned items.
- Every enabled item always backs up first to repository role `A`.
- Policies decide schedule, retention, check cadence, and which higher-tier destinations the item should be promoted to.
- Promotion is modeled as `A -> B,C`, not as direct writes from the original source item to every destination.
- Restic handles the actual backup snapshots, promotion copies, forget, prune, and check operations.
- Generated systemd services/timers are the execution layer.

In the current host topology:

- `tyrant` is the backup coordinator host
- `tyrant` stores repository role `A` locally on the filesystem
- `tyrant` promotes selected items to repository role `B` over SFTP
- `lavpc` writes its local backups to `tyrant` as repository role `A`

Conceptually, the flow is:

1. declare items in Nix
2. resolve them through backup policies
3. render local Restic backup jobs to `A`
4. render promotion and maintenance systemd units
5. let systemd timers execute the resulting services

## 5) Detailed Nix + Restic Implementation Notes

### Declaration model

The source of truth is the Nix module tree.

- Host-owned backup items live under `my."unit.backup".host_items`
- Unit-owned backup items live under each unit's `backup.items`
- Backup destinations and policies live under `my."unit.backup"`

This means backup intent is declared near the owning system or service rather than being maintained as an external job list.

### Types and schema

The backup schema is defined in the backup type layer.

It includes:

- destination type definitions
- policy type definitions
- item type definitions
- strict payload validation so each item has exactly one payload matching its declared kind

Supported item kinds currently are:

- `path`
- `btrfs_snapshot`
- `postgres_dump`
- `mysql_dump`
- `custom`

### Item collection and resolution

The implementation collects both host-owned and unit-owned items, then resolves them into executable job descriptions.

Resolution computes:

- the effective schedule
- the effective retention arguments
- promotion targets
- destination repository paths
- Restic tags
- command payloads for dump/custom jobs
- generated job names

Each resolved item always has a local job for repository role `A`, and may additionally participate in promotion/maintenance for other repository roles.

### Local backups to `A`

Local-to-`A` jobs are rendered into `services.restic.backups` entries.

These jobs use the native NixOS Restic integration for:

- filesystem path backups
- Btrfs snapshot path backups
- command/stdin backups such as PostgreSQL and MariaDB dumps

For snapshot-based jobs, prepare and cleanup commands create and remove the readonly Btrfs snapshot around the backup operation.

For command-based jobs:

- PostgreSQL uses `pg_dump`
- MariaDB uses `mysqldump`
- custom jobs run a generated shell script and feed data to Restic over stdin

### Promotion and maintenance layer

Promotion and maintenance are rendered as custom `systemd.services` and `systemd.timers`.

This layer is responsible for:

- `restic copy` from `A` to promoted destinations
- `restic forget` scoped by item identity tags
- `restic prune` per repository role
- `restic check` per repository role

Promotion units:

- run only on the configured coordinator host
- initialize empty destination repositories when necessary
- add stable tags for host/unit/item identity and promotion role
- gain network/SSH runtime dependencies when the destination backend requires them

### Secret rendering

Secrets are rendered automatically from destination definitions and item definitions.

That includes:

- destination password files
- destination environment files
- per-item MariaDB password secrets

This lets backup items declare the secret references they need while the backup module renders the actual SOPS secret declarations consumed by generated jobs.

### Current concrete coverage

The current implementation includes these declared backup items:

- host snapshots on `tyrant` for `/` and `/home`
- sensitive path backup on `lavpc` for `/home/lav/.sensitive`
- Pi-hole state
- Traefik ACME state
- Actual Budget state
- Fxsync MariaDB dumps for both databases
- Soularr state

The implementation explicitly does not include certain service-owned data in v1, including the currently excluded qbittorrent/nixarr backup cases.

### Validation status

The eval layer asserts that:

- expected jobs exist
- excluded jobs do not exist
- promotion/maintenance units are rendered as expected
- command-backed jobs are typed correctly
- network/SSH-related unit wiring is present where required

This gives good confidence in the generated structure, but it is still not a substitute for live drill execution.

## 6) Host-By-Host Drill Checklist

This section turns the general drill into concrete per-host checklists.

### `tyrant`

`tyrant` is currently the most important host for backup validation because it is both:

- a source host with local backup items
- the coordinator host for promotion and maintenance
- the storage location for repository role `A`

#### Pre-flight

- confirm the applied system config includes the new backup units
- confirm `/run/secrets/backup_restic_password_A` exists
- confirm `/run/secrets/backup_restic_password_B` exists
- confirm the role `B` environment secret file exists if configured
- confirm SSH connectivity from `tyrant` to the `B` remote endpoint works for the account used in the SFTP repository path

Suggested checks:

```bash
sudo ls -l /run/secrets/backup_restic_password_A
sudo ls -l /run/secrets/backup_restic_password_B
sudo ls -l /run/secrets/backup_restic_env_B
sudo ssh temperance@89.167.107.74 true
systemctl list-unit-files 'restic-backups-*' 'backup_*'
systemctl list-timers 'restic-backups-*' 'backup_*'
```

#### Local backup drill on `tyrant`

Test at least one snapshot-style item and one command-backed item.

Recommended snapshot item:

```bash
sudo systemctl start restic-backups-tyrant_home_snapshot_to_a.service
sudo journalctl -u restic-backups-tyrant_home_snapshot_to_a.service -n 200 --no-pager
```

Recommended command-backed item:

```bash
sudo systemctl start restic-backups-tyrant_fxsync_syncstorage_db_to_a.service
sudo journalctl -u restic-backups-tyrant_fxsync_syncstorage_db_to_a.service -n 200 --no-pager
```

Inspect repository `A`:

```bash
sudo restic --repo /var/lib/backups/repos/tyrant --password-file /run/secrets/backup_restic_password_A snapshots
```

Verify:

- snapshots exist
- tags include the expected `host:*`, `unit:*`, and `item:*` identity tags
- the Btrfs snapshot job created and cleaned up its temporary snapshot correctly

#### Promotion drill on `tyrant`

Run a promotion explicitly:

```bash
sudo systemctl start backup_promote_tyrant_home_snapshot_to_b.service
sudo journalctl -u backup_promote_tyrant_home_snapshot_to_b.service -n 200 --no-pager
```

Then verify the remote repository can be read:

```bash
sudo restic \
  --repo 'sftp:temperance@89.167.107.74:/var/lib/backups/repos/tyrant' \
  --password-file /run/secrets/backup_restic_password_B \
  snapshots
```

Verify:

- remote repo is initialized if it was previously empty
- promoted snapshot exists remotely
- authentication works non-interactively

#### Maintenance drill on `tyrant`

Run at least one round of each maintenance class:

```bash
sudo systemctl start backup_forget_tyrant_home_snapshot_on_a.service
sudo systemctl start backup_prune_tyrant_a.service
sudo systemctl start backup_check_tyrant_a.service

sudo systemctl start backup_forget_tyrant_home_snapshot_on_b.service
sudo systemctl start backup_prune_tyrant_b.service
sudo systemctl start backup_check_tyrant_b.service
```

Verify:

- all units exit successfully
- no auth/network failures occur on role `B`
- no repository format/corruption issues are reported

#### Restore drill on `tyrant`

Restore into a scratch path:

```bash
sudo rm -rf /tmp/restore-test-tyrant
sudo mkdir -p /tmp/restore-test-tyrant
sudo restic --repo /var/lib/backups/repos/tyrant \
  --password-file /run/secrets/backup_restic_password_A \
  restore latest --target /tmp/restore-test-tyrant
```

For the dump-based job, identify the snapshot and inspect the SQL artifact:

```bash
sudo restic --repo /var/lib/backups/repos/tyrant \
  --password-file /run/secrets/backup_restic_password_A \
  snapshots

sudo find /tmp/restore-test-tyrant -type f | sort
```

If possible, take the restored SQL dump and import it into a disposable MariaDB instance/container.

### `lavpc`

`lavpc` currently acts as a source host that writes its local backups into repository role `A` hosted on `tyrant`.

#### Pre-flight

- confirm the applied system config includes the generated Restic backup unit
- confirm `/run/secrets/backup_restic_password_A` exists on `lavpc`
- confirm SSH connectivity from `lavpc` to `tyrant` works for the account embedded in the repository path

Suggested checks:

```bash
sudo ls -l /run/secrets/backup_restic_password_A
sudo ssh tyrant@192.168.15.13 true
systemctl list-unit-files 'restic-backups-*'
systemctl list-timers 'restic-backups-*'
```

#### Backup drill on `lavpc`

Run the declared sensitive-data backup:

```bash
sudo systemctl start restic-backups-lavpc_shared_sync_to_a.service
sudo journalctl -u restic-backups-lavpc_shared_sync_to_a.service -n 200 --no-pager
```

Then verify the repository on `tyrant` contains the `lavpc` snapshots:

```bash
sudo restic --repo 'sftp:tyrant@192.168.15.13:/var/lib/backups/repos/lavpc' \
  --password-file /run/secrets/backup_restic_password_A \
  snapshots
```

Verify:

- snapshot exists for `lavpc`
- tags correctly identify `host:lavpc`, `unit:host`, `item:shared_sync`
- no SSH auth issue occurs during the backup

#### Restore drill on `lavpc`

Restore into a scratch path:

```bash
sudo rm -rf /tmp/restore-test-lavpc
sudo mkdir -p /tmp/restore-test-lavpc
sudo restic --repo 'sftp:tyrant@192.168.15.13:/var/lib/backups/repos/lavpc' \
  --password-file /run/secrets/backup_restic_password_A \
  restore latest --target /tmp/restore-test-lavpc
```

Verify that the restored tree contains the expected contents from `/home/lav/.sensitive`.

### `temperance`

`temperance` does not currently originate local backup items in this setup, but it is still part of the drill because it hosts repository role `B` over SFTP.

#### Remote destination checks

- confirm the backing path exists or can be created as intended
- confirm the SSH account has permission to access `/var/lib/backups/repos`
- confirm disk space and ownership are suitable for a Restic repository

Suggested checks:

```bash
sudo ls -ld /var/lib/backups /var/lib/backups/repos
sudo -u temperance test -w /var/lib/backups/repos
df -h /var/lib/backups/repos
```

This host mostly participates indirectly by making the `tyrant -> B` promotion drill succeed.

## 7) Example Secret Templates

These are example shapes only. Replace placeholders with your real values.

### Example `backups.yaml`

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

### Example `fxsync.yaml`

If Fxsync is already configured, this likely already exists. Included here just to show the expected shape.

```yaml
mariadb_password: "replace-with-the-actual-fxsync-mariadb-password"
sync_master_secret: "existing-or-generated-secret"
metrics_hash_secret: "existing-or-generated-secret"
```

### Generating password values

For Restic repository passwords, any strong random string is fine.

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
- do not change an existing Restic repository password casually unless you also intend to handle repository password migration correctly

### About `restic_b_env`

For the currently configured `sftp` destination, this file may legitimately contain no variables at all.

Safe options are:

- an empty file, if your secret tooling permits it
- a comment-only file
- a small placeholder line that does not affect behavior

Example:

```dotenv
# currently unused for sftp backend B
```
