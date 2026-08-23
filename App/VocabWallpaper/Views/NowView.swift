import SwiftUI
import VocabKit

struct NowView: View {
    @Environment(AppModel.self) private var model
    @State private var exporter = WallpaperExporter()
    @State private var showsSavedBanner = false
    @State private var showsExport = false

    var body: some View {
        NavigationStack {
            TimelineView(.everyMinute) { context in
                let date = context.date
                let entry = model.entry(at: date) ?? AppModel.placeholder
                let hourIndex = model.hourIndex(at: date)

                ScrollView {
                    VStack(spacing: 22) {
                        LockScreenPreview(
                            entry: entry,
                            hourIndex: hourIndex,
                            settings: model.settings
                        )
                        .aspectRatio(model.canvas.aspectRatio, contentMode: .fit)
                        .frame(maxHeight: 520)
                        .padding(.horizontal, 26)
                        .padding(.top, 8)

                        countdown

                        actions(entry: entry, hourIndex: hourIndex)

                        upNext(from: date)

                        Text("\(model.deck.count) words in rotation · one every hour · "
                             + "the deck lasts \(Int(model.deck.cycleDuration / 86_400)) days "
                             + "before anything repeats")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                            .padding(.bottom, 24)
                    }
                }
            }
            .background(backdrop)
            .navigationTitle("Wort der Stunde")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        model.reshuffleDeck()
                    } label: {
                        Label("Reshuffle", systemImage: "shuffle")
                    }
                }
            }
            .overlay(alignment: .bottom) { banner }
            .animation(.snappy, value: showsSavedBanner)
            .sheet(isPresented: $showsExport) {
                ExportView()
                    .environment(model)
            }
        }
    }

    private var backdrop: some View {
        LinearGradient(
            colors: [Ember.void, Ember.pitch, Color(hex: 0x14_08_06)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    /// The only thing on this screen that needs a per-second timeline. The
    /// wallpaper preview above runs on `.everyMinute`, which is enough to catch
    /// the hour boundary without redrawing gradients sixty times a minute.
    private var countdown: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let date = context.date
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(Ember.soot, lineWidth: 3)
                    Circle()
                        .trim(from: 0, to: model.hourProgress(at: date))
                        .stroke(
                            AngularGradient(colors: [Ember.crimson, Ember.orange, Ember.gold],
                                            center: .center),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                }
                .frame(width: 26, height: 26)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Next word in \(model.secondsUntilNextWord(at: date).countdownText)")
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                    Text("Changes at \(HourlyRotation.nextChange(after: date), format: .dateTime.hour().minute())")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(Ember.ember.opacity(0.18)))
        }
    }

    private func actions(entry: VocabEntry, hourIndex: Int) -> some View {
        VStack(spacing: 10) {
            Button {
                Task {
                    await exporter.saveOne(
                        entry: entry,
                        hourIndex: hourIndex,
                        canvas: model.canvas,
                        settings: model.settings
                    )
                    if case .finished = exporter.state { flashBanner() }
                }
            } label: {
                Label("Save this wallpaper", systemImage: "arrow.down.to.line")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Ember.ember)
            .controlSize(.large)
            .disabled(exporter.isRunning)

            Button {
                showsExport = true
            } label: {
                Label("Export the next 24 hours", systemImage: "square.stack.3d.down.right")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            if case .failed(let message) = exporter.state {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(Ember.crimson)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 26)
    }

    private func upNext(from date: Date) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("UP NEXT")
                .font(.caption.weight(.semibold))
                .tracking(1.6)
                .foregroundStyle(Ember.dust)
                .padding(.horizontal, 26)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(model.upcoming(from: date, count: 9).dropFirst())) { scheduled in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(scheduled.date, format: .dateTime.hour().minute())
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Ember.accent(for: scheduled.entry))
                            Text(scheduled.entry.headword)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                            Text(scheduled.entry.translation)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .frame(width: 132, alignment: .leading)
                        .padding(12)
                        .background(Ember.ash.opacity(0.7), in: RoundedRectangle(cornerRadius: 14))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(Ember.soot, lineWidth: 1)
                        }
                    }
                }
                .padding(.horizontal, 26)
            }
        }
    }

    @ViewBuilder private var banner: some View {
        if showsSavedBanner {
            Label("Saved to Photos", systemImage: "checkmark.circle.fill")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(Ember.ember.opacity(0.35)))
                .padding(.bottom, 12)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func flashBanner() {
        showsSavedBanner = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            showsSavedBanner = false
            exporter.reset()
        }
    }
}
