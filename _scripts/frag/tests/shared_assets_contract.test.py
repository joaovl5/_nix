from pathlib import Path

from frag import bootstrap, image_assets, shared_assets_contract


def test_bootstrap_shared_home_view_mappings_derive_from_shared_asset_contract() -> (
  None
):
  """Covers bootstrap shared home view mappings derive from shared asset contract."""
  # Verify the observed behavior matches the contract.
  assert bootstrap._shared_home_view_mappings() == tuple(
    (
      entry.home_relative_path,
      bootstrap.MappingKind.SHARED,
      entry.state_shared_relative_path,
    )
    for entry in shared_assets_contract.SHARED_PACKAGED_ASSET_ENTRIES
  )


def test_image_asset_shared_mount_specs_derive_from_shared_asset_contract() -> (
  None
):
  """Covers image asset shared mount specs derive from shared asset contract."""
  # Verify the observed behavior matches the contract.
  assert image_assets._shared_asset_mount_specs() == tuple(
    (
      str(entry.packaged_asset_relative_path),
      entry.runtime_destination,
      entry.entry_type.value,
    )
    for entry in shared_assets_contract.SHARED_PACKAGED_ASSET_ENTRIES
  )


def test_shared_asset_contract_state_paths_match_runtime_destinations() -> (
  None
):
  """Covers shared asset contract state paths match runtime destinations."""
  # Verify the observed behavior matches the contract.
  assert all(
    entry.state_shared_relative_path
    == Path(entry.runtime_destination.removeprefix("/state/shared/"))
    for entry in shared_assets_contract.SHARED_PACKAGED_ASSET_ENTRIES
  )


def test_shared_asset_contract_declares_terminal_assets() -> None:
  """Covers shared asset contract declares terminal assets."""
  expected_terminal_entries = {
    (
      Path(".config/fish/conf.d/frag_init.fish"),
      Path(".config/fish/conf.d/frag_init.fish"),
      "/state/shared/config/fish/conf.d/frag_init.fish",
      shared_assets_contract.SharedAssetEntryType.FILE,
    ),
    (
      Path(".config/fish/conf.d/container_safe_vars.fish"),
      Path(".config/fish/conf.d/container_safe_vars.fish"),
      "/state/shared/config/fish/conf.d/container_safe_vars.fish",
      shared_assets_contract.SharedAssetEntryType.FILE,
    ),
    (
      Path(".config/fish/conf.d/container_safe_functions.fish"),
      Path(".config/fish/conf.d/container_safe_functions.fish"),
      "/state/shared/config/fish/conf.d/container_safe_functions.fish",
      shared_assets_contract.SharedAssetEntryType.FILE,
    ),
    (
      Path(".config/starship.toml"),
      Path(".config/starship.toml"),
      "/state/shared/config/starship.toml",
      shared_assets_contract.SharedAssetEntryType.FILE,
    ),
    (
      Path(".config/zellij/config.kdl"),
      Path(".config/zellij/config.kdl"),
      "/state/shared/config/zellij/config.kdl",
      shared_assets_contract.SharedAssetEntryType.FILE,
    ),
    (
      Path(".config/zellij/layouts"),
      Path(".config/zellij/layouts"),
      "/state/shared/config/zellij/layouts",
      shared_assets_contract.SharedAssetEntryType.DIRECTORY,
    ),
    (
      Path(".local/share/zellij/plugins/zjstatus.wasm"),
      Path(".local/share/zellij/plugins/zjstatus.wasm"),
      "/state/shared/local/share/zellij/plugins/zjstatus.wasm",
      shared_assets_contract.SharedAssetEntryType.FILE,
    ),
    (
      Path(".config/tmux/tmux.conf"),
      Path(".config/tmux/tmux.conf"),
      "/state/shared/config/tmux/tmux.conf",
      shared_assets_contract.SharedAssetEntryType.FILE,
    ),
    (
      Path(".config/tmux/plugins/better-mouse-mode"),
      Path(".config/tmux/plugins/better-mouse-mode"),
      "/state/shared/config/tmux/plugins/better-mouse-mode",
      shared_assets_contract.SharedAssetEntryType.DIRECTORY,
    ),
  }

  actual_terminal_entries = {
    (
      entry.home_relative_path,
      entry.packaged_asset_relative_path,
      entry.runtime_destination,
      entry.entry_type,
    )
    for entry in shared_assets_contract.SHARED_PACKAGED_ASSET_ENTRIES
    if str(entry.home_relative_path).startswith(
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
  assert actual_terminal_entries == expected_terminal_entries


def test_shared_asset_contract_declares_host_override_entries() -> None:
  """Covers shared asset contract declares host override entries."""
  expected_host_override_entries = {
    (
      Path(".agents/skills"),
      "/state/shared/agents/skills",
      shared_assets_contract.SharedAssetEntryType.DIRECTORY,
    ),
    (
      Path(".config/agents/skills"),
      "/state/shared/config/agents/skills",
      shared_assets_contract.SharedAssetEntryType.DIRECTORY,
    ),
    (
      Path(".config/zellij/config.kdl"),
      "/state/shared/config/zellij/config.kdl",
      shared_assets_contract.SharedAssetEntryType.FILE,
    ),
    (
      Path(".config/zellij/layouts"),
      "/state/shared/config/zellij/layouts",
      shared_assets_contract.SharedAssetEntryType.DIRECTORY,
    ),
    (
      Path(".local/share/zellij/plugins/zjstatus.wasm"),
      "/state/shared/local/share/zellij/plugins/zjstatus.wasm",
      shared_assets_contract.SharedAssetEntryType.FILE,
    ),
    (
      Path(".config/tmux/tmux.conf"),
      "/state/shared/config/tmux/tmux.conf",
      shared_assets_contract.SharedAssetEntryType.FILE,
    ),
    (
      Path(".config/tmux/plugins/better-mouse-mode"),
      "/state/shared/config/tmux/plugins/better-mouse-mode",
      shared_assets_contract.SharedAssetEntryType.DIRECTORY,
    ),
  }

  actual_host_override_entries = {
    (
      entry.host_relative_path,
      entry.runtime_destination,
      entry.entry_type,
    )
    for entry in shared_assets_contract.SHARED_HOST_OVERRIDE_ENTRIES
  }

  # Verify the observed behavior matches the contract.
  assert actual_host_override_entries == expected_host_override_entries
