from __future__ import annotations

import json
from functools import lru_cache
from pathlib import Path
import re
import shutil
import subprocess
import tarfile

import pytest

from frag import image_assets, profiles


REPO_ROOT = Path(__file__).resolve().parents[3]
FRAG_BUILD_EXPR = r"""
let
  flake = builtins.getFlake (toString ./.);
  pkgs = import flake.inputs.nixpkgs {
    system = "x86_64-linux";
    overlays = flake._channels.overlays;
    config.allowUnfree = true;
  };
  local = import ./packages {
    inherit pkgs;
    inputs = flake.inputs;
  };
in
  local.frag
"""


_DOCKER_BIN = shutil.which("docker")


_NIX_BIN = shutil.which("nix")


@lru_cache(maxsize=1)
def _build_frag_package() -> Path:
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
            FRAG_BUILD_EXPR,
        ],
        cwd=REPO_ROOT,
        check=True,
        text=True,
        capture_output=True,
    )
    return Path(result.stdout.strip())


def _load_packaged_catalog(package_root: Path) -> dict[str, object]:
    return json.loads((package_root / "share" / "frag" / "catalog.json").read_text())


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
        detail = (result.stderr or result.stdout or str(result.returncode)).strip()
        pytest.skip(f"docker daemon is unavailable for packaged helper tests: {detail}")

    return _DOCKER_BIN


def _create_shared_assets_tree(shared_assets_dir: Path) -> None:
    for relative_source, _destination, entry_type in image_assets._SHARED_ASSET_MOUNTS:
        asset_path = shared_assets_dir / relative_source
        asset_path.parent.mkdir(parents=True, exist_ok=True)
        if entry_type == "file":
            asset_path.write_text("placeholder\n")
        else:
            asset_path.mkdir(exist_ok=True)


def test_direct_profile_image_assets_exposes_schema2_packaged_metadata(
    tmp_path: Path,
) -> None:
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

    assert metadata.image_key == "main"
    assert metadata.image_ref == "frag-main:immutable123"
    assert metadata.shared_assets_identity == "shared-assets-123"
    assert metadata.helper_path == helper_path


def test_direct_profile_image_assets_refuses_legacy_catalog_entries(
    tmp_path: Path,
) -> None:
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

    assets = image_assets.DirectProfileImageAssets(
        package_assets=image_assets.resolve_installed_package_assets(package_root)
    )
    profile = profiles.Profile(
        name="demo",
        image="main",
        workspace_root="/workspace/demo",
        volume_name="frag-profile-demo",
    )

    with pytest.raises(
        image_assets.docker_runtime.DockerRuntimeError,
        match="shared_assets_identity",
    ):
        assets.resolve_profile_image_metadata(profile=profile)


def test_packaged_catalog_exposes_schema2_runtime_metadata() -> None:
    package_root = _build_frag_package()
    catalog = _load_packaged_catalog(package_root)

    main = catalog["images"]["main"]

    assert re.fullmatch(r"frag-main:[0-9a-df-np-sv-z]{32}", main["image_ref"])
    assert isinstance(main["shared_assets_identity"], str)
    assert main["shared_assets_identity"].strip()


def test_packaged_helper_stays_under_share_frag_helpers() -> None:
    package_root = _build_frag_package()
    catalog = _load_packaged_catalog(package_root)

    assert "main" in catalog["images"]

    loader_name = catalog["images"]["main"]["loader"]
    helper_path = package_root / "share" / "frag" / "helpers" / loader_name

    assert helper_path.is_file()
    assert helper_path.parent == package_root / "share" / "frag" / "helpers"

    helper_script = helper_path.resolve().read_text()

    assert "ENV PATH=/sw/bin:/bin" in helper_script
    assert "ENV PATH=/run/current-system/sw/bin:/bin" not in helper_script


def test_packaged_runtime_rootfs_seeds_agent_home_target() -> None:
    package_root = _build_frag_package()
    catalog = _load_packaged_catalog(package_root)
    helper_path = (
        package_root
        / "share"
        / "frag"
        / "helpers"
        / catalog["images"]["main"]["loader"]
    )
    helper_script = helper_path.resolve().read_text()

    runtime_rootfs = Path(
        re.search(r"^runtime_rootfs=([^\n]+)$", helper_script, re.MULTILINE).group(1)
    )

    with tarfile.open(runtime_rootfs) as archive:
        home_member = archive.getmember("./home/agent")
        state_home_member = archive.getmember("./state/profile/home")
        system_path_member = archive.getmember("./sw")

    assert home_member.issym()
    assert home_member.linkname == "/state/profile/home"
    assert state_home_member.isdir()
    assert system_path_member.issym()
    assert re.fullmatch(
        r"/nix/store/[0-9a-z]{32}-system-path",
        system_path_member.linkname,
    )


def test_packaged_helper_reports_exact_catalog_image_ref() -> None:
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

        assert result.returncode == 0, result.stderr or result.stdout
        assert result.stdout.strip() == main["image_ref"]

        inspect_result = subprocess.run(
            [docker_bin, "image", "inspect", main["image_ref"]],
            check=False,
            text=True,
            capture_output=True,
        )
        assert inspect_result.returncode == 0, (
            inspect_result.stderr or inspect_result.stdout
        )
    finally:
        subprocess.run(
            [docker_bin, "image", "rm", "-f", main["image_ref"]],
            check=False,
            text=True,
            capture_output=True,
        )
