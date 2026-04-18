from __future__ import annotations

from collections.abc import Callable, Sequence
import os
from pathlib import Path
import shutil
import sys

from cyclopts import App, CycloptsError

from frag import docker_runtime, image_assets, profiles, prompts, ui

app = App(
    name="frag", result_action="return_value", exit_on_error=False, print_error=False
)
profile_app = App(name="profile")
app.command(profile_app)
DEFAULT_SHELL = ("bash",)
_FRAG_PACKAGE_ROOT_ENV = "FRAG_PACKAGE_ROOT"


@profile_app.command(name="list")
def profile_list() -> int:
    return handle_profile_list()


@profile_app.command(name="new")
def profile_new(
    name: str | None = None,
    image: str | None = None,
    workspace_root: str | None = None,
) -> int:
    return handle_profile_new(
        name=name,
        image=image,
        workspace_root=workspace_root,
    )


@profile_app.command(name="rm")
def profile_rm(name: str | None = None) -> int:
    return handle_profile_rm(name=name)


@profile_app.command(name="stop")
def profile_stop(name: str | None = None) -> int:
    return handle_profile_stop(name=name)


@app.command(name="enter")
def enter(*command: str, profile: str | None = None) -> int:
    return handle_enter(profile=profile, command=command)


def build_docker_backend() -> profiles.DockerCliBackend:
    return profiles.DockerCliBackend()


def _resolve_entrypoint_anchor() -> Path | None:
    argv0 = sys.argv[0] if sys.argv else ""
    if not argv0:
        return None

    entrypoint = Path(argv0).expanduser()
    if entrypoint.is_absolute() or entrypoint.parent != Path("."):
        return entrypoint

    resolved_entrypoint = shutil.which(argv0)
    if resolved_entrypoint is None:
        return None

    resolved_path = Path(resolved_entrypoint).expanduser()
    if resolved_path.is_absolute():
        return resolved_path
    return Path.cwd() / resolved_path


def _resolve_package_anchor() -> Path | None:
    package_root = os.environ.get(_FRAG_PACKAGE_ROOT_ENV, "").strip()
    if package_root:
        return Path(package_root).expanduser()
    return _resolve_entrypoint_anchor()


def build_image_assets() -> image_assets.ImageAssets:
    return image_assets.DirectProfileImageAssets(
        package_assets=image_assets.resolve_installed_package_assets(
            _resolve_package_anchor()
        )
    )


def handle_profile_list() -> int:
    docker_backend = build_docker_backend()
    for profile in profiles.list_profiles(docker_backend):
        state = (
            "running" if docker_backend.is_profile_running(profile.name) else "stopped"
        )
        print(
            f"{profile.name}\timage={profile.image}\tworkspace_root={profile.workspace_root}"
            f"\tvolume={profile.volume_name}\tstate={state}"
        )
    return 0


def _resolve_required_value(
    *,
    supplied: str | None,
    prompt: Callable[[], str],
) -> str:
    if supplied is not None:
        return prompts.require_non_blank(supplied)
    return prompts.require_non_blank(prompt())


def _create_profile_interactively(
    docker_backend: profiles.DockerCliBackend,
) -> profiles.Profile:
    image_assets_provider = build_image_assets()
    resolved_name = prompts.prompt_profile_name()
    raw_image = prompts.prompt_profile_image(image_assets_provider.list_image_keys())
    resolved_workspace_root = prompts.prompt_workspace_root()
    return profiles.create_profile(
        docker_backend,
        name=resolved_name,
        image=image_assets_provider.normalize_profile_image(image=raw_image),
        workspace_root=resolved_workspace_root,
    )


def _resolve_selected_profile_name(
    docker_backend: profiles.DockerCliBackend, profile_name: str | None
) -> str | None:
    selected_profile = profile_name
    if selected_profile is None:
        available_names = [
            profile.name for profile in profiles.list_profiles(docker_backend)
        ]
        action, chosen_name = prompts.prompt_enter_profile_action(available_names)
        if action == "create":
            selected_profile = _create_profile_interactively(docker_backend).name
        else:
            selected_profile = chosen_name
    return selected_profile


def handle_profile_new(
    *,
    name: str | None,
    image: str | None,
    workspace_root: str | None,
) -> int:
    docker_backend = build_docker_backend()
    image_assets_provider = build_image_assets()
    try:
        resolved_name = _resolve_required_value(
            supplied=name,
            prompt=prompts.prompt_profile_name,
        )
        resolved_image = _resolve_required_value(
            supplied=image,
            prompt=lambda: prompts.prompt_profile_image(
                image_assets_provider.list_image_keys()
            ),
        )
        resolved_workspace_root = _resolve_required_value(
            supplied=workspace_root,
            prompt=prompts.prompt_workspace_root,
        )
        profiles.create_profile(
            docker_backend,
            name=resolved_name,
            image=image_assets_provider.normalize_profile_image(
                image=resolved_image,
            ),
            workspace_root=resolved_workspace_root,
        )
    except prompts.PromptAborted:
        return 1
    return 0


def handle_profile_rm(*, name: str | None) -> int:
    docker_backend = build_docker_backend()
    resolved_name = name
    if resolved_name is None:
        available_names = [
            profile.name for profile in profiles.list_profiles(docker_backend)
        ]
        resolved_name = prompts.prompt_select_profile(available_names)
        if resolved_name is None:
            return 1
    existing_profile = profiles.get_profile(docker_backend, resolved_name)
    if existing_profile is None:
        raise profiles.ProfileNotFoundError(resolved_name)
    if docker_backend.is_profile_running(existing_profile.name):
        raise profiles.ProfileInUseError(existing_profile.name)
    if not prompts.confirm_profile_removal(resolved_name):
        return 1
    profiles.remove_profile(docker_backend, resolved_name)
    return 0


def handle_profile_stop(*, name: str | None) -> int:
    docker_backend = build_docker_backend()
    resolved_name = name
    if resolved_name is None:
        available_names = [
            profile.name for profile in profiles.list_profiles(docker_backend)
        ]
        resolved_name = prompts.prompt_select_profile(available_names)
        if resolved_name is None:
            return 1
    selected_profile = profiles.get_profile(docker_backend, resolved_name)
    if selected_profile is None:
        raise profiles.ProfileNotFoundError(resolved_name)
    docker_runtime.stop_profile_container(selected_profile)
    return 0


def handle_enter(*, profile: str | None, command: Sequence[str]) -> int:
    docker_backend = build_docker_backend()
    try:
        selected_profile_name = _resolve_selected_profile_name(docker_backend, profile)
    except prompts.PromptAborted:
        return 1
    if selected_profile_name is None:
        ui.render_no_profile_selected()
        return 1

    selected_profile = profiles.get_profile(docker_backend, selected_profile_name)
    if selected_profile is None:
        raise profiles.ProfileNotFoundError(selected_profile_name)

    workspace_root = Path(selected_profile.workspace_root)
    workdir = docker_runtime.container_workdir_for_cwd(
        profile=selected_profile,
        cwd=Path.cwd(),
        workspace_root=workspace_root,
    )

    image_assets_provider = build_image_assets()
    runtime_spec = docker_runtime.resolve_runtime_spec(
        selected_profile,
        workspace_root,
        image_assets_provider,
    )
    runtime_metadata = profiles.RuntimeProfileMetadata(
        image_ref=runtime_spec.image_ref,
        shared_assets_identity=runtime_spec.shared_assets_identity,
        target_uid=str(os.getuid()),
        target_gid=str(os.getgid()),
        supplementary_gids=docker_runtime._current_supplementary_gids(
            primary_gid=os.getgid()
        ),
    )

    if docker_runtime.is_container_running(
        selected_profile,
        runtime_metadata=runtime_metadata,
    ):
        ui.render_status("Reusing running container…")
    else:
        ui.render_status("Loading runtime image…")
        docker_runtime.load_profile_image(selected_profile, image_assets_provider)
        bootstrap_token = docker_runtime.bootstrap_token_for_profile(selected_profile)
        ui.render_status("Starting container…")
        docker_runtime.start_profile_container(
            profile=selected_profile,
            workspace_root=workspace_root,
            runtime_spec=runtime_spec,
            bootstrap_token=bootstrap_token,
        )
        ui.render_status("Waiting for bootstrap…")
        docker_runtime.wait_for_profile_bootstrap(
            profile=selected_profile,
            bootstrap_token=bootstrap_token,
        )
    return docker_runtime.exec_in_profile_container(
        profile=selected_profile,
        workdir=workdir,
        command=tuple(command) or DEFAULT_SHELL,
    )


def _print_cli_error(error: Exception) -> None:
    detail = str(error).strip()
    if not detail:
        return
    if isinstance(error, docker_runtime.WorkspacePathError):
        ui.render_no_workspace(detail)
        return
    if (
        "legacy catalog schema" in detail
        or "legacy schema 1" in detail
        or "shared_assets_identity" in detail
    ):
        ui.render_legacy_schema_refusal(detail)
        return
    ui.render_error(detail)


def main(argv: Sequence[str] | None = None) -> int:
    try:
        result = app(argv)
    except CycloptsError as exc:
        _print_cli_error(exc)
        return 2
    except docker_runtime.DockerRuntimeError as exc:
        _print_cli_error(exc)
        return 1
    except profiles.ProfileError as exc:
        _print_cli_error(exc)
        return 1
    return 0 if result is None else int(result)
