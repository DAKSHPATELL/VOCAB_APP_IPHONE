import SwiftUI
import VocabKit

/// Renders the real wallpaper view at whatever size it is given. Because every
/// dimension in `WallpaperCanvas` is relative, this preview is pixel-faithful —
/// what you see here is what gets exported.
struct WallpaperPreview: View {
    let entry: VocabEntry
    let hourIndex: Int
    let settings: WallpaperSettings
    var cornerRadius: CGFloat = 34

    var body: some View {
        GeometryReader { proxy in
            WallpaperCanvas(
                entry: entry,
                hourIndex: hourIndex,
                size: proxy.size,
                settings: settings
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Ember.ember.opacity(0.22), lineWidth: 1)
        }
        .shadow(color: Ember.ember.opacity(0.28), radius: 26, y: 12)
    }
}

/// Preview with the lock-screen furniture drawn on top, so the safe areas can
/// actually be judged before exporting.
struct LockScreenPreview: View {
    let entry: VocabEntry
    let hourIndex: Int
    let settings: WallpaperSettings

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                WallpaperCanvas(
                    entry: entry,
                    hourIndex: hourIndex,
                    size: proxy.size,
                    settings: settings
                )

                if settings.layout == .lockScreen {
                    VStack(spacing: proxy.size.height * 0.004) {
                        Text(Date.now, format: .dateTime.weekday(.wide).day().month(.wide))
                            .font(.system(size: proxy.size.height * 0.018, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.85))
                        Text(Date.now, format: .dateTime.hour().minute())
                            .font(.system(size: proxy.size.height * 0.085, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.92))
                    }
                    .padding(.top, proxy.size.height * 0.10)
                    .allowsHitTesting(false)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .strokeBorder(Ember.ember.opacity(0.22), lineWidth: 1)
        }
        .shadow(color: Ember.ember.opacity(0.28), radius: 26, y: 12)
    }
}
