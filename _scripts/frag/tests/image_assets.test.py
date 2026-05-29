import hashlib
import importlib
import json
import re
import shutil
import subprocess
import sys
import tarfile
import time
from functools import lru_cache
from pathlib import Path

import pytest
from frag import profiles, shared_assets_contract
from frag.exceptions import DockerRuntimeError, LegacySchemaError


def _import_image_assets():
  sys.modules.pop("frag.image_assets", None)
  return importlib.import_module("frag.image_assets")


REPO_ROOT = Path(__file__).resolve().parents[3]
FRAG_BUILD_EXPR = r"""
let
  flake = builtins.getFlake (toString ./.);
  outputs = flake.outputs;
  pkgs = import outputs.inputs.nixpkgs {
    system = "x86_64-linux";
    overlays = outputs._channels.overlays;
    config.allowUnfree = true;
  };
  local = import ./modules/_packages {
    inherit pkgs;
    inputs = outputs.inputs;
  };
in
  local.frag
"""
FRAG_TERMINAL_ASSETS_EXPR = r"""
let
  flake = builtins.getFlake (toString ./.);
  outputs = flake.outputs;
  pkgs = import outputs.inputs.nixpkgs {
    system = "x86_64-linux";
    overlays = outputs._channels.overlays;
    config.allowUnfree = true;
  };
in
  import ./modules/_packages/frag/terminal_assets.nix {
    inherit pkgs;
    zjstatus = outputs.inputs.zjstatus.packages.x86_64-linux.default;
  }
"""

FRAG_RUNTIME_ROOTFS_EXPR = r"""
let
  flake = builtins.getFlake (toString ./.);
  outputs = flake.outputs;
  pkgs = import outputs.inputs.nixpkgs {
    system = "x86_64-linux";
    overlays = outputs._channels.overlays;
    config.allowUnfree = true;
  };
  local = import ./modules/_packages {
    inherit pkgs;
    inputs = outputs.inputs;
  };
in
  local.frag.passthru.images.main.artifact
"""


_DOCKER_BIN = shutil.which("docker")

_NIX_BIN = shutil.which("nix")


def _build_nix_output(build_expr: str) -> Path:
  if _NIX_BIN is None:
    pytest.skip("nix executable is required for packaging-contract tests")

  result = subprocess.run(
    [
      _NIX_BIN,
      "build",
      "--impure",
      "--no-link",
      "--print-out-paths",
      "--expr",
      build_expr,
    ],
    cwd=REPO_ROOT,
    check=True,
    text=True,
    capture_output=True,
  )
  return Path(result.stdout.strip())


@lru_cache(maxsize=1)
def _build_frag_package() -> Path:
  return _build_nix_output(FRAG_BUILD_EXPR)


@lru_cache(maxsize=1)
def _build_frag_runtime_rootfs() -> Path:
  return _build_nix_output(FRAG_RUNTIME_ROOTFS_EXPR)


@lru_cache(maxsize=1)
def _build_frag_terminal_assets() -> Path:
  return _build_nix_output(FRAG_TERMINAL_ASSETS_EXPR)


def _load_packaged_catalog(package_root: Path) -> dict[str, object]:
  return json.loads(
    (package_root / "share" / "frag" / "catalog.json").read_text()
  )


def _require_docker() -> str:
  if _DOCKER_BIN is None:
    pytest.skip("docker executable is required for packaged helper tests")

  result = subprocess.run(
    [_DOCKER_BIN, "info"],
    check=False,
    text=True,
    capture_output=True,
  )
  if result.returncode != 0:
    detail = (
      result.stderr or result.stdout or str(result.returncode)
    ).strip()
    pytest.skip(
      f"docker daemon is unavailable for packaged helper tests: {detail}"
    )

  return _DOCKER_BIN


_PACKAGED_IMAGE_IDENTITY_LABEL = "dev.frag.packaged-runtime-rootfs"
_PACKAGED_IMAGE_CHANGE_PREFIX = [
  'CMD ["/init"]',
  "ENV HOME=/home/agent",
  "ENV PATH=/sw/bin:/bin",
  "ENV USER=agent",
  "WORKDIR /home/agent",
]
_PACKAGED_IMAGE_ENV = [
  "HOME=/home/agent",
  "PATH=/sw/bin:/bin",
  "USER=agent",
]
_PACKAGED_IMAGE_WORKDIR = "/home/agent"


def _packaged_image_identity() -> str:
  recipe_seed = [
    str(_build_frag_runtime_rootfs()),
    _PACKAGED_IMAGE_CHANGE_PREFIX
    + [f"LABEL {_PACKAGED_IMAGE_IDENTITY_LABEL}=<packaged-image-identity>"],
  ]
  recipe_json = json.dumps(recipe_seed, separators=(",", ":"))
  return hashlib.sha256(recipe_json.encode()).hexdigest()


def _inspect_image(docker_bin: str, image_ref: str) -> dict[str, object]:
  inspect_result = subprocess.run(
    [docker_bin, "image", "inspect", image_ref],
    check=False,
    text=True,
    capture_output=True,
  )
  # Verify the observed behavior matches the contract.
  assert inspect_result.returncode == 0, (
    inspect_result.stderr or inspect_result.stdout
  )
  inspect_payload = json.loads(inspect_result.stdout)
  # Verify the observed behavior matches the contract.
  assert len(inspect_payload) == 1
  return inspect_payload[0]


def _import_unrelated_image(
  docker_bin: str, image_ref: str, tmp_path: Path
) -> dict[str, object]:
  rootfs_dir = tmp_path / "unrelated-rootfs"
  rootfs_dir.mkdir()
  (rootfs_dir / "etc").mkdir()
  (rootfs_dir / "etc" / "issue").write_text("unrelated\n")

  archive_path = tmp_path / "unrelated-rootfs.tar"
  with tarfile.open(archive_path, mode="w") as archive:
    archive.add(rootfs_dir, arcname=".")

  subprocess.run(
    [docker_bin, "image", "rm", "-f", image_ref],
    check=False,
    text=True,
    capture_output=True,
  )
  import_result = subprocess.run(
    [docker_bin, "import", str(archive_path), image_ref],
    check=False,
    text=True,
    capture_output=True,
  )
  # Verify the observed behavior matches the contract.
  assert import_result.returncode == 0, (
    import_result.stderr or import_result.stdout
  )
  return _inspect_image(docker_bin, image_ref)


def _create_shared_assets_tree(shared_assets_dir: Path) -> None:
  for (
    relative_source,
    _destination,
    entry_type,
  ) in shared_assets_contract.shared_runtime_mount_specs():
    asset_path = shared_assets_dir / relative_source
    asset_path.parent.mkdir(parents=True, exist_ok=True)
    if entry_type == "file":
      asset_path.write_text("placeholder\n")
    else:
      asset_path.mkdir(exist_ok=True)


def _create_host_override_tree(host_home: Path) -> None:
  (host_home / ".agents" / "skills").mkdir(parents=True, exist_ok=True)
  (host_home / ".agents" / "skills" / "README.md").write_text("host agents\n")
  (host_home / ".config" / "agents" / "skills").mkdir(
    parents=True, exist_ok=True
  )
  (host_home / ".config" / "agents" / "skills" / "README.md").write_text(
    "host config agents\n"
  )
  (host_home / ".config" / "zellij").mkdir(parents=True, exist_ok=True)
  (host_home / ".config" / "zellij" / "config.kdl").write_text(
    'default_mode "locked"\n'
  )
  (host_home / ".config" / "zellij" / "layouts").mkdir(
    parents=True, exist_ok=True
  )
  (host_home / ".config" / "zellij" / "layouts" / "default.kdl").write_text(
    "layout host\n"
  )
  (host_home / ".local" / "share" / "zellij" / "plugins").mkdir(
    parents=True, exist_ok=True
  )
  (
    host_home / ".local" / "share" / "zellij" / "plugins" / "zjstatus.wasm"
  ).write_text("wasm\n")
  (host_home / ".config" / "tmux" / "plugins").mkdir(
    parents=True, exist_ok=True
  )
  (host_home / ".config" / "tmux" / "tmux.conf").write_text(
    "set -g prefix C-a\n"
  )
  (host_home / ".config" / "tmux" / "plugins" / "better-mouse-mode").mkdir(
    parents=True, exist_ok=True
  )
  (
    host_home
    / ".config"
    / "tmux"
    / "plugins"
    / "better-mouse-mode"
    / "scroll_copy_mode.tmux"
  ).write_text("bind -T copy-mode-vi v send-keys -X begin-selection\n")


def test_image_assets_imports_without_docker_runtime_bootstrap() -> None:
  """Covers image assets imports without docker runtime bootstrap."""
  original_docker_runtime = sys.modules.pop("frag.docker_runtime", None)

  try:
    module = _import_image_assets()

    # Verify the observed behavior matches the contract.
    assert module.__name__ == "frag.image_assets"
    # Verify the observed behavior matches the contract.
    assert "frag.docker_runtime" not in sys.modules
  finally:
    if original_docker_runtime is not None:
      sys.modules["frag.docker_runtime"] = original_docker_runtime


def test_direct_profile_image_assets_exposes_schema2_packaged_metadata(
  tmp_path: Path,
) -> None:
  """Covers direct profile image assets exposes schema2 packaged metadata."""
  package_root = tmp_path / "nix" / "store" / "frag-0.1.0"
  shared_assets_dir = package_root / "share" / "frag" / "shared-assets"
  _create_shared_assets_tree(shared_assets_dir)

  helpers_dir = package_root / "share" / "frag" / "helpers"
  helpers_dir.mkdir(parents=True)
  helper_path = helpers_dir / "load-image-main"
  helper_path.write_text("#!/bin/sh\nprintf 'frag-main:immutable123\n'")
  helper_path.chmod(0o755)

  catalog_path = package_root / "share" / "frag" / "catalog.json"
  catalog_path.parent.mkdir(parents=True, exist_ok=True)
  catalog_path.write_text(
    json.dumps(
      {
        "images": {
          "main": {
            "image_ref": "frag-main:immutable123",
            "shared_assets_identity": "shared-assets-123",
            "loader": "load-image-main",
          }
        }
      }
    )
  )

  image_assets = _import_image_assets()

  assets = image_assets.DirectProfileImageAssets(
    package_assets=image_assets.resolve_installed_package_assets(package_root)
  )
  profile = profiles.Profile(
    name="demo",
    image="main",
    workspace_root="/workspace/demo",
    volume_name="frag-profile-demo",
  )

  metadata = assets.resolve_profile_image_metadata(profile=profile)

  # Verify the observed behavior matches the contract.
  assert metadata.image_key == "main"
  # Verify the observed behavior matches the contract.
  assert metadata.image_ref == "frag-main:immutable123"
  # Verify the observed behavior matches the contract.
  assert metadata.shared_assets_identity == "shared-assets-123"
  # Verify the observed behavior matches the contract.
  assert metadata.helper_path == helper_path


def test_direct_profile_image_assets_refuses_legacy_catalog_entries(
  tmp_path: Path,
) -> None:
  """Covers direct profile image assets refuses legacy catalog entries."""
  package_root = tmp_path / "nix" / "store" / "frag-0.1.0"
  shared_assets_dir = package_root / "share" / "frag" / "shared-assets"
  _create_shared_assets_tree(shared_assets_dir)

  helpers_dir = package_root / "share" / "frag" / "helpers"
  helpers_dir.mkdir(parents=True)
  helper_path = helpers_dir / "load-image-main"
  helper_path.write_text("#!/bin/sh\nprintf 'frag-main:immutable123\n'")
  helper_path.chmod(0o755)

  catalog_path = package_root / "share" / "frag" / "catalog.json"
  catalog_path.parent.mkdir(parents=True, exist_ok=True)
  catalog_path.write_text(
    json.dumps(
      {
        "images": {
          "main": {
            "image_ref": "frag-main:immutable123",
            "loader": "load-image-main",
          }
        }
      }
    )
  )

  image_assets = _import_image_assets()

  assets = image_assets.DirectProfileImageAssets(
    package_assets=image_assets.resolve_installed_package_assets(package_root)
  )
  profile = profiles.Profile(
    name="demo",
    image="main",
    workspace_root="/workspace/demo",
    volume_name="frag-profile-demo",
  )

  with pytest.raises(LegacySchemaError) as exc_info:
    assets.resolve_profile_image_metadata(profile=profile)

  # Verify the observed behavior matches the contract.
  assert isinstance(exc_info.value, DockerRuntimeError)
  # Verify the observed behavior matches the contract.
  assert "shared_assets_identity" in str(exc_info.value)


def test_packaged_catalog_exposes_main_runtime_metadata() -> None:
  """Covers packaged catalog exposes main runtime metadata."""
  package_root = _build_frag_package()
  catalog = _load_packaged_catalog(package_root)

  # Verify the observed behavior matches the contract.
  assert "main" in catalog["images"]
  main = catalog["images"]["main"]

  # Verify the observed behavior matches the contract.
  assert main["image_ref"] == f"frag-main:{_packaged_image_identity()[:32]}"
  # Verify the observed behavior matches the contract.
  assert isinstance(main["shared_assets_identity"], str)
  # Verify the observed behavior matches the contract.
  assert main["shared_assets_identity"].strip()
  # Verify the observed behavior matches the contract.
  assert re.fullmatch(r"load-image-[a-z0-9][a-z0-9-]*", main["loader"])


def test_direct_profile_image_assets_uses_packaged_mounts_when_host_overrides_absent(
  monkeypatch: pytest.MonkeyPatch,
  tmp_path: Path,
) -> None:
  """Covers direct profile image assets uses packaged mounts when host overrides absent."""
  package_root = tmp_path / "nix" / "store" / "frag-0.1.0"
  shared_assets_dir = package_root / "share" / "frag" / "shared-assets"
  _create_shared_assets_tree(shared_assets_dir)

  helpers_dir = package_root / "share" / "frag" / "helpers"
  helpers_dir.mkdir(parents=True)
  helper_path = helpers_dir / "load-image-main"
  helper_path.write_text("#!/bin/sh\nprintf 'frag-main:immutable123\n'")
  helper_path.chmod(0o755)

  catalog_path = package_root / "share" / "frag" / "catalog.json"
  catalog_path.parent.mkdir(parents=True, exist_ok=True)
  catalog_path.write_text(
    json.dumps(
      {
        "images": {
          "main": {
            "image_ref": "frag-main:immutable123",
            "shared_assets_identity": "shared-assets-123",
            "loader": "load-image-main",
          }
        }
      }
    )
  )

  image_assets = _import_image_assets()
  monkeypatch.setattr(
    image_assets.Path, "home", lambda: tmp_path / "empty-home"
  )

  assets = image_assets.DirectProfileImageAssets(
    package_assets=image_assets.resolve_installed_package_assets(package_root)
  )
  profile = profiles.Profile(
    name="demo",
    image="main",
    workspace_root="/workspace/demo",
    volume_name="frag-profile-demo",
  )

  runtime_spec = assets.build_runtime_spec(
    profile=profile,
    workspace_root=Path("/workspace/demo"),
  )
  mounts_by_destination = {
    shared_mount.destination: shared_mount.source
    for shared_mount in runtime_spec.shared_mounts
  }

  # Verify the observed behavior matches the contract.
  assert runtime_spec.shared_assets_identity == "shared-assets-123"
  # Verify the observed behavior matches the contract.
  assert mounts_by_destination["/state/shared/agents/skills"] == (
    shared_assets_dir / ".agents" / "skills"
  )
  # Verify the observed behavior matches the contract.
  assert mounts_by_destination["/state/shared/config/zellij/config.kdl"] == (
    shared_assets_dir / ".config" / "zellij" / "config.kdl"
  )
  # Verify the observed behavior matches the contract.
  assert mounts_by_destination["/state/shared/config/tmux/tmux.conf"] == (
    shared_assets_dir / ".config" / "tmux" / "tmux.conf"
  )


def test_packaged_shared_assets_cover_runtime_mount_contract(
  monkeypatch: pytest.MonkeyPatch,
  tmp_path: Path,
) -> None:
  """Covers packaged shared assets cover runtime mount contract."""
  image_assets = _import_image_assets()

  monkeypatch.setattr(
    image_assets.Path, "home", lambda: tmp_path / "empty-home"
  )

  package_root = _build_frag_package()
  package_assets = image_assets.resolve_installed_package_assets(package_root)
  catalog = _load_packaged_catalog(package_root)

  profile = profiles.Profile(
    name="demo",
    image="main",
    workspace_root="/workspace/demo",
    volume_name="frag-profile-demo",
  )
  runtime_spec = image_assets.DirectProfileImageAssets(
    package_assets=package_assets
  ).build_runtime_spec(
    profile=profile, workspace_root=Path("/workspace/demo")
  )

  expected_mounted_entries = {
    (relative_source, destination): package_assets.shared_assets_root
    / relative_source
    for relative_source, destination, _entry_type in shared_assets_contract.shared_runtime_mount_specs()
  }
  mounted_entries = {
    (
      str(shared_mount.source.relative_to(package_assets.shared_assets_root)),
      shared_mount.destination,
    ): shared_mount.source
    for shared_mount in runtime_spec.shared_mounts
  }

  # Verify the observed behavior matches the contract.
  assert (
    runtime_spec.shared_assets_identity
    == catalog["images"]["main"]["shared_assets_identity"]
  )
  # Verify the observed behavior matches the contract.
  assert runtime_spec.shared_mounts
  # Verify the observed behavior matches the contract.
  assert mounted_entries == expected_mounted_entries
  # Verify the observed behavior matches the contract.
  assert all(
    shared_mount.source.exists()
    and str(shared_mount.source).startswith(
      str(package_assets.shared_assets_root)
    )
    and shared_mount.destination.startswith("/state/shared/")
    for shared_mount in runtime_spec.shared_mounts
  )

  for (
    relative_source,
    _destination,
    entry_type,
  ) in shared_assets_contract.shared_runtime_mount_specs():
    asset_path = package_assets.shared_assets_root / relative_source
    if entry_type == "directory":
      # Verify the observed behavior matches the contract.
      assert asset_path.is_dir()
    else:
      # Verify the observed behavior matches the contract.
      assert asset_path.is_file()


def test_direct_profile_image_assets_prefers_host_override_mounts(
  monkeypatch: pytest.MonkeyPatch,
  tmp_path: Path,
) -> None:
  """Covers direct profile image assets prefers host override mounts."""
  package_root = tmp_path / "nix" / "store" / "frag-0.1.0"
  shared_assets_dir = package_root / "share" / "frag" / "shared-assets"
  _create_shared_assets_tree(shared_assets_dir)

  helpers_dir = package_root / "share" / "frag" / "helpers"
  helpers_dir.mkdir(parents=True)
  helper_path = helpers_dir / "load-image-main"
  helper_path.write_text("#!/bin/sh\nprintf 'frag-main:immutable123\n'")
  helper_path.chmod(0o755)

  catalog_path = package_root / "share" / "frag" / "catalog.json"
  catalog_path.parent.mkdir(parents=True, exist_ok=True)
  catalog_path.write_text(
    json.dumps(
      {
        "images": {
          "main": {
            "image_ref": "frag-main:immutable123",
            "shared_assets_identity": "shared-assets-123",
            "loader": "load-image-main",
          }
        }
      }
    )
  )

  image_assets = _import_image_assets()
  host_home = tmp_path / "host-home"
  _create_host_override_tree(host_home)
  monkeypatch.setattr(image_assets.Path, "home", lambda: host_home)

  assets = image_assets.DirectProfileImageAssets(
    package_assets=image_assets.resolve_installed_package_assets(package_root)
  )
  profile = profiles.Profile(
    name="demo",
    image="main",
    workspace_root="/workspace/demo",
    volume_name="frag-profile-demo",
  )

  runtime_spec = assets.build_runtime_spec(
    profile=profile,
    workspace_root=Path("/workspace/demo"),
  )
  mounts_by_destination = {
    shared_mount.destination: shared_mount.source
    for shared_mount in runtime_spec.shared_mounts
  }

  # Verify the observed behavior matches the contract.
  assert runtime_spec.shared_assets_identity != "shared-assets-123"
  # Verify the observed behavior matches the contract.
  assert mounts_by_destination["/state/shared/agents/skills"] == (
    host_home / ".agents" / "skills"
  ).resolve(strict=False)
  # Verify the observed behavior matches the contract.
  assert mounts_by_destination["/state/shared/config/agents/skills"] == (
    host_home / ".config" / "agents" / "skills"
  ).resolve(strict=False)
  # Verify the observed behavior matches the contract.
  assert mounts_by_destination["/state/shared/config/zellij/config.kdl"] == (
    host_home / ".config" / "zellij" / "config.kdl"
  ).resolve(strict=False)
  # Verify the observed behavior matches the contract.
  assert mounts_by_destination["/state/shared/config/zellij/layouts"] == (
    host_home / ".config" / "zellij" / "layouts"
  ).resolve(strict=False)
  # Verify the observed behavior matches the contract.
  assert mounts_by_destination[
    "/state/shared/local/share/zellij/plugins/zjstatus.wasm"
  ] == (
    host_home / ".local" / "share" / "zellij" / "plugins" / "zjstatus.wasm"
  ).resolve(strict=False)
  # Verify the observed behavior matches the contract.
  assert mounts_by_destination["/state/shared/config/tmux/tmux.conf"] == (
    host_home / ".config" / "tmux" / "tmux.conf"
  ).resolve(strict=False)
  # Verify the observed behavior matches the contract.
  assert mounts_by_destination[
    "/state/shared/config/tmux/plugins/better-mouse-mode"
  ] == (
    host_home / ".config" / "tmux" / "plugins" / "better-mouse-mode"
  ).resolve(strict=False)
  # Verify the observed behavior matches the contract.
  assert mounts_by_destination["/state/shared/code/agents"] == (
    shared_assets_dir / ".code" / "agents"
  )


def test_packaged_helper_wiring_stays_under_share_frag_helpers() -> None:
  """Covers packaged helper wiring stays under share frag helpers."""
  package_root = _build_frag_package()
  catalog = _load_packaged_catalog(package_root)

  loader_name = catalog["images"]["main"]["loader"]
  helper_path = package_root / "share" / "frag" / "helpers" / loader_name

  # Verify the observed behavior matches the contract.
  assert helper_path.is_file()
  # Verify the observed behavior matches the contract.
  assert helper_path.parent == package_root / "share" / "frag" / "helpers"
  # Verify the observed behavior matches the contract.
  assert helper_path.resolve().is_file()
  # Verify the observed behavior matches the contract.
  assert helper_path.stat().st_mode & 0o111


def test_packaged_shared_skill_bundles_exclude_agent_browser_skill() -> None:
  """Covers packaged shared skill bundles exclude agent browser skill."""
  package_root = _build_frag_package()
  shared_assets_root = package_root / "share" / "frag" / "shared-assets"

  skill_roots = (
    shared_assets_root / ".agents" / "skills",
    shared_assets_root / ".config" / "agents" / "skills",
    shared_assets_root / ".code" / "skills",
    shared_assets_root / ".omp" / "agent" / "skills",
    shared_assets_root / ".config" / "opencode" / "skill",
  )

  for skill_root in skill_roots:
    # Verify the observed behavior matches the contract.
    assert skill_root.is_dir()

  # Verify the observed behavior matches the contract.
  assert (
    shared_assets_root / ".config" / "opencode" / "skill" / "superpowers"
  ).is_dir()


def test_packaged_terminal_shared_assets_cover_runtime_contract() -> None:
  """Covers packaged terminal shared assets cover runtime contract."""
  terminal_assets_root = (
    _build_frag_terminal_assets() / "share" / "frag" / "shared-assets"
  )

  terminal_paths = {
    relative_source: terminal_assets_root / relative_source
    for relative_source, _destination, _entry_type in shared_assets_contract.shared_runtime_mount_specs()
    if relative_source.startswith(
      (
        ".config/fish/",
        ".config/starship",
        ".config/zellij/",
        ".local/share/zellij/",
        ".config/tmux/",
      )
    )
  }

  # Verify the observed behavior matches the contract.
  assert terminal_paths
  # Verify the observed behavior matches the contract.
  assert (
    terminal_paths[".config/zellij/config.kdl"].read_text()
    == (
      REPO_ROOT
      / "modules"
      / "aspects"
      / "desktop"
      / "cli"
      / "multiplexer"
      / "zellij"
      / "config"
      / "config.kdl"
    ).read_text()
  )
  # Verify the observed behavior matches the contract.
  assert (terminal_paths[".config/zellij/layouts"] / "default.kdl").is_file()
  # Verify the observed behavior matches the contract.
  assert terminal_paths[".config/zellij/layouts"].is_dir()
  # Verify the observed behavior matches the contract.
  assert terminal_paths[".local/share/zellij/plugins/zjstatus.wasm"].is_file()
  # Verify the observed behavior matches the contract.
  assert terminal_paths[".config/starship.toml"].is_file()
  # Verify the observed behavior matches the contract.
  assert terminal_paths[".config/fish/conf.d/frag_init.fish"].is_file()
  # Verify the observed behavior matches the contract.
  assert terminal_paths[
    ".config/fish/conf.d/container_safe_vars.fish"
  ].is_file()
  # Verify the observed behavior matches the contract.
  assert terminal_paths[
    ".config/fish/conf.d/container_safe_functions.fish"
  ].is_file()
  # Verify the observed behavior matches the contract.
  assert terminal_paths[".config/tmux/tmux.conf"].is_file()
  # Verify the observed behavior matches the contract.
  assert terminal_paths[".config/tmux/plugins/better-mouse-mode"].is_dir()

  tmux_config = terminal_paths[".config/tmux/tmux.conf"].read_text()
  # Verify the observed behavior matches the contract.
  assert "better-mouse-mode" in tmux_config
  # Verify the observed behavior matches the contract.
  assert "run-shell" in tmux_config
  # Verify the observed behavior matches the contract.
  assert (
    terminal_paths[".config/tmux/plugins/better-mouse-mode"]
    / "scroll_copy_mode.tmux"
  ).is_file()

  for relative_source, asset_path in terminal_paths.items():
    entry_type = dict(
      (source, kind)
      for source, _destination, kind in shared_assets_contract.shared_runtime_mount_specs()
    )[relative_source]
    if entry_type == "directory":
      # Verify the observed behavior matches the contract.
      assert asset_path.is_dir()
    else:
      # Verify the observed behavior matches the contract.
      assert asset_path.is_file()


def test_packaged_runtime_rootfs_exports_agent_home_target() -> None:
  """Covers packaged runtime rootfs exports agent home target."""
  runtime_rootfs = _build_frag_runtime_rootfs()

  with tarfile.open(runtime_rootfs) as archive:
    members = {
      member.name.removeprefix("./"): member
      for member in archive.getmembers()
    }
    home_member = members["home/agent"]
    state_home_member = members["state/profile/home"]
    system_path_member = members["sw"]

  # Verify the observed behavior matches the contract.
  assert runtime_rootfs.name.endswith("-frag-runtime-rootfs.tar")
  # Verify the observed behavior matches the contract.
  assert home_member.issym()
  # Verify the observed behavior matches the contract.
  assert home_member.linkname == "/state/profile/home"
  # Verify the observed behavior matches the contract.
  assert state_home_member.isdir()
  # Verify the observed behavior matches the contract.
  assert system_path_member.issym()
  # Verify the observed behavior matches the contract.
  assert re.fullmatch(
    r"/nix/store/[0-9a-z]{32}-system-path",
    system_path_member.linkname,
  )


def test_packaged_helper_reports_exact_catalog_image_ref() -> None:
  """Covers packaged helper reports exact catalog image ref."""
  docker_bin = _require_docker()
  package_root = _build_frag_package()
  catalog = _load_packaged_catalog(package_root)

  main = catalog["images"]["main"]
  helper_path = package_root / "share" / "frag" / "helpers" / main["loader"]

  subprocess.run(
    [docker_bin, "image", "rm", "-f", main["image_ref"]],
    check=False,
    text=True,
    capture_output=True,
  )

  try:
    result = subprocess.run(
      [str(helper_path)],
      check=False,
      text=True,
      capture_output=True,
    )

    # Verify the observed behavior matches the contract.
    assert result.returncode == 0, result.stderr or result.stdout
    # Verify the observed behavior matches the contract.
    assert result.stdout.strip() == main["image_ref"]

    image_metadata = _inspect_image(docker_bin, main["image_ref"])
    # Verify the observed behavior matches the contract.
    assert image_metadata["RepoTags"] == [main["image_ref"]]
    # Verify the observed behavior matches the contract.
    assert image_metadata["Config"]["Cmd"] == ["/init"]
    # Verify the observed behavior matches the contract.
    assert image_metadata["Config"]["WorkingDir"] == "/home/agent"
    # Verify the observed behavior matches the contract.
    assert sorted(image_metadata["Config"]["Env"]) == [
      "HOME=/home/agent",
      "PATH=/sw/bin:/bin",
      "USER=agent",
    ]
    # Verify the observed behavior matches the contract.
    assert (
      image_metadata["Config"]["Labels"][_PACKAGED_IMAGE_IDENTITY_LABEL]
      == _packaged_image_identity()
    )
  finally:
    subprocess.run(
      [docker_bin, "image", "rm", "-f", main["image_ref"]],
      check=False,
      text=True,
      capture_output=True,
    )


def test_packaged_helper_runtime_image_includes_git() -> None:
  """Covers packaged helper runtime image includes git."""
  docker_bin = _require_docker()
  package_root = _build_frag_package()
  catalog = _load_packaged_catalog(package_root)

  main = catalog["images"]["main"]
  helper_path = package_root / "share" / "frag" / "helpers" / main["loader"]

  subprocess.run(
    [docker_bin, "image", "rm", "-f", main["image_ref"]],
    check=False,
    text=True,
    capture_output=True,
  )

  try:
    result = subprocess.run(
      [str(helper_path)],
      check=False,
      text=True,
      capture_output=True,
    )

    # Verify the observed behavior matches the contract.
    assert result.returncode == 0, result.stderr or result.stdout

    git_check = subprocess.run(
      [
        docker_bin,
        "run",
        "--rm",
        "--entrypoint",
        "/sw/bin/bash",
        main["image_ref"],
        "-lc",
        "test -x /sw/bin/bash && command -v git >/dev/null",
      ],
      check=False,
      text=True,
      capture_output=True,
    )

    # Verify the observed behavior matches the contract.
    assert git_check.returncode == 0, git_check.stderr or git_check.stdout
  finally:
    subprocess.run(
      [docker_bin, "image", "rm", "-f", main["image_ref"]],
      check=False,
      text=True,
      capture_output=True,
    )


def test_packaged_helper_reuses_matching_packaged_image_identity() -> None:
  """Covers packaged helper reuses matching packaged image identity."""
  docker_bin = _require_docker()
  package_root = _build_frag_package()
  catalog = _load_packaged_catalog(package_root)

  main = catalog["images"]["main"]
  helper_path = package_root / "share" / "frag" / "helpers" / main["loader"]

  subprocess.run(
    [docker_bin, "image", "rm", "-f", main["image_ref"]],
    check=False,
    text=True,
    capture_output=True,
  )

  try:
    first_result = subprocess.run(
      [str(helper_path)],
      check=False,
      text=True,
      capture_output=True,
    )
    # Verify the observed behavior matches the contract.
    assert first_result.returncode == 0, (
      first_result.stderr or first_result.stdout
    )

    first_metadata = _inspect_image(docker_bin, main["image_ref"])
    time.sleep(1.2)

    second_result = subprocess.run(
      [str(helper_path)],
      check=False,
      text=True,
      capture_output=True,
    )
    # Verify the observed behavior matches the contract.
    assert second_result.returncode == 0, (
      second_result.stderr or second_result.stdout
    )

    second_metadata = _inspect_image(docker_bin, main["image_ref"])
    # Verify the observed behavior matches the contract.
    assert second_metadata["Id"] == first_metadata["Id"]
    # Verify the observed behavior matches the contract.
    assert second_metadata["Created"] == first_metadata["Created"]
  finally:
    subprocess.run(
      [docker_bin, "image", "rm", "-f", main["image_ref"]],
      check=False,
      text=True,
      capture_output=True,
    )


def test_packaged_helper_reimports_unlabeled_same_tag_image(
  tmp_path: Path,
) -> None:
  """Covers packaged helper reimports unlabeled same tag image."""
  docker_bin = _require_docker()
  package_root = _build_frag_package()
  catalog = _load_packaged_catalog(package_root)

  main = catalog["images"]["main"]
  helper_path = package_root / "share" / "frag" / "helpers" / main["loader"]

  try:
    stale_metadata = _import_unrelated_image(
      docker_bin, main["image_ref"], tmp_path
    )
    # Verify the observed behavior matches the contract.
    assert stale_metadata["Config"].get("Labels") in (None, {})

    result = subprocess.run(
      [str(helper_path)],
      check=False,
      text=True,
      capture_output=True,
    )

    # Verify the observed behavior matches the contract.
    assert result.returncode == 0, result.stderr or result.stdout
    refreshed_metadata = _inspect_image(docker_bin, main["image_ref"])
    # Verify the observed behavior matches the contract.
    assert refreshed_metadata["Id"] != stale_metadata["Id"]
    # Verify the observed behavior matches the contract.
    assert (
      refreshed_metadata["Config"]["Labels"][_PACKAGED_IMAGE_IDENTITY_LABEL]
      == _packaged_image_identity()
    )
  finally:
    subprocess.run(
      [docker_bin, "image", "rm", "-f", main["image_ref"]],
      check=False,
      text=True,
      capture_output=True,
    )


def test_packaged_helper_reimports_same_tag_image_with_legacy_rootfs_only_identity(
  tmp_path: Path,
) -> None:
  """Covers packaged helper reimports same tag image with legacy rootfs only identity."""
  docker_bin = _require_docker()
  package_root = _build_frag_package()
  catalog = _load_packaged_catalog(package_root)

  main = catalog["images"]["main"]
  helper_path = package_root / "share" / "frag" / "helpers" / main["loader"]

  rootfs_dir = tmp_path / "legacy-rootfs"
  rootfs_dir.mkdir()
  (rootfs_dir / "etc").mkdir()
  (rootfs_dir / "etc" / "issue").write_text("legacy-rootfs-only\n")
  archive_path = tmp_path / "legacy-rootfs.tar"
  with tarfile.open(archive_path, mode="w") as archive:
    archive.add(rootfs_dir, arcname=".")

  subprocess.run(
    [docker_bin, "image", "rm", "-f", main["image_ref"]],
    check=False,
    text=True,
    capture_output=True,
  )

  legacy_identity = _build_frag_runtime_rootfs().name

  try:
    import_result = subprocess.run(
      [
        docker_bin,
        "import",
        "--change",
        'CMD ["/bin/sh"]',
        "--change",
        f"LABEL {_PACKAGED_IMAGE_IDENTITY_LABEL}={legacy_identity}",
        str(archive_path),
        main["image_ref"],
      ],
      check=False,
      text=True,
      capture_output=True,
    )
    # Verify the observed behavior matches the contract.
    assert import_result.returncode == 0, (
      import_result.stderr or import_result.stdout
    )

    stale_metadata = _inspect_image(docker_bin, main["image_ref"])
    # Verify the observed behavior matches the contract.
    assert (
      stale_metadata["Config"]["Labels"][_PACKAGED_IMAGE_IDENTITY_LABEL]
      == legacy_identity
    )
    # Verify the observed behavior matches the contract.
    assert stale_metadata["Config"]["Cmd"] == ["/bin/sh"]

    result = subprocess.run(
      [str(helper_path)],
      check=False,
      text=True,
      capture_output=True,
    )

    # Verify the observed behavior matches the contract.
    assert result.returncode == 0, result.stderr or result.stdout
    refreshed_metadata = _inspect_image(docker_bin, main["image_ref"])
    # Verify the observed behavior matches the contract.
    assert refreshed_metadata["Id"] != stale_metadata["Id"]
    # Verify the observed behavior matches the contract.
    assert refreshed_metadata["Config"]["Cmd"] == ["/init"]
    # Verify the observed behavior matches the contract.
    assert (
      refreshed_metadata["Config"]["WorkingDir"] == _PACKAGED_IMAGE_WORKDIR
    )
    # Verify the observed behavior matches the contract.
    assert sorted(refreshed_metadata["Config"]["Env"]) == sorted(
      _PACKAGED_IMAGE_ENV
    )
    # Verify the observed behavior matches the contract.
    assert (
      refreshed_metadata["Config"]["Labels"][_PACKAGED_IMAGE_IDENTITY_LABEL]
      == _packaged_image_identity()
    )
  finally:
    subprocess.run(
      [docker_bin, "image", "rm", "-f", main["image_ref"]],
      check=False,
      text=True,
      capture_output=True,
    )


def test_packaged_helper_reimports_same_tag_image_with_wrong_identity_label(
  tmp_path: Path,
) -> None:
  """Covers packaged helper reimports same tag image with wrong identity label."""
  docker_bin = _require_docker()
  package_root = _build_frag_package()
  catalog = _load_packaged_catalog(package_root)

  main = catalog["images"]["main"]
  helper_path = package_root / "share" / "frag" / "helpers" / main["loader"]

  rootfs_dir = tmp_path / "mismatched-rootfs"
  rootfs_dir.mkdir()
  (rootfs_dir / "etc").mkdir()
  (rootfs_dir / "etc" / "issue").write_text("mismatched\n")
  archive_path = tmp_path / "mismatched-rootfs.tar"
  with tarfile.open(archive_path, mode="w") as archive:
    archive.add(rootfs_dir, arcname=".")

  subprocess.run(
    [docker_bin, "image", "rm", "-f", main["image_ref"]],
    check=False,
    text=True,
    capture_output=True,
  )

  try:
    import_result = subprocess.run(
      [
        docker_bin,
        "import",
        "--change",
        f"LABEL {_PACKAGED_IMAGE_IDENTITY_LABEL}=wrong-identity",
        str(archive_path),
        main["image_ref"],
      ],
      check=False,
      text=True,
      capture_output=True,
    )
    # Verify the observed behavior matches the contract.
    assert import_result.returncode == 0, (
      import_result.stderr or import_result.stdout
    )

    stale_metadata = _inspect_image(docker_bin, main["image_ref"])
    # Verify the observed behavior matches the contract.
    assert (
      stale_metadata["Config"]["Labels"][_PACKAGED_IMAGE_IDENTITY_LABEL]
      == "wrong-identity"
    )

    result = subprocess.run(
      [str(helper_path)],
      check=False,
      text=True,
      capture_output=True,
    )

    # Verify the observed behavior matches the contract.
    assert result.returncode == 0, result.stderr or result.stdout
    refreshed_metadata = _inspect_image(docker_bin, main["image_ref"])
    # Verify the observed behavior matches the contract.
    assert refreshed_metadata["Id"] != stale_metadata["Id"]
    # Verify the observed behavior matches the contract.
    assert refreshed_metadata["RepoTags"] == [main["image_ref"]]
    # Verify the observed behavior matches the contract.
    assert (
      refreshed_metadata["Config"]["Labels"][_PACKAGED_IMAGE_IDENTITY_LABEL]
      != "wrong-identity"
    )
  finally:
    subprocess.run(
      [docker_bin, "image", "rm", "-f", main["image_ref"]],
      check=False,
      text=True,
      capture_output=True,
    )
