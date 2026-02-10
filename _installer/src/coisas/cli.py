import subprocess
import shlex
from shlex import quote as shlex_quote
from pathlib import Path
from typing import Protocol, override
from contextlib import contextmanager

from attrs import define
from rich.console import Console
from rich.live import Live
from rich.panel import Panel
from rich.text import Text


def _ensure_dir(path: Path) -> None:
    """Ensure that a directory exists."""

    if not path.exists():
        path.mkdir(parents=True, exist_ok=True)


class AppendLineFn(Protocol):
    def __call__(self, line: str | Text, style: str | None = None) -> int: ...


class SetFailedFn(Protocol):
    def __call__(self) -> None: ...


class UpdateLineFn(Protocol):
    def __call__(
        self,
        index: int,
        line: str | Text,
        style: str | None = None,
    ) -> None: ...


class PanelWriterLike(Protocol):
    def append_line(self, line: str | Text, style: str | None = None) -> int: ...
    def update_line(
        self,
        index: int,
        line: str | Text,
        style: str | None = None,
    ) -> None: ...
    def set_failed(self) -> None: ...


@define
class PanelWriter:
    append_line: AppendLineFn
    update_line: UpdateLineFn
    set_failed: SetFailedFn


@define
class CLI:
    console: Console

    def info(self, msg: str) -> None:
        """Display an informative message."""
        self.console.print(f"[blue][bold]🛈 :[/bold][/blue] {msg}")

    def _run_command(
        self,
        command: list[str],
    ) -> subprocess.Popen[str]:
        return self._run_local_command(command=command)

    def _run_local_command(
        self,
        command: list[str],
    ) -> subprocess.Popen[str]:
        return subprocess.Popen(
            command,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1,
            universal_newlines=True,
        )

    def _format_panel_line(self, line: str) -> str:
        clean = line.rstrip("\n").replace("\t", "    ")
        return clean

    def _format_status_line(self, line: str, status: str) -> Text:
        width = max(self.console.size.width - 6, 20)
        available = width - len(status) - 1
        left = line
        if len(left) > available:
            if available <= 3:
                left = left[:available]
            else:
                left = left[: available - 3] + "..."
        padding = max(width - len(left) - len(status), 1)
        text = Text()
        text.append(left, style="dim")
        text.append(" " * padding)
        text.append(status, style="green")
        return text

    @contextmanager
    def _panel_session(
        self,
        *,
        title: str,
        prelude: list[str],
    ):
        lines: list[Text] = []
        for line in prelude:
            lines.append(Text(line, style="dim"))

        border_style = "cyan"

        def refresh() -> None:
            text = Text()
            for line in lines:
                text.append(line)
                text.append("\n")
            live.update(Panel(text, title=title, border_style=border_style))

        def append_line(line: str | Text, style: str | None = None) -> int:
            if isinstance(line, Text):
                lines.append(line)
            else:
                lines.append(Text(line, style=style or ""))
            refresh()
            return len(lines) - 1

        def update_line(
            index: int,
            line: str | Text,
            style: str | None = None,
        ) -> None:
            if 0 <= index < len(lines):
                if isinstance(line, Text):
                    lines[index] = line
                else:
                    lines[index] = Text(line, style=style or "")
            refresh()

        def set_failed() -> None:
            nonlocal border_style
            border_style = "red"
            refresh()

        text = Text()
        for line in lines:
            text.append(line)
            text.append("\n")
        panel = Panel(text, title=title, border_style=border_style)
        with Live(
            panel,
            console=self.console,
            refresh_per_second=12,
            transient=False,
        ) as live:
            yield PanelWriter(
                append_line=append_line,
                update_line=update_line,
                set_failed=set_failed,
            )
            refresh()

    def _stream_in_panel(
        self,
        *,
        title: str,
        command_line: str,
        process: subprocess.Popen[str],
        writer: PanelWriterLike | None = None,
    ) -> int:
        if writer is not None:
            command_index = writer.append_line(command_line, style="dim")
            if process.stdout is not None:
                for line in process.stdout:
                    formatted = self._format_panel_line(line)
                    writer.append_line(formatted)
            returncode = process.wait()
            if returncode == 0:
                status_line = self._format_status_line(command_line, "OK")
                writer.update_line(command_index, status_line)
            else:
                writer.append_line(
                    f"Failed with exit code {returncode}",
                    style="red",
                )
                writer.set_failed()
            return returncode

        with self._panel_session(title=title, prelude=[]) as panel_writer:
            command_index = panel_writer.append_line(command_line, style="dim")
            if process.stdout is not None:
                for line in process.stdout:
                    formatted = self._format_panel_line(line)
                    panel_writer.append_line(formatted)

            returncode = process.wait()
            if returncode == 0:
                status_line = self._format_status_line(command_line, "OK")
                panel_writer.update_line(command_index, status_line)
            else:
                panel_writer.append_line(
                    f"Failed with exit code {returncode}",
                    style="red",
                )
                panel_writer.set_failed()

            return returncode

    def run_command(
        self,
        command: list[str],
        description: str,
        writer: PanelWriterLike | None = None,
    ) -> int:
        """Run a shell command and pretty-print the result.

        Returns the command's exit code.
        """

        joint_cmd = " ".join(command)
        panel_title = description
        command_line = f"$ {joint_cmd}"

        try:
            process = self._run_command(command=command)
        except Exception as exc:
            if writer is not None:
                writer.append_line(f"Failed to run command: {exc}", style="red")
                writer.set_failed()
                return 1
            self.console.print(
                Panel(
                    f"Failed to run command: {exc}",
                    title=panel_title,
                    border_style="red",
                )
            )
            return 1

        return self._stream_in_panel(
            title=panel_title,
            command_line=command_line,
            process=process,
            writer=writer,
        )

    def run_local_command(
        self,
        command: list[str],
        description: str,
        writer: PanelWriterLike | None = None,
    ) -> int:
        joint_cmd = " ".join(command)
        panel_title = description
        command_line = f"$ {joint_cmd}"

        try:
            process = self._run_local_command(command=command)
        except Exception as exc:
            if writer is not None:
                writer.append_line(f"Failed to run command: {exc}", style="red")
                writer.set_failed()
                return 1
            self.console.print(
                Panel(
                    f"Failed to run command: {exc}",
                    title=panel_title,
                    border_style="red",
                )
            )
            return 1

        return self._stream_in_panel(
            title=panel_title,
            command_line=command_line,
            process=process,
            writer=writer,
        )

    def chown_recursive(
        self,
        path: Path,
        user: str,
        writer: PanelWriterLike | None = None,
    ) -> None:
        """Recursively change ownership of a path to the given user."""

        _ = self.run_command(
            command=[
                "chown",
                "-R",
                user,
                str(path),
            ],
            description=f"chown -R {user} {path}",
            writer=writer,
        )

    def copy_all(
        self,
        src_dir: Path,
        dest_dir: Path,
        description: str,
        user: str,
        glob: str = "*",
        writer: PanelWriterLike | None = None,
    ) -> None:
        """Copy all files from src_dir into dest_dir, with Rich output.

        Directories inside src_dir are ignored; only regular files are copied.
        Missing source directories are reported and skipped.
        """

        title = description
        prelude = [
            f"From {src_dir} to {dest_dir}",
        ]

        if writer is not None:
            for line in prelude:
                writer.append_line(line, style="dim")
            if not src_dir.is_dir():
                writer.append_line(
                    "Source directory does not exist, skipping.",
                    style="yellow",
                )
                writer.set_failed()
                return

            _ensure_dir(dest_dir)

            copied = 0
            for item in src_dir.glob(glob):
                if item.is_file():
                    target = dest_dir / item.name
                    _ = target.write_bytes(item.read_bytes())
                    writer.append_line(f"Copied {item} -> {target}", style="green")
                    copied += 1

            if copied == 0:
                writer.append_line("No files to copy.", style="yellow")

            self.chown_recursive(
                path=dest_dir,
                user=user,
                writer=writer,
            )
            return

        with self._panel_session(title=title, prelude=prelude) as panel_writer:
            if not src_dir.is_dir():
                panel_writer.append_line(
                    "Source directory does not exist, skipping.",
                    style="yellow",
                )
                panel_writer.set_failed()
                return

            _ensure_dir(dest_dir)

            copied = 0
            for item in src_dir.glob(glob):
                if item.is_file():
                    target = dest_dir / item.name
                    _ = target.write_bytes(item.read_bytes())
                    panel_writer.append_line(
                        f"Copied {item} -> {target}", style="green"
                    )
                    copied += 1

            if copied == 0:
                panel_writer.append_line("No files to copy.", style="yellow")

            self.chown_recursive(
                path=dest_dir,
                user=user,
                writer=panel_writer,
            )


@define
class SshCLI(CLI):
    host: str
    identity: Path
    port: int = 22

    def _ssh_base(self) -> list[str]:
        return [
            "ssh",
            "-i",
            str(self.identity),
            "-p",
            str(self.port),
            self.host,
        ]

    def _rsync_base(self) -> list[str]:
        return [
            "rsync",
            "-a",
            "-e",
            f"ssh -i {shlex_quote(str(self.identity))} -p {self.port}",
        ]

    @override
    def _run_command(
        self,
        command: list[str],
    ) -> subprocess.Popen[str]:
        # Join into a single shell string, but only quote arguments that contain
        # whitespace so globs like id_* still expand on the remote shell.
        # This preserves past behavior for rsync/mv while still handling args
        # like GIT_SSH_COMMAND=ssh -o ... or nix-shell --run "<cmd>".
        parts: list[str] = []
        for arg in command:
            if arg == "" or any(ch.isspace() for ch in arg):
                parts.append(shlex_quote(arg))
            else:
                parts.append(arg)
        remote_cmd = " ".join(parts)
        ssh_command = self._ssh_base() + ["--", remote_cmd]
        return subprocess.Popen(
            ssh_command,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1,
            universal_newlines=True,
        )

    def upload(
        self,
        src_dir: Path,
        dest_dir: str,
        description: str,
        glob: str = "*",
    ) -> int:
        """Upload files from a local directory to a remote destination."""

        title = description
        prelude = [
            f"From {src_dir} to {dest_dir}",
        ]
        with self._panel_session(title=title, prelude=prelude) as panel_writer:
            if not src_dir.is_dir():
                panel_writer.append_line(
                    "Source directory does not exist, skipping.",
                    style="yellow",
                )
                panel_writer.set_failed()
                return 1

            files = [item for item in src_dir.glob(glob) if item.is_file()]
            if not files:
                panel_writer.append_line("No files to upload.", style="yellow")
                return 0

            _ = self.run_command(
                command=["mkdir", "-p", dest_dir],
                description="Ensuring destination directory exists",
                writer=panel_writer,
            )

            rsync_command = self._rsync_base() + [str(item) for item in files]
            rsync_command.append(f"{self.host}:{dest_dir}/")
            return self.run_local_command(
                command=rsync_command,
                description=f"rsync -> {self.host}:{dest_dir}",
                writer=panel_writer,
            )

    def download(
        self,
        src_dir: str,
        dest_dir: Path,
        description: str,
        glob: str = "*",
    ) -> int:
        """Download files from a remote directory to a local destination."""

        title = description
        prelude = [
            f"From {src_dir} to {dest_dir}",
        ]
        with self._panel_session(title=title, prelude=prelude) as panel_writer:
            _ensure_dir(dest_dir)
            panel_writer.append_line(
                "Ensured destination directory exists.", style="dim"
            )

            rsync_command = self._rsync_base()
            rsync_command.extend(
                [
                    "--include",
                    glob,
                    "--exclude",
                    "*",
                    f"{self.host}:{src_dir}/",
                    f"{dest_dir}/",
                ]
            )
            return self.run_local_command(
                command=rsync_command,
                description=f"rsync <- {self.host}:{src_dir}",
                writer=panel_writer,
            )
