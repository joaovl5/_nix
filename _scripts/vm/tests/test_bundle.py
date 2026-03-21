from __future__ import annotations

import stat
from pathlib import Path

import pytest

from vm_wrapper.bundle import (
    ResolvedInputs,
    UserFacingError,
    resolve_inputs,
    stage_bundle,
    validate_secret_file,
)


def write_secret(path: Path, content: str = "secret", mode: int = 0o600) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="ascii")
    path.chmod(mode)
    return path


def test_resolve_inputs_uses_home_age_default(tmp_path: Path) -> None:
    home = tmp_path / "home"
    key = write_secret(home / ".age" / "key.txt")

    resolved = resolve_inputs(host="lavpc", home_dir=home, age_key=None, ssh_key=None)

    assert resolved == ResolvedInputs(host="lavpc", age_key=key, ssh_key=None)


def test_resolve_inputs_accepts_optional_ssh_key(tmp_path: Path) -> None:
    home = tmp_path / "home"
    age_key = write_secret(home / ".age" / "key.txt")
    ssh_key = write_secret(tmp_path / "keys" / "id_ed25519")

    resolved = resolve_inputs(
        host="lavpc",
        home_dir=home,
        age_key=age_key,
        ssh_key=ssh_key,
    )

    assert resolved.age_key == age_key
    assert resolved.ssh_key == ssh_key


def test_resolve_inputs_expands_user_in_explicit_paths(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    home = tmp_path / "home"
    age_key = write_secret(home / ".age" / "key.txt")
    ssh_key = write_secret(home / ".ssh" / "id_ed25519")
    monkeypatch.setenv("HOME", str(home))

    resolved = resolve_inputs(
        host="lavpc",
        home_dir=home,
        age_key="~/.age/key.txt",
        ssh_key="~/.ssh/id_ed25519",
    )

    assert resolved.age_key == age_key
    assert resolved.ssh_key == ssh_key


def test_validate_secret_file_rejects_missing_file(tmp_path: Path) -> None:
    missing = tmp_path / "missing.txt"

    with pytest.raises(UserFacingError, match="does not exist"):
        validate_secret_file(missing, label="AGE key")


def test_validate_secret_file_rejects_non_regular_file(tmp_path: Path) -> None:
    directory = tmp_path / "secret-dir"
    directory.mkdir()

    with pytest.raises(UserFacingError, match="regular file"):
        validate_secret_file(directory, label="AGE key")


def test_validate_secret_file_rejects_group_readable_file(tmp_path: Path) -> None:
    key = write_secret(tmp_path / "key.txt", mode=0o640)

    with pytest.raises(UserFacingError, match="unsafe permissions"):
        validate_secret_file(key, label="AGE key")


def test_stage_bundle_copies_expected_layout(tmp_path: Path) -> None:
    age_key = write_secret(tmp_path / "inputs" / "age.txt", content="age-secret")
    ssh_key = write_secret(tmp_path / "inputs" / "id_ed25519", content="ssh-secret")
    bundle_dir = tmp_path / "bundle"

    resolved = ResolvedInputs(host="lavpc", age_key=age_key, ssh_key=ssh_key)

    stage_bundle(bundle_dir, resolved)

    staged_age_key = bundle_dir / "age" / "key.txt"
    staged_ssh_key = bundle_dir / "ssh" / "id_ed25519"

    assert staged_age_key.read_text(encoding="ascii") == "age-secret"
    assert staged_ssh_key.read_text(encoding="ascii") == "ssh-secret"
    assert not staged_age_key.is_symlink()
    assert not staged_ssh_key.is_symlink()
    assert staged_age_key.stat().st_ino != age_key.stat().st_ino
    assert staged_ssh_key.stat().st_ino != ssh_key.stat().st_ino
    assert stat.S_IMODE(staged_age_key.stat().st_mode) == 0o600
    assert stat.S_IMODE(staged_ssh_key.stat().st_mode) == 0o600


def test_stage_bundle_skips_optional_ssh_key(tmp_path: Path) -> None:
    age_key = write_secret(tmp_path / "inputs" / "age.txt")
    bundle_dir = tmp_path / "bundle"

    stage_bundle(
        bundle_dir, ResolvedInputs(host="lavpc", age_key=age_key, ssh_key=None)
    )

    assert (bundle_dir / "age" / "key.txt").read_text(encoding="ascii") == "secret"
    assert not (bundle_dir / "ssh" / "id_ed25519").exists()


def test_stage_bundle_replaces_preexisting_destination_symlink(tmp_path: Path) -> None:
    age_key = write_secret(tmp_path / "inputs" / "age.txt", content="age-secret")
    outside_target = write_secret(
        tmp_path / "outside" / "leaked.txt", content="outside"
    )
    bundle_dir = tmp_path / "bundle"
    staged_age_key = bundle_dir / "age" / "key.txt"
    staged_age_key.parent.mkdir(parents=True, exist_ok=True)
    staged_age_key.symlink_to(outside_target)

    stage_bundle(
        bundle_dir, ResolvedInputs(host="lavpc", age_key=age_key, ssh_key=None)
    )

    assert outside_target.read_text(encoding="ascii") == "outside"
    assert staged_age_key.read_text(encoding="ascii") == "age-secret"
    assert not staged_age_key.is_symlink()
