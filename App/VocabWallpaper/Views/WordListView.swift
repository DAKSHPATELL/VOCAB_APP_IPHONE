import SwiftUI
import VocabKit

struct WordListView: View {
    @Environment(AppModel.self) private var model
    @State private var query = ""
    @State private var levelFilter: VocabEntry.Level?
    @State private var favouritesOnly = false
    @State private var selection: VocabEntry?

    private var results: [VocabEntry] {
        var entries = model.library.entries

        if let levelFilter {
            entries = entries.filter { $0.level == levelFilter }
        }
        if favouritesOnly {
            entries = entries.filter { model.isFavourite($0) }
        }
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            entries = entries.filter { entry in
                [entry.word, entry.translation, entry.example, entry.category]
                    .contains { $0.localizedCaseInsensitiveContains(trimmed) }
            }
        }
        return entries.sorted { $0.word.localizedCompare($1.word) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    filterRow
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 8, trailing: 0))
                        .listRowBackground(Color.clear)
                }

                Section {
                    ForEach(results) { entry in
                        Button {
                            selection = entry
                        } label: {
                            row(for: entry)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .leading) {
                            Button {
                                model.toggleFavourite(entry)
                            } label: {
                                Label("Favourite",
                                      systemImage: model.isFavourite(entry) ? "star.slash" : "star")
                            }
                            .tint(Ember.amber)
                        }
                    }
                } header: {
                    Text("\(results.count) of \(model.library.entries.count) words")
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Ember.void)
            .searchable(text: $query, prompt: "Word, meaning, example")
            .navigationTitle("Wörter")
            .sheet(item: $selection) { entry in
                WordDetailView(entry: entry)
                    .environment(model)
            }
        }
    }

    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(title: "All", isOn: levelFilter == nil && !favouritesOnly) {
                    levelFilter = nil
                    favouritesOnly = false
                }
                chip(title: "★", isOn: favouritesOnly) {
                    favouritesOnly.toggle()
                }
                ForEach(model.library.levels, id: \.self) { level in
                    chip(title: level.rawValue, isOn: levelFilter == level) {
                        levelFilter = levelFilter == level ? nil : level
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func chip(title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isOn ? Ember.ember.opacity(0.9) : Ember.ash,
                            in: Capsule())
                .foregroundStyle(isOn ? Ember.void : Ember.smoke)
        }
        .buttonStyle(.plain)
    }

    private func row(for entry: VocabEntry) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Ember.accent(for: entry))
                .frame(width: 3, height: 34)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(entry.headword)
                        .font(.body.weight(.semibold))
                    if model.isFavourite(entry) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(Ember.amber)
                    }
                }
                Text(entry.translation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(entry.level.rawValue)
                .font(.caption2.weight(.bold))
                .foregroundStyle(Ember.dust)
        }
        .padding(.vertical, 3)
    }
}

struct WordDetailView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var exporter = WallpaperExporter()

    let entry: VocabEntry

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    WallpaperPreview(
                        entry: entry,
                        hourIndex: model.hourIndex(),
                        settings: model.settings
                    )
                    .aspectRatio(model.canvas.aspectRatio, contentMode: .fit)
                    .frame(maxHeight: 460)
                    .padding(.horizontal, 40)
                    .padding(.top, 12)

                    VStack(alignment: .leading, spacing: 14) {
                        detail("Meaning", entry.translation)
                        if let inflection = entry.inflection {
                            detail(entry.partOfSpeech.inflectionCaption, inflection)
                        }
                        detail("Example", entry.example)
                        detail("", entry.exampleTranslation, secondary: true)
                        detail("Tags",
                               "\(entry.level.rawValue) · \(entry.partOfSpeech.englishLabel) · \(entry.category)")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(Ember.pitch, in: RoundedRectangle(cornerRadius: 18))
                    .padding(.horizontal, 20)

                    Button {
                        Task {
                            await exporter.saveOne(
                                entry: entry,
                                hourIndex: model.hourIndex(),
                                canvas: model.canvas,
                                settings: model.settings
                            )
                        }
                    } label: {
                        Label(savedLabel, systemImage: "arrow.down.to.line")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Ember.ember)
                    .controlSize(.large)
                    .disabled(exporter.isRunning)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }
            .background(Ember.void)
            .navigationTitle(entry.word)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        model.toggleFavourite(entry)
                    } label: {
                        Image(systemName: model.isFavourite(entry) ? "star.fill" : "star")
                    }
                    .tint(Ember.amber)
                }
            }
        }
    }

    private var savedLabel: String {
        if case .finished = exporter.state { return "Saved to Photos" }
        return "Save this wallpaper"
    }

    private func detail(_ title: String, _ value: String, secondary: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            if !title.isEmpty {
                Text(title.uppercased())
                    .font(.caption2.weight(.semibold))
                    .tracking(1.2)
                    .foregroundStyle(Ember.dust)
            }
            Text(value)
                .font(secondary ? .subheadline : .body)
                .foregroundStyle(secondary ? Color.secondary : Ember.bone)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
