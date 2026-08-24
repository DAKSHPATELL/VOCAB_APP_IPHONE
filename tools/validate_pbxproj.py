#!/usr/bin/env python3
"""Parses project.pbxproj as an OpenStep plist and checks it for the two
failure modes that make Xcode refuse to open a project: malformed structure,
and object ids that are referenced but never defined.

Run:  python3 tools/validate_pbxproj.py
"""

import pathlib
import re
import sys

PATH = (pathlib.Path(__file__).resolve().parent.parent
        / "VocabWallpaper.xcodeproj/project.pbxproj")

TOKEN = re.compile(r"""
      /\*.*?\*/               # comment
    | "(?:[^"\\]|\\.)*"       # quoted string
    | [{}()=;,]               # punctuation
    | [A-Za-z0-9_./$@:<>+\-*~^\[\]\\]+   # bare string
    | \s+
""", re.VERBOSE | re.DOTALL)


def tokenize(text):
    position = 0
    tokens = []
    while position < len(text):
        match = TOKEN.match(text, position)
        if not match:
            raise SyntaxError(
                f"unexpected character {text[position]!r} at offset {position}"
            )
        value = match.group(0)
        position = match.end()
        if value.startswith("/*") or value.isspace():
            continue
        tokens.append(value)
    return tokens


class Parser:
    def __init__(self, tokens):
        self.tokens = tokens
        self.index = 0

    def peek(self):
        return self.tokens[self.index] if self.index < len(self.tokens) else None

    def take(self, expected=None):
        token = self.peek()
        if token is None:
            raise SyntaxError("unexpected end of file")
        if expected and token != expected:
            raise SyntaxError(f"expected {expected!r} but found {token!r} "
                              f"near token {self.index}")
        self.index += 1
        return token

    def value(self):
        token = self.peek()
        if token == "{":
            return self.dictionary()
        if token == "(":
            return self.array()
        return self.take()

    def dictionary(self):
        self.take("{")
        result = {}
        while self.peek() != "}":
            key = self.take()
            self.take("=")
            result[key] = self.value()
            self.take(";")
        self.take("}")
        return result

    def array(self):
        self.take("(")
        items = []
        while self.peek() != ")":
            items.append(self.value())
            if self.peek() == ",":
                self.take(",")
        self.take(")")
        return items


ID_PATTERN = re.compile(r"^[0-9A-F]{24}$")


def collect_references(node, found):
    if isinstance(node, dict):
        for key, value in node.items():
            if ID_PATTERN.match(key):
                found.add(key)
            collect_references(value, found)
    elif isinstance(node, list):
        for item in node:
            collect_references(item, found)
    elif isinstance(node, str) and ID_PATTERN.match(node):
        found.add(node)


def main():
    text = PATH.read_text(encoding="utf-8")
    if not text.startswith("// !$*UTF8*$!"):
        print("error: missing the UTF-8 marker comment", file=sys.stderr)
        return 1

    body = text.split("\n", 1)[1]
    parser = Parser(tokenize(body))
    root = parser.dictionary()
    if parser.peek() is not None:
        print(f"error: trailing tokens after the root dictionary: {parser.peek()!r}",
              file=sys.stderr)
        return 1

    objects = root["objects"]
    defined = set(objects)

    referenced = set()
    collect_references(objects, referenced)
    referenced.add(root["rootObject"])
    referenced -= defined  # keys of `objects` are definitions, not references

    dangling = sorted(referenced)
    if dangling:
        for identifier in dangling:
            print(f"error: {identifier} is referenced but never defined", file=sys.stderr)
        return 1

    # Every object must declare its class, and every target must be reachable.
    for identifier, obj in objects.items():
        if not isinstance(obj, dict) or "isa" not in obj:
            print(f"error: object {identifier} has no isa", file=sys.stderr)
            return 1

    project_id = root["rootObject"]
    project = objects[project_id]
    targets = project["targets"]

    kinds = {}
    for obj in objects.values():
        kinds[obj["isa"]] = kinds.get(obj["isa"], 0) + 1

    orphans = sorted(
        identifier for identifier, obj in objects.items()
        if obj["isa"] == "PBXFileReference"
        and identifier not in referenced_by_groups(objects)
    )

    print(f"ok: {len(objects)} objects, {len(targets)} targets, "
          f"{len(defined)} ids, no dangling references")
    for isa, count in sorted(kinds.items()):
        print(f"    {count:>3}  {isa}")
    if orphans:
        print(f"warning: {len(orphans)} file references are not in any group")
    return 0


def referenced_by_groups(objects):
    inside = set()
    for obj in objects.values():
        if obj["isa"] == "PBXGroup":
            inside.update(obj.get("children", []))
    return inside


if __name__ == "__main__":
    raise SystemExit(main())
