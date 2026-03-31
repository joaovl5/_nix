from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path
from subprocess import CalledProcessError, CompletedProcess

import pytest

from vm_wrapper.bundle import UserFacingError
from vm_wrapper.nix_runner import build_vm_runner, list_hosts, require_host, run_vm


@dataclass
class FakeRun:
    stdout: str = ""
    returncode: int = 0
    calls: list[tuple[list[str], dict[str, str] | None, Path | None, bool]] = field(
        default_factory=list
    )

    def __call__(
        self,
        command: list[str],
        env: dict[str, str] | None,
        cwd: Path | None,
        check: bool,
    ):
        self.calls.append((command, env, cwd, check))
        return CompletedProcess(command, self.returncode, stdout=self.stdout, stderr="")


@dataclass
class FakeRunVm:
    returncode: int = 0
    calls: list[tuple[Path, dict[str, str] | None]] = field(default_factory=list)

    def __call__(self, runner_path: Path, env: dict[str, str] | None) -> int:
        self.calls.append((runner_path, env))
        return self.returncode


def test_list_hosts_uses_expected_eval_command(tmp_path: Path) -> None:
    fake_run = FakeRun(stdout='["alpha", "beta"]\n')

    hosts = list_hosts(repo_root=tmp_path, run_command=fake_run)

    assert hosts == ["alpha", "beta"]
    assert fake_run.calls == [
        (
            [
                "nix",
                "eval",
                "--json",
                ".#nixosConfigurations",
                "--apply",
                "builtins.attrNames",
            ],
            None,
            tmp_path,
            True,
        )
    ]


def test_require_host_rejects_unknown_host() -> None:
    with pytest.raises(
        UserFacingError, match="Available nixosConfigurations: alpha, beta"
    ):
        require_host("missing", ["beta", "alpha"])


def test_build_vm_runner_uses_expected_installable(tmp_path: Path) -> None:
    runner_path = tmp_path / "example-vm-runner"
    runner_path.write_text("#!/usr/bin/env bash\n", encoding="ascii")
    runner_path.chmod(0o755)
    fake_run = FakeRun(stdout=f"{runner_path}\n")

    runner = build_vm_runner(repo_root=tmp_path, host="lavpc", run_command=fake_run)

    assert runner == runner_path
    assert fake_run.calls == [
        (
            [
                "nix",
                "build",
                ".#nixosConfigurations.lavpc.config.system.build.vm",
                "--print-out-paths",
                "--no-link",
            ],
            None,
            tmp_path,
            True,
        )
    ]


def test_build_vm_runner_uses_vm_script_from_directory_output(tmp_path: Path) -> None:
    vm_output = tmp_path / "nixos-vm-output"
    vm_output_bin = vm_output / "bin"
    vm_output_bin.mkdir(parents=True)
    runner = vm_output_bin / "run-lavpc-vm"
    runner.write_text("#!/usr/bin/env bash\n", encoding="ascii")
    runner.chmod(0o755)

    fake_run = FakeRun(stdout=f"{vm_output}\n")

    resolved = build_vm_runner(repo_root=tmp_path, host="lavpc", run_command=fake_run)

    assert resolved == runner


def test_build_vm_runner_rejects_unexpected_vm_output_shape(tmp_path: Path) -> None:
    vm_output = tmp_path / "nixos-vm-output"
    vm_output_bin = vm_output / "bin"
    vm_output_bin.mkdir(parents=True)
    (vm_output_bin / "run-other-vm").write_text(
        "#!/usr/bin/env bash\n", encoding="ascii"
    )
    (vm_output_bin / "run-another-vm").write_text(
        "#!/usr/bin/env bash\n", encoding="ascii"
    )

    fake_run = FakeRun(stdout=f"{vm_output}\n")

    with pytest.raises(UserFacingError, match="Failed to resolve VM runner path"):
        build_vm_runner(repo_root=tmp_path, host="lavpc", run_command=fake_run)


def test_run_vm_uses_bundle_environment_without_default_overrides(
    tmp_path: Path,
) -> None:
    fake_run = FakeRunVm(returncode=7)
    bundle_dir = tmp_path / "bundle"
    runner_path = Path("/nix/store/example-vm/bin/run-lavpc-vm")

    result = run_vm(
        runner_path=runner_path,
        bundle_dir=bundle_dir,
        cpu=4,
        ram=6192,
        run_command=fake_run,
    )

    assert result == 7
    assert fake_run.calls == [
        (
            runner_path,
            {
                "VM_BUNDLE_DIR": str(bundle_dir),
            },
        )
    ]


def test_run_vm_does_not_raise_on_non_zero_exit(tmp_path: Path) -> None:
    fake_run = FakeRunVm(returncode=3)

    result = run_vm(
        runner_path=Path("/nix/store/example-vm/bin/run-lavpc-vm"),
        bundle_dir=tmp_path / "bundle",
        cpu=4,
        ram=6192,
        run_command=fake_run,
    )

    assert result == 3


def test_run_vm_preserves_existing_qemu_opts_without_default_overrides(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    fake_run = FakeRunVm(returncode=0)
    monkeypatch.setenv("QEMU_OPTS", "-display gtk")

    result = run_vm(
        runner_path=Path("/nix/store/example-vm/bin/run-lavpc-vm"),
        bundle_dir=tmp_path / "bundle",
        cpu=4,
        ram=6192,
        run_command=fake_run,
    )

    assert result == 0
    assert fake_run.calls == [
        (
            Path("/nix/store/example-vm/bin/run-lavpc-vm"),
            {
                "VM_BUNDLE_DIR": str(tmp_path / "bundle"),
                "QEMU_OPTS": "-display gtk",
            },
        )
    ]


def test_run_vm_preserves_existing_qemu_opts(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    fake_run = FakeRunVm(returncode=0)
    monkeypatch.setenv("QEMU_OPTS", "-display gtk")

    result = run_vm(
        runner_path=Path("/nix/store/example-vm/bin/run-lavpc-vm"),
        bundle_dir=tmp_path / "bundle",
        cpu=2,
        ram=4096,
        run_command=fake_run,
    )

    assert result == 0
    assert fake_run.calls == [
        (
            Path("/nix/store/example-vm/bin/run-lavpc-vm"),
            {
                "VM_BUNDLE_DIR": str(tmp_path / "bundle"),
                "QEMU_OPTS": "-display gtk -m 4096 -smp 2",
            },
        )
    ]


def test_list_hosts_wraps_command_failures(tmp_path: Path) -> None:
    def failing_run(
        command: list[str],
        env: dict[str, str] | None,
        cwd: Path | None,
        check: bool,
    ):
        raise CalledProcessError(returncode=1, cmd=command, stderr="nix failed")

    with pytest.raises(UserFacingError, match="Failed to list VM hosts. nix failed"):
        list_hosts(repo_root=tmp_path, run_command=failing_run)
