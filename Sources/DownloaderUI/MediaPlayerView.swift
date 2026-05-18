import AppKit
import AVKit
import DownloaderCore
import SwiftUI

enum MediaPlaybackSupport {
    private static let nativePathExtensions: Set<String> = [
        "3g2", "3gp", "aac", "aif", "aiff", "caf", "m4a", "m4v", "mj2", "mov", "mp3", "mp4", "wav",
    ]
    private static let unsupportedPathExtensions: Set<String> = [
        "asf", "avi", "flv", "mkv", "webm", "wmv",
    ]
    private static let unsupportedContainerTokens: Set<String> = [
        "asf", "avi", "flv", "matroska", "webm", "wmv",
    ]

    static func canUseNativePlayer(for asset: MediaAsset) -> Bool {
        let pathExtension = asset.file.pathExtension.lowercased()
        if unsupportedPathExtensions.contains(pathExtension) {
            return false
        }

        if !containerTokens(for: asset).isDisjoint(with: unsupportedContainerTokens) {
            return false
        }

        return nativePathExtensions.contains(pathExtension)
    }

    static func unsupportedMessage(for asset: MediaAsset) -> String {
        let pathExtension = asset.file.pathExtension.uppercased()
        let format = pathExtension.isEmpty ? "this file" : "\(pathExtension) files"
        return "Native playback for \(format) is not reliable on macOS. Use Open Externally, or download MP4 or M4A for in-app playback."
    }

    private static func containerTokens(for asset: MediaAsset) -> Set<String> {
        guard let container = asset.container?.lowercased(), !container.isEmpty else {
            return []
        }

        return Set(container.split { !$0.isLetter && !$0.isNumber }.map(String.init))
    }
}

final class MediaPlaybackSession: ObservableObject, @unchecked Sendable {
    private let lock = NSLock()
    private var completedAssetIDs = Set<UUID>()
    private var replayingCompletedAssetIDs = Set<UUID>()

    func markCompleted(assetID: UUID) {
        lock.withLock {
            completedAssetIDs.insert(assetID)
            replayingCompletedAssetIDs.remove(assetID)
        }
    }

    func markReplayStarted(assetID: UUID) {
        lock.withLock {
            completedAssetIDs.remove(assetID)
            replayingCompletedAssetIDs.insert(assetID)
        }
    }

    func shouldPersistProgress(
        for assetID: UUID,
        mediaLibraryAssets: [MediaAsset],
        position: TimeInterval,
        duration: TimeInterval?
    ) -> Bool {
        let sessionState = lock.withLock {
            (
                completed: completedAssetIDs.contains(assetID),
                replayingCompleted: replayingCompletedAssetIDs.contains(assetID)
            )
        }
        guard !sessionState.completed else {
            return Self.isBeforeCompletedEnd(position: position, duration: duration)
        }
        if sessionState.replayingCompleted {
            return true
        }

        let wasCompletedInLibrary = mediaLibraryAssets.first(where: { $0.id == assetID })?.playback.completed == true
        guard wasCompletedInLibrary else {
            return true
        }

        return Self.isBeforeCompletedEnd(position: position, duration: duration)
    }

    func isCompleted(assetID: UUID, mediaLibraryAssets: [MediaAsset]) -> Bool {
        let wasCompletedInSession = lock.withLock {
            completedAssetIDs.contains(assetID)
        }
        if wasCompletedInSession {
            return true
        }

        return mediaLibraryAssets.first(where: { $0.id == assetID })?.playback.completed == true
    }

    func shouldPersistCompletion(assetID: UUID, position: TimeInterval, duration: TimeInterval?) -> Bool {
        let sessionState = lock.withLock {
            (
                completed: completedAssetIDs.contains(assetID),
                replayingCompleted: replayingCompletedAssetIDs.contains(assetID)
            )
        }
        guard sessionState.completed, !sessionState.replayingCompleted else {
            return false
        }

        if Self.isBeforeCompletedEnd(position: position, duration: duration) {
            return false
        }

        return true
    }

    private static func isBeforeCompletedEnd(position: TimeInterval, duration: TimeInterval?) -> Bool {
        guard position.isFinite, let duration, duration.isFinite, duration > 0 else {
            return false
        }

        return position < max(0, duration - 1)
    }
}

struct MediaPlayerView: View {
    @ObservedObject private var appState: DownloaderAppState
    let asset: MediaAsset
    @StateObject private var playbackSession = MediaPlaybackSession()
    @State private var player: AVPlayer?
    @State private var playerAssetID: UUID?
    @State private var playbackError: String?
    @State private var completionObserver: NSObjectProtocol?

    init(appState: DownloaderAppState, asset: MediaAsset) {
        self._appState = ObservedObject(wrappedValue: appState)
        self.asset = asset
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerCard
                playerCard
                metadataCard
            }
            .padding(24)
        }
        .background {
            DownloaderCanvasBackground(theme: theme)
        }
        .task(id: asset.id) {
            configurePlayer()
        }
        .onDisappear {
            persistPlayback()
            removeCompletionObserver()
            player?.pause()
        }
    }

    private var theme: DownloaderThemeStyle {
        DownloaderThemeStyle(preset: appState.themePreset)
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(asset.title)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(theme.bodyText)

                    Text(asset.file.path)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(theme.mutedText)
                        .textSelection(.enabled)
                }

                Spacer()

                Text(asset.isMissing ? "MISSING" : "LIBRARY")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(theme.bodyText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule(style: .continuous).fill((asset.isMissing ? theme.warning : theme.success).opacity(0.16)))
            }

            HStack(spacing: 10) {
                Button {
                    playFromStart()
                } label: {
                    Label("Play", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(asset.isMissing || player == nil)

                Button {
                    openExternally()
                } label: {
                    Label("Open Externally", systemImage: "arrow.up.forward.app")
                }
                .buttonStyle(.bordered)
                .disabled(asset.isMissing)

                Button {
                    appState.revealDestination(for: asset)
                } label: {
                    Label("Reveal", systemImage: "folder")
                }
                .buttonStyle(.bordered)

                Menu {
                    Button {
                        appState.openSourceURL(asset.source.absoluteString)
                    } label: {
                        Label("Open Source", systemImage: "safari")
                    }

                    Button {
                        appState.copyToClipboard(asset.file.path, label: "media path")
                    } label: {
                        Label("Copy Path", systemImage: "doc.on.doc")
                    }

                    Divider()

                    Button(role: .destructive) {
                        do {
                            try appState.removeMediaAsset(asset.id)
                        } catch {
                            appState.statusMessage = "Remove failed: \(error.localizedDescription)"
                        }
                    } label: {
                        Label("Remove", systemImage: "trash")
                    }
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                }
                .buttonStyle(.bordered)

                Spacer()
            }
        }
        .padding(22)
        .downloaderPanel(theme: theme, tone: .strong, radius: 24)
    }

    @ViewBuilder
    private var playerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Player")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(theme.bodyText)

            if asset.isMissing {
                playerPlaceholder("File is missing. Reveal opens the last known folder.", showsFileActions: false)
            } else if let player {
                NativeAVPlayerSurface(player: player)
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                playerPlaceholder(playbackError ?? "This file cannot be opened by the native player.", showsFileActions: true)
            }
        }
        .padding(18)
        .downloaderPanel(theme: theme, radius: 12)
    }

    private var metadataCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Media")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(theme.bodyText)

            LabeledMediaValue(title: "Mode", value: asset.mode.rawValue.capitalized, theme: theme)
            LabeledMediaValue(title: "Duration", value: asset.duration.map(\.formattedPlayerDuration) ?? "Unknown", theme: theme)
            LabeledMediaValue(title: "Container", value: asset.container ?? "Unknown", theme: theme)
            LabeledMediaValue(title: "Video", value: asset.codecs.video ?? "None", theme: theme)
            LabeledMediaValue(title: "Audio", value: asset.codecs.audio ?? "Unknown", theme: theme)
            if let resolution = asset.resolution {
                LabeledMediaValue(title: "Resolution", value: "\(resolution.width)x\(resolution.height)", theme: theme)
            }
            LabeledMediaValue(title: "Resume", value: asset.playback.position.formattedPlayerDuration, theme: theme)
        }
        .padding(18)
        .downloaderPanel(theme: theme, radius: 12)
    }

    private func playerPlaceholder(_ message: String, showsFileActions: Bool) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "play.slash")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(theme.mutedText)

            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(theme.mutedText)
                .multilineTextAlignment(.center)

            if showsFileActions {
                HStack(spacing: 10) {
                    Button {
                        openExternally()
                    } label: {
                        Label("Open Externally", systemImage: "arrow.up.forward.app")
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        appState.revealDestination(for: asset)
                    } label: {
                        Label("Reveal", systemImage: "folder")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 220)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(theme.canvasBase.opacity(theme.isLight ? 0.56 : 0.44))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(theme.panelStroke, lineWidth: 1)
                }
        }
    }

    private func configurePlayer() {
        persistPlayback()
        removeCompletionObserver()
        player?.pause()
        player = nil
        playerAssetID = nil
        playbackError = nil

        guard !asset.isMissing, FileManager.default.fileExists(atPath: asset.file.path) else {
            playbackError = "File is missing. Reveal opens the last known folder."
            return
        }

        guard MediaPlaybackSupport.canUseNativePlayer(for: asset) else {
            playbackError = MediaPlaybackSupport.unsupportedMessage(for: asset)
            return
        }

        let playerItem = AVPlayerItem(url: asset.file)
        let player = AVPlayer(playerItem: playerItem)
        if asset.playback.position > 0 {
            player.seek(to: CMTime(seconds: asset.playback.position, preferredTimescale: 600))
        }
        self.player = player
        playerAssetID = asset.id
        observePlaybackCompletion(for: player)
    }

    private func openExternally() {
        guard !asset.isMissing, FileManager.default.fileExists(atPath: asset.file.path) else {
            appState.statusMessage = "Open failed: file is missing."
            return
        }

        NSWorkspace.shared.open(asset.file)
        appState.statusMessage = "Opened \(asset.title) externally."
    }

    private func playFromStart() {
        guard let player else {
            return
        }

        if asset.playback.completed || playbackSession.isCompleted(assetID: asset.id, mediaLibraryAssets: appState.mediaLibraryAssets) {
            playbackSession.markReplayStarted(assetID: asset.id)
            try? appState.updatePlaybackPosition(for: asset.id, position: 0, completed: false)
            player.seek(to: .zero)
        }
        player.play()
    }

    private func persistPlayback() {
        guard let player, let playerAssetID else {
            return
        }

        let currentSeconds = player.currentTime().seconds
        guard currentSeconds.isFinite else {
            return
        }
        let itemDuration = player.currentItem?.duration.seconds
        let duration = itemDuration?.isFinite == true ? itemDuration : asset.duration

        guard playbackSession.shouldPersistProgress(
            for: playerAssetID,
            mediaLibraryAssets: appState.mediaLibraryAssets,
            position: currentSeconds,
            duration: duration
        ) else {
            return
        }

        try? appState.updatePlaybackPosition(
            for: playerAssetID,
            position: currentSeconds,
            completed: false
        )
    }

    private func observePlaybackCompletion(for player: AVPlayer) {
        removeCompletionObserver()
        guard let playerItem = player.currentItem else {
            playbackError = "Player could not load this file."
            return
        }

        let playbackSession = playbackSession
        let assetID = asset.id
        completionObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { _ in
            playbackSession.markCompleted(assetID: assetID)
            Task { @MainActor in
                let duration = player.currentItem?.duration.seconds
                let fallbackPosition = player.currentTime().seconds
                let position = duration?.isFinite == true ? duration ?? fallbackPosition : fallbackPosition
                guard playbackSession.shouldPersistCompletion(
                    assetID: assetID,
                    position: position.isFinite ? position : 0,
                    duration: duration?.isFinite == true ? duration : asset.duration
                ) else {
                    return
                }

                try? appState.updatePlaybackPosition(
                    for: assetID,
                    position: position.isFinite ? position : 0,
                    completed: true
                )
            }
        }
    }

    private func removeCompletionObserver() {
        if let completionObserver {
            NotificationCenter.default.removeObserver(completionObserver)
            self.completionObserver = nil
        }
    }
}

private struct NativeAVPlayerSurface: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> AVPlayerView {
        let playerView = AVPlayerView()
        playerView.controlsStyle = .floating
        playerView.videoGravity = .resizeAspect
        playerView.player = player
        return playerView
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        if nsView.player !== player {
            nsView.player = player
        }
    }

    static func dismantleNSView(_ nsView: AVPlayerView, coordinator: ()) {
        nsView.player?.pause()
        nsView.player = nil
    }
}

struct MediaLibraryEmptyView: View {
    @ObservedObject private var appState: DownloaderAppState

    init(appState: DownloaderAppState) {
        self._appState = ObservedObject(wrappedValue: appState)
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "play.rectangle.on.rectangle")
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(theme.mutedText)

            Text("No saved media")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(theme.bodyText)

            Button {
                appState.selectOverview()
            } label: {
                Label("Open Downloader", systemImage: "arrow.down.circle")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            DownloaderCanvasBackground(theme: theme)
        }
    }

    private var theme: DownloaderThemeStyle {
        DownloaderThemeStyle(preset: appState.themePreset)
    }
}

private struct LabeledMediaValue: View {
    let title: String
    let value: String
    let theme: DownloaderThemeStyle

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(theme.mutedText)

            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(theme.bodyText)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension TimeInterval {
    var formattedPlayerDuration: String {
        let totalSeconds = max(0, Int(self.rounded()))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return "\(hours):\(String(format: "%02d", minutes)):\(String(format: "%02d", seconds))"
        }

        return "\(minutes):\(String(format: "%02d", seconds))"
    }
}
