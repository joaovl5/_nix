"""Integration test: local backup — path, custom, postgres, retention, maintenance."""

import json
from typing import Protocol, runtime_checkable

from nix_machine_protocol import Machine as _MachineProtocol


@runtime_checkable
class Machine(_MachineProtocol, Protocol):
  """Runtime-checkable view of the NixOS VM driver protocol."""


_REPO = "/var/lib/backups/repos/machine"
_PWD = "/run/secrets/backup_restic_password_A"
_RESTIC = f"restic --repo {_REPO} --password-file {_PWD} --no-lock"
_PATH_TAG = "item:my-path"
_CUSTOM_TAG = "item:my-custom"
_POSTGRES_TAG = "item:my-postgres"
_PATH_FILE = "test-data/file.txt"
_CUSTOM_FILE = "custom.dat"

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


def _start(*, service: str, machine: Machine) -> None:
  """Start a systemd unit under test."""
  machine.succeed(f"systemctl start {service}")


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


def _snapshots(*, machine: Machine, tag: str | None = None) -> Snapshots:
  """List restic snapshots, optionally filtered by tag."""
  tag_flag = f"--tag {tag}" if tag else ""
  raw = machine.succeed(f"{_RESTIC} snapshots --json {tag_flag}")
  return _parse_snapshots(raw=raw)


def _snapshot_id(*, snapshot: Snapshot) -> str:
  """Extract the restic snapshot identifier."""
  value = snapshot["id"]
  assert isinstance(value, str), (
    f"Expected snapshot id to be a string, got {type(value)!r}"
  )
  return value


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


def _new_snapshot(
  *, machine: Machine, tag: str, known_ids: set[str]
) -> Snapshot:
  """Return the single snapshot that appeared since the previous check."""
  snapshots = _snapshots(machine=machine, tag=tag)
  snapshots_by_id = {
    _snapshot_id(snapshot=snapshot): snapshot for snapshot in snapshots
  }
  new_ids = set(snapshots_by_id) - known_ids
  # The retention tests rely on each service run producing one new snapshot.
  assert len(new_ids) == 1, (
    f"Expected exactly one new snapshot for {tag}, got {sorted(new_ids)} "
    f"from {sorted(snapshots_by_id)}"
  )
  return snapshots_by_id[new_ids.pop()]


def _restore_path_content(
  *, machine: Machine, snapshot_id: str, target: str
) -> str:
  """Restore the path fixture snapshot and return its file contents."""
  machine.succeed(f"rm -rf {target}")
  machine.succeed(f"{_RESTIC} restore {snapshot_id} --target {target}")
  return machine.succeed(f"cat {target}/{_PATH_FILE}").strip()


def _dump_snapshot_file(
  *, machine: Machine, snapshot_id: str, path: str
) -> str:
  """Dump a single file from a restic snapshot."""
  return machine.succeed(f"{_RESTIC} dump {snapshot_id} {path}").strip()


def _parse_snapshot_entries(*, raw: str) -> list[SnapshotEntry]:
  """Parse `restic ls --json` line output into validated entry dictionaries."""
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


def _entry_path(*, entry: SnapshotEntry) -> str:
  """Extract the path field from a restic ls entry."""
  value = entry["path"]
  assert isinstance(value, str), (
    f"Expected entry path to be a string, got {type(value)!r}"
  )
  return value


def _assert_unit_succeeded(*, machine: Machine, service: str) -> None:
  """Assert that a oneshot maintenance unit completed successfully."""
  output = machine.succeed(
    f"systemctl show {service} "
    "--property=ActiveState,Result,ExecMainStatus --value --no-pager"
  )
  states = [line.strip() for line in output.splitlines() if line.strip()]
  # The service inspection must return all expected state fields.
  assert len(states) >= 3, f"Could not inspect {service}: {output!r}"
  # Maintenance units must not land in the failed state.
  assert states[0] != "failed", (
    f"{service} should not be failed, got {states}"
  )
  # Successful oneshot units report Result=success.
  assert states[1] == "success", (
    f"{service} result should be success, got {states}"
  )
  # Successful oneshot units also exit with status code zero.
  assert states[2] == "0", f"{service} exit status should be 0, got {states}"


def run(*, driver_globals: dict[str, object]) -> None:
  """Run backup_local integration assertions."""
  start_all = driver_globals.get("start_all")
  if callable(start_all):
    start_all()

  machine = _require_machine(globals_dict=driver_globals, key="machine")
  machine.wait_for_unit("multi-user.target")
  machine.wait_for_unit("postgresql.service")

  # ── 1. Path backup ────────────────────────────────────────────────────────
  known_path_snapshot_ids: set[str] = set()
  path_history: list[tuple[str, str]] = []

  machine.succeed(
    "mkdir -p /test-data && printf 'important-content' > /test-data/file.txt"
  )
  _start(
    service="restic-backups-machine_my_path_to_a.service", machine=machine
  )

  path_snapshot = _new_snapshot(
    machine=machine, tag=_PATH_TAG, known_ids=known_path_snapshot_ids
  )
  path_snapshot_id = _snapshot_id(snapshot=path_snapshot)
  known_path_snapshot_ids.add(path_snapshot_id)
  path_history.append((path_snapshot_id, "important-content"))

  tags = _get_tags(snapshot=path_snapshot)
  # The path backup must retain the host-level metadata tags used by maintenance logic.
  assert "host:machine" in tags, f"Missing host:machine tag in {tags}"
  assert "unit:host" in tags, f"Missing unit:host tag in {tags}"
  assert _PATH_TAG in tags, f"Missing {_PATH_TAG} tag in {tags}"

  restored_content = _restore_path_content(
    machine=machine,
    snapshot_id=path_snapshot_id,
    target="/tmp/restore-path-initial",
  )
  # The restored path snapshot must reproduce the original file contents exactly.
  assert restored_content == "important-content", (
    f"Initial path restore content mismatch: {restored_content!r}"
  )

  # ── 2. Custom command (stdin) backup ──────────────────────────────────────
  _start(
    service="restic-backups-machine_my_custom_to_a.service",
    machine=machine,
  )

  snaps = _snapshots(machine=machine, tag=_CUSTOM_TAG)
  # The custom backup fixture runs once, so exactly one snapshot should exist.
  assert len(snaps) == 1, f"Expected 1 custom snapshot, got {len(snaps)}"
  custom_snapshot_id = _snapshot_id(snapshot=snaps[0])

  custom_content = _dump_snapshot_file(
    machine=machine, snapshot_id=custom_snapshot_id, path=_CUSTOM_FILE
  )
  # The custom backup must preserve the emitted stdin payload.
  assert custom_content == "backup-custom-data", (
    f"Custom dump content mismatch: {custom_content!r}"
  )

  # ── 3. PostgreSQL dump backup ─────────────────────────────────────────────
  machine.succeed(
    "runuser -u postgres -- psql testdb -v ON_ERROR_STOP=1 -c "
    '"CREATE TABLE IF NOT EXISTS backup_fixture (id integer PRIMARY KEY, note text NOT NULL); '
    "TRUNCATE backup_fixture; "
    "INSERT INTO backup_fixture (id, note) VALUES (1, 'backup-fixture');\""
  )
  _start(
    service="restic-backups-machine_my_postgres_to_a.service",
    machine=machine,
  )

  snaps = _snapshots(machine=machine, tag=_POSTGRES_TAG)
  # The PostgreSQL fixture also performs one backup run.
  assert len(snaps) == 1, f"Expected 1 postgres snapshot, got {len(snaps)}"
  postgres_snapshot = snaps[0]
  tags = _get_tags(snapshot=postgres_snapshot)
  # The PostgreSQL snapshot must keep its restic classification tag.
  assert _POSTGRES_TAG in tags, f"Missing {_POSTGRES_TAG} tag in {tags}"

  postgres_snapshot_id = _snapshot_id(snapshot=postgres_snapshot)
  ls_entries = _parse_snapshot_entries(
    raw=machine.succeed(f"{_RESTIC} ls --json {postgres_snapshot_id}")
  )
  dump_paths = [
    _entry_path(entry=entry)
    for entry in ls_entries
    if entry.get("struct_type") == "node" and entry.get("type") == "file"
  ]
  # The dump backup should produce one SQL file for the test database export.
  assert len(dump_paths) == 1, (
    f"Expected 1 postgres dump file in snapshot, got {dump_paths}"
  )
  postgres_dump_path = dump_paths[0]

  machine.succeed(
    "runuser -u postgres -- dropdb --if-exists backup_local_restore"
  )
  machine.succeed("runuser -u postgres -- createdb backup_local_restore")
  machine.succeed(
    f"{_RESTIC} dump {postgres_snapshot_id} {postgres_dump_path} > /tmp/backup_local_restore.sql"
  )
  machine.succeed(
    "runuser -u postgres -- psql -d backup_local_restore -v ON_ERROR_STOP=1 "
    "-f /tmp/backup_local_restore.sql"
  )
  restored_note = machine.succeed(
    "runuser -u postgres -- psql -d backup_local_restore -Atc "
    '"SELECT note FROM backup_fixture WHERE id = 1"'
  ).strip()
  # Restoring the SQL dump must recreate the seeded row.
  assert restored_note == "backup-fixture", (
    f"Restored postgres content mismatch: {restored_note!r}"
  )

  # ── 4. Retention (forget) ─────────────────────────────────────────────────
  # Capture the concrete snapshot ids and contents because these services run
  # back-to-back and timestamp ordering alone is weaker evidence than identity.
  for expected_content, label in [
    ("second-content", "second"),
    ("third-content", "third"),
  ]:
    machine.succeed(f"printf '{expected_content}' > /test-data/file.txt")
    _start(
      service="restic-backups-machine_my_path_to_a.service",
      machine=machine,
    )

    path_snapshot = _new_snapshot(
      machine=machine, tag=_PATH_TAG, known_ids=known_path_snapshot_ids
    )
    path_snapshot_id = _snapshot_id(snapshot=path_snapshot)
    known_path_snapshot_ids.add(path_snapshot_id)
    path_history.append((path_snapshot_id, expected_content))

    restored_content = _restore_path_content(
      machine=machine,
      snapshot_id=path_snapshot_id,
      target=f"/tmp/restore-path-{label}",
    )
    # Each newly retained snapshot must restore the content written before that run.
    assert restored_content == expected_content, (
      f"{label} path restore content mismatch: {restored_content!r}"
    )

  _start(
    service="backup_forget_machine_my_path_on_a.service", machine=machine
  )

  remaining_path_snapshots = _snapshots(machine=machine, tag=_PATH_TAG)
  remaining_path_snapshot_ids = {
    _snapshot_id(snapshot=snapshot) for snapshot in remaining_path_snapshots
  }
  expected_remaining_path_snapshots = {
    snapshot_id for snapshot_id, _ in path_history[-2:]
  }
  # The forget job should keep only the two most recent path snapshots.
  assert remaining_path_snapshot_ids == expected_remaining_path_snapshots, (
    "Path forget kept unexpected snapshots: "
    f"expected {sorted(expected_remaining_path_snapshots)}, "
    f"got {sorted(remaining_path_snapshot_ids)}"
  )

  for snapshot_id, expected_content in path_history[-2:]:
    restored_content = _restore_path_content(
      machine=machine,
      snapshot_id=snapshot_id,
      target=f"/tmp/restore-path-after-forget-{snapshot_id}",
    )
    # Every retained snapshot must remain readable after the forget pass.
    assert restored_content == expected_content, (
      f"Path snapshot {snapshot_id} restored {restored_content!r}, "
      f"expected {expected_content!r}"
    )

  custom_snapshot_ids = {
    _snapshot_id(snapshot=snapshot)
    for snapshot in _snapshots(machine=machine, tag=_CUSTOM_TAG)
  }
  # Forgetting path snapshots must not delete the custom backup snapshot.
  assert custom_snapshot_ids == {custom_snapshot_id}, (
    f"Path forget should not remove custom snapshot, got {sorted(custom_snapshot_ids)}"
  )
  postgres_snapshot_ids = {
    _snapshot_id(snapshot=snapshot)
    for snapshot in _snapshots(machine=machine, tag=_POSTGRES_TAG)
  }
  # Forgetting path snapshots must not delete the PostgreSQL backup snapshot.
  assert postgres_snapshot_ids == {postgres_snapshot_id}, (
    f"Path forget should not remove postgres snapshot, got {sorted(postgres_snapshot_ids)}"
  )

  # ── 5. Maintenance: prune and check ──────────────────────────────────────
  _start(service="backup_prune_machine_a.service", machine=machine)
  _assert_unit_succeeded(
    machine=machine, service="backup_prune_machine_a.service"
  )

  _start(service="backup_check_machine_a.service", machine=machine)
  _assert_unit_succeeded(
    machine=machine, service="backup_check_machine_a.service"
  )

  remaining_path_snapshot_ids_after_maintenance = {
    _snapshot_id(snapshot=snapshot)
    for snapshot in _snapshots(machine=machine, tag=_PATH_TAG)
  }
  # Prune and check must preserve the retained path snapshots.
  assert (
    remaining_path_snapshot_ids_after_maintenance
    == expected_remaining_path_snapshots
  ), (
    "Maintenance should keep the retained path snapshots readable: "
    f"expected {sorted(expected_remaining_path_snapshots)}, "
    f"got {sorted(remaining_path_snapshot_ids_after_maintenance)}"
  )
  # The custom backup payload must remain readable after maintenance.
  assert (
    _dump_snapshot_file(
      machine=machine, snapshot_id=custom_snapshot_id, path=_CUSTOM_FILE
    )
    == "backup-custom-data"
  )
  postgres_dump = _dump_snapshot_file(
    machine=machine, snapshot_id=postgres_snapshot_id, path=postgres_dump_path
  )
  # The PostgreSQL dump must still contain the seeded fixture row after maintenance.
  assert "backup-fixture" in postgres_dump, (
    "Post-maintenance postgres snapshot should remain readable"
  )
