from __future__ import annotations

from pathlib import Path

from frag import image_assets, profiles, runtime_contract


def test_current_runtime_metadata_uses_process_identity(monkeypatch) -> None:
    runtime_spec = image_assets.RuntimeSpec(
        image_ref="loaded:image",
        shared_assets_identity="shared-assets-123",
        shared_mounts=(),
        start_command=("frag-bootstrap",),
    )
    monkeypatch.setattr(runtime_contract.os, "getuid", lambda: 1234)
    monkeypatch.setattr(runtime_contract.os, "getgid", lambda: 5678)
    monkeypatch.setattr(
        runtime_contract.os, "getgroups", lambda: [5678, 2001, 2001, 2002]
    )

    assert runtime_contract.current_runtime_metadata(
        runtime_spec=runtime_spec
    ) == profiles.RuntimeProfileMetadata(
        image_ref="loaded:image",
        shared_assets_identity="shared-assets-123",
        target_uid="1234",
        target_gid="5678",
        supplementary_gids=(2001, 2002),
    )


def test_bootstrap_contract_paths_are_shared_sources_of_truth(tmp_path: Path) -> None:
    state_profile = tmp_path / "profile-state"

    assert runtime_contract.bootstrap_token_path(state_profile) == (
        state_profile / "meta" / "bootstrap-token"
    )
    assert runtime_contract.bootstrap_status_path(state_profile) == (
        state_profile / "meta" / "bootstrap-status.json"
    )
    assert (
        runtime_contract.BOOTSTRAP_TOKEN_CONTAINER_PATH
        == "/state/profile/meta/bootstrap-token"
    )
    assert (
        runtime_contract.BOOTSTRAP_STATUS_CONTAINER_PATH
        == "/state/profile/meta/bootstrap-status.json"
    )


def test_canonical_path_expands_and_resolves_without_requiring_target(
    tmp_path: Path,
) -> None:
    home_dir = tmp_path / "home"
    workspace = home_dir / "workspace"
    workspace.mkdir(parents=True)
    target = runtime_contract.canonical_path(workspace / ".." / "workspace" / "missing")

    assert target == workspace / "missing"
