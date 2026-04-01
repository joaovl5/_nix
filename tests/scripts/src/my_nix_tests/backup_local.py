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

type Snapshot = dict[str, object]
type Snapshots = list[Snapshot]


def _start(service: str, machine: Machine) -> None:
    machine.succeed(f"systemctl start {service}")


def _snapshots(machine: Machine, tag: str | None = None) -> Snapshots:
    tag_flag = f"--tag {tag}" if tag else ""
    raw = machine.succeed(f"{_RESTIC} snapshots --json {tag_flag}")
    return cast(Snapshots, json.loads(raw))


def _get_tags(snap: Snapshot) -> list[str]:
    tags = snap.get("tags", [])
    return cast("list[str]", tags)


def run(driver_globals: dict[str, object]) -> None:
    """Run backup_local integration assertions."""
    start_all = driver_globals.get("start_all")
    if callable(start_all):
        cast("Callable[[], None]", start_all)()

    machine = cast("Machine", driver_globals["machine"])
    machine.wait_for_unit("multi-user.target")
    machine.wait_for_unit("postgresql.service")

    # ── 1. Path backup ────────────────────────────────────────────────────────
    machine.succeed(
        "mkdir -p /test-data && printf 'important-content' > /test-data/file.txt"
    )
    _start("restic-backups-machine_my_path_to_a.service", machine)

    snaps = _snapshots(machine, "item:my-path")
    assert len(snaps) == 1, f"Expected 1 path snapshot, got {len(snaps)}"
    tags = _get_tags(snaps[0])
    assert "host:machine" in tags, f"Missing host:machine tag in {tags}"
    assert "unit:host" in tags, f"Missing unit:host tag in {tags}"
    assert "item:my-path" in tags, f"Missing item:my-path tag in {tags}"

    # Restore and verify data integrity
    machine.succeed("rm -f /test-data/file.txt")
    machine.succeed(
        f"{_RESTIC} restore latest --target /tmp/restore-path --tag item:my-path"
    )
    content = machine.succeed("cat /tmp/restore-path/test-data/file.txt").strip()
    assert content == "important-content", f"Restored content mismatch: {content!r}"

    # ── 2. Custom command (stdin) backup ──────────────────────────────────────
    _start("restic-backups-machine_my_custom_to_a.service", machine)

    snaps = _snapshots(machine, "item:my-custom")
    assert len(snaps) == 1, f"Expected 1 custom snapshot, got {len(snaps)}"
    snap_id = cast("str", snaps[0]["id"])

    # Restore stdin artifact and verify content
    content = machine.succeed(f"{_RESTIC} dump {snap_id} custom.dat").strip()
    assert content == "backup-custom-data", f"Custom dump content mismatch: {content!r}"

    # ── 3. PostgreSQL dump backup ─────────────────────────────────────────────
    machine.succeed(
        "runuser -u postgres -- psql testdb -v ON_ERROR_STOP=1 -c "
        '"CREATE TABLE IF NOT EXISTS backup_fixture (id integer PRIMARY KEY, note text NOT NULL); '
        "TRUNCATE backup_fixture; "
        "INSERT INTO backup_fixture (id, note) VALUES (1, 'backup-fixture');\""
    )
    _start("restic-backups-machine_my_postgres_to_a.service", machine)

    snaps = _snapshots(machine, "item:my-postgres")
    assert len(snaps) == 1, f"Expected 1 postgres snapshot, got {len(snaps)}"
    tags = _get_tags(snaps[0])
    assert "item:my-postgres" in tags, f"Missing item:my-postgres tag in {tags}"

    snap_id = cast("str", snaps[0]["id"])
    ls_entries = [
        json.loads(line)
        for line in machine.succeed(f"{_RESTIC} ls --json {snap_id}").splitlines()
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
    dump_path = dump_paths[0]

    machine.succeed("runuser -u postgres -- dropdb --if-exists backup_local_restore")
    machine.succeed("runuser -u postgres -- createdb backup_local_restore")
    machine.succeed(
        f"{_RESTIC} dump {snap_id} {dump_path} > /tmp/backup_local_restore.sql"
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
    # Create two more path snapshots (policy: keep-last 2)
    machine.succeed("printf 'second-content' > /test-data/file.txt")
    _start("restic-backups-machine_my_path_to_a.service", machine)
    machine.succeed("printf 'third-content' > /test-data/file.txt")
    _start("restic-backups-machine_my_path_to_a.service", machine)

    # 3 path snapshots exist; forget should prune to 2
    _start("backup_forget_machine_my_path_on_a.service", machine)

    snaps = _snapshots(machine, "item:my-path")
    assert len(snaps) == 2, f"Expected 2 path snapshots after forget, got {len(snaps)}"

    # ── 5. Maintenance: prune and check ──────────────────────────────────────
    _start("backup_prune_machine_a.service", machine)
    _start("backup_check_machine_a.service", machine)
