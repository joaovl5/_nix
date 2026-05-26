

from attrs import Factory, define

import pytest
from frag import cli, profiles, prompts
from frag.exceptions import LegacySchemaError


@define
class FakeDockerBackend:
  volumes: dict[str, dict[str, str]]
  running_profiles: set[str]
  create_volume_calls: list[tuple[str, dict[str, str]]] = Factory(list)

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
    lambda _profile, *, runtime_metadata=None: True,
  )
  monkeypatch.setattr(cli, "build_image_assets", lambda: object())
  monkeypatch.setattr(
    cli.docker_runtime,
    "resolve_runtime_spec",
    lambda *_args, **_kwargs: type(
      "RuntimeSpec",
      (),
      {
        "image_ref": "loaded:image",
        "shared_assets_identity": "shared-assets-123",
      },
    )(),
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


def _workspace_root(tmp_path, name: str = "demo") -> str:
  workspace_root = tmp_path / name
  workspace_root.mkdir()
  return str(workspace_root)


def test_create_profile_canonicalizes_workspace_root(
  monkeypatch: pytest.MonkeyPatch,
  tmp_path,
) -> None:
  """Covers create profile canonicalizes workspace root."""
  backend = FakeDockerBackend(volumes={}, running_profiles=set())
  workspace = tmp_path / "workspace"
  workspace.mkdir()
  nested = workspace / "nested"
  nested.mkdir()
  project = nested / "../project"
  project.mkdir()
  monkeypatch.chdir(nested)

  profile = profiles.create_profile(
    backend,
    name="Demo Profile",
    image="python:3.14",
    workspace_root="../project",
  )

  expected_root = str(project.resolve())
  # Verify the observed behavior matches the contract.
  assert profile.workspace_root == expected_root
  # Verify the observed behavior matches the contract.
  assert (
    backend.volumes["frag-profile-demo-profile"][
      profiles.LABEL_WORKSPACE_ROOT
    ]
    == expected_root
  )


def test_create_profile_rejects_missing_workspace_root(tmp_path) -> None:
  """Covers create profile rejects missing workspace root."""
  backend = FakeDockerBackend(volumes={}, running_profiles=set())

  with pytest.raises(
    profiles.ProfileError,
    match="workspace root must be an existing directory",
  ):
    profiles.create_profile(
      backend,
      name="Demo Profile",
      image="python:3.14",
      workspace_root=str(tmp_path / "missing"),
    )

  # Verify the observed behavior matches the contract.
  assert backend.create_volume_calls == []


def test_create_profile_rejects_non_directory_workspace_root(
  tmp_path,
) -> None:
  """Covers create profile rejects non directory workspace root."""
  backend = FakeDockerBackend(volumes={}, running_profiles=set())
  workspace_file = tmp_path / "workspace-file"
  workspace_file.write_text("not a directory\n")

  with pytest.raises(
    profiles.ProfileError,
    match="workspace root must be an existing directory",
  ):
    profiles.create_profile(
      backend,
      name="Demo Profile",
      image="python:3.14",
      workspace_root=str(workspace_file),
    )

  # Verify the observed behavior matches the contract.
  assert backend.create_volume_calls == []


def test_create_profile_creates_labeled_volume(tmp_path) -> None:
  """Covers create profile creates labeled volume."""
  backend = FakeDockerBackend(volumes={}, running_profiles=set())

  profile = profiles.create_profile(
    backend,
    name="Demo Profile",
    image="python:3.14",
    workspace_root=_workspace_root(tmp_path),
  )

  # Verify the observed behavior matches the contract.
  assert profile.volume_name == "frag-profile-demo-profile"
  # Verify the observed behavior matches the contract.
  assert backend.volumes == {
    "frag-profile-demo-profile": {
      profiles.LABEL_PROFILE: "Demo Profile",
      profiles.LABEL_IMAGE: "python:3.14",
      profiles.LABEL_WORKSPACE_ROOT: profile.workspace_root,
      profiles.LABEL_SCHEMA_VERSION: profiles.SCHEMA_VERSION,
    }
  }


def test_create_profile_rejects_names_without_alphanumeric_characters(
  tmp_path,
) -> None:
  """Covers create profile rejects names without alphanumeric characters."""
  backend = FakeDockerBackend(volumes={}, running_profiles=set())

  with pytest.raises(
    profiles.ProfileError,
    match="profile name must contain at least one alphanumeric character",
  ):
    profiles.create_profile(
      backend,
      name="---",
      image="python:3.14",
      workspace_root=_workspace_root(tmp_path),
    )

  # Verify the observed behavior matches the contract.
  assert backend.create_volume_calls == []


def test_create_profile_rejects_distinct_names_with_same_normalized_volume(
  tmp_path,
) -> None:
  """Covers create profile rejects distinct names with same normalized volume."""
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
      workspace_root=_workspace_root(tmp_path, "other"),
    )

  # Verify the observed behavior matches the contract.
  assert backend.volumes == {
    "frag-profile-demo-profile": {
      profiles.LABEL_PROFILE: "Demo Profile",
      profiles.LABEL_IMAGE: "python:3.14",
      profiles.LABEL_WORKSPACE_ROOT: "/workspace/demo",
      profiles.LABEL_SCHEMA_VERSION: profiles.SCHEMA_VERSION,
    }
  }


def test_create_profile_rejects_reusing_existing_name_with_different_metadata(
  tmp_path,
) -> None:
  """Covers create profile rejects reusing existing name with different metadata."""
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

  with pytest.raises(
    profiles.ProfileNameCollisionError, match="already exists"
  ):
    profiles.create_profile(
      backend,
      name="Demo Profile",
      image="python:3.15",
      workspace_root=_workspace_root(tmp_path, "other"),
    )

  # Verify the observed behavior matches the contract.
  assert backend.create_volume_calls == []
  # Verify the observed behavior matches the contract.
  assert backend.volumes == {
    "frag-profile-demo-profile": {
      profiles.LABEL_PROFILE: "Demo Profile",
      profiles.LABEL_IMAGE: "python:3.14",
      profiles.LABEL_WORKSPACE_ROOT: "/workspace/demo",
      profiles.LABEL_SCHEMA_VERSION: profiles.SCHEMA_VERSION,
    }
  }


def test_create_profile_is_idempotent_for_matching_existing_metadata(
  tmp_path,
) -> None:
  """Covers create profile is idempotent for matching existing metadata."""
  workspace_root = _workspace_root(tmp_path, "demo")
  backend = FakeDockerBackend(
    volumes={
      "frag-profile-demo-profile": {
        profiles.LABEL_PROFILE: "Demo Profile",
        profiles.LABEL_IMAGE: "python:3.14",
        profiles.LABEL_WORKSPACE_ROOT: workspace_root,
        profiles.LABEL_SCHEMA_VERSION: profiles.SCHEMA_VERSION,
      }
    },
    running_profiles=set(),
  )

  profile = profiles.create_profile(
    backend,
    name="Demo Profile",
    image="python:3.14",
    workspace_root=workspace_root,
  )

  # Verify the observed behavior matches the contract.
  assert profile == profiles.Profile(
    name="Demo Profile",
    image="python:3.14",
    workspace_root=workspace_root,
    volume_name="frag-profile-demo-profile",
  )
  # Verify the observed behavior matches the contract.
  assert backend.create_volume_calls == []


def test_list_profiles_reconstructs_metadata_from_volume_labels() -> None:
  """Covers list profiles reconstructs metadata from volume labels."""
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

  # Verify the observed behavior matches the contract.
  assert listed == [
    profiles.Profile(
      name="demo",
      image="python:3.14",
      workspace_root="/workspace/demo",
      volume_name="frag-profile-demo",
    )
  ]
  # Verify the observed behavior matches the contract.
  assert profiles.get_profile(backend, name="demo") == listed[0]


def test_list_profiles_ignores_unrelated_legacy_schema1_volume() -> None:
  """Covers list profiles ignores unrelated legacy schema1 volume."""
  backend = FakeDockerBackend(
    volumes={
      "frag-profile-demo": {
        profiles.LABEL_PROFILE: "demo",
        profiles.LABEL_IMAGE: "python:3.14",
        profiles.LABEL_WORKSPACE_ROOT: "/workspace/demo",
        profiles.LABEL_SCHEMA_VERSION: profiles.SCHEMA_VERSION,
      },
      "frag-profile-work": {
        profiles.LABEL_PROFILE: "work",
        profiles.LABEL_IMAGE: "python:3.14",
        profiles.LABEL_WORKSPACE_ROOT: "/workspace/work",
        profiles.LABEL_SCHEMA_VERSION: "1",
      },
    },
    running_profiles=set(),
  )

  listed = profiles.list_profiles(backend)

  # Verify the observed behavior matches the contract.
  assert listed == [
    profiles.Profile(
      name="demo",
      image="python:3.14",
      workspace_root="/workspace/demo",
      volume_name="frag-profile-demo",
    )
  ]
  # Verify the observed behavior matches the contract.
  assert profiles.get_profile(backend, name="demo") == listed[0]


def test_get_profile_refuses_legacy_schema1_volume() -> None:
  """Covers get profile refuses legacy schema1 volume."""
  backend = FakeDockerBackend(
    volumes={
      "frag-profile-demo": {
        profiles.LABEL_PROFILE: "demo",
        profiles.LABEL_IMAGE: "python:3.14",
        profiles.LABEL_WORKSPACE_ROOT: "/workspace/demo",
        profiles.LABEL_SCHEMA_VERSION: "1",
      }
    },
    running_profiles=set(),
  )

  with pytest.raises(
    LegacySchemaError,
    match="schema 1 profile volume .*demo.* is not supported",
  ):
    profiles.get_profile(backend, name="demo")


def test_get_profile_raises_typed_legacy_schema_error() -> None:
  """Covers get profile raises typed legacy schema error."""
  backend = FakeDockerBackend(
    volumes={
      "frag-profile-demo": {
        profiles.LABEL_PROFILE: "demo",
        profiles.LABEL_IMAGE: "python:3.14",
        profiles.LABEL_WORKSPACE_ROOT: "/workspace/demo",
        profiles.LABEL_SCHEMA_VERSION: "1",
      }
    },
    running_profiles=set(),
  )

  with pytest.raises(LegacySchemaError) as exc_info:
    profiles.get_profile(backend, name="demo")

  # Verify the observed behavior matches the contract.
  assert "schema 1 profile volume" in str(exc_info.value)


def test_get_profile_skips_malformed_same_name_schema2_volume() -> None:
  """Covers get profile skips malformed same name schema2 volume."""
  backend = FakeDockerBackend(
    volumes={
      "frag-profile-demo-broken": {
        profiles.LABEL_PROFILE: "demo",
        profiles.LABEL_WORKSPACE_ROOT: "/workspace/broken",
        profiles.LABEL_SCHEMA_VERSION: profiles.SCHEMA_VERSION,
      },
      "frag-profile-demo": {
        profiles.LABEL_PROFILE: "demo",
        profiles.LABEL_IMAGE: "python:3.14",
        profiles.LABEL_WORKSPACE_ROOT: "/workspace/demo",
        profiles.LABEL_SCHEMA_VERSION: profiles.SCHEMA_VERSION,
      },
    },
    running_profiles=set(),
  )

  # Verify the observed behavior matches the contract.
  assert profiles.get_profile(backend, name="demo") == profiles.Profile(
    name="demo",
    image="python:3.14",
    workspace_root="/workspace/demo",
    volume_name="frag-profile-demo",
  )


def test_create_profile_refuses_legacy_schema1_name_conflict(
  tmp_path,
) -> None:
  """Covers create profile refuses legacy schema1 name conflict."""
  backend = FakeDockerBackend(
    volumes={
      "frag-profile-demo-profile": {
        profiles.LABEL_PROFILE: "Demo Profile",
        profiles.LABEL_IMAGE: "python:3.14",
        profiles.LABEL_WORKSPACE_ROOT: "/workspace/demo",
        profiles.LABEL_SCHEMA_VERSION: "1",
      }
    },
    running_profiles=set(),
  )

  with pytest.raises(
    LegacySchemaError,
    match="schema 1 profile volume .*Demo Profile.* is not supported",
  ):
    profiles.create_profile(
      backend,
      name="Demo Profile",
      image="python:3.15",
      workspace_root=_workspace_root(tmp_path, "other"),
    )

  # Verify the observed behavior matches the contract.
  assert backend.create_volume_calls == []


def test_remove_profile_refuses_running_profiles() -> None:
  """Covers remove profile refuses running profiles."""
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
    profiles.remove_profile(backend, name="demo")


def test_profile_new_prompts_for_missing_values(
  monkeypatch: pytest.MonkeyPatch,
) -> None:
  """Covers profile new prompts for missing values."""
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

  # Verify the observed behavior matches the contract.
  assert result == 0
  # Verify the observed behavior matches the contract.
  assert prompt_calls == [("python",)]
  # Verify the observed behavior matches the contract.
  assert captured == {
    "docker_backend": backend,
    "name": "demo",
    "image": "python",
    "workspace_root": "/workspace/demo",
  }


def test_profile_new_prompts_with_catalog_image_choices(
  monkeypatch: pytest.MonkeyPatch,
) -> None:
  """Covers profile new prompts with catalog image choices."""
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
  monkeypatch.setattr(
    cli.prompts, "prompt_workspace_root", lambda: "/workspace/demo"
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

  # Verify the observed behavior matches the contract.
  assert cli.main(["profile", "new"]) == 0
  # Verify the observed behavior matches the contract.
  assert prompt_calls == [("main", "cuda")]
  # Verify the observed behavior matches the contract.
  assert captured == {
    "docker_backend": backend,
    "name": "demo",
    "image": "cuda",
    "workspace_root": "/workspace/demo",
  }


def test_required_profile_prompts_reject_blank_text_answers(
  monkeypatch: pytest.MonkeyPatch,
) -> None:
  """Covers required profile prompts reject blank text answers."""
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
  """Covers prompt profile image uses catalog select choices."""
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

  # Verify the observed behavior matches the contract.
  assert prompts.prompt_profile_image(("main", "cuda")) == "cuda"
  # Verify the observed behavior matches the contract.
  assert captured == {
    "message": "Image",
    "choices": ["main", "cuda"],
  }


def test_prompt_profile_image_rejects_cancelled_selection(
  monkeypatch: pytest.MonkeyPatch,
) -> None:
  """Covers prompt profile image rejects cancelled selection."""
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
  """Covers profile new aborts cleanly when prompt answer is whitespace only."""
  backend = FakeDockerBackend(volumes={}, running_profiles=set())

  monkeypatch.setattr(cli, "build_docker_backend", lambda: backend)
  monkeypatch.setattr(cli.prompts, "prompt_profile_name", lambda: "   ")
  monkeypatch.setattr(
    cli.prompts, "prompt_profile_image", lambda _choices: "python"
  )
  monkeypatch.setattr(
    cli.prompts, "prompt_workspace_root", lambda: "/workspace/demo"
  )
  monkeypatch.setattr(
    cli.profiles,
    "create_profile",
    lambda *_args, **_kwargs: pytest.fail(
      "profile creation should not be reached"
    ),
  )

  # Verify the observed behavior matches the contract.
  assert cli.main(["profile", "new"]) == 1


def test_profile_new_aborts_cleanly_when_required_prompt_is_blank(
  monkeypatch: pytest.MonkeyPatch,
) -> None:
  """Covers profile new aborts cleanly when required prompt is blank."""
  backend = FakeDockerBackend(volumes={}, running_profiles=set())

  monkeypatch.setattr(cli, "build_docker_backend", lambda: backend)
  monkeypatch.setattr(cli.prompts, "prompt_profile_name", lambda: "   ")
  monkeypatch.setattr(
    cli.profiles,
    "create_profile",
    lambda *_args, **_kwargs: pytest.fail(
      "profile creation should not be reached"
    ),
  )

  # Verify the observed behavior matches the contract.
  assert cli.main(["profile", "new"]) == 1


def test_profile_new_aborts_cleanly_when_prompt_is_cancelled(
  monkeypatch: pytest.MonkeyPatch,
) -> None:
  """Covers profile new aborts cleanly when prompt is cancelled."""
  backend = FakeDockerBackend(volumes={}, running_profiles=set())
  prompt_aborted = getattr(cli.prompts, "PromptAborted", RuntimeError)

  monkeypatch.setattr(cli, "build_docker_backend", lambda: backend)

  def raise_cancelled() -> str:
    raise prompt_aborted()

  monkeypatch.setattr(cli.prompts, "prompt_profile_name", raise_cancelled)
  monkeypatch.setattr(
    cli.profiles,
    "create_profile",
    lambda *_args, **_kwargs: pytest.fail(
      "profile creation should not be reached"
    ),
  )

  # Verify the observed behavior matches the contract.
  assert cli.main(["profile", "new"]) == 1


def test_enter_without_profile_uses_prompt_helper(
  monkeypatch: pytest.MonkeyPatch,
) -> None:
  """Covers enter without profile uses prompt helper."""
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

  # Verify the observed behavior matches the contract.
  assert result == 0
  # Verify the observed behavior matches the contract.
  assert chosen == [("demo",)]
  # Verify the observed behavior matches the contract.
  assert executed == [("demo", "/workspace-root", ("bash",))]


def test_enter_without_profile_can_choose_create_flow(
  monkeypatch: pytest.MonkeyPatch,
) -> None:
  """Covers enter without profile can choose create flow."""
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
  monkeypatch.setattr(
    cli.prompts, "prompt_profile_image", lambda _choices: "python"
  )
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

  # Verify the observed behavior matches the contract.
  assert cli.main(["enter", "--", "bash"]) == 0
  # Verify the observed behavior matches the contract.
  assert created == ["new-demo"]
  # Verify the observed behavior matches the contract.
  assert executed == [("new-demo", "/workspace-root", ("bash",))]


def test_prompt_enter_profile_action_treats_colliding_label_as_existing(
  monkeypatch: pytest.MonkeyPatch,
) -> None:
  """Covers prompt enter profile action treats colliding label as existing."""
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

  # Verify the observed behavior matches the contract.
  assert prompts.prompt_enter_profile_action(["Create a new profile"]) == (
    "existing",
    "Create a new profile",
  )


def test_enter_without_profile_creates_profile_when_none_exist(
  monkeypatch: pytest.MonkeyPatch,
) -> None:
  """Covers enter without profile creates profile when none exist."""
  backend = FakeDockerBackend(volumes={}, running_profiles=set())
  created: dict[str, object] = {}
  executed = stub_enter_runtime(monkeypatch)

  monkeypatch.setattr(cli, "build_docker_backend", lambda: backend)
  stub_image_assets(monkeypatch)
  monkeypatch.setattr(
    cli.profiles, "list_profiles", lambda _docker_backend: []
  )
  monkeypatch.setattr(cli.prompts, "prompt_profile_name", lambda: "demo")
  monkeypatch.setattr(
    cli.prompts, "prompt_profile_image", lambda _choices: "python"
  )
  monkeypatch.setattr(
    cli.prompts, "prompt_workspace_root", lambda: "/workspace/demo"
  )

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

  # Verify the observed behavior matches the contract.
  assert cli.main(["enter", "--", "bash"]) == 0
  # Verify the observed behavior matches the contract.
  assert created == {
    "docker_backend": backend,
    "name": "demo",
    "image": "python",
    "workspace_root": "/workspace/demo",
  }
  # Verify the observed behavior matches the contract.
  assert executed == [("demo", "/workspace-root", ("bash",))]


def test_profile_list_shows_metadata_and_state(
  monkeypatch: pytest.MonkeyPatch,
  capsys: pytest.CaptureFixture[str],
) -> None:
  """Covers profile list shows metadata and state."""
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

  # Verify the observed behavior matches the contract.
  assert cli.main(["profile", "list"]) == 0
  # Verify the observed behavior matches the contract.
  assert capsys.readouterr().out.splitlines() == [
    "demo\timage=python:3.14\tworkspace_root=/workspace/demo\tvolume=frag-profile-demo\tstate=running"
  ]


def test_profile_rm_refuses_running_profiles_without_prompting(
  monkeypatch: pytest.MonkeyPatch,
) -> None:
  """Covers profile rm refuses running profiles without prompting."""
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

  # Verify the observed behavior matches the contract.
  assert result == 1


def test_docker_cli_backend_wraps_missing_docker_binary(
  monkeypatch: pytest.MonkeyPatch,
) -> None:
  """Covers docker cli backend wraps missing docker binary."""
  backend = profiles.DockerCliBackend()

  def raise_missing_binary(*_args: object, **_kwargs: object) -> object:
    raise FileNotFoundError("docker")

  monkeypatch.setattr(profiles.subprocess, "run", raise_missing_binary)

  with pytest.raises(profiles.DockerBackendError):
    backend.create_volume(name="frag-profile-demo", labels={})


def test_runtime_metadata_labels_round_trip_includes_identity_state() -> None:
  """Covers runtime metadata labels round trip includes identity state."""
  metadata = profiles.RuntimeProfileMetadata(
    image_ref="loaded:image",
    shared_assets_identity="shared-assets-123",
    target_uid="1000",
    target_gid="1001",
    supplementary_gids=(2001, 2002),
  )

  # Verify the observed behavior matches the contract.
  assert profiles.runtime_metadata_labels(metadata) == {
    profiles.LABEL_RUNTIME_IMAGE_REF: "loaded:image",
    profiles.LABEL_SHARED_ASSETS_IDENTITY: "shared-assets-123",
    profiles.LABEL_TARGET_UID: "1000",
    profiles.LABEL_TARGET_GID: "1001",
    profiles.LABEL_TARGET_SUPPLEMENTARY_GIDS: "2001,2002",
  }
  # Verify the observed behavior matches the contract.
  assert (
    profiles.runtime_metadata_from_labels(
      profiles.runtime_metadata_labels(metadata)
    )
    == metadata
  )
