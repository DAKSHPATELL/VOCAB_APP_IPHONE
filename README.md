# Vokabel — German vocabulary wallpapers that change every hour

A complete iPhone app. One German word per hour, rendered as a wallpaper at your
device's exact panel resolution: near-black ground, ember reds and oranges, no
other colour in the system.

<sub>Word · article · plural or principal parts · English meaning · an example
sentence with the word lit up inside it · CEFR level.</sub>

---

## What actually refreshes every hour

Worth being blunt about this up front, because it shapes the whole design:

**iOS has no public API for setting the wallpaper.** Not from an app, not from a
background task, not from a push notification. Any app that claims to swap your
wallpaper on a schedule is either driving Shortcuts or is not on the App Store.

So the app does the two things that genuinely work, and does them properly:

| Path | Refresh | Effort | Colour |
|---|---|---|---|
| **Photo Shuffle** — export an album, point the system's own shuffling Lock Screen at it | Hourly, by iOS itself | One-time setup | Full ember palette |
| **Widgets** — Lock Screen and Home Screen | Hourly, live | Add the widget | Full colour on Home Screen; iOS desaturates Lock Screen accessories |
| Shortcuts automation | Whatever you can trigger | Fiddly | Full palette |

The in-app guide (`Export › How to make iOS rotate them hourly`) walks through
each one. Photo Shuffle is the recommended path: after the export, nothing needs
to run at all — iOS rotates the images on its own.

## The rotation is arithmetic, not state

There is no server, no background refresh, and nothing written down about "which
word is next". The current word is a pure function:

```
hourIndex   = floor(local seconds since epoch / 3600)
cycle       = hourIndex / deckSize          (floor division)
deck        = fisherYates(0..<deckSize, seed: userSeed ^ cycle)
word        = deck[hourIndex - cycle * deckSize]
```

Every word appears exactly once per cycle, each cycle is reshuffled, and the app,
the widget extension and any wallpaper you exported three days ago all compute the
identical answer offline. With the default filters the deck is **241 words**, so
nothing repeats for ten days.

## Resolution

Wallpapers render at the exact pixel dimensions of the target panel — 1320 × 2868
on a 6.9″ Pro Max, and so on down the preset list — via `ImageRenderer` with
`scale` set to the device's native scale. iOS therefore never resamples the image.
Every dimension inside `WallpaperCanvas` is expressed as a fraction of the canvas
height, so the same view is correct at 200 pt in a preview card and at 2868 px in
the export. A supersample toggle renders at 2× and downsamples for slightly
cleaner serif edges.

PNG is the default format: the design is flat gradients and large type, which is
exactly where JPEG banding shows.

## Getting it running

Requires Xcode 15 or newer and iOS 17+.

```bash
open VocabWallpaper.xcodeproj
```

Then, **once**, in Signing & Capabilities:

1. Select the `VocabWallpaper` target → set your Team.
2. Do the same for `VocabWidgetExtension`.
3. Both targets already declare the App Group `group.com.dakshpatel.vocabwallpaper`
   in their `.entitlements`. If you change the bundle identifier, change the group
   to match in three places: both `.entitlements` files and
   `SharedStore.appGroupIdentifier`.

The Settings tab shows `App Group: Connected` when this is wired up correctly. If
it says otherwise, the widget will still work — it just falls back to default
settings instead of reading yours.

Build and run on a device; widgets are only really testable on hardware.

### If you are signing with a free Apple ID

App Groups are not available to free personal teams — only to paid Apple
Developer Program accounts. With a free Apple ID the build fails at the signing
step until you remove the capability:

1. Delete `com.apple.security.application-groups` from both `.entitlements`
   files (or clear `CODE_SIGN_ENTITLEMENTS` on both targets).
2. Everything still builds and runs. `SharedStore` falls back to standard
   `UserDefaults`, and Settings will honestly report `App Group: Not configured`.

The only thing you lose is the app and the widget sharing settings: the widget
falls back to the defaults instead of following your filters. The word shown
still matches, because the rotation is computed from the clock rather than from
anything the two processes pass between them.

Free personal provisioning also expires after 7 days, after which the app must
be re-run from Xcode.

## Downloads

Every push builds on a macOS runner and uploads a simulator build:
**[Actions](../../actions) → the latest `Build` run → Artifacts →
`Vokabel-simulator-app`**. Unzip and drag `VocabWallpaper.app` onto a booted iOS
Simulator, or:

```bash
xcrun simctl install booted VocabWallpaper.app
xcrun simctl launch booted com.dakshpatel.vocabwallpaper
```

That artifact is a **simulator** binary — it will not install on a physical
iPhone.

The same run also uploads **`Vokabel-unsigned-ipa`**, a Release device build with
no signature. Nothing can be installed on an iPhone without a signature tied to
an Apple developer identity and that specific device, so this .ipa has to be
re-signed with *your* Apple ID before it will run. Two ways:

| Route | What it needs | Lasts |
|---|---|---|
| **Xcode** (recommended) | Open the project, select your device, press Run | 7 days on a free Apple ID |
| **Sideloadly / AltStore** | Drop the .ipa in, sign in with your Apple ID | 7 days on a free Apple ID |

Entitlements are deliberately stripped from the .ipa: App Groups is a paid
Developer Program capability, and leaving it in makes re-signing with a free
Apple ID fail. The app notices at runtime and falls back to standard
`UserDefaults` — everything works, the widget just uses default filters rather
than following yours.

There is no route to a tap-to-install build without a paid Apple Developer
Program membership; that is an Apple restriction, not a gap in this project.

## Layout

```
VocabKit/                  Swift package shared by both targets
  VocabEntry.swift           the model
  SeededGenerator.swift      SplitMix64 + a hand-written Fisher–Yates
  HourlyRotation.swift       hour maths and deck position
  VocabularyLibrary.swift    corpus loading, filtering, scheduling
  WallpaperSettings.swift    everything the renderer needs
  SharedStore.swift          the App Group bridge
  EmberPalette.swift         the entire colour system
  DeviceCanvas.swift         pixel-exact render targets
  WallpaperCanvas.swift      the wallpaper itself
  WallpaperRenderer.swift    SwiftUI view → PNG/HEIC at native resolution
  VocabCards.swift           compact variants for widgets
  Resources/vocabulary.json  241 entries, generated

App/VocabWallpaper/        the app: Now, Export, Words, Settings
Widget/VocabWidget/        Lock Screen and Home Screen widgets
tools/                     generators and checks, all pure Python 3
```

## Tooling

```bash
make vocab      # rebuild vocabulary.json from the editable table
make icon       # re-render the 1024px app icon (no Pillow needed)
make project    # regenerate the .xcodeproj from the folders on disk
make validate   # parse the pbxproj, fail on dangling object references
make check      # structural check over every Swift file
make test       # swift test --package-path VocabKit          (needs macOS)
make build      # xcodebuild for the simulator                 (needs macOS)
```

`tools/generate_xcodeproj.py` is the source of truth for the project file — add a
Swift file to `App/` or `Widget/` and re-run `make project` rather than editing
the pbxproj by hand. A `project.yml` is included for anyone who would rather use
XcodeGen; use one or the other, not both.

## Adding words

Edit the table at the top of `tools/build_vocabulary.py` and run `make vocab`.
Each row is:

```python
("Freiheit", "die", "die Freiheiten", "freedom, liberty", "noun", "A2", "abstract",
 "Freiheit bedeutet auch Verantwortung.", "Freedom also means responsibility.")
```

The builder validates as it goes: nouns must carry a valid article, non-nouns must
not, levels and parts of speech must be known, ids must be unique. The test suite
additionally asserts that at least 75% of examples contain their own headword, so
the highlight-in-context feature keeps working as the corpus grows.

## Licence

MIT — see `LICENSE`.
