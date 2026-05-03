"""Integration test: multi-node backup with SFTP promotion (A → B)."""

from __future__ import annotations

import json
from typing import TYPE_CHECKING, cast

if TYPE_CHECKING:
    from collections.abc import Callable

    from nix_machine_protocol import Machine

_REPO_A = "/var/lib/backups/repos/coordinator"
_PWD_A = "/run/secrets/backup_restic_password_A"
_REPO_B = "sftp://backup-user@storage:59222//var/lib/backups/repos/coordinator"
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


def _start(service: str, node: Machine) -> None:
    node.succeed(f"systemctl start {service}")


def _start_and_assert_success(service: str, node: Machine) -> None:
    _start(service, node)
    result = node.succeed(f"systemctl show -P Result {service}").strip()
    assert result == "success", f"{service} result mismatch: {result!r}"
    status = node.succeed(f"systemctl show -P ExecMainStatus {service}").strip()
    assert status == "0", f"{service} exit status mismatch: {status!r}"


def _snapshots(node: Machine, repo_cmd: str, tag: str) -> Snapshots:
    raw = node.succeed(f"{repo_cmd} snapshots --json --tag {tag}")
    return cast(Snapshots, json.loads(raw))


def _snapshot_ids(snaps: Snapshots) -> list[str]:
    return [cast("str", snap["id"]) for snap in snaps]


def _get_tags(snap: Snapshot) -> list[str]:
    tags = snap.get("tags", [])
    return cast("list[str]", tags)


def _ls_entries(
    node: Machine, repo_cmd: str, snapshot_id: str
) -> list[dict[str, object]]:
    return [
        cast("dict[str, object]", json.loads(line))
        for line in node.succeed(f"{repo_cmd} ls --json {snapshot_id}").splitlines()
        if line
    ]


def _dump_paths(node: Machine, repo_cmd: str, snapshot_id: str) -> list[str]:
    return [
        cast("str", entry["path"])
        for entry in _ls_entries(node, repo_cmd, snapshot_id)
        if entry.get("struct_type") == "node" and entry.get("type") == "file"
    ]


def _assert_snapshot_ids(
    snaps: Snapshots, expected_ids: list[str], context: str
) -> None:
    actual_ids = _snapshot_ids(snaps)
    assert len(actual_ids) == len(expected_ids), (
        f"{context}: expected {len(expected_ids)} snapshots, got {actual_ids}"
    )
    assert set(actual_ids) == set(expected_ids), (
        f"{context}: expected snapshot ids {expected_ids}, got {actual_ids}"
    )


def _write_path_fixture(node: Machine, content: str) -> None:
    node.succeed(f"mkdir -p /test-data && printf '%s' '{content}' > {_PATH_FILE}")


def _path_snapshot_content(node: Machine, repo_cmd: str, snapshot_id: str) -> str:
    restore_target = f"/tmp/path-restore-{snapshot_id}"
    node.succeed(f"rm -rf {restore_target}")
    node.succeed(f"{repo_cmd} restore {snapshot_id} --target {restore_target}")
    return node.succeed(f"cat {restore_target}{_PATH_FILE}").strip()


def _postgres_dump_path(node: Machine, repo_cmd: str, snapshot_id: str) -> str:
    dump_paths = _dump_paths(node, repo_cmd, snapshot_id)
    assert len(dump_paths) == 1, (
        f"Expected 1 postgres dump file in snapshot {snapshot_id}, got {dump_paths}"
    )
    return dump_paths[0]


def _restore_postgres_snapshot(
    node: Machine, repo_cmd: str, snapshot_id: str, database: str
) -> None:
    dump_path = _postgres_dump_path(node, repo_cmd, snapshot_id)
    node.succeed(f"runuser -u postgres -- dropdb --if-exists {database}")
    node.succeed(f"runuser -u postgres -- createdb {database}")
    node.succeed(f"{repo_cmd} dump {snapshot_id} {dump_path} > /tmp/{database}.sql")
    node.succeed(
        "runuser -u postgres -- psql -d "
        f"{database} -v ON_ERROR_STOP=1 -f /tmp/{database}.sql"
    )


def _postgres_note(node: Machine, database: str) -> str:
    return node.succeed(
        "runuser -u postgres -- psql -d "
        f'{database} -Atc "SELECT note FROM {_POSTGRES_TABLE} WHERE id = 1"'
    ).strip()


def _assert_promoted_postgres_snapshot(
    node: Machine,
    repo_cmd: str,
    snapshot_id: str,
    database: str,
    expected_note: str,
) -> None:
    _restore_postgres_snapshot(node, repo_cmd, snapshot_id, database)
    restored_note = _postgres_note(node, database)
    assert restored_note == expected_note, (
        f"Restored postgres content mismatch for {snapshot_id}: {restored_note!r}"
    )


def run(driver_globals: dict[str, object]) -> None:
    """Run backup_promotion integration assertions."""
    start_all = driver_globals.get("start_all")
    if callable(start_all):
        cast("Callable[[], None]", start_all)()

    coordinator = cast("Machine", driver_globals["coordinator"])
    storage = cast("Machine", driver_globals["storage"])

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
        "restic-backups-coordinator_my_postgres_to_a.service", coordinator
    )

    postgres_a = _snapshots(coordinator, _RESTIC_A, _POSTGRES_TAG)
    assert len(postgres_a) == 1, (
        f"Expected 1 postgres snapshot in repo A, got {len(postgres_a)}"
    )
    postgres_tags = _get_tags(postgres_a[0])
    assert _POSTGRES_TAG in postgres_tags, (
        f"Missing {_POSTGRES_TAG} tag in {postgres_tags}"
    )
    assert "promote:B" in postgres_tags, f"Missing promote:B tag in {postgres_tags}"

    _start_and_assert_success(
        "backup_promote_coordinator_my_postgres_to_b.service", coordinator
    )

    postgres_b = _snapshots(coordinator, _RESTIC_B, _POSTGRES_TAG)
    assert len(postgres_b) == 1, (
        f"Expected 1 postgres snapshot in repo B, got {len(postgres_b)}"
    )
    postgres_snapshot_id = cast("str", postgres_b[0]["id"])
    _assert_promoted_postgres_snapshot(
        coordinator,
        _RESTIC_B,
        postgres_snapshot_id,
        "backup_promotion_restore_before_forget",
        _POSTGRES_EXPECTED_NOTE,
    )

    # ── 2. Promote three distinct path snapshots to repo B ───────────────────────
    path_snapshot_ids: list[str] = []
    expected_path_content: dict[str, str] = {}
    seen_path_ids: set[str] = set()

    for content in _PATH_FIXTURES:
        _write_path_fixture(coordinator, content)
        _start_and_assert_success(
            "restic-backups-coordinator_my_path_to_a.service", coordinator
        )
        _start_and_assert_success(
            "backup_promote_coordinator_my_path_to_b.service", coordinator
        )

        path_b = _snapshots(coordinator, _RESTIC_B, _PATH_TAG)
        new_ids = [
            snapshot_id
            for snapshot_id in _snapshot_ids(path_b)
            if snapshot_id not in seen_path_ids
        ]
        assert len(new_ids) == 1, (
            f"Expected exactly 1 new path snapshot after promoting {content!r}, got {new_ids}"
        )
        snapshot_id = new_ids[0]
        seen_path_ids.add(snapshot_id)
        path_snapshot_ids.append(snapshot_id)
        expected_path_content[snapshot_id] = content

    path_b = _snapshots(coordinator, _RESTIC_B, _PATH_TAG)
    _assert_snapshot_ids(path_b, path_snapshot_ids, "repo B before forget")

    # ── 3. Forget path snapshots on repo B without touching postgres snapshots ───
    _start_and_assert_success(
        "backup_forget_coordinator_my_path_on_b.service", coordinator
    )

    kept_path_ids = path_snapshot_ids[-2:]
    forgotten_path_id = path_snapshot_ids[0]
    path_b = _snapshots(coordinator, _RESTIC_B, _PATH_TAG)
    _assert_snapshot_ids(path_b, kept_path_ids, "repo B after path forget")
    assert forgotten_path_id not in _snapshot_ids(path_b), (
        f"Forgot kept the oldest path snapshot {forgotten_path_id} unexpectedly"
    )

    for snapshot_id in kept_path_ids:
        content = _path_snapshot_content(coordinator, _RESTIC_B, snapshot_id)
        assert content == expected_path_content[snapshot_id], (
            f"Path snapshot {snapshot_id} content mismatch: {content!r}"
        )

    postgres_b = _snapshots(coordinator, _RESTIC_B, _POSTGRES_TAG)
    _assert_snapshot_ids(
        postgres_b, [postgres_snapshot_id], "repo B postgres after path forget"
    )
    _assert_promoted_postgres_snapshot(
        coordinator,
        _RESTIC_B,
        postgres_snapshot_id,
        "backup_promotion_restore_after_forget",
        _POSTGRES_EXPECTED_NOTE,
    )

    # ── 4. Prune and check repo B, then prove both snapshot families still work ──
    _start_and_assert_success("backup_prune_coordinator_b.service", coordinator)
    _start_and_assert_success("backup_check_coordinator_b.service", coordinator)

    path_b = _snapshots(coordinator, _RESTIC_B, _PATH_TAG)
    _assert_snapshot_ids(path_b, kept_path_ids, "repo B after prune/check")
    latest_path_id = kept_path_ids[-1]
    latest_path_content = _path_snapshot_content(coordinator, _RESTIC_B, latest_path_id)
    assert latest_path_content == expected_path_content[latest_path_id], (
        f"Latest path snapshot {latest_path_id} content mismatch: {latest_path_content!r}"
    )

    postgres_b = _snapshots(coordinator, _RESTIC_B, _POSTGRES_TAG)
    _assert_snapshot_ids(
        postgres_b, [postgres_snapshot_id], "repo B postgres after prune/check"
    )
    _assert_promoted_postgres_snapshot(
        coordinator,
        _RESTIC_B,
        postgres_snapshot_id,
        "backup_promotion_restore_after_prune",
        _POSTGRES_EXPECTED_NOTE,
    )
