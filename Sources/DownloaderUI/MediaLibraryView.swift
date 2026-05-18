import DownloaderCore
import SwiftUI

struct MediaLibraryView: View {
    @ObservedObject private var appState: DownloaderAppState

    init(appState: DownloaderAppState) {
        self._appState = ObservedObject(wrappedValue: appState)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            controls
            content
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            DownloaderCanvasBackground(theme: theme)
        }
    }

    private var theme: DownloaderThemeStyle {
        DownloaderThemeStyle(preset: appState.themePreset)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Library")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(theme.bodyText)

                Text(savedMediaCountLabel)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(theme.mutedText)
            }

            Spacer()

            Button {
                appState.refreshMediaLibrary()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
        }
    }

    private var savedMediaCountLabel: String {
        let count = appState.mediaLibraryAssets.count
        return "\(count) saved media \(count == 1 ? "file" : "files")"
    }

    private var controls: some View {
        HStack(spacing: 12) {
            TextField("Search library", text: $appState.mediaLibrarySearchText)
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 220, maxWidth: 360)

            Picker("Filter", selection: $appState.mediaLibraryFilter) {
                ForEach(MediaLibraryFilter.allCases, id: \.self) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 420)

            Picker("Sort", selection: $appState.mediaLibrarySort) {
                ForEach(MediaLibrarySort.allCases, id: \.self) { sort in
                    Text(sort.title).tag(sort)
                }
            }
            .frame(width: 170)
        }
    }

    @ViewBuilder
    private var content: some View {
        let assets = appState.filteredMediaLibraryAssets
        if let loadError = appState.mediaLibraryLoadError {
            libraryErrorState(loadError)
        } else if appState.mediaLibraryAssets.isEmpty {
            MediaLibraryEmptyView(appState: appState)
        } else if assets.isEmpty {
            emptySearchState
        } else {
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(assets) { asset in
                        MediaLibraryAssetRow(appState: appState, asset: asset, theme: theme)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var emptySearchState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(theme.mutedText)

            Text("No matches")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(theme.bodyText)

            Text("Try another search or filter.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(theme.mutedText)

            Button {
                appState.clearMediaLibraryFilters()
            } label: {
                Label("Clear Filters", systemImage: "line.3.horizontal.decrease.circle")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func libraryErrorState(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(theme.warning)

            Text("Library needs attention")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(theme.bodyText)

            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(theme.mutedText)
                .multilineTextAlignment(.center)
                .textSelection(.enabled)

            HStack(spacing: 10) {
                Button {
                    appState.refreshMediaLibrary()
                } label: {
                    Label("Retry", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderedProminent)

                Button {
                    appState.selectOverview()
                } label: {
                    Label("Open Downloader", systemImage: "arrow.down.circle")
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct MediaLibraryAssetRow: View {
    @ObservedObject var appState: DownloaderAppState
    let asset: MediaAsset
    let theme: DownloaderThemeStyle

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: iconName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(asset.isMissing ? theme.warning : theme.modeColor(asset.mode))
                .frame(width: 34, height: 34)
                .background {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(theme.canvasBase.opacity(theme.isLight ? 0.62 : 0.46))
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(asset.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(theme.bodyText)
                    .lineLimit(1)

                Text(asset.file.path)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(theme.mutedText)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(asset.duration.map(\.formattedPlayerDuration) ?? "Unknown")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(theme.bodyText)

                Text(asset.isMissing ? "Missing" : asset.mode.rawValue.capitalized)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(asset.isMissing ? theme.warning : theme.mutedText)
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    assetActions
                }
                .labelStyle(.titleAndIcon)

                HStack(spacing: 6) {
                    assetActions
                }
                .labelStyle(.iconOnly)
            }
        }
        .padding(14)
        .downloaderPanel(theme: theme, radius: 12)
    }

    @ViewBuilder
    private var assetActions: some View {
        Button {
            appState.selection = .library(asset.id)
        } label: {
            Label("Open", systemImage: "play.rectangle")
        }
        .buttonStyle(.bordered)
        .help("Open in player")

        Button {
            appState.requeue(asset)
        } label: {
            Label("Requeue", systemImage: "arrow.clockwise")
        }
        .buttonStyle(.bordered)
        .help("Requeue with current Smart Mode settings")

        Button {
            appState.copyToClipboard(asset.file.path, label: "media path")
        } label: {
            Label("Copy", systemImage: "doc.on.doc")
        }
        .buttonStyle(.bordered)
        .help("Copy media path")

        Button(role: .destructive) {
            do {
                try appState.removeMediaAsset(asset.id)
            } catch {
                appState.statusMessage = "Remove failed: \(error.localizedDescription)"
            }
        } label: {
            Label("Remove", systemImage: "trash")
        }
        .buttonStyle(.bordered)
        .help("Remove from library")
    }

    private var iconName: String {
        if asset.isMissing {
            return "exclamationmark.triangle.fill"
        }

        return asset.mode == .video ? "play.rectangle.fill" : "waveform.circle.fill"
    }
}

struct NowPlayingBar: View {
    @ObservedObject private var appState: DownloaderAppState
    let asset: MediaAsset

    init(appState: DownloaderAppState, asset: MediaAsset) {
        self._appState = ObservedObject(wrappedValue: appState)
        self.asset = asset
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: asset.mode == .video ? "play.rectangle.fill" : "waveform.circle.fill")
                .foregroundStyle(theme.modeColor(asset.mode))

            VStack(alignment: .leading, spacing: 2) {
                Text(asset.title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(theme.bodyText)
                    .lineLimit(1)

                Text("Resume \(asset.playback.position.formattedPlayerDuration)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(theme.mutedText)
            }

            Spacer()

            Button {
                appState.selection = .library(asset.id)
            } label: {
                Label("Now Playing", systemImage: "play.fill")
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
        .background(.bar)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(theme.panelStroke.opacity(theme.isLight ? 1 : 0.75))
                .frame(height: 1)
        }
    }

    private var theme: DownloaderThemeStyle {
        DownloaderThemeStyle(preset: appState.themePreset)
    }
}
