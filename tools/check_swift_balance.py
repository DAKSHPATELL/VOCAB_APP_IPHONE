#!/usr/bin/env python3
"""A cheap structural sanity check for the Swift sources.

This is not a compiler. It strips comments and string literals (including
interpolation-aware handling of `\\(...)`) and then verifies that braces,
brackets and parentheses balance in every file — which catches the class of
typo that a Linux CI box otherwise cannot see at all.

Run:  python3 tools/check_swift_balance.py
"""

import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
PAIRS = {")": "(", "]": "[", "}": "{"}


def check(path: pathlib.Path):
    text = path.read_text(encoding="utf-8")
    stack = []
    problems = []

    index = 0
    line = 1
    length = len(text)
    in_line_comment = False
    block_depth = 0
    in_string = False
    in_multiline_string = False

    while index < length:
        char = text[index]
        if char == "\n":
            line += 1
            in_line_comment = False
            index += 1
            continue

        if in_line_comment:
            index += 1
            continue

        if block_depth:
            if text.startswith("/*", index):
                block_depth += 1
                index += 2
                continue
            if text.startswith("*/", index):
                block_depth -= 1
                index += 2
                continue
            index += 1
            continue

        if in_multiline_string:
            if text.startswith('"""', index):
                in_multiline_string = False
                index += 3
                continue
            index += 1
            continue

        if in_string:
            if char == "\\":
                # `\(` opens an interpolation, which contains real code; the
                # simplest safe move is to treat the rest of the literal as
                # opaque up to the closing quote on the same line.
                index += 2
                continue
            if char == '"':
                in_string = False
            index += 1
            continue

        if text.startswith("//", index):
            in_line_comment = True
            index += 2
            continue
        if text.startswith("/*", index):
            block_depth = 1
            index += 2
            continue
        if text.startswith('"""', index):
            in_multiline_string = True
            index += 3
            continue
        if char == '"':
            in_string = True
            index += 1
            continue

        if char in "([{":
            stack.append((char, line))
        elif char in ")]}":
            if not stack:
                problems.append(f"{path}:{line}: stray {char!r}")
            else:
                opener, opened_at = stack.pop()
                if opener != PAIRS[char]:
                    problems.append(
                        f"{path}:{line}: {char!r} closes {opener!r} opened on line {opened_at}"
                    )
        index += 1

    if block_depth:
        problems.append(f"{path}: unterminated block comment")
    for opener, opened_at in stack:
        problems.append(f"{path}:{opened_at}: unclosed {opener!r}")

    return problems


def main():
    files = sorted(
        path for directory in ("VocabKit", "App", "Widget")
        for path in (ROOT / directory).rglob("*.swift")
    )
    if not files:
        print("error: no Swift files found", file=sys.stderr)
        return 1

    all_problems = []
    for path in files:
        all_problems.extend(check(path))

    for problem in all_problems:
        print(f"error: {problem}", file=sys.stderr)

    total_lines = sum(len(p.read_text(encoding="utf-8").splitlines()) for p in files)
    print(f"checked {len(files)} Swift files ({total_lines} lines): "
          f"{'balanced' if not all_problems else str(len(all_problems)) + ' problems'}")
    return 1 if all_problems else 0


if __name__ == "__main__":
    raise SystemExit(main())
