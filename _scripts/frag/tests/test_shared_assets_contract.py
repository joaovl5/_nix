from __future__ import annotations

from pathlib import Path

from frag import bootstrap, image_assets, shared_assets_contract


def test_bootstrap_shared_home_view_mappings_derive_from_shared_asset_contract() -> (
    None
):
    assert bootstrap._shared_home_view_mappings() == tuple(
        (
            entry.home_relative_path,
            bootstrap.MappingKind.SHARED,
            entry.state_shared_relative_path,
        )
        for entry in shared_assets_contract.SHARED_PACKAGED_ASSET_ENTRIES
    )


def test_image_asset_shared_mount_specs_derive_from_shared_asset_contract() -> None:
    assert image_assets._shared_asset_mount_specs() == tuple(
        (
            str(entry.packaged_asset_relative_path),
            entry.runtime_destination,
            entry.entry_type.value,
        )
        for entry in shared_assets_contract.SHARED_PACKAGED_ASSET_ENTRIES
    )


def test_shared_asset_contract_state_paths_match_runtime_destinations() -> None:
    assert all(
        entry.state_shared_relative_path
        == Path(entry.runtime_destination.removeprefix("/state/shared/"))
        for entry in shared_assets_contract.SHARED_PACKAGED_ASSET_ENTRIES
    )
