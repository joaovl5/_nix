from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

import pytest

from vm_wrapper import cli
from vm_wrapper.bundle import UserFacingError


@dataclass(frozen=True)
class FakeResolvedInputs:
    host: str


def test_parser_defaults() -> None:
    args = cli.build_parser().parse_args(["demo-host"])

    assert args.host == "demo-host"
    assert args.age_key is None
    assert args.ssh_key is None


def test_parser_overrides() -> None:
    args = cli.build_parser().parse_args(
        ["demo-host", "--age-key", "/tmp/age.txt", "--ssh-key", "/tmp/id_ed25519"]
    )

    assert args.host == "demo-host"
    assert args.age_key == "/tmp/age.txt"
    assert args.ssh_key == "/tmp/id_ed25519"


def test_main_prints_user_facing_errors(
    monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]
) -> None:
    monkeypatch.setattr(
        cli,
        "resolve_inputs",
        lambda **_: (_ for _ in ()).throw(UserFacingError("bad input")),
    )

    result = cli.main(["demo-host"])

    captured = capsys.readouterr()
    assert result == 1
    assert captured.err == "error: bad input\n"


def test_main_orchestrates_bundle_build_and_run(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    home_dir = tmp_path / "home"
    repo_root = tmp_path / "repo"
    bundle_dirs: list[Path] = []

    repo_root.mkdir()
    home_dir.mkdir()

    resolved = FakeResolvedInputs(host="demo-host")
    expected_runner_path = Path("/nix/store/example-vm/bin/run-lavpc-vm")

    monkeypatch.setattr(cli.Path, "home", lambda: home_dir)
    monkeypatch.setattr(cli.Path, "cwd", lambda: repo_root)
    monkeypatch.setattr(cli, "resolve_inputs", lambda **kwargs: resolved)
    monkeypatch.setattr(cli, "list_hosts", lambda repo_root: ["demo-host"])
    monkeypatch.setattr(cli, "require_host", lambda host, hosts: None)
    monkeypatch.setattr(
        cli, "build_vm_runner", lambda repo_root, host: expected_runner_path
    )

    def fake_stage_bundle(bundle_dir: Path, resolved_inputs: object) -> None:
        assert resolved_inputs is resolved
        bundle_dirs.append(bundle_dir)
        bundle_dir.mkdir(parents=True, exist_ok=True)

    def fake_run_vm(runner_path: Path, bundle_dir: Path) -> int:
        assert runner_path == expected_runner_path
        assert bundle_dir in bundle_dirs
        assert bundle_dir.exists()
        return 0

    monkeypatch.setattr(cli, "stage_bundle", fake_stage_bundle)
    monkeypatch.setattr(cli, "run_vm", fake_run_vm)

    result = cli.main(["demo-host"])

    assert result == 0
    assert len(bundle_dirs) == 1
    assert not bundle_dirs[0].exists()


def test_main_checks_host_before_staging_bundle(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    repo_root = tmp_path / "repo"
    home_dir = tmp_path / "home"
    resolved = FakeResolvedInputs(host="missing-host")
    staged = False

    repo_root.mkdir()
    home_dir.mkdir()

    def require_missing_host(host: str, hosts: list[str]) -> None:
        raise UserFacingError("missing host")

    monkeypatch.setattr(cli.Path, "home", lambda: home_dir)
    monkeypatch.setattr(cli.Path, "cwd", lambda: repo_root)
    monkeypatch.setattr(cli, "resolve_inputs", lambda **kwargs: resolved)
    monkeypatch.setattr(cli, "list_hosts", lambda repo_root: ["demo-host"])
    monkeypatch.setattr(cli, "require_host", require_missing_host)

    def fake_stage_bundle(bundle_dir: Path, resolved_inputs: object) -> None:
        nonlocal staged
        staged = True

    monkeypatch.setattr(cli, "stage_bundle", fake_stage_bundle)

    result = cli.main(["missing-host"])

    assert result == 1
    assert staged is False
