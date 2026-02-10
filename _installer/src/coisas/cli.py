import subprocess
from shlex import quote as shlex_quote
from pathlib import Path
from typing import Protocol, override
from contextlib import contextmanager

from attrs import define
from rich.console import Console
from rich.live import Live
from rich.panel import Panel
from rich.text import Text


def ensure_dir(path: Path) -> None:
    """Ensure that a directory exists."""

    if not path.exists():
        path.mkdir(parents=True, exist_ok=True)


class AppendFn(Protocol):
    def __call__(self, line: str, style: str | None = None) -> None: ...


class SetFailedFn(Protocol):
    def __call__(self) -> None: ...


class PanelWriterLike(Protocol):
    def append(self, line: str, style: str | None = None) -> None: ...
    def set_failed(self) -> None: ...


@define
class PanelWriter:
    append: AppendFn
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

    @contextmanager
    def _panel_session(
        self,
        *,
        title: str,
        prelude: list[str],
    ):
        text = Text()
        for line in prelude:
            text.append(line + "\n", style="dim")

        border_style = "cyan"

        def refresh() -> None:
            live.update(Panel(text, title=title, border_style=border_style))

        def append(line: str, style: str | None = None) -> None:
            text.append(line + "\n", style=style)
            refresh()

        def set_failed() -> None:
            nonlocal border_style
            border_style = "red"
            refresh()

        panel = Panel(text, title=title, border_style=border_style)
        with Live(
            panel,
            console=self.console,
            refresh_per_second=12,
            transient=False,
        ) as live:
            yield PanelWriter(append=append, set_failed=set_failed)
            refresh()

    def _stream_in_panel(
        self,
        *,
        title: str,
        prelude: list[str],
        process: subprocess.Popen[str],
        writer: PanelWriterLike | None = None,
    ) -> int:
        if writer is not None:
            for line in prelude:
                writer.append(line, style="dim")
            if process.stdout is not None:
                for line in process.stdout:
                    formatted = self._format_panel_line(line)
                    writer.append(formatted)
            returncode = process.wait()
            if returncode == 0:
                writer.append("OK", style="green")
            else:
                writer.append(f"Failed with exit code {returncode}", style="red")
                writer.set_failed()
            return returncode

        with self._panel_session(title=title, prelude=prelude) as panel_writer:
            if process.stdout is not None:
                for line in process.stdout:
                    formatted = self._format_panel_line(line)
                    panel_writer.append(formatted)

            returncode = process.wait()
            if returncode == 0:
                panel_writer.append("OK", style="green")
            else:
                panel_writer.append(
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
        prelude = [
            f"$ {joint_cmd}",
        ]

        try:
            process = self._run_command(command=command)
        except Exception as exc:
            if writer is not None:
                writer.append(f"Failed to run command: {exc}", style="red")
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
            prelude=prelude,
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
        prelude = [
            f"$ {joint_cmd}",
        ]

        try:
            process = self._run_local_command(command=command)
        except Exception as exc:
            if writer is not None:
                writer.append(f"Failed to run command: {exc}", style="red")
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
            prelude=prelude,
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
                writer.append(line, style="dim")
            if not src_dir.is_dir():
                writer.append("Source directory does not exist, skipping.", style="yellow")
                writer.set_failed()
                return

            ensure_dir(dest_dir)

            copied = 0
            for item in src_dir.glob(glob):
                if item.is_file():
                    target = dest_dir / item.name
                    _ = target.write_bytes(item.read_bytes())
                    writer.append(f"Copied {item} -> {target}", style="green")
                    copied += 1

            if copied == 0:
                writer.append("No files to copy.", style="yellow")

            self.chown_recursive(
                path=dest_dir,
                user=user,
                writer=writer,
            )
            return

        with self._panel_session(title=title, prelude=prelude) as panel_writer:
            if not src_dir.is_dir():
                panel_writer.append(
                    "Source directory does not exist, skipping.",
                    style="yellow",
                )
                panel_writer.set_failed()
                return

            ensure_dir(dest_dir)

            copied = 0
            for item in src_dir.glob(glob):
                if item.is_file():
                    target = dest_dir / item.name
                    _ = target.write_bytes(item.read_bytes())
                    panel_writer.append(f"Copied {item} -> {target}", style="green")
                    copied += 1

            if copied == 0:
                panel_writer.append("No files to copy.", style="yellow")

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
        ssh_command = self._ssh_base() + ["--"] + command
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
                panel_writer.append(
                    "Source directory does not exist, skipping.",
                    style="yellow",
                )
                panel_writer.set_failed()
                return 1

            files = [item for item in src_dir.glob(glob) if item.is_file()]
            if not files:
                panel_writer.append("No files to upload.", style="yellow")
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
            ensure_dir(dest_dir)
            panel_writer.append("Ensured destination directory exists.", style="dim")

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
