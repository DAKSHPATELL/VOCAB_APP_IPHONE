import SwiftUI
import VocabKit

/// Written deliberately as plain instructions rather than marketing: the
/// constraint it explains is a real iOS limitation, not a missing feature.
struct HowToView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                intro

                section(
                    number: 1,
                    title: "Hourly wallpaper — Photo Shuffle",
                    tint: Ember.ember,
                    steps: [
                        "In the Export tab, export 24 (or 168) wallpapers into an album.",
                        "Long-press your Lock Screen, tap +, choose Photo Shuffle.",
                        "Tap the three-dot menu, pick Albums, and select your export album.",
                        "Set Shuffle Frequency to Hourly, then Add and Set as Wallpaper Pair."
                    ],
                    note: "iOS now rotates the wallpaper itself, on its own schedule, "
                        + "with no app running in the background. Re-export whenever you "
                        + "want fresh words."
                )

                section(
                    number: 2,
                    title: "Truly live — widgets",
                    tint: Ember.orange,
                    steps: [
                        "Long-press the Lock Screen, tap Customise, then the widget area.",
                        "Add “Wort der Stunde”. On the Home Screen, long-press and add the "
                          + "medium or large widget.",
                        "The widget recomputes on the hour from a 24-hour timeline it holds "
                          + "locally."
                    ],
                    note: "Lock Screen accessory widgets are rendered by iOS in a "
                        + "desaturated style, so they show the word without the ember "
                        + "colours. Home Screen widgets keep the full palette."
                )

                section(
                    number: 3,
                    title: "Automated — Shortcuts",
                    tint: Ember.amber,
                    steps: [
                        "Shortcuts › new shortcut › Get Latest Photos from the export album.",
                        "Add the Set Wallpaper action and pick that photo.",
                        "Automation › new › Time of Day. Shortcuts repeats daily, so add one "
                          + "automation per hour you care about."
                    ],
                    note: "More fiddly than Photo Shuffle and it only wins if you want the "
                        + "wallpaper to change on some other trigger — arriving somewhere, "
                        + "a Focus turning on, opening an app."
                )

                honesty
            }
            .padding(24)
        }
        .background(Ember.void)
        .navigationTitle("Hourly setup")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Three ways to get a new word every hour")
                .font(.title2.bold())
            Text("Pick one. The first needs no app running at all, the second is "
                 + "genuinely live, the third is for people who like automations.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func section(
        number: Int,
        title: String,
        tint: Color,
        steps: [String],
        note: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text("\(number)")
                    .font(.system(.headline, design: .serif).bold())
                    .foregroundStyle(Ember.void)
                    .frame(width: 28, height: 28)
                    .background(tint, in: Circle())
                Text(title)
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(steps.enumerated()), id: \.offset) { _, step in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(tint.opacity(0.6))
                            .frame(width: 5, height: 5)
                            .padding(.top, 7)
                        Text(step)
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            Text(note)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Ember.ash.opacity(0.6), in: RoundedRectangle(cornerRadius: 12))
        }
        .padding(16)
        .background(Ember.pitch, in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(tint.opacity(0.2), lineWidth: 1)
        }
    }

    private var honesty: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Why the app can't just do it", systemImage: "lock.fill")
                .font(.subheadline.weight(.semibold))
            Text("iOS has no public API for setting the wallpaper — not from an app, "
                 + "not from a background task, not from a notification. Anything "
                 + "claiming otherwise is either using Shortcuts under the hood or is "
                 + "not on the App Store. Everything above is built on what the system "
                 + "genuinely offers.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Ember.ash.opacity(0.5), in: RoundedRectangle(cornerRadius: 16))
    }
}
