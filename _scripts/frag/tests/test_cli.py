from __future__ import annotations

import json
from pathlib import Path
import sys
import tomllib

import subprocess
import pytest

from frag import cli, image_assets, profiles


def _create_shared_assets_tree(shared_assets_dir: Path) -> None:
    for (
        relative_source,
        _destination,
        entry_type,
    ) in cli.image_assets._SHARED_ASSET_MOUNTS:
        asset_path = shared_assets_dir / relative_source
        asset_path.parent.mkdir(parents=True, exist_ok=True)
        if entry_type == "file":
            asset_path.write_text("placeholder\n")
        else:
            asset_path.mkdir(exist_ok=True)


def _create_installed_frag_layout(tmp_path: Path) -> tuple[Path, object]:
    package_root = tmp_path / "nix" / "store" / "frag-0.1.0"
    anchor = (
        package_root
        / "lib"
        / "python3.13"
        / "site-packages"
        / "frag"
        / "image_assets.py"
    )
    anchor.parent.mkdir(parents=True, exist_ok=True)
    anchor.write_text("# anchor\n")

    shared_assets_dir = package_root / "share" / "frag" / "shared-assets"
    _create_shared_assets_tree(shared_assets_dir)

    helpers_dir = package_root / "share" / "frag" / "helpers"
    helpers_dir.mkdir(parents=True)

    catalog_path = package_root / "share" / "frag" / "catalog.json"
    catalog_path.write_text(json.dumps({"images": {}}))

    package_assets = cli.image_assets.resolve_installed_package_assets(anchor)
    return package_root, package_assets


def _repo_root() -> Path | None:
    for parent in Path(__file__).resolve().parents:
        if (parent / "packages" / "default.nix").is_file():
            return parent
    return None


def test_build_image_assets_anchors_resolution_to_invoked_entrypoint(
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: Path,
) -> None:
    package_assets = object()
    captured: list[object] = []

    class FakeDirectProfileImageAssets:
        def __init__(self, *, package_assets: object) -> None:
            captured.append(package_assets)

    wrapper_path = tmp_path / "bin" / "frag"
    wrapper_path.parent.mkdir(parents=True)
    wrapper_path.write_text("#!/bin/sh\n")

    monkeypatch.setattr(
        cli.image_assets, "DirectProfileImageAssets", FakeDirectProfileImageAssets
    )
    monkeypatch.setattr(
        cli.image_assets,
        "resolve_installed_package_assets",
        lambda anchor=None: captured.append(anchor) or package_assets,
    )
    monkeypatch.setattr(sys, "argv", [str(wrapper_path)])

    cli.build_image_assets()

    assert captured == [wrapper_path, package_assets]


def test_build_image_assets_resolves_bare_argv0_via_path(
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: Path,
) -> None:
    package_assets = object()
    captured: list[object] = []

    class FakeDirectProfileImageAssets:
        def __init__(self, *, package_assets: object) -> None:
            captured.append(package_assets)

    resolved_path = tmp_path / "bin" / "frag"
    resolved_path.parent.mkdir(parents=True)
    resolved_path.write_text("#!/bin/sh\n")

    monkeypatch.setattr(
        cli.image_assets, "DirectProfileImageAssets", FakeDirectProfileImageAssets
    )
    monkeypatch.setattr(
        cli.image_assets,
        "resolve_installed_package_assets",
        lambda anchor=None: captured.append(anchor) or package_assets,
    )
    monkeypatch.setattr(cli.shutil, "which", lambda name: str(resolved_path))
    monkeypatch.setattr(sys, "argv", ["frag"])

    cli.build_image_assets()

    assert captured == [resolved_path, package_assets]


def test_resolve_entrypoint_anchor_returns_none_for_missing_path_lookup(
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: Path,
) -> None:
    (tmp_path / "frag").mkdir()
    monkeypatch.chdir(tmp_path)
    monkeypatch.setattr(cli.shutil, "which", lambda name: None)
    monkeypatch.setattr(sys, "argv", ["frag"])

    assert cli._resolve_entrypoint_anchor() is None


def test_build_image_assets_prefers_frag_package_root_env(
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: Path,
) -> None:
    package_assets = object()
    captured: list[object] = []

    class FakeDirectProfileImageAssets:
        def __init__(self, *, package_assets: object) -> None:
            captured.append(package_assets)

    package_root = tmp_path / "nix" / "store" / "frag-0.1.0"
    runtime_entrypoint = package_root / "bin" / "frag"
    runtime_entrypoint.parent.mkdir(parents=True)
    runtime_entrypoint.write_text("#!/bin/sh\n")

    monkeypatch.setattr(
        cli.image_assets, "DirectProfileImageAssets", FakeDirectProfileImageAssets
    )
    monkeypatch.setattr(
        cli.image_assets,
        "resolve_installed_package_assets",
        lambda anchor=None: captured.append(anchor) or package_assets,
    )
    monkeypatch.setenv("FRAG_PACKAGE_ROOT", str(package_root))
    monkeypatch.setattr(sys, "argv", [str(runtime_entrypoint)])

    cli.build_image_assets()

    assert captured == [package_root, package_assets]


def test_build_image_assets_uses_installed_package_assets(
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: Path,
) -> None:
    package_assets = object()
    captured: list[object] = []

    class FakeDirectProfileImageAssets:
        def __init__(self, *, package_assets: object) -> None:
            captured.append(package_assets)

    monkeypatch.setattr(
        cli.image_assets, "DirectProfileImageAssets", FakeDirectProfileImageAssets
    )
    monkeypatch.setattr(
        cli.image_assets,
        "resolve_installed_package_assets",
        lambda anchor=None: package_assets,
    )

    cli.build_image_assets()

    assert captured == [package_assets]


def test_resolve_installed_package_assets_uses_frag_package_layout(
    tmp_path: Path,
) -> None:
    _package_root, package_assets = _create_installed_frag_layout(tmp_path)

    assert (
        package_assets.shared_assets_root
        == tmp_path
        / "nix"
        / "store"
        / "frag-0.1.0"
        / "share"
        / "frag"
        / "shared-assets"
    )
    assert (
        package_assets.catalog_path
        == tmp_path / "nix" / "store" / "frag-0.1.0" / "share" / "frag" / "catalog.json"
    )
    assert (
        package_assets.helpers_dir
        == tmp_path / "nix" / "store" / "frag-0.1.0" / "share" / "frag" / "helpers"
    )


def test_resolve_installed_package_assets_uses_wrapper_path_parents(
    tmp_path: Path,
) -> None:
    outer_root = tmp_path / "nix" / "store" / "frag-wrapper-0.1.0"
    runtime_root = tmp_path / "nix" / "store" / "frag-runtime-0.1.0"
    wrapper_path = outer_root / "bin" / "frag"
    runtime_entrypoint = runtime_root / "bin" / "frag"
    runtime_entrypoint.parent.mkdir(parents=True, exist_ok=True)
    runtime_entrypoint.write_text("#!/bin/sh\n")
    wrapper_path.parent.mkdir(parents=True, exist_ok=True)
    wrapper_path.symlink_to(runtime_entrypoint)

    shared_assets_dir = outer_root / "share" / "frag" / "shared-assets"
    _create_shared_assets_tree(shared_assets_dir)
    helpers_dir = outer_root / "share" / "frag" / "helpers"
    helpers_dir.mkdir(parents=True)
    catalog_path = outer_root / "share" / "frag" / "catalog.json"
    catalog_path.write_text(json.dumps({"images": {}}))

    package_assets = cli.image_assets.resolve_installed_package_assets(wrapper_path)

    assert package_assets.shared_assets_root == shared_assets_dir
    assert package_assets.catalog_path == catalog_path
    assert package_assets.helpers_dir == helpers_dir


def test_resolve_installed_package_assets_requires_share_helper_dir(
    tmp_path: Path,
) -> None:
    anchor = (
        tmp_path
        / "pkg"
        / "lib"
        / "python3.13"
        / "site-packages"
        / "frag"
        / "image_assets.py"
    )
    anchor.parent.mkdir(parents=True, exist_ok=True)
    anchor.write_text("# anchor\n")

    with pytest.raises(
        cli.docker_runtime.DockerRuntimeError,
        match="installed frag assets could not be resolved",
    ):
        cli.image_assets.resolve_installed_package_assets(anchor)


def test_resolve_installed_package_assets_rejects_wrong_shared_asset_types(
    tmp_path: Path,
) -> None:
    package_root, _package_assets = _create_installed_frag_layout(tmp_path)
    wrong_dir = package_root / "share" / "frag" / "shared-assets" / ".agents/skills"
    wrong_dir.rmdir()
    wrong_dir.write_text("not a directory\n")

    with pytest.raises(
        cli.docker_runtime.DockerRuntimeError,
        match=r"required shared assets .*\.agents/skills",
    ):
        cli.image_assets.resolve_installed_package_assets(
            package_root
            / "lib"
            / "python3.13"
            / "site-packages"
            / "frag"
            / "image_assets.py"
        )


def test_load_image_runs_bundled_helper_and_returns_loaded_ref(tmp_path: Path) -> None:
    package_root, package_assets = _create_installed_frag_layout(tmp_path)
    helper_path = package_root / "share" / "frag" / "helpers" / "load-image-main"
    marker_path = tmp_path / "helper-invoked.txt"
    helper_path.write_text(
        "#!/bin/sh\n"
        f"printf 'invoked\\n' > {marker_path}\n"
        "printf 'frag-main:latest\\n'\n"
    )
    helper_path.chmod(0o755)

    package_assets.catalog_path.write_text(
        json.dumps(
            {
                "images": {
                    "main": {
                        "image_ref": "frag-main:latest",
                        "shared_assets_identity": "shared-assets-123",
                        "loader": "load-image-main",
                    }
                }
            }
        )
    )

    provider = cli.image_assets.DirectProfileImageAssets(package_assets=package_assets)
    loaded_image = provider.load_image(
        profile=profiles.Profile(
            name="demo",
            image="main",
            workspace_root="/workspace/demo",
            volume_name="frag-profile-demo",
        )
    )

    assert loaded_image == "frag-main:latest"
    assert marker_path.read_text() == "invoked\n"


def test_load_image_rejects_unknown_catalog_key(tmp_path: Path) -> None:
    _package_root, package_assets = _create_installed_frag_layout(tmp_path)
    provider = cli.image_assets.DirectProfileImageAssets(package_assets=package_assets)

    with pytest.raises(
        cli.docker_runtime.DockerRuntimeError, match="unknown image key"
    ):
        provider.load_image(
            profile=profiles.Profile(
                name="demo",
                image="missing",
                workspace_root="/workspace/demo",
                volume_name="frag-profile-demo",
            )
        )


def test_profile_list_dispatches_to_handler(monkeypatch: pytest.MonkeyPatch) -> None:
    called: list[bool] = []

    monkeypatch.setattr(cli, "handle_profile_list", lambda: called.append(True) or 0)

    result = cli.main(["profile", "list"])

    assert result == 0
    assert called == [True]


def test_profile_new_accepts_optional_arguments(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    captured: dict[str, object] = {}

    def fake_handle_profile_new(
        *, name: str | None, image: str | None, workspace_root: str | None
    ) -> int:
        captured.update(
            name=name,
            image=image,
            workspace_root=workspace_root,
        )
        return 0

    monkeypatch.setattr(cli, "handle_profile_new", fake_handle_profile_new)

    result = cli.main(
        [
            "profile",
            "new",
            "--name",
            "demo",
            "--image",
            "python:3.14",
            "--workspace-root",
            "/tmp/workspace",
        ]
    )

    assert result == 0
    assert captured == {
        "name": "demo",
        "image": "python:3.14",
        "workspace_root": "/tmp/workspace",
    }


def test_handle_profile_new_normalizes_catalog_image_key(
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: Path,
) -> None:
    _package_root, package_assets = _create_installed_frag_layout(tmp_path)
    package_assets.catalog_path.write_text(
        json.dumps(
            {
                "images": {
                    "main": {
                        "image_ref": "frag-main:latest",
                        "shared_assets_identity": "shared-assets-123",
                        "loader": "load-image-main",
                    }
                }
            }
        )
    )
    captured: dict[str, object] = {}

    monkeypatch.setattr(cli, "build_docker_backend", lambda: object())
    monkeypatch.setattr(
        cli,
        "build_image_assets",
        lambda: cli.image_assets.DirectProfileImageAssets(
            package_assets=package_assets
        ),
    )

    def fake_create_profile(
        _docker_backend: object,
        *,
        name: str,
        image: str,
        workspace_root: str,
    ) -> profiles.Profile:
        captured.update(
            name=name,
            image=image,
            workspace_root=workspace_root,
        )
        return profiles.Profile(
            name=name,
            image=image,
            workspace_root=workspace_root,
            volume_name="frag-profile-demo",
        )

    monkeypatch.setattr(cli.profiles, "create_profile", fake_create_profile)

    assert (
        cli.handle_profile_new(
            name="demo",
            image="  main  ",
            workspace_root="/workspace/demo",
        )
        == 0
    )
    assert captured == {
        "name": "demo",
        "image": "main",
        "workspace_root": "/workspace/demo",
    }


def test_profile_new_returns_nonzero_for_unknown_catalog_image_key(
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: Path,
) -> None:
    _package_root, package_assets = _create_installed_frag_layout(tmp_path)
    package_assets.catalog_path.write_text(
        json.dumps(
            {
                "images": {
                    "main": {
                        "image_ref": "frag-main:latest",
                        "shared_assets_identity": "shared-assets-123",
                        "loader": "load-image-main",
                    }
                }
            }
        )
    )

    monkeypatch.setattr(
        cli,
        "build_image_assets",
        lambda: cli.image_assets.DirectProfileImageAssets(
            package_assets=package_assets
        ),
    )
    monkeypatch.setattr(cli, "build_docker_backend", lambda: object())
    monkeypatch.setattr(
        cli.profiles,
        "create_profile",
        lambda *_args, **_kwargs: (_ for _ in ()).throw(
            AssertionError("create_profile should not be called")
        ),
    )
    assert (
        cli.main(
            [
                "profile",
                "new",
                "--name",
                "demo",
                "--image",
                "missing",
                "--workspace-root",
                "/workspace/demo",
            ]
        )
        == 1
    )


def test_frag_package_uses_real_shared_asset_sources() -> None:
    repo_root = _repo_root()
    if repo_root is None:
        pytest.skip(
            "repo packaging files are not available from the packaged source tree"
        )
    package_nix = (repo_root / "packages" / "frag" / "default.nix").read_text()

    assert "users/_modules/ai/_prompts/agents" in package_nix
    assert "users/_modules/ai/_prompts/skills" in package_nix
    assert (
        'cp -r ${../../users/_modules/ai/_prompts/skills} "$shared_root/.agents/skills"'
        in package_nix
    )
    assert (
        'cp -r ${../../users/_modules/ai/_prompts/skills} "$shared_root/.config/agents/skills"'
        in package_nix
    )
    assert "../../.agents/skills" not in package_nix
    assert "users/_modules/ai/_prompts/general/system.md" in package_nix
    assert 'inputs.superpowers + "/skills"' in package_nix
    assert 'inputs.superpowers + "/.opencode/plugins/superpowers.js"' in package_nix
    assert '"$schema" = "https://opencode.ai/config.json";' in package_nix
    assert "plugin = [" in package_nix
    assert '"@gotgenes/opencode-agent-identity"' in package_nix
    assert '"opencode-agent-skills"' in package_nix
    assert (
        'cp ${opencode_json} "$shared_root/.config/opencode/opencode.json"'
        in package_nix
    )
    assert "users/_modules/ai/_prompts/skills/agent-browser/SKILL.md" in package_nix
    assert "Frag bundles installed shared assets under share/frag." not in package_nix
    assert "// frag packaged superpowers bridge" not in package_nix


def test_frag_package_runtime_image_includes_seeded_agent_clis() -> None:
    repo_root = _repo_root()
    if repo_root is None:
        pytest.skip(
            "repo packaging files are not available from the packaged source tree"
        )
    package_nix = (repo_root / "packages" / "frag" / "runtime-system.nix").read_text()

    assert "pkgs.llm-agents.code" in package_nix
    assert "pkgs.llm-agents.omp" in package_nix
    assert "pkgs.llm-agents.agent-browser" in package_nix
    assert "pkgs.llm-agents.opencode" in package_nix
    assert "pkgs.mcp-nixos" in package_nix


def test_frag_package_runtime_image_includes_git() -> None:
    repo_root = _repo_root()
    if repo_root is None:
        pytest.skip(
            "repo packaging files are not available from the packaged source tree"
        )
    package_nix = (repo_root / "packages" / "frag" / "runtime-system.nix").read_text()

    assert "pkgs.git" in package_nix


def test_frag_package_import_requires_inputs() -> None:
    repo_root = _repo_root()
    if repo_root is None:
        pytest.skip(
            "repo packaging files are not available from the packaged source tree"
        )
    packages_nix = (repo_root / "packages" / "default.nix").read_text()

    assert "frag = pkgs.callPackage ./frag {inherit inputs;};" in packages_nix


def test_frag_package_loader_always_reloads_bundled_images() -> None:
    repo_root = _repo_root()
    if repo_root is None:
        pytest.skip(
            "repo packaging files are not available from the packaged source tree"
        )
    package_nix = (repo_root / "packages" / "frag" / "images.nix").read_text()

    assert '"$docker_bin" image rm -f "$image_ref"' in package_nix
    assert '"$docker_bin" import' in package_nix
    assert '"$docker_bin" image inspect "$image_ref"' not in package_nix
    assert '"$docker_bin" load -i' not in package_nix


def test_enter_accepts_optional_profile_and_command_tail(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    captured: dict[str, object] = {}

    def fake_handle_enter(*, profile: str | None, command: tuple[str, ...]) -> int:
        captured.update(profile=profile, command=command)
        return 0

    monkeypatch.setattr(cli, "handle_enter", fake_handle_enter)

    result = cli.main(["enter", "--profile", "demo", "--", "bash", "-lc", "pwd"])

    assert result == 0
    assert captured == {
        "profile": "demo",
        "command": ("bash", "-lc", "pwd"),
    }


def test_invalid_flag_returns_parse_error_code_and_stderr(
    capsys: pytest.CaptureFixture[str],
) -> None:
    assert cli.main(["profile", "list", "--bogus"]) == 2

    captured = capsys.readouterr()
    assert captured.err.strip()
    assert "bogus" in captured.err


def test_enter_missing_profile_prints_actionable_error(
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
) -> None:
    backend = object()
    monkeypatch.setattr(cli, "build_docker_backend", lambda: backend)
    monkeypatch.setattr(
        cli.profiles,
        "get_profile",
        lambda _backend, _name: None,
    )

    assert cli.main(["enter", "--profile", "missing-profile"]) == 1

    captured = capsys.readouterr()
    assert "missing-profile" in captured.err


def test_profile_rm_missing_profile_prints_actionable_error(
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
) -> None:
    backend = object()
    monkeypatch.setattr(cli, "build_docker_backend", lambda: backend)
    monkeypatch.setattr(
        cli.profiles,
        "get_profile",
        lambda _backend, _name: None,
    )

    assert cli.main(["profile", "rm", "missing-profile"]) == 1

    captured = capsys.readouterr()
    assert "missing-profile" in captured.err


def test_profile_stop_missing_profile_prints_actionable_error(
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
) -> None:
    backend = object()
    monkeypatch.setattr(cli, "build_docker_backend", lambda: backend)
    monkeypatch.setattr(
        cli.profiles,
        "get_profile",
        lambda _backend, _name: None,
    )

    assert cli.main(["profile", "stop", "missing-profile"]) == 1

    captured = capsys.readouterr()
    assert "missing-profile" in captured.err


def test_enter_workspace_mismatch_prints_actionable_error(
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
) -> None:
    backend = object()
    demo_profile = profiles.Profile(
        name="demo",
        image="main",
        workspace_root="/workspace/demo",
        volume_name="frag-profile-demo",
    )
    monkeypatch.setattr(cli, "build_docker_backend", lambda: backend)
    monkeypatch.setattr(
        cli.profiles,
        "get_profile",
        lambda _backend, _name: demo_profile,
    )
    monkeypatch.setattr(
        cli.docker_runtime,
        "container_workdir_for_cwd",
        lambda **_kwargs: (_ for _ in ()).throw(
            cli.docker_runtime.WorkspacePathError(
                "Current directory is outside workspace root '/workspace/demo'"
            )
        ),
    )

    assert cli.main(["enter", "--profile", "demo"]) == 1

    captured = capsys.readouterr()
    assert "outside workspace root" in captured.err


def test_enter_cold_start_renders_rich_phase_messages(
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: Path,
    capsys: pytest.CaptureFixture[str],
) -> None:
    workspace_root = tmp_path / "workspace"
    workspace_root.mkdir()
    nested = workspace_root / "nested"
    nested.mkdir()

    runtime_profile = profiles.Profile(
        name="Demo Profile",
        image="main",
        workspace_root=str(workspace_root),
        volume_name="frag-profile-demo-profile",
    )

    monkeypatch.setattr(cli, "build_docker_backend", lambda: object())
    monkeypatch.setattr(
        cli.profiles,
        "get_profile",
        lambda _backend, name: runtime_profile if name == "Demo Profile" else None,
    )
    monkeypatch.setattr(
        cli.docker_runtime,
        "container_workdir_for_cwd",
        lambda **_kwargs: "/workspace/nested",
    )
    monkeypatch.setattr(
        cli.docker_runtime,
        "is_container_running",
        lambda _profile, *, runtime_metadata=None: False,
    )
    runtime_spec = image_assets.RuntimeSpec(
        image_ref="frag-main:deadbeefdeadbeefdeadbeefdeadbeef",
        shared_assets_identity="shared-assets-123",
        shared_mounts=(),
        start_command=("frag-bootstrap",),
    )
    monkeypatch.setattr(cli, "build_image_assets", lambda: object())
    monkeypatch.setattr(
        cli.docker_runtime,
        "resolve_runtime_spec",
        lambda *_args, **_kwargs: runtime_spec,
    )
    monkeypatch.setattr(
        cli.docker_runtime,
        "load_profile_image",
        lambda _profile, _assets: runtime_spec.image_ref,
    )
    monkeypatch.setattr(
        cli.docker_runtime,
        "bootstrap_token_for_profile",
        lambda _profile: "fresh-token-123",
    )
    monkeypatch.setattr(
        cli.docker_runtime,
        "start_profile_container",
        lambda **_kwargs: None,
    )
    monkeypatch.setattr(
        cli.docker_runtime,
        "wait_for_profile_bootstrap",
        lambda **_kwargs: None,
    )
    monkeypatch.setattr(
        cli.docker_runtime,
        "exec_in_profile_container",
        lambda **_kwargs: 0,
    )
    monkeypatch.chdir(nested)

    assert cli.handle_enter(profile="Demo Profile", command=()) == 0

    captured = capsys.readouterr()
    assert captured.out == ""
    assert "Loading runtime image" in captured.err
    assert "Starting container" in captured.err
    assert "Waiting for bootstrap" in captured.err


def test_enter_hot_path_reports_container_reuse(
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: Path,
    capsys: pytest.CaptureFixture[str],
) -> None:
    workspace_root = tmp_path / "workspace"
    workspace_root.mkdir()
    nested = workspace_root / "nested"
    nested.mkdir()

    runtime_profile = profiles.Profile(
        name="Demo Profile",
        image="main",
        workspace_root=str(workspace_root),
        volume_name="frag-profile-demo-profile",
    )

    monkeypatch.setattr(cli, "build_docker_backend", lambda: object())
    monkeypatch.setattr(
        cli.profiles,
        "get_profile",
        lambda _backend, name: runtime_profile if name == "Demo Profile" else None,
    )
    monkeypatch.setattr(
        cli.docker_runtime,
        "container_workdir_for_cwd",
        lambda **_kwargs: "/workspace/nested",
    )
    monkeypatch.setattr(
        cli.docker_runtime,
        "is_container_running",
        lambda _profile, *, runtime_metadata=None: True,
    )
    monkeypatch.setattr(cli, "build_image_assets", lambda: object())
    monkeypatch.setattr(
        cli.docker_runtime,
        "resolve_runtime_spec",
        lambda *_args, **_kwargs: image_assets.RuntimeSpec(
            image_ref="loaded:image",
            shared_assets_identity="shared-assets-123",
            shared_mounts=(),
            start_command=("frag-bootstrap",),
        ),
    )
    monkeypatch.setattr(
        cli.docker_runtime,
        "exec_in_profile_container",
        lambda **_kwargs: 0,
    )
    monkeypatch.chdir(nested)

    assert cli.handle_enter(profile="Demo Profile", command=()) == 0

    captured = capsys.readouterr()
    assert captured.out == ""
    assert "Reusing running container" in captured.err


def test_enter_runtime_failures_still_print_to_stderr(
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
) -> None:
    monkeypatch.setattr(
        cli,
        "handle_enter",
        lambda **_kwargs: (_ for _ in ()).throw(
            cli.docker_runtime.DockerRuntimeError("runtime [exploded]")
        ),
    )

    assert cli.main(["enter", "--profile", "demo"]) == 1

    captured = capsys.readouterr()
    assert captured.out == ""
    assert "runtime [exploded]" in captured.err


def test_enter_legacy_runtime_refusal_uses_legacy_schema_renderer(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    rendered: list[tuple[str, str]] = []

    monkeypatch.setattr(
        cli,
        "handle_enter",
        lambda **_kwargs: (_ for _ in ()).throw(
            cli.docker_runtime.DockerRuntimeError(
                "legacy schema 1 profile container for 'Demo Profile' is not supported; remove it and recreate the profile"
            )
        ),
    )
    monkeypatch.setattr(
        cli.ui,
        "render_legacy_schema_refusal",
        lambda message: rendered.append(("legacy", message)),
    )
    monkeypatch.setattr(
        cli.ui,
        "render_error",
        lambda message: rendered.append(("error", message)),
    )

    assert cli.main(["enter", "--profile", "demo"]) == 1
    assert rendered == [
        (
            "legacy",
            "legacy schema 1 profile container for 'Demo Profile' is not supported; remove it and recreate the profile",
        )
    ]


def test_pyproject_defines_bootstrap_console_entrypoint() -> None:
    pyproject = Path(__file__).resolve().parents[1] / "pyproject.toml"
    scripts = tomllib.loads(pyproject.read_text())["project"]["scripts"]

    assert scripts["frag-bootstrap"] == "frag.bootstrap:main"


def test_profile_new_returns_nonzero_for_invalid_profile_name(
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: Path,
    capsys: pytest.CaptureFixture[str],
) -> None:
    workspace_root = tmp_path / "workspace"
    workspace_root.mkdir()

    class FakeImageAssets:
        def normalize_profile_image(self, *, image: str) -> str:
            return image

    monkeypatch.setattr(cli.prompts, "require_non_blank", lambda value: value)
    monkeypatch.setattr(cli, "build_image_assets", lambda: FakeImageAssets())

    assert (
        cli.main(
            [
                "profile",
                "new",
                "--name=---",
                "--image",
                "python:3.14",
                "--workspace-root",
                str(workspace_root),
            ]
        )
        == 1
    )
    captured = capsys.readouterr()
    assert "Traceback" not in captured.err
    assert (
        "profile name must contain at least one alphanumeric character" in captured.err
    )


def test_profile_new_returns_nonzero_when_docker_command_fails(
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: Path,
    capsys: pytest.CaptureFixture[str],
) -> None:
    error = subprocess.CalledProcessError(
        1,
        ["docker", "volume", "create", "frag-profile-demo"],
        stderr="backend failed",
    )
    workspace_root = tmp_path / "workspace"
    workspace_root.mkdir()

    class FakeImageAssets:
        def normalize_profile_image(self, *, image: str) -> str:
            return image

    monkeypatch.setattr(cli.prompts, "require_non_blank", lambda value: value)
    monkeypatch.setattr(cli, "build_image_assets", lambda: FakeImageAssets())
    monkeypatch.setattr(
        cli.profiles.subprocess,
        "run",
        lambda *_args, **_kwargs: (_ for _ in ()).throw(error),
    )

    assert (
        cli.main(
            [
                "profile",
                "new",
                "--name",
                "demo",
                "--image",
                "python:3.14",
                "--workspace-root",
                str(workspace_root),
            ]
        )
        == 1
    )
    captured = capsys.readouterr()
    assert "backend failed" in captured.err
