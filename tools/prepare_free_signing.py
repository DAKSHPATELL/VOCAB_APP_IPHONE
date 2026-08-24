#!/usr/bin/env python3
"""Makes the project signable with a free Apple ID.

Two things block a free personal team:

  1. App Groups is a paid Apple Developer Program capability. Xcode fails
     signing outright while the entitlement is present.
  2. The bundle identifiers are the author's. Two people cannot register the
     same App ID, so yours have to be unique to you.

This rewrites both, in place. The app still works: SharedStore notices the
missing App Group at runtime and falls back to standard UserDefaults, so the
widget uses default filters instead of following the Settings tab. The word
shown still matches the app's, because the rotation is computed from the clock
rather than passed between the two processes.

Run:  python3 tools/prepare_free_signing.py --bundle-id com.yourname.vokabel
      python3 tools/prepare_free_signing.py --restore
"""

import argparse
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent

ENTITLEMENTS = [
    ROOT / "App/VocabWallpaper/VocabWallpaper.entitlements",
    ROOT / "Widget/VocabWidget/VocabWidget.entitlements",
]
GENERATOR = ROOT / "tools/generate_xcodeproj.py"
SHARED_STORE = ROOT / "VocabKit/Sources/VocabKit/SharedStore.swift"

EMPTY_ENTITLEMENTS = """<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
\t<!-- App Groups removed: it requires a paid Apple Developer Program account.
\t     Restore with: python3 tools/prepare_free_signing.py --restore -->
</dict>
</plist>
"""

DEFAULT_BUNDLE_ID = "com.dakshpatel.vocabwallpaper"


def current_bundle_id() -> str:
    text = GENERATOR.read_text(encoding="utf-8")
    match = re.search(r'^APP_BUNDLE_ID = "([^"]+)"', text, re.MULTILINE)
    if not match:
        sys.exit("error: could not find APP_BUNDLE_ID in the project generator")
    return match.group(1)


def rewrite_bundle_id(new_id: str) -> str:
    old = current_bundle_id()
    if old == new_id:
        return old

    generator = GENERATOR.read_text(encoding="utf-8")
    generator = generator.replace(f'APP_BUNDLE_ID = "{old}"', f'APP_BUNDLE_ID = "{new_id}"')
    generator = generator.replace(
        f'WIDGET_BUNDLE_ID = "{old}.widget"', f'WIDGET_BUNDLE_ID = "{new_id}.widget"'
    )
    GENERATOR.write_text(generator, encoding="utf-8")

    store = SHARED_STORE.read_text(encoding="utf-8")
    store = re.sub(
        r'appGroupIdentifier = "group\.[^"]+"',
        f'appGroupIdentifier = "group.{new_id}"',
        store,
    )
    SHARED_STORE.write_text(store, encoding="utf-8")
    return old


def strip_entitlements() -> None:
    for path in ENTITLEMENTS:
        path.write_text(EMPTY_ENTITLEMENTS, encoding="utf-8")


def restore_entitlements(bundle_id: str) -> None:
    body = (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" '
        '"http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n'
        '<plist version="1.0">\n<dict>\n'
        '\t<key>com.apple.security.application-groups</key>\n'
        f'\t<array>\n\t\t<string>group.{bundle_id}</string>\n\t</array>\n'
        '</dict>\n</plist>\n'
    )
    for path in ENTITLEMENTS:
        path.write_text(body, encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--bundle-id", help="your own reverse-DNS identifier, "
                                            "e.g. com.yourname.vokabel")
    parser.add_argument("--restore", action="store_true",
                        help="put the App Group entitlement back (paid account)")
    args = parser.parse_args()

    if args.restore:
        bundle_id = args.bundle_id or current_bundle_id()
        if args.bundle_id:
            rewrite_bundle_id(args.bundle_id)
        restore_entitlements(bundle_id)
        print(f"restored App Groups for group.{bundle_id}")
    else:
        if not args.bundle_id:
            parser.error("--bundle-id is required (or pass --restore)")
        if not re.fullmatch(r"[A-Za-z0-9.-]+", args.bundle_id) or "." not in args.bundle_id:
            parser.error("bundle id must be reverse-DNS, e.g. com.yourname.vokabel")
        old = rewrite_bundle_id(args.bundle_id)
        strip_entitlements()
        print(f"bundle id: {old} -> {args.bundle_id}")
        print(f"widget:    {args.bundle_id}.widget")
        print("App Groups entitlement removed from both targets")

    print("\nnow run:  python3 tools/generate_xcodeproj.py")
    print("then in Xcode set your Team on both targets and press Run.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
