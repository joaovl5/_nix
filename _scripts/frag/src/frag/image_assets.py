from __future__ import annotations

from dataclasses import dataclass
import hashlib
import json
from pathlib import Path
import subprocess
from typing import Protocol

from frag import profiles, shared_assets_contract
from frag.exceptions import DockerRuntimeError, LegacySchemaError


def _shared_asset_mount_specs() -> tuple[tuple[str, str, str], ...]:
    return shared_assets_contract.shared_runtime_mount_specs()


@dataclass(frozen=True)
class SharedMount:
    source: Path
    destination: str


@dataclass(frozen=True)
class RuntimeSpec:
    image_ref: str
    shared_assets_identity: str
    shared_mounts: tuple[SharedMount, ...]
    start_command: tuple[str, ...]


@dataclass(frozen=True)
class ResolvedSharedMounts:
    mounts: tuple[SharedMount, ...]
    host_override_sources: tuple[tuple[str, Path], ...]


@dataclass(frozen=True)
class InstalledPackageAssets:
    shared_assets_root: Path
    catalog_path: Path
    helpers_dir: Path


@dataclass(frozen=True)
class PackagedImageMetadata:
    image_key: str
    image_ref: str
    shared_assets_identity: str
    helper_path: Path


class ImageAssets(Protocol):
    def list_image_keys(self) -> tuple[str, ...]: ...

    def normalize_profile_image(self, *, image: str) -> str: ...

    def resolve_profile_image_metadata(
        self, *, profile: profiles.Profile
    ) -> PackagedImageMetadata: ...

    def load_image(self, *, profile: profiles.Profile) -> str: ...

    def build_runtime_spec(
        self, *, profile: profiles.Profile, workspace_root: Path
    ) -> RuntimeSpec: ...


def _shared_asset_entry_has_expected_type(path: Path, entry_type: str) -> bool:
    if entry_type == "directory":
        return path.is_dir()
    if entry_type == "file":
        return path.is_file()
    raise AssertionError(f"unsupported shared asset entry type: {entry_type}")


def _missing_required_shared_assets(shared_assets_root: Path) -> tuple[str, ...]:
    return tuple(
        relative_source
        for relative_source, _destination, entry_type in _shared_asset_mount_specs()
        if not _shared_asset_entry_has_expected_type(
            shared_assets_root / relative_source, entry_type
        )
    )


def _resolve_host_override_source(host_home: Path, relative_path: Path) -> Path:
    return (host_home / relative_path).expanduser().resolve(strict=False)


def _resolve_shared_mounts(
    shared_assets_root: Path,
    *,
    host_home: Path | None = None,
) -> ResolvedSharedMounts:
    package_mounts_by_destination: dict[str, SharedMount] = {}
    mount_order: list[str] = []
    for relative_source, destination, entry_type in _shared_asset_mount_specs():
        source = shared_assets_root / relative_source
        if not _shared_asset_entry_has_expected_type(source, entry_type):
            continue
        package_mounts_by_destination[destination] = SharedMount(
            source=source,
            destination=destination,
        )
        mount_order.append(destination)

    resolved_host_home = (host_home or Path.home()).expanduser().resolve(strict=False)
    host_override_sources: list[tuple[str, Path]] = []
    for (
        relative_path,
        destination,
        entry_type,
    ) in shared_assets_contract.shared_host_override_specs():
        source = _resolve_host_override_source(resolved_host_home, relative_path)
        if not _shared_asset_entry_has_expected_type(source, entry_type):
            continue
        if destination not in package_mounts_by_destination:
            continue
        package_mounts_by_destination[destination] = SharedMount(
            source=source,
            destination=destination,
        )
        host_override_sources.append((destination, source))

    mounts = tuple(
        package_mounts_by_destination[destination]
        for destination in mount_order
        if destination in package_mounts_by_destination
    )
    return ResolvedSharedMounts(
        mounts=mounts,
        host_override_sources=tuple(host_override_sources),
    )


def _resolved_shared_assets_identity(
    base_identity: str,
    *,
    host_override_sources: tuple[tuple[str, Path], ...],
) -> str:
    if not host_override_sources:
        return base_identity
    payload = [
        base_identity,
        [(destination, str(source)) for destination, source in host_override_sources],
    ]
    digest = hashlib.sha256(
        json.dumps(payload, separators=(",", ":")).encode()
    ).hexdigest()[:16]
    return f"{base_identity}-host-{digest}"


def _read_catalog_images(*, catalog_path: Path) -> dict[str, object]:
    try:
        catalog_data = json.loads(catalog_path.read_text())
    except OSError as exc:
        raise DockerRuntimeError(
            f"failed reading frag image catalog at {catalog_path}"
        ) from exc
    except json.JSONDecodeError as exc:
        raise DockerRuntimeError(
            f"frag image catalog at {catalog_path} is not valid JSON"
        ) from exc

    images = catalog_data.get("images")
    if not isinstance(images, dict):
        raise DockerRuntimeError(
            f"frag image catalog at {catalog_path} is missing an 'images' object"
        )
    return images


def _normalize_catalog_image_key(*, images: dict[str, object], image_key: str) -> str:
    normalized_key = image_key.strip()
    image_entry = images.get(normalized_key)
    if not isinstance(image_entry, dict):
        raise DockerRuntimeError(f"unknown image key {normalized_key!r}")
    return normalized_key


def normalize_catalog_image_key(*, catalog_path: Path, image_key: str) -> str:
    images = _read_catalog_images(catalog_path=catalog_path)
    return _normalize_catalog_image_key(images=images, image_key=image_key)


def _resolve_catalog_image_metadata(
    *, catalog_path: Path, helpers_dir: Path, image_key: str
) -> PackagedImageMetadata:
    images = _read_catalog_images(catalog_path=catalog_path)
    normalized_key = _normalize_catalog_image_key(images=images, image_key=image_key)
    image_entry = images[normalized_key]
    assert isinstance(image_entry, dict)

    image_ref = image_entry.get("image_ref")
    shared_assets_identity = image_entry.get("shared_assets_identity")
    loader = image_entry.get("loader")
    if not isinstance(image_ref, str) or not image_ref.strip():
        raise DockerRuntimeError(
            f"catalog entry for image key {normalized_key!r} is missing image_ref"
        )
    if (
        not isinstance(shared_assets_identity, str)
        or not shared_assets_identity.strip()
    ):
        raise LegacySchemaError(
            f"catalog entry for image key {normalized_key!r} is missing shared_assets_identity; legacy catalog schema is not supported"
        )
    if not isinstance(loader, str) or not loader.strip():
        raise DockerRuntimeError(
            f"catalog entry for image key {normalized_key!r} is missing loader"
        )

    helper_path = helpers_dir / loader.strip()

    return PackagedImageMetadata(
        image_key=normalized_key,
        image_ref=image_ref.strip(),
        shared_assets_identity=shared_assets_identity.strip(),
        helper_path=helper_path,
    )


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
            raise DockerRuntimeError(
                f"required shared assets missing or wrong type under {shared_assets_root}: {missing_paths}"
            )

        return InstalledPackageAssets(
            shared_assets_root=shared_assets_root,
            catalog_path=catalog_path,
            helpers_dir=helpers_dir,
        )

    raise DockerRuntimeError(
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

    def resolve_profile_image_metadata(
        self, *, profile: profiles.Profile
    ) -> PackagedImageMetadata:
        return _resolve_catalog_image_metadata(
            catalog_path=self._package_assets.catalog_path,
            helpers_dir=self._package_assets.helpers_dir,
            image_key=profile.image,
        )

    def load_image(self, *, profile: profiles.Profile) -> str:
        metadata = self.resolve_profile_image_metadata(profile=profile)

        if not metadata.helper_path.is_file():
            raise DockerRuntimeError(
                f"image loader helper does not exist: {metadata.helper_path}"
            )

        try:
            result = subprocess.run(
                [str(metadata.helper_path)],
                check=False,
                text=True,
                capture_output=True,
            )
        except FileNotFoundError as exc:
            raise DockerRuntimeError(
                f"image loader helper is not executable: {metadata.helper_path}"
            ) from exc

        if result.returncode != 0:
            detail = (result.stderr or result.stdout or str(result.returncode)).strip()
            raise DockerRuntimeError(detail)

        loaded_image_ref = result.stdout.strip()
        if not loaded_image_ref:
            raise DockerRuntimeError(
                f"image loader returned an empty image reference for {profile.name!r}"
            )
        if loaded_image_ref != metadata.image_ref:
            raise DockerRuntimeError(
                f"image loader returned unexpected image reference for {profile.name!r}: {loaded_image_ref!r}"
            )
        return loaded_image_ref

    def build_runtime_spec(
        self, *, profile: profiles.Profile, workspace_root: Path
    ) -> RuntimeSpec:
        metadata = self.resolve_profile_image_metadata(profile=profile)
        resolved_shared_mounts = _resolve_shared_mounts(
            self._package_assets.shared_assets_root
        )
        return RuntimeSpec(
            image_ref=metadata.image_ref,
            shared_assets_identity=_resolved_shared_assets_identity(
                metadata.shared_assets_identity,
                host_override_sources=resolved_shared_mounts.host_override_sources,
            ),
            shared_mounts=resolved_shared_mounts.mounts,
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
