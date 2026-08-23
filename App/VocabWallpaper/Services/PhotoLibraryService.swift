import Photos
import UIKit
import VocabKit

/// Writes exported wallpapers into a dedicated Photos album, which is what the
/// iOS "Photo Shuffle" lock screen points at.
enum PhotoLibraryService {

    enum Failure: Error, LocalizedError {
        case accessDenied
        case albumUnavailable
        case saveFailed(String)

        var errorDescription: String? {
            switch self {
            case .accessDenied:
                "VocabWallpaper needs permission to add photos. Enable it in Settings › Privacy › Photos."
            case .albumUnavailable:
                "The album could not be created."
            case .saveFailed(let reason):
                "Saving failed: \(reason)"
            }
        }
    }

    /// `.readWrite` rather than `.addOnly`, because creating and reusing a named
    /// album requires being able to read the album list.
    @discardableResult
    static func requestAccess() async throws -> PHAuthorizationStatus {
        let current = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if current == .authorized || current == .limited { return current }
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        guard status == .authorized || status == .limited else { throw Failure.accessDenied }
        return status
    }

    static func album(named title: String) async throws -> PHAssetCollection {
        if let existing = findAlbum(named: title) { return existing }

        var placeholder: PHObjectPlaceholder?
        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCollectionChangeRequest
                .creationRequestForAssetCollection(withTitle: title)
            placeholder = request.placeholderForCreatedAssetCollection
        }

        guard let identifier = placeholder?.localIdentifier,
              let created = PHAssetCollection.fetchAssetCollections(
                withLocalIdentifiers: [identifier], options: nil
              ).firstObject
        else { throw Failure.albumUnavailable }
        return created
    }

    static func findAlbum(named title: String) -> PHAssetCollection? {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "title = %@", title)
        return PHAssetCollection.fetchAssetCollections(
            with: .album, subtype: .albumRegular, options: options
        ).firstObject
    }

    /// Saves one image and files it in `album`.
    static func save(imageData: Data, to album: PHAssetCollection?) async throws {
        do {
            try await PHPhotoLibrary.shared().performChanges {
                let creation = PHAssetCreationRequest.forAsset()
                creation.addResource(with: .photo, data: imageData, options: nil)

                guard let album,
                      let placeholder = creation.placeholderForCreatedAsset,
                      let albumChange = PHAssetCollectionChangeRequest(for: album)
                else { return }
                albumChange.addAssets([placeholder] as NSArray)
            }
        } catch {
            throw Failure.saveFailed(error.localizedDescription)
        }
    }

    /// Number of items already sitting in the album, used to warn about
    /// duplicates before a second export.
    static func assetCount(inAlbumNamed title: String) -> Int {
        guard let album = findAlbum(named: title) else { return 0 }
        return PHAsset.fetchAssets(in: album, options: nil).count
    }

    /// Removes every asset the app previously put in the album, so re-exporting
    /// replaces rather than accumulates.
    static func emptyAlbum(named title: String) async throws {
        guard let album = findAlbum(named: title) else { return }
        let assets = PHAsset.fetchAssets(in: album, options: nil)
        guard assets.count > 0 else { return }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.deleteAssets(assets)
            }
        } catch {
            throw Failure.saveFailed(error.localizedDescription)
        }
    }
}
