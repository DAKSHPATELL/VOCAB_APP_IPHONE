import Foundation
import SwiftUI
import VocabKit

/// Renders a batch of wallpapers straight to the app's Documents directory.
///
/// Only ever runs when the process is launched with `--export-wallpapers`,
/// which requires a debugger or `xcrun simctl` — a person tapping the icon
/// cannot reach it. It exists so CI can boot the app in a simulator, produce
/// real wallpapers at real resolutions, and publish them as artifacts, which is
/// also the only way to see the design without a Mac to hand.
///
///     xcrun simctl launch booted com.dakshpatel.vocabwallpaper \
///         --export-wallpapers --count 8 --canvas iphone-6.7
enum WallpaperDump {

    private static let flag = "--export-wallpapers"

    static var isRequested: Bool {
        ProcessInfo.processInfo.arguments.contains(flag)
    }

    @MainActor
    static func runIfRequested(model: AppModel) async {
        guard isRequested else { return }

        let arguments = ProcessInfo.processInfo.arguments
        let count = value(after: "--count", in: arguments).flatMap(Int.init) ?? 8
        let canvas = value(after: "--canvas", in: arguments)
            .flatMap { DeviceCanvas.preset(id: $0) } ?? DeviceCanvas.presets[0]

        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let output = directory.appendingPathComponent("wallpapers", isDirectory: true)
        try? FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

        var settings = model.settings
        settings.layout = .lockScreen

        var manifest: [String] = [
            "Vokabel — \(canvas.name), \(canvas.resolutionLabel)",
            ""
        ]

        for scheduled in model.deck.schedule(from: .now, count: count) {
            do {
                let data = try WallpaperRenderer.pngData(
                    entry: scheduled.entry,
                    hourIndex: scheduled.hourIndex,
                    canvas: canvas,
                    settings: settings
                )
                let hour = WallpaperCanvasHour.stamp(for: scheduled.hourIndex)
                let name = "\(hour.replacingOccurrences(of: ":", with: ""))-"
                    + "\(scheduled.entry.id).png"
                try data.write(to: output.appendingPathComponent(name))
                manifest.append("\(hour)  \(scheduled.entry.headword) — \(scheduled.entry.translation)")
            } catch {
                manifest.append("FAILED \(scheduled.entry.id): \(error.localizedDescription)")
            }
        }

        try? manifest.joined(separator: "\n").write(
            to: output.appendingPathComponent("manifest.txt"),
            atomically: true,
            encoding: .utf8
        )

        // A sentinel file, so CI can poll for completion rather than guessing
        // at a sleep duration.
        try? "done".write(
            to: directory.appendingPathComponent("export-complete"),
            atomically: true,
            encoding: .utf8
        )
    }

    private static func value(after key: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: key),
              arguments.index(after: index) < arguments.endIndex
        else { return nil }
        return arguments[arguments.index(after: index)]
    }
}
