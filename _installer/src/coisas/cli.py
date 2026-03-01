# pyright: reportUnusedCallResult=false

import subprocess
from contextlib import contextmanager
from typing import Protocol

from attrs import define
from rich.box import ASCII, ROUNDED
from rich.console import Console
from rich.live import Live
from rich.panel import Panel
from rich.text import Text

from coisas.command import Command


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
    error_cls: type[Exception] = RuntimeError

    def info(self, msg: str) -> None:
        """Display an informative message."""
        self.console.print(f"[blue][bold]🛈 :[/bold][/blue] {msg}")

    def _format_panel_line(self, line: str) -> str:
        clean = line.rstrip("\n").replace("\t", "    ")
        return clean

    def _format_status_line(
        self, line: str | Text, status: str, failed: bool = False
    ) -> Text:
        text = Text()
        style = "red bold" if failed else "green"
        text.append(f"{status} ", style=style)
        if isinstance(line, Text):
            text.append_text(line)
        else:
            text.append(line, style="dim")
        return text

    @contextmanager
    def panel_session(
        self,
        *,
        title: str,
        prelude: list[str],
        max_lines: int | None = None,
    ):
        lines: list[Text] = []
        for line in prelude:
            lines.append(Text(line, style="dim"))

        if max_lines is None:
            max_lines = min(self.console.size.height // 2, 30)
        effective_max: int = max_lines

        current_box = ASCII
        border_style = "dim"
        show_all = False
        failed = False

        def refresh() -> None:
            text = Text()
            visible = lines
            if not show_all and len(lines) > effective_max:
                hidden = len(lines) - effective_max
                text.append(f"... ({hidden} more lines above)\n", style="dim italic")
                visible = lines[-effective_max:]
            for line in visible:
                text.append(line)
                text.append("\n")
            live.update(
                Panel(text, title=title, border_style=border_style, box=current_box)
            )

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
            nonlocal border_style, show_all, current_box, failed
            failed = True
            current_box = ROUNDED
            border_style = "red"
            show_all = True
            refresh()

        text = Text()
        for line in lines:
            text.append(line)
            text.append("\n")
        panel = Panel(text, title=title, border_style=border_style, box=current_box)
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
            if not failed:
                current_box = ROUNDED
                border_style = "green"
            refresh()

    def _stream_in_panel(
        self,
        *,
        title: str,
        command_line: str | Text,
        process: subprocess.Popen[str],
        writer: PanelWriterLike | None = None,
        raw_command: list[str] | None = None,
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
                status_line = self._format_status_line(
                    command_line,
                    f"FAILED ({returncode})",
                    failed=True,
                )
                writer.update_line(command_index, status_line)
                if raw_command is not None:
                    writer.append_line(
                        f"Full command: {raw_command}",
                        style="red dim",
                    )
                writer.append_line(
                    f"Failed with exit code {returncode}",
                    style="red",
                )
                writer.set_failed()
            return returncode

        with self.panel_session(title=title, prelude=[]) as panel_writer:
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
                status_line = self._format_status_line(
                    command_line,
                    f"FAILED ({returncode})",
                    failed=True,
                )
                panel_writer.update_line(command_index, status_line)
                if raw_command is not None:
                    panel_writer.append_line(
                        f"Full command: {raw_command}",
                        style="red dim",
                    )
                panel_writer.append_line(
                    f"Failed with exit code {returncode}",
                    style="red",
                )
                panel_writer.set_failed()

            return returncode

    def run_command(
        self,
        command: Command,
        description: str,
        writer: PanelWriterLike | None = None,
        error_msg: str | None = None,
        error_cls: type[Exception] | None = None,
        ok_codes: tuple[int, ...] = (0,),
    ) -> int:
        """Run a command and pretty-print the result. Returns exit code.

        If error_msg is set and the exit code is not in ok_codes,
        raises error_cls(error_msg). error_cls defaults to self.error_cls.
        """
        if error_cls is None:
            error_cls = self.error_cls
        command_line = command.render()
        executable = command.build()
        panel_title = description

        try:
            process = subprocess.Popen(
                executable,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                bufsize=1,
                universal_newlines=True,
            )
        except Exception as exc:
            if writer is not None:
                writer.append_line(f"Failed to run command: {exc}", style="red")
                writer.set_failed()
                if error_msg is not None:
                    raise error_cls(error_msg) from exc
                return 1
            self.console.print(
                Panel(
                    f"Failed to run command: {exc}",
                    title=panel_title,
                    border_style="red",
                )
            )
            if error_msg is not None:
                raise error_cls(error_msg) from exc
            return 1

        rc = self._stream_in_panel(
            title=panel_title,
            command_line=command_line,
            process=process,
            writer=writer,
            raw_command=executable,
        )
        if error_msg is not None and rc not in ok_codes:
            raise error_cls(error_msg)
        return rc
