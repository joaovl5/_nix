from __future__ import annotations

from dataclasses import dataclass
from enum import StrEnum
from pathlib import Path

_STATE_SHARED_DESTINATION_PREFIX = "/state/shared/"


class SharedAssetEntryType(StrEnum):
    DIRECTORY = "directory"
    FILE = "file"


@dataclass(frozen=True)
class SharedPackagedAssetEntry:
    home_relative_path: Path
    packaged_asset_relative_path: Path
    runtime_destination: str
    entry_type: SharedAssetEntryType

    @property
    def state_shared_relative_path(self) -> Path:
        if not self.runtime_destination.startswith(_STATE_SHARED_DESTINATION_PREFIX):
            raise ValueError(
                "shared asset runtime destinations must stay under /state/shared/"
            )
        return Path(
            self.runtime_destination.removeprefix(_STATE_SHARED_DESTINATION_PREFIX)
        )


@dataclass(frozen=True)
class SharedHostOverrideEntry:
    host_relative_path: Path
    runtime_destination: str
    entry_type: SharedAssetEntryType


SHARED_PACKAGED_ASSET_ENTRIES: tuple[SharedPackagedAssetEntry, ...] = (
    SharedPackagedAssetEntry(
        home_relative_path=Path(".agents/skills"),
        packaged_asset_relative_path=Path(".agents/skills"),
        runtime_destination="/state/shared/agents/skills",
        entry_type=SharedAssetEntryType.DIRECTORY,
    ),
    SharedPackagedAssetEntry(
        home_relative_path=Path(".config/agents/skills"),
        packaged_asset_relative_path=Path(".config/agents/skills"),
        runtime_destination="/state/shared/config/agents/skills",
        entry_type=SharedAssetEntryType.DIRECTORY,
    ),
    SharedPackagedAssetEntry(
        home_relative_path=Path(".code/agents"),
        packaged_asset_relative_path=Path(".code/agents"),
        runtime_destination="/state/shared/code/agents",
        entry_type=SharedAssetEntryType.DIRECTORY,
    ),
    SharedPackagedAssetEntry(
        home_relative_path=Path(".code/skills"),
        packaged_asset_relative_path=Path(".code/skills"),
        runtime_destination="/state/shared/code/skills",
        entry_type=SharedAssetEntryType.DIRECTORY,
    ),
    SharedPackagedAssetEntry(
        home_relative_path=Path(".code/AGENTS.md"),
        packaged_asset_relative_path=Path(".code/AGENTS.md"),
        runtime_destination="/state/shared/code/AGENTS.md",
        entry_type=SharedAssetEntryType.FILE,
    ),
    SharedPackagedAssetEntry(
        home_relative_path=Path(".omp/agent/agents"),
        packaged_asset_relative_path=Path(".omp/agent/agents"),
        runtime_destination="/state/shared/omp/agent/agents",
        entry_type=SharedAssetEntryType.DIRECTORY,
    ),
    SharedPackagedAssetEntry(
        home_relative_path=Path(".omp/agent/skills"),
        packaged_asset_relative_path=Path(".omp/agent/skills"),
        runtime_destination="/state/shared/omp/agent/skills",
        entry_type=SharedAssetEntryType.DIRECTORY,
    ),
    SharedPackagedAssetEntry(
        home_relative_path=Path(".omp/agent/SYSTEM.md"),
        packaged_asset_relative_path=Path(".omp/agent/SYSTEM.md"),
        runtime_destination="/state/shared/omp/agent/SYSTEM.md",
        entry_type=SharedAssetEntryType.FILE,
    ),
    SharedPackagedAssetEntry(
        home_relative_path=Path(".config/opencode/skill"),
        packaged_asset_relative_path=Path(".config/opencode/skill"),
        runtime_destination="/state/shared/opencode/skill",
        entry_type=SharedAssetEntryType.DIRECTORY,
    ),
    SharedPackagedAssetEntry(
        home_relative_path=Path(".config/opencode/opencode.json"),
        packaged_asset_relative_path=Path(".config/opencode/opencode.json"),
        runtime_destination="/state/shared/opencode/opencode.json",
        entry_type=SharedAssetEntryType.FILE,
    ),
    SharedPackagedAssetEntry(
        home_relative_path=Path(".config/opencode/superpowers"),
        packaged_asset_relative_path=Path(".config/opencode/superpowers"),
        runtime_destination="/state/shared/opencode/superpowers",
        entry_type=SharedAssetEntryType.DIRECTORY,
    ),
    SharedPackagedAssetEntry(
        home_relative_path=Path(".config/opencode/plugins/superpowers.js"),
        packaged_asset_relative_path=Path(".config/opencode/plugins/superpowers.js"),
        runtime_destination="/state/shared/opencode/plugins/superpowers.js",
        entry_type=SharedAssetEntryType.FILE,
    ),
    SharedPackagedAssetEntry(
        home_relative_path=Path(".config/fish/conf.d/frag_init.fish"),
        packaged_asset_relative_path=Path(".config/fish/conf.d/frag_init.fish"),
        runtime_destination="/state/shared/config/fish/conf.d/frag_init.fish",
        entry_type=SharedAssetEntryType.FILE,
    ),
    SharedPackagedAssetEntry(
        home_relative_path=Path(".config/fish/conf.d/container_safe_vars.fish"),
        packaged_asset_relative_path=Path(
            ".config/fish/conf.d/container_safe_vars.fish"
        ),
        runtime_destination="/state/shared/config/fish/conf.d/container_safe_vars.fish",
        entry_type=SharedAssetEntryType.FILE,
    ),
    SharedPackagedAssetEntry(
        home_relative_path=Path(".config/fish/conf.d/container_safe_functions.fish"),
        packaged_asset_relative_path=Path(
            ".config/fish/conf.d/container_safe_functions.fish"
        ),
        runtime_destination="/state/shared/config/fish/conf.d/container_safe_functions.fish",
        entry_type=SharedAssetEntryType.FILE,
    ),
    SharedPackagedAssetEntry(
        home_relative_path=Path(".config/starship.toml"),
        packaged_asset_relative_path=Path(".config/starship.toml"),
        runtime_destination="/state/shared/config/starship.toml",
        entry_type=SharedAssetEntryType.FILE,
    ),
    SharedPackagedAssetEntry(
        home_relative_path=Path(".config/zellij/config.kdl"),
        packaged_asset_relative_path=Path(".config/zellij/config.kdl"),
        runtime_destination="/state/shared/config/zellij/config.kdl",
        entry_type=SharedAssetEntryType.FILE,
    ),
    SharedPackagedAssetEntry(
        home_relative_path=Path(".config/zellij/layouts"),
        packaged_asset_relative_path=Path(".config/zellij/layouts"),
        runtime_destination="/state/shared/config/zellij/layouts",
        entry_type=SharedAssetEntryType.DIRECTORY,
    ),
    SharedPackagedAssetEntry(
        home_relative_path=Path(".local/share/zellij/plugins/zjstatus.wasm"),
        packaged_asset_relative_path=Path(".local/share/zellij/plugins/zjstatus.wasm"),
        runtime_destination="/state/shared/local/share/zellij/plugins/zjstatus.wasm",
        entry_type=SharedAssetEntryType.FILE,
    ),
    SharedPackagedAssetEntry(
        home_relative_path=Path(".config/tmux/tmux.conf"),
        packaged_asset_relative_path=Path(".config/tmux/tmux.conf"),
        runtime_destination="/state/shared/config/tmux/tmux.conf",
        entry_type=SharedAssetEntryType.FILE,
    ),
    SharedPackagedAssetEntry(
        home_relative_path=Path(".config/tmux/plugins/better-mouse-mode"),
        packaged_asset_relative_path=Path(".config/tmux/plugins/better-mouse-mode"),
        runtime_destination="/state/shared/config/tmux/plugins/better-mouse-mode",
        entry_type=SharedAssetEntryType.DIRECTORY,
    ),
)

SHARED_HOST_OVERRIDE_ENTRIES: tuple[SharedHostOverrideEntry, ...] = (
    SharedHostOverrideEntry(
        host_relative_path=Path(".agents/skills"),
        runtime_destination="/state/shared/agents/skills",
        entry_type=SharedAssetEntryType.DIRECTORY,
    ),
    SharedHostOverrideEntry(
        host_relative_path=Path(".config/agents/skills"),
        runtime_destination="/state/shared/config/agents/skills",
        entry_type=SharedAssetEntryType.DIRECTORY,
    ),
    SharedHostOverrideEntry(
        host_relative_path=Path(".config/zellij/config.kdl"),
        runtime_destination="/state/shared/config/zellij/config.kdl",
        entry_type=SharedAssetEntryType.FILE,
    ),
    SharedHostOverrideEntry(
        host_relative_path=Path(".config/zellij/layouts"),
        runtime_destination="/state/shared/config/zellij/layouts",
        entry_type=SharedAssetEntryType.DIRECTORY,
    ),
    SharedHostOverrideEntry(
        host_relative_path=Path(".local/share/zellij/plugins/zjstatus.wasm"),
        runtime_destination="/state/shared/local/share/zellij/plugins/zjstatus.wasm",
        entry_type=SharedAssetEntryType.FILE,
    ),
    SharedHostOverrideEntry(
        host_relative_path=Path(".config/tmux/tmux.conf"),
        runtime_destination="/state/shared/config/tmux/tmux.conf",
        entry_type=SharedAssetEntryType.FILE,
    ),
    SharedHostOverrideEntry(
        host_relative_path=Path(".config/tmux/plugins/better-mouse-mode"),
        runtime_destination="/state/shared/config/tmux/plugins/better-mouse-mode",
        entry_type=SharedAssetEntryType.DIRECTORY,
    ),
)


def shared_home_view_mappings() -> tuple[tuple[Path, Path], ...]:
    return tuple(
        (entry.home_relative_path, entry.state_shared_relative_path)
        for entry in SHARED_PACKAGED_ASSET_ENTRIES
    )


def shared_runtime_mount_specs() -> tuple[tuple[str, str, str], ...]:
    return tuple(
        (
            str(entry.packaged_asset_relative_path),
            entry.runtime_destination,
            entry.entry_type.value,
        )
        for entry in SHARED_PACKAGED_ASSET_ENTRIES
    )


def shared_host_override_specs() -> tuple[tuple[Path, str, str], ...]:
    return tuple(
        (
            entry.host_relative_path,
            entry.runtime_destination,
            entry.entry_type.value,
        )
        for entry in SHARED_HOST_OVERRIDE_ENTRIES
    )
