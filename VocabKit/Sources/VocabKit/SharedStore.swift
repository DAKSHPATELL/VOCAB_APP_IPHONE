import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

/// The App Group bridge. The widget extension is a separate process with its
/// own container, so both sides read and write settings here.
public enum SharedStore {

    /// Must match the `com.apple.security.application-groups` entitlement on
    /// both targets. Change it in one place if you re-bundle the app.
    public static let appGroupIdentifier = "group.com.dakshpatel.vocabwallpaper"

    private static let settingsKey = "wallpaper.settings.v1"
    private static let favouritesKey = "wallpaper.favourites.v1"
    private static let lastExportKey = "wallpaper.lastExport.v1"

    public static let defaults: UserDefaults = {
        UserDefaults(suiteName: appGroupIdentifier) ?? .standard
    }()

    /// True when the App Group is actually wired up. When it is false the app
    /// still works, but the widget will fall back to default settings.
    public static var appGroupIsAvailable: Bool {
        UserDefaults(suiteName: appGroupIdentifier) != nil
    }

    public static func loadSettings() -> WallpaperSettings {
        guard let data = defaults.data(forKey: settingsKey),
              let settings = try? JSONDecoder().decode(WallpaperSettings.self, from: data)
        else { return .default }
        return settings
    }

    public static func save(_ settings: WallpaperSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: settingsKey)
        reloadWidgets()
    }

    public static func loadFavourites() -> Set<String> {
        Set(defaults.stringArray(forKey: favouritesKey) ?? [])
    }

    public static func save(favourites: Set<String>) {
        defaults.set(Array(favourites).sorted(), forKey: favouritesKey)
    }

    public static var lastExportDate: Date? {
        get { defaults.object(forKey: lastExportKey) as? Date }
        set { defaults.set(newValue, forKey: lastExportKey) }
    }

    public static func reloadWidgets() {
        #if canImport(WidgetKit) && !os(macOS)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}
