"""Integration test: multi-node backup with SFTP promotion (A → B)."""

import json
from typing import Protocol, runtime_checkable

from nix_machine_protocol import Machine as _MachineProtocol


@runtime_checkable
class Machine(_MachineProtocol, Protocol):
  """Runtime-checkable view of the NixOS VM driver protocol."""


_REPO_A = "/var/lib/backups/repos/coordinator"
_PWD_A = "/run/secrets/backup_restic_password_A"
_REPO_B = (
  "sftp://backup-user@storage:59222//var/lib/backups/repos/coordinator"
)
_PWD_B = "/run/secrets/backup_restic_password_B"

_RESTIC_A = f"restic --repo {_REPO_A} --password-file {_PWD_A} --no-lock"
_RESTIC_B = f"restic --repo '{_REPO_B}' --password-file {_PWD_B} --no-lock"

_PATH_TAG = "item:my-path"
_POSTGRES_TAG = "item:my-postgres"
_PATH_FILE = "/test-data/file.txt"
_POSTGRES_TABLE = "backup_fixture"
_POSTGRES_EXPECTED_NOTE = "promoted-postgres-fixture"

_PATH_FIXTURES = [
  "coordinator-data-1",
  "coordinator-data-2",
  "coordinator-data-3",
]

type Snapshot = dict[str, object]
type Snapshots = list[Snapshot]
type SnapshotEntry = dict[str, object]


def _require_machine(*, globals_dict: dict[str, object], key: str) -> Machine:
  """Return a required VM driver object from the driver globals."""
  value = globals_dict[key]
  assert isinstance(value, Machine), (
    f"Expected Machine for {key}, got {type(value)!r}"
  )
  return value


def _start(*, service: str, node: Machine) -> None:
  """Start a systemd unit on a test node."""
  node.succeed(f"systemctl start {service}")


def _start_and_assert_success(*, service: str, node: Machine) -> None:
  """Start a oneshot unit and prove it reported success."""
  _start(service=service, node=node)
  result = node.succeed(f"systemctl show -P Result {service}").strip()
  # Promotion fixtures must report Result=success when systemd finishes them.
  assert result == "success", f"{service} result mismatch: {result!r}"
  status = node.succeed(f"systemctl show -P ExecMainStatus {service}").strip()
  # Successful promotion fixtures must also exit with code zero.
  assert status == "0", f"{service} exit status mismatch: {status!r}"


def _parse_snapshots(*, raw: str) -> Snapshots:
  """Parse restic snapshot JSON into validated snapshot dictionaries."""
  data = json.loads(raw)
  assert isinstance(data, list), (
    f"Expected restic snapshots payload to be a list, got {type(data)!r}"
  )
  for snapshot in data:
    assert isinstance(snapshot, dict), (
      f"Expected snapshot entry to be a dict, got {type(snapshot)!r}"
    )
  return data


def _snapshots(*, node: Machine, repo_cmd: str, tag: str) -> Snapshots:
  """List snapshots for a repository/tag pair."""
  raw = node.succeed(f"{repo_cmd} snapshots --json --tag {tag}")
  return _parse_snapshots(raw=raw)


def _snapshot_id(*, snapshot: Snapshot) -> str:
  """Extract the restic snapshot identifier."""
  value = snapshot["id"]
  assert isinstance(value, str), (
    f"Expected snapshot id to be a string, got {type(value)!r}"
  )
  return value


def _snapshot_ids(*, snapshots: Snapshots) -> list[str]:
  """Collect validated snapshot identifiers."""
  return [_snapshot_id(snapshot=snapshot) for snapshot in snapshots]


def _get_tags(*, snapshot: Snapshot) -> list[str]:
  """Extract validated snapshot tags."""
  value = snapshot.get("tags", [])
  assert isinstance(value, list), (
    f"Expected snapshot tags to be a list, got {type(value)!r}"
  )
  for tag in value:
    assert isinstance(tag, str), (
      f"Expected snapshot tag to be a string, got {type(tag)!r}"
    )
  return value


def _parse_ls_entries(*, raw: str) -> list[SnapshotEntry]:
  """Parse `restic ls --json` output into validated entry dictionaries."""
  entries: list[SnapshotEntry] = []
  for line in raw.splitlines():
    if not line:
      continue
    entry = json.loads(line)
    assert isinstance(entry, dict), (
      f"Expected snapshot entry to be a dict, got {type(entry)!r}"
    )
    entries.append(entry)
  return entries


def _ls_entries(
  *, node: Machine, repo_cmd: str, snapshot_id: str
) -> list[SnapshotEntry]:
  """List parsed entries from `restic ls --json`."""
  return _parse_ls_entries(
    raw=node.succeed(f"{repo_cmd} ls --json {snapshot_id}")
  )


def _entry_path(*, entry: SnapshotEntry) -> str:
  """Extract the path field from a restic ls entry."""
  value = entry["path"]
  assert isinstance(value, str), (
    f"Expected entry path to be a string, got {type(value)!r}"
  )
  return value


def _dump_paths(
  *, node: Machine, repo_cmd: str, snapshot_id: str
) -> list[str]:
  """Collect file paths from a restic snapshot listing."""
  return [
    _entry_path(entry=entry)
    for entry in _ls_entries(
      node=node, repo_cmd=repo_cmd, snapshot_id=snapshot_id
    )
    if entry.get("struct_type") == "node" and entry.get("type") == "file"
  ]


def _assert_snapshot_ids(
  *, snapshots: Snapshots, expected_ids: list[str], context: str
) -> None:
  """Assert that the snapshot set exactly matches the expected identifiers."""
  actual_ids = _snapshot_ids(snapshots=snapshots)
  # Promotion flows must not silently create or skip snapshots.
  assert len(actual_ids) == len(expected_ids), (
    f"{context}: expected {len(expected_ids)} snapshots, got {actual_ids}"
  )
  assert set(actual_ids) == set(expected_ids), (
    f"{context}: expected snapshot ids {expected_ids}, got {actual_ids}"
  )


def _write_path_fixture(*, node: Machine, content: str) -> None:
  """Write a deterministic file payload for path-backup promotion tests."""
  node.succeed(
    f"mkdir -p /test-data && printf '%s' '{content}' > {_PATH_FILE}"
  )


def _path_snapshot_content(
  *, node: Machine, repo_cmd: str, snapshot_id: str
) -> str:
  """Restore a path snapshot and return the fixture file contents."""
  restore_target = f"/tmp/path-restore-{snapshot_id}"
  node.succeed(f"rm -rf {restore_target}")
  node.succeed(f"{repo_cmd} restore {snapshot_id} --target {restore_target}")
  return node.succeed(f"cat {restore_target}{_PATH_FILE}").strip()


def _postgres_dump_path(
  *, node: Machine, repo_cmd: str, snapshot_id: str
) -> str:
  """Return the only SQL dump path contained in a PostgreSQL snapshot."""
  dump_paths = _dump_paths(
    node=node, repo_cmd=repo_cmd, snapshot_id=snapshot_id
  )
  # PostgreSQL backup fixtures are expected to emit exactly one SQL dump file.
  assert len(dump_paths) == 1, (
    f"Expected 1 postgres dump file in snapshot {snapshot_id}, got {dump_paths}"
  )
  return dump_paths[0]


def _restore_postgres_snapshot(
  *, node: Machine, repo_cmd: str, snapshot_id: str, database: str
) -> None:
  """Restore a promoted PostgreSQL snapshot into a scratch database."""
  dump_path = _postgres_dump_path(
    node=node, repo_cmd=repo_cmd, snapshot_id=snapshot_id
  )
  node.succeed(f"runuser -u postgres -- dropdb --if-exists {database}")
  node.succeed(f"runuser -u postgres -- createdb {database}")
  node.succeed(
    f"{repo_cmd} dump {snapshot_id} {dump_path} > /tmp/{database}.sql"
  )
  node.succeed(
    "runuser -u postgres -- psql -d "
    f"{database} -v ON_ERROR_STOP=1 -f /tmp/{database}.sql"
  )


def _postgres_note(*, node: Machine, database: str) -> str:
  """Read the fixture note from a restored scratch database."""
  return node.succeed(
    "runuser -u postgres -- psql -d "
    f'{database} -Atc "SELECT note FROM {_POSTGRES_TABLE} WHERE id = 1"'
  ).strip()


def _assert_promoted_postgres_snapshot(
  *,
  node: Machine,
  repo_cmd: str,
  snapshot_id: str,
  database: str,
  expected_note: str,
) -> None:
  """Assert that a promoted PostgreSQL snapshot restores the seeded row."""
  _restore_postgres_snapshot(
    node=node, repo_cmd=repo_cmd, snapshot_id=snapshot_id, database=database
  )
  restored_note = _postgres_note(node=node, database=database)
  # The promoted PostgreSQL snapshot must restore the seeded row contents.
  assert restored_note == expected_note, (
    f"Restored postgres content mismatch for {snapshot_id}: {restored_note!r}"
  )


def run(*, driver_globals: dict[str, object]) -> None:
  """Run backup_promotion integration assertions."""
  start_all = driver_globals.get("start_all")
  if callable(start_all):
    start_all()

  coordinator = _require_machine(
    globals_dict=driver_globals, key="coordinator"
  )
  storage = _require_machine(globals_dict=driver_globals, key="storage")

  coordinator.wait_for_unit("multi-user.target")
  coordinator.wait_for_unit("postgresql.service")
  storage.wait_for_unit("multi-user.target")
  storage.wait_for_unit("sshd.service")

  # ── 1. Promote one PostgreSQL snapshot to repo B first ──────────────────────
  coordinator.succeed(
    "runuser -u postgres -- psql testdb -v ON_ERROR_STOP=1 -c "
    f'"CREATE TABLE IF NOT EXISTS {_POSTGRES_TABLE} '
    "(id integer PRIMARY KEY, note text NOT NULL); "
    f"TRUNCATE {_POSTGRES_TABLE}; "
    f"INSERT INTO {_POSTGRES_TABLE} (id, note) VALUES (1, '{_POSTGRES_EXPECTED_NOTE}');\""
  )
  _start_and_assert_success(
    service="restic-backups-coordinator_my_postgres_to_a.service",
    node=coordinator,
  )

  postgres_a = _snapshots(
    node=coordinator, repo_cmd=_RESTIC_A, tag=_POSTGRES_TAG
  )
  # The first source repository should contain exactly one PostgreSQL snapshot.
  assert len(postgres_a) == 1, (
    f"Expected 1 postgres snapshot in repo A, got {len(postgres_a)}"
  )
  postgres_tags = _get_tags(snapshot=postgres_a[0])
  # The promoted snapshot must carry both the PostgreSQL classification tag and the promotion tag.
  assert _POSTGRES_TAG in postgres_tags, (
    f"Missing {_POSTGRES_TAG} tag in {postgres_tags}"
  )
  assert "promote:B" in postgres_tags, (
    f"Missing promote:B tag in {postgres_tags}"
  )

  _start_and_assert_success(
    service="backup_promote_coordinator_my_postgres_to_b.service",
    node=coordinator,
  )

  postgres_b = _snapshots(
    node=coordinator, repo_cmd=_RESTIC_B, tag=_POSTGRES_TAG
  )
  # Promotion into repo B should produce exactly one PostgreSQL snapshot there too.
  assert len(postgres_b) == 1, (
    f"Expected 1 postgres snapshot in repo B, got {len(postgres_b)}"
  )
  postgres_snapshot_id = _snapshot_id(snapshot=postgres_b[0])
  _assert_promoted_postgres_snapshot(
    node=coordinator,
    repo_cmd=_RESTIC_B,
    snapshot_id=postgres_snapshot_id,
    database="backup_promotion_restore_before_forget",
    expected_note=_POSTGRES_EXPECTED_NOTE,
  )

  # ── 2. Promote three distinct path snapshots to repo B ───────────────────────
  path_snapshot_ids: list[str] = []
  expected_path_content: dict[str, str] = {}
  seen_path_ids: set[str] = set()

  for content in _PATH_FIXTURES:
    _write_path_fixture(node=coordinator, content=content)
    _start_and_assert_success(
      service="restic-backups-coordinator_my_path_to_a.service",
      node=coordinator,
    )
    _start_and_assert_success(
      service="backup_promote_coordinator_my_path_to_b.service",
      node=coordinator,
    )

    path_b = _snapshots(node=coordinator, repo_cmd=_RESTIC_B, tag=_PATH_TAG)
    new_ids = [
      snapshot_id
      for snapshot_id in _snapshot_ids(snapshots=path_b)
      if snapshot_id not in seen_path_ids
    ]
    # Each promote run should add exactly one new path snapshot to repo B.
    assert len(new_ids) == 1, (
      f"Expected exactly 1 new path snapshot after promoting {content!r}, got {new_ids}"
    )
    snapshot_id = new_ids[0]
    seen_path_ids.add(snapshot_id)
    path_snapshot_ids.append(snapshot_id)
    expected_path_content[snapshot_id] = content

  path_b = _snapshots(node=coordinator, repo_cmd=_RESTIC_B, tag=_PATH_TAG)
  _assert_snapshot_ids(
    snapshots=path_b,
    expected_ids=path_snapshot_ids,
    context="repo B before forget",
  )

  # ── 3. Forget path snapshots on repo B without touching postgres snapshots ───
  _start_and_assert_success(
    service="backup_forget_coordinator_my_path_on_b.service",
    node=coordinator,
  )

  kept_path_ids = path_snapshot_ids[-2:]
  forgotten_path_id = path_snapshot_ids[0]
  path_b = _snapshots(node=coordinator, repo_cmd=_RESTIC_B, tag=_PATH_TAG)
  _assert_snapshot_ids(
    snapshots=path_b,
    expected_ids=kept_path_ids,
    context="repo B after path forget",
  )
  # The forget job must drop the oldest promoted path snapshot.
  assert forgotten_path_id not in _snapshot_ids(snapshots=path_b), (
    f"Forgot kept the oldest path snapshot {forgotten_path_id} unexpectedly"
  )

  for snapshot_id in kept_path_ids:
    content = _path_snapshot_content(
      node=coordinator, repo_cmd=_RESTIC_B, snapshot_id=snapshot_id
    )
    # The retained path snapshots must still restore their original contents.
    assert content == expected_path_content[snapshot_id], (
      f"Path snapshot {snapshot_id} content mismatch: {content!r}"
    )

  postgres_b = _snapshots(
    node=coordinator, repo_cmd=_RESTIC_B, tag=_POSTGRES_TAG
  )
  _assert_snapshot_ids(
    snapshots=postgres_b,
    expected_ids=[postgres_snapshot_id],
    context="repo B postgres after path forget",
  )
  _assert_promoted_postgres_snapshot(
    node=coordinator,
    repo_cmd=_RESTIC_B,
    snapshot_id=postgres_snapshot_id,
    database="backup_promotion_restore_after_forget",
    expected_note=_POSTGRES_EXPECTED_NOTE,
  )

  # ── 4. Prune and check repo B, then prove both snapshot families still work ──
  _start_and_assert_success(
    service="backup_prune_coordinator_b.service",
    node=coordinator,
  )
  _start_and_assert_success(
    service="backup_check_coordinator_b.service",
    node=coordinator,
  )

  path_b = _snapshots(node=coordinator, repo_cmd=_RESTIC_B, tag=_PATH_TAG)
  _assert_snapshot_ids(
    snapshots=path_b,
    expected_ids=kept_path_ids,
    context="repo B after prune/check",
  )
  latest_path_id = kept_path_ids[-1]
  latest_path_content = _path_snapshot_content(
    node=coordinator, repo_cmd=_RESTIC_B, snapshot_id=latest_path_id
  )
  # Prune/check must preserve the newest retained path snapshot content.
  assert latest_path_content == expected_path_content[latest_path_id], (
    f"Latest path snapshot {latest_path_id} content mismatch: {latest_path_content!r}"
  )

  postgres_b = _snapshots(
    node=coordinator, repo_cmd=_RESTIC_B, tag=_POSTGRES_TAG
  )
  _assert_snapshot_ids(
    snapshots=postgres_b,
    expected_ids=[postgres_snapshot_id],
    context="repo B postgres after prune/check",
  )
  _assert_promoted_postgres_snapshot(
    node=coordinator,
    repo_cmd=_RESTIC_B,
    snapshot_id=postgres_snapshot_id,
    database="backup_promotion_restore_after_prune",
    expected_note=_POSTGRES_EXPECTED_NOTE,
  )
