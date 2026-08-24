import SwiftUI
import VocabKit

struct ExportView: View {
    @Environment(AppModel.self) private var model
    @State private var exporter = WallpaperExporter()

    @AppStorage("export.hours") private var hours = 24
    @AppStorage("export.format") private var formatRaw = WallpaperExporter.Format.png.rawValue
    @AppStorage("export.album") private var albumName = "German Vocab"
    @AppStorage("export.replace") private var replaceExisting = true

    private var format: WallpaperExporter.Format {
        WallpaperExporter.Format(rawValue: formatRaw) ?? .png
    }

    private let hourChoices = [12, 24, 48, 72, 168]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Wallpapers", selection: $hours) {
                        ForEach(hourChoices, id: \.self) { count in
                            Text(label(forHours: count)).tag(count)
                        }
                    }
                    Picker("Format", selection: $formatRaw) {
                        ForEach(WallpaperExporter.Format.allCases) { option in
                            Text(option.title).tag(option.rawValue)
                        }
                    }
                    TextField("Album name", text: $albumName)
                        .textInputAutocapitalization(.words)
                    Toggle("Replace the previous export", isOn: $replaceExisting)
                } header: {
                    Text("Batch")
                } footer: {
                    Text(format.detail + " Estimated total: "
                         + estimatedSize + " for \(hours) images at \(model.canvas.resolutionLabel). "
                         + "Replacing deletes only the wallpapers this app exported last time — "
                         + "anything else in the album is left alone.")
                }

                Section("Target") {
                    LabeledContent("Canvas", value: model.canvas.name)
                    LabeledContent("Resolution", value: model.canvas.resolutionLabel)
                    LabeledContent("Megapixels",
                                   value: String(format: "%.1f MP", model.canvas.megapixels))
                    LabeledContent("Layout", value: model.settings.layout.title)
                }

                Section {
                    Button {
                        Task { await runExport() }
                    } label: {
                        HStack {
                            Label("Export to Photos", systemImage: "square.and.arrow.down.on.square")
                            Spacer()
                            if exporter.isRunning { ProgressView() }
                        }
                    }
                    .disabled(exporter.isRunning || albumName.trimmingCharacters(in: .whitespaces).isEmpty)

                    if exporter.isRunning {
                        ProgressView(value: exporter.progress)
                            .tint(Ember.ember)
                    }

                    switch exporter.state {
                    case .finished(let saved, let album):
                        Label("Saved \(saved) wallpapers to “\(album)”.",
                              systemImage: "checkmark.circle.fill")
                            .foregroundStyle(Ember.amber)
                    case .failed(let message):
                        Label(message, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(Ember.crimson)
                    default:
                        EmptyView()
                    }
                }

                Section {
                    NavigationLink {
                        HowToView()
                    } label: {
                        Label("How to make iOS rotate them hourly", systemImage: "questionmark.circle")
                    }
                } footer: {
                    Text("iOS gives no app permission to change your wallpaper directly. "
                         + "The reliable hourly path is the system's own Photo Shuffle, "
                         + "pointed at the album you just exported.")
                }
            }
            .navigationTitle("Export")
            .background(Ember.void)
            .scrollContentBackground(.hidden)
        }
    }

    private func runExport() async {
        await exporter.export(
            hours: hours,
            deck: model.deck,
            canvas: model.canvas,
            settings: model.settings,
            format: format,
            albumName: albumName.trimmingCharacters(in: .whitespaces),
            replaceExisting: replaceExisting
        )
    }

    private func label(forHours count: Int) -> String {
        switch count {
        case 12: "12 · half a day"
        case 24: "24 · one day"
        case 48: "48 · two days"
        case 72: "72 · three days"
        case 168: "168 · one week"
        default: "\(count)"
        }
    }

    /// Rough, honest arithmetic: PNGs of this design land around 1.1 bytes per
    /// pixel-thousand once zlib has had a go at the flat gradients.
    private var estimatedSize: String {
        let perImageMB = model.canvas.megapixels * (format == .png ? 1.35 : 0.28)
        let total = perImageMB * Double(hours)
        return total >= 1_024
            ? String(format: "%.1f GB", total / 1_024)
            : String(format: "%.0f MB", total)
    }
}
