"""Command-line entry points for the VM wrapper."""

import sys
from pathlib import Path
from tempfile import TemporaryDirectory

from cyclopts import App

from vm_wrapper.bundle import UserFacingError, resolve_inputs, stage_bundle
from vm_wrapper.nix_runner import (
  DEFAULT_VM_CPU,
  DEFAULT_VM_RAM,
  build_vm_runner,
  list_hosts,
  require_host,
  run_vm,
)

app = App(name="vm-launcher")


@app.default
def main(
  host: str,
  *,
  repo_root: Path | None = None,
  age_key: Path | None = None,
  ssh_key: Path | None = None,
  cpu: int = DEFAULT_VM_CPU,
  ram: int = DEFAULT_VM_RAM,
) -> int:
  """Launch a configured NixOS VM."""
  try:
    resolved_repo_root = repo_root if repo_root is not None else Path.cwd()
    resolved = resolve_inputs(
      host=host,
      home_dir=Path.home(),
      age_key=age_key,
      ssh_key=ssh_key,
    )
    available_hosts = list_hosts(repo_root=resolved_repo_root)
    require_host(host=resolved.host, available_hosts=available_hosts)
    runner_path = build_vm_runner(
      repo_root=resolved_repo_root,
      host=resolved.host,
    )

    with TemporaryDirectory(prefix="vm-bundle-") as bundle_dir_str:
      bundle_dir = Path(bundle_dir_str)
      stage_bundle(bundle_dir=bundle_dir, resolved=resolved)
      return run_vm(
        runner_path=runner_path,
        bundle_dir=bundle_dir,
        cpu=cpu,
        ram=ram,
      )
  except UserFacingError as exc:
    print(f"error: {exc}", file=sys.stderr)
    return 1


if __name__ == "__main__":
  raise SystemExit(app())
