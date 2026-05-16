# Janet Processes and Tooling Reference

## Upstream refs

- [Process Management: Executing](https://janet-lang.org/1.40.1/docs/process_management/execute.html)
- [Process Management: Spawning](https://janet-lang.org/1.40.1/docs/process_management/spawn.html)
- [Spork sh](https://janet-lang.org/1.40.1/spork/api/sh.html)
- [JPM](https://janet-lang.org/1.40.1/jpm/index.html)
- [Project.janet](https://janet-lang.org/1.40.1/jpm/project.janet.html)

## Process model

- **Default rule:** pass commands as argv data, not shell strings
- **Simple runs:** use `os/execute` when you only need a run-and-wait call
- **Handles and pipes:** use `os/spawn` when you need process handles, streams, or explicit cleanup
- **Cleanup:** wait on spawned processes and close the resources you open

## Spork sh

- **`sh/exec`:** runs a command and returns its exit code
- **`sh/exec-fail`:** runs a command and throws on non-zero exit
- **`sh/exec-slurp`:** runs a command, trims stdout, and returns the text
- **`sh/escape`:** quote args only when you truly need a shell string
- **Rule of thumb:** use `sh/exec-slurp` for small helpers like file lists, and prefer argv arrays everywhere else

## JPM

- **What it is:** JPM is Janet's project manager and package/build tool
- **Project shape:** a project is a directory with a `project.janet`
- **Use it for:** dependencies, native modules, project scripts, and project packaging
- **When to reach for it:** use the repo's wrapper if the project expects one; keep scripts runnable through the same entrypoint the repo documents

## Repo workflow

- **Scripts:** keep Janet scripts small and explicit
- **Dependency checks:** load the same Janet/Spork environment that the script expects before calling it
- **Testing:** if a script touches files, prefer a dry run or a temp tree before acting on the real checkout

## Common mistakes

- **Shell strings:** building command lines as strings when argv data would be safer
- **Wrong helper:** using `sh/exec` when you need stdout, or `os/execute` when you need control
- **Leaked handles:** forgetting to close spawned processes or open files
- **Path drift:** assuming the repo wrapper and the plain interpreter see the same environment
