import Foundation
import Photos
import SwiftUI
import VocabKit

/// Drives a batch export: render N hourly wallpapers, drop them into a Photos
/// album, report progress as it goes.
@Observable
final class WallpaperExporter {

    enum Format: String, CaseIterable, Identifiable {
        case png, heic
        var id: String { rawValue }
        var title: String { self == .png ? "PNG (lossless)" : "HEIC (smaller)" }
        var detail: String {
            self == .png
                ? "No compression artefacts in the gradients. ~2–4 MB each."
                : "Roughly a fifth of the size. Fine for most eyes."
        }
    }

    enum State: Equatable {
        case idle
        case running(completed: Int, total: Int)
        case finished(saved: Int, albumName: String)
        case failed(String)
    }

    private(set) var state: State = .idle

    var isRunning: Bool {
        if case .running = state { return true }
        return false
    }

    var progress: Double {
        guard case .running(let completed, let total) = state, total > 0 else { return 0 }
        return Double(completed) / Double(total)
    }

    func reset() { state = .idle }

    @MainActor
    func export(
        hours: Int,
        deck: VocabularyDeck,
        canvas: DeviceCanvas,
        settings: WallpaperSettings,
        format: Format,
        albumName: String,
        replaceExisting: Bool
    ) async {
        state = .running(completed: 0, total: hours)

        do {
            try await PhotoLibraryService.requestAccess()

            if replaceExisting {
                try await PhotoLibraryService.deleteAssets(
                    withIdentifiers: SharedStore.exportedAssetIdentifiers
                )
                SharedStore.exportedAssetIdentifiers = []
            }
            let album = try await PhotoLibraryService.album(named: albumName)

            let schedule = deck.schedule(from: .now, count: hours)
            guard !schedule.isEmpty else {
                state = .failed("There are no words matching the current filters.")
                return
            }

            var saved = 0
            var identifiers: [String] = []
            for scheduled in schedule {
                let data: Data
                switch format {
                case .png:
                    data = try WallpaperRenderer.pngData(
                        entry: scheduled.entry,
                        hourIndex: scheduled.hourIndex,
                        canvas: canvas,
                        settings: settings
                    )
                case .heic:
                    data = try WallpaperRenderer.heicData(
                        entry: scheduled.entry,
                        hourIndex: scheduled.hourIndex,
                        canvas: canvas,
                        settings: settings
                    )
                }

                if let identifier = try await PhotoLibraryService.save(imageData: data, to: album) {
                    identifiers.append(identifier)
                }
                saved += 1
                state = .running(completed: saved, total: schedule.count)

                // Let the run loop breathe: a 24-image PNG batch at 1320×2868 is
                // real work, and starving the main thread makes the UI stutter.
                await Task.yield()
            }

            SharedStore.exportedAssetIdentifiers += identifiers
            SharedStore.lastExportDate = .now
            state = .finished(saved: saved, albumName: albumName)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    /// Single wallpaper, saved to the camera roll rather than the album.
    @MainActor
    func saveOne(
        entry: VocabEntry,
        hourIndex: Int,
        canvas: DeviceCanvas,
        settings: WallpaperSettings
    ) async {
        state = .running(completed: 0, total: 1)
        do {
            try await PhotoLibraryService.requestAccess()
            let data = try WallpaperRenderer.pngData(
                entry: entry, hourIndex: hourIndex, canvas: canvas, settings: settings
            )
            try await PhotoLibraryService.save(imageData: data, to: nil)
            state = .finished(saved: 1, albumName: "Recents")
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
