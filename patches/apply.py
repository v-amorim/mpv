#!/usr/bin/env python3
"""Reapply the local patches over the vendored scripts.

`portable_config/scripts/uosc/` is gitignored and uosc's own updater overwrites
it, so every update silently reverts these. Run this afterwards.

Unified diffs are applied here rather than by `git apply`, so the repo does not
have to be a git checkout and git's autocrlf cannot rewrite uosc's LF sources on
the way in. Targets are always written back with LF, the way upstream ships them.

    python patches/apply.py [--check]
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

HUNK = re.compile(r"^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@")
ROOT = Path(__file__).resolve().parent.parent


class PatchError(Exception):
    pass


def parse(patch_text: str) -> tuple[str, list[tuple[int, list[str]]]]:
    """-> target path, and each hunk as its start line plus its diff body."""
    target, hunks, body, start = None, [], None, 0
    for line in patch_text.split("\n"):
        if line.startswith("+++ "):
            path = line[4:].split("\t")[0].strip()
            target = path[2:] if path.startswith(("a/", "b/")) else path
            continue
        match = HUNK.match(line)
        if match:
            if body is not None:
                hunks.append((start, body))
            start, body = int(match.group(1)), []
            continue
        if body is not None and line[:1] in (" ", "-", "+", "\\"):
            body.append(line)
    if body is not None:
        hunks.append((start, body))
    if not target or not hunks:
        raise PatchError("no target file or no hunks in the patch")
    return target, hunks


def sides(body: list[str]) -> tuple[list[str], list[str]]:
    """The lines a hunk expects to find, and the lines it leaves behind."""
    before = [l[1:] for l in body if l[:1] in (" ", "-")]
    after = [l[1:] for l in body if l[:1] in (" ", "+")]
    return before, after


def locate(lines: list[str], want: list[str], hint: int) -> int:
    """Index of `want` in `lines`, searched outwards from `hint`."""
    if not want:
        return max(0, min(hint, len(lines)))
    for offset in range(len(lines)):
        for index in {hint + offset, hint - offset}:
            if 0 <= index <= len(lines) - len(want) and lines[index:index + len(want)] == want:
                return index
    raise PatchError("context not found")


def transform(lines: list[str], hunks, forward: bool) -> list[str]:
    out, shift = list(lines), 0
    for start, body in hunks:
        before, after = sides(body)
        if not forward:
            before, after = after, before
        at = locate(out, before, start - 1 + shift)
        out[at:at + len(before)] = after
        shift += len(after) - len(before)
    return out


def state(target: Path, hunks) -> str:
    text = target.read_text(encoding="utf-8", newline="").replace("\r\n", "\n")
    lines = text.split("\n")
    try:
        transform(lines, hunks, forward=True)
        return "pending"
    except PatchError:
        pass
    try:
        transform(lines, hunks, forward=False)
        return "applied"
    except PatchError:
        return "conflict"


def apply(target: Path, hunks) -> None:
    text = target.read_text(encoding="utf-8", newline="").replace("\r\n", "\n")
    patched = transform(text.split("\n"), hunks, forward=True)
    target.write_text("\n".join(patched), encoding="utf-8", newline="")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="report without writing")
    args = parser.parse_args()

    patches = sorted((ROOT / "patches").glob("*.patch"))
    if not patches:
        print("no patches to apply")
        return 0

    failed = False
    for patch in patches:
        name = patch.relative_to(ROOT).as_posix()
        try:
            relative, hunks = parse(patch.read_text(encoding="utf-8"))
            target = ROOT / relative
            if not target.exists():
                raise PatchError(f"{relative} is missing")
            status = state(target, hunks)
            if status == "applied":
                print(f"already applied: {name}")
            elif status == "conflict":
                raise PatchError(f"{relative} matches neither side of the patch")
            elif args.check:
                print(f"would apply:     {name}")
            else:
                apply(target, hunks)
                print(f"applied:         {name}")
        except (PatchError, OSError) as error:
            print(f"FAILED:          {name}: {error}", file=sys.stderr)
            failed = True
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
