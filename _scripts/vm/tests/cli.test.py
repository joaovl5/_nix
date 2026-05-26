
from pathlib import Path

import pytest
from attrs import define
from vm_wrapper import cli
from vm_wrapper.bundle import UserFacingError


@define(frozen=True)
class FakeResolvedInputs:
  host: str


def test_main_uses_default_cpu_and_ram(
  monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
  """main() defaults to CPU=4 and RAM=6192 when not overridden."""
  home_dir = tmp_path / "home"
  repo_root = tmp_path / "repo"
  repo_root.mkdir()
  home_dir.mkdir()

  resolved = FakeResolvedInputs(host="demo-host")
  runner_path = Path("/nix/store/example-vm/bin/run-demo-host-vm")
  observed: dict[str, int] = {}

  monkeypatch.setattr(cli.Path, "home", lambda: home_dir)
  monkeypatch.setattr(cli.Path, "cwd", lambda: repo_root)
  monkeypatch.setattr(cli, "resolve_inputs", lambda **kwargs: resolved)
  monkeypatch.setattr(cli, "list_hosts", lambda *, repo_root: ["demo-host"])
  monkeypatch.setattr(
    cli, "require_host", lambda *, host, available_hosts: None
  )
  monkeypatch.setattr(
    cli, "build_vm_runner", lambda *, repo_root, host: runner_path
  )
  monkeypatch.setattr(
    cli, "stage_bundle", lambda *, bundle_dir, resolved: None
  )

  def capture_run_vm(
    *, runner_path: Path, bundle_dir: Path, cpu: int, ram: int
  ) -> int:
    observed["cpu"] = cpu
    observed["ram"] = ram
    return 0

  monkeypatch.setattr(cli, "run_vm", capture_run_vm)

  result = cli.main("demo-host")

  assert result == 0
  # Default values from nix_runner constants
  assert observed["cpu"] == 4
  assert observed["ram"] == 6192


def test_main_passes_explicit_cpu_and_ram(
  monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
  """main() forwards --cpu and --ram overrides to run_vm."""
  home_dir = tmp_path / "home"
  repo_root = tmp_path / "repo"
  repo_root.mkdir()
  home_dir.mkdir()

  resolved = FakeResolvedInputs(host="demo-host")
  runner_path = Path("/nix/store/example-vm/bin/run-demo-host-vm")
  observed: dict[str, int] = {}

  monkeypatch.setattr(cli.Path, "home", lambda: home_dir)
  monkeypatch.setattr(cli.Path, "cwd", lambda: repo_root)
  monkeypatch.setattr(cli, "resolve_inputs", lambda **kwargs: resolved)
  monkeypatch.setattr(cli, "list_hosts", lambda *, repo_root: ["demo-host"])
  monkeypatch.setattr(
    cli, "require_host", lambda *, host, available_hosts: None
  )
  monkeypatch.setattr(
    cli, "build_vm_runner", lambda *, repo_root, host: runner_path
  )
  monkeypatch.setattr(
    cli, "stage_bundle", lambda *, bundle_dir, resolved: None
  )

  def capture_run_vm(
    *, runner_path: Path, bundle_dir: Path, cpu: int, ram: int
  ) -> int:
    observed["cpu"] = cpu
    observed["ram"] = ram
    return 0

  monkeypatch.setattr(cli, "run_vm", capture_run_vm)

  result = cli.main("demo-host", cpu=2, ram=4096)

  assert result == 0
  assert observed["cpu"] == 2
  assert observed["ram"] == 4096


def test_main_prints_user_facing_errors(
  monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]
) -> None:
  """User-facing errors are printed to stderr and return exit code 1."""
  monkeypatch.setattr(
    cli,
    "resolve_inputs",
    lambda **_: (_ for _ in ()).throw(UserFacingError("bad input")),
  )

  result = cli.main("demo-host")

  captured = capsys.readouterr()
  assert result == 1
  assert captured.err == "error: bad input\n"


def test_main_orchestrates_bundle_build_and_run(
  monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
  """main() resolves inputs, validates host, builds runner, stages, and runs."""
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
  monkeypatch.setattr(cli, "list_hosts", lambda *, repo_root: ["demo-host"])
  monkeypatch.setattr(
    cli, "require_host", lambda *, host, available_hosts: None
  )
  monkeypatch.setattr(
    cli,
    "build_vm_runner",
    lambda *, repo_root, host: expected_runner_path,
  )

  def fake_stage_bundle(*, bundle_dir: Path, resolved: object) -> None:  # noqa: ARG001
    bundle_dirs.append(bundle_dir)
    bundle_dir.mkdir(parents=True, exist_ok=True)

  def fake_run_vm(
    *,
    runner_path: Path,
    bundle_dir: Path,
    cpu: int,
    ram: int,
  ) -> int:
    assert runner_path == expected_runner_path
    assert bundle_dir in bundle_dirs
    assert bundle_dir.exists()
    # CPU and RAM overrides passed through correctly
    assert cpu == 8
    assert ram == 4096
    return 0

  monkeypatch.setattr(cli, "stage_bundle", fake_stage_bundle)
  monkeypatch.setattr(cli, "run_vm", fake_run_vm)

  result = cli.main("demo-host", cpu=8, ram=4096)

  # Successful run returns 0 and cleans up bundle directory
  assert result == 0
  assert len(bundle_dirs) == 1
  assert not bundle_dirs[0].exists()


def test_main_checks_host_before_staging_bundle(
  monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
  """If host validation fails, bundle staging is never attempted."""
  repo_root = tmp_path / "repo"
  home_dir = tmp_path / "home"
  resolved = FakeResolvedInputs(host="missing-host")
  staged = False

  repo_root.mkdir()
  home_dir.mkdir()

  def require_missing_host(
    *, host: str, available_hosts: list[str]  # noqa: ARG001
  ) -> None:
    raise UserFacingError("missing host")

  monkeypatch.setattr(cli.Path, "home", lambda: home_dir)
  monkeypatch.setattr(cli.Path, "cwd", lambda: repo_root)
  monkeypatch.setattr(cli, "resolve_inputs", lambda **kwargs: resolved)
  monkeypatch.setattr(cli, "list_hosts", lambda *, repo_root: ["demo-host"])
  monkeypatch.setattr(cli, "require_host", require_missing_host)

  def fake_stage_bundle(*, bundle_dir: Path, resolved: object) -> None:  # noqa: ARG001
    nonlocal staged
    staged = True

  monkeypatch.setattr(cli, "stage_bundle", fake_stage_bundle)

  result = cli.main("missing-host")

  # Host validation failure returns 1 without staging
  assert result == 1
  assert staged is False
