import re
import secrets
import shutil
import subprocess
from collections.abc import Callable
from pathlib import Path
from typing import Self

from attrs import define

from frag import docker_runtime, profiles

CleanupCallback = Callable[[], None]
_VERIFICATION_NAMESPACE = "frag-verify"


@define(frozen=True)
class VerificationArtifacts:
  """Describe the isolated resources created for verification runs."""

  label: str
  profile_name: str
  workspace_path: Path


@define(frozen=True)
class CleanupAction:
  """Capture a cleanup step and the callback that performs it."""

  label: str
  callback: CleanupCallback


class CleanupHarness:
  """Run registered cleanup actions in reverse order, even on failure."""

  def __init__(self) -> None:
    self._actions: list[CleanupAction] = []

  def register(self, *, label: str, callback: CleanupCallback) -> None:
    """Register a cleanup action that should run during teardown."""
    self._actions.append(CleanupAction(label=label, callback=callback))

  def run_cleanup(self) -> None:
    """Run every registered cleanup action and re-raise the first real error."""
    first_error: BaseException | None = None
    for action in reversed(self._actions):
      try:
        action.callback()
      except BaseException as exc:  # pragma: no cover - re-raised below
        if _is_missing_cleanup_error(exc):
          continue
        if first_error is None:
          first_error = exc
    self._actions.clear()
    if first_error is not None:
      raise first_error

  def __enter__(self) -> Self:
    """Return the active cleanup harness for context-manager use."""
    return self

  def __exit__(
    self, exc_type: object, exc: BaseException | None, _tb: object
  ) -> bool:
    """Run registered cleanup actions when leaving the context manager."""

    try:
      self.run_cleanup()
    except BaseException as cleanup_error:
      if exc is not None:
        exc.add_note(f"cleanup failed: {cleanup_error}")
        return False
      raise
    return False


def create_verification_artifacts(
  *,
  purpose: str,
  workspace_root: Path | str,
  token_factory: Callable[[], str] | None = None,
) -> VerificationArtifacts:
  """Create deterministic names for verification resources."""
  token = _normalize_slug((token_factory or _default_token_factory)())
  purpose_slug = _normalize_slug(purpose)
  label = f"{_VERIFICATION_NAMESPACE}-{purpose_slug}-{token}"
  return VerificationArtifacts(
    label=label,
    profile_name=label,
    workspace_path=Path(workspace_root) / label,
  )


def remove_profile_if_present(
  *, docker_backend: profiles.DockerBackend, profile_name: str
) -> None:
  """Remove a profile while tolerating a single transient volume race."""
  for attempt in range(2):
    try:
      profiles.remove_profile(
        docker_backend=docker_backend,
        name=profile_name,
      )
      return
    except profiles.DockerBackendError as error:
      if attempt == 0 and _is_transient_volume_in_use_cleanup_error(
        profile_name=profile_name,
        error=error,
      ):
        continue
      raise


def stop_profile_container_if_present(*, profile_name: str) -> None:
  """Stop a profile container and surface docker failures to callers."""
  command = [
    "docker",
    "stop",
    docker_runtime.container_name_for_profile(profile_name),
  ]
  result = subprocess.run(command, capture_output=True, text=True)
  if result.returncode != 0:
    raise subprocess.CalledProcessError(
      result.returncode,
      command,
      output=result.stdout,
      stderr=result.stderr,
    )


def remove_workspace_if_present(*, workspace_path: Path | str) -> None:
  """Remove a verification workspace when it still exists."""
  try:
    shutil.rmtree(Path(workspace_path))
  except FileNotFoundError:
    return


def _default_token_factory() -> str:
  return secrets.token_hex(4)


def _normalize_slug(value: str) -> str:
  normalized = re.sub(r"[^a-z0-9]+", "-", value.strip().lower()).strip("-")
  if normalized:
    return normalized
  return "run"


def _is_transient_volume_in_use_cleanup_error(
  *, profile_name: str, error: profiles.DockerBackendError
) -> bool:
  detail = str(error).lower()
  return (
    profiles.volume_name_for_profile(profile_name).lower() in detail
    and "volume is in use" in detail
  )


def _is_missing_cleanup_error(error: BaseException) -> bool:
  if isinstance(error, profiles.ProfileNotFoundError):
    return True
  if isinstance(
    error, (docker_runtime.DockerRuntimeError, profiles.DockerBackendError)
  ):
    return _message_indicates_missing_resource(str(error))
  if isinstance(error, subprocess.CalledProcessError):
    detail = "\n".join(
      part for part in (error.stderr, error.output, str(error)) if part
    )
    return _message_indicates_missing_resource(detail)
  return False


def _message_indicates_missing_resource(detail: str) -> bool:
  lowered = detail.lower()
  return any(
    phrase in lowered
    for phrase in (
      "no such container",
      "no such volume",
      "no such file or directory",
      "cannot find the path specified",
    )
  )
