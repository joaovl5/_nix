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

type Snapshot = dict[str, object]
type Snapshots = list[Snapshot]


def _start(service: str, node: Machine) -> None:
    node.succeed(f"systemctl start {service}")


def _snapshots(node: Machine, cmd: str, tag: str | None = None) -> Snapshots:
    tag_flag = f"--tag {tag}" if tag else ""
    raw = node.succeed(f"{cmd} snapshots --json {tag_flag}")
    return cast(Snapshots, json.loads(raw))


def _get_tags(snap: Snapshot) -> list[str]:
    tags = snap.get("tags", [])
    return cast("list[str]", tags)


def run(driver_globals: dict[str, object]) -> None:
    """Run backup_promotion integration assertions."""
    start_all = driver_globals.get("start_all")
    if callable(start_all):
        cast("Callable[[], None]", start_all)()

    coordinator = cast("Machine", driver_globals["coordinator"])
    storage = cast("Machine", driver_globals["storage"])

    coordinator.wait_for_unit("multi-user.target")
    storage.wait_for_unit("multi-user.target")
    storage.wait_for_unit("sshd.service")

    # ── 1. Local backup to repo A ─────────────────────────────────────────────
    coordinator.succeed(
        "mkdir -p /test-data && printf 'coordinator-data' > /test-data/file.txt"
    )
    _start("restic-backups-coordinator_my_path_to_a.service", coordinator)

    snaps = _snapshots(coordinator, _RESTIC_A, "item:my-path")
    assert len(snaps) == 1, f"Expected 1 snapshot in repo A, got {len(snaps)}"
    tags = _get_tags(snaps[0])
    assert "host:coordinator" in tags, f"Missing host:coordinator in {tags}"
    assert "promote:B" in tags, f"Missing promote:B tag in {tags}"

    # ── 2. Promotion A → B (SFTP) ────────────────────────────────────────────
    # Promotion service initialises remote repo if empty, then copies snapshots.
    _start("backup_promote_coordinator_my_path_to_b.service", coordinator)

    # Verify remote repo B has the promoted snapshot
    snaps_b = _snapshots(coordinator, _RESTIC_B, "item:my-path")
    assert len(snaps_b) == 1, (
        f"Expected 1 snapshot in remote repo B, got {len(snaps_b)}"
    )
    tags_b = _get_tags(snaps_b[0])
    assert "host:coordinator" in tags_b, (
        f"Missing host:coordinator in remote tags {tags_b}"
    )
    assert "promote:B" in tags_b, f"Missing promote:B in remote tags {tags_b}"

    # ── 3. Restore from remote repo B ────────────────────────────────────────
    coordinator.succeed("rm -f /test-data/file.txt")
    coordinator.succeed(
        f"{_RESTIC_B} restore latest --target /tmp/restore-from-b --tag item:my-path"
    )
    content = coordinator.succeed("cat /tmp/restore-from-b/test-data/file.txt").strip()
    assert content == "coordinator-data", (
        f"Remote restore content mismatch: {content!r}"
    )

    # ── 4. Remote maintenance: prune and check on B ───────────────────────────
    _start("backup_prune_coordinator_b.service", coordinator)
    _start("backup_check_coordinator_b.service", coordinator)
