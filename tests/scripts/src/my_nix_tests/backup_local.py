"""Integration test: local backup — path, custom, postgres, retention, maintenance."""

from __future__ import annotations

import json
from typing import TYPE_CHECKING, cast

if TYPE_CHECKING:
    from collections.abc import Callable

    from nix_machine_protocol import Machine

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


def _start(service: str, machine: Machine) -> None:
    machine.succeed(f"systemctl start {service}")


def _snapshots(machine: Machine, tag: str | None = None) -> Snapshots:
    tag_flag = f"--tag {tag}" if tag else ""
    raw = machine.succeed(f"{_RESTIC} snapshots --json {tag_flag}")
    return cast(Snapshots, json.loads(raw))


def _snapshot_id(snapshot: Snapshot) -> str:
    return cast("str", snapshot["id"])


def _get_tags(snap: Snapshot) -> list[str]:
    tags = snap.get("tags", [])
    return cast("list[str]", tags)


def _new_snapshot(machine: Machine, *, tag: str, known_ids: set[str]) -> Snapshot:
    snapshots = _snapshots(machine, tag)
    snapshots_by_id = {_snapshot_id(snapshot): snapshot for snapshot in snapshots}
    new_ids = set(snapshots_by_id) - known_ids
    assert len(new_ids) == 1, (
        f"Expected exactly one new snapshot for {tag}, got {sorted(new_ids)} "
        f"from {sorted(snapshots_by_id)}"
    )
    return snapshots_by_id[new_ids.pop()]


def _restore_path_content(machine: Machine, snapshot_id: str, target: str) -> str:
    machine.succeed(f"rm -rf {target}")
    machine.succeed(f"{_RESTIC} restore {snapshot_id} --target {target}")
    return machine.succeed(f"cat {target}/{_PATH_FILE}").strip()


def _dump_snapshot_file(machine: Machine, snapshot_id: str, path: str) -> str:
    return machine.succeed(f"{_RESTIC} dump {snapshot_id} {path}").strip()


def _assert_unit_succeeded(machine: Machine, service: str) -> None:
    output = machine.succeed(
        f"systemctl show {service} "
        "--property=ActiveState,Result,ExecMainStatus --value --no-pager"
    )
    states = [line.strip() for line in output.splitlines() if line.strip()]
    assert len(states) >= 3, f"Could not inspect {service}: {output!r}"
    assert states[0] != "failed", f"{service} should not be failed, got {states}"
    assert states[1] == "success", f"{service} result should be success, got {states}"
    assert states[2] == "0", f"{service} exit status should be 0, got {states}"


def run(driver_globals: dict[str, object]) -> None:
    """Run backup_local integration assertions."""
    start_all = driver_globals.get("start_all")
    if callable(start_all):
        cast("Callable[[], None]", start_all)()

    machine = cast("Machine", driver_globals["machine"])
    machine.wait_for_unit("multi-user.target")
    machine.wait_for_unit("postgresql.service")

    # ── 1. Path backup ────────────────────────────────────────────────────────
    known_path_snapshot_ids: set[str] = set()
    path_history: list[tuple[str, str]] = []

    machine.succeed(
        "mkdir -p /test-data && printf 'important-content' > /test-data/file.txt"
    )
    _start("restic-backups-machine_my_path_to_a.service", machine)

    path_snapshot = _new_snapshot(
        machine, tag=_PATH_TAG, known_ids=known_path_snapshot_ids
    )
    path_snapshot_id = _snapshot_id(path_snapshot)
    known_path_snapshot_ids.add(path_snapshot_id)
    path_history.append((path_snapshot_id, "important-content"))

    tags = _get_tags(path_snapshot)
    assert "host:machine" in tags, f"Missing host:machine tag in {tags}"
    assert "unit:host" in tags, f"Missing unit:host tag in {tags}"
    assert _PATH_TAG in tags, f"Missing {_PATH_TAG} tag in {tags}"

    restored_content = _restore_path_content(
        machine, path_snapshot_id, "/tmp/restore-path-initial"
    )
    assert restored_content == "important-content", (
        f"Initial path restore content mismatch: {restored_content!r}"
    )

    # ── 2. Custom command (stdin) backup ──────────────────────────────────────
    _start("restic-backups-machine_my_custom_to_a.service", machine)

    snaps = _snapshots(machine, _CUSTOM_TAG)
    assert len(snaps) == 1, f"Expected 1 custom snapshot, got {len(snaps)}"
    custom_snapshot_id = _snapshot_id(snaps[0])

    custom_content = _dump_snapshot_file(machine, custom_snapshot_id, _CUSTOM_FILE)
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
    _start("restic-backups-machine_my_postgres_to_a.service", machine)

    snaps = _snapshots(machine, _POSTGRES_TAG)
    assert len(snaps) == 1, f"Expected 1 postgres snapshot, got {len(snaps)}"
    postgres_snapshot = snaps[0]
    tags = _get_tags(postgres_snapshot)
    assert _POSTGRES_TAG in tags, f"Missing {_POSTGRES_TAG} tag in {tags}"

    postgres_snapshot_id = _snapshot_id(postgres_snapshot)
    ls_entries = [
        json.loads(line)
        for line in machine.succeed(
            f"{_RESTIC} ls --json {postgres_snapshot_id}"
        ).splitlines()
        if line
    ]
    dump_paths = [
        cast("str", entry["path"])
        for entry in ls_entries
        if entry.get("struct_type") == "node" and entry.get("type") == "file"
    ]
    assert len(dump_paths) == 1, (
        f"Expected 1 postgres dump file in snapshot, got {dump_paths}"
    )
    postgres_dump_path = dump_paths[0]

    machine.succeed("runuser -u postgres -- dropdb --if-exists backup_local_restore")
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
        _start("restic-backups-machine_my_path_to_a.service", machine)

        path_snapshot = _new_snapshot(
            machine, tag=_PATH_TAG, known_ids=known_path_snapshot_ids
        )
        path_snapshot_id = _snapshot_id(path_snapshot)
        known_path_snapshot_ids.add(path_snapshot_id)
        path_history.append((path_snapshot_id, expected_content))

        restored_content = _restore_path_content(
            machine, path_snapshot_id, f"/tmp/restore-path-{label}"
        )
        assert restored_content == expected_content, (
            f"{label} path restore content mismatch: {restored_content!r}"
        )

    _start("backup_forget_machine_my_path_on_a.service", machine)

    remaining_path_snapshots = _snapshots(machine, _PATH_TAG)
    remaining_path_snapshot_ids = {
        _snapshot_id(snapshot) for snapshot in remaining_path_snapshots
    }
    expected_remaining_path_snapshots = {
        snapshot_id for snapshot_id, _ in path_history[-2:]
    }
    assert remaining_path_snapshot_ids == expected_remaining_path_snapshots, (
        "Path forget kept unexpected snapshots: "
        f"expected {sorted(expected_remaining_path_snapshots)}, "
        f"got {sorted(remaining_path_snapshot_ids)}"
    )

    for snapshot_id, expected_content in path_history[-2:]:
        restored_content = _restore_path_content(
            machine, snapshot_id, f"/tmp/restore-path-after-forget-{snapshot_id}"
        )
        assert restored_content == expected_content, (
            f"Path snapshot {snapshot_id} restored {restored_content!r}, "
            f"expected {expected_content!r}"
        )

    custom_snapshot_ids = {
        _snapshot_id(snapshot) for snapshot in _snapshots(machine, _CUSTOM_TAG)
    }
    assert custom_snapshot_ids == {custom_snapshot_id}, (
        f"Path forget should not remove custom snapshot, got {sorted(custom_snapshot_ids)}"
    )
    postgres_snapshot_ids = {
        _snapshot_id(snapshot) for snapshot in _snapshots(machine, _POSTGRES_TAG)
    }
    assert postgres_snapshot_ids == {postgres_snapshot_id}, (
        f"Path forget should not remove postgres snapshot, got {sorted(postgres_snapshot_ids)}"
    )

    # ── 5. Maintenance: prune and check ──────────────────────────────────────
    _start("backup_prune_machine_a.service", machine)
    _assert_unit_succeeded(machine, "backup_prune_machine_a.service")

    _start("backup_check_machine_a.service", machine)
    _assert_unit_succeeded(machine, "backup_check_machine_a.service")

    remaining_path_snapshot_ids_after_maintenance = {
        _snapshot_id(snapshot) for snapshot in _snapshots(machine, _PATH_TAG)
    }
    assert (
        remaining_path_snapshot_ids_after_maintenance
        == expected_remaining_path_snapshots
    ), (
        "Maintenance should keep the retained path snapshots readable: "
        f"expected {sorted(expected_remaining_path_snapshots)}, "
        f"got {sorted(remaining_path_snapshot_ids_after_maintenance)}"
    )
    assert (
        _dump_snapshot_file(machine, custom_snapshot_id, _CUSTOM_FILE)
        == "backup-custom-data"
    )
    postgres_dump = _dump_snapshot_file(
        machine, postgres_snapshot_id, postgres_dump_path
    )
    assert "backup-fixture" in postgres_dump, (
        "Post-maintenance postgres snapshot should remain readable"
    )
