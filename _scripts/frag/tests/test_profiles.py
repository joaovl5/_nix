from __future__ import annotations

from dataclasses import dataclass, field

import pytest

from frag import cli, profiles, prompts


@dataclass
class FakeDockerBackend:
    volumes: dict[str, dict[str, str]]
    running_profiles: set[str]
    create_volume_calls: list[tuple[str, dict[str, str]]] = field(default_factory=list)

    def create_volume(self, name: str, labels: dict[str, str]) -> None:
        self.create_volume_calls.append((name, labels.copy()))
        self.volumes[name] = labels.copy()

    def list_volumes(self) -> list[dict[str, object]]:
        return [
            {
                "name": name,
                "labels": labels.copy(),
            }
            for name, labels in self.volumes.items()
        ]

    def remove_volume(self, name: str) -> None:
        self.volumes.pop(name)

    def is_profile_running(self, profile_name: str) -> bool:
        return profile_name in self.running_profiles


def stub_enter_runtime(
    monkeypatch: pytest.MonkeyPatch,
) -> list[tuple[str, str, tuple[str, ...]]]:
    executed: list[tuple[str, str, tuple[str, ...]]] = []
    monkeypatch.setattr(
        cli.docker_runtime,
        "container_workdir_for_cwd",
        lambda **_kwargs: "/workspace-root",
    )
    monkeypatch.setattr(
        cli.docker_runtime,
        "is_container_running",
        lambda _profile: True,
    )
    monkeypatch.setattr(
        cli.docker_runtime,
        "resolve_runtime_spec",
        lambda *_args, **_kwargs: pytest.fail(
            "container startup should not be reached"
        ),
    )
    monkeypatch.setattr(
        cli.docker_runtime,
        "start_profile_container",
        lambda **_kwargs: pytest.fail("container startup should not be reached"),
    )
    monkeypatch.setattr(
        cli.docker_runtime,
        "exec_in_profile_container",
        lambda *, profile, workdir, command: (
            executed.append((profile.name, workdir, tuple(command))) or 0
        ),
    )
    return executed


def stub_image_assets(
    monkeypatch: pytest.MonkeyPatch,
    *,
    normalize: str | None = None,
) -> None:
    class FakeImageAssets:
        def list_image_keys(self) -> tuple[str, ...]:
            return ("python",)

        def normalize_profile_image(self, *, image: str) -> str:
            return image.strip() if normalize is None else normalize

    monkeypatch.setattr(cli, "build_image_assets", lambda: FakeImageAssets())


def test_create_profile_canonicalizes_workspace_root(
    monkeypatch: pytest.MonkeyPatch,
    tmp_path,
) -> None:
    backend = FakeDockerBackend(volumes={}, running_profiles=set())
    workspace = tmp_path / "workspace"
    workspace.mkdir()
    nested = workspace / "nested"
    nested.mkdir()
    monkeypatch.chdir(nested)

    profile = profiles.create_profile(
        backend,
        name="Demo Profile",
        image="python:3.14",
        workspace_root="../project",
    )

    expected_root = str((nested / "../project").resolve())
    assert profile.workspace_root == expected_root
    assert (
        backend.volumes["frag-profile-demo-profile"][profiles.LABEL_WORKSPACE_ROOT]
        == expected_root
    )


def test_create_profile_creates_labeled_volume() -> None:
    backend = FakeDockerBackend(volumes={}, running_profiles=set())

    profile = profiles.create_profile(
        backend,
        name="Demo Profile",
        image="python:3.14",
        workspace_root="/workspace/demo",
    )

    assert profile.volume_name == "frag-profile-demo-profile"
    assert backend.volumes == {
        "frag-profile-demo-profile": {
            profiles.LABEL_PROFILE: "Demo Profile",
            profiles.LABEL_IMAGE: "python:3.14",
            profiles.LABEL_WORKSPACE_ROOT: "/workspace/demo",
            profiles.LABEL_SCHEMA_VERSION: profiles.SCHEMA_VERSION,
        }
    }


def test_create_profile_rejects_names_without_alphanumeric_characters() -> None:
    backend = FakeDockerBackend(volumes={}, running_profiles=set())

    with pytest.raises(
        profiles.ProfileError,
        match="profile name must contain at least one alphanumeric character",
    ):
        profiles.create_profile(
            backend,
            name="---",
            image="python:3.14",
            workspace_root="/workspace/demo",
        )

    assert backend.create_volume_calls == []


def test_create_profile_rejects_distinct_names_with_same_normalized_volume() -> None:
    backend = FakeDockerBackend(
        volumes={
            "frag-profile-demo-profile": {
                profiles.LABEL_PROFILE: "Demo Profile",
                profiles.LABEL_IMAGE: "python:3.14",
                profiles.LABEL_WORKSPACE_ROOT: "/workspace/demo",
                profiles.LABEL_SCHEMA_VERSION: profiles.SCHEMA_VERSION,
            }
        },
        running_profiles=set(),
    )

    with pytest.raises(profiles.ProfileNameCollisionError):
        profiles.create_profile(
            backend,
            name="Demo_Profile",
            image="python:3.14",
            workspace_root="/workspace/other",
        )

    assert backend.volumes == {
        "frag-profile-demo-profile": {
            profiles.LABEL_PROFILE: "Demo Profile",
            profiles.LABEL_IMAGE: "python:3.14",
            profiles.LABEL_WORKSPACE_ROOT: "/workspace/demo",
            profiles.LABEL_SCHEMA_VERSION: profiles.SCHEMA_VERSION,
        }
    }


def test_create_profile_rejects_reusing_existing_name_with_different_metadata() -> None:
    backend = FakeDockerBackend(
        volumes={
            "frag-profile-demo-profile": {
                profiles.LABEL_PROFILE: "Demo Profile",
                profiles.LABEL_IMAGE: "python:3.14",
                profiles.LABEL_WORKSPACE_ROOT: "/workspace/demo",
                profiles.LABEL_SCHEMA_VERSION: profiles.SCHEMA_VERSION,
            }
        },
        running_profiles=set(),
    )

    with pytest.raises(profiles.ProfileNameCollisionError, match="already exists"):
        profiles.create_profile(
            backend,
            name="Demo Profile",
            image="python:3.15",
            workspace_root="/workspace/other",
        )

    assert backend.create_volume_calls == []
    assert backend.volumes == {
        "frag-profile-demo-profile": {
            profiles.LABEL_PROFILE: "Demo Profile",
            profiles.LABEL_IMAGE: "python:3.14",
            profiles.LABEL_WORKSPACE_ROOT: "/workspace/demo",
            profiles.LABEL_SCHEMA_VERSION: profiles.SCHEMA_VERSION,
        }
    }


def test_create_profile_is_idempotent_for_matching_existing_metadata() -> None:
    backend = FakeDockerBackend(
        volumes={
            "frag-profile-demo-profile": {
                profiles.LABEL_PROFILE: "Demo Profile",
                profiles.LABEL_IMAGE: "python:3.14",
                profiles.LABEL_WORKSPACE_ROOT: "/workspace/demo",
                profiles.LABEL_SCHEMA_VERSION: profiles.SCHEMA_VERSION,
            }
        },
        running_profiles=set(),
    )

    profile = profiles.create_profile(
        backend,
        name="Demo Profile",
        image="python:3.14",
        workspace_root="/workspace/demo",
    )

    assert profile == profiles.Profile(
        name="Demo Profile",
        image="python:3.14",
        workspace_root="/workspace/demo",
        volume_name="frag-profile-demo-profile",
    )
    assert backend.create_volume_calls == []


def test_list_profiles_reconstructs_metadata_from_volume_labels() -> None:
    backend = FakeDockerBackend(
        volumes={
            "frag-profile-demo": {
                profiles.LABEL_PROFILE: "demo",
                profiles.LABEL_IMAGE: "python:3.14",
                profiles.LABEL_WORKSPACE_ROOT: "/workspace/demo",
                profiles.LABEL_SCHEMA_VERSION: profiles.SCHEMA_VERSION,
            }
        },
        running_profiles=set(),
    )

    listed = profiles.list_profiles(backend)

    assert listed == [
        profiles.Profile(
            name="demo",
            image="python:3.14",
            workspace_root="/workspace/demo",
            volume_name="frag-profile-demo",
        )
    ]
    assert profiles.get_profile(backend, "demo") == listed[0]


def test_remove_profile_refuses_running_profiles() -> None:
    backend = FakeDockerBackend(
        volumes={
            "frag-profile-demo": {
                profiles.LABEL_PROFILE: "demo",
                profiles.LABEL_IMAGE: "python:3.14",
                profiles.LABEL_WORKSPACE_ROOT: "/workspace/demo",
                profiles.LABEL_SCHEMA_VERSION: profiles.SCHEMA_VERSION,
            }
        },
        running_profiles={"demo"},
    )

    with pytest.raises(profiles.ProfileInUseError):
        profiles.remove_profile(backend, "demo")


def test_profile_new_prompts_for_missing_values(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    backend = FakeDockerBackend(volumes={}, running_profiles=set())
    captured: dict[str, object] = {}

    prompt_calls: list[tuple[str, ...]] = []

    monkeypatch.setattr(cli, "build_docker_backend", lambda: backend)
    stub_image_assets(monkeypatch)
    monkeypatch.setattr(cli.prompts, "prompt_profile_name", lambda: "demo")
    monkeypatch.setattr(
        cli.prompts,
        "prompt_profile_image",
        lambda image_keys: prompt_calls.append(tuple(image_keys)) or "python",
    )
    monkeypatch.setattr(
        cli.prompts,
        "prompt_workspace_root",
        lambda: "/workspace/demo",
    )

    def fake_create_profile(
        docker_backend: object,
        *,
        name: str,
        image: str,
        workspace_root: str,
    ) -> profiles.Profile:
        captured.update(
            docker_backend=docker_backend,
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

    result = cli.main(["profile", "new"])

    assert result == 0
    assert prompt_calls == [("python",)]
    assert captured == {
        "docker_backend": backend,
        "name": "demo",
        "image": "python",
        "workspace_root": "/workspace/demo",
    }


def test_profile_new_prompts_with_catalog_image_choices(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    backend = FakeDockerBackend(volumes={}, running_profiles=set())
    captured: dict[str, object] = {}
    prompt_calls: list[tuple[str, ...]] = []

    class FakeImageAssets:
        def list_image_keys(self) -> tuple[str, ...]:
            return ("main", "cuda")

        def normalize_profile_image(self, *, image: str) -> str:
            return image.strip()

    monkeypatch.setattr(cli, "build_docker_backend", lambda: backend)
    monkeypatch.setattr(cli, "build_image_assets", lambda: FakeImageAssets())
    monkeypatch.setattr(cli.prompts, "prompt_profile_name", lambda: "demo")
    monkeypatch.setattr(
        cli.prompts,
        "prompt_profile_image",
        lambda image_keys: prompt_calls.append(tuple(image_keys)) or "cuda",
    )
    monkeypatch.setattr(cli.prompts, "prompt_workspace_root", lambda: "/workspace/demo")

    def fake_create_profile(
        docker_backend: object,
        *,
        name: str,
        image: str,
        workspace_root: str,
    ) -> profiles.Profile:
        captured.update(
            docker_backend=docker_backend,
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

    assert cli.main(["profile", "new"]) == 0
    assert prompt_calls == [("main", "cuda")]
    assert captured == {
        "docker_backend": backend,
        "name": "demo",
        "image": "cuda",
        "workspace_root": "/workspace/demo",
    }


def test_required_profile_prompts_reject_blank_text_answers(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    class FakePrompt:
        def __init__(self, answer: object) -> None:
            self.answer = answer

        def ask(self) -> object:
            return self.answer

    monkeypatch.setattr(
        prompts.questionary,
        "text",
        lambda _message: FakePrompt("   "),
    )
    monkeypatch.setattr(
        prompts.questionary,
        "path",
        lambda _message: FakePrompt(""),
    )

    with pytest.raises(prompts.PromptAborted):
        prompts.prompt_profile_name()
    with pytest.raises(prompts.PromptAborted):
        prompts.prompt_workspace_root()


def test_prompt_profile_image_uses_catalog_select_choices(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    captured: dict[str, object] = {}

    class FakePrompt:
        def ask(self) -> object:
            return "cuda"

    monkeypatch.setattr(
        prompts.questionary,
        "select",
        lambda message, choices: (
            captured.update(message=message, choices=list(choices)) or FakePrompt()
        ),
    )

    assert prompts.prompt_profile_image(("main", "cuda")) == "cuda"
    assert captured == {
        "message": "Image",
        "choices": ["main", "cuda"],
    }


def test_prompt_profile_image_rejects_cancelled_selection(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    class FakePrompt:
        def ask(self) -> object:
            return None

    monkeypatch.setattr(
        prompts.questionary,
        "select",
        lambda _message, choices: FakePrompt(),
    )

    with pytest.raises(prompts.PromptAborted):
        prompts.prompt_profile_image(("main",))


def test_profile_new_aborts_cleanly_when_prompt_answer_is_whitespace_only(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    backend = FakeDockerBackend(volumes={}, running_profiles=set())

    monkeypatch.setattr(cli, "build_docker_backend", lambda: backend)
    monkeypatch.setattr(cli.prompts, "prompt_profile_name", lambda: "   ")
    monkeypatch.setattr(cli.prompts, "prompt_profile_image", lambda _choices: "python")
    monkeypatch.setattr(cli.prompts, "prompt_workspace_root", lambda: "/workspace/demo")
    monkeypatch.setattr(
        cli.profiles,
        "create_profile",
        lambda *_args, **_kwargs: pytest.fail("profile creation should not be reached"),
    )

    assert cli.main(["profile", "new"]) == 1


def test_profile_new_aborts_cleanly_when_required_prompt_is_blank(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    backend = FakeDockerBackend(volumes={}, running_profiles=set())

    monkeypatch.setattr(cli, "build_docker_backend", lambda: backend)
    monkeypatch.setattr(cli.prompts, "prompt_profile_name", lambda: "   ")
    monkeypatch.setattr(
        cli.profiles,
        "create_profile",
        lambda *_args, **_kwargs: pytest.fail("profile creation should not be reached"),
    )

    assert cli.main(["profile", "new"]) == 1


def test_profile_new_aborts_cleanly_when_prompt_is_cancelled(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    backend = FakeDockerBackend(volumes={}, running_profiles=set())
    prompt_aborted = getattr(cli.prompts, "PromptAborted", RuntimeError)

    monkeypatch.setattr(cli, "build_docker_backend", lambda: backend)

    def raise_cancelled() -> str:
        raise prompt_aborted()

    monkeypatch.setattr(cli.prompts, "prompt_profile_name", raise_cancelled)
    monkeypatch.setattr(
        cli.profiles,
        "create_profile",
        lambda *_args, **_kwargs: pytest.fail("profile creation should not be reached"),
    )

    assert cli.main(["profile", "new"]) == 1


def test_enter_without_profile_uses_prompt_helper(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    backend = FakeDockerBackend(volumes={}, running_profiles=set())
    chosen: list[tuple[str, ...]] = []
    executed = stub_enter_runtime(monkeypatch)

    monkeypatch.setattr(cli, "build_docker_backend", lambda: backend)
    monkeypatch.setattr(
        cli.profiles,
        "list_profiles",
        lambda docker_backend: [
            profiles.Profile(
                name="demo",
                image="python:3.14",
                workspace_root="/workspace/demo",
                volume_name="frag-profile-demo",
            )
        ],
    )
    monkeypatch.setattr(
        cli.prompts,
        "prompt_enter_profile_action",
        lambda names: chosen.append(tuple(names)) or ("existing", "demo"),
        raising=False,
    )
    monkeypatch.setattr(
        cli.profiles,
        "get_profile",
        lambda _docker_backend, name: profiles.Profile(
            name=name,
            image="python:3.14",
            workspace_root="/workspace/demo",
            volume_name="frag-profile-demo",
        ),
    )

    result = cli.main(["enter", "--", "bash"])

    assert result == 0
    assert chosen == [("demo",)]
    assert executed == [("demo", "/workspace-root", ("bash",))]


def test_enter_without_profile_can_choose_create_flow(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    backend = FakeDockerBackend(volumes={}, running_profiles=set())
    created: list[str] = []
    executed = stub_enter_runtime(monkeypatch)

    monkeypatch.setattr(cli, "build_docker_backend", lambda: backend)
    stub_image_assets(monkeypatch)
    monkeypatch.setattr(
        cli.profiles,
        "list_profiles",
        lambda _docker_backend: [
            profiles.Profile(
                name="demo",
                image="python:3.14",
                workspace_root="/workspace/demo",
                volume_name="frag-profile-demo",
            )
        ],
    )
    monkeypatch.setattr(
        cli.prompts,
        "prompt_enter_profile_action",
        lambda names: ("create", None),
        raising=False,
    )
    monkeypatch.setattr(cli.prompts, "prompt_profile_name", lambda: "new-demo")
    monkeypatch.setattr(cli.prompts, "prompt_profile_image", lambda _choices: "python")
    monkeypatch.setattr(
        cli.prompts, "prompt_workspace_root", lambda: "/workspace/new-demo"
    )
    monkeypatch.setattr(
        cli.profiles,
        "create_profile",
        lambda _docker_backend, **kwargs: (
            created.append(kwargs["name"])
            or profiles.Profile(
                name=kwargs["name"],
                image=kwargs["image"],
                workspace_root=kwargs["workspace_root"],
                volume_name="frag-profile-new-demo",
            )
        ),
    )
    monkeypatch.setattr(
        cli.profiles,
        "get_profile",
        lambda _docker_backend, name: profiles.Profile(
            name=name,
            image="python:3.14",
            workspace_root="/workspace/new-demo",
            volume_name="frag-profile-new-demo",
        ),
    )

    assert cli.main(["enter", "--", "bash"]) == 0
    assert created == ["new-demo"]
    assert executed == [("new-demo", "/workspace-root", ("bash",))]


def test_prompt_enter_profile_action_treats_colliding_label_as_existing(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    class FakePrompt:
        def __init__(self, selected: object) -> None:
            self.selected = selected

        def ask(self) -> object:
            return self.selected

    monkeypatch.setattr(
        prompts.questionary,
        "select",
        lambda _message, choices: FakePrompt(choices[0]),
    )

    assert prompts.prompt_enter_profile_action(["Create a new profile"]) == (
        "existing",
        "Create a new profile",
    )


def test_enter_without_profile_creates_profile_when_none_exist(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    backend = FakeDockerBackend(volumes={}, running_profiles=set())
    created: dict[str, object] = {}
    executed = stub_enter_runtime(monkeypatch)

    monkeypatch.setattr(cli, "build_docker_backend", lambda: backend)
    stub_image_assets(monkeypatch)
    monkeypatch.setattr(cli.profiles, "list_profiles", lambda _docker_backend: [])
    monkeypatch.setattr(cli.prompts, "prompt_profile_name", lambda: "demo")
    monkeypatch.setattr(cli.prompts, "prompt_profile_image", lambda _choices: "python")
    monkeypatch.setattr(cli.prompts, "prompt_workspace_root", lambda: "/workspace/demo")

    def fake_create_profile(
        docker_backend: object,
        *,
        name: str,
        image: str,
        workspace_root: str,
    ) -> profiles.Profile:
        created.update(
            docker_backend=docker_backend,
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
    monkeypatch.setattr(
        cli.profiles,
        "get_profile",
        lambda _docker_backend, name: profiles.Profile(
            name=name,
            image="python:3.14",
            workspace_root="/workspace/demo",
            volume_name="frag-profile-demo",
        ),
    )

    assert cli.main(["enter", "--", "bash"]) == 0
    assert created == {
        "docker_backend": backend,
        "name": "demo",
        "image": "python",
        "workspace_root": "/workspace/demo",
    }
    assert executed == [("demo", "/workspace-root", ("bash",))]


def test_profile_list_shows_metadata_and_state(
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
) -> None:
    backend = FakeDockerBackend(
        volumes={
            "frag-profile-demo": {
                profiles.LABEL_PROFILE: "demo",
                profiles.LABEL_IMAGE: "python:3.14",
                profiles.LABEL_WORKSPACE_ROOT: "/workspace/demo",
                profiles.LABEL_SCHEMA_VERSION: profiles.SCHEMA_VERSION,
            }
        },
        running_profiles={"demo"},
    )

    monkeypatch.setattr(cli, "build_docker_backend", lambda: backend)

    assert cli.main(["profile", "list"]) == 0
    assert capsys.readouterr().out.splitlines() == [
        "demo\timage=python:3.14\tworkspace_root=/workspace/demo\tvolume=frag-profile-demo\tstate=running"
    ]


def test_profile_rm_refuses_running_profiles_without_prompting(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    backend = FakeDockerBackend(volumes={}, running_profiles=set())

    monkeypatch.setattr(cli, "build_docker_backend", lambda: backend)
    monkeypatch.setattr(
        cli.prompts,
        "confirm_profile_removal",
        lambda _name: pytest.fail("confirmation should not be reached"),
    )

    def fake_remove_profile(docker_backend: object, name: str) -> None:
        raise profiles.ProfileInUseError(name)

    monkeypatch.setattr(cli.profiles, "remove_profile", fake_remove_profile)

    result = cli.main(["profile", "rm", "--name", "demo"])

    assert result == 1


def test_docker_cli_backend_wraps_missing_docker_binary(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    backend = profiles.DockerCliBackend()

    def raise_missing_binary(*_args: object, **_kwargs: object) -> object:
        raise FileNotFoundError("docker")

    monkeypatch.setattr(profiles.subprocess, "run", raise_missing_binary)

    with pytest.raises(profiles.DockerBackendError):
        backend.create_volume("frag-profile-demo", labels={})
