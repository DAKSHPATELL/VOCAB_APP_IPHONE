# The prompt

This is the prompt that produced the app in this repository. Copy everything
between the rules into Claude Code, from an empty directory.

---

> Build me a complete, buildable iPhone app called **Vokabel** that shows me one
> German vocabulary word per hour as an iPhone wallpaper.
>
> **Before you write anything, resolve this constraint and tell me how you handled
> it:** iOS has no public API for setting the wallpaper from an app. Do not
> pretend otherwise and do not invent a background task that "updates the
> wallpaper". Build the paths that actually work on a stock iPhone:
>
> 1. **Batch export → Photos album → Photo Shuffle set to Hourly.** This is the
>    primary path: iOS itself rotates the images, nothing has to be running.
> 2. **A WidgetKit extension** with a 24-entry hourly timeline, for Lock Screen
>    and Home Screen — genuinely live, no export needed.
> 3. A short in-app guide covering both, plus a Shortcuts variant, written as
>    plain instructions that admit the limitation rather than marketing copy.
>
> **Word rotation must be a pure function of the clock, not stored state.** The
> app, the widget extension (separate process) and an image exported three days
> ago must all agree on which word belongs to a given hour, offline, with no
> shared writes. Derive it: `hourIndex = floor(local epoch seconds / 3600)`, walk
> a Fisher–Yates shuffle of the deck seeded on `userSeed ^ cycleNumber` so every
> word appears exactly once per cycle and each cycle is reshuffled. Write your own
> Fisher–Yates and your own SplitMix64 generator — `shuffle(using:)` is not
> contractually stable across Swift versions, and this has to be reproducible.
>
> **The wallpaper design.** Very dark, ember-lit, and strictly red and orange —
> no blues, no greens, no cool greys:
>
> - Ground: warm-tinted near-blacks (#05 0304 → #12 0909), never pure #000, which
>   reads flat on OLED.
> - Fire: #B01414 blood, #E02A18 crimson, #FF4D1C ember, #FF8A28 orange, #FFC76B
>   gold. Three or four soft radial blooms placed by a generator seeded on the
>   hour, screen-blended, so consecutive wallpapers are siblings but never
>   identical. A band of heat along the bottom edge. Film grain and a few brighter
>   sparks. A vignette.
> - Type: large serif headword filled with a gold→ember gradient and an orange
>   glow; the article above it in italic; grammatical gender colour-coded but
>   every colour staying inside the red/orange family.
> - Content: article · word · English meaning · plural (or verb principal parts) ·
>   an example sentence with the headword highlighted **inside** the sentence ·
>   its translation · hour, CEFR level, part of speech.
> - Three layouts: Lock Screen (top ~40% kept clear for the clock, bottom clear
>   for the two buttons), Home Screen (dimmer so icons stay readable), Poster.
>
> **Highest resolution, and mean it.** Render at the exact pixel dimensions of the
> target panel — 1320 × 2868 for a 6.9″ Pro Max, and a preset list down to the SE
> — using `ImageRenderer` with the device's native scale, so iOS never resamples.
> Detect the running device's panel from `nativeBounds` rather than assuming.
> Express every dimension inside the wallpaper view as a fraction of the canvas
> height, so the identical view is correct at 200 pt in a preview and 2868 px in
> the export. PNG by default (flat gradients are where JPEG bands), HEIC optional,
> plus a 2× supersample-and-downscale toggle.
>
> **Architecture.** Put everything shared — model, rotation, palette, the
> wallpaper view, the renderer — in a local Swift package so the app and the
> widget extension import the same code rather than duplicating it. Bridge user
> settings between the two processes through an App Group. SwiftUI, iOS 17,
> `@Observable`.
>
> **The app itself:** a Now tab with a live lock-screen-framed preview and a
> countdown to the next word; an Export tab that batch-renders 12/24/48/72/168
> wallpapers into a named Photos album with progress; a searchable word list with
> favourites and per-word preview; a Settings tab for levels, parts of speech,
> themes, layout, resolution, the ember/grain/vignette sliders, and a reshuffle.
>
> **Vocabulary:** at least 200 real entries spanning A1–B2 — nouns with correct
> articles and plurals, verbs with principal parts, adjectives, adverbs,
> connectors and idiomatic phrases — each with a natural example sentence and its
> English translation. Generate the JSON from an editable Python table that
> validates itself, rather than hand-writing 200 JSON objects I can never maintain.
>
> **Ship it properly:** a real `.xcodeproj` I can open, the App Group declared in
> both `.entitlements`, an app icon, and a test suite covering the rotation
> invariants (exactly-once-per-cycle, determinism, negative hour indices, hour
> boundaries) and the corpus (unique ids, every noun has an article, examples
> contain their own headword). Since you cannot compile Swift where you are
> running, write the checks you *can* run — parse the pbxproj and fail on dangling
> object references, structurally check every Swift file — and tell me plainly at
> the end what you verified and what still needs a Mac.
>
> Do not stub anything. Do not leave TODOs. Commit and push when it builds out.

---

## Why it is shaped this way

Five things in that prompt are doing most of the work, and they generalise to any
app you ask Claude Code to build:

**Name the constraint before the feature.** "Wallpaper app" plus a naive model of
iOS produces something that cannot exist. Putting the missing API first, and
saying *do not pretend otherwise*, converts a doomed request into three real ones.
If you do not know the constraint yourself, ask for it first: *"before building,
tell me what iOS actually permits here."*

**Specify the mechanism, not the vibe.** "Words refresh every hour" has a dozen
implementations, most of them fragile — a timer, a background fetch, a stored
index that two processes fight over. Saying *pure function of the clock, no shared
state, all three consumers must agree offline* removes the entire class of bugs
before any code exists.

**Give colour in hex.** "Dark with red and orange" is a mood board. Five named
hex values, a rule about what is banned, and *never pure black because it reads
flat on OLED* is a design system. The second one survives contact with an
implementation; the first gets reinterpreted every time you ask for a change.

**Define "highest resolution" operationally.** On its own it is a wish. *Exact
panel pixels, native scale, detected from nativeBounds, every dimension a fraction
of canvas height, PNG because gradients band* is a spec — and the last clause is
the one that stops a well-meaning JPEG export from quietly ruining the design.

**Say what verification you expect.** A coding agent on Linux cannot compile an
iOS app. Asking for the checks that *are* possible, plus an honest closing summary
of what remains unverified, is the difference between a report you can trust and
one you have to re-derive yourself.

## Reusing it

Swap the subject and the palette and the skeleton holds:

- **Different language** — replace the vocabulary table and the article/gender
  colour rule (`Ember.accent(for:)`); everything else is language-agnostic.
- **Different mood** — the entire colour system is `EmberPalette.swift`. Rewrite
  those twelve constants and the whole app changes.
- **Different content entirely** (quotes, kanji, formulas, chess puzzles) — the
  rotation engine, renderer, exporter and widget do not know what a word is.
