#!/usr/bin/env python3
"""Read the exact release name from VERSION, without consulting Git history."""

import argparse
import os
from pathlib import Path
import re
import sys


VERSION_FILE = Path(__file__).resolve().parent.parent / "VERSION"
VERSION_PATTERN = re.compile(r"(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)")


def read_version(path: Path) -> str:
    version = path.read_text(encoding="utf-8-sig").strip()
    if VERSION_PATTERN.fullmatch(version) is None:
        raise ValueError("VERSION must contain one version in X.Y.Z format, for example 1.1.0.")
    return version


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("file", type=Path, nargs="?", default=VERSION_FILE)
    args = parser.parse_args()
    try:
        version = read_version(args.file)
        output = os.environ.get("GITHUB_OUTPUT")
        if output:
            with Path(output).open("a", encoding="utf-8") as destination:
                destination.write(f"version={version}\ntag=v{version}\n")
    except (OSError, ValueError) as error:
        print(f"::error file=VERSION::{error}", file=sys.stderr)
        return 1
    print(f"Release version from VERSION: {version}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
