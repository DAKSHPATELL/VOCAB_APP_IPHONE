import SwiftUI
import VocabKit

@main
struct VocabWallpaperApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .preferredColorScheme(.dark)
                .tint(Ember.flame)
        }
    }
}
