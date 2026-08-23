# Getting a new word every hour

Three routes. Pick one — you do not need all three.

## 1. Photo Shuffle (recommended)

iOS rotates the images itself. Nothing runs in the background, the battery cost
is zero, and it keeps working if you never open the app again.

1. **Export** — in the app, `Export` tab. Choose `24 · one day` (or `168 · one
   week`), leave the format on PNG, name the album, tap **Export to Photos**.
   Grant photo access when asked; it needs read-write because it creates and
   reuses a named album.
2. **Point the Lock Screen at it** — long-press the Lock Screen → `+` →
   **Photo Shuffle** → the `…` menu → **Albums** → pick your export album.
3. **Set the frequency** — **Shuffle Frequency → Hourly**.
4. **Add** → **Set as Wallpaper Pair**.

Re-export whenever you want fresh words. Leave "Clear the album first" on and
the export replaces the previous batch instead of piling up.

If the album does not appear in the Photo Shuffle picker, open Photos once and
confirm the album exists — iOS caches that list.

## 2. Widgets

Genuinely live: the extension holds a 24-hour timeline and iOS advances it on
the hour.

- **Lock Screen** — long-press → `Customise` → tap the widget area below the
  clock → add **Wort der Stunde**.
- **Home Screen** — long-press an empty area → `+` → find **Wort der Stunde** →
  the medium or large size shows the example sentence, the small one does not.

One thing to expect: iOS renders Lock Screen accessory widgets in a desaturated
vibrant style. The ember palette cannot survive that, so the Lock Screen widget
deliberately reads as tone and weight instead of colour. Home Screen widgets keep
the full palette.

If the widget shows a word that disagrees with the app, the App Group is not
wired up — check `Settings › About › App Group` in the app.

## 3. Shortcuts

Worth it only if you want a trigger other than the clock — arriving somewhere, a
Focus turning on, opening an app.

1. Shortcuts → new shortcut → **Get Latest Photos** → set the album to your
   export album, and `Get Latest 1 Photo`.
2. Add **Set Wallpaper** and feed it that photo.
3. Automation tab → new → choose your trigger.

Note that Shortcuts' time-of-day automations repeat daily, not hourly — a true
hourly schedule means creating twenty-four of them. That is why Photo Shuffle is
the recommended path.

## Why the app cannot just do it

There is no public iOS API for setting the wallpaper — not from the app, not from
a background task, not from a notification handler. `UIScreen` exposes nothing,
and the private entitlements that would are not available to App Store apps. Every
route above is built on what the system genuinely offers.
