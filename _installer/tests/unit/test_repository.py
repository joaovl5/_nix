# pyright: reportUnusedCallResult=false

import pytest

from coisas.repository import GitForge, RepositoryURI, URIType

_PARSE_CASES: dict[str, tuple[str, URIType, GitForge | None]] = {
    "absolute_path": ("/home/user/my-flake", URIType.LOCAL_PATH, None),
    "relative_dot_path": ("./my-flake", URIType.LOCAL_PATH, None),
    "home_tilde_path": ("~/projects/flake", URIType.LOCAL_PATH, None),
    "github": ("github:user/repo", URIType.GIT_FORGE, GitForge.GITHUB),
    "gitlab": ("gitlab:user/repo", URIType.GIT_FORGE, GitForge.GITLAB),
    "gitea": ("gitea:user/repo", URIType.GIT_FORGE, GitForge.GITEA),
    "git_at": ("git@github.com:user/repo.git", URIType.GIT_URL, None),
    "git_ssh": ("git+ssh://git@github.com/user/repo", URIType.GIT_URL, None),
    "ssh": ("ssh://git@github.com/user/repo", URIType.GIT_URL, None),
    "https": ("https://github.com/user/repo.git", URIType.GIT_URL, None),
    "http": ("http://github.com/user/repo.git", URIType.GIT_URL, None),
}

_PARSE_ERRORS: dict[str, str] = {
    "empty_string": "",
    "unknown_prefix": "ftp://example.com/repo",
}

_NEEDS_CLONE_CASES: dict[str, tuple[str, bool]] = {
    "local_path": ("/home/user/flake", False),
    "github": ("github:user/repo", True),
    "git_url": ("git@github.com:user/repo.git", True),
    "https": ("https://github.com/user/repo.git", True),
}

_GET_URL_CASES: dict[str, tuple[str, str]] = {
    "local_path": ("/home/user/flake", "/home/user/flake"),
    "github": ("github:user/repo", "git@github.com:user/repo.git"),
    "gitlab": ("gitlab:user/repo", "git@gitlab.com:user/repo.git"),
    "git_at": ("git@github.com:user/repo.git", "git@github.com:user/repo.git"),
    "https": ("https://github.com/user/repo.git", "https://github.com/user/repo.git"),
    "tilde_path": ("~/my-flake", "~/my-flake"),
}


@pytest.mark.parametrize(
    "uri_str, expected_type, expected_forge",
    _PARSE_CASES.values(),
    ids=_PARSE_CASES.keys(),
)
def test_parse(uri_str: str, expected_type: URIType, expected_forge: GitForge | None):
    uri = RepositoryURI.parse(uri_str)
    assert uri.type == expected_type
    assert uri.forge == expected_forge


@pytest.mark.parametrize("uri_str", _PARSE_ERRORS.values(), ids=_PARSE_ERRORS.keys())
def test_parse_errors(uri_str: str):
    with pytest.raises(ValueError):
        RepositoryURI.parse(uri_str)


@pytest.mark.parametrize(
    "uri_str, expected",
    _NEEDS_CLONE_CASES.values(),
    ids=_NEEDS_CLONE_CASES.keys(),
)
def test_needs_clone(uri_str: str, expected: bool):
    assert RepositoryURI.parse(uri_str).needs_clone() is expected


@pytest.mark.parametrize(
    "uri_str, expected_url",
    _GET_URL_CASES.values(),
    ids=_GET_URL_CASES.keys(),
)
def test_get_url(uri_str: str, expected_url: str):
    assert RepositoryURI.parse(uri_str).get_url() == expected_url
