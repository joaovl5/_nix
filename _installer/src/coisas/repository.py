"""Repository URI parsing for git forge, SSH, HTTPS, and local paths."""

from enum import Enum

from attrs import define


class URIType(Enum):
  """Categories of repository references accepted by the installer."""

  LOCAL_PATH = "local_path"
  GIT_FORGE = "git_forge"
  GIT_URL = "git_url"


class GitForge(Enum):
  """Supported forge shorthands."""

  GITHUB = "github"
  GITLAB = "gitlab"
  GITEA = "gitea"


_FORGE_HOSTS: dict[GitForge, str] = {
  GitForge.GITHUB: "github.com",
  GitForge.GITLAB: "gitlab.com",
}

_FORGE_PREFIXES: dict[str, GitForge] = {
  "github:": GitForge.GITHUB,
  "gitlab:": GitForge.GITLAB,
  "gitea:": GitForge.GITEA,
}

_GIT_URL_PREFIXES = ("git@", "git+ssh://", "ssh://", "https://", "http://")
_LOCAL_PATH_PREFIXES = ("/", "./", "~/")


@define(frozen=True)
class RepositoryURI:
  """Parse and normalize repository references for installer inputs."""

  raw: str
  type: URIType
  forge: GitForge | None = None

  @classmethod
  def parse(cls, raw: str) -> RepositoryURI:
    """Parse a repository reference into a typed representation."""
    if not raw:
      raise ValueError("Repository URI cannot be empty")

    # local paths
    if any(raw.startswith(p) for p in _LOCAL_PATH_PREFIXES):
      return cls(raw=raw, type=URIType.LOCAL_PATH)

    # git forges
    for prefix, forge in _FORGE_PREFIXES.items():
      if raw.startswith(prefix):
        return cls(raw=raw, type=URIType.GIT_FORGE, forge=forge)

    # git URLs
    if any(raw.startswith(p) for p in _GIT_URL_PREFIXES):
      return cls(raw=raw, type=URIType.GIT_URL)

    raise ValueError(f"Unrecognized repository URI format: {raw!r}")

  def needs_clone(self) -> bool:
    """Return whether the repository must be cloned locally first."""
    return self.type != URIType.LOCAL_PATH

  def get_url(self) -> str:
    """Resolve the repository reference into a cloneable URL or local path."""
    if self.type != URIType.GIT_FORGE:
      return self.raw

    # strip forge prefix to get "user/repo"
    user_repo = self.raw
    for prefix in _FORGE_PREFIXES:
      if self.raw.startswith(prefix):
        user_repo = self.raw[len(prefix) :]
        break

    if self.forge and self.forge in _FORGE_HOSTS:
      host = _FORGE_HOSTS[self.forge]
      return f"git@{host}:{user_repo}.git"

    # for forges without a known host (e.g. gitea), return raw
    return self.raw
