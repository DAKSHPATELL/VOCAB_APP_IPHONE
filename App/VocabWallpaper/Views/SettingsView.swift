import SwiftUI
import VocabKit

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var showsResetConfirmation = false

    var body: some View {
        @Bindable var model = model

        return NavigationStack {
            Form {
                previewSection

                Section("Design") {
                    Picker("Layout", selection: $model.settings.layout) {
                        ForEach(WallpaperLayout.allCases, id: \.self) { layout in
                            Text(layout.title).tag(layout)
                        }
                    }
                    Text(model.settings.layout.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    slider("Ember glow", value: $model.settings.emberIntensity)
                    slider("Grain", value: $model.settings.grain)
                    slider("Vignette", value: $model.settings.vignette)
                }

                Section("Show on the wallpaper") {
                    Toggle("English meaning", isOn: $model.settings.showTranslation)
                    Toggle("Plural / verb forms", isOn: $model.settings.showInflection)
                    Toggle("Example sentence", isOn: $model.settings.showExample)
                    Toggle("Example translation", isOn: $model.settings.showExampleTranslation)
                        .disabled(!model.settings.showExample)
                    Toggle("Hour and level stamp", isOn: $model.settings.showHourStamp)
                }

                Section {
                    Picker("Canvas", selection: canvasBinding) {
                        Text("This device — \(DeviceCanvas.current.resolutionLabel)")
                            .tag(String?.none)
                        ForEach(DeviceCanvas.presets) { canvas in
                            Text("\(canvas.name) — \(canvas.resolutionLabel)")
                                .tag(Optional(canvas.id))
                        }
                    }
                    Toggle("Supersample (2× then downscale)", isOn: $model.settings.supersample)
                } header: {
                    Text("Resolution")
                } footer: {
                    Text("Wallpapers render at exactly \(model.canvas.resolutionLabel) "
                         + "(\(String(format: "%.1f", model.canvas.megapixels)) MP), so iOS never "
                         + "rescales them. Supersampling doubles render time for slightly "
                         + "cleaner serif edges.")
                }

                levelSection
                partOfSpeechSection
                categorySection

                Section {
                    Button {
                        model.reshuffleDeck()
                    } label: {
                        Label("Reshuffle the deck", systemImage: "shuffle")
                    }
                    Button(role: .destructive) {
                        showsResetConfirmation = true
                    } label: {
                        Label("Reset everything", systemImage: "arrow.counterclockwise")
                    }
                } footer: {
                    Text("Reshuffling picks a new order for every word without changing "
                         + "which words are in rotation. Seed \(String(model.settings.seed, radix: 16)).")
                }

                Section {
                    NavigationLink {
                        HowToView()
                    } label: {
                        Label("Hourly setup guide", systemImage: "questionmark.circle")
                    }
                    LabeledContent("Words in rotation", value: "\(model.deck.count)")
                    LabeledContent("Repeats after",
                                   value: "\(Int(model.deck.cycleDuration / 86_400)) days")
                    LabeledContent("App Group",
                                   value: SharedStore.appGroupIsAvailable ? "Connected" : "Not configured")
                        .foregroundStyle(SharedStore.appGroupIsAvailable ? Color.primary : Ember.crimson)
                } header: {
                    Text("About")
                } footer: {
                    if !SharedStore.appGroupIsAvailable {
                        Text("The widget cannot read your settings until the App Group "
                             + "“\(SharedStore.appGroupIdentifier)” is enabled on both targets "
                             + "in Signing & Capabilities.")
                    }
                }
            }
            .navigationTitle("Einstellungen")
            .scrollContentBackground(.hidden)
            .background(Ember.void)
            .confirmationDialog("Reset every setting?",
                                isPresented: $showsResetConfirmation,
                                titleVisibility: .visible) {
                Button("Reset", role: .destructive) { model.resetToDefaults() }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    // MARK: - Sections

    private var previewSection: some View {
        Section {
            HStack {
                Spacer()
                WallpaperPreview(
                    entry: model.entry() ?? AppModel.placeholder,
                    hourIndex: model.hourIndex(),
                    settings: model.settings,
                    cornerRadius: 20
                )
                .aspectRatio(model.canvas.aspectRatio, contentMode: .fit)
                .frame(height: 250)
                Spacer()
            }
            .listRowBackground(Color.clear)
        }
    }

    private var levelSection: some View {
        Section {
            ForEach(VocabEntry.Level.allCases, id: \.self) { level in
                let count = model.library.entries.filter { $0.level == level }.count
                if count > 0 {
                    Toggle(isOn: levelBinding(level)) {
                        HStack {
                            Text(level.rawValue)
                            Spacer()
                            Text("\(count)").foregroundStyle(.secondary)
                        }
                    }
                }
            }
        } header: {
            Text("Levels")
        } footer: {
            Text("Turning everything off falls back to the full corpus rather than "
                 + "showing an empty wallpaper.")
        }
    }

    private var partOfSpeechSection: some View {
        Section("Word types") {
            ForEach(VocabEntry.PartOfSpeech.allCases, id: \.self) { pos in
                let count = model.library.entries.filter { $0.partOfSpeech == pos }.count
                if count > 0 {
                    Toggle(isOn: posBinding(pos)) {
                        HStack {
                            Text(pos.englishLabel.capitalized)
                            Spacer()
                            Text("\(count)").foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private var categorySection: some View {
        Section {
            NavigationLink {
                CategoryPicker()
                    .environment(model)
            } label: {
                LabeledContent(
                    "Themes",
                    value: model.settings.categories.isEmpty
                        ? "All"
                        : "\(model.settings.categories.count) selected"
                )
            }
        } header: {
            Text("Themes")
        }
    }

    // MARK: - Controls

    private func slider(_ title: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                Spacer()
                Text("\(Int(value.wrappedValue * 100))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: 0...1)
                .tint(Ember.ember)
        }
    }

    private var canvasBinding: Binding<String?> {
        Binding(
            get: { model.settings.canvasID },
            set: { model.settings.canvasID = $0 }
        )
    }

    private func levelBinding(_ level: VocabEntry.Level) -> Binding<Bool> {
        Binding(
            get: { model.settings.levels.contains(level) },
            set: { isOn in
                if isOn { model.settings.levels.insert(level) }
                else { model.settings.levels.remove(level) }
            }
        )
    }

    private func posBinding(_ pos: VocabEntry.PartOfSpeech) -> Binding<Bool> {
        Binding(
            get: {
                model.settings.partsOfSpeech.isEmpty
                    || model.settings.partsOfSpeech.contains(pos)
            },
            set: { isOn in
                var current = model.settings.partsOfSpeech.isEmpty
                    ? Set(VocabEntry.PartOfSpeech.allCases)
                    : model.settings.partsOfSpeech
                if isOn { current.insert(pos) } else { current.remove(pos) }
                model.settings.partsOfSpeech =
                    current.count == VocabEntry.PartOfSpeech.allCases.count ? [] : current
            }
        )
    }
}

struct CategoryPicker: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        List {
            Section {
                Button("Select all") { model.settings.categories = [] }
            } footer: {
                Text("An empty selection means every theme is in rotation.")
            }

            ForEach(model.library.categories, id: \.self) { category in
                let count = model.library.entries.filter { $0.category == category }.count
                Button {
                    toggle(category)
                } label: {
                    HStack {
                        Text(category.capitalized)
                            .foregroundStyle(Ember.bone)
                        Spacer()
                        Text("\(count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if isOn(category) {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Ember.ember)
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Ember.void)
        .navigationTitle("Themes")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func isOn(_ category: String) -> Bool {
        model.settings.categories.isEmpty || model.settings.categories.contains(category)
    }

    private func toggle(_ category: String) {
        var current = model.settings.categories.isEmpty
            ? Set(model.library.categories)
            : model.settings.categories
        if current.contains(category) { current.remove(category) } else { current.insert(category) }
        if current.isEmpty || current.count == model.library.categories.count {
            model.settings.categories = []
        } else {
            model.settings.categories = current
        }
    }
}
