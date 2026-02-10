import subprocess
from shlex import quote as shlex_quote
from pathlib import Path
from typing import override
from rich.console import Console
from rich import print
from attrs import define
from rich.live import Live
from rich.panel import Panel
from rich.text import Text


def ensure_dir(path: Path) -> None:
    """Ensure that a directory exists."""

    if not path.exists():
        path.mkdir(parents=True, exist_ok=True)


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

    def _stream_in_panel(
        self,
        *,
        title: str,
        prelude: list[str],
        process: subprocess.Popen[str],
    ) -> int:
        text = Text()
        for line in prelude:
            text.append(line + "\n", style="dim")

        border_style = "cyan"
        panel = Panel(text, title=title, border_style=border_style)
        with Live(
            panel,
            console=self.console,
            refresh_per_second=12,
            transient=False,
        ) as live:
            if process.stdout is not None:
                for line in process.stdout:
                    formatted = self._format_panel_line(line)
                    text.append(formatted + "\n")
                    live.update(Panel(text, title=title, border_style=border_style))

            returncode = process.wait()
            if returncode == 0:
                text.append("OK\n", style="green")
            else:
                text.append(
                    f"Failed with exit code {returncode}\n",
                    style="red",
                )
                border_style = "red"
            live.update(Panel(text, title=title, border_style=border_style))

        return returncode

    def run_command(
        self,
        command: list[str],
        description: str,
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
            self.console.print(
                Panel(
                    f"Failed to run command: {exc}",
                    title=panel_title,
                    style="red",
                )
            )
            return 1

        return self._stream_in_panel(
            title=panel_title,
            prelude=prelude,
            process=process,
        )

    def chown_recursive(
        self,
        path: Path,
        user: str,
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
        )

    def copy_all(
        self,
        src_dir: Path,
        dest_dir: Path,
        description: str,
        user: str,
        glob: str = "*",
    ) -> None:
        """Copy all files from src_dir into dest_dir, with Rich output.

        Directories inside src_dir are ignored; only regular files are copied.
        Missing source directories are reported and skipped.
        """

        self.console.rule(f"[bold cyan]{description}")
        self.console.print(
            f"From [magenta]{src_dir}[/magenta] to [magenta]{dest_dir}[/magenta]"
        )

        if not src_dir.is_dir():
            print("[yellow]Source directory does not exist, skipping.[/yellow]")
            return

        ensure_dir(dest_dir)

        copied = 0
        for item in src_dir.glob(glob):
            if item.is_file():
                target = dest_dir / item.name
                _ = target.write_bytes(item.read_bytes())
                self.console.print(f"[green]Copied[/green] {item} -> {target}")
                copied += 1

        if copied == 0:
            self.console.print("[yellow]No files to copy.[/yellow]")

        # Ensure destination is owned by the specified user
        self.chown_recursive(
            path=dest_dir,
            user=user,
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

    def _run_local_command(
        self,
        command: list[str],
    ) -> subprocess.CompletedProcess[bytes]:
        return subprocess.run(command, check=False)

    def _report_local_command(
        self,
        command: list[str],
        description: str,
    ) -> int:
        self.console.rule(f"[bold cyan]{description}")
        self.console.print(f"[bold]$ {' '.join(command)}[/bold]")

        try:
            result = self._run_local_command(command=command)
        except Exception as exc:
            self.console.print(f"[red]Failed to run command:[/red] {exc}")
            return 1

        if result.returncode == 0:
            self.console.print("[green]OK[/green]")
        else:
            self.console.print(
                f"[red]Command failed with code {result.returncode}[/red]"
            )

        return result.returncode

    def upload(
        self,
        src_dir: Path,
        dest_dir: str,
        description: str,
        glob: str = "*",
    ) -> int:
        """Upload files from a local directory to a remote destination."""

        self.console.rule(f"[bold cyan]{description}")
        self.console.print(
            f"From [magenta]{src_dir}[/magenta] to [magenta]{dest_dir}[/magenta]"
        )

        if not src_dir.is_dir():
            print("[yellow]Source directory does not exist, skipping.[/yellow]")
            return 1

        files = [item for item in src_dir.glob(glob) if item.is_file()]
        if not files:
            self.console.print("[yellow]No files to upload.[/yellow]")
            return 0

        _ = self._run_command(
            command=["mkdir", "-p", dest_dir],
        )

        rsync_command = self._rsync_base() + [str(item) for item in files]
        rsync_command.append(f"{self.host}:{dest_dir}/")
        return self._report_local_command(
            command=rsync_command,
            description=f"rsync -> {self.host}:{dest_dir}",
        )

    def download(
        self,
        src_dir: str,
        dest_dir: Path,
        description: str,
        glob: str = "*",
    ) -> int:
        """Download files from a remote directory to a local destination."""

        self.console.rule(f"[bold cyan]{description}")
        self.console.print(
            f"From [magenta]{src_dir}[/magenta] to [magenta]{dest_dir}[/magenta]"
        )

        ensure_dir(dest_dir)

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
        return self._report_local_command(
            command=rsync_command,
            description=f"rsync <- {self.host}:{src_dir}",
        )
