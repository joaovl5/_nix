from __future__ import annotations

from dataclasses import dataclass
import json
from pathlib import Path
import subprocess
from typing import Protocol

from frag import docker_runtime, profiles

_SHARED_ASSET_MOUNTS: tuple[tuple[str, str, str], ...] = (
    (".agents/skills", "/state/shared/agents/skills", "directory"),
    (".config/agents/skills", "/state/shared/config/agents/skills", "directory"),
    (".code/agents", "/state/shared/code/agents", "directory"),
    (".code/skills", "/state/shared/code/skills", "directory"),
    (".code/AGENTS.md", "/state/shared/code/AGENTS.md", "file"),
    (".omp/agent/agents", "/state/shared/omp/agent/agents", "directory"),
    (".omp/agent/skills", "/state/shared/omp/agent/skills", "directory"),
    (".omp/agent/SYSTEM.md", "/state/shared/omp/agent/SYSTEM.md", "file"),
    (".config/opencode/skill", "/state/shared/opencode/skill", "directory"),
    (".config/opencode/opencode.json", "/state/shared/opencode/opencode.json", "file"),
    (
        ".config/opencode/superpowers",
        "/state/shared/opencode/superpowers",
        "directory",
    ),
    (
        ".config/opencode/plugins/superpowers.js",
        "/state/shared/opencode/plugins/superpowers.js",
        "file",
    ),
)


@dataclass(frozen=True)
class SharedMount:
    source: Path
    destination: str


@dataclass(frozen=True)
class RuntimeSpec:
    image_ref: str
    shared_mounts: tuple[SharedMount, ...]
    start_command: tuple[str, ...]


@dataclass(frozen=True)
class InstalledPackageAssets:
    shared_assets_root: Path
    catalog_path: Path
    helpers_dir: Path


class ImageAssets(Protocol):
    def list_image_keys(self) -> tuple[str, ...]: ...

    def normalize_profile_image(self, *, image: str) -> str: ...

    def load_image(self, *, profile: profiles.Profile) -> str: ...

    def build_runtime_spec(
        self, *, profile: profiles.Profile, workspace_root: Path
    ) -> RuntimeSpec: ...


def _canonical_path(path: Path | str) -> Path:
    return Path(path).expanduser().resolve(strict=False)


def _shared_asset_entry_has_expected_type(path: Path, entry_type: str) -> bool:
    if entry_type == "directory":
        return path.is_dir()
    if entry_type == "file":
        return path.is_file()
    raise AssertionError(f"unsupported shared asset entry type: {entry_type}")


def _missing_required_shared_assets(shared_assets_root: Path) -> tuple[str, ...]:
    return tuple(
        relative_source
        for relative_source, _destination, entry_type in _SHARED_ASSET_MOUNTS
        if not _shared_asset_entry_has_expected_type(
            shared_assets_root / relative_source, entry_type
        )
    )


def _resolve_shared_mounts(shared_assets_root: Path) -> tuple[SharedMount, ...]:
    mounts: list[SharedMount] = []
    for relative_source, destination, entry_type in _SHARED_ASSET_MOUNTS:
        source = shared_assets_root / relative_source
        if _shared_asset_entry_has_expected_type(source, entry_type):
            mounts.append(SharedMount(source=source, destination=destination))
    return tuple(mounts)


def _read_catalog_images(*, catalog_path: Path) -> dict[str, object]:
    try:
        catalog_data = json.loads(catalog_path.read_text())
    except OSError as exc:
        raise docker_runtime.DockerRuntimeError(
            f"failed reading frag image catalog at {catalog_path}"
        ) from exc
    except json.JSONDecodeError as exc:
        raise docker_runtime.DockerRuntimeError(
            f"frag image catalog at {catalog_path} is not valid JSON"
        ) from exc

    images = catalog_data.get("images")
    if not isinstance(images, dict):
        raise docker_runtime.DockerRuntimeError(
            f"frag image catalog at {catalog_path} is missing an 'images' object"
        )
    return images


def _normalize_catalog_image_key(*, images: dict[str, object], image_key: str) -> str:
    normalized_key = image_key.strip()
    image_entry = images.get(normalized_key)
    if not isinstance(image_entry, dict):
        raise docker_runtime.DockerRuntimeError(f"unknown image key {normalized_key!r}")
    return normalized_key


def normalize_catalog_image_key(*, catalog_path: Path, image_key: str) -> str:
    images = _read_catalog_images(catalog_path=catalog_path)
    return _normalize_catalog_image_key(images=images, image_key=image_key)


def _resolve_catalog_image_entry(
    *, catalog_path: Path, image_key: str
) -> tuple[str, str]:
    images = _read_catalog_images(catalog_path=catalog_path)
    normalized_key = _normalize_catalog_image_key(images=images, image_key=image_key)
    image_entry = images[normalized_key]
    assert isinstance(image_entry, dict)

    image_ref = image_entry.get("image_ref")
    loader = image_entry.get("loader")
    if not isinstance(image_ref, str) or not image_ref.strip():
        raise docker_runtime.DockerRuntimeError(
            f"catalog entry for image key {normalized_key!r} is missing image_ref"
        )
    if not isinstance(loader, str) or not loader.strip():
        raise docker_runtime.DockerRuntimeError(
            f"catalog entry for image key {normalized_key!r} is missing loader"
        )
    return image_ref.strip(), loader.strip()


def resolve_installed_package_assets(
    package_anchor: Path | str | None = None,
) -> InstalledPackageAssets:
    search_anchor = Path(package_anchor or Path(__file__).resolve()).expanduser()
    if not search_anchor.is_absolute():
        search_anchor = Path.cwd() / search_anchor
    search_start = search_anchor if search_anchor.is_dir() else search_anchor.parent

    for package_root in (search_start, *search_start.parents):
        share_dir = package_root / "share" / "frag"
        shared_assets_root = share_dir / "shared-assets"
        catalog_path = share_dir / "catalog.json"
        helpers_dir = share_dir / "helpers"
        if not (
            catalog_path.is_file()
            and helpers_dir.is_dir()
            and shared_assets_root.exists()
        ):
            continue

        missing_required_assets = _missing_required_shared_assets(shared_assets_root)
        if missing_required_assets:
            missing_paths = ", ".join(missing_required_assets)
            raise docker_runtime.DockerRuntimeError(
                f"required shared assets missing or wrong type under {shared_assets_root}: {missing_paths}"
            )

        return InstalledPackageAssets(
            shared_assets_root=shared_assets_root,
            catalog_path=catalog_path,
            helpers_dir=helpers_dir,
        )

    raise docker_runtime.DockerRuntimeError(
        f"installed frag assets could not be resolved from {search_anchor}"
    )


class DirectProfileImageAssets:
    def __init__(self, *, package_assets: InstalledPackageAssets) -> None:
        self._package_assets = package_assets

    def list_image_keys(self) -> tuple[str, ...]:
        return tuple(
            _read_catalog_images(catalog_path=self._package_assets.catalog_path)
        )

    def normalize_profile_image(self, *, image: str) -> str:
        return normalize_catalog_image_key(
            catalog_path=self._package_assets.catalog_path,
            image_key=image,
        )

    def load_image(self, *, profile: profiles.Profile) -> str:
        _image_ref, loader_name = _resolve_catalog_image_entry(
            catalog_path=self._package_assets.catalog_path,
            image_key=profile.image,
        )
        helper_path = self._package_assets.helpers_dir / loader_name
        if not helper_path.is_file():
            raise docker_runtime.DockerRuntimeError(
                f"image loader helper does not exist: {helper_path}"
            )

        try:
            result = subprocess.run(
                [str(helper_path)],
                check=False,
                text=True,
                capture_output=True,
            )
        except FileNotFoundError as exc:
            raise docker_runtime.DockerRuntimeError(
                f"image loader helper is not executable: {helper_path}"
            ) from exc

        if result.returncode != 0:
            detail = (result.stderr or result.stdout or str(result.returncode)).strip()
            raise docker_runtime.DockerRuntimeError(detail)

        loaded_image_ref = result.stdout.strip()
        if not loaded_image_ref:
            raise docker_runtime.DockerRuntimeError(
                f"image loader returned an empty image reference for {profile.name!r}"
            )
        return loaded_image_ref

    def build_runtime_spec(
        self, *, profile: profiles.Profile, workspace_root: Path
    ) -> RuntimeSpec:
        image_ref, _loader_name = _resolve_catalog_image_entry(
            catalog_path=self._package_assets.catalog_path,
            image_key=profile.image,
        )
        return RuntimeSpec(
            image_ref=image_ref,
            shared_mounts=_resolve_shared_mounts(
                self._package_assets.shared_assets_root
            ),
            start_command=(
                "frag-bootstrap",
                "--profile-name",
                profile.name,
                "--profile-image",
                profile.image,
                "--workspace-root",
                str(workspace_root),
                "--keepalive",
                "tail",
                "-f",
                "/dev/null",
            ),
        )
