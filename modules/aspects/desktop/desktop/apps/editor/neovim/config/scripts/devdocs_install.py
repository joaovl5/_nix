#!/usr/bin/env python3

import argparse
import json
import os
import shutil
import subprocess
import urllib.request
from pathlib import Path


def install(url: str, destination: Path) -> None:
    destination = destination.resolve()
    staging = destination.with_name(f"{destination.name}.tmp-{os.getpid()}")
    backup = destination.with_name(f"{destination.name}.old-{os.getpid()}")

    shutil.rmtree(staging, ignore_errors=True)
    shutil.rmtree(backup, ignore_errors=True)
    staging.mkdir(parents=True)

    try:
        request = urllib.request.Request(url, headers={"User-Agent": "devdocs.nvim"})
        with urllib.request.urlopen(request, timeout=120) as response:
            documentation = json.load(response)

        for slug in list(documentation):
            html = documentation.pop(slug)
            target = (staging / f"{slug}.md").resolve()
            if not target.is_relative_to(staging):
                raise ValueError(f"unsafe documentation path: {slug}")

            target.parent.mkdir(parents=True, exist_ok=True)
            with target.open("w") as output:
                subprocess.run(
                    [
                        "pandoc",
                        "--from",
                        "html",
                        "--to",
                        "gfm-raw_html",
                        "--wrap",
                        "none",
                    ],
                    input=str(html),
                    text=True,
                    stderr=subprocess.DEVNULL,
                    stdout=output,
                    check=True,
                )

        if destination.exists():
            destination.replace(backup)
        try:
            staging.replace(destination)
        except Exception:
            if backup.exists():
                backup.replace(destination)
            raise
        shutil.rmtree(backup, ignore_errors=True)
    except Exception:
        shutil.rmtree(staging, ignore_errors=True)
        raise


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("url")
    parser.add_argument("destination", type=Path)
    args = parser.parse_args()
    install(args.url, args.destination)


if __name__ == "__main__":
    main()
