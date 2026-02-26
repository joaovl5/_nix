"""Command protocol and typed implementations for installer commands."""

from __future__ import annotations

from typing import Protocol, runtime_checkable

from attrs import Factory, define
from rich.text import Text

_NIX_RUN = [
    "nix",
    "run",
    "--option",
    "experimental-features",
    "nix-command flakes",
]


@runtime_checkable
class Command(Protocol):
    def render(self) -> Text: ...
    def build(self) -> list[str]: ...


def _render_env(env: dict[str, str]) -> Text:
    """Render environment variables as multi-line header."""
    text = Text()
    for key, value in env.items():
        text.append("  ")
        text.append(key, style="yellow")
        text.append("=", style="dim")
        text.append(value, style="white")
        text.append("\n")
    return text


def _env_prefix(env: dict[str, str]) -> list[str]:
    return ["env", *[f"{k}={v}" for k, v in env.items()]] if env else []


@define
class ShellCommand:
    program: str
    args: list[str] = Factory(list)
    env: dict[str, str] = Factory(dict)

    def render(self) -> Text:
        text = Text()
        if self.env:
            text.append_text(_render_env(self.env))
        text.append("$ ", style="dim")
        text.append(self.program, style="bold")
        if self.args:
            text.append(" " + " ".join(self.args), style="dim")
        return text

    def build(self) -> list[str]:
        return _env_prefix(self.env) + [self.program] + self.args


@define
class NixRunCommand:
    package: str
    args: list[str] = Factory(list)
    env: dict[str, str] = Factory(dict)

    def render(self) -> Text:
        text = Text()
        if self.env:
            text.append_text(_render_env(self.env))
        text.append("$ ", style="dim")
        text.append("nix run ", style="bold magenta")
        text.append(self.package, style="cyan")
        if self.args:
            text.append(" -- ", style="dim")
            text.append(" ".join(self.args), style="dim")
        return text

    def build(self) -> list[str]:
        cmd = _env_prefix(self.env) + _NIX_RUN + [self.package]
        if self.args:
            cmd += ["--"] + self.args
        return cmd


@define
class GitCommand:
    args: list[str] = Factory(list)
    env: dict[str, str] = Factory(dict)
    repo_path: str | None = None

    def render(self) -> Text:
        text = Text()
        if self.env:
            text.append_text(_render_env(self.env))
        text.append("$ ", style="dim")
        text.append("git", style="bold green")
        if self.args:
            text.append(" " + " ".join(self.args), style="dim")
        if self.repo_path:
            text.append(f"  ({self.repo_path})", style="dim italic")
        return text

    def build(self) -> list[str]:
        env = _env_prefix(self.env)
        git = _NIX_RUN + ["nixpkgs#git", "--"] + self.args
        if self.repo_path:
            return ["cd", self.repo_path, "&&"] + env + git
        return env + git


@define
class SudoCommand:
    inner: ShellCommand | NixRunCommand | GitCommand

    def render(self) -> Text:
        text = Text()
        text.append("sudo ", style="bold red")
        text.append_text(self.inner.render())
        return text

    def build(self) -> list[str]:
        return ["sudo"] + self.inner.build()
