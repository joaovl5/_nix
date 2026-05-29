import importlib
import json
import sys
from pathlib import Path

import pytest
from frag import profiles, shared_assets_contract
from frag.exceptions import DockerRuntimeError, LegacySchemaError


def _import_image_assets():
  sys.modules.pop("frag.image_assets", None)
  return importlib.import_module("frag.image_assets")


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
  package_root = tmp_path / "frag-package"
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
  package_root = tmp_path / "frag-package"
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


def test_direct_profile_image_assets_uses_packaged_mounts_when_host_overrides_absent(
  monkeypatch: pytest.MonkeyPatch,
  tmp_path: Path,
) -> None:
  """Covers direct profile image assets uses packaged mounts when host overrides absent."""
  package_root = tmp_path / "frag-package"
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


def test_direct_profile_image_assets_prefers_host_override_mounts(
  monkeypatch: pytest.MonkeyPatch,
  tmp_path: Path,
) -> None:
  """Covers direct profile image assets prefers host override mounts."""
  package_root = tmp_path / "frag-package"
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
