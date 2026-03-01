"""Command protocol and typed implementations for installer commands."""

# pyright: reportUnusedCallResult=false

from __future__ import annotations

from pathlib import Path
from shlex import quote as shlex_quote
from typing import Protocol, overload, runtime_checkable

from attrs import Factory, define
from rich.text import Text

NIX_FLAGS = ["--option", "experimental-features", "nix-command flakes"]


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
    args: list[str] = Factory(lambda: [])
    env: dict[str, str] = Factory(lambda: {})

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
class NixCommand:
    args: list[str]  # e.g. ["flake", "update", "mysecrets", "--flake", path]
    env: dict[str, str] = Factory(lambda: {})

    def render(self) -> Text:
        text = Text()
        if self.env:
            text.append_text(_render_env(self.env))
        text.append("$ ", style="dim")
        text.append("nix", style="bold magenta")
        if self.args:
            text.append(" " + " ".join(self.args), style="dim")
        return text

    def build(self) -> list[str]:
        return _env_prefix(self.env) + ["nix"] + NIX_FLAGS + self.args


@define
class NixRunCommand:
    package: str
    args: list[str] = Factory(lambda: [])
    env: dict[str, str] = Factory(lambda: {})

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
        cmd = _env_prefix(self.env) + ["nix", "run"] + NIX_FLAGS + [self.package]
        if self.args:
            cmd += ["--"] + self.args
        return cmd


@define
class GitCommand:
    args: list[str] = Factory(lambda: [])
    env: dict[str, str] = Factory(lambda: {})
    repo_path: str | None = None
    config: dict[str, str] = Factory(lambda: {})

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
        config_args = [
            arg for k, v in self.config.items() for arg in ["-c", f"{k}={v}"]
        ]
        git = ["git"] + config_args
        if self.repo_path:
            git += ["-C", self.repo_path]
        git += self.args
        return env + git


@define
class GitHelper:
    config: dict[str, str]
    repo_path: str

    def add(self, paths: list[str]) -> GitCommand:
        return GitCommand(
            args=["add", *paths], repo_path=self.repo_path, config=self.config
        )

    def commit(self, msg: str) -> GitCommand:
        return GitCommand(
            args=["commit", "-m", msg], repo_path=self.repo_path, config=self.config
        )

    def push(self, remote: str = "origin", ref: str = "HEAD") -> GitCommand:
        return GitCommand(args=["push", "-u", remote, ref], repo_path=self.repo_path)


@define(frozen=True)
class SSHConfig:
    host: str
    identity: Path
    port: int = 22


def _quote_for_ssh(parts: list[str]) -> str:
    """Join command parts into a remote shell string.

    Quotes arguments containing whitespace with shlex, but leaves
    globs/operators unquoted so they expand on the remote shell.
    """
    result: list[str] = []
    for part in parts:
        if part == "" or any(ch.isspace() for ch in part):
            result.append(shlex_quote(part))
        else:
            result.append(part)
    return " ".join(result)


@define
class SSHCommand:
    inner: Command
    config: SSHConfig

    def render(self) -> Text:
        text = Text()
        text.append(f"[ssh {self.config.host}] ", style="bold yellow")
        text.append_text(self.inner.render())
        return text

    def build(self) -> list[str]:
        inner_parts = self.inner.build()
        remote_str = _quote_for_ssh(inner_parts)
        return [
            "ssh",
            "-i",
            str(self.config.identity),
            "-p",
            str(self.config.port),
            self.config.host,
            "--",
            remote_str,
        ]


@define
class RsyncCommand:
    src: str
    dest: str
    ssh_config: SSHConfig | None = None
    extra_args: list[str] = Factory(lambda: [])
    remote_dest: bool = True

    def render(self) -> Text:
        text = Text()
        if self.ssh_config:
            text.append(f"[ssh {self.ssh_config.host}] ", style="bold yellow")
        text.append("$ ", style="dim")
        text.append("rsync ", style="bold")
        text.append(f"{self.src} -> {self.dest}", style="dim")
        return text

    def build(self) -> list[str]:
        cmd = ["rsync", "-avz"]
        if self.extra_args:
            cmd += self.extra_args
        if self.ssh_config:
            identity = shlex_quote(str(self.ssh_config.identity))
            ssh_cmd = f"ssh -i {identity} -p {self.ssh_config.port}"
            cmd += ["-e", ssh_cmd]
        src = self.src
        dest = self.dest
        if self.ssh_config:
            host = self.ssh_config.host
            if self.remote_dest:
                dest = f"{host}:{dest}"
            else:
                src = f"{host}:{src}"
        cmd += [src, dest]
        return cmd


@define
class SudoCommand:
    inner: Command

    def render(self) -> Text:
        text = Text()
        text.append("sudo ", style="bold red")
        text.append_text(self.inner.render())
        return text

    def build(self) -> list[str]:
        return ["sudo"] + self.inner.build()


class CommandWrapper(Protocol):
    def wrap(self, cmd: Command) -> Command: ...

    @overload
    def __or__(self, other: Command) -> Command: ...
    @overload
    def __or__(self, other: CommandWrapper) -> CommandWrapper: ...
    def __or__(self, other: CommandWrapper | Command) -> CommandWrapper | Command:
        if isinstance(other, Command):
            return self.wrap(other)
        return _ComposedWrapper(outer=self, inner=other)


@define
class _ComposedWrapper:
    outer: CommandWrapper
    inner: CommandWrapper

    def wrap(self, cmd: Command) -> Command:
        return self.outer.wrap(self.inner.wrap(cmd))

    @overload
    def __or__(self, other: Command) -> Command: ...
    @overload
    def __or__(self, other: CommandWrapper) -> CommandWrapper: ...
    def __or__(self, other: CommandWrapper | Command) -> CommandWrapper | Command:
        if isinstance(other, Command):
            return self.wrap(other)
        return _ComposedWrapper(outer=self, inner=other)


@define
class SSHWrapper:
    config: SSHConfig

    def wrap(self, cmd: Command) -> Command:
        return SSHCommand(inner=cmd, config=self.config)

    @overload
    def __or__(self, other: Command) -> Command: ...
    @overload
    def __or__(self, other: CommandWrapper) -> CommandWrapper: ...
    def __or__(self, other: CommandWrapper | Command) -> CommandWrapper | Command:
        if isinstance(other, Command):
            return self.wrap(other)
        return _ComposedWrapper(outer=self, inner=other)


@define
class SudoWrapper:
    def wrap(self, cmd: Command) -> Command:
        return SudoCommand(inner=cmd)

    @overload
    def __or__(self, other: Command) -> Command: ...
    @overload
    def __or__(self, other: CommandWrapper) -> CommandWrapper: ...
    def __or__(self, other: CommandWrapper | Command) -> CommandWrapper | Command:
        if isinstance(other, Command):
            return self.wrap(other)
        return _ComposedWrapper(outer=self, inner=other)


@define
class PassthroughWrapper:
    def wrap(self, cmd: Command) -> Command:
        return cmd

    @overload
    def __or__(self, other: Command) -> Command: ...
    @overload
    def __or__(self, other: CommandWrapper) -> CommandWrapper: ...
    def __or__(self, other: CommandWrapper | Command) -> CommandWrapper | Command:
        if isinstance(other, Command):
            return self.wrap(other)
        return _ComposedWrapper(outer=self, inner=other)
