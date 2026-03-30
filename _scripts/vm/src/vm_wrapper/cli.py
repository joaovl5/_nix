"""Command-line entry points for the VM wrapper."""

from __future__ import annotations

import argparse
from collections.abc import Sequence
from pathlib import Path
import sys
from tempfile import TemporaryDirectory

from vm_wrapper.bundle import UserFacingError, resolve_inputs, stage_bundle
from vm_wrapper.nix_runner import (
    DEFAULT_VM_CPU,
    DEFAULT_VM_RAM,
    build_vm_runner,
    list_hosts,
    require_host,
    run_vm,
)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="vm-launcher")
    parser.add_argument("host")
    parser.add_argument("--age-key")
    parser.add_argument("--ssh-key")
    parser.add_argument("--cpu", type=int, default=DEFAULT_VM_CPU)
    parser.add_argument("--ram", type=int, default=DEFAULT_VM_RAM)
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = build_parser().parse_args(argv)

    try:
        repo_root = Path.cwd()
        resolved = resolve_inputs(
            host=args.host,
            home_dir=Path.home(),
            age_key=args.age_key,
            ssh_key=args.ssh_key,
        )
        available_hosts = list_hosts(repo_root=repo_root)
        require_host(resolved.host, available_hosts)
        runner_path = build_vm_runner(repo_root=repo_root, host=resolved.host)

        with TemporaryDirectory(prefix="vm-bundle-") as bundle_dir_str:
            bundle_dir = Path(bundle_dir_str)
            stage_bundle(bundle_dir, resolved)
            return run_vm(
                runner_path=runner_path,
                bundle_dir=bundle_dir,
                cpu=args.cpu,
                ram=args.ram,
            )
    except UserFacingError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
