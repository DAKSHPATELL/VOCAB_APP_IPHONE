import SwiftUI
import VocabKit

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        TabView {
            NowView()
                .tabItem { Label("Now", systemImage: "flame.fill") }

            ExportView()
                .tabItem { Label("Export", systemImage: "square.and.arrow.down.on.square") }

            WordListView()
                .tabItem { Label("Words", systemImage: "text.book.closed.fill") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "slider.horizontal.3") }
        }
        .background(Ember.void)
        .onChange(of: model.settings) { _, _ in model.persistSettings() }
        .onChange(of: model.favourites) { _, _ in model.persistFavourites() }
    }
}
